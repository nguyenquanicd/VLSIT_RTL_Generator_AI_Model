# Phase 3a · RTL Generator — /rtl_generator

**Mục tiêu:** Sinh 18 module SystemVerilog-2012 cho `rv32im_core`, tag REQ-ID vào từng block,
lint từng module ngay sau khi sinh, rồi chạy synthesis gate với GF180MCU.

**Không làm trong command này:** sinh SVA (dùng `/sva_generator`), sinh testbench, chạy simulation.

---

## Quy tắc bất di bất dịch

1. Sinh xong một module → lint ngay → lint pass → mới sang module tiếp theo.
2. Synth fail → phân tích lỗi, sửa RTL, chạy lại. Không báo "done" khi synth chưa pass.
3. Mọi file RTL phải có `` `default_nettype none `` ở dòng đầu và `` `default_nettype wire `` ở dòng cuối.
4. Không tự quyết định logic không có trong spec. Nếu spec mơ hồ → dừng, hỏi người dùng.
5. Gate 3 mở sau `/sva_generator`, không phải ở đây.

---

## Bước 1 — Pre-flight

Thực hiện theo thứ tự, dừng ngay nếu bất kỳ bước nào fail:

1. Đọc `schemas/final_config.json` → trích toàn bộ `parameters` (values đã xác nhận ở Gate 2).
   - Nếu `gate_2_approved != true` → dừng: _"Gate 2 chưa ký. Chạy `/config_ui` trước."_
2. Đọc `schemas/structured_spec.json` → trích danh sách `requirements` (REQ-IDs và text).
   - Nếu không tồn tại → dùng feature IDs (F01–F19) làm placeholder, ghi nhận warning.
3. Đọc `spec_parser.md` toàn bộ — đây là nguồn spec chính cho mọi module.
4. Đọc `rtl_rule.md` — enforce trong suốt quá trình sinh.
5. Tạo `src/rtl/` nếu chưa tồn tại.
6. Kiểm tra `module load oss-cad-suite` khả dụng:
   ```bash
   module load oss-cad-suite && verilator --version
   ```
   Nếu fail → dừng: _"oss-cad-suite không load được. Kiểm tra môi trường module."_

Tóm tắt pre-flight trước khi bắt đầu sinh:
```
Pre-flight OK:
  Gate 2: approved
  Parameters: 15 loaded
  REQ-IDs: N loaded (hoặc WARNING: dùng feature IDs)
  Lint tool: Verilator X.XXX
  Output: src/rtl/
```

---

## Bước 2 — Sinh module theo thứ tự compile

Sinh 18 module theo đúng thứ tự dưới đây. Với **mỗi module**:

### Quy trình per-module

**2a. Đọc spec section tương ứng** trong `spec_parser.md`:

| Module | Spec section |
|---|---|
| `rv32im_pkg` | §4.2 (enum) + §4.3 (struct typedef) |
| `rv32im_alu` | §11 |
| `rv32im_branch_unit` | §12 |
| `rv32im_imm_gen` | §8 |
| `rv32im_decoder` | §7 |
| `rv32im_lsu` | §15 |
| `rv32im_regfile` | §9 |
| `rv32im_mult` | §13.4 |
| `rv32im_div` | §13.5 |
| `rv32im_muldiv` | §13 |
| `rv32im_hazard_ctrl` | §18 |
| `rv32im_if_stage` | §5 |
| `rv32im_id_stage` | §6 |
| `rv32im_ex_stage` | §10 |
| `rv32im_csr_file` | §16 |
| `rv32im_trap_ctrl` | §17 |
| `rv32im_mem_stage` | §14 |
| `rv32im_core` | §3 + §4.1 |

**2b. Sinh file SystemVerilog** vào `src/rtl/<module_name>.sv`.

Template bắt buộc cho mọi file:
```systemverilog
`default_nettype none
//==============================================================================
// Module      : <module_name>
// Description : <mô tả 1 dòng từ spec>
// Parent      : <parent module>
// Spec ref    : spec_parser.md §<số>
// REQ-IDs     : REQ-xxx, REQ-yyy  (hoặc F01, F02 nếu chưa có structured_spec)
//==============================================================================
module <module_name>
  import rv32im_pkg::*;
#(
  // PR_* parameters theo spec §2.2 — chỉ list những cái module này dùng
) (
  // ---- Clock & Reset ----
  // ---- <nhóm port> ---- // REQ-xxx
  ...
);
  // localparam LP_*
  // khai báo reg_* rồi w_*
  // always_comb (với default assignment đầu tiên)
  // always_ff
  // instance submodule
  `ifndef SYNTHESIS
  // assertions (placeholder — sẽ được fill bởi /sva_generator)
  `endif
endmodule
`default_nettype wire
```

**Quy tắc tagging REQ-ID trong RTL:**
- Header comment: `// REQ-IDs: REQ-xxx, REQ-yyy`
- Cuối mỗi `always_comb` / `always_ff` block liên quan đến một requirement: `// REQ-xxx`
- Port group: `// ---- <tên nhóm> ---- // REQ-xxx` nếu port trực tiếp implement requirement đó

**Parameter substitution:** Lấy giá trị từ `final_config.json`. Ví dụ nếu `PR_M_EXT_EN = 0` thì trong `rv32im_decoder`, nhánh RV32M decode ra `o_illegal = 1`.

**2c. Chạy lint ngay sau khi sinh:**
```bash
module load oss-cad-suite
verilator --lint-only --sv -Wall \
  +incdir+src/rtl \
  src/rtl/rv32im_pkg.sv \
  src/rtl/<module_name>.sv \
  2>&1
```
_(Với pkg cần include trước. Nếu module phụ thuộc module khác đã sinh, add vào list.)_

- **Lint pass (0 warning/error)** → thông báo `✓ <module_name> lint OK` → tiếp tục module tiếp.
- **Lint fail** → hiển thị lỗi, phân tích nguyên nhân, sửa file, lint lại. Không sang module tiếp cho đến khi pass.

**Loại warning phải fix (không dùng `-Wno-` để suppress):**
- `UNOPTFLAT` — latch hoặc combinational loop
- `MULTIDRIVEN` — multi-driven net
- `WIDTH` — width mismatch
- `UNUSED` — signal khai báo nhưng không dùng (gợi ý xem lại spec)
- `LATCH` — latch không chủ ý

### Thứ tự 18 module

```
[1/18]  rv32im_pkg          → src/rtl/rv32im_pkg.sv
[2/18]  rv32im_alu          → src/rtl/rv32im_alu.sv
[3/18]  rv32im_branch_unit  → src/rtl/rv32im_branch_unit.sv
[4/18]  rv32im_imm_gen      → src/rtl/rv32im_imm_gen.sv
[5/18]  rv32im_decoder      → src/rtl/rv32im_decoder.sv
[6/18]  rv32im_lsu          → src/rtl/rv32im_lsu.sv
[7/18]  rv32im_regfile      → src/rtl/rv32im_regfile.sv
[8/18]  rv32im_mult         → src/rtl/rv32im_mult.sv
[9/18]  rv32im_div          → src/rtl/rv32im_div.sv
[10/18] rv32im_muldiv       → src/rtl/rv32im_muldiv.sv
[11/18] rv32im_hazard_ctrl  → src/rtl/rv32im_hazard_ctrl.sv
[12/18] rv32im_if_stage     → src/rtl/rv32im_if_stage.sv
[13/18] rv32im_id_stage     → src/rtl/rv32im_id_stage.sv
[14/18] rv32im_ex_stage     → src/rtl/rv32im_ex_stage.sv
[15/18] rv32im_csr_file     → src/rtl/rv32im_csr_file.sv
[16/18] rv32im_trap_ctrl    → src/rtl/rv32im_trap_ctrl.sv
[17/18] rv32im_mem_stage    → src/rtl/rv32im_mem_stage.sv
[18/18] rv32im_core         → src/rtl/rv32im_core.sv
```

---

## Bước 3 — Sinh filelist.f

Sau khi tất cả 18 module đã sinh và lint sạch, tạo `src/rtl/filelist.f`:

```
src/rtl/rv32im_pkg.sv
src/rtl/rv32im_alu.sv
src/rtl/rv32im_branch_unit.sv
src/rtl/rv32im_imm_gen.sv
src/rtl/rv32im_decoder.sv
src/rtl/rv32im_lsu.sv
src/rtl/rv32im_regfile.sv
src/rtl/rv32im_mult.sv
src/rtl/rv32im_div.sv
src/rtl/rv32im_muldiv.sv
src/rtl/rv32im_hazard_ctrl.sv
src/rtl/rv32im_if_stage.sv
src/rtl/rv32im_id_stage.sv
src/rtl/rv32im_ex_stage.sv
src/rtl/rv32im_csr_file.sv
src/rtl/rv32im_trap_ctrl.sv
src/rtl/rv32im_mem_stage.sv
src/rtl/rv32im_core.sv
```

Chạy lint full design một lần nữa để verify không có cross-module issue:
```bash
module load oss-cad-suite
verilator --lint-only --sv -Wall --top-module rv32im_core -f src/rtl/filelist.f 2>&1
```

---

## Bước 4 — Synthesis Gate (Gate 3a)

### 4a. Chuẩn bị Yosys synthesis script

Tạo `src/rtl/synth_gf180_tt.ys`:
```tcl
# Synthesis script — GF180MCU TT 25C 1.8V
set GF180_TT "/tools/PDK/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0/liberty/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80.lib"

read_verilog -sv -f src/rtl/filelist.f
hierarchy -check -top rv32im_core
proc
opt -full
memory
opt -full
techmap
opt -fast
dfflibmap -liberty $GF180_TT
abc -liberty $GF180_TT -D 5000
opt_clean -purge
stat -liberty $GF180_TT
write_json src/rtl/synth_gf180_tt.json
```

Tạo `src/rtl/synth_gf180_ss.ys` (SS corner — worst case):
```tcl
set GF180_SS "/tools/PDK/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0/liberty/gf180mcu_fd_sc_mcu7t5v0__ss_125C_1v62.lib"

read_verilog -sv -f src/rtl/filelist.f
hierarchy -check -top rv32im_core
proc
opt -full
memory
opt -full
techmap
opt -fast
dfflibmap -liberty $GF180_SS
abc -liberty $GF180_SS -D 5000
opt_clean -purge
stat -liberty $GF180_SS
write_json src/rtl/synth_gf180_ss.json
```

### 4b. Chạy synthesis

```bash
module load oss-cad-suite

echo "=== Synthesis TT corner ==="
yosys -l src/rtl/synth_tt.log src/rtl/synth_gf180_tt.ys

echo "=== Synthesis SS corner ==="
yosys -l src/rtl/synth_ss.log src/rtl/synth_gf180_ss.ys
```

### 4c. Kiểm tra kết quả

Kết quả **PASS** khi:
- Không có `ERROR:` trong log
- `hierarchy -check` không báo missing module
- `stat` xuất ra số cell count > 0

Kết quả **FAIL** khi:
- Có `ERROR:` → phân tích: thường là construct không synthesizable (`initial`, `#delay`, `$display` trong RTL)
- Fix ngay trong file RTL tương ứng, lint lại module đó, chạy lại toàn bộ synth

### 4d. Ghi synth_report.json

Sau khi cả hai corner pass, trích số liệu từ log và ghi `schemas/synth_report.json`:

```json
{
  "tool": "Yosys 0.58",
  "pdk": "GF180MCU",
  "top_module": "rv32im_core",
  "corners": {
    "tt_025C_1v80": {
      "status": "pass",
      "cell_count": <trích từ log>,
      "area_estimate_um2": null,
      "log": "src/rtl/synth_tt.log"
    },
    "ss_125C_1v62": {
      "status": "pass",
      "cell_count": <trích từ log>,
      "area_estimate_um2": null,
      "log": "src/rtl/synth_ss.log"
    }
  },
  "req_ids_tagged": <đếm số REQ-ID comments trong src/rtl/>,
  "generated_at": "<timestamp>"
}
```

---

## Bước 5 — Báo cáo tổng kết

```
╔══ RTL GENERATOR REPORT ══════════════════════════════╗
║  Modules sinh: 18/18                                ║
║  Lint status:  ✓ 18/18 pass (0 warning)             ║
║  Synth TT:     ✓ pass — XXX cells                   ║
║  Synth SS:     ✓ pass — XXX cells                   ║
║  REQ-IDs tagged: N tags trong 18 files              ║
╠══ Files tạo ra ══════════════════════════════════════╣
║  src/rtl/rv32im_pkg.sv  ... (18 files)              ║
║  src/rtl/filelist.f                                 ║
║  src/rtl/synth_gf180_tt.ys                          ║
║  src/rtl/synth_gf180_ss.ys                          ║
║  schemas/synth_report.json                          ║
╠══ Bước tiếp theo ════════════════════════════════════╣
║  Chạy /sva_generator để sinh SVA và mở Gate 3       ║
╚══════════════════════════════════════════════════════╝
```

---

## Xử lý lỗi

| Tình huống | Hành động |
|---|---|
| `final_config.json` không tồn tại | Dừng, yêu cầu chạy `/config_ui` |
| Gate 2 chưa ký | Dừng, yêu cầu ký Gate 2 |
| Spec section không rõ ràng | Dừng, hỏi người dùng — không tự đoán |
| Lint warning `UNUSED` | Xem lại spec, nếu signal thực sự không dùng thì xoá, không dùng `-Wno-UNUSED` |
| Synth: missing cell từ GF180 | Kiểm tra construct có synthesizable không (`initial`, `$`-tasks, v.v.) |
| `src/rtl/<module>.sv` đã tồn tại | Hỏi "Ghi đè?" trước khi overwrite |
