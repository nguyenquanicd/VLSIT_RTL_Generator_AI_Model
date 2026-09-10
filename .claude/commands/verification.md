# Phase 5 · Verification — /verification

**Mục tiêu:** Chạy simulation VCS, mutation testing Yosys, cập nhật RTM với 6 điều kiện
sign-off per REQ-ID, và trình bày RTM Dashboard để người dùng ký Gate 5.

**Người ký, tool chạy. LLM không sign-off được bất cứ thứ gì.**

---

## Quy tắc bắt buộc

1. Gate 5 chỉ mở sau khi sim_pass và mutation_score đã được tính xong.
2. REQ-ID thiếu bất kỳ điều kiện nào trong 5 điều kiện đầu → ô `signed_off` bị **LOCK**, không cho ký.
3. Mutation score < 85% không block Gate 5, nhưng block sign-off của REQ-ID đó.
4. Mọi kết quả phải đến từ tool — không tự suy diễn hay đánh dấu pass/fail thay tool.
5. Nếu VCS compile fail → **dừng ngay**, không chạy sim, không mở dashboard.

---

## Bước 1 — Pre-flight

**1.1 Kiểm tra gate chain:**

Đọc và kiểm tra theo thứ tự:
- `schemas/final_config.json` → `gate_2_approved == true` — nếu không: _"Gate 2 chưa ký. Chạy `/config_ui`."_
- `schemas/rtm.json` → `gate_3_approved == true` — nếu không: _"Gate 3 chưa ký. Chạy `/sva_generator`."_
- `schemas/selected_testplan.json` → `gate_4_approved == true` — nếu không: _"Gate 4 chưa ký. Chạy `/tb_generator`."_

Kiểm tra file list tồn tại:
- `src/rtl/filelist.f`
- `src/sva/filelist_sva.f`
- `src/tb/filelist_tb.f`

Thiếu file nào → dừng, thông báo rõ.

**1.2 Kiểm tra tool:**

Thử VCS trước; nếu không có thì dùng Icarus Verilog:

```bash
# Thử VCS
if module load synopsys/vcs/X-2025.06 2>/dev/null && vcs -ID 2>&1 | head -1; then
    sim_tool="vcs"
elif source /etc/profile.d/modules.sh && module load oss-cad-suite 2>/dev/null && iverilog -V 2>&1 | head -1; then
    sim_tool="icarus"
else
    echo "Không tìm thấy VCS hoặc Icarus Verilog. Dừng."
    exit 1
fi
echo "sim_tool=$sim_tool"
```

Nếu cả hai đều fail → dừng: _"Không có simulator nào khả dụng. Kiểm tra `module avail`."_

```bash
module load oss-cad-suite && yosys --version
```
Nếu fail → cảnh báo: _"oss-cad-suite không load được — bước mutation sẽ bị skip."_
Ghi nhận `mutation_available: false` để xử lý ở Bước 4.

> **Icarus 13.0 known limitations (ghi nhận để tránh khi generate TB):**
> - Tránh `$realtime` trong compilation-unit-scope tasks — dùng `longint'($time)` thay thế (VPI type=600 bug)
> - Tránh `disable fork` trong `automatic` tasks — dùng done-flag `fork...join` pattern
> - Tránh `#<param_expr>` (delay dùng real param) trong CU-scope tasks — dùng literal hoặc `@(posedge clk)`
> - File TB signals phải có `` `timescale 1ns/1ps `` (RTL files không cần)

**1.3 Chuẩn bị thư mục:**

```bash
mkdir -p work/mutant work/mut_scripts work/mut_results
```

Thông báo pre-flight:
```
Pre-flight OK:
  Gate 2/3/4: approved
  VCS: X-2025.06 ✓
  Yosys: 0.58 ✓  (hoặc ✗ nếu không load được)
  Schemas: all present ✓
```

---

## Bước 2 — Full compile check (RTL + SVA + TB)

**Nếu `sim_tool == "vcs"`:**

```bash
module load synopsys/vcs/X-2025.06
vcs -sverilog -timescale=1ns/1ps \
    -f src/rtl/filelist.f \
    -f src/sva/filelist_sva.f \
    -f src/tb/filelist_tb.f \
    -assert svaext_bind \
    +define+SIMULATION \
    -o work/simv 2>&1 | tee work/compile.log
```

**Nếu `sim_tool == "icarus"`:**

```bash
source /etc/profile.d/modules.sh && module load oss-cad-suite
mkdir -p sim work
iverilog -g2012 -o sim/simv \
    $(grep -v "^//" src/rtl/filelist.f) \
    $(grep -v "^-f\|^//" src/tb/filelist_tb.f) \
    src/tb/tests/tc_*.sv \
    2>&1 | tee work/compile.log
```

> SVA (filelist_sva.f) không được Icarus Verilog hỗ trợ — bỏ qua trong Icarus mode.

Parse `work/compile.log`:
- Tìm `error:` hoặc exit code ≠ 0 → **FAIL**
- Tìm `warning:` → ghi nhận nhưng không block

Nếu **FAIL**:
1. Hiển thị 20 dòng lỗi đầu tiên từ `work/compile.log`
2. Phân tích lỗi: file nào, dòng nào, lỗi gì
3. Nếu lỗi ở RTL → hướng dẫn: _"Fix `src/rtl/<file>.sv` rồi chạy lại `/verification`"_
4. Nếu lỗi ở SVA → hướng dẫn: _"Fix `src/sva/<file>.sv`..."_
5. Nếu lỗi ở TB → hướng dẫn: _"Fix `src/tb/<file>.sv`..."_
6. **Dừng**, không tiếp tục.

Nếu **PASS**: _"✓ Compile OK. Bắt đầu simulation."_

---

## Bước 3 — Simulation per TC

Đọc danh sách TC từ `schemas/selected_testplan.json` (chỉ TC có `selected: true`).

Tạo `work/sim_results.json` rỗng:
```json
{ "tc_results": {}, "sva_violations": 0, "total_pass": 0, "total_fail": 0, "total_timeout": 0 }
```

**Với mỗi TC**, chạy:

_Nếu `sim_tool == "vcs"`:_
```bash
work/simv \
    +TC=<tc_id> \
    +TIMEOUT=500000 \
    +HEXFILE=src/tb/tests/<tc_id>.hex \
    2>&1 | tee work/sim_<tc_id>.log
```

_Nếu `sim_tool == "icarus"`:_
```bash
# Icarus chạy tất cả TC trong một binary — không chạy từng TC riêng lẻ
vvp sim/simv 2>&1 | tee work/sim_all.log
```

Parse output:
- `[PASS]` → status = `pass`
- `[FAIL]` → status = `fail`
- `[N/A]` → status = `na` (không block sign-off)
- `Assertion FAILED` → status = `sva_violation` (cũng là fail, chỉ VCS mode)
- `TESTBENCH SUMMARY: X PASS, Y FAIL` → dùng làm tổng kết
- Không có SUMMARY sau timeout → status = `timeout`

Hiển thị progress sau mỗi TC:
```
TC-001 reset_boot_addr    : PASS
TC-002 rv32i_alu_ops      : PASS  (SVA violations: 0)
TC-003 rv32i_lui_auipc    : FAIL  ← dừng hỏi
```

Nếu TC **fail hoặc timeout**:
> **"TC-xxx `<name>` FAIL. Xem `work/sim_<tc_id>.log`. Chọn: (s)kip và tiếp tục / (f)ix và retry / (a)bort?"**
- `skip` → ghi `status: fail`, tiếp tục TC tiếp theo
- `fix` → người dùng fix file tương ứng, chạy lại TC này
- `abort` → dừng hoàn toàn

**Tổng kết simulation:**
```
═══ Simulation Summary ══════════════════════
  Total TC:   XX
  PASS:       XX
  FAIL:       XX
  TIMEOUT:    XX
  SVA violations: XX
════════════════════════════════════════════
```

**Update `rtm.json`:**

Với mỗi REQ-ID trong rtm.json:
- Lấy danh sách TC cover REQ-ID đó (từ `tc_ids` field)
- Kiểm tra trong `work/sim_results.json` xem tất cả TC đó có status `pass` không
- Không có SVA violation nào liên quan đến assertion của REQ-ID đó
- Nếu đủ: `sim_pass: true`; nếu không: `sim_pass: false`

---

## Bước 4 — Mutation testing

Nếu `mutation_available: false` từ Bước 1 → thông báo _"Bỏ qua mutation testing (oss-cad-suite không khả dụng). Tất cả REQ-IDs sẽ có `mutation_score: 'N/A'`."_ → sang Bước 5.

**4.1 Build danh sách REQ-ID cần mutation:**

Chỉ test mutation cho REQ-ID có `sim_pass: true` (test mutation trên RTL sai là vô nghĩa).

Với mỗi REQ-ID:
1. Grep `src/rtl/` để tìm dòng có tag `// REQ-xxx`:
   ```bash
   grep -rn "// REQ-xxx" src/rtl/ | cut -d: -f1 | sort -u
   ```
2. Xác định module (tên file `.sv` không có path)
3. Nếu không tìm thấy tag nào → `mutation_score: "N/A"`, skip

**4.2 Generate mutation list per REQ-ID:**

```bash
module load oss-cad-suite
cat > work/mut_scripts/gen_<req_id>.ys << 'YOSYS_EOF'
read_verilog -sv -f src/rtl/filelist.f
hierarchy -check -top rv32im_core
proc; opt
select -module <module_name>
mutate -list 50 -o work/mutations_<req_id>.txt
YOSYS_EOF
yosys work/mut_scripts/gen_<req_id>.ys 2>&1 | tee work/mut_scripts/gen_<req_id>.log
```

Nếu `work/mutations_<req_id>.txt` rỗng hoặc không tạo được → `mutation_score: "N/A"`, skip.

**4.3 Apply + run mỗi mutation:**

Hiển thị progress: `[REQ-001] Mutation 1/50 ...`

Với mỗi mutation M (mỗi dòng trong `mutations_<req_id>.txt`):

```bash
# Bước A: Apply mutation
cat > work/mut_scripts/apply_${M_ID}.ys << YOSYS_EOF
read_verilog -sv -f src/rtl/filelist.f
hierarchy -check -top rv32im_core
proc; opt
mutate ${M_ARGS}
write_verilog -sv work/mutant/rv32im_mutant_${M_ID}.sv
YOSYS_EOF
yosys work/mut_scripts/apply_${M_ID}.ys 2>/dev/null

# Bước B: Compile mutant (silent)
vcs -sverilog -timescale=1ns/1ps \
    work/mutant/rv32im_mutant_${M_ID}.sv \
    -f src/sva/filelist_sva.f \
    -f src/tb/filelist_tb.f \
    -assert svaext_bind \
    +define+SIMULATION \
    -o work/mutant/simv_${M_ID} 2>/dev/null
COMPILE_EXIT=$?

# Nếu compile fail → skip mutation này (không tính vào total)
if [ $COMPILE_EXIT -ne 0 ]; then
  echo "COMPILE_FAIL" > work/mut_results/result_${M_ID}.txt
  continue
fi

# Bước C: Run với timeout ngắn
work/mutant/simv_${M_ID} +TIMEOUT=100000 \
    2>&1 | grep -E "\[PASS\]|\[FAIL\]|Assertion FAILED" \
    > work/mut_results/result_${M_ID}.txt

# Bước D: Phân loại
if grep -qE "\[FAIL\]|Assertion FAILED" work/mut_results/result_${M_ID}.txt; then
  echo "KILLED"
else
  echo "SURVIVED: ${M_ARGS}" >> work/mut_survived_<req_id>.txt
fi
```

**4.4 Tính và hiển thị score:**

Sau khi chạy xong tất cả mutations của một REQ-ID:
```
REQ-001: 46/50 killed (92%) ✓
REQ-002: 42/50 killed (84%) ⚠ below 85%
  Survived mutations:
    - mutate -module rv32im_alu -cell u_add -port Y -bit 3 -inv
    - ...
```

`mutation_score[REQ-ID] = killed / (total - compile_fail)`

Nếu score < 0.85:
> **"REQ-xxx mutation score < 85%. Gợi ý: thêm assertion hoặc TC để kill các mutation trên. Tiếp tục vào dashboard với score hiện tại (sign-off sẽ bị LOCK), hay dừng để bổ sung? (continue/stop)"**
- `stop` → dừng, người dùng fix, chạy lại `/verification`
- `continue` → ghi score hiện tại, sang Bước 5

**Update `rtm.json`** với `mutation_score` và `mutation_detail` cho mỗi REQ-ID.

---

## Bước 5 — Gate 5: RTM Dashboard

**5.1 Tính eligible status per REQ-ID:**

REQ-ID eligible để sign-off khi tất cả 5 điều kiện đều đúng:
1. `rtl_traced == true`
2. `sva_traced == true` (có assertion đã confirmed ở Gate 3)
3. `tc_traced == true` (có TC đã chọn ở Gate 4)
4. `sim_pass == true`
5. `mutation_score >= 0.85` hoặc `mutation_score == "N/A"`

**5.2 Hiển thị dashboard:**

```
╔══ GATE 5 · RTM DASHBOARD ══════════════════════════════════════════════════════╗
║  IP: rv32im_core   Spec rev: 0.2                                              ║
╠══════════╦════════════╦════════════╦═══════════╦══════════╦═══════════╦═══════╣
║ REQ-ID   ║ rtl_traced ║ sva_traced ║ tc_traced ║ sim_pass ║ mut_score ║ s/o   ║
╠══════════╬════════════╬════════════╬═══════════╬══════════╬═══════════╬═══════╣
║ REQ-001  ║     ✓      ║     ✓      ║     ✓     ║    ✓     ║  92%  ✓  ║  [ ]  ║
║ REQ-002  ║     ✓      ║     ✓      ║     ✓     ║    ✓     ║  84%  ⚠  ║ LOCK  ║
║ REQ-003  ║     ✓      ║     ✗      ║     ✓     ║    ✓     ║  88%  ✓  ║ LOCK  ║
║ REQ-004  ║     ✗      ║     ✗      ║     ✗     ║    ✗     ║   N/A    ║ LOCK  ║
╠══════════╩════════════╩════════════╩═══════════╩══════════╩═══════════╩═══════╣
║ Legend: ✓=pass  ✗=fail  ⚠=below 85%  LOCK=không đủ điều kiện sign-off       ║
╚════════════════════════════════════════════════════════════════════════════════╝
  Eligible for sign-off: X / Y REQ-IDs
```

**5.3 Sign-off loop — chỉ cho REQ-ID eligible:**

Với mỗi REQ-ID eligible (chưa signed-off):
```
─────────────────────────────────────────────────
REQ-001 | "RV32I base integer instruction set"
  rtl_traced: ✓  (rv32im_decoder.sv, rv32im_alu.sv)
  sva_traced: ✓  (a_req001_rv32i_decode confirmed)
  tc_traced:  ✓  (TC-002 rv32i_alu_ops)
  sim_pass:   ✓
  mut_score:  92% (46/50 killed)
─────────────────────────────────────────────────
Ký sign-off REQ-001? (yes / no / skip-all-remaining):
```

- `yes` → `signed_off: true`, `sign_off_note: ""`
- `no` → hỏi thêm: _"Lý do (optional, Enter để bỏ qua):"_ → `signed_off: false`, ghi note
- `skip-all-remaining` → bỏ qua tất cả REQ-ID còn lại trong loop, status giữ nguyên `pending`

**5.4 Sign-off summary:**

```
╔══ SIGN-OFF SUMMARY ════════╗
║  Signed off:  X / Y       ║
║  Pending:     Z           ║
║  LOCKED:      W           ║
╚════════════════════════════╝
```

Nếu có REQ-ID LOCKED hoặc pending, liệt kê và giải thích lý do cụ thể.

Hỏi: **"Ký Gate 5 (đóng phase Verification)? Các REQ-ID pending/locked vẫn có thể sign-off sau. (yes/no)"**

- `no` → dừng, không ghi gate_5_approved
- `yes` → sang Bước 6

---

## Bước 6 — Ghi output

**6.1 Update `schemas/rtm.json`** đầy đủ:

```json
{
  "metadata": {
    "phase": 5,
    "ip_name": "rv32im_core",
    "spec_revision": "0.2",
    "gate_5_approved": true,
    "approved_at": "<ISO-8601 timestamp>"
  },
  "requirements": [
    {
      "req_id": "REQ-001",
      "text": "...",
      "rtl_traced": true,
      "rtl_files": ["src/rtl/rv32im_decoder.sv", "src/rtl/rv32im_alu.sv"],
      "sva_traced": true,
      "sva_assertions": ["a_req001_rv32i_decode"],
      "tc_traced": true,
      "tc_ids": ["TC-002"],
      "sim_pass": true,
      "sim_tc_results": { "TC-002": "pass" },
      "mutation_score": 0.92,
      "mutation_detail": { "total": 50, "killed": 46, "survived": 4, "compile_fail": 0 },
      "mutation_survived_list": ["mutate -module rv32im_alu ..."],
      "signed_off": true,
      "sign_off_note": ""
    }
  ]
}
```

**6.2 Ghi `schemas/verification_report.json`:**

```json
{
  "metadata": {
    "phase": 5,
    "gate_5_approved": true,
    "approved_at": "<ISO-8601 timestamp>"
  },
  "sim_summary": {
    "total_tc": 0,
    "pass": 0,
    "fail": 0,
    "timeout": 0,
    "sva_violations": 0,
    "compile_log": "work/compile.log"
  },
  "mutation_summary": {
    "total_req_ids_tested": 0,
    "above_threshold": 0,
    "below_threshold": 0,
    "na": 0,
    "threshold": 0.85
  },
  "rtm_summary": {
    "total_req_ids": 0,
    "signed_off": 0,
    "pending": 0,
    "locked": 0
  },
  "tool_versions": {
    "vcs": "X-2025.06",
    "yosys": "0.58",
    "pdk": "GF180MCU TT 025C 1v80",
    "pdk_lib": "/tools/PDK/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0/liberty/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80.lib"
  }
}
```

Lấy timestamp bằng: `date -Iseconds`

**6.3 Thông báo cuối:**

```
✓ Gate 5 đã ký.
  schemas/rtm.json          — updated
  schemas/verification_report.json — written
  work/compile.log          — VCS compile log
  work/sim_*.log            — per-TC sim logs
  work/mut_survived_*.txt   — survived mutations per REQ-ID

Xem schemas/rtm.json để biết trạng thái từng REQ-ID.
REQ-IDs pending/locked có thể ký bổ sung bằng cách chạy lại /verification.
```

---

## Xử lý lỗi

| Tình huống | Hành động |
|---|---|
| Gate 2/3/4 chưa ký | Dừng, chỉ rõ gate nào thiếu và command cần chạy |
| VCS compile fail | Dừng, hiển thị 20 dòng lỗi đầu, gợi ý file cần fix |
| TC simulation timeout | Mark `timeout` (không phải pass), tiếp tục TC khác |
| VCS binary không tìm thấy | Dừng với hướng dẫn `module load synopsys/vcs/X-2025.06` |
| oss-cad-suite không load | Skip toàn bộ mutation, mark tất cả `mutation_score: "N/A"` |
| Yosys mutant compile fail | Skip mutation đó, không tính vào total (chỉ ghi log warning) |
| Yosys generate 0 mutations | Mark REQ-ID `mutation_score: "N/A"`, không block sign-off |
| REQ-ID không có RTL tag | `rtl_traced: false`, ô sign-off bị LOCK, highlight trong dashboard |
| `schemas/rtm.json` đã có gate_5_approved | Cảnh báo "Chạy lại sẽ ghi đè kết quả cũ", hỏi xác nhận |
| Người dùng abort giữa chừng | Ghi trạng thái hiện tại vào rtm.json (partial), để chạy lại tiếp tục được |
