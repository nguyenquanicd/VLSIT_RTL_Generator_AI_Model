# Phase 4 · Testbench — /tb_generator

**Mục tiêu:** Sinh testbench plain SystemVerilog cho `rv32im_core`, lấy TC-ID ánh xạ sang
REQ-ID, cho người dùng chọn TC nào đưa vào, cảnh báo REQ-ID thiếu coverage,
và xuất `schemas/selected_testplan.json` sau khi người dùng ký Gate 4.

**Không dùng UVM.** Testbench thuần SystemVerilog-2012.

---

## Quy tắc bắt buộc

1. Mọi test block phải tag `// TC-ID | REQ-ID` ở dòng đầu.
2. REQ-ID không có TC nào cover → cảnh báo rõ trước Gate 4, không được im lặng.
3. Gate 4 chỉ mở sau khi: (a) người dùng xác nhận Test Plan, (b) VCS compile check pass.
4. TC conditional theo parameter (TC-014/015 cần `PR_M_EXT_EN=1`, v.v.) phải đọc từ `schemas/final_config.json`.

---

## Bước 1 — Pre-flight

Đọc theo thứ tự:
1. `schemas/final_config.json` → lấy parameter values (PR_M_EXT_EN, PR_CSR_EN, PR_IRQ_EN, v.v.)
2. `schemas/structured_spec.json` → lấy danh sách REQ-IDs
3. `src/rtl/filelist.f` → xác nhận RTL đã sinh (nếu thiếu → dừng: "Chạy /rtl_generator trước")
4. `schemas/rtm.json` → lấy danh sách SVA đã confirmed (nếu có, từ Phase 3)

Tạo thư mục `src/tb/` và `src/tb/tests/` nếu chưa có.

---

## Bước 2 — Hiển thị Test Plan UI

Hiển thị bảng 25 TC đề xuất. TC có dấu `[COND]` chỉ generate khi parameter tương ứng bật.

```
╔══ PHASE 4 · TEST PLAN UI ════════════════════════════════════════════════╗
║  Chọn TC nào đưa vào testbench. Gõ ID cách nhau dấu phẩy, hoặc 'all'. ║
╠══════╦══════════════════════════════════╦══════════════════╦════════════╣
║ TC   ║ Tên                             ║ REQ-IDs cover    ║ Ghi chú   ║
╠══════╬══════════════════════════════════╬══════════════════╬════════════╣
║ TC-001 ║ reset_boot_addr               ║ REQ-001          ║           ║
║ TC-002 ║ rv32i_alu_ops                 ║ REQ-002,003      ║           ║
║ TC-003 ║ rv32i_lui_auipc               ║ REQ-004          ║           ║
║ TC-004 ║ load_instructions             ║ REQ-005,010      ║           ║
║ TC-005 ║ store_instructions            ║ REQ-006,010      ║           ║
║ TC-006 ║ branch_not_taken              ║ REQ-007,008      ║           ║
║ TC-007 ║ branch_taken_penalty          ║ REQ-007,008      ║ 2cy flush ║
║ TC-008 ║ jal_jalr                      ║ REQ-009          ║           ║
║ TC-009 ║ fence_i_refetch               ║ REQ-004 (F04)    ║           ║
║ TC-010 ║ load_use_hazard               ║ REQ-007 (F07)    ║ 1cy stall ║
║ TC-011 ║ ex_forwarding                 ║ REQ-006 (F06)    ║ EX→EX     ║
║ TC-012 ║ mem_forwarding                ║ REQ-006 (F06)    ║ MEM→EX    ║
║ TC-013 ║ x0_hardwired_zero             ║ REQ-009 (F09)    ║           ║
║ TC-014 ║ rv32m_multiply                ║ REQ-002 (F02)    ║ [COND:M]  ║
║ TC-015 ║ rv32m_divide_special          ║ REQ-002 (F02)    ║ [COND:M]  ║
║ TC-016 ║ csr_read_write                ║ REQ-003 (F03)    ║ [COND:CSR]║
║ TC-017 ║ ecall_ebreak_exception        ║ REQ-013 (F13)    ║           ║
║ TC-018 ║ illegal_instruction           ║ REQ-013 (F13)    ║           ║
║ TC-019 ║ misaligned_access             ║ REQ-013 (F13)    ║           ║
║ TC-020 ║ machine_interrupt             ║ REQ-014 (F14)    ║ [COND:IRQ]║
║ TC-021 ║ mret_behavior                 ║ REQ-015 (F15)    ║ [COND:CSR]║
║ TC-022 ║ mcycle_minstret_counter       ║ REQ-016 (F16)    ║ [COND:CTR]║
║ TC-023 ║ bus_protocol_handshake        ║ REQ-010 (F10)    ║           ║
║ TC-024 ║ precise_exception_commit      ║ REQ-012 (F12)    ║           ║
║ TC-025 ║ mtvec_vectored_mode           ║ REQ-019 (F19)    ║ [COND:VEC]║
╚══════╩══════════════════════════════════╩══════════════════╩════════════╝
  [COND:M]   = chỉ sinh khi PR_M_EXT_EN=1
  [COND:CSR] = chỉ sinh khi PR_CSR_EN=1
  [COND:IRQ] = chỉ sinh khi PR_IRQ_EN=1
  [COND:CTR] = chỉ sinh khi PR_COUNTER_EN=1
  [COND:VEC] = chỉ sinh khi PR_MTVEC_VEC_EN=1
```

Sau khi hiển thị, hỏi:
> **"Bạn muốn chọn TC nào? Gõ ID (ví dụ: TC-001,TC-002,TC-010) hoặc 'all' để chọn tất cả hợp lệ."**

TC `[COND:X]` mà parameter tương ứng đang tắt → tự động loại ra và thông báo.

---

## Bước 3 — Kiểm tra coverage và cảnh báo

Sau khi người dùng chọn xong:
1. Tổng hợp danh sách REQ-IDs được cover bởi các TC đã chọn.
2. So sánh với danh sách REQ-IDs trong `schemas/structured_spec.json`.
3. Hiển thị rõ:

```
⚠ REQ-IDs chưa có TC cover: REQ-xxx, REQ-yyy
✓ REQ-IDs đã cover: REQ-001, REQ-002, ...
Coverage: XX / YY REQ-IDs (ZZ%)
```

4. Hỏi: **"Tiếp tục với coverage hiện tại, hay muốn thêm TC? (continue / add)"**
   - `add` → quay lại Bước 2, cho phép chọn thêm
   - `continue` → sang Bước 4

---

## Bước 4 — Sinh testbench framework

Sinh theo thứ tự sau. Sau mỗi file: chạy VCS compile check ngay.

**4.1 Memory model** `src/tb/rv32im_mem_model.sv`
- Byte-array đơn giản, 64 KB mặc định, tham số hoá size
- Valid-ready protocol theo `spec_parser.md §3.4`
- Hỗ trợ cả I-bus (read-only) và D-bus (read/write)
- Latency configurable (mặc định 1 cycle)
- `$readmemh(HEX_FILE, mem_array)` để nạp test program
- Tag: `// TC-ALL | REQ-010`

**4.2 CLINT model** `src/tb/rv32im_clint_model.sv` — chỉ sinh khi `PR_IRQ_EN=1`
- Sinh `i_irq_timer` và `i_irq_sw` theo schedule đơn giản
- Configurable bằng task: `set_timer_irq(delay_cycles)`, `set_sw_irq(delay_cycles)`
- Tag: `// TC-020 | REQ-014`

**4.3 Testbench top** `src/tb/rv32im_tb_top.sv`
- Instantiate `rv32im_core` với tất cả parameter từ `schemas/final_config.json`
- Instantiate `rv32im_mem_model` (connect I-bus + D-bus)
- Instantiate `rv32im_clint_model` (nếu `PR_IRQ_EN=1`)
- Clock: `localparam LP_CLK_PERIOD = 10; always #(LP_CLK_PERIOD/2) i_clk_core = ~i_clk_core;`
- Reset: assert `i_resetn_core=0` trong 10 cycle đầu
- Timeout: `$fatal` sau 100_000 cycle nếu test chưa xong
- `$dumpfile`/`$dumpvars` cho waveform (VCD)
- Main: gọi lần lượt các task TC đã chọn
- Tag: `// TC-ALL | REQ-ALL`

**4.4 Mỗi TC đã chọn** → sinh file `src/tb/tests/tc_XXX_<name>.sv`

Mỗi TC file phải tuân theo template sau:

```systemverilog
// TC-XXX | REQ-yyy, REQ-zzz
// Description: <mô tả một dòng>
task automatic tc_xxx_name(
  ref logic i_clk_core,
  ref logic i_resetn_core,
  // ... các ref signal cần thiết
);
  // TC-XXX | REQ-yyy — setup
  <setup code>

  // TC-XXX | REQ-yyy — stimulus
  <stimulus>

  // TC-XXX | REQ-yyy — check
  <assertions / $error checks>

  $display("[PASS] TC-XXX <name>");
endtask
```

Mỗi TC có ít nhất một `$error` hoặc `assert` để tự động phát hiện lỗi.

Chi tiết stimulus cho từng TC quan trọng:

| TC | Stimulus chính | Check |
|---|---|---|
| TC-001 | Release reset, đọc PC | `o_imem_req_addr == PR_BOOT_ADDR` |
| TC-002 | Nạp hex chứa ADDI/ADD/SUB/AND/OR... | Kiểm tra kết quả qua STORE + load lại |
| TC-006 | BEQ với rs1==rs2 (not-taken), rồi rs1≠rs2 (not-taken cũng predict) | PC tiếp theo = PC+4 |
| TC-007 | BEQ với rs1==rs2, đo PC sau 3 cycle | PC = branch_target, 2 bubble |
| TC-010 | LOAD rồi ngay ADD dùng load result | Tổng số cycle = N+2 (1 stall) |
| TC-011 | ADDI x1,x0,5; ADD x2,x1,x1 | x2 = 10 (forward từ EX) |
| TC-013 | ADDI x0,x0,99; LW x3,0(x0) | x0 vẫn = 0 |
| TC-015 | DIV x1,x1,x0 (div-by-zero) | x1 = 0xFFFFFFFF |
| TC-017 | ECALL | mcause = 11, mepc = PC của ECALL |
| TC-023 | Stall i_imem_req_ready cho vài cycle | Payload stable, no re-request |

---

## Bước 5 — Sinh filelist và compile check

Sinh `src/tb/filelist_tb.f`:
```
// RTL
-f src/rtl/filelist.f
// TB
src/tb/rv32im_mem_model.sv
src/tb/rv32im_clint_model.sv   // nếu PR_IRQ_EN=1
src/tb/rv32im_tb_top.sv
// TCs
src/tb/tests/tc_001_reset_boot_addr.sv
// ... (chỉ TC đã chọn)
```

Chạy VCS compile check:
```bash
module load synopsys/vcs/X-2025.06
vcs -sverilog -timescale=1ns/1ps \
    -f src/tb/filelist_tb.f \
    -assert svaext_bind \
    +define+SIMULATION \
    -o /dev/null 2>&1
```

Nếu compile fail → phân tích lỗi, fix file tương ứng, compile lại. Không mở Gate 4 khi còn compile error.

---

## Bước 6 — Gate 4: Test Plan Review và xác nhận

Hiển thị tổng kết:

```
╔══ GATE 4 · TEST PLAN SUMMARY ═══════════════════════════════╗
║  TC đã chọn:     XX / 25                                   ║
║  REQ covered:    YY / ZZ  (AA%)                            ║
║  REQ uncovered:  (danh sách nếu có)                        ║
║  VCS compile:    PASS                                       ║
╚═════════════════════════════════════════════════════════════╝
```

Hỏi: **"Ký Gate 4 và chốt Test Plan? (yes/no)"**
- `no` → quay về Bước 2
- `yes` → ghi `schemas/selected_testplan.json`, đánh dấu `gate_4_approved: true`

Thông báo: **"✓ Gate 4 đã ký. `schemas/selected_testplan.json` đã ghi. Phase 5 (Verification) có thể bắt đầu với `/verification`."**

---

## Schema output — `schemas/selected_testplan.json`

Cấu trúc:
```json
{
  "metadata": {
    "phase": 4,
    "gate_4_approved": true,
    "approved_at": "<timestamp>"
  },
  "test_cases": [
    {
      "tc_id": "TC-001",
      "name": "reset_boot_addr",
      "description": "...",
      "req_ids": ["REQ-001"],
      "selected": true,
      "conditional_param": null,
      "file": "src/tb/tests/tc_001_reset_boot_addr.sv",
      "compile_status": "pass"
    }
  ],
  "coverage": {
    "total_req_ids": 0,
    "covered_req_ids": [],
    "uncovered_req_ids": [],
    "coverage_pct": 0.0
  },
  "compile_check": {
    "tool": "vcs X-2025.06",
    "status": "pass",
    "error_count": 0
  }
}
```

---

## Xử lý lỗi

| Tình huống | Hành động |
|---|---|
| `src/rtl/filelist.f` không tồn tại | Dừng, yêu cầu chạy `/rtl_generator` trước |
| Parameter tắt mà user chọn TC conditional | Từ chối TC đó, giải thích, đề xuất TC thay thế |
| VCS compile fail sau nhiều lần fix | Hiển thị lỗi đầy đủ, hỏi user có muốn skip TC đó không |
| `schemas/selected_testplan.json` đã tồn tại | Cảnh báo "Ghi đè test plan cũ?" trước khi overwrite |
| REQ-ID trong TC không tồn tại trong structured_spec.json | Cảnh báo mismatch, ghi nhận nhưng vẫn tiếp tục |
