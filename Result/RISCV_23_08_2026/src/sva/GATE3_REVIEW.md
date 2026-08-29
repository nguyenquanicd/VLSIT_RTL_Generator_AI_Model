# Gate 3 · Property Review — `rv32im_core`

> ## ✅ GATE 3 ĐÃ KÝ — 2026-08-23T22:57:41+07:00
> Người dùng confirm **toàn bộ 181 property**, 0 skip, 0 edit.
> `schemas/rtm.json`: `gate_3_approved: true`, `sva_traced` bật cho 108 REQ.
>
> Ký Gate 3 xác nhận property **đúng ý định**, không xác nhận đã được **thử**.
> 83 property vẫn `vacuous` — tạo stimulus là việc của Phase 4/5.

Sinh bởi Phase 3b (`/sva_generator`). Spec rev 0.4. VCS X-2025.06: compile 0 Error, sim 0 assertion fail.

## Cách đọc

| Status | Nghĩa |
|---|---|
| `exercised` | Antecedent có thoả và property đúng |
| `vacuous` | Antecedent **chưa bao giờ** thoả → property chưa thực sự được thử |
| `cover-hit` / `cover-miss` | Cover property đã chạm / chưa chạm |
| `in-flight` | Đang trong một attempt dở khi sim kết thúc |

> ⚠ **Quan trọng:** `vacuous` chiếm phần lớn vì chương trình smoke 113 chu kỳ không có trap, interrupt, branch taken hay exception. Assertion đã bind và đã được chứng minh là fire được (fault injection), nhưng stimulus chưa với tới. Thử thật là việc của Phase 4/5 — **đừng đọc "0 fail" thành "RTL đúng"**.

## Tổng quan

- **165 assert** + **16 cover** = **181 property**
- REQ có assertion: **108/191**
- `vacuous`: 83
- `exercised`: 76
- `cover-miss`: 9
- `cover-hit`: 7
- `in-flight`: 6

## Việc của bạn

Đọc bảng dưới. **Chỉ cần báo lại dòng nào muốn sửa hoặc bỏ** — phần còn lại mặc định `confirmed`. Ví dụ: *"bỏ a_top_dmem_rsp_needs_req, sửa NL của a_if_two_cycle_fetch"*. Sau đó tôi cập nhật file SVA + `schemas/rtm.json` và ký Gate 3.


---

## `rv32im_csr_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_csr_illegal_needs_en` | 50 | REQ-132 | `exercised` | §16.3 - o_csr_illegal phai bang 0 khi khong co lenh CSR |
| 2 | `a_csr_x1_unknown_addr` | 56 | REQ-142 | `vacuous` | §16.6 X1 - dia chi ngoai bang §16.4 phai bao illegal |
| 3 | `a_csr_x2_write_ro` | 63 | REQ-143 | `vacuous` | §16.6 X2 - ghi vao CSR read-only (addr[11:10] = 11) phai bao illegal REQ-143 |
| 4 | `a_csr_read_only_access_legal` | 69 | REQ-141 | `exercised` | §16.6 - doc CSR hop le thi khong duoc bao illegal |
| 5 | `a_csr_read_old_value` | 75 | REQ-141 | `exercised` | §16.6 - o_csr_rdata luon la gia tri TRUOC khi ghi |
| 6 | `a_csr_no_read_zero` | 81 | REQ-131 | `exercised` | §16.3 - khong doc thi rdata phai bang 0, khong ro ri gia tri CSR |
| 7 | `a_csr_trap_saves_mie` | 87 | REQ-144 | `vacuous` | §16.7 - trap ha mstatus.MIE va luu gia tri cu vao MPIE |
| 8 | `a_csr_mepc_is_trap_pc` | 94 | REQ-145 | `vacuous` | §16.7 - mepc nhan PC cua chinh instruction bi trap, khong phai pc+4 REQ-145 |
| 9 | `a_csr_mepc_aligned` | 100 | REQ-140 | `exercised` | §16.4 - mepc[1:0] hardwired 0 |
| 10 | `a_csr_mret_restores_mie` | 106 | REQ-146 | `vacuous` | §16.8 - MRET khoi phuc MIE tu MPIE va dat MPIE = 1 |
| 11 | `a_csr_trap_beats_mret` | 113 | REQ-151 | `vacuous` | §16.10 - trap thang MRET khi ca hai cung chu ky |
| 12 | `a_csr_mie_stable` | 119 | REQ-133 | `in-flight` | mstatus.MIE chi doi khi co trap hoac MRET hoac lenh ghi mstatus |
| 13 | `a_csr_mie_output` | 127 | REQ-133 | `exercised` | §16.3 - o_mstatus_mie phai phan anh dung thanh ghi |
| 14 | `a_csr_mtvec_mode_direct` | 134 | REQ-135 | `exercised` | §16.5 - mtvec.MODE bi ep ve Direct khi PR_MTVEC_VEC_EN = 0 |
| 15 | `a_csr_mtvec_mode_warl` | 141 | REQ-135 | `exercised` | §16.5 - khi bat Vectored, MODE khong bao gio nhan gia tri >= 2 |
| 16 | `a_csr_mcycle_increment` | 149 | REQ-147 | `in-flight` | §16.9 - mcycle tang moi chu ky, ke ca khi stall |
| 17 | `a_csr_minstret_only_on_retire` | 157 | REQ-148 | `in-flight` | §16.9 - minstret chi tang khi co instruction retire |
| 18 | `a_csr_minstret_increment` | 165 | — | `exercised` |  |
| 19 | `a_csr_no_irq_pending` | 177 | REQ-152 | `exercised` | §16.3 - o_irq_pending da AND voi mie, nen chi bat khi co ngat that REQ-152 |
| 20 | `a_csr_mhartid_constant` | 184 | REQ-130 | `vacuous` | §16.4 - mhartid la read-only va luon bang PR_HART_ID |
| 21 | `a_csr_misa_constant` | 191 | REQ-137 | `vacuous` | §16.4 - misa doc ra gia tri co dinh MXL=1, ext I+M |
| 22 | `a_csr_mip_write_not_illegal` | 198 | REQ-138 | `vacuous` | §16.4 - ghi mip duoc chap nhan nhung khong bao illegal |
| 23 | `a_csr_mstatush_write_not_illegal` | 204 | REQ-139 | `vacuous` | §16.4 - mstatush cung vay: ghi vo tac dung nhung khong illegal |
| 24 | `c_csr_read` | 211 | REQ-131 | `cover-hit` | Quan sat da thuc su doc duoc mot CSR |
| 25 | `c_csr_write` | 215 | REQ-141 | `cover-miss` | Quan sat da thuc su ghi duoc mot CSR |

---

## `rv32im_ex_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_ex_redirect_aligned` | 42 | REQ-086 REQ-089 | `exercised` | §10.5 - dia chi redirect tu EX luon align 4. Truong hop misaligned da bi chan, khong redirect |
| 2 | `a_ex_misaligned_no_redirect` | 49 | REQ-092 | `vacuous` | §10.6 - khi target misaligned thi KHONG duoc redirect, trap se redirect o MEM |
| 3 | `a_ex_misaligned_no_mem_req` | 55 | REQ-092 | `vacuous` | §10.6 - misaligned load/store khong duoc phat request ra D-bus |
| 4 | `a_ex_load_misaligned_code` | 62 | REQ-090 | `vacuous` | §10.6 - misaligned load sinh dung EXC_LOAD_MISALIGNED |
| 5 | `a_ex_store_misaligned_code` | 69 | REQ-091 | `vacuous` | §10.6 - misaligned store sinh dung EXC_STORE_MISALIGNED |
| 6 | `a_ex_exc_no_redirect` | 76 | REQ-087 | `vacuous` | §10.5 - instruction dang co exception thi khong duoc redirect |
| 7 | `a_ex_fwd_a_exmem` | 82 | REQ-084 | `vacuous` | §10.4 - forward select phai giong het toan tu tuong ung |
| 8 | `a_ex_fwd_b_memwb` | 87 | — | `exercised` |  |
| 9 | `a_ex_store_data_uses_fwd_b` | 95 | REQ-084 | `in-flight` | §10.4 - store data dung chung duong forward voi toan tu B. Chi rang buoc cho slot hop le: voi bubble thi store_data la don't-care va co the mang X tu datapath flop khong reset (rtl_rule §4.2) |
| 10 | `a_ex_busy_only_muldiv` | 102 | REQ-093 | `exercised` | §10.7 - o_ex_busy chi bat cho instruction MULDIV hop le |
| 11 | `a_ex_busy_bubbles_mem` | 108 | REQ-093 | `vacuous` | §10.8 B1 - trong luc MULDIV chay, MEM phai nhan bubble |
| 12 | `a_ex_flush_clears` | 114 | REQ-093 | `vacuous` | §10.8 B3 - flush thang tat ca, EX/MEM bi xoa |
| 13 | `a_ex_muldiv_flush` | 120 | REQ-101 | `vacuous` | §10.8 - MULDIV phai dung han trong huu han chu ky sau flush |
| 14 | `a_ex_no_forwarding` | 127 | REQ-173 | `exercised` | Khi PR_FWD_EN = 0, forward select luon la FWD_NONE |
| 15 | `c_ex_muldiv_completes` | 134 | REQ-017 | `cover-hit` | Quan sat mot lan MULDIV chay het den khi hoan tat |
| 16 | `a_alu_add` | 158 | REQ-094 | `exercised` | §11.4 - ALU_ADD phai bang tong hai toan tu |
| 17 | `a_alu_sub` | 165 | REQ-094 | `vacuous` | §11.4 - ALU_SUB phai bang hieu hai toan tu |
| 18 | `a_alu_slt_boolean` | 172 | REQ-094 | `vacuous` | §11.4 - SLT/SLTU chi tra ve 0 hoac 1 |
| 19 | `a_alu_pass_b` | 180 | REQ-094 | `vacuous` | §11.4 - ALU_PASS_B tra thang toan tu B (dung cho LUI) |
| 20 | `a_br_eq` | 204 | REQ-095 | `exercised` | §12.3 - BEQ dung khi va chi khi hai toan tu bang nhau |
| 21 | `a_br_ne` | 211 | REQ-095 | `vacuous` | §12.3 - BNE la phu dinh cua BEQ |
| 22 | `a_br_lt_signed` | 218 | REQ-095 | `vacuous` | §12.3 - BLT dung so sanh co dau |
| 23 | `a_br_ltu_unsigned` | 225 | REQ-095 | `vacuous` | §12.3 - BLTU dung so sanh khong dau |
| 24 | `a_br_ge_is_not_lt` | 232 | REQ-095 | `vacuous` | §12.3 - BGE la phu dinh cua BLT |
| 25 | `a_md_busy_done_exclusive` | 261 | REQ-099 | `exercised` | §13.3 D3 - o_busy va o_done khong bao gio cung bat |
| 26 | `a_md_done_one_cycle` | 267 | REQ-098 | `exercised` | §13.3 D2 - o_done rong dung 1 chu ky |
| 27 | `a_md_no_restart_while_busy` | 273 | REQ-102 | `exercised` | §13.3 D6 - khong nhan i_start moi khi dang busy |
| 28 | `a_md_flush_clears` | 279 | REQ-101 | `vacuous` | §13.3 D5 - flush ha ca busy lan done ngay chu ky do |
| 29 | `a_md_div_by_zero_quotient` | 285 | REQ-108 | `vacuous` | §13.5 - chia 0 phai bit-exact: DIV/DIVU ra toan bit 1 |
| 30 | `c_md_done_seen` | 293 | REQ-017 | `cover-hit` | Quan sat da chay het mot phep MULDIV |
| 31 | `c_md_div_by_zero` | 297 | REQ-108 | `cover-miss` | Quan sat truong hop chia 0 |

---

## `rv32im_hazard_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_hz_cascade_mem_ex` | 45 | REQ-178 | `vacuous` | §18.6 - bat bien cascade: tang nao stall thi moi tang truoc no cung phai stall, neu khong se mat instruction |
| 2 | `a_hz_cascade_ex_id` | 50 | — | `exercised` |  |
| 3 | `a_hz_cascade_id_if` | 55 | — | `exercised` |  |
| 4 | `a_hz_mem_busy_stalls` | 61 | REQ-177 | `vacuous` | §18.6 - moi nguon busy phai dan den stall tuong ung |
| 5 | `a_hz_ex_busy_stalls` | 66 | — | `exercised` |  |
| 6 | `a_hz_if_busy_stalls` | 71 | — | `vacuous` |  |
| 7 | `a_hz_ex_busy_does_not_flush` | 78 | REQ-176 | `exercised` | §18.6 rev 0.4 - i_ex_busy KHONG duoc lam bat o_flush_ex. Neu bat, MULDIV bi reset moi chu ky va loi treo quay lai |
| 8 | `a_hz_load_use_flush_id` | 84 | REQ-175 | `vacuous` | §18.5 - load-use chen bubble vao EX bang o_flush_id |
| 9 | `a_hz_trap_flush_all` | 90 | REQ-177 | `vacuous` | §18.6 - trap huy ca 4 slot |
| 10 | `a_hz_branch_flush` | 96 | REQ-177 | `exercised` | §18.6 - branch/jump taken huy 2 instruction da fetch nham |
| 11 | `a_hz_mem_redirect_flush` | 102 | REQ-177 | `vacuous` | §18.6 - MRET/FENCE.I huy IF, ID, EX |
| 12 | `a_hz_fwd_exmem_valid_source` | 109 | REQ-171 | `vacuous` | §18.4 - forward tu EX/MEM chi hop le khi co ghi thanh ghi khac x0 REQ-171 |
| 13 | `a_hz_fwd_memwb_valid_source` | 116 | — | `exercised` |  |
| 14 | `a_hz_no_fwd_from_load` | 125 | REQ-172 | `exercised` | §18.4 - khong bao gio forward tu EX/MEM khi do la mot load: duong forward 1 khong mang load data |
| 15 | `a_hz_no_fwd_from_x0_a` | 132 | REQ-171 | `exercised` | §18.4 - x0 khong bao gio la nguon forward |
| 16 | `a_hz_no_fwd_from_x0_b` | 137 | — | `exercised` |  |
| 17 | `a_hz_fwd_disabled` | 144 | REQ-173 | `exercised` | Khi PR_FWD_EN = 0, khong bao gio co forward |
| 18 | `c_hz_load_use` | 151 | REQ-174 | `cover-miss` | Quan sat da xay ra load-use interlock |
| 19 | `c_hz_fwd_exmem` | 155 | REQ-171 | `cover-miss` | Quan sat da forward tu ca hai duong |
| 20 | `c_hz_fwd_memwb` | 157 | — | `cover-hit` |  |

---

## `rv32im_id_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_id_exc_priority_if` | 33 | REQ-057 | `vacuous` | Uu tien exception o ID - loi mang tu IF thang illegal, illegal thang ecall/ebreak |
| 2 | `a_id_illegal_code` | 42 | REQ-057 | `vacuous` | Illegal instruction phai thanh EXC_ILLEGAL voi tval = instruction word REQ-057 |
| 3 | `a_id_ecall_code` | 50 | REQ-057 | `vacuous` | ECALL sinh EXC_ECALL_M voi tval = 0 |
| 4 | `a_id_ebreak_code` | 58 | REQ-057 | `vacuous` | EBREAK sinh EXC_BREAKPOINT voi tval = pc |
| 5 | `a_id_exc_kills_side_effects` | 67 | REQ-058 | `vacuous` | Khi co exception o ID, moi side-effect phai bi tat |
| 6 | `c_id_exc_flows_on` | 76 | REQ-058 | `cover-miss` | Instruction co exception van chay tiep xuong MEM de commit trap o do REQ-058 |
| 7 | `a_id_used_needs_valid` | 82 | REQ-059 | `exercised` | rs*_used chi bat khi slot IF/ID hop le - tranh stall gia |
| 8 | `a_id_flush_clears` | 88 | REQ-056 | `in-flight` | i_flush xoa slot ID/EX ngay chu ky ke tiep |
| 9 | `a_id_stall_holds` | 94 | REQ-056 | `exercised` | i_stall khong flush thi giu nguyen ID/EX |
| 10 | `a_dec_compressed_illegal` | 136 | REQ-067 | `exercised` | L2 - encoding compressed (opcode[1:0] != 11) luon illegal |
| 11 | `a_dec_illegal_no_side_effect` | 142 | REQ-060 | `exercised` | Illegal thi khong duoc bat bat ky side-effect nao |
| 12 | `a_dec_unknown_opcode` | 149 | REQ-066 | `exercised` | L1 - opcode ngoai bang §7.4 phai ra illegal |
| 13 | `a_dec_priv_fields_zero` | 160 | REQ-071 | `vacuous` | L6 - ECALL/EBREAK/MRET/WFI phai co rs1 = 0 va rd = 0 |
| 14 | `a_dec_no_rs_for_u_j` | 167 | REQ-074 | `exercised` | §7.9 - LUI/AUIPC/JAL khong dung rs nao |
| 15 | `a_dec_branch_store_uses_both` | 174 | REQ-074 | `exercised` | §7.9 - BRANCH va STORE dung ca rs1 lan rs2 |
| 16 | `a_dec_imm_sel_u` | 182 | REQ-062 | `vacuous` | §7.5 - LUI/AUIPC dung IMM_U, JAL dung IMM_J |
| 17 | `a_dec_imm_sel_j` | 188 | — | `exercised` |  |
| 18 | `a_dec_jump_wb_pc4` | 194 | REQ-062 | `exercised` | JAL/JALR ghi pc+4 vao rd qua WB_PC4 |
| 19 | `a_dec_jalr_implies_jump` | 200 | REQ-061 | `vacuous` | JALR luon keo theo jump_en |
| 20 | `a_dec_csrrw_always_writes` | 206 | REQ-065 | `vacuous` | §7.7 - CSRRW/CSRRWI luon ghi CSR |
| 21 | `a_dec_csrrs_always_reads` | 213 | REQ-065 | `exercised` | §7.7 - CSRRS/C(I) luon doc CSR |
| 22 | `a_dec_csrrw_rd0_no_read` | 223 | REQ-065 | `vacuous` | §7.7 - CSRRW voi rd = x0 thi khong duoc doc CSR (tranh side-effect doc) REQ-065 |
| 23 | `a_dec_fence_is_nop` | 230 | REQ-064 | `vacuous` | FENCE la NOP - khong side-effect, khong fencei |
| 24 | `c_dec_muldiv_seen` | 237 | REQ-063 | `cover-hit` | Quan sat da decode duoc RV32M |
| 25 | `a_imm_i_format` | 258 | REQ-075 | `exercised` | §8.3 - IMM_I sign-extend tu instr[31:20] |
| 26 | `a_imm_u_format` | 264 | REQ-075 | `vacuous` | §8.3 - IMM_U dat instr[31:12] len cao, 12 bit thap bang 0 |
| 27 | `a_imm_branch_jump_even` | 270 | REQ-075 | `exercised` | §8.3 - IMM_B va IMM_J luon co bit 0 bang 0 |
| 28 | `a_imm_z_zero_extended` | 277 | REQ-075 | `vacuous` | §8.3 - IMM_Z zero-extend uimm 5 bit, 27 bit cao phai bang 0 |
| 29 | `a_rf_x0_read_zero_a` | 304 | REQ-077 | `exercised` | x0 luon doc ra 0, ke ca khi co write cung chu ky |
| 30 | `a_rf_x0_read_zero_b` | 309 | — | `exercised` |  |
| 31 | `a_rf_bypass_a` | 316 | REQ-078 | `exercised` | §9.4 write-first bypass - doc va ghi cung dia chi thi doc ra du lieu dang ghi |
| 32 | `a_rf_bypass_b` | 322 | — | `exercised` |  |
| 33 | `a_rf_no_x_a` | 332 | REQ-076 REQ-079 | `exercised` | Dia chi doc xac dinh thi du lieu doc ra khong duoc X. Khong rang buoc khi dia chi con X: ngay sau reset, instr trong IF/ID chua xac dinh (datapath flop khong reset, rtl_rule §4.2) nhung valid = 0 nen khong ai dung ket qua do. |
| 34 | `a_rf_no_x_b` | 337 | — | `exercised` |  |

---

## `rv32im_if_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_if_pc_reset_value` | 36 | REQ-046 | `exercised` | Sau khi reset nhả, PC phải bằng PR_BOOT_ADDR |
| 2 | `a_if_redirect_priority` | 43 | REQ-047 | `vacuous` | Redirect tu MEM uu tien hon redirect tu EX - khi ca hai cung bat, PC phai lay theo duong MEM |
| 3 | `a_if_two_cycle_fetch` | 51 | REQ-048 REQ-184 | `exercised` | Moi lan fetch ton it nhat 2 chu ky - mot slot valid o IF/ID luon duoc theo sau boi mot bubble khi pipeline chay tiep |
| 4 | `c_if_rsp_latency0` | 58 | REQ-049 REQ-041 | `cover-miss` | Quan sat truong hop response ve ngay chu ky bat tay (B9, latency 0) - duong reg_rsp_early |
| 5 | `a_if_single_outstanding` | 65 | REQ-037 REQ-050 | `exercised` | Toi da mot request chua hoan tat tren I-bus - sau khi bat tay, khong phat request moi cho toi khi co response (B5) |
| 6 | `a_if_ibus_payload_stable` | 72 | REQ-034 | `vacuous` | Khi valid=1 ma ready=0, payload request phai giu nguyen (B2) |
| 7 | `a_if_ibus_addr_aligned` | 79 | REQ-051 | `exercised` | I1 - dia chi request tren I-bus luon align 4 byte |
| 8 | `a_if_pc_aligned` | 85 | REQ-052 | `exercised` | I2 - reg_pc luon align 4 byte (khong co C-extension) |
| 9 | `a_if_ifid_pc_aligned` | 91 | REQ-052 | `exercised` | PC cua instruction trong IF/ID cung phai align 4 |
| 10 | `a_if_access_fault_code` | 98 | REQ-053 | `vacuous` | I3 - loi tren I-bus phai thanh EXC_INSTR_ACCESS gan vao instruction, khong trap tai cho |
| 11 | `a_if_busy_no_request` | 106 | REQ-054 | `vacuous` | o_if_busy chi bat khi dang cho response, va luc do khong phat request moi |
| 12 | `a_if_flush_clears_ifid` | 112 | REQ-055 | `in-flight` | i_flush phai xoa slot IF/ID ngay chu ky ke tiep |
| 13 | `a_if_stall_holds` | 118 | REQ-055 | `exercised` | i_stall khong bi flush thi giu nguyen ca reg_pc lan IF/ID |

---

## `rv32im_mem_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_mem_gate_on_exception` | 43 | REQ-118 | `vacuous` | §14.5 - store khong bao gio ra bus khi instruction se bi huy. Day la dieu kien giu precise exception |
| 2 | `a_mem_req_needs_valid` | 49 | REQ-118 | `exercised` | §14.5 - chi phat request cho instruction hop le co mem_req |
| 3 | `a_mem_single_outstanding` | 55 | REQ-037 | `exercised` | B5 - toi da mot transaction chua hoan tat tren D-bus |
| 4 | `a_mem_dbus_payload_stable` | 61 | REQ-034 | `vacuous` | B2 - payload D-bus giu nguyen khi valid=1 ma ready=0 |
| 5 | `a_mem_dbus_addr_aligned` | 69 | REQ-125 | `exercised` | §15.3 - dia chi D-bus luon word-align |
| 6 | `a_mem_never_misaligned_on_bus` | 76 | REQ-129 | `exercised` | §15.5 A1 - EX da chan misaligned nen request ra bus khong bao gio misaligned |
| 7 | `a_mem_busy_covers_accept_wait` | 83 | REQ-113 | `vacuous` | §14.5 - o_mem_busy phai phu ca hai giai doan cho: cho ready va cho response. Neu thieu ve dau, lenh load/store se bi mat |
| 8 | `a_mem_busy_covers_rsp_wait` | 88 | — | `vacuous` |  |
| 9 | `a_mem_outstanding_matches` | 94 | REQ-114 | `exercised` | §14.5 - o_mem_outstanding phai bang co reg_req_sent |
| 10 | `a_mem_exc_priority_carried` | 100 | REQ-119 | `vacuous` | §14.6 uu tien 1 - exception mang tu tang truoc duoc giu nguyen |
| 11 | `a_mem_csr_illegal_code` | 107 | REQ-120 | `vacuous` | §14.6 uu tien 2 - CSR illegal sinh EXC_ILLEGAL |
| 12 | `a_mem_load_access_fault` | 114 | REQ-121 REQ-122 | `vacuous` | §14.6 uu tien 3/4 - loi bus tren load va store phan biet dung ma |
| 13 | `a_mem_store_access_fault` | 121 | — | `vacuous` |  |
| 14 | `a_mem_trap_kills_wb` | 129 | REQ-124 | `vacuous` | §17.8 - instruction bi trap khong duoc de lai dau vet o WB |
| 15 | `a_mem_exc_no_retire` | 135 | REQ-124 | `vacuous` | §14.6 - instruction co exception khong bao gio retire |
| 16 | `a_mem_csr_wr_en_from_bundle` | 142 | REQ-151 | `exercised` | §16.10 - o_csr_wr_en KHONG duoc phu thuoc i_trap_taken. Neu phu thuoc se tao vong to hop qua o_csr_illegal (spec rev 0.4) |
| 17 | `a_mem_csr_en_needs_valid` | 148 | REQ-115 | `exercised` | §14.1 T2 - CSR chi truy cap cho instruction hop le |
| 18 | `c_mem_dbus_transaction` | 154 | REQ-111 | `cover-hit` | Quan sat da co mot truy cap D-bus hoan tat |
| 19 | `a_lsu_addr_word_aligned` | 179 | REQ-125 | `exercised` | §15.3 - dia chi request luon la dia chi word-align cua i_addr |
| 20 | `a_lsu_be_sb` | 185 | REQ-126 | `vacuous` | §15.3 - SB bat dung 1 lane, SH bat dung 2 lane, SW bat ca 4 |
| 21 | `a_lsu_be_sh` | 191 | — | `vacuous` |  |
| 22 | `a_lsu_be_sw` | 197 | — | `exercised` |  |
| 23 | `a_lsu_byte_never_misaligned` | 204 | REQ-128 | `exercised` | §15.5 - truy cap byte khong bao gio misaligned |
| 24 | `a_lsu_word_misaligned` | 210 | REQ-128 | `exercised` | §15.5 - SZ_W misaligned khi va chi khi addr[1:0] khac 0 |
| 25 | `a_lsu_half_misaligned` | 217 | REQ-128 | `vacuous` | §15.5 - SZ_H misaligned khi va chi khi addr[0] khac 0 |

---

## `rv32im_top_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_top_trap_clears_pipeline` | 86 | REQ-161 REQ-162 | `vacuous` | §17.8 E2 - trap xoa sach ca 4 slot pipeline, khong de lai dau vet REQ-161 REQ-162 |
| 2 | `a_top_trap_no_retire` | 93 | REQ-161 | `vacuous` | §17.8 - instruction bi trap khong duoc dem vao minstret |
| 3 | `a_top_retire_tracks_memwb` | 99 | REQ-124 | `exercised` | §4.1 CH12c - tin hieu retire phai bam theo w_memwb.valid |
| 4 | `a_top_ifid_pc_aligned` | 105 | REQ-005 | `exercised` | §5 - PC cua moi slot pipeline hop le deu align 4 |
| 5 | `a_top_idex_pc_aligned` | 110 | — | `exercised` |  |
| 6 | `a_top_exmem_pc_aligned` | 115 | — | `exercised` |  |
| 7 | `a_top_imem_rsp_needs_req` | 121 | REQ-039 | `exercised` | B7 - response tren moi bus phai co request truoc do |
| 8 | `a_top_dmem_rsp_needs_req` | 126 | — | `exercised` |  |
| 9 | `a_top_trace_tied_off` | 137 | REQ-032 | `exercised` | Khi PR_TRACE_EN = 0, toan bo port trace phai tie ve 0 chu khong bi xoa khoi port list |
| 10 | `a_top_trace_tracks_wb` | 146 | REQ-123 | `exercised` | Khi bat trace, o_trace_valid phai trung voi slot WB hop le |
| 11 | `a_top_no_muldiv` | 154 | REQ-063 | `exercised` | Khi PR_M_EXT_EN = 0, khong instruction nao duoc bat muldiv_en |
| 12 | `c_top_retire` | 165 | REQ-184 | `cover-hit` | §3.4.3 - quan sat throughput fetch: hai instruction retire lien tiep cach nhau it nhat 2 chu ky |
| 13 | `c_top_pipeline_full` | 169 | REQ-005 | `cover-miss` | Quan sat ca 4 slot pipeline cung hop le - pipeline day |

---

## `rv32im_trap_sva.sv`

| # | Label | Ln | REQ | Status | Mô tả (NL) |
|---|---|---|---|---|---|
| 1 | `a_trap_not_while_outstanding` | 46 | REQ-160 | `exercised` | §17.7 - KHONG bao gio commit trap khi D-bus con transaction chua xong. Vi pham la pha precise exception |
| 2 | `a_trap_needs_valid_instr` | 52 | REQ-159 | `vacuous` | §17.7 - trap chi commit cho instruction hop le o MEM |
| 3 | `a_trap_needs_a_source` | 58 | REQ-159 | `vacuous` | §17.7 - trap chi xay ra khi co exception hoac interrupt |
| 4 | `a_trap_irq_wins` | 64 | REQ-157 | `vacuous` | §17.6 - interrupt luon thang exception dong bo |
| 5 | `a_trap_exc_when_no_irq` | 70 | REQ-157 | `vacuous` | §17.6 - khong co interrupt thi trap phai la exception dong bo |
| 6 | `a_trap_irq_tval_zero` | 77 | REQ-155 | `vacuous` | §17.5 - mtval bang 0 voi moi interrupt |
| 7 | `a_trap_irq_priority_mei` | 83 | REQ-158 | `vacuous` | §17.6 - uu tien interrupt MEI > MSI > MTI |
| 8 | `a_trap_irq_priority_msi` | 89 | — | `vacuous` |  |
| 9 | `a_trap_irq_needs_mie` | 96 | REQ-154 | `vacuous` | §17.5 - interrupt chi taken khi mstatus.MIE bat |
| 10 | `a_trap_pc_is_mem_pc` | 102 | REQ-165 | `vacuous` | §16.7 - mepc lay PC cua chinh instruction o MEM |
| 11 | `a_trap_beats_mret` | 108 | REQ-165 | `vacuous` | §17.9 - trap thang MRET, MRET thang FENCE.I |
| 12 | `a_trap_redirect_to_mtvec` | 114 | REQ-166 | `vacuous` | §17.9 - khi trap, PC redirect ve vector cua mtvec |
| 13 | `a_trap_mret_to_mepc` | 122 | REQ-165 | `vacuous` | §17.9 - MRET redirect ve mepc |
| 14 | `a_trap_fencei_to_pc4` | 128 | REQ-170 | `vacuous` | §17.10 - FENCE.I refetch tu pc+4 |
| 15 | `a_trap_redirect_sane` | 135 | REQ-165 | `vacuous` | §17.9 - moi redirect deu phai co dia chi xac dinh va align 4 |
| 16 | `a_trap_redirect_has_reason` | 142 | REQ-165 | `vacuous` | §17.9 - redirect chi bat khi co trap, MRET hoac FENCE.I |
| 17 | `a_trap_vectored_irq_only` | 150 | REQ-167 | `vacuous` | §17.9 - Vectored chi ap dung cho interrupt. Exception dong bo luon nhay BASE |
| 18 | `a_trap_no_irq` | 158 | REQ-154 | `exercised` | Khi PR_IRQ_EN = 0 thi khong bao gio co interrupt |
| 19 | `c_trap_taken` | 165 | REQ-153 | `cover-miss` | Quan sat da co it nhat mot trap |
| 20 | `c_trap_mret` | 169 | REQ-015 | `cover-miss` | Quan sat da co it nhat mot MRET |

---

## REQ chưa có assertion (83)

Đã ghi `no_assertion` trong `schemas/rtm.json` theo quyết định ở Gate 3. Phần lớn là bảng tra cứu mà một assertion không diễn tả hết (opcode map §7.4, ALU table §11.4, byte-enable §15.3) — kiểm tra đầy đủ là việc của directed test ở Phase 4. Cột **Active** = `—` nghĩa là REQ không thực thi ở cấu hình hiện tại.

| REQ | Cat | Active | Nội dung |
|---|---|---|---|
| REQ-001 | func | ✓ | RV32I base integer instruction set — 40 lệnh, liệt kê đầy đủ ở §1.1.1 (37 lệnh cơ bản +  |
| REQ-002 | func | ✓ | RV32M: MUL MULH MULHSU MULHU DIV DIVU REM REMU |
| REQ-003 | func | ✓ | Zicsr: CSRRW/S/C, CSRRWI/SI/CI |
| REQ-004 | func | ✓ | Zifencei: FENCE.I — flush pipeline và refetch từ pc+4 |
| REQ-006 | func | ✓ | Full forwarding EX/MEM → EX và MEM/WB → EX |
| REQ-007 | func | ✓ | Load-use interlock — stall khi consumer đứng ngay sau load |
| REQ-008 | func | ✓ | Branch resolve tại tầng EX, static predict-not-taken |
| REQ-009 | func | ✓ | Regfile 32×32, x0 hardwired 0, write-first bypass |
| REQ-010 | func | ✓ | I-bus / D-bus tách rời (Harvard), valid-ready handshake |
| REQ-011 | func | ✓ | M-mode CSR file — 16 CSR theo §16.4 |
| REQ-012 | func | ✓ | Precise exception, commit point tại tầng MEM |
| REQ-013 | func | ✓ | 9 exception đồng bộ (ECALL/EBREAK/illegal/misaligned/access fault) |
| REQ-014 | func | ✓ | 3 interrupt M-mode (software/timer/external), level-sensitive |
| REQ-016 | func | ✓ | mcycle / minstret 64-bit |
| REQ-018 | func | — | Retire trace port cho co-simulation với ISS |
| REQ-019 | func | — | mtvec Vectored mode |
| REQ-020 | cons | ✓ | C1: PR_BOOT_ADDR[1:0] == 2'b00 |
| REQ-021 | cons | ✓ | C2: PR_MTVEC_RESET[1:0] == 2'b00 |
| REQ-022 | cons | ✓ | C3: PR_IRQ_EN == 1 → yêu cầu PR_CSR_EN == 1 |
| REQ-023 | cons | ✓ | C4: PR_MTVEC_VEC_EN == 1 → yêu cầu PR_CSR_EN == 1 |
| REQ-024 | cons | ✓ | C5: PR_COUNTER_EN == 1 → yêu cầu PR_CSR_EN == 1 |
| REQ-025 | cons | ✓ | C6: PR_DIV_IMPL == 0 — Phase 1 chỉ có SEQ non-restoring |
| REQ-026 | cons | ✓ | C7: PR_BUS_OUTSTANDING == 1 — Phase 1 khoá ở 1 |
| REQ-027 | cons | ✓ | C8: PR_RF_IMPL == 1 chỉ hợp lệ khi target là FPGA (LUTRAM async-read, §9.5). Target ASIC |
| REQ-028 | inte | ✓ | Nhóm clock/reset: i_clk_core là clock duy nhất của lõi; i_resetn_core active-low, async  |
| REQ-029 | inte | ✓ | Nhóm Instruction bus (read-only): o_imem_req_valid/addr, i_imem_req_ready, i_imem_rsp_va |
| REQ-030 | inte | ✓ | Nhóm Data bus: o_dmem_req_valid/addr/we/be/wdata, i_dmem_req_ready, i_dmem_rsp_valid/rda |
| REQ-031 | inte | ✓ | Nhóm Interrupt: i_irq_sw / i_irq_timer / i_irq_ext level-sensitive. Lõi KHÔNG có synchro |
| REQ-033 | inte | ✓ | B1: transfer xảy ra tại rising edge khi o_*_req_valid && i_*_req_ready |
| REQ-035 | inte | ✓ | B3: o_*_req_valid KHÔNG được phụ thuộc tổ hợp vào i_*_req_ready (chống combinational loo |
| REQ-036 | inte | ✓ | B4: i_*_req_ready ĐƯỢC PHÉP phụ thuộc tổ hợp vào o_*_req_valid |
| REQ-038 | inte | ✓ | B6: mỗi request được chấp nhận sinh đúng một xung i_*_rsp_valid rộng 1 chu kỳ |
| REQ-040 | inte | ✓ | B8: lõi luôn sẵn sàng nhận response — không có rsp_ready |
| REQ-042 | inte | ✓ | B10: khi i_*_rsp_err = 1, i_*_rsp_rdata là don't-care |
| REQ-043 | inte | ✓ | rv32im_pkg định nghĩa 11 enum type: alu_op_t, op_a_sel_t, op_b_sel_t, imm_sel_t, br_op_t |
| REQ-044 | inte | ✓ | Pipeline bundle typedef struct packed: ifid_t, idex_t, exmem_t, memwb_t. Field instr tro |
| REQ-045 | inte | ✓ | TOP rv32im_core thuần structural: instantiate U03–U18 và đấu nối theo bảng channel CH01– |
| REQ-068 | func | ✓ | Illegal instruction L3: funct3 không hợp lệ cho opcode tương ứng |
| REQ-069 | func | ✓ | Illegal instruction L4: funct7 sai với R-type (0000000 / 0100000 / 0000001 tuỳ lệnh) |
| REQ-070 | func | ✓ | Illegal instruction L5: SLLI/SRLI mà instr[31:25] != 7'b0000000; SRAI mà != 7'b0100000 |
| REQ-072 | func | — | Illegal instruction L7: RV32M khi PR_M_EXT_EN = 0 |
| REQ-073 | func | — | Illegal instruction L8: Lệnh CSR / MRET khi PR_CSR_EN = 0 |
| REQ-080 | func | — | PR_RF_IMPL = 1 → mảng reg_file infer thành distributed RAM (LUTRAM), KHÔNG phải block RA |
| REQ-081 | func | — | R1: khi PR_RF_IMPL = 1, read port giữ nguyên tổ hợp — dữ liệu ra cùng chu kỳ với i_rs*_a |
| REQ-082 | func | — | R2: khi PR_RF_IMPL = 1, bypass §9.4 phải làm bằng mux bên ngoài mảng RAM — LUTRAM không  |
| REQ-083 | func | — | R3: khi PR_RF_IMPL = 1, PR_RF_RESET_EN bị bỏ qua — LUTRAM không reset được |
| REQ-085 | func | ✓ | Mux nguồn ALU sau forwarding: op_a_sel ∈ {OPA_RS1, OPA_PC, OPA_ZERO}, op_b_sel ∈ {OPB_RS |
| REQ-088 | func | ✓ | JAL/JALR ghi pc + 4 vào rd qua wb_sel = WB_PC4 |
| REQ-096 | func | — | PR_M_EXT_EN = 0 → muldiv là module rỗng, o_done tie 1 |
| REQ-097 | func | ✓ | D1: i_start là xung 1 chu kỳ; i_op / i_op_a / i_op_b chỉ cần hợp lệ ở chu kỳ đó — module |
| REQ-100 | func | ✓ | D4: special case §13.5 và PR_MULT_IMPL = 1 → o_done = 1 ngay chu kỳ kế i_start, o_busy k |
| REQ-103 | func | ✓ | Chuẩn bị operand mult §13.4 trên datapath 33×33 dùng chung: MUL lấy [PR_XLEN-1:0]; MULH  |
| REQ-104 | func | ✓ | PR_MULT_IMPL = 0: shift-add radix-2, 1 partial product mỗi chu kỳ |
| REQ-105 | func | — | PR_MULT_IMPL = 1: toán tử * 33×33 → 66-bit, tổ hợp (infer DSP trên FPGA) |
| REQ-106 | func | ✓ | Thuật toán div: non-restoring radix-2, PR_XLEN iteration + 1 fixup |
| REQ-107 | func | ✓ | Xử lý dấu signed §13.5: lấy trị tuyệt đối 2 operand trước khi chia; quotient âm nếu sign |
| REQ-109 | func | ✓ | Overflow (op_a == {1'b1,{XLEN-1{1'b0}}} && op_b == '1) bit-exact: DIV → op_a (= -2^31);  |
| REQ-110 | func | ✓ | Special case (chia 0 / overflow) thoát sớm — early exit, không chạy đủ iteration |
| REQ-112 | func | ✓ | reg_req_sent: cờ nội bộ 1 bit — set khi o_dmem_req_valid && i_dmem_req_ready, clear khi  |
| REQ-116 | func | ✓ | WB mux ở cuối tầng MEM §14.4: WB_ALU → alu_result, WB_MEM → w_load_data, WB_PC4 → pc_plu |
| REQ-117 | func | ✓ | Forward path 1 (o_fwd_exmem_data) là mux giữa alu_result, pc_plus4 và i_csr_rdata — KHÔN |
| REQ-127 | func | ✓ | Load extraction + extend theo bảng §15.4: LB/LBU 4 offset, LH/LHU 2 offset, LW. sign ext |
| REQ-134 | func | ✓ | mie (0x304) / mip (0x344): bit 3 MSIE/MSIP, bit 7 MTIE/MTIP, bit 11 MEIE/MEIP. mip do pi |
| REQ-136 | func | ✓ | mcause (0x342) = {i_trap_is_irq, 26'b0, i_trap_code[4:0]} |
| REQ-149 | func | ✓ | Mỗi counter implement như MỘT counter 64-bit duy nhất với 2 write port riêng cho nửa thấ |
| REQ-150 | func | — | PR_COUNTER_EN = 0: mcycle/mcycleh/minstret/minstreth đọc ra '0, ghi bị bỏ qua, KHÔNG ill |
| REQ-156 | func | ✓ | Interrupt level-sensitive: lõi KHÔNG tự clear mip. Phần mềm phải xử lý nguồn ngắt để pin |
| REQ-163 | func | ✓ | Exception phát hiện ở IF/ID/EX KHÔNG trap tại chỗ — đóng gói thành {exc_valid, exc_code, |
| REQ-164 | func | ✓ | Khi o_trap_taken = 1: flush IF/ID/EX, kill WB của instruction ở MEM (o_memwb.rd_wen = 0, |
| REQ-168 | func | ✓ | WFI thực thi như NOP trong Phase 1 |
| REQ-169 | func | ✓ | FENCE thực thi như NOP (không có store buffer, không reorder, không agent khác) |
| REQ-179 | func | ✓ | CLINT register map §19.3: msip @0x0000 (bit 0), mtimecmp 64-bit @0x4000 (low/high), mtim |
| REQ-180 | func | ✓ | o_irq_timer = (reg_mtime >= reg_mtimecmp) |
| REQ-181 | func | ✓ | o_irq_sw = reg_msip[0] |
| REQ-182 | func | ✓ | CLINT bus slave interface §19.4 tuân theo giao thức §3.4 (B1–B10) |
| REQ-183 | cons | ✓ | File layout §20: 1 module / 1 file, tên file = tên module + .sv. rtl/ cho U01–U18, rtl/s |
| REQ-185 | timi | ✓ | Load-use penalty = 1 cycle |
| REQ-186 | timi | ✓ | Branch / Jump taken penalty = 2 cycle |
| REQ-187 | timi | — | PR_FWD_EN = 0: penalty tối đa 2 cycle (producer đi EX → MEM → WB) |
| REQ-188 | timi | ✓ | MUL/MULH/MULHSU/MULHU latency 33 cycle khi PR_MULT_IMPL = 0 |
| REQ-189 | timi | — | MUL/MULH/MULHSU/MULHU latency 1 cycle khi PR_MULT_IMPL = 1 |
| REQ-190 | timi | ✓ | DIV/DIVU/REM/REMU latency 34 cycle khi PR_DIV_IMPL = 0 |
| REQ-191 | timi | ✓ | MULDIV special case (chia 0 / overflow) latency 1 cycle — early exit |
