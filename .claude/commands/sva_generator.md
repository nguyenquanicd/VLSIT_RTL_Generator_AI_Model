# Phase 3b · SVA Generator — /sva_generator

**Mục tiêu:** Sinh SystemVerilog Assertion cho mỗi REQ-ID, tổ chức theo file per-module,
chạy VCS compile check, sau đó thực hiện Gate 3 (Property Review) với người dùng.

**Phụ thuộc:** `/rtl_generator` phải đã chạy xong — `src/rtl/` tồn tại và synth pass.

---

## Quy tắc bất di bất dịch

1. Tối thiểu **1 assertion per REQ-ID**. REQ-ID nào không có assertion → cảnh báo rõ trong summary.
2. Mọi assertion phải bọc trong `` `ifndef SYNTHESIS `` / `` `endif ``.
3. Mọi assertion phải có dòng `// NL:` ngay trên — đây là nội dung người dùng review ở Gate 3.
4. Assertion chưa được người dùng ký `yes` ở Gate 3 **không được tính** vào RTM sign-off.
5. VCS compile phải pass trước khi mở Gate 3. Nếu compile fail → fix SVA, không mở gate.

---

## Bước 1 — Pre-flight

1. Kiểm tra `src/rtl/filelist.f` tồn tại.
   - Không tồn tại → dừng: _"RTL chưa được sinh. Chạy `/rtl_generator` trước."_
2. Kiểm tra `schemas/synth_report.json` — xác nhận synth đã pass.
   - Nếu không tồn tại hoặc status != "pass" → cảnh báo nhưng vẫn tiếp tục (user có thể muốn sinh SVA trước).
3. Đọc `schemas/structured_spec.json` → lấy danh sách `requirements` (REQ-IDs và text).
   - Nếu không tồn tại → dùng feature IDs (F01–F19) làm placeholder.
4. Đọc `spec_parser.md` — cần cho tất cả signal names và behavior spec.
5. Đọc `src/rtl/rv32im_pkg.sv` — cần enum types cho assertion.
6. Tạo `src/sva/` nếu chưa tồn tại.
7. Kiểm tra VCS:
   ```bash
   module load synopsys/vcs/X-2025.06 && vcs -ID 2>&1 | head -2
   ```
   Nếu fail → cảnh báo: _"VCS không khả dụng — sẽ bỏ qua VCS compile check."_

---

## Bước 2 — Sinh SVA pkg (macros dùng chung)

Tạo `src/sva/rv32im_sva_pkg.sv`:

```systemverilog
`default_nettype none
//==============================================================================
// Module      : rv32im_sva_pkg
// Description : Common macros và typedefs cho SVA rv32im_core
// Spec ref    : spec_parser.md §3–§18
//==============================================================================
package rv32im_sva_pkg;
  // Không có nội dung — package dùng để group import nếu cần sau này
endpackage

// Macro tắt gọn clock/disable pattern
`define RV32IM_SVA_CLK(clk, rstn) @(posedge clk) disable iff (!rstn)

`default_nettype wire
```

---

## Bước 3 — Sinh SVA per-module

Sinh assertion file cho từng stage/module. Mỗi file có cấu trúc:

```systemverilog
`default_nettype none
//==============================================================================
// Module      : rv32im_<stage>_sva
// Description : SVA cho rv32im_<stage>
// Bound to    : rv32im_<stage> via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §<N>
// REQ-IDs     : REQ-xxx, REQ-yyy
//==============================================================================
module rv32im_<stage>_sva
  import rv32im_pkg::*;
(
  input logic i_clk_core,
  input logic i_resetn_core,
  // mirror ports cần thiết cho assertion
);

`ifndef SYNTHESIS

  // === Assertions ===
  // [một assertion per block, với // NL: và // REQ-xxx]

`endif
endmodule
`default_nettype wire
```

### Danh sách file SVA cần sinh

```
src/sva/rv32im_sva_pkg.sv      — common macros
src/sva/rv32im_if_sva.sv       — IF stage (§5)
src/sva/rv32im_id_sva.sv       — ID stage (§6, §7, §8)
src/sva/rv32im_ex_sva.sv       — EX stage (§10, §11, §12, §13)
src/sva/rv32im_mem_sva.sv      — MEM stage (§14, §15)
src/sva/rv32im_csr_sva.sv      — CSR file (§16)
src/sva/rv32im_trap_sva.sv     — Trap ctrl (§17)
src/sva/rv32im_hazard_sva.sv   — Hazard ctrl (§18)
src/sva/rv32im_top_sva.sv      — Top-level / cross-module (§3, §4)
src/sva/rv32im_top_bind.sv     — bind statements
src/sva/filelist_sva.f         — filelist
```

---

## Bước 4 — Assertion tối thiểu bắt buộc

Sinh đủ các assertion sau. Với mỗi assertion, đặt đúng file per-module tương ứng.

### 4.1 IF Stage — `rv32im_if_sva.sv`

```
// NL: PC luôn align 4 byte khi valid (không có C-extension)  // REQ-Fxx
a_if_pc_aligned : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_ifid.valid |-> (o_ifid.pc[1:0] == 2'b00))
) else $error("IF: PC misaligned = %h", o_ifid.pc);

// NL: Sau reset, PC bằng PR_BOOT_ADDR  // REQ-Fxx
a_if_pc_reset_value : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  ($rose(i_resetn_core) |=> (reg_pc == PR_BOOT_ADDR))
) else $error("IF: PC reset value wrong");

// NL: I-bus request valid không phụ thuộc combinational vào ready (chống comb loop)  // REQ-Fxx
// Dùng cover để observe — không thể assert comb property này trực tiếp
a_if_ibus_no_comb_dep : cover property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_imem_req_valid && !i_imem_req_ready)
);

// NL: Khi valid=1 và ready=0, toàn bộ request payload phải giữ nguyên  // REQ-Fxx
a_if_ibus_payload_stable : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_imem_req_valid && !i_imem_req_ready) |=>
  ($stable(o_imem_req_valid) && $stable(o_imem_req_addr))
) else $error("IF: I-bus payload changed before handshake");

// NL: I-bus address bit 1:0 luôn bằng 0  // REQ-Fxx
a_if_ibus_addr_aligned : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_imem_req_valid |-> (o_imem_req_addr[1:0] == 2'b00))
) else $error("IF: I-bus addr misaligned = %h", o_imem_req_addr);
```

### 4.2 ID Stage / Regfile — `rv32im_id_sva.sv`

```
// NL: Thanh ghi x0 luôn đọc ra 0, kể cả khi có write cùng lúc  // REQ-Fxx
a_id_x0_hardwired : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (i_rf_rs1_addr == 5'b0 |-> i_rf_rs1_data == '0)
) else $error("ID: x0 not zero");

// NL: rs1_used=0 thì không bao giờ generate load-use stall vì rs1  // REQ-Fxx
a_id_unused_rs1_no_stall : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (!o_id_rs1_used |-> !$isunknown(o_id_rs1_addr))
);
```

### 4.3 EX Stage — `rv32im_ex_sva.sv`

```
// NL: Địa chỉ branch/jump target phải align 4 (bit 1:0 = 0) khi taken  // REQ-Fxx
a_ex_redirect_aligned : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_redirect_ex_valid |-> (o_redirect_ex_pc[1:0] == 2'b00))
) else $error("EX: Branch target misaligned = %h", o_redirect_ex_pc);

// NL: Khi PR_FWD_EN=0, forward select phải luôn là FWD_NONE  // REQ-Fxx
generate
  if (!PR_FWD_EN) begin : g_no_fwd_sva
    a_ex_no_forwarding : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (i_fwd_a_sel == FWD_NONE && i_fwd_b_sel == FWD_NONE)
    ) else $error("EX: Forwarding active when PR_FWD_EN=0");
  end
endgenerate

// NL: MULDIV o_ex_busy phải về 0 trong hữu hạn cycle sau flush  // REQ-Fxx
a_ex_muldiv_flush : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (i_flush |=> !o_ex_busy)
) else $error("EX: MULDIV still busy after flush");
```

### 4.4 MEM Stage / D-bus — `rv32im_mem_sva.sv`

```
// NL: D-bus payload ổn định khi valid=1, ready=0  // REQ-Fxx
a_mem_dbus_payload_stable : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_dmem_req_valid && !i_dmem_req_ready) |=>
  ($stable(o_dmem_req_valid) && $stable(o_dmem_req_addr) &&
   $stable(o_dmem_req_we)   && $stable(o_dmem_req_be))
) else $error("MEM: D-bus payload changed before handshake");

// NL: D-bus address word-aligned (bit 1:0 = 0)  // REQ-Fxx
a_mem_dbus_addr_aligned : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_dmem_req_valid |-> (o_dmem_req_addr[1:0] == 2'b00))
) else $error("MEM: D-bus addr misaligned = %h", o_dmem_req_addr);
```

### 4.5 CSR File — `rv32im_csr_sva.sv`

```
// NL: mstatus.MIE chỉ thay đổi khi có trap hoặc MRET  // REQ-Fxx
a_csr_mie_stable : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (!i_trap_valid && !i_mret_valid) |=>
  ($stable(o_mstatus_mie))
) else $error("CSR: mstatus.MIE changed without trap/mret");

// NL: mcycle tăng mỗi clock khi PR_COUNTER_EN=1  // REQ-Fxx
generate
  if (PR_COUNTER_EN) begin : g_counter_sva
    a_csr_mcycle_increment : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      1'b1 |=> ($past(reg_mcycle) + 64'd1 == reg_mcycle)
    ) else $error("CSR: mcycle did not increment");
  end
endgenerate
```

### 4.6 Trap Ctrl — `rv32im_trap_sva.sv`

```
// NL: Trap redirect PC không bao giờ X  // REQ-Fxx
a_trap_redirect_no_x : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_redirect_mem_valid |-> !$isunknown(o_redirect_mem_pc))
) else $error("TRAP: redirect PC has X");

// NL: Chỉ một trong hai redirect (EX hoặc MEM) active mỗi cycle  // REQ-Fxx
// (đây là safety property — MEM redirect có ưu tiên cao hơn nhưng cả hai không nên cùng lúc)
a_trap_single_redirect : cover property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_redirect_mem_valid)
);
```

### 4.7 Hazard Ctrl — `rv32im_hazard_sva.sv`

```
// NL: Khi stall IF, PC không được thay đổi  // REQ-Fxx
a_hz_stall_if_pc_stable : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  (o_stall_if |=> $stable(reg_pc))
) else $error("HZ: PC changed during IF stall");

// NL: Stall và flush không được cùng active cho cùng stage  // REQ-Fxx
a_hz_no_stall_and_flush : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  !((o_stall_if && o_flush_if) ||
    (o_stall_id && o_flush_id) ||
    (o_stall_ex && o_flush_ex))
) else $error("HZ: Stall and flush same stage same cycle");
```

### 4.8 Top-level / Static — `rv32im_top_sva.sv`

```
// Static elaboration checks (dùng initial $fatal — chạy khi elaborate)
initial begin
  // NL: C3 — IRQ cần CSR  // REQ-Fxx
  if (PR_IRQ_EN && !PR_CSR_EN)
    $fatal(1, "STATIC: PR_IRQ_EN=1 requires PR_CSR_EN=1 (C3)");
  // NL: C4 — Vectored mode cần CSR  // REQ-Fxx
  if (PR_MTVEC_VEC_EN && !PR_CSR_EN)
    $fatal(1, "STATIC: PR_MTVEC_VEC_EN=1 requires PR_CSR_EN=1 (C4)");
  // NL: C5 — Counter cần CSR  // REQ-Fxx
  if (PR_COUNTER_EN && !PR_CSR_EN)
    $fatal(1, "STATIC: PR_COUNTER_EN=1 requires PR_CSR_EN=1 (C5)");
  // NL: C1 — Boot address align 4  // REQ-Fxx
  if (PR_BOOT_ADDR[1:0] != 2'b00)
    $fatal(1, "STATIC: PR_BOOT_ADDR not aligned to 4 (C1)");
  // NL: C2 — mtvec reset align 4  // REQ-Fxx
  if (PR_MTVEC_RESET[1:0] != 2'b00)
    $fatal(1, "STATIC: PR_MTVEC_RESET not aligned to 4 (C2)");
end

// NL: Reset value của toàn bộ pipeline valid = 0 sau reset (không có garbage in-flight)
a_top_pipeline_clear_on_reset : assert property (
  `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
  ($rose(i_resetn_core) |=>
    (!u_if_stage.o_ifid.valid &&
     !u_id_stage.o_idex.valid &&
     !u_ex_stage.o_exmem.valid))
) else $error("TOP: Pipeline not cleared after reset");
```

### 4.9 Assertions từ REQ-IDs trong structured_spec.json

Sau khi sinh các assertion bắt buộc ở 4.1–4.8, đọc `schemas/structured_spec.json` và với **mỗi REQ-ID chưa có assertion**, sinh thêm assertion phù hợp với nội dung `text` của requirement đó.

Quy tắc:
- Đọc `text` của requirement → hiểu behavior → sinh property phù hợp
- Nếu requirement là timing/interface → dùng `assert property`
- Nếu requirement là configuration constraint → dùng `initial $fatal`
- Nếu requirement khó formalize (ví dụ "hành vi khi X phụ thuộc implementation") → sinh `cover property` để observe thay vì assert
- Gán `// REQ-xxx` chính xác theo ID của requirement đó

---

## Bước 5 — Sinh bind file

Tạo `src/sva/rv32im_top_bind.sv`:

```systemverilog
`default_nettype none
// Bind SVA modules vào DUT — chỉ active khi `ifndef SYNTHESIS
`ifndef SYNTHESIS

bind rv32im_if_stage rv32im_if_sva #(
  .PR_BOOT_ADDR (PR_BOOT_ADDR),
  .PR_XLEN      (32)
) u_if_sva (
  .i_clk_core        (i_clk_core),
  .i_resetn_core      (i_resetn_core),
  .o_imem_req_valid   (o_imem_req_valid),
  .i_imem_req_ready   (i_imem_req_ready),
  .o_imem_req_addr    (o_imem_req_addr),
  .o_ifid             (o_ifid),
  .reg_pc             (reg_pc)
);

// Thêm bind cho các stage khác tương tự...
// rv32im_id_stage, rv32im_ex_stage, rv32im_mem_stage,
// rv32im_csr_file, rv32im_trap_ctrl, rv32im_hazard_ctrl

bind rv32im_core rv32im_top_sva #(
  .PR_BOOT_ADDR     (PR_BOOT_ADDR),
  .PR_IRQ_EN        (PR_IRQ_EN),
  .PR_CSR_EN        (PR_CSR_EN),
  .PR_COUNTER_EN    (PR_COUNTER_EN),
  .PR_MTVEC_VEC_EN  (PR_MTVEC_VEC_EN),
  .PR_MTVEC_RESET   (PR_MTVEC_RESET),
  .PR_FWD_EN        (PR_FWD_EN)
) u_top_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core  (i_resetn_core)
);

`endif
`default_nettype wire
```

**Lưu ý khi sinh bind file:** Port list của mỗi SVA module phải khớp chính xác với signal names trong RTL đã sinh ở `/rtl_generator`. Đọc lại các file `.sv` trong `src/rtl/` để lấy signal names chính xác trước khi viết bind.

---

## Bước 6 — Sinh filelist_sva.f

Tạo `src/sva/filelist_sva.f`:
```
src/sva/rv32im_sva_pkg.sv
src/sva/rv32im_if_sva.sv
src/sva/rv32im_id_sva.sv
src/sva/rv32im_ex_sva.sv
src/sva/rv32im_mem_sva.sv
src/sva/rv32im_csr_sva.sv
src/sva/rv32im_trap_sva.sv
src/sva/rv32im_hazard_sva.sv
src/sva/rv32im_top_sva.sv
src/sva/rv32im_top_bind.sv
```

---

## Bước 7 — VCS Compile Check

```bash
module load synopsys/vcs/X-2025.06

vcs -full64 -sverilog \
    -f src/rtl/filelist.f \
    -f src/sva/filelist_sva.f \
    -assert svaext_bind \
    -assert enable_diag \
    +define+SIMULATION \
    -o /tmp/rv32im_sva_check \
    2>&1 | tee src/sva/vcs_compile.log
```

Kiểm tra log:
- **Pass:** Không có `Error` (case-sensitive). Warning có thể acceptable nếu không liên quan đến SVA.
- **Fail:** Có `Error` → phân tích từng lỗi, fix SVA file tương ứng, chạy lại.

Lỗi thường gặp và cách fix:
| Lỗi | Nguyên nhân | Fix |
|---|---|---|
| `undeclared symbol` trong SVA | Signal name sai so với RTL | Đọc lại RTL file, dùng tên đúng |
| `width mismatch` | Port width trong bind sai | Kiểm tra port declaration trong RTL |
| `property not clocked` | Thiếu clock event | Thêm `@(posedge i_clk_core)` |
| `initial in module` | `initial $fatal` trong synthesizable context | Xác nhận đã bọc trong `` `ifndef SYNTHESIS `` |

---

## Bước 8 — Gate 3: Property Review

Sau khi VCS compile pass, thực hiện Property Review với người dùng.

Xây dựng danh sách tất cả assertion đã sinh (lấy từ các file SVA). Với **từng assertion**, hiển thị:

```
════════════════════════════════════════════════════════
[REQ-001] a_if_pc_aligned                   (rv32im_if_sva.sv:32)
────────────────────────────────────────────────────────
NL: "PC luôn align 4 byte khi valid — bit 1:0 phải bằng 0"

SVA:
  assert property (
    @(posedge i_clk_core) disable iff (!i_resetn_core)
    (o_ifid.valid |-> (o_ifid.pc[1:0] == 2'b00))
  ) else $error("IF: PC misaligned = %h", o_ifid.pc);

Xác nhận? [yes / no / edit]:
════════════════════════════════════════════════════════
```

**Xử lý response:**
- `yes` → ghi vào RTM: `{req_id, assertion_label, confirmed: true, nl_description: "..."}`
- `no` → ghi vào RTM: `{req_id, assertion_label, confirmed: false, status: "skipped"}`. Comment out assertion trong file SVA (dùng `/* */`).
- `edit` → hỏi: _"Nhập NL description mới (Enter để giữ nguyên):"_ và _"Sửa assertion body (paste text mới, Enter 2 lần để kết thúc):"_ → cập nhật file SVA, hiển thị lại để confirm.

Sau khi review hết tất cả, hiển thị summary:

```
╔══ GATE 3 · PROPERTY REVIEW SUMMARY ═════════════════╗
║  Tổng assertion:     N                              ║
║  ✓ Confirmed:        X  (X REQ-IDs covered)         ║
║  ✗ Skipped:          Y                              ║
║  ⚠ REQ-IDs không có assertion: Z (liệt kê IDs)     ║
╠══ VCS Compile ═══════════════════════════════════════╣
║  ✓ Pass                                             ║
╚══════════════════════════════════════════════════════╝
```

Nếu có REQ-IDs không có assertion → hỏi: _"Có muốn sinh thêm assertion cho các REQ-IDs còn thiếu không? (yes/no)"_
- `yes` → quay lại Bước 4.9, sinh assertion cho các REQ-IDs thiếu, compile lại, review lại.
- `no` → ghi nhận vào RTM là `no_assertion`.

Hỏi: **"Ký Gate 3? (yes/no)"**

- `no` → Cho phép tiếp tục chỉnh sửa (quay bất kỳ bước nào).
- `yes` → Ghi `schemas/rtm.json`, đánh dấu `gate_3_approved: true`.

---

## Bước 9 — Cập nhật RTM

Ghi/cập nhật `schemas/rtm.json`:

```json
{
  "metadata": {
    "ip_name": "rv32im_core",
    "gate_3_approved": true,
    "approved_at": "<timestamp>",
    "vcs_compile": "pass"
  },
  "assertions": [
    {
      "req_id": "REQ-001",
      "assertion_label": "a_if_pc_aligned",
      "file": "src/sva/rv32im_if_sva.sv",
      "line": 32,
      "nl_description": "PC luôn align 4 byte khi valid",
      "confirmed": true,
      "status": "active"
    }
  ],
  "req_id_coverage": {
    "total": N,
    "covered": X,
    "skipped": Y,
    "no_assertion": Z
  }
}
```

---

## Bước 10 — Báo cáo tổng kết

```
╔══ SVA GENERATOR REPORT ══════════════════════════════╗
║  SVA files sinh: 10 files                           ║
║  Assertions tổng: N                                 ║
║  ✓ Confirmed (Gate 3): X                            ║
║  REQ-ID coverage: X/N                               ║
║  VCS compile: ✓ pass                               ║
║  Gate 3: ✓ Signed                                   ║
╠══ Files tạo ra ══════════════════════════════════════╣
║  src/sva/rv32im_*.sv  (10 files)                    ║
║  src/sva/filelist_sva.f                             ║
║  src/sva/vcs_compile.log                            ║
║  schemas/rtm.json                                   ║
╠══ Bước tiếp theo ════════════════════════════════════╣
║  Chạy /tb_generator để sinh testbench (Gate 4)      ║
╚══════════════════════════════════════════════════════╝
```

---

## Xử lý lỗi

| Tình huống | Hành động |
|---|---|
| `src/rtl/` chưa có | Dừng, yêu cầu `/rtl_generator` |
| VCS không khả dụng | Cảnh báo, bỏ qua compile check, vẫn thực hiện Gate 3 nhưng ghi note trong RTM |
| Bind port mismatch với RTL | Đọc RTL file để lấy signal name chính xác, sửa bind |
| REQ-ID trong spec quá mơ hồ để formalize | Sinh `cover property` thay vì assert, ghi nhận trong RTM `type: "coverage_only"` |
| `schemas/rtm.json` đã tồn tại | Merge assertion mới vào, không overwrite toàn bộ |
