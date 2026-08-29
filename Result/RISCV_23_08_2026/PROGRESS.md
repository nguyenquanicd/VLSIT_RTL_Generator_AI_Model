# Trạng thái dự án `rv32im_core` — checkpoint 2026-08-23 (Phase 3b)

## Gate

| Gate | Trạng thái | Output |
|---|---|---|
| Gate 1 (`/spec_parser`) | ✅ đã ký | `schemas/structured_spec.json` — 191 REQ |
| Gate 2 (`/config_ui`) | ✅ đã ký | `schemas/final_config.json` — 15 param default, 8/8 constraint PASS |
| Phase 3a (`/rtl_generator`) | ✅ **hoàn tất** | 18 module + `synth_report.json` |
| Phase 3b (`/sva_generator`) | ✅ sinh xong | 181 property, VCS 0 Error, sim 0 fail |
| Gate 3 (Property Review) | ✅ **đã ký** | `schemas/rtm.json` — 181/181 confirm, 108 REQ `sva_traced` |

Spec: **`spec_parser.md` rev 0.4**. Cấu hình: toàn default, F18/F19 tắt, 175/191 REQ active.

## Phase 3a — kết quả

```
18/18 module sinh xong, 4191 dòng SV
Full-design lint : PASS — 0 warning, 0 error (Verilator 5.041 -Wall)
Synth TT/SS      : PASS — 12731 cells, 2219 flops, 371272 um2
REQ-ID tag       : 173/191 REQ, 393 lần xuất hiện trong RTL
```

### 18 REQ chưa tag trong RTL — đều có lý do

| Nhóm | REQ | Vì sao |
|---|---|---|
| B1–B10 bus protocol | 033–042 | Là thuộc tính giao thức, tag bằng **assertion ở Phase 3b**, không phải một khối code |
| CLINT (U19) | 179–182 | Ngoài phạm vi 18 module lõi, optional, thuộc tầng SoC |
| File layout | 183 | Ràng buộc cấu trúc repo, thoả mãn bởi chính `filelist.f` |
| Timing penalty | 185, 186 | Hành vi emergent, verify bằng sim/assertion |
| `PR_FWD_EN=0` penalty | 187 | INACTIVE ở cấu hình hiện tại |

## Smoke test mức lõi — ✅ PASS

`build/selfcheck/tb_core_smoke.sv`. Chương trình 11 lệnh phủ đúng các ca vừa sửa:
`MUL` (lỗi treo), load-use interlock, `SW`/`LW`, `BEQ` not-taken, `DIV`,
`CSRRS mcycle` (đường CH12c). Chạy 2 cấu hình I-mem: `PR_IMEM_LAT = 1` và `0`.

```
8/8 retire dung gia tri, khong treo, ca hai cau hinh deu 113 cycles
  x1=6 @5   x2=7 @7    x3=42 @42 (MUL, 35 cy)   x4=100 @45
  x5=42 @49 x6=43 @51  x7=7 @89 (DIV, 38 cy)    x8=91 @92 (mcycle)
```

Xác nhận được:
- **Lỗi treo MULDIV đã hết** — `MUL` hoàn tất sau ~33 chu kỳ đúng như spec.
- **2 chu kỳ/fetch** ở cả latency 0 lẫn 1 ⇒ đúng bảng §3.4.3 rev 0.4 và REQ-184.
- Đường `reg_rsp_early` (B9, §5.4.2) chạy đúng — trước đó chưa test lần nào.
- CH12c + `o_csr_rdata` tổ hợp chạy đúng (`mcycle` đọc ra 91 ở chu kỳ 92).

**Chưa phủ:** exception/trap, interrupt, MRET, FENCE.I, forwarding EX/MEM,
misaligned, CSR illegal, branch taken. Đó là việc của Phase 4/5.

## Lỗi tìm ra ở phiên này → spec bump rev 0.3 → 0.4

| # | Mục | Vấn đề |
|---|---|---|
| 1 | §18.6 · §10.7 · **§10.8 mới** · §13.3 D5 | **Treo lõi ở lệnh `MUL` đầu tiên.** `o_flush_ex` vừa phải bật suốt 33–34 chu kỳ để giữ bubble ở MEM, vừa được dùng để huỷ MULDIV ⇒ MULDIV reset mỗi cạnh clock, `i_ex_busy` kẹt ở 1. Sửa: bỏ `i_ex_busy` khỏi `o_flush_ex`, `ex_stage` tự chèn bubble (§10.8 B1–B3). |
| 2 | §16.10 | **Combinational loop** `i_trap_taken → o_csr_wr_en → o_csr_illegal → o_exc_valid → i_trap_taken`. Sửa: bỏ gating ở `mem_stage`; `csr_file.w_wr_commit` vốn đã có `!i_trap_valid`. |
| 3 | §14.5 | **Mất lệnh load/store** khi slave chưa assert `ready`. Sửa: `o_mem_busy` thêm vế `(o_dmem_req_valid && !i_dmem_req_ready)`. |

Cả 3 đều do chính đợt sửa rev 0.3 đưa vào. #1 và #2 bị `UNOPTFLAT` của full-design
lint bắt được — đó là lý do phải chạy full-design lint chứ không chỉ lint từng module.

## Hai sai sót trong template của `/rtl_generator` (đã vòng tránh)

| # | Template ghi | Thực tế |
|---|---|---|
| 1 | `read_verilog -sv -f filelist.f` + `set GF180_TT "..."` | `read_verilog` không nhận `-f`, và `set` là TCL không phải Yosys script. Ngoài ra Yosys frontend **không parse được** `module X import pkg::*;` (rtl_rule §3.1) → phải dùng `plugin -i slang` + `read_slang`. |
| 2 | Liberty ở `.../liberty/*.lib` | Thư mục đó chỉ có **header thư viện (5.7 KB, 0 cell)** → `dfflibmap` fail. Bản dùng được là `.../build/synopsys/*_full.lib` (20 MB, 229 cell, 36 loại DFF). |

Script đã sửa nằm ở `src/rtl/synth_gf180_{tt,ss}.ys`, có comment giải thích.

## Môi trường

Verilator 5.041 · Yosys 0.58+35 · slang plugin · `/tools/OSS/oss-cad-suite/bin`
(**không** có sẵn trong PATH mặc định — phải `export PATH=/tools/OSS/oss-cad-suite/bin:$PATH`)

Helper lint: `src/rtl/lint.sh <top> <file...>`

## Self-check số học (`build/selfcheck/`, ngoài phạm vi Phase 3a)

`mult`/`div`: **992 phép, 0 sai**, phủ `INT_MIN×-1`, chia 0, overflow, dấu remainder,
`MULHSU`; latency 33 / 34 / 1. Checker đã validate bằng fault injection.

> Lưu ý: test này chạy `mult`/`div` **độc lập với `i_flush` buộc bằng 0**, nên nó
> **không** phát hiện được lỗi treo #1 ở trên. Đó là lỗi mức tích hợp.

> Gotcha Verilator: không ghi ngược được biến static module-scope từ `task automatic`
> (cả `x++` lẫn `x = x + 1`). Đếm bằng `$display` + grep log.

## Quyết định thiết kế tự chốt (spec thiếu dữ kiện) — cần review

| # | Quyết định | Lý do |
|---|---|---|
| 1 | `instr` vô điều kiện trong cả 4 bundle | `typedef` trong package không thể phụ thuộc `PR_TRACE_EN` |
| 2 | `PR_XLEN`/`PR_REG_NUM` lấy từ package, không khai báo lại | §2.1 nói không override được; §2.2 không chứa chúng |
| 3 | Port list `mult`/`div` suy ra từ §13.1 T1 | §13.4/§13.5 không có port list cho U12/U13 |
| 4 | `o_req_be` cho **load** = bật toàn bộ lane | §15.3 chỉ lập bảng cho store |
| 5 | `reg_md_sticky` trong `ex_stage` | `o_done` rộng 1 chu kỳ nhưng EX có thể bị stall vì `mem_busy` ⇒ mất kết quả |
| 6 | Nhánh regfile không reset dùng `always_ff @(posedge clk)` | rtl_rule R1 vs §4.2 xung đột; §4.2 cụ thể hơn |
| 7 | 6 pragma `lint_off UNUSEDSIGNAL` phạm vi hẹp | Port/bundle do spec quy định, không được thu hẹp. Không dùng `-Wno-` toàn cục |

Vị trí 6 pragma: `imm_gen:17` `ex_stage:33,74` `csr_file:44` `mem_stage:89` `core:110`.

## Còn treo trong `rtl_rule.md` rev 1.0 (bạn chọn `none`, chưa sửa)

1. §3.3/§3.4 template ghi `Spec ref: §7.3` cho `rv32im_alu` — ALU ở **§11**.
2. §1.1 ví dụ `WB_SEL_MEM`, spec §4.2 định nghĩa **`WB_MEM`**. RTL dùng `WB_MEM`.
3. §1.1 dòng "Macro (`define`)" ô prefix rỗng.
