# RV32IM Pipelined Core — RTL Specification

| Mục | Giá trị |
|---|---|
| Tên lõi (TOP) | `rv32im_core` |
| ISA | RV32I + M + Zicsr + Zifencei |
| Privilege | Machine mode only |
| Pipeline | 5-stage, in-order, single-issue |
| Ngôn ngữ | SystemVerilog-2012, synthesizable subset |
| Naming rule | Theo `rtl_rule.md` — **bắt buộc** |
| Revision | 0.4 |

> **Phạm vi:** chỉ RTL (chức năng + vi kiến trúc + interface).
> Verification plan nằm ở `spec_verify.md` (chưa tạo).

**Cấu trúc tài liệu:** §1 Target → §2 Parameter → §3 Overview (TOP) → §4 Interconnect → §5–§19 Sub-module → §20 File layout → §21 Milestone → §22 Open item → **§23 Changelog**.

---

# 1. TARGET

## 1.1 Feature list

| ID | Feature | Bắt buộc | Parameter điều khiển |
|---|---|---|---|
| **F01** | RV32I base integer instruction set — **40 lệnh** (liệt kê §1.1.1) | ✅ | — |
| **F02** | RV32M: `MUL MULH MULHSU MULHU DIV DIVU REM REMU` | ✅ | `PR_M_EXT_EN` |
| **F03** | Zicsr: `CSRRW/S/C`, `CSRRWI/SI/CI` | ✅ | `PR_CSR_EN` |
| **F04** | Zifencei: `FENCE.I` (flush + refetch) | ✅ | — |
| **F05** | Pipeline 5 tầng in-order, single-issue | ✅ | — |
| **F06** | Full forwarding EX/MEM → EX và MEM/WB → EX | ✅ | `PR_FWD_EN` |
| **F07** | Load-use interlock, penalty 1 cycle | ✅ | — |
| **F08** | Branch resolve tại EX, static predict-not-taken, penalty 2 cycle | ✅ | — |
| **F09** | Regfile 32×32, x0 hardwired 0, write-first bypass | ✅ | `PR_RF_IMPL` |
| **F10** | I-bus / D-bus tách rời (Harvard), valid-ready handshake | ✅ | — |
| **F11** | M-mode CSR file (16 CSR, §16) | ✅ | `PR_CSR_EN` |
| **F12** | Precise exception, commit point tại tầng MEM | ✅ | — |
| **F13** | 9 exception đồng bộ (`ECALL`/`EBREAK`/illegal/misaligned/access fault) | ✅ | — |
| **F14** | 3 interrupt M-mode (software / timer / external), level-sensitive | ✅ | `PR_IRQ_EN` |
| **F15** | `MRET` khôi phục `mstatus.MIE` và `PC` | ✅ | `PR_CSR_EN` |
| **F16** | `mcycle` / `minstret` 64-bit | ⬜ | `PR_COUNTER_EN` |
| **F17** | MULDIV multi-cycle, stall EX, bit-exact special case | ✅ | `PR_MULT_IMPL`, `PR_DIV_IMPL` |
| **F18** | Retire trace port (cho co-simulation với ISS) | ⬜ | `PR_TRACE_EN` |
| **F19** | `mtvec` Vectored mode | ⬜ | `PR_MTVEC_VEC_EN` |

✅ = luôn build · ⬜ = tuỳ chọn qua parameter

## 1.1.1 RV32I base — 40 lệnh (F01)

| Nhóm | Lệnh | Số |
|---|---|---|
| U-type | `LUI` `AUIPC` | 2 |
| Jump | `JAL` `JALR` | 2 |
| Branch | `BEQ` `BNE` `BLT` `BGE` `BLTU` `BGEU` | 6 |
| Load | `LB` `LH` `LW` `LBU` `LHU` | 5 |
| Store | `SB` `SH` `SW` | 3 |
| OP-IMM | `ADDI` `SLTI` `SLTIU` `XORI` `ORI` `ANDI` `SLLI` `SRLI` `SRAI` | 9 |
| OP | `ADD` `SUB` `SLL` `SLT` `SLTU` `XOR` `SRL` `SRA` `OR` `AND` | 10 |
| MISC-MEM | `FENCE` | 1 |
| SYSTEM | `ECALL` `EBREAK` | 2 |
| **Tổng** | | **40** |

> `FENCE.I` thuộc **Zifencei** (F04), `CSRR*` thuộc **Zicsr** (F03), `MRET`/`WFI` thuộc
> **privileged spec** (F15) — cả ba **không** tính vào 40 lệnh của F01.

## 1.2 Out of scope (Phase sau)

| Hạng mục | Lý do hoãn |
|---|---|
| C-extension (compressed) | Kéo theo misaligned fetch, PC+2 — đổi hẳn IF stage |
| A / F / D extension | Không cần cho mục tiêu hiện tại |
| U-mode / S-mode / MMU / PMP | `mstatus.MPP` hardwired `2'b11` |
| Branch predictor (BTB/BHT) | Phase 1 static not-taken |
| I-Cache / D-Cache | Nối thẳng SRAM |
| Bus outstanding > 1 | `PR_BUS_OUTSTANDING` khoá ở 1 |
| Debug module / trigger | — |
| Clock gating | Cấm theo `rtl_rule.md` §4.3 |

---

# 2. PARAMETER

## 2.1 Package constant — `rv32im_pkg`

Hằng cấu trúc, **không** override được per-instance. Dùng bên trong `typedef`.

| Tên | Type | Giá trị | Mô tả |
|---|---|---|---|
| `PR_XLEN` | `int unsigned` | `32` | Độ rộng thanh ghi / datapath |
| `PR_INSTR_W` | `int unsigned` | `32` | Độ rộng instruction word |
| `PR_REG_NUM` | `int unsigned` | `32` | Số thanh ghi kiến trúc |
| `PR_CSR_ADDR_W` | `int unsigned` | `12` | Độ rộng CSR address |
| `LP_REG_ADDR_W` | `int unsigned` | `$clog2(PR_REG_NUM)` = 5 | Độ rộng rs/rd address |
| `LP_SHAMT_W` | `int unsigned` | `$clog2(PR_XLEN)` = 5 | Độ rộng shift amount |
| `LP_BE_W` | `int unsigned` | `PR_XLEN/8` = 4 | Độ rộng byte-enable |
| `LP_EXC_CODE_W` | `int unsigned` | `5` | Độ rộng `mcause[4:0]` |
| `LP_CNT_W` | `int unsigned` | `64` | Độ rộng `mcycle`/`minstret` |
| `LP_MD_CNT_W` | `int unsigned` | `$clog2(PR_XLEN+2)` = 6 | Bộ đếm iteration MULDIV |

## 2.2 Parameter của TOP — `rv32im_core`

Override được khi instantiate. Truyền xuống submodule theo §3.4.

| # | Tên | Type | Default | Range hợp lệ | Mô tả |
|---|---|---|---|---|---|
| P01 | `PR_BOOT_ADDR` | `logic [PR_XLEN-1:0]` | `32'h8000_0000` | align 4 | PC sau reset |
| P02 | `PR_MTVEC_RESET` | `logic [PR_XLEN-1:0]` | `32'h0000_0000` | align 4 | Giá trị `mtvec` sau reset |
| P03 | `PR_HART_ID` | `logic [PR_XLEN-1:0]` | `32'h0` | any | Giá trị `mhartid` (read-only) |
| P04 | `PR_M_EXT_EN` | `bit` | `1` | 0 / 1 | `0` → RV32I thuần, RV32M decode ra Illegal |
| P05 | `PR_MULT_IMPL` | `int unsigned` | `0` | 0 / 1 | `0`=SEQ shift-add (33cy) · `1`=COMB single-cycle (infer DSP) |
| P06 | `PR_DIV_IMPL` | `int unsigned` | `0` | 0 | `0`=SEQ non-restoring (34cy). Chỗ mở rộng radix-4 sau |
| P07 | `PR_CSR_EN` | `bit` | `1` | 0 / 1 | `0` → bỏ CSR file + trap. Chỉ dùng để bring-up M1–M4 |
| P08 | `PR_IRQ_EN` | `bit` | `1` | 0 / 1 | `0` → bỏ `mie`/`mip`, chỉ còn exception đồng bộ |
| P09 | `PR_COUNTER_EN` | `bit` | `1` | 0 / 1 | `0` → `mcycle`/`minstret` đọc ra 0 |
| P10 | `PR_MTVEC_VEC_EN` | `bit` | `0` | 0 / 1 | `1` → hỗ trợ `mtvec.MODE = 1` (Vectored) |
| P11 | `PR_FWD_EN` | `bit` | `1` | 0 / 1 | `0` → bỏ forwarding, hazard chuyển sang stall-only (debug/so sánh IPC) |
| P12 | `PR_RF_RESET_EN` | `bit` | `1` | 0 / 1 | `1` → reset regfile về 0 (sim deterministic) |
| P13 | `PR_RF_IMPL` | `int unsigned` | `0` | 0 / 1 | `0`=flop array · `1`=RAM-style (FPGA LUTRAM/BRAM) |
| P14 | `PR_TRACE_EN` | `bit` | `0` | 0 / 1 | `1` → xuất retire trace port |
| P15 | `PR_BUS_OUTSTANDING` | `int unsigned` | `1` | 1 | Phase 1 khoá ở 1. Có mặt để đánh dấu chỗ mở rộng |

**Ràng buộc elaboration** (kiểm tra bằng `$fatal` trong `initial` của TB, hoặc `assert` static):

| # | Ràng buộc |
|---|---|
| C1 | `PR_BOOT_ADDR[1:0] == 2'b00` |
| C2 | `PR_MTVEC_RESET[1:0] == 2'b00` |
| C3 | `PR_IRQ_EN == 1` → yêu cầu `PR_CSR_EN == 1` |
| C4 | `PR_MTVEC_VEC_EN == 1` → yêu cầu `PR_CSR_EN == 1` |
| C5 | `PR_COUNTER_EN == 1` → yêu cầu `PR_CSR_EN == 1` |
| C6 | `PR_DIV_IMPL == 0` — Phase 1 chỉ có SEQ non-restoring |
| C7 | `PR_BUS_OUTSTANDING == 1` — Phase 1 khoá ở 1 |
| C8 | `PR_RF_IMPL == 1` chỉ hợp lệ khi target là **FPGA** (LUTRAM async-read, §9.4). Target ASIC bắt buộc `PR_RF_IMPL == 0` |

## 2.3 Ma trận parameter → sub-module

| Parameter | core | if | id | decoder | imm_gen | regfile | ex | alu | branch | muldiv | mult | div | mem | lsu | csr | trap | hazard |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `PR_BOOT_ADDR` | ● | ● | | | | | | | | | | | | | | | |
| `PR_MTVEC_RESET` | ● | | | | | | | | | | | | | ● | | | |
| `PR_HART_ID` | ● | | | | | | | | | | | | | ● | | | |
| `PR_M_EXT_EN` | ● | | ● | ● | | | ● | | | ● | | | | | | | |
| `PR_MULT_IMPL` | ● | | | | | | ● | | | ● | ● | | | | | | |
| `PR_DIV_IMPL` | ● | | | | | | ● | | | ● | | ● | | | | | |
| `PR_CSR_EN` | ● | | ● | ● | | | | | | | | | ● | | ● | ● | |
| `PR_IRQ_EN` | ● | | | | | | | | | | | | | | ● | ● | |
| `PR_COUNTER_EN` | ● | | | | | | | | | | | | | | ● | | |
| `PR_MTVEC_VEC_EN` | ● | | | | | | | | | | | | | | ● | ● | |
| `PR_FWD_EN` | ● | | | | | | ● | | | | | | | | | | ● |
| `PR_RF_RESET_EN` | ● | | | | | ● | | | | | | | | | | | |
| `PR_RF_IMPL` | ● | | | | | ● | | | | | | | | | | | |
| `PR_TRACE_EN` | ● | | | | | | | | | | | | ● | | | | |

---

# 3. OVERVIEW — TOP MODULE

## 3.1 Block diagram

```
                                  rv32im_core (TOP)
 ┌───────────────────────────────────────────────────────────────────────────────────┐
 │                                                                                   │
 │   IF                ID                  EX                MEM              WB     │
 │ ┌────────────┐   ┌────────────┐   ┌──────────────┐   ┌──────────────┐             │
 │ │ if_stage   │   │ id_stage   │   │ ex_stage     │   │ mem_stage    │             │
 │ │            │   │ ┌────────┐ │   │ ┌──────────┐ │   │ ┌──────────┐ │             │
 │ │ ┌────────┐ │   │ │decoder │ │   │ │  alu     │ │   │ │  lsu     │ │             │
 │ │ │ pc mux │ │   │ └────────┘ │   │ └──────────┘ │   │ └──────────┘ │             │
 │ │ └────────┘ │   │ ┌────────┐ │   │ ┌──────────┐ │   │              │             │
 │ │            │   │ │imm_gen │ │   │ │ branch   │ │   │  wb mux      │             │
 │ │  I-bus FSM │   │ └────────┘ │   │ └──────────┘ │   │              │             │
 │ │            │   │            │   │ ┌──────────┐ │   │  D-bus FSM   │             │
 │ │            │   │  fwd mux ──┼───┼─│ muldiv   │ │   │              │             │
 │ │            │   │            │   │ │ ├─ mult  │ │   │              │             │
 │ │            │   │            │   │ │ └─ div   │ │   │              │             │
 │ │            │   │            │   │ └──────────┘ │   │              │             │
 │ └─────┬──────┘   └─────┬──────┘   └──────┬───────┘   └──────┬───────┘             │
 │  w_ifid │         w_idex │          w_exmem │          w_memwb │                  │
 │       ══╪═══════════════╪═════════════════╪═════════════════╪═════════════►      │
 │         │               │                 │                 │                     │
 │         │        ┌──────┴──────┐          │                 │  ┌───────────────┐  │
 │         │        │  regfile    │◄─────────┼─────────────────┴──┤ RF write port │  │
 │         │        │  32 x XLEN  │          │                    └───────────────┘  │
 │         │        └─────────────┘          │                                       │
 │         │                                 │  CH03 br redirect                     │
 │         │◄────────────────────────────────┘                                       │
 │         │                                                                         │
 │         │  CH02 trap/mret redirect     ┌──────────────┐   ┌──────────────┐         │
 │         │◄─────────────────────────────┤ trap_ctrl    │◄─►│  csr_file    │         │
 │         │                              └──────┬───────┘   └──────┬───────┘         │
 │         │                                     │                  │ irq             │
 │  ┌──────┴───────────────────────────────────────────────────────────────────────┐ │
 │  │                        hazard_ctrl  (stall / flush / fwd_sel)                 │ │
 │  └──────────────────────────────────────────────────────────────────────────────┘ │
 └───────────────────────────────────────────────────────────────────────────────────┘
        │  I-bus                    │  D-bus                    │ irq_sw/timer/ext
        ▼                           ▼                           ▲
```

## 3.2 Danh sách module

| ID | Module | Loại | Parent | Mục spec |
|---|---|---|---|---|
| U01 | `rv32im_pkg` | package | — | §4.2 |
| U02 | `rv32im_core` | TOP, structural | — | §3 |
| U03 | `rv32im_if_stage` | seq | U02 | §5 |
| U04 | `rv32im_id_stage` | seq | U02 | §6 |
| U05 | `rv32im_decoder` | comb | U04 | §7 |
| U06 | `rv32im_imm_gen` | comb | U04 | §8 |
| U07 | `rv32im_regfile` | seq | U02 | §9 |
| U08 | `rv32im_ex_stage` | seq | U02 | §10 |
| U09 | `rv32im_alu` | comb | U08 | §11 |
| U10 | `rv32im_branch_unit` | comb | U08 | §12 |
| U11 | `rv32im_muldiv` | seq | U08 | §13 |
| U12 | `rv32im_mult` | seq/comb | U11 | §13.4 |
| U13 | `rv32im_div` | seq | U11 | §13.5 |
| U14 | `rv32im_mem_stage` | seq | U02 | §14 |
| U15 | `rv32im_lsu` | comb | U14 | §15 |
| U16 | `rv32im_csr_file` | seq | U02 | §16 |
| U17 | `rv32im_trap_ctrl` | comb | U02 | §17 |
| U18 | `rv32im_hazard_ctrl` | comb | U02 | §18 |
| U19 | `rv32im_clint` | seq | SoC (ngoài lõi) — **optional**, §19.1 | §19 |

> **Không có module `wb_stage`.** Tầng WB chỉ gồm thanh ghi `w_memwb` (nằm trong `mem_stage`)
> nối thẳng vào write port của `regfile` — không có logic nào ngoài đó.
> WB mux được thực hiện ở cuối tầng MEM (§14.4), vì dữ liệu load về trong tầng MEM.

## 3.3 Port list — `rv32im_core`

### Nhóm 1: Clock & Reset

| Port | Dir | Width | Mô tả |
|---|---|---|---|
| `i_clk_core` | in | 1 | Clock duy nhất của lõi |
| `i_resetn_core` | in | 1 | Reset active-low. Async assert, **sync deassert** (synchronizer ở SoC) |

### Nhóm 2: Instruction bus (read-only)

| Port | Dir | Width | Mô tả |
|---|---|---|---|
| `o_imem_req_valid` | out | 1 | Request hợp lệ |
| `i_imem_req_ready` | in | 1 | Slave nhận request |
| `o_imem_req_addr` | out | `PR_XLEN` | Địa chỉ fetch, `[1:0]` luôn `2'b00` |
| `i_imem_rsp_valid` | in | 1 | Response hợp lệ (1 xung / request) |
| `i_imem_rsp_rdata` | in | `PR_XLEN` | Instruction word |
| `i_imem_rsp_err` | in | 1 | `1` → Instruction access fault |

### Nhóm 3: Data bus

| Port | Dir | Width | Mô tả |
|---|---|---|---|
| `o_dmem_req_valid` | out | 1 | Request hợp lệ |
| `i_dmem_req_ready` | in | 1 | Slave nhận request |
| `o_dmem_req_addr` | out | `PR_XLEN` | Địa chỉ word-align, `[1:0]` luôn `2'b00` |
| `o_dmem_req_we` | out | 1 | `1`=store · `0`=load |
| `o_dmem_req_be` | out | `LP_BE_W` | Byte enable (§15.2) |
| `o_dmem_req_wdata` | out | `PR_XLEN` | Store data đã replicate theo lane |
| `i_dmem_rsp_valid` | in | 1 | Response hợp lệ |
| `i_dmem_rsp_rdata` | in | `PR_XLEN` | Load data thô (chưa extract) |
| `i_dmem_rsp_err` | in | 1 | `1` → Load/Store access fault |

### Nhóm 4: Interrupt

| Port | Dir | Width | Mô tả |
|---|---|---|---|
| `i_irq_sw` | in | 1 | Machine software IRQ → `mip.MSIP`. Level-sensitive |
| `i_irq_timer` | in | 1 | Machine timer IRQ → `mip.MTIP`. Level-sensitive |
| `i_irq_ext` | in | 1 | Machine external IRQ → `mip.MEIP`. Level-sensitive |

> Cả 3 pin phải được đồng bộ về `i_clk_core` **ở ngoài lõi**. Lõi không có synchronizer.

### Nhóm 5: Retire trace (chỉ khi `PR_TRACE_EN = 1`)

| Port | Dir | Width | Mô tả |
|---|---|---|---|
| `o_trace_valid` | out | 1 | Có instruction retire trong chu kỳ này |
| `o_trace_pc` | out | `PR_XLEN` | PC của instruction retire |
| `o_trace_instr` | out | `PR_INSTR_W` | Instruction word |
| `o_trace_rd_wen` | out | 1 | Instruction có ghi regfile không |
| `o_trace_rd_addr` | out | `LP_REG_ADDR_W` | Chỉ số thanh ghi đích |
| `o_trace_rd_wdata` | out | `PR_XLEN` | Giá trị đã ghi |

> Khi `PR_TRACE_EN = 0`, các port này vẫn tồn tại nhưng bị tie `'0` — tránh phải sửa
> port list khi đổi parameter. Tool sẽ tự optimize away.

## 3.4 Memory bus protocol

Giao thức 2 kênh decoupled, dùng chung cho cả I-bus và D-bus.

### 3.4.1 Request channel

| # | Rule |
|---|---|
| B1 | Transfer xảy ra tại rising edge khi `o_*_req_valid && i_*_req_ready` |
| B2 | Khi `o_*_req_valid = 1`, toàn bộ payload phải **giữ ổn định** cho tới khi bắt tay xong |
| B3 | `o_*_req_valid` **không** được phụ thuộc tổ hợp vào `i_*_req_ready` (chống combinational loop) |
| B4 | `i_*_req_ready` **được phép** phụ thuộc tổ hợp vào `o_*_req_valid` |
| B5 | Lõi phát tối đa `PR_BUS_OUTSTANDING` = 1 request chưa hoàn tất trên mỗi bus |

### 3.4.2 Response channel

| # | Rule |
|---|---|
| B6 | Mỗi request được chấp nhận sinh **đúng một** xung `i_*_rsp_valid` rộng 1 chu kỳ |
| B7 | Response **in-order** |
| B8 | Lõi **luôn sẵn sàng** nhận response — không có `rsp_ready` |
| B9 | `i_*_rsp_valid` được phép xảy ra **cùng chu kỳ** với bắt tay request (memory latency 0) |
| B10 | Khi `i_*_rsp_err = 1`, `i_*_rsp_rdata` là don't-care |

### 3.4.3 Ảnh hưởng performance

Fetch FSM (§5.4.2) **luôn đi qua `ST_WAIT` ít nhất 1 chu kỳ**, kể cả khi slave trả
response tổ hợp. Đây là lựa chọn có chủ đích: đổi IPC lấy timing closure — đường
`i_imem_rsp_rdata → IF/ID` không bị nối tiếp tổ hợp với `o_imem_req_valid`.

| Memory latency | Chu kỳ / fetch | Hệ quả |
|---|---|---|
| 0 cycle (combinational read) | **2** | IPC trần **0.5**. `ST_IDLE` (phát + bắt tay) → `ST_WAIT` (chốt IF/ID) |
| 1 cycle | **2** | Không tệ hơn latency 0 — `ST_WAIT` vốn đã tốn 1 chu kỳ |
| ≥2 cycle | `1 + latency` | IF stall tương ứng |

> **Cảnh báo khi đo IPC:** penalty load-use (1 cycle, §18.5) và branch (2 cycle, §18.6)
> cộng **thêm** vào baseline 0.5 IPC này, **không** phải cộng vào 1.0.
> Nếu cần IPC = 1 thì phải đổi §5.4.2 sang FSM có nhánh bypass `ST_IDLE → ST_IDLE`
> cho trường hợp latency 0 — thay đổi này nằm ngoài rev 0.3.

### 3.4.4 Waveform — load, latency 1 cycle

```
                  _   _   _   _   _   _
i_clk_core      _/ \_/ \_/ \_/ \_/ \_/ \_
o_dmem_req_valid ___/‾‾‾‾‾\________________
i_dmem_req_ready ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
o_dmem_req_addr  ---< A     >-------------
i_dmem_rsp_valid ____________/‾‾‾‾‾\______
i_dmem_rsp_rdata -------------< D  >------
                      ^          ^
                   accepted     data
```

---

# 4. INTERCONNECT

## 4.1 Bảng channel

Tên net ở TOP dùng prefix `w_` theo `rtl_rule.md` §2.2.

| CH | Từ | Tới | Net / Signal | Width | Reg? | Mô tả |
|---|---|---|---|---|:-:|---|
| CH01 | TOP | tất cả | `i_clk_core`, `i_resetn_core` | 1+1 | — | Clock & reset |
| CH02 | `trap_ctrl` | `if_stage` | `w_redirect_mem_valid`, `w_redirect_mem_pc` | 1+XLEN | N | Trap / MRET / FENCE.I redirect. **Ưu tiên cao** |
| CH03 | `ex_stage` | `if_stage` | `w_redirect_ex_valid`, `w_redirect_ex_pc` | 1+XLEN | N | Branch / Jump taken. **Ưu tiên thấp** |
| CH04 | `if_stage` | `id_stage`, `hazard_ctrl` | `w_ifid` (`ifid_t`) | §4.3 | **Y** | Pipeline reg IF/ID |
| CH05a | `id_stage` | `regfile` | `w_rf_rs1_addr`, `w_rf_rs2_addr` | 5×2 | N | Read address |
| CH05b | `regfile` | `id_stage` | `w_rf_rs1_data`, `w_rf_rs2_data` | XLEN×2 | N | Read data (async) |
| CH06 | `id_stage` | `ex_stage`, `hazard_ctrl` | `w_idex` (`idex_t`) | §4.3 | **Y** | Pipeline reg ID/EX |
| CH07a | `id_stage` | `hazard_ctrl` | `w_id_rs1_addr`, `w_id_rs2_addr`, `w_id_rs1_used`, `w_id_rs2_used` | 5×2+1×2 | N | Pre-register, cho load-use detect |
| CH07b | `hazard_ctrl` | `ex_stage` | `w_fwd_a_sel`, `w_fwd_b_sel` (`fwd_sel_t`) | 2×2 | N | Chọn nguồn forward |
| CH08 | `ex_stage` | `mem_stage`, `hazard_ctrl` | `w_exmem` (`exmem_t`) | §4.3 | **Y** | Pipeline reg EX/MEM |
| CH09 | `mem_stage` | `ex_stage` | `w_fwd_exmem_data` | XLEN | N | Forward path 1 (ALU result / CSR rdata) |
| CH10 | `mem_stage` | `ex_stage`, `regfile` | `w_memwb` (`memwb_t`) | §4.3 | **Y** | Pipeline reg MEM/WB + forward path 2 |
| CH11 | `w_memwb` | `regfile` | `w_rf_wr_en`, `w_rf_wr_addr`, `w_rf_wr_data` | 1+5+XLEN | — | Write port (tầng WB) |
| CH12a | `mem_stage` | `csr_file` | `w_csr_en`, `w_csr_rd_en`, `w_csr_wr_en`, `w_csr_op`, `w_csr_addr`, `w_csr_wdata` | 3+2+12+XLEN | N | CSR access request |
| CH12b | `csr_file` | `mem_stage` | `w_csr_rdata`, `w_csr_illegal` | XLEN+1 | N | CSR read data (**tổ hợp**, §16.3) + illegal flag |
| CH12c | `w_memwb` | `csr_file` | `w_instr_retire` = `w_memwb.valid` | 1 | — | Nguồn tăng `minstret` (§16.9) |
| CH13a | `mem_stage` | `trap_ctrl` | `w_exc_valid`, `w_exc_code`, `w_exc_tval`, `w_mem_pc`, `w_mem_pc_plus4`, `w_mem_instr_valid`, `w_mem_outstanding`, `w_sys_mret`, `w_sys_fencei` | — | N | Nguồn trap từ tầng commit |
| CH13b | `trap_ctrl` | `csr_file` | `w_trap_valid`, `w_trap_is_irq`, `w_trap_code`, `w_trap_tval`, `w_trap_pc`, `w_mret_valid` | — | N | Lệnh cập nhật CSR khi trap |
| CH13c | `csr_file` | `trap_ctrl` | `w_mtvec`, `w_mepc`, `w_mstatus_mie`, `w_irq_pending[2:0]` | — | N | Trạng thái để quyết định trap |
| CH13d | `trap_ctrl` | `mem_stage`, `hazard_ctrl` | `w_trap_taken` | 1 | N | Kill instruction ở MEM, gate D-bus |
| CH14 | TOP | `csr_file` | `i_irq_sw`, `i_irq_timer`, `i_irq_ext` | 3 | N | IRQ pin ngoài |
| CH15 | `hazard_ctrl` | tất cả stage | `w_stall_if/id/ex/mem`, `w_flush_if/id/ex/mem` | 4+4 | N | Điều khiển pipeline |
| CH16 | các stage | `hazard_ctrl` | `w_if_busy`, `w_ex_busy`, `w_mem_busy` | 3 | N | Báo stall nguồn |
| CH17 | `if_stage` | TOP | I-bus (§3.3 nhóm 2) | — | — | Pass-through |
| CH18 | `mem_stage` | TOP | D-bus (§3.3 nhóm 3) | — | — | Pass-through |
| CH19 | `mem_stage` | TOP | Trace port (§3.3 nhóm 5) | — | — | Chỉ khi `PR_TRACE_EN` |

## 4.2 Package `rv32im_pkg` — enum

| Type | Members |
|---|---|
| `alu_op_t` | `ALU_ADD ALU_SUB ALU_SLL ALU_SLT ALU_SLTU ALU_XOR ALU_SRL ALU_SRA ALU_OR ALU_AND ALU_PASS_B` |
| `op_a_sel_t` | `OPA_RS1 OPA_PC OPA_ZERO` |
| `op_b_sel_t` | `OPB_RS2 OPB_IMM` |
| `imm_sel_t` | `IMM_I IMM_S IMM_B IMM_U IMM_J IMM_Z` (`IMM_Z` = CSR uimm) |
| `br_op_t` | `BR_EQ BR_NE BR_LT BR_GE BR_LTU BR_GEU` |
| `mem_size_t` | `SZ_B SZ_H SZ_W` |
| `wb_sel_t` | `WB_ALU WB_MEM WB_PC4 WB_CSR` |
| `csr_op_t` | `CSR_RW CSR_RS CSR_RC` |
| `muldiv_op_t` | `MD_MUL MD_MULH MD_MULHSU MD_MULHU MD_DIV MD_DIVU MD_REM MD_REMU` |
| `fwd_sel_t` | `FWD_NONE FWD_EXMEM FWD_MEMWB` |
| `exc_code_t` | Xem §17.1 |

## 4.3 Pipeline bundle — `typedef struct packed`

Toàn bộ payload giữa các tầng đóng gói thành struct. Lý do: port list gọn, thêm field
không phải sửa mọi module trung gian, và lint bắt được width mismatch.

### `ifid_t` — IF → ID

| Field | Type / Width | Mô tả |
|---|---|---|
| `valid` | 1 | Slot chứa instruction hợp lệ |
| `pc` | `PR_XLEN` | PC của instruction |
| `instr` | `PR_INSTR_W` | Raw instruction word |
| `exc_valid` | 1 | Có exception phát sinh ở IF |
| `exc_code` | `LP_EXC_CODE_W` | Chỉ có thể là `EXC_INSTR_ACCESS` (1) |

### `idex_t` — ID → EX

| Nhóm | Field | Type / Width |
|---|---|---|
| Chung | `valid` | 1 |
| | `pc` | `PR_XLEN` |
| Operand | `rs1_addr`, `rs2_addr` | `LP_REG_ADDR_W` ×2 |
| | `rs1_data`, `rs2_data` | `PR_XLEN` ×2 |
| | `imm` | `PR_XLEN` |
| ALU | `alu_op` | `alu_op_t` |
| | `op_a_sel` | `op_a_sel_t` |
| | `op_b_sel` | `op_b_sel_t` |
| Branch | `br_en` | 1 |
| | `br_op` | `br_op_t` |
| | `jump_en` | 1 (JAL hoặc JALR) |
| | `jalr_en` | 1 |
| MulDiv | `muldiv_en` | 1 |
| | `muldiv_op` | `muldiv_op_t` |
| LSU | `mem_req` | 1 |
| | `mem_we` | 1 |
| | `mem_size` | `mem_size_t` |
| | `mem_unsigned` | 1 |
| WB | `rd_addr` | `LP_REG_ADDR_W` |
| | `rd_wen` | 1 |
| | `wb_sel` | `wb_sel_t` |
| CSR | `csr_en` | 1 |
| | `csr_op` | `csr_op_t` |
| | `csr_addr` | `PR_CSR_ADDR_W` |
| | `csr_rd_en` | 1 (`0` khi `CSRRW/WI` và `rd == x0`) |
| | `csr_wr_en` | 1 (`0` khi `CSRRS/C(I)` và source == 0) |
| | `csr_use_imm` | 1 |
| | `csr_uimm` | `LP_REG_ADDR_W` |
| System | `sys_mret`, `sys_wfi`, `sys_fencei` | 1 ×3 |
| Exception | `exc_valid` | 1 |
| | `exc_code` | `LP_EXC_CODE_W` |
| | `exc_tval` | `PR_XLEN` |
| Instr | `instr` | `PR_INSTR_W` — **luôn có**, không phụ thuộc `PR_TRACE_EN`. Cần cho `mtval` của `EXC_ILLEGAL` phát ở MEM (§14.6 P2) |

### `exmem_t` — EX → MEM

| Nhóm | Field | Type / Width |
|---|---|---|
| Chung | `valid`, `pc` | 1, `PR_XLEN` |
| Data | `alu_result` | `PR_XLEN` (với load/store = địa chỉ) |
| | `store_data` | `PR_XLEN` (rs2 đã forward) |
| | `pc_plus4` | `PR_XLEN` |
| LSU | `mem_req`, `mem_we`, `mem_size`, `mem_unsigned` | như `idex_t` |
| WB | `rd_addr`, `rd_wen`, `wb_sel` | như `idex_t` |
| CSR | `csr_en`, `csr_rd_en`, `csr_wr_en`, `csr_op`, `csr_addr` | như `idex_t` |
| | `csr_wdata` | `PR_XLEN` (đã chọn rs1/uimm) |
| System | `sys_mret`, `sys_fencei` | 1 ×2 |
| Exception | `exc_valid`, `exc_code`, `exc_tval` | như `idex_t` |
| Instr | `instr` | `PR_INSTR_W` — **luôn có**, không phụ thuộc `PR_TRACE_EN`. Cần cho `mtval` của `EXC_ILLEGAL` phát ở MEM (§14.6 P2) |

### `memwb_t` — MEM → WB

| Field | Type / Width | Mô tả |
|---|---|---|
| `valid` | 1 | Instruction retire hợp lệ → tăng `minstret` |
| `pc` | `PR_XLEN` | Debug / trace |
| `rd_addr` | `LP_REG_ADDR_W` | Thanh ghi đích |
| `rd_wen` | 1 | Cho phép ghi regfile |
| `wb_data` | `PR_XLEN` | Dữ liệu **đã mux xong** ở cuối MEM |
| `instr` | `PR_INSTR_W` | Chỉ khi `PR_TRACE_EN` |

---

# 5. U03 — `rv32im_if_stage`

## 5.1 Target

| # | Chức năng |
|---|---|
| T1 | Sinh PC: `reg_pc + 4` hoặc redirect từ EX / MEM |
| T2 | Phát request trên I-bus, nhận instruction |
| T3 | Bắt `i_imem_rsp_err` → gắn cờ `EXC_INSTR_ACCESS` vào instruction |
| T4 | Chứa pipeline register IF/ID |
| T5 | Báo `o_if_busy` khi đang chờ response |

## 5.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_BOOT_ADDR` | `logic [PR_XLEN-1:0]` | `32'h8000_0000` | PC sau reset |

## 5.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Clk/Rst | `i_clk_core` | in | 1 | |
| | `i_resetn_core` | in | 1 | |
| Control | `i_stall` | in | 1 | Giữ nguyên `reg_pc` và IF/ID |
| | `i_flush` | in | 1 | Đặt `o_ifid.valid = 0` |
| Redirect | `i_redirect_mem_valid` | in | 1 | Từ `trap_ctrl`. **Ưu tiên 1** |
| | `i_redirect_mem_pc` | in | `PR_XLEN` | |
| | `i_redirect_ex_valid` | in | 1 | Từ `ex_stage`. **Ưu tiên 2** |
| | `i_redirect_ex_pc` | in | `PR_XLEN` | |
| I-bus | `o_imem_req_valid` | out | 1 | |
| | `i_imem_req_ready` | in | 1 | |
| | `o_imem_req_addr` | out | `PR_XLEN` | |
| | `i_imem_rsp_valid` | in | 1 | |
| | `i_imem_rsp_rdata` | in | `PR_XLEN` | |
| | `i_imem_rsp_err` | in | 1 | |
| Output | `o_ifid` | out | `ifid_t` | Pipeline reg IF/ID |
| Status | `o_if_busy` | out | 1 | `1` khi đã phát request mà chưa có response |

## 5.4 Chức năng

### 5.4.1 PC mux — thứ tự ưu tiên

| Ưu tiên | Điều kiện | `w_pc_nxt` | Lý do |
|---|---|---|---|
| 1 | `i_redirect_mem_valid` | `i_redirect_mem_pc` | Nguồn từ MEM — instruction **cũ hơn** EX, luôn thắng |
| 2 | `i_redirect_ex_valid` | `i_redirect_ex_pc` | Branch / Jump taken |
| 3 | mặc định | `reg_pc + 4` | Static predict-not-taken |

### 5.4.2 Fetch FSM

FSM 2 state. **Mỗi lần fetch bắt buộc đi qua `ST_WAIT` ít nhất 1 chu kỳ**, kể cả khi
slave trả response tổ hợp cùng chu kỳ bắt tay (B9, latency 0). Xem §3.4.3 về hệ quả IPC.

| State | Điều kiện chuyển | State kế | Hành động trong state |
|---|---|---|---|
| `ST_IDLE` | `i_stall` | `ST_IDLE` | `o_imem_req_valid = 0` · `o_if_busy = 0` |
| `ST_IDLE` | `!i_stall && !i_imem_req_ready` | `ST_IDLE` | `o_imem_req_valid = 1`, payload giữ ổn định (B2) · `o_if_busy = 0` |
| `ST_IDLE` | `!i_stall && i_imem_req_ready` | `ST_WAIT` | `o_imem_req_valid = 1` — bắt tay xong · `o_if_busy = 0` |
| `ST_WAIT` | `!w_rsp_seen` | `ST_WAIT` | `o_imem_req_valid = 0` · `o_if_busy = 1` |
| `ST_WAIT` | `w_rsp_seen` | `ST_IDLE` | Ghi `{pc, instr, exc_*}` vào IF/ID · `o_if_busy = 0` |

`w_rsp_seen` phải bao cả trường hợp response về **sớm** ở ngay chu kỳ bắt tay:

```
// bắt response latency-0 tại chu kỳ ST_IDLE có bắt tay
w_handshake    = (reg_state == ST_IDLE) && o_imem_req_valid && i_imem_req_ready;
reg_rsp_early <= w_handshake && i_imem_rsp_valid;          // clear ở chu kỳ sau
reg_rsp_data  <= i_imem_rsp_rdata;                         // enable khi i_imem_rsp_valid
reg_rsp_err   <= i_imem_rsp_err;                           // enable khi i_imem_rsp_valid

w_rsp_seen     = i_imem_rsp_valid || reg_rsp_early;
w_rsp_data     = i_imem_rsp_valid ? i_imem_rsp_rdata : reg_rsp_data;
w_rsp_err      = i_imem_rsp_valid ? i_imem_rsp_err   : reg_rsp_err;
```

Khi có redirect trong lúc `ST_WAIT`: **vẫn phải nhận response** (protocol B6), nhưng
kết quả bị bỏ đi và fetch lại từ PC mới. Không được huỷ request đã bắt tay.

### 5.4.3 Ràng buộc

| # | Ràng buộc |
|---|---|
| I1 | `o_imem_req_addr[1:0]` luôn `2'b00` |
| I2 | `reg_pc[1:0]` luôn `2'b00` — vì không có C-extension và mọi redirect đều align 4 |
| I3 | `o_ifid.exc_valid = 1` khi `i_imem_rsp_err`, `exc_code = EXC_INSTR_ACCESS`, `exc_tval = pc` |

---

# 6. U04 — `rv32im_id_stage`

## 6.1 Target

| # | Chức năng |
|---|---|
| T1 | Gọi `decoder` và `imm_gen` |
| T2 | Phát địa chỉ đọc regfile, nhận dữ liệu |
| T3 | Chuyển `ECALL`/`EBREAK`/illegal thành exception payload |
| T4 | Xuất `rs1_addr`/`rs2_addr`/`rs*_used` (pre-register) cho `hazard_ctrl` |
| T5 | Chứa pipeline register ID/EX |

## 6.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_M_EXT_EN` | `bit` | `1` | Truyền xuống `decoder` |
| `PR_CSR_EN` | `bit` | `1` | Truyền xuống `decoder` |

## 6.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 | |
| Control | `i_stall` | in | 1 | Giữ nguyên ID/EX |
| | `i_flush` | in | 1 | Đặt `o_idex.valid = 0` |
| Input | `i_ifid` | in | `ifid_t` | Từ `if_stage` |
| Regfile | `o_rf_rs1_addr` | out | `LP_REG_ADDR_W` | |
| | `o_rf_rs2_addr` | out | `LP_REG_ADDR_W` | |
| | `i_rf_rs1_data` | in | `PR_XLEN` | Async read |
| | `i_rf_rs2_data` | in | `PR_XLEN` | Async read |
| Hazard | `o_id_rs1_addr` | out | `LP_REG_ADDR_W` | Pre-register, = `o_rf_rs1_addr` |
| | `o_id_rs2_addr` | out | `LP_REG_ADDR_W` | |
| | `o_id_rs1_used` | out | 1 | Instruction thực sự dùng rs1 |
| | `o_id_rs2_used` | out | 1 | Instruction thực sự dùng rs2 |
| Output | `o_idex` | out | `idex_t` | Pipeline reg ID/EX |

## 6.4 Exception phát sinh ở ID

| Điều kiện | `exc_code` | `exc_tval` |
|---|---|---|
| `i_ifid.exc_valid` (từ IF) | Giữ nguyên | Giữ nguyên |
| `decoder.o_illegal` | `EXC_ILLEGAL` (2) | `i_ifid.instr` |
| `decoder.o_sys_ecall` | `EXC_ECALL_M` (11) | `'0` |
| `decoder.o_sys_ebreak` | `EXC_BREAKPOINT` (3) | `i_ifid.pc` |

Ưu tiên: exception từ IF > illegal > ecall/ebreak. Khi có exception, mọi tín hiệu
side-effect phải bị tắt: `rd_wen = 0`, `mem_req = 0`, `csr_en = 0`, `br_en = 0`,
`muldiv_en = 0`. Instruction vẫn chảy tiếp tới MEM để commit trap ở đó.

---

# 7. U05 — `rv32im_decoder`

## 7.1 Target

Thuần combinational. Giải mã 1 instruction word thành toàn bộ control signal.
Mọi encoding không nằm trong bảng §7.4–§7.7 → `o_illegal = 1`.

## 7.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_M_EXT_EN` | `bit` | `1` | `0` → RV32M decode ra illegal |
| `PR_CSR_EN` | `bit` | `1` | `0` → lệnh CSR + `MRET` decode ra illegal |

## 7.3 Port list

| Nhóm | Port | Dir | Width |
|---|---|---|---|
| Input | `i_instr` | in | `PR_INSTR_W` |
| Operand | `o_rs1_addr`, `o_rs2_addr`, `o_rd_addr` | out | `LP_REG_ADDR_W` ×3 |
| | `o_rs1_used`, `o_rs2_used` | out | 1 ×2 |
| ALU | `o_alu_op` | out | `alu_op_t` |
| | `o_op_a_sel` | out | `op_a_sel_t` |
| | `o_op_b_sel` | out | `op_b_sel_t` |
| | `o_imm_sel` | out | `imm_sel_t` |
| Branch | `o_br_en`, `o_jump_en`, `o_jalr_en` | out | 1 ×3 |
| | `o_br_op` | out | `br_op_t` |
| MulDiv | `o_muldiv_en` | out | 1 |
| | `o_muldiv_op` | out | `muldiv_op_t` |
| LSU | `o_mem_req`, `o_mem_we`, `o_mem_unsigned` | out | 1 ×3 |
| | `o_mem_size` | out | `mem_size_t` |
| WB | `o_rd_wen` | out | 1 |
| | `o_wb_sel` | out | `wb_sel_t` |
| CSR | `o_csr_en`, `o_csr_rd_en`, `o_csr_wr_en`, `o_csr_use_imm` | out | 1 ×4 |
| | `o_csr_op` | out | `csr_op_t` |
| | `o_csr_addr` | out | `PR_CSR_ADDR_W` |
| | `o_csr_uimm` | out | `LP_REG_ADDR_W` |
| System | `o_sys_ecall`, `o_sys_ebreak`, `o_sys_mret`, `o_sys_wfi`, `o_sys_fencei` | out | 1 ×5 |
| Status | `o_illegal` | out | 1 |

## 7.4 Opcode map

| `opcode[6:0]` | Tên | Lệnh |
|---|---|---|
| `0110111` | LUI | `LUI` |
| `0010111` | AUIPC | `AUIPC` |
| `1101111` | JAL | `JAL` |
| `1100111` | JALR | `JALR` (funct3 = `000`, khác → illegal) |
| `1100011` | BRANCH | `BEQ BNE BLT BGE BLTU BGEU` |
| `0000011` | LOAD | `LB LH LW LBU LHU` |
| `0100011` | STORE | `SB SH SW` |
| `0010011` | OP-IMM | `ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI` |
| `0110011` | OP | RV32I R-type + RV32M |
| `0001111` | MISC-MEM | `FENCE` (funct3=`000`), `FENCE.I` (funct3=`001`) |
| `1110011` | SYSTEM | `ECALL EBREAK MRET WFI` + CSR |
| khác | — | **Illegal** |

## 7.5 Immediate select

| Opcode | `o_imm_sel` |
|---|---|
| OP-IMM, LOAD, JALR | `IMM_I` |
| STORE | `IMM_S` |
| BRANCH | `IMM_B` |
| LUI, AUIPC | `IMM_U` |
| JAL | `IMM_J` |
| SYSTEM (CSR-immediate) | `IMM_Z` |

## 7.6 RV32M decode (`opcode = 0110011`, `funct7 = 0000001`)

| `funct3` | Lệnh | `o_muldiv_op` |
|---|---|---|
| `000` | `MUL` | `MD_MUL` |
| `001` | `MULH` | `MD_MULH` |
| `010` | `MULHSU` | `MD_MULHSU` |
| `011` | `MULHU` | `MD_MULHU` |
| `100` | `DIV` | `MD_DIV` |
| `101` | `DIVU` | `MD_DIVU` |
| `110` | `REM` | `MD_REM` |
| `111` | `REMU` | `MD_REMU` |

Khi `PR_M_EXT_EN = 0` → toàn bộ nhánh này ra `o_illegal = 1`.

## 7.7 SYSTEM decode (`opcode = 1110011`)

| `funct3` | `rs1`/`uimm` | `funct12` | Lệnh | Ghi chú |
|---|---|---|---|---|
| `000` | `00000` | `0000_0000_0000` | `ECALL` | `rd` phải = `00000` |
| `000` | `00000` | `0000_0000_0001` | `EBREAK` | `rd` phải = `00000` |
| `000` | `00000` | `0011_0000_0010` | `MRET` | `rd` phải = `00000` |
| `000` | `00000` | `0001_0000_0101` | `WFI` | Thực thi như NOP |
| `001` | `rs1` | csr | `CSRRW` | |
| `010` | `rs1` | csr | `CSRRS` | |
| `011` | `rs1` | csr | `CSRRC` | |
| `101` | `uimm5` | csr | `CSRRWI` | |
| `110` | `uimm5` | csr | `CSRRSI` | |
| `111` | `uimm5` | csr | `CSRRCI` | |
| `100` | — | — | **Illegal** | |

**Sinh `o_csr_rd_en` / `o_csr_wr_en`** (quan trọng — quyết định side-effect):

| Lệnh | `o_csr_rd_en` | `o_csr_wr_en` |
|---|---|---|
| `CSRRW` / `CSRRWI` | `rd != x0` | `1` (luôn ghi) |
| `CSRRS` / `CSRRC` | `1` (luôn đọc) | `rs1 != x0` |
| `CSRRSI` / `CSRRCI` | `1` | `uimm != 0` |

## 7.8 Illegal instruction — danh sách điều kiện

| # | Điều kiện |
|---|---|
| L1 | `opcode` không có trong §7.4 |
| L2 | `opcode[1:0] != 2'b11` (dạng compressed, không hỗ trợ) |
| L3 | `funct3` không hợp lệ cho opcode tương ứng |
| L4 | `funct7` sai với R-type (`0000000`/`0100000`/`0000001` tuỳ lệnh) |
| L5 | `SLLI`/`SRLI` mà `instr[31:25] != 7'b0000000`; `SRAI` mà `!= 7'b0100000` |
| L6 | `ECALL`/`EBREAK`/`MRET`/`WFI` mà `rs1 != 0` hoặc `rd != 0` |
| L7 | RV32M khi `PR_M_EXT_EN = 0` |
| L8 | Lệnh CSR / `MRET` khi `PR_CSR_EN = 0` |

> Illegal do **CSR address** không tồn tại hoặc read-only được phát hiện ở `csr_file`
> (§16.6), **không** ở decoder — vì decoder không giữ danh sách CSR.

## 7.9 `o_rs1_used` / `o_rs2_used`

Quan trọng để tránh stall giả trong `hazard_ctrl`.

| Opcode | `rs1_used` | `rs2_used` |
|---|---|---|
| LUI, AUIPC, JAL | 0 | 0 |
| JALR, LOAD, OP-IMM | 1 | 0 |
| BRANCH, STORE, OP | 1 | 1 |
| SYSTEM (CSRR*, không immediate) | 1 | 0 |
| SYSTEM (CSRR*I, ECALL, EBREAK, MRET, WFI) | 0 | 0 |
| MISC-MEM | 0 | 0 |

---

# 8. U06 — `rv32im_imm_gen`

## 8.1 Target

Thuần combinational. Trích và sign/zero-extend immediate theo 6 format.

## 8.2 Port list

| Port | Dir | Width | Mô tả |
|---|---|---|---|
| `i_instr` | in | `PR_INSTR_W` | |
| `i_imm_sel` | in | `imm_sel_t` | |
| `o_imm` | out | `PR_XLEN` | Đã extend đủ `PR_XLEN` bit |

## 8.3 Công thức

| `i_imm_sel` | Công thức |
|---|---|
| `IMM_I` | `{{20{i[31]}}, i[31:20]}` |
| `IMM_S` | `{{20{i[31]}}, i[31:25], i[11:7]}` |
| `IMM_B` | `{{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0}` |
| `IMM_U` | `{i[31:12], 12'b0}` |
| `IMM_J` | `{{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0}` |
| `IMM_Z` | `{27'b0, i[19:15]}` (zero-extend, CSR uimm) |

`shamt` cho `SLLI/SRLI/SRAI` lấy từ `IMM_I[LP_SHAMT_W-1:0]` — không cần đường riêng.

---

# 9. U07 — `rv32im_regfile`

## 9.1 Target

| # | Chức năng |
|---|---|
| T1 | 32 × `PR_XLEN` bit, 2 read port async + 1 write port sync |
| T2 | `x0` hardwired `0` — ghi bị bỏ qua, đọc luôn ra `0` |
| T3 | **Write-first bypass**: cùng chu kỳ `wr_addr == rd_addr` thì read trả `wr_data` |

## 9.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_REG_NUM` | `int unsigned` | `32` | Số thanh ghi |
| `PR_RF_RESET_EN` | `bit` | `1` | `1` → reset toàn bộ về 0 |
| `PR_RF_IMPL` | `int unsigned` | `0` | `0`=flop array · `1`=**LUTRAM async-read** (distributed RAM, FPGA-only — C8). `PR_RF_RESET_EN` bị bỏ qua |

## 9.3 Port list

| Nhóm | Port | Dir | Width |
|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 |
| Read A | `i_rs1_addr` | in | `LP_REG_ADDR_W` |
| | `o_rs1_data` | out | `PR_XLEN` |
| Read B | `i_rs2_addr` | in | `LP_REG_ADDR_W` |
| | `o_rs2_data` | out | `PR_XLEN` |
| Write | `i_wr_en` | in | 1 |
| | `i_wr_addr` | in | `LP_REG_ADDR_W` |
| | `i_wr_data` | in | `PR_XLEN` |

## 9.4 Bypass logic

```
o_rs1_data = (i_rs1_addr == 0)                                    ? '0
           : (i_wr_en && (i_wr_addr == i_rs1_addr))               ? i_wr_data
           :                                                        reg_file[i_rs1_addr];
```

> Nhờ bypass này **không cần** forwarding path WB → ID.

## 9.5 `PR_RF_IMPL = 1` — LUTRAM async-read

Mảng `reg_file` được infer thành **distributed RAM (LUTRAM)**, **không** phải block RAM.
Lý do: §9.1 T1 bắt buộc 2 read port **async**, mà BRAM chỉ có sync read — dùng BRAM sẽ
phải phát `rs*_addr` sớm 1 chu kỳ (từ tầng IF) và đổi hẳn cấu trúc `id_stage` + `ifid_t`.

| # | Yêu cầu khi `PR_RF_IMPL = 1` |
|---|---|
| R1 | Read port giữ nguyên **tổ hợp** — dữ liệu ra cùng chu kỳ với `i_rs*_addr` (§9.3) |
| R2 | Bypass §9.4 làm bằng mux **bên ngoài** mảng RAM — LUTRAM không có write-first |
| R3 | `PR_RF_RESET_EN` bị bỏ qua — LUTRAM không reset được. Sim mất tính deterministic |
| R4 | Chỉ hợp lệ trên **FPGA** (ràng buộc C8). Target ASIC → `PR_RF_IMPL = 0` |

---

# 10. U08 — `rv32im_ex_stage`

## 10.1 Target

| # | Chức năng |
|---|---|
| T1 | Forwarding mux chọn operand thật cho ALU / branch / store data |
| T2 | Gọi `alu`, `branch_unit`, `muldiv` |
| T3 | Tính branch/jump target, phát redirect về IF |
| T4 | Phát hiện `EXC_INSTR_MISALIGNED` và `EXC_LOAD/STORE_MISALIGNED` |
| T5 | Chứa pipeline register EX/MEM |
| T6 | Báo `o_ex_busy` khi MULDIV đang chạy |

## 10.2 Parameter

| Tên | Type | Default |
|---|---|---|
| `PR_M_EXT_EN` | `bit` | `1` |
| `PR_MULT_IMPL` | `int unsigned` | `0` |
| `PR_DIV_IMPL` | `int unsigned` | `0` |
| `PR_FWD_EN` | `bit` | `1` |

## 10.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 | |
| Control | `i_stall` | in | 1 | Giữ nguyên EX/MEM |
| | `i_flush` | in | 1 | Đặt `o_exmem.valid = 0`, huỷ MULDIV |
| Input | `i_idex` | in | `idex_t` | |
| Forward | `i_fwd_a_sel` | in | `fwd_sel_t` | |
| | `i_fwd_b_sel` | in | `fwd_sel_t` | |
| | `i_fwd_exmem_data` | in | `PR_XLEN` | |
| | `i_fwd_memwb_data` | in | `PR_XLEN` | |
| Redirect | `o_redirect_ex_valid` | out | 1 | Branch/Jump taken |
| | `o_redirect_ex_pc` | out | `PR_XLEN` | Target address |
| Output | `o_exmem` | out | `exmem_t` | |
| Status | `o_ex_busy` | out | 1 | MULDIV chưa xong |

## 10.4 Forwarding mux

```
w_op_a_fwd = (i_fwd_a_sel == FWD_EXMEM) ? i_fwd_exmem_data
           : (i_fwd_a_sel == FWD_MEMWB) ? i_fwd_memwb_data
           :                              i_idex.rs1_data;
```
Tương tự cho `w_op_b_fwd` với `rs2_data`. **Store data** dùng chung `w_op_b_fwd`.

Sau forwarding mới tới mux chọn nguồn ALU:

| `op_a_sel` | Giá trị | | `op_b_sel` | Giá trị |
|---|---|---|---|---|
| `OPA_RS1` | `w_op_a_fwd` | | `OPB_RS2` | `w_op_b_fwd` |
| `OPA_PC` | `i_idex.pc` | | `OPB_IMM` | `i_idex.imm` |
| `OPA_ZERO` | `'0` | | | |

## 10.5 Branch / Jump target

| Lệnh | Target | Ghi chú |
|---|---|---|
| BRANCH | `i_idex.pc + i_idex.imm` | Chỉ dùng khi `w_br_take = 1` |
| `JAL` | `i_idex.pc + i_idex.imm` | Luôn taken |
| `JALR` | `(w_op_a_fwd + i_idex.imm) & ~PR_XLEN'(1)` | **Bit 0 luôn bị xoá** |

```
o_redirect_ex_valid = i_idex.valid && !i_idex.exc_valid
                   && ((i_idex.br_en && w_br_take) || i_idex.jump_en);
```

`JAL`/`JALR` ghi `pc + 4` vào `rd` qua `wb_sel = WB_PC4`.

## 10.6 Exception phát sinh ở EX

| Điều kiện | `exc_code` | `exc_tval` |
|---|---|---|
| `o_redirect_ex_valid && o_redirect_ex_pc[1:0] != 0` | `EXC_INSTR_MISALIGNED` (0) | Target address |
| Load, `mem_size = SZ_W`, `addr[1:0] != 0` | `EXC_LOAD_MISALIGNED` (4) | Địa chỉ |
| Load, `mem_size = SZ_H`, `addr[0] != 0` | `EXC_LOAD_MISALIGNED` (4) | Địa chỉ |
| Store, `mem_size = SZ_W`, `addr[1:0] != 0` | `EXC_STORE_MISALIGNED` (6) | Địa chỉ |
| Store, `mem_size = SZ_H`, `addr[0] != 0` | `EXC_STORE_MISALIGNED` (6) | Địa chỉ |

Khi phát hiện: `o_exmem.mem_req = 0` (không phát request ra D-bus) và
`o_redirect_ex_valid = 0` (không redirect PC — trap sẽ redirect ở MEM).

> Misaligned được bắt ở **EX** chứ không phải MEM, để chắc chắn request chưa bao giờ ra bus.

## 10.7 MULDIV interlock

```
o_ex_busy = i_idex.valid && i_idex.muldiv_en && !w_muldiv_done;
```
Khi `o_ex_busy = 1`, `hazard_ctrl` stall IF/ID/EX. Bubble vào MEM **do chính
`ex_stage` sinh ra**, xem §10.8 — không dùng `o_flush_ex`.

`i_flush` huỷ MULDIV đang chạy (reset FSM về IDLE). Từ rev 0.4, `i_flush` của
`ex_stage` **chỉ** đến từ `i_trap_taken` hoặc `i_redirect_mem_valid` (§18.6), nên nó
không còn bật trong lúc MULDIV chạy bình thường.

## 10.8 Bubble khi EX bận (rev 0.4)

`ex_stage` tự chèn bubble vào MEM thay vì mượn `o_flush_ex`:

| # | Quy tắc |
|---|---|
| B1 | `o_exmem.valid = i_idex.valid && !o_ex_busy` — trong lúc MULDIV chạy, MEM nhận bubble |
| B2 | EX/MEM được **ghi** khi `!i_stall \|\| o_ex_busy`; chỉ **giữ** khi bị stall vì lý do khác (D-bus bận) |
| B3 | `i_flush` vẫn thắng cả hai: clear EX/MEM và huỷ MULDIV |

**Lý do tách:** `o_flush_ex` mang nghĩa "huỷ instruction ở EX". Trong lúc MULDIV chạy
thì instruction đó **không** bị huỷ — nó vẫn đang được thực thi. Chỉ cái slot phía sau
nó ở MEM mới cần rỗng. Dùng chung một dây cho hai việc này tạo vòng tổ hợp
`o_ex_busy → o_flush_ex → MULDIV reset → o_ex_busy` và làm lõi treo ở lệnh `MUL` đầu tiên.

---

# 11. U09 — `rv32im_alu`

## 11.1 Target

Thuần combinational, 1 kết quả. Dùng chung cho cả tính địa chỉ load/store (`ALU_ADD`).

## 11.2 Parameter

| Tên | Type | Default |
|---|---|---|
| `PR_XLEN` | `int unsigned` | `32` |

## 11.3 Port list

| Port | Dir | Width |
|---|---|---|
| `i_alu_op` | in | `alu_op_t` |
| `i_op_a` | in | `PR_XLEN` |
| `i_op_b` | in | `PR_XLEN` |
| `o_result` | out | `PR_XLEN` |

## 11.4 Bảng chức năng

| `i_alu_op` | Hành vi | Lệnh dùng |
|---|---|---|
| `ALU_ADD` | `i_op_a + i_op_b` | `ADD ADDI AUIPC LOAD STORE JALR` |
| `ALU_SUB` | `i_op_a - i_op_b` | `SUB` |
| `ALU_SLL` | `i_op_a << i_op_b[LP_SHAMT_W-1:0]` | `SLL SLLI` |
| `ALU_SLT` | `$signed(a) < $signed(b)` | `SLT SLTI` |
| `ALU_SLTU` | `a < b` (unsigned) | `SLTU SLTIU` |
| `ALU_XOR` | `a ^ b` | `XOR XORI` |
| `ALU_SRL` | `a >> b[LP_SHAMT_W-1:0]` | `SRL SRLI` |
| `ALU_SRA` | `$signed(a) >>> b[LP_SHAMT_W-1:0]` | `SRA SRAI` |
| `ALU_OR` | `a \| b` | `OR ORI` |
| `ALU_AND` | `a & b` | `AND ANDI` |
| `ALU_PASS_B` | `i_op_b` | `LUI` |

---

# 12. U10 — `rv32im_branch_unit`

## 12.1 Target

Comparator riêng cho branch, chạy **song song** với ALU (không chiếm ALU) để
đường tính target và đường so sánh không nối tiếp nhau → giảm critical path.

## 12.2 Port list

| Port | Dir | Width |
|---|---|---|
| `i_br_op` | in | `br_op_t` |
| `i_op_a` | in | `PR_XLEN` |
| `i_op_b` | in | `PR_XLEN` |
| `o_br_take` | out | 1 |

## 12.3 Bảng điều kiện

| `i_br_op` | Lệnh | Điều kiện |
|---|---|---|
| `BR_EQ` | `BEQ` | `a == b` |
| `BR_NE` | `BNE` | `a != b` |
| `BR_LT` | `BLT` | `$signed(a) < $signed(b)` |
| `BR_GE` | `BGE` | `$signed(a) >= $signed(b)` |
| `BR_LTU` | `BLTU` | `a < b` |
| `BR_GEU` | `BGEU` | `a >= b` |

---

# 13. U11 — `rv32im_muldiv`

## 13.1 Target

| # | Chức năng |
|---|---|
| T1 | Wrapper cho `mult` và `div`, dùng chung handshake |
| T2 | Multi-cycle, stall tầng EX qua `o_busy` |
| T3 | Xử lý special case chia-0 / overflow **bit-exact** theo spec |
| T4 | Huỷ sạch khi `i_flush` |

## 13.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_M_EXT_EN` | `bit` | `1` | `0` → module rỗng, `o_done` tie `1` |
| `PR_MULT_IMPL` | `int unsigned` | `0` | `0`=SEQ · `1`=COMB |
| `PR_DIV_IMPL` | `int unsigned` | `0` | `0`=SEQ non-restoring |

## 13.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 | |
| Control | `i_flush` | in | 1 | Huỷ ngay, về IDLE |
| | `i_start` | in | 1 | Xung 1 chu kỳ bắt đầu |
| Input | `i_op` | in | `muldiv_op_t` | |
| | `i_op_a`, `i_op_b` | in | `PR_XLEN` ×2 | |
| Output | `o_result` | out | `PR_XLEN` | Hợp lệ khi `o_done` |
| Status | `o_done` | out | 1 | Kết quả sẵn sàng — **xung rộng đúng 1 chu kỳ** |
| | `o_busy` | out | 1 | Đang tính |

**Handshake**

| # | Quy tắc |
|---|---|
| D1 | `i_start` là xung 1 chu kỳ. `i_op` / `i_op_a` / `i_op_b` chỉ cần hợp lệ ở chu kỳ đó — module tự đăng ký |
| D2 | `o_done` rộng **đúng 1 chu kỳ**; `o_result` hợp lệ **chỉ** trong chu kỳ đó |
| D3 | `o_busy = 1` từ chu kỳ sau `i_start` tới hết chu kỳ trước `o_done`. `o_busy` và `o_done` **không bao giờ** bật cùng chu kỳ |
| D4 | Special case §13.5 và `PR_MULT_IMPL = 1`: `o_done = 1` ngay chu kỳ kế `i_start`, `o_busy` không bật chu kỳ nào |
| D5 | `i_flush = 1` → `o_done` và `o_busy` về 0 ngay trong chu kỳ đó, FSM về IDLE, kết quả bị bỏ. Từ rev 0.4, `i_flush` chỉ đến từ trap / MRET / FENCE.I redirect (§10.8), **không** bật trong lúc MULDIV chạy bình thường |
| D6 | Không nhận `i_start` mới khi `o_busy = 1` — `ex_stage` đã stall nên trường hợp này không xảy ra; nếu xảy ra là lỗi (điểm neo assertion) |

**Latency**

| Operation | `PR_MULT_IMPL`/`PR_DIV_IMPL` = 0 | = 1 |
|---|---|---|
| `MUL MULH MULHSU MULHU` | 33 cycle | 1 cycle |
| `DIV DIVU REM REMU` | 34 cycle | — |
| Special case (chia 0 / overflow) | **1 cycle** (early exit) | — |

## 13.4 U12 — `rv32im_mult`

**Chuẩn bị operand** — dùng chung 1 datapath 33×33 cho cả 4 biến thể:

| Lệnh | `op_a` extend | `op_b` extend | Bit lấy ra |
|---|---|---|---|
| `MUL` | any | any | `[PR_XLEN-1:0]` |
| `MULH` | signed → 33b | signed → 33b | `[2*PR_XLEN-1:PR_XLEN]` |
| `MULHSU` | signed → 33b | zero → 33b | `[2*PR_XLEN-1:PR_XLEN]` |
| `MULHU` | zero → 33b | zero → 33b | `[2*PR_XLEN-1:PR_XLEN]` |

| `PR_MULT_IMPL` | Thuật toán | Latency | Ghi chú |
|---|---|---|---|
| `0` (SEQ) | Shift-add radix-2, 1 partial product / cycle | `PR_XLEN + 1` = 33 | Diện tích nhỏ |
| `1` (COMB) | Toán tử `*` 33×33 → 66-bit | 1 | FPGA infer DSP |

## 13.5 U13 — `rv32im_div`

Thuật toán: **non-restoring radix-2**, `PR_XLEN` iteration + 1 fixup = 34 cycle.

**Xử lý dấu (signed):**
- Lấy trị tuyệt đối 2 operand trước khi chia
- `quotient` âm nếu `sign(op_a) ^ sign(op_b)`
- `remainder` mang dấu của `op_a` (dividend)

**Special case — early exit, 1 cycle, bắt buộc bit-exact:**

| Điều kiện | `DIV` | `REM` | `DIVU` | `REMU` |
|---|---|---|---|---|
| `op_b == 0` | `'1` (tất cả bit 1 = −1) | `op_a` | `'1` | `op_a` |
| Overflow: `op_a == {1'b1,{XLEN-1{1'b0}}}` và `op_b == '1` | `op_a` (= −2³¹) | `'0` | n/a | n/a |

> RISC-V **không** raise exception khi chia 0. Đây là điểm khác hầu hết kiến trúc khác.

---

# 14. U14 — `rv32im_mem_stage`

## 14.1 Target

| # | Chức năng |
|---|---|
| T1 | Điều khiển D-bus, gọi `lsu` để format địa chỉ / byte-enable / dữ liệu |
| T2 | Cầu nối tới `csr_file` — **CSR read và write đều xảy ra ở tầng này** |
| T3 | Gom nguồn exception, đẩy sang `trap_ctrl` |
| T4 | Thực hiện **WB mux** ở cuối tầng |
| T5 | Chứa pipeline register MEM/WB |
| T6 | Xuất trace port khi `PR_TRACE_EN = 1` |

## 14.2 Parameter

| Tên | Type | Default |
|---|---|---|
| `PR_CSR_EN` | `bit` | `1` |
| `PR_TRACE_EN` | `bit` | `0` |

## 14.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 | |
| Control | `i_stall` | in | 1 | |
| | `i_flush` | in | 1 | |
| Input | `i_exmem` | in | `exmem_t` | |
| D-bus | `o_dmem_req_valid` | out | 1 | |
| | `i_dmem_req_ready` | in | 1 | |
| | `o_dmem_req_addr` | out | `PR_XLEN` | |
| | `o_dmem_req_we` | out | 1 | |
| | `o_dmem_req_be` | out | `LP_BE_W` | |
| | `o_dmem_req_wdata` | out | `PR_XLEN` | |
| | `i_dmem_rsp_valid` | in | 1 | |
| | `i_dmem_rsp_rdata` | in | `PR_XLEN` | |
| | `i_dmem_rsp_err` | in | 1 | |
| CSR | `o_csr_en` | out | 1 | |
| | `o_csr_rd_en`, `o_csr_wr_en` | out | 1 ×2 | |
| | `o_csr_op` | out | `csr_op_t` | |
| | `o_csr_addr` | out | `PR_CSR_ADDR_W` | |
| | `o_csr_wdata` | out | `PR_XLEN` | |
| | `i_csr_rdata` | in | `PR_XLEN` | |
| | `i_csr_illegal` | in | 1 | CSR không tồn tại / read-only |
| Trap | `o_exc_valid` | out | 1 | |
| | `o_exc_code` | out | `LP_EXC_CODE_W` | |
| | `o_exc_tval` | out | `PR_XLEN` | |
| | `o_mem_pc` | out | `PR_XLEN` | PC của instruction ở MEM |
| | `o_mem_pc_plus4` | out | `PR_XLEN` | Cho `FENCE.I` redirect |
| | `o_mem_instr_valid` | out | 1 | Có instruction hợp lệ ở MEM |
| | `o_mem_outstanding` | out | 1 | D-bus đang có transaction chưa xong |
| | `o_sys_mret`, `o_sys_fencei` | out | 1 ×2 | |
| | `i_trap_taken` | in | 1 | Từ `trap_ctrl` — kill instruction, gate bus |
| Forward | `o_fwd_exmem_data` | out | `PR_XLEN` | Về `ex_stage` (CH09) |
| Output | `o_memwb` | out | `memwb_t` | |
| Status | `o_mem_busy` | out | 1 | Đang chờ `i_dmem_rsp_valid` |
| Trace | `o_trace_*` | out | — | Chỉ khi `PR_TRACE_EN` |

## 14.4 WB mux (cuối tầng MEM)

| `i_exmem.wb_sel` | `w_wb_data` |
|---|---|
| `WB_ALU` | `i_exmem.alu_result` |
| `WB_MEM` | `w_load_data` (từ `lsu`, đã extract + extend) |
| `WB_PC4` | `i_exmem.pc_plus4` |
| `WB_CSR` | `i_csr_rdata` |

> Đặt mux ở MEM (không phải WB) vì load data về trong tầng MEM.
> Nhờ vậy tầng WB không có logic, và `o_memwb.wb_data` dùng thẳng làm forward path 2.

**Forward path 1** (`o_fwd_exmem_data`) là mux giữa `alu_result`, `pc_plus4` và `i_csr_rdata`
— **không** bao gồm `WB_MEM`, vì load data chưa có khi instruction ở EX cần nó
(đó chính là lý do phải có load-use interlock).

## 14.5 Gate D-bus

```
o_dmem_req_valid = i_exmem.valid && i_exmem.mem_req
                && !i_exmem.exc_valid       // đã có exception từ tầng trước
                && !i_trap_taken            // trap commit trong chu kỳ này
                && !reg_req_sent;           // chưa phát request cho instruction này
```

Đây là điều kiện **bắt buộc** để giữ precise exception: store không bao giờ được
ra bus nếu instruction sẽ bị huỷ.

`reg_req_sent` là cờ nội bộ 1 bit của `mem_stage` — đánh dấu instruction hiện tại đã
phát request ra D-bus:

```
reg_req_sent <= 1'b0          khi !i_resetn_core || i_flush
              : 1'b1          khi o_dmem_req_valid && i_dmem_req_ready
              : 1'b0          khi i_dmem_rsp_valid
              : reg_req_sent  còn lại
```

Hai tín hiệu trạng thái dẫn xuất từ nó:

```
o_mem_busy        = (o_dmem_req_valid && !i_dmem_req_ready)   // chờ slave nhận
                  | (reg_req_sent     && !i_dmem_rsp_valid);  // chờ response
o_mem_outstanding = reg_req_sent;                             // → trap_ctrl (CH13a)
```

> **Vế `!i_dmem_req_ready` là bắt buộc** (thêm ở rev 0.4). Rev 0.3 chỉ có vế thứ hai,
> nên khi slave chưa assert `ready` thì `o_mem_busy = 0`, pipeline chạy tiếp và
> **lệnh load/store bị mất hẳn**. `reg_req_sent` chỉ set *sau* khi bắt tay xong nên
> nó không phủ được giai đoạn chờ `ready`.

`o_mem_outstanding` chính là tín hiệu mà §17.7 dùng để **chặn commit trap** khi D-bus
còn transaction chưa hoàn tất.

## 14.6 Exception gom ở MEM

| Ưu tiên | Nguồn | `exc_code` |
|---|---|---|
| 1 | `i_exmem.exc_valid` (mang từ IF/ID/EX) | Giữ nguyên |
| 2 | `i_csr_illegal` | `EXC_ILLEGAL` (2), `tval` = instruction word |
| 3 | `i_dmem_rsp_err && !mem_we` | `EXC_LOAD_ACCESS` (5), `tval` = địa chỉ |
| 4 | `i_dmem_rsp_err && mem_we` | `EXC_STORE_ACCESS` (7), `tval` = địa chỉ |

---

# 15. U15 — `rv32im_lsu`

## 15.1 Target

Thuần combinational. Format địa chỉ, byte-enable, store data; extract + extend load data.

## 15.2 Port list

| Nhóm | Port | Dir | Width |
|---|---|---|---|
| Input | `i_addr` | in | `PR_XLEN` |
| | `i_store_data` | in | `PR_XLEN` |
| | `i_mem_size` | in | `mem_size_t` |
| | `i_mem_we` | in | 1 |
| | `i_mem_unsigned` | in | 1 |
| | `i_rsp_rdata` | in | `PR_XLEN` |
| Bus out | `o_req_addr` | out | `PR_XLEN` |
| | `o_req_be` | out | `LP_BE_W` |
| | `o_req_wdata` | out | `PR_XLEN` |
| Data out | `o_load_data` | out | `PR_XLEN` |
| Status | `o_addr_misaligned` | out | 1 |

## 15.3 Byte enable + store data

`o_req_addr = {i_addr[PR_XLEN-1:2], 2'b00}` — luôn word-align.

| Lệnh | `i_addr[1:0]` | `o_req_be` | `o_req_wdata` |
|---|---|---|---|
| `SB` | `00` | `4'b0001` | `{4{i_store_data[7:0]}}` |
| `SB` | `01` | `4'b0010` | `{4{i_store_data[7:0]}}` |
| `SB` | `10` | `4'b0100` | `{4{i_store_data[7:0]}}` |
| `SB` | `11` | `4'b1000` | `{4{i_store_data[7:0]}}` |
| `SH` | `00` | `4'b0011` | `{2{i_store_data[15:0]}}` |
| `SH` | `10` | `4'b1100` | `{2{i_store_data[15:0]}}` |
| `SW` | `00` | `4'b1111` | `i_store_data` |

> Store data được **replicate** ra toàn bộ lane; slave chỉ ghi lane có `be` bật.

## 15.4 Load extraction

| Lệnh | `i_addr[1:0]` | Lane lấy ra | Extend |
|---|---|---|---|
| `LB` | `00 01 10 11` | `i_rsp_rdata[8*addr +: 8]` | sign |
| `LBU` | `00 01 10 11` | `i_rsp_rdata[8*addr +: 8]` | zero |
| `LH` | `00` / `10` | `[15:0]` / `[31:16]` | sign |
| `LHU` | `00` / `10` | `[15:0]` / `[31:16]` | zero |
| `LW` | `00` | `[31:0]` | — |

## 15.5 Misaligned detect

| Lệnh | Điều kiện `o_addr_misaligned` |
|---|---|
| `LH LHU SH` | `i_addr[0] != 1'b0` |
| `LW SW` | `i_addr[1:0] != 2'b00` |
| `LB LBU SB` | không bao giờ |

> `lsu` được instantiate **hai lần**? Không — chỉ một lần ở `mem_stage`.
> Phần misaligned detect ở EX (§10.6) dùng logic tổ hợp nhỏ riêng, không cần cả module.

**Hệ quả cho `o_addr_misaligned`:** port này **không** nối vào đường exception của
`mem_stage` — tầng EX đã chặn từ trước bằng `mem_req = 0` (§10.6), nên request
misaligned không bao giờ tới được MEM. Port giữ lại làm **điểm neo assertion**:

| # | Bất biến |
|---|---|
| A1 | `o_dmem_req_valid = 1` → `lsu.o_addr_misaligned` phải `= 0`. Nếu vi phạm, logic misaligned ở EX (§10.6) đã sai |

---

# 16. U16 — `rv32im_csr_file`

## 16.1 Target

| # | Chức năng |
|---|---|
| T1 | Lưu trữ 16 CSR M-mode |
| T2 | Thực hiện read-old-then-write đúng semantics `CSRRW/S/C` |
| T3 | Sinh `o_csr_illegal` cho địa chỉ không tồn tại / ghi read-only |
| T4 | Cập nhật `mepc`/`mcause`/`mtval`/`mstatus` khi trap |
| T5 | Khôi phục `mstatus` khi `MRET` |
| T6 | Đếm `mcycle`/`minstret` 64-bit |
| T7 | Ghép `i_irq_*` vào `mip`, sinh `o_irq_pending` |

## 16.2 Parameter

| Tên | Type | Default |
|---|---|---|
| `PR_MTVEC_RESET` | `logic [PR_XLEN-1:0]` | `32'h0` |
| `PR_HART_ID` | `logic [PR_XLEN-1:0]` | `32'h0` |
| `PR_IRQ_EN` | `bit` | `1` |
| `PR_COUNTER_EN` | `bit` | `1` |
| `PR_MTVEC_VEC_EN` | `bit` | `0` |

## 16.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 | |
| CSR access | `i_csr_en` | in | 1 | Có lệnh CSR ở MEM |
| | `i_csr_rd_en`, `i_csr_wr_en` | in | 1 ×2 | Từ decoder (§7.7) |
| | `i_csr_op` | in | `csr_op_t` | |
| | `i_csr_addr` | in | `PR_CSR_ADDR_W` | |
| | `i_csr_wdata` | in | `PR_XLEN` | |
| | `o_csr_rdata` | out | `PR_XLEN` | **Tổ hợp** (async read). Giá trị **trước** khi ghi |
| | `o_csr_illegal` | out | 1 | Tổ hợp. Bắt buộc `= 0` khi `i_csr_en = 0` |
| Trap in | `i_trap_valid` | in | 1 | Từ `trap_ctrl` |
| | `i_trap_is_irq` | in | 1 | |
| | `i_trap_code` | in | `LP_EXC_CODE_W` | |
| | `i_trap_tval` | in | `PR_XLEN` | |
| | `i_trap_pc` | in | `PR_XLEN` | → `mepc` |
| | `i_mret_valid` | in | 1 | |
| Trap out | `o_mtvec` | out | `PR_XLEN` | |
| | `o_mepc` | out | `PR_XLEN` | |
| | `o_mstatus_mie` | out | 1 | |
| | `o_irq_pending` | out | 3 | `{MEI, MTI, MSI}` đã AND với `mie` |
| IRQ | `i_irq_sw`, `i_irq_timer`, `i_irq_ext` | in | 1 ×3 | |
| Counter | `i_instr_retire` | in | 1 | Tăng `minstret`. Nối từ `w_memwb.valid` (CH12c) |

> **`o_csr_rdata` là đường tổ hợp**, không đăng ký. `csr_file` được xếp loại `seq`
> (§3.2) vì giữ state, nhưng read path đọc thẳng mảng CSR theo `i_csr_addr` trong
> **cùng chu kỳ**. Bắt buộc như vậy vì WB mux đặt ở **cuối tầng MEM** (§14.4) và
> forward path 1 (CH09) đều tiêu thụ `i_csr_rdata` ngay trong chu kỳ đó.
>
> Ghi CSR xảy ra ở clock edge **cuối** chu kỳ → semantics read-old-then-write (§16.6)
> tự thoả mãn, **không** cần logic bypass riêng.
>
> Đánh đổi: đường `i_csr_addr → mảng CSR → WB mux → w_memwb` trở thành ứng viên
> critical path thứ hai (§22 O2).

## 16.4 Address map

| Addr | Tên | R/W | Reset | Ghi chú |
|---|---|---|---|---|
| `0x300` | `mstatus` | RW | `'0` | Chỉ MIE/MPIE/MPP live |
| `0x301` | `misa` | RW (WARL) | `0x4000_1100` | MXL=1, ext I+M. Ghi bị bỏ qua |
| `0x304` | `mie` | RW | `'0` | Chỉ MSIE/MTIE/MEIE writable |
| `0x305` | `mtvec` | RW (WARL) | `PR_MTVEC_RESET` | MODE tuỳ `PR_MTVEC_VEC_EN` |
| `0x310` | `mstatush` | RW (WARL) | `'0` | RV32-only, mọi field hardwired 0. Ghi được chấp nhận nhưng vô tác dụng, **không** illegal — vì `addr[11:10] == 2'b00` nên X2 (§16.6) không áp dụng |
| `0x340` | `mscratch` | RW | `'0` | 32-bit tự do |
| `0x341` | `mepc` | RW (WARL) | `'0` | `[1:0]` hardwired `0` |
| `0x342` | `mcause` | RW | `'0` | `{irq, 26'b0, code[4:0]}` |
| `0x343` | `mtval` | RW | `'0` | 32-bit tự do |
| `0x344` | `mip` | RO\* | `'0` | Do pin ngoài drive |
| `0xB00` | `mcycle` | RW | `'0` | Low 32 |
| `0xB02` | `minstret` | RW | `'0` | Low 32 |
| `0xB80` | `mcycleh` | RW | `'0` | High 32 |
| `0xB82` | `minstreth` | RW | `'0` | High 32 |
| `0xF11` | `mvendorid` | RO | `'0` | |
| `0xF12` | `marchid` | RO | `'0` | |
| `0xF13` | `mimpid` | RO | `'0` | |
| `0xF14` | `mhartid` | RO | `PR_HART_ID` | |

\* `mip` chấp nhận lệnh ghi nhưng mọi bit read-only → ghi không tác dụng,
**không** raise exception (khác với `0xF1x` là read-only theo `addr[11:10]`).

## 16.5 Field layout

**`mstatus` (0x300)**

| Bit | Tên | Hành vi |
|---|---|---|
| 3 | `MIE` | Global machine interrupt enable |
| 7 | `MPIE` | Giá trị `MIE` trước trap |
| 12:11 | `MPP` | Hardwired `2'b11` (M-mode only) |
| còn lại | — | Hardwired 0, ghi bị bỏ qua (WPRI) |

**`mie` (0x304) / `mip` (0x344)**

| Bit | `mie` | `mip` | Nguồn `mip` |
|---|---|---|---|
| 3 | `MSIE` | `MSIP` | `i_irq_sw` |
| 7 | `MTIE` | `MTIP` | `i_irq_timer` |
| 11 | `MEIE` | `MEIP` | `i_irq_ext` |
| còn lại | 0 | 0 | Hardwired |

**`mtvec` (0x305)**

| Bit | Tên | Hành vi |
|---|---|---|
| 31:2 | `BASE` | Writable |
| 1:0 | `MODE` | `PR_MTVEC_VEC_EN=0` → hardwired `2'b00`, ghi khác bị bỏ qua (WARL)<br>`=1` → chấp nhận `00` (Direct) và `01` (Vectored), giá trị ≥ `10` bị ép về `00` |

**`mcause` (0x342)** = `{i_trap_is_irq, 26'b0, i_trap_code[4:0]}`

## 16.6 Semantics lệnh CSR

| Lệnh | `o_csr_rdata` | Giá trị ghi |
|---|---|---|
| `CSRRW` / `CSRRWI` | CSR cũ (nếu `csr_rd_en`) | `i_csr_wdata` |
| `CSRRS` / `CSRRSI` | CSR cũ | `csr_old \| i_csr_wdata` |
| `CSRRC` / `CSRRCI` | CSR cũ | `csr_old & ~i_csr_wdata` |

**Bắt buộc:** `o_csr_rdata` là giá trị **trước** khi ghi, kể cả khi `rd` và CSR nguồn trùng nhau.

**Điều kiện `o_csr_illegal = 1`:**

| # | Điều kiện |
|---|---|
| X1 | `i_csr_addr` không nằm trong §16.4 |
| X2 | `i_csr_wr_en = 1` và `i_csr_addr[11:10] == 2'b11` (CSR read-only theo chuẩn RISC-V) |

## 16.7 Trap update (1 chu kỳ, khi `i_trap_valid`)

```
mepc         <= i_trap_pc;                          // PC của instruction bị trap
mcause       <= {i_trap_is_irq, 26'b0, i_trap_code};
mtval        <= i_trap_tval;
mstatus.MPIE <= mstatus.MIE;
mstatus.MIE  <= 1'b0;                               // chống trap lồng nhau
mstatus.MPP  <= 2'b11;
```

> `mepc` lưu PC của **chính instruction bị trap**, không phải `pc + 4`.
> Với `ECALL`/`EBREAK`, handler phải tự `mepc += 4` trước `MRET`, nếu không lặp vô hạn.
> Đây là hành vi **đúng spec**, không phải bug.

## 16.8 MRET update (khi `i_mret_valid`)

```
mstatus.MIE  <= mstatus.MPIE;
mstatus.MPIE <= 1'b1;
mstatus.MPP  <= 2'b11;
```

## 16.9 Counter

| CSR | Điều kiện tăng |
|---|---|
| `mcycle` (64-bit) | Mỗi chu kỳ sau khi `i_resetn_core` deassert, **kể cả khi stall** |
| `minstret` (64-bit) | `i_instr_retire = 1` |

Implement như **một** counter 64-bit duy nhất với 2 write port riêng cho nửa thấp/cao,
để ghi `mcycleh` không làm mất carry đang xảy ra ở nửa thấp.

Khi `PR_COUNTER_EN = 0`: 4 CSR này đọc ra `'0`, ghi bị bỏ qua, không illegal.

## 16.10 Ưu tiên ghi CSR

Khi cùng chu kỳ có cả lệnh CSR và trap:

| Ưu tiên | Nguồn |
|---|---|
| 1 | `i_trap_valid` — trap update (§16.7) |
| 2 | `i_mret_valid` — MRET update (§16.8) |
| 3 | `i_csr_wr_en` — lệnh CSR |

Trường hợp 1 và 3 xảy ra cùng lúc nghĩa là chính lệnh CSR đó bị trap → ghi CSR
phải bị huỷ.

> **Gating trap nằm ở `csr_file`, KHÔNG ở `mem_stage`** (đổi ở rev 0.4).
> `w_wr_commit` của `csr_file` đã có sẵn `&& !i_trap_valid` nên việc ghi CSR bị huỷ
> đúng như yêu cầu.
>
> Rev 0.3 bắt `mem_stage` đặt `o_csr_wr_en = 0` khi `i_trap_taken = 1`. Cách đó sinh
> **combinational loop**:
> `i_trap_taken → o_csr_wr_en → o_csr_illegal (X2) → o_exc_valid → i_trap_taken`.
>
> Về mặt kiến trúc cũng sai: một lệnh CSR **illegal hay không** là thuộc tính của
> encoding (§16.6 X1/X2), không được phụ thuộc vào việc nó có bị huỷ hay không.
> Vì vậy `mem_stage` truyền thẳng `o_csr_wr_en = i_exmem.csr_wr_en`.

---

# 17. U17 — `rv32im_trap_ctrl`

## 17.1 Target

| # | Chức năng |
|---|---|
| T1 | Quyết định có trap hay không tại **commit point = tầng MEM** |
| T2 | Chọn ưu tiên giữa interrupt và các exception đồng bộ |
| T3 | Sinh redirect PC cho trap / `MRET` / `FENCE.I` |
| T4 | Đảm bảo precise exception |

## 17.2 Parameter

| Tên | Type | Default |
|---|---|---|
| `PR_IRQ_EN` | `bit` | `1` |
| `PR_MTVEC_VEC_EN` | `bit` | `0` |

## 17.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| Exception in | `i_exc_valid` | in | 1 | Từ `mem_stage` |
| | `i_exc_code` | in | `LP_EXC_CODE_W` | |
| | `i_exc_tval` | in | `PR_XLEN` | |
| Context | `i_mem_pc` | in | `PR_XLEN` | |
| | `i_mem_pc_plus4` | in | `PR_XLEN` | Cho `FENCE.I` |
| | `i_mem_instr_valid` | in | 1 | |
| | `i_mem_outstanding` | in | 1 | D-bus đang bận |
| | `i_sys_mret`, `i_sys_fencei` | in | 1 ×2 | |
| CSR state | `i_mtvec` | in | `PR_XLEN` | |
| | `i_mepc` | in | `PR_XLEN` | |
| | `i_mstatus_mie` | in | 1 | |
| | `i_irq_pending` | in | 3 | `{MEI, MTI, MSI}` |
| CSR out | `o_trap_valid` | out | 1 | |
| | `o_trap_is_irq` | out | 1 | |
| | `o_trap_code` | out | `LP_EXC_CODE_W` | |
| | `o_trap_tval` | out | `PR_XLEN` | |
| | `o_trap_pc` | out | `PR_XLEN` | → `mepc` |
| | `o_mret_valid` | out | 1 | |
| Redirect | `o_redirect_mem_valid` | out | 1 | → `if_stage` |
| | `o_redirect_mem_pc` | out | `PR_XLEN` | |
| Pipeline | `o_trap_taken` | out | 1 | → `mem_stage`, `hazard_ctrl` |

## 17.4 Exception code (`mcause[31] = 0`)

| Code | Enum | Tên | Phát hiện ở | `mtval` |
|---|---|---|---|---|
| 0 | `EXC_INSTR_MISALIGNED` | Instruction address misaligned | EX | Target address |
| 1 | `EXC_INSTR_ACCESS` | Instruction access fault | IF | PC |
| 2 | `EXC_ILLEGAL` | Illegal instruction | ID / MEM (CSR) | Instruction word |
| 3 | `EXC_BREAKPOINT` | Breakpoint (`EBREAK`) | ID | PC |
| 4 | `EXC_LOAD_MISALIGNED` | Load address misaligned | EX | Địa chỉ |
| 5 | `EXC_LOAD_ACCESS` | Load access fault | MEM | Địa chỉ |
| 6 | `EXC_STORE_MISALIGNED` | Store address misaligned | EX | Địa chỉ |
| 7 | `EXC_STORE_ACCESS` | Store access fault | MEM | Địa chỉ |
| 11 | `EXC_ECALL_M` | Environment call from M-mode | ID | `'0` |

## 17.5 Interrupt code (`mcause[31] = 1`)

| Code | Enum | Điều kiện taken |
|---|---|---|
| 3 | `IRQ_M_SOFT` | `mip.MSIP && mie.MSIE && mstatus.MIE` |
| 7 | `IRQ_M_TIMER` | `mip.MTIP && mie.MTIE && mstatus.MIE` |
| 11 | `IRQ_M_EXT` | `mip.MEIP && mie.MEIE && mstatus.MIE` |

`mtval = '0` với mọi interrupt.

> **Level-sensitive.** Lõi không tự clear `mip`. Phần mềm phải xử lý nguồn ngắt
> (ghi `mtimecmp`, đọc UART...) để pin ngoài hạ xuống — nếu không, trap tái phát ngay sau `MRET`.

## 17.6 Ưu tiên

| Ưu tiên | Nguồn |
|---|---|
| 1 | **Interrupt** (nếu enabled) — luôn thắng exception đồng bộ |
| 2 | `EXC_INSTR_ACCESS` (IF) |
| 3 | `EXC_ILLEGAL` / `EXC_ECALL_M` / `EXC_BREAKPOINT` (ID) |
| 4 | `EXC_INSTR_MISALIGNED` (EX) |
| 5 | `EXC_LOAD_MISALIGNED` / `EXC_STORE_MISALIGNED` (EX) |
| 6 | `EXC_LOAD_ACCESS` / `EXC_STORE_ACCESS` (MEM) |

Giữa các interrupt: **MEI (11) > MSI (3) > MTI (7)** — theo priv spec.

> Vì interrupt thắng exception, instruction bị "cướp" sẽ chạy lại sau `MRET`
> (`mepc` = PC của nó) và exception đồng bộ mới raise khi đó. Đúng semantics.

## 17.7 Điều kiện commit trap

```
w_irq_req   = PR_IRQ_EN && i_mstatus_mie && (|i_irq_pending);

o_trap_taken = i_mem_instr_valid
            && !i_mem_outstanding          // <-- ràng buộc bắt buộc, xem dưới
            && (i_exc_valid || w_irq_req);
```

**Ràng buộc `!i_mem_outstanding`:** không được commit trap khi D-bus đang có
transaction chưa hoàn tất. Nếu vi phạm, một store đã ra bus nhưng instruction bị huỷ
→ **phá precise exception**. Phải chờ `i_dmem_rsp_valid` rồi mới trap.

## 17.8 Precise exception — cơ chế

| # | Yêu cầu |
|---|---|
| E1 | Mọi instruction **trước** instruction trap đã hoàn tất (regfile + memory) |
| E2 | Instruction trap và mọi instruction **sau** nó không để lại dấu vết |

Cơ chế thực hiện:

1. Exception phát hiện ở IF/ID/EX **không** trap tại chỗ. Chúng được đóng gói thành
   `{exc_valid, exc_code, exc_tval}` và **đi theo pipeline register** như payload.
2. Tại MEM, `trap_ctrl` chốt `o_trap_taken`.
3. `o_trap_taken = 1` gây:
   - Flush IF, ID, EX (bubble)
   - Kill WB của instruction ở MEM: `o_memwb.rd_wen = 0`, `o_memwb.valid = 0`
   - Gate D-bus: `o_dmem_req_valid = 0` (§14.5)
   - Gate CSR write: `o_csr_wr_en = 0`
   - Redirect PC về `mtvec`
4. Instruction đang ở **WB** (cũ hơn) vẫn hoàn tất bình thường — đúng E1.

## 17.9 Redirect PC

| Ưu tiên | Điều kiện | `o_redirect_mem_pc` |
|---|---|---|
| 1 | `o_trap_taken` | Direct: `{i_mtvec[31:2], 2'b00}`<br>Vectored: `{i_mtvec[31:2],2'b00} + (o_trap_code << 2)` — **chỉ khi** `PR_MTVEC_VEC_EN == 1` **và** `i_mtvec[1:0] == 2'b01` **và** `o_trap_is_irq == 1` |
| 2 | `i_sys_mret` | `i_mepc` |
| 3 | `i_sys_fencei` | `i_mem_pc_plus4` |

Cả 3 trường hợp đều flush IF, ID, EX (tên port cụ thể: §18.6).

> **Vectored chỉ áp dụng cho interrupt.** Exception đồng bộ luôn nhảy tới `BASE`
> kể cả khi `mtvec.MODE = 1` — đúng priv spec.

## 17.10 `WFI` và `FENCE`

| Lệnh | Hành vi Phase 1 | Lý do |
|---|---|---|
| `WFI` | **NOP** | Spec cho phép WFI hoàn thành ngay. Clock gating để Phase sau |
| `FENCE` | **NOP** | Không có store buffer, không reorder, không agent khác |
| `FENCE.I` | **Flush + refetch từ `pc + 4`** | Instruction sau nó có thể đã nằm trong IF/ID trước khi store sửa code hoàn tất |

---

# 18. U18 — `rv32im_hazard_ctrl`

## 18.1 Target

| # | Chức năng |
|---|---|
| T1 | Sinh `fwd_a_sel` / `fwd_b_sel` cho `ex_stage` |
| T2 | Phát hiện load-use, sinh stall |
| T3 | Gom mọi nguồn stall/flush thành tín hiệu cho từng tầng |

## 18.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_FWD_EN` | `bit` | `1` | `0` → không forward, chuyển sang stall-only |

## 18.3 Port list

| Nhóm | Port | Dir | Width | Mô tả |
|---|---|---|---|---|
| ID info | `i_id_rs1_addr`, `i_id_rs2_addr` | in | `LP_REG_ADDR_W` ×2 | Pre-register |
| | `i_id_rs1_used`, `i_id_rs2_used` | in | 1 ×2 | |
| EX info | `i_idex_valid` | in | 1 | |
| | `i_idex_rs1_addr`, `i_idex_rs2_addr` | in | `LP_REG_ADDR_W` ×2 | |
| | `i_idex_rd_addr` | in | `LP_REG_ADDR_W` | |
| | `i_idex_rd_wen` | in | 1 | |
| | `i_idex_mem_req`, `i_idex_mem_we` | in | 1 ×2 | Nhận diện load |
| MEM info | `i_exmem_rd_addr` | in | `LP_REG_ADDR_W` | |
| | `i_exmem_rd_wen` | in | 1 | |
| | `i_exmem_wb_sel` | in | `wb_sel_t` | |
| WB info | `i_memwb_rd_addr` | in | `LP_REG_ADDR_W` | |
| | `i_memwb_rd_wen` | in | 1 | |
| Busy | `i_if_busy`, `i_ex_busy`, `i_mem_busy` | in | 1 ×3 | |
| Redirect | `i_redirect_ex_valid` | in | 1 | |
| | `i_redirect_mem_valid` | in | 1 | |
| | `i_trap_taken` | in | 1 | |
| Forward out | `o_fwd_a_sel`, `o_fwd_b_sel` | out | `fwd_sel_t` ×2 | |
| Stall out | `o_stall_if`, `o_stall_id`, `o_stall_ex`, `o_stall_mem` | out | 1 ×4 | |
| Flush out | `o_flush_if`, `o_flush_id`, `o_flush_ex`, `o_flush_mem` | out | 1 ×4 | |

## 18.4 Forwarding

| Ưu tiên | `o_fwd_a_sel` | Điều kiện |
|---|---|---|
| 1 | `FWD_EXMEM` | `i_exmem_rd_wen && i_exmem_rd_addr != 0 && i_exmem_rd_addr == i_idex_rs1_addr` |
| 2 | `FWD_MEMWB` | `i_memwb_rd_wen && i_memwb_rd_addr != 0 && i_memwb_rd_addr == i_idex_rs1_addr` |
| 3 | `FWD_NONE` | mặc định |

Tương tự cho `o_fwd_b_sel` với `i_idex_rs2_addr`.

**Chốt chặn `WB_MEM`:** `FWD_EXMEM` **không** được chọn khi `i_exmem_wb_sel == WB_MEM`,
vì forward path 1 (§14.4) không mang load data. Về lý thuyết trường hợp này không thể
xảy ra — load-use interlock §18.5 đã đẩy consumer lùi 1 chu kỳ nên khi nó vào EX thì
load đã nằm ở MEM/WB. Giữ điều kiện làm **defensive check** và điểm neo assertion.

### 18.4.1 Khi `PR_FWD_EN = 0`

`o_fwd_a_sel` / `o_fwd_b_sel` luôn trả `FWD_NONE`, và §18.5 được **thay thế** bằng:

```
w_raw_ex   = i_idex_valid && i_idex_rd_wen && (i_idex_rd_addr != '0)
          && ( (i_id_rs1_used && i_idex_rd_addr  == i_id_rs1_addr)
            || (i_id_rs2_used && i_idex_rd_addr  == i_id_rs2_addr) );

w_raw_mem  = i_exmem_rd_wen && (i_exmem_rd_addr != '0)
          && ( (i_id_rs1_used && i_exmem_rd_addr == i_id_rs1_addr)
            || (i_id_rs2_used && i_exmem_rd_addr == i_id_rs2_addr) );

w_load_use = w_raw_ex | w_raw_mem;      // thay cho §18.5 khi PR_FWD_EN = 0
```

**Không** bao RAW với MEM/WB: khi producer tới tầng WB nó đang drive write port của
regfile, và **write-first bypass** §9.4 đã trả đúng giá trị mới cho `id_stage` ngay
trong chu kỳ đó. Bao thêm MEM/WB sẽ stall dư 1 chu kỳ và làm sai lệch phép đo IPC —
vốn là mục đích duy nhất của `PR_FWD_EN = 0` (§2.2 P11).

Penalty tối đa khi `PR_FWD_EN = 0`: **2 cycle** (producer đi EX → MEM → WB, consumer
chờ ở ID hai chu kỳ rồi vào EX).

## 18.5 Load-use interlock

```
w_load_use = i_idex_valid
          && i_idex_mem_req && !i_idex_mem_we          // là load
          && i_idex_rd_addr != '0
          && ( (i_id_rs1_used && i_idex_rd_addr == i_id_rs1_addr)
            || (i_id_rs2_used && i_idex_rd_addr == i_id_rs2_addr) );
```

Hành động: stall IF, ID · bubble vào EX. Penalty **1 cycle**.

> `i_id_rs*_used` là bắt buộc — nếu bỏ, `LUI`/`AUIPC`/`JAL` (không dùng rs nào)
> sẽ bị stall giả vì trường `rs1_addr` trong encoding của chúng là don't-care.

## 18.6 Bảng stall / flush tổng hợp

**Định nghĩa port flush — đọc trước bảng:**

> **`o_flush_X` clear pipeline register ở ĐẦU RA của tầng X.**

| Port | Đi tới | Register bị clear | Kết quả |
|---|---|---|---|
| `o_flush_if` | `if_stage.i_flush` | `w_ifid` (IF/ID) | bubble vào **ID** |
| `o_flush_id` | `id_stage.i_flush` | `w_idex` (ID/EX) | bubble vào **EX** |
| `o_flush_ex` | `ex_stage.i_flush` | `w_exmem` (EX/MEM) | bubble vào **MEM** |
| `o_flush_mem` | `mem_stage.i_flush` | `w_memwb` (MEM/WB) | bubble vào **WB** |

Chỉ có **4** port flush. Không có `o_flush_wb` vì không có module `wb_stage` (§3.2) —
`o_flush_mem` đã bao tầng WB.

| Sự kiện | Nguồn | Stall | Flush (tên port) |
|---|---|---|---|
| I-bus chưa response | `i_if_busy` | IF | — |
| Load-use | `w_load_use` | IF, ID | `o_flush_id` |
| MULDIV đang chạy | `i_ex_busy` | IF, ID, EX | — · `ex_stage` **tự** chèn bubble (§10.8) |
| D-bus chưa response | `i_mem_busy` | IF, ID, EX, MEM | `o_flush_mem` |
| Branch/Jump taken | `i_redirect_ex_valid` | — | `o_flush_if`, `o_flush_id` |
| Trap taken | `i_trap_taken` | — | `o_flush_if`, `o_flush_id`, `o_flush_ex`, `o_flush_mem` |
| MRET / FENCE.I | `i_redirect_mem_valid` | — | `o_flush_if`, `o_flush_id`, `o_flush_ex` |

> Hàng **Trap taken** dùng cả 4 port: ba port đầu xoá 3 instruction trẻ hơn, còn
> `o_flush_mem` kill chính instruction bị trap đang ở MEM (`o_memwb.valid = 0`,
> `o_memwb.rd_wen = 0`) — khớp §17.8 bước 3.
>
> Hàng **Load-use** dùng `o_flush_id` (clear ID/EX) chứ **không** phải `o_flush_ex`:
> load đang ở EX phải chảy tiếp sang MEM bình thường, chỉ slot phía sau nó mới thành
> bubble.
>
> ⚠ **Hàng MULDIV KHÔNG dùng `o_flush_ex`** (đổi ở rev 0.4). Nếu dùng thì sinh
> combinational loop và **treo lõi**: `o_flush_ex` phải bật suốt 33–34 chu kỳ để giữ
> bubble ở MEM, nhưng cùng dây đó lại huỷ MULDIV (§10.3, §13.3 D5) ⇒ MULDIV bị reset
> mỗi cạnh clock, `i_ex_busy` kẹt ở 1 vĩnh viễn.
> `o_flush_ex` vì vậy **chỉ** đến từ `i_trap_taken` và `i_redirect_mem_valid` — đúng
> hai trường hợp thật sự phải huỷ MULDIV. Việc chèn bubble vào MEM chuyển sang cho
> `ex_stage` tự làm, xem §10.8.

**Quy tắc bất biến:** khi tầng N stall thì mọi tầng **trước** N cũng phải stall, và
tầng N+1 nhận bubble. Không bao giờ được stall tầng sau mà không stall tầng trước
→ sẽ mất instruction.

```
o_stall_mem = i_mem_busy;
o_stall_ex  = o_stall_mem | i_ex_busy;
o_stall_id  = o_stall_ex  | w_load_use;
o_stall_if  = o_stall_id  | i_if_busy;
```

## 18.7 Structural hazard

Không có: I-bus và D-bus tách rời, regfile 2R1W, mỗi tầng đúng 1 instruction.

---

# 19. U19 — `rv32im_clint` (ngoài lõi)

## 19.1 Target

Peripheral trên D-bus, cung cấp `i_irq_timer` và `i_irq_sw` cho lõi.
**Không** thuộc `rv32im_core` — nằm ở tầng SoC.

> **Phạm vi sinh RTL:** U19 là **optional**, nằm **ngoài** `rv32im_core`.
> Sinh và verify lõi (U01–U18) trước; CLINT sinh ở bước SoC.
> Verify của lõi drive `i_irq_sw` / `i_irq_timer` / `i_irq_ext` **trực tiếp từ
> testbench** — không phụ thuộc U19. Chỉ milestone **M9** (§21) mới cần U19.

## 19.2 Parameter

| Tên | Type | Default | Mô tả |
|---|---|---|---|
| `PR_CLINT_BASE` | `logic [PR_XLEN-1:0]` | `32'h0200_0000` | Base address |
| `PR_MTIME_W` | `int unsigned` | `64` | Độ rộng `mtime` |

## 19.3 Register map

| Offset | Tên | Width | R/W | Mô tả |
|---|---|---|---|---|
| `0x0000` | `msip` | 32 | RW | Bit 0 → `o_irq_sw` |
| `0x4000` | `mtimecmp` | 64 | RW | Ngưỡng so sánh (low @ `0x4000`, high @ `0x4004`) |
| `0xBFF8` | `mtime` | 64 | RW | Bộ đếm tự do (low @ `0xBFF8`, high @ `0xBFFC`) |

`o_irq_timer = (reg_mtime >= reg_mtimecmp)`

## 19.4 Port list

| Nhóm | Port | Dir | Width |
|---|---|---|---|
| Clk/Rst | `i_clk_core`, `i_resetn_core` | in | 1 ×2 |
| Bus slave | `i_req_valid` | in | 1 |
| | `o_req_ready` | out | 1 |
| | `i_req_addr` | in | `PR_XLEN` |
| | `i_req_we` | in | 1 |
| | `i_req_be` | in | `LP_BE_W` |
| | `i_req_wdata` | in | `PR_XLEN` |
| | `o_rsp_valid` | out | 1 |
| | `o_rsp_rdata` | out | `PR_XLEN` |
| | `o_rsp_err` | out | 1 |
| IRQ out | `o_irq_sw` | out | 1 |
| | `o_irq_timer` | out | 1 |

---

# 20. FILE LAYOUT

```
rtl/
├── rv32im_pkg.sv              // U01 — typedef, enum, hằng ISA
├── rv32im_core.sv             // U02 — TOP, structural
├── rv32im_if_stage.sv         // U03
├── rv32im_id_stage.sv         // U04
├── rv32im_decoder.sv          // U05
├── rv32im_imm_gen.sv          // U06
├── rv32im_regfile.sv          // U07
├── rv32im_ex_stage.sv         // U08
├── rv32im_alu.sv              // U09
├── rv32im_branch_unit.sv      // U10
├── rv32im_muldiv.sv           // U11
├── rv32im_mult.sv             // U12
├── rv32im_div.sv              // U13
├── rv32im_mem_stage.sv        // U14
├── rv32im_lsu.sv              // U15
├── rv32im_csr_file.sv         // U16
├── rv32im_trap_ctrl.sv        // U17
└── rv32im_hazard_ctrl.sv      // U18

rtl/soc/                       // ngoài phạm vi lõi
├── rv32im_clint.sv            // U19
├── rv32im_ram_sp.sv
└── rv32im_soc_top.sv
```

---

# 21. MILESTONE

| Phase | Module | Definition of Done |
|---|---|---|
| M0 | U01, U05, U06, U09, U07 | Decode đúng toàn bộ opcode map §7.4; ALU đúng bảng §11.4 |
| M1 | U03, U04, U08, U14, U02 | Pipeline 5 tầng chạy chuỗi lệnh tuần tự, chưa forwarding |
| M2 | U18 | Forwarding + load-use; không còn stall dư ngoài load-use |
| M3 | U10 + redirect | Control flow đúng, penalty 2 cycle |
| M4 | U15 | 8 lệnh load/store đúng ở cả 4 offset; misaligned detect đúng |
| M5 | U16 | Read-old-then-write đúng; `o_csr_illegal` đúng §16.6 |
| M6 | U17 (exception) | `ECALL`/`EBREAK`/illegal/misaligned precise |
| M7 | U17 (interrupt) + `MRET` | Priority đúng §17.6; ràng buộc `!i_mem_outstanding` §17.7 |
| M8 | U11, U12, U13 | Toàn bộ special case §13.5 bit-exact |
| M9 | U19 + SoC top | Timer interrupt chạy được end-to-end |

---

# 22. OPEN ITEM

| # | Hạng mục | Ảnh hưởng |
|---|---|---|
| O1 | **Target công nghệ** — FPGA (board nào?) / ASIC / chỉ mô phỏng? | Quyết định default của `PR_MULT_IMPL` và `PR_RF_IMPL`. **Đã một phần thành ràng buộc C8** (rev 0.3): `PR_RF_IMPL = 1` dùng LUTRAM nên chỉ hợp lệ trên FPGA |
| O2 | **Timing constraint** — chưa có mục tiêu tần số | 2 critical path dự kiến:<br>(a) `fwd mux → ALU → branch resolve → PC mux`<br>(b) `i_csr_addr → mảng CSR (async read) → WB mux → w_memwb` — mới từ rev 0.3 §16.3 |
| O3 | **`PR_TRACE_EN` bật hay tắt mặc định?** | Nếu định co-sim với Spike thì phải bật từ M1, thêm sau sẽ phải sửa nhiều bundle |
| O4 | **Bus outstanding > 1** | Muốn pipeline fetch thì phải tách address/data phase ở `if_stage` |
| O5 | **`PR_MTVEC_VEC_EN` có cần không?** | Hiện default `0`; riscv-arch-test không bắt buộc Vectored |

---

# 23. CHANGELOG

## rev 0.4 — sửa 3 lỗi phát hiện khi sinh RTL (`/rtl_generator`)

Cả ba đều là lỗi thật, không phải mơ hồ. Hai cái đầu do full-design lint bắt được
(`UNOPTFLAT` — circular combinational logic), cái thứ ba phát hiện khi viết `mem_stage`.

| # | Mục sửa | Vấn đề và cách sửa |
|---|---|---|
| 1 | §18.6 · §10.7 · **§10.8 mới** · §13.3 D5 | **Treo lõi ở lệnh `MUL` đầu tiên.** `o_flush_ex` mang hai nghĩa trái ngược: §18.6 bắt bật suốt 33–34 chu kỳ để giữ bubble ở MEM, còn §10.3/§13.3 D5 bắt nó huỷ MULDIV ⇒ MULDIV reset mỗi cạnh clock, `i_ex_busy` kẹt ở 1. **Sửa:** bỏ `i_ex_busy` khỏi `o_flush_ex`; `ex_stage` tự chèn bubble theo §10.8 B1–B3. `o_flush_ex` giờ chỉ đến từ trap / MRET / FENCE.I. |
| 2 | §16.10 | **Combinational loop** `i_trap_taken → o_csr_wr_en → o_csr_illegal → o_exc_valid → i_trap_taken`. Cũng sai kiến trúc: tính illegal của một encoding không được phụ thuộc việc lệnh có bị huỷ hay không. **Sửa:** bỏ yêu cầu `mem_stage` gate `o_csr_wr_en` bằng `i_trap_taken`; `csr_file.w_wr_commit` vốn đã có `!i_trap_valid`. |
| 3 | §14.5 | **Mất lệnh load/store.** `o_mem_busy` chỉ có vế `reg_req_sent && !rsp_valid`, không phủ giai đoạn chờ `i_dmem_req_ready`. Slave chưa nhận request mà pipeline vẫn chạy tiếp. **Sửa:** thêm vế `(o_dmem_req_valid && !i_dmem_req_ready)`. |

> Cả ba lỗi đều được đưa vào rev 0.3 bởi chính đợt sửa trước; #1 và #2 là hệ quả trực
> tiếp của việc rev 0.3 chuẩn hoá `o_flush_X` và siết `§16.10` mà không kiểm tra vòng
> tổ hợp.

## rev 0.3 — giải quyết 8 điểm mơ hồ phát hiện ở Phase 1 (`/spec_parser`)

| # | Mục sửa | Nội dung |
|---|---|---|
| 1 | §1.1 F01 · §1.1.1 *(mới)* | Liệt kê tường minh 40 lệnh RV32I. `FENCE.I` / `CSRR*` / `MRET` / `WFI` **không** tính vào 40 |
| 2 | §5.4.2 · §3.4.3 | Fetch FSM **luôn qua `ST_WAIT` ≥1 chu kỳ**. Bảng state viết lại đủ 5 hàng + `w_rsp_seen` cho latency 0. §3.4.3 sửa: IPC trần **0.5**, không phải "đạt IPC lý thuyết" |
| 3 | §9.2 · §9.5 *(mới)* · C8 | `PR_RF_IMPL = 1` = **LUTRAM async-read** (không phải BRAM). Thêm R1–R4 và ràng buộc FPGA-only |
| 4 | §4.3 `idex_t` / `exmem_t` | Field `instr` thành **vô điều kiện** — cần cho `mtval` của `EXC_ILLEGAL` phát ở MEM (§14.6 P2) khi `PR_TRACE_EN = 0` |
| 5 | §16.3 | `o_csr_rdata` là **đường tổ hợp** (async read), không đăng ký. Read-old-then-write tự thoả, không cần bypass riêng |
| 6 | §18.4.1 *(mới)* | Phương trình stall đầy đủ cho `PR_FWD_EN = 0`: bao ID/EX + EX/MEM, **không** bao MEM/WB (write-first bypass §9.4 đã lo). Penalty tối đa 2 cycle |
| 7 | §18.6 | Định nghĩa `o_flush_X` = clear register đầu ra tầng X. Bảng viết lại theo tên port. Xoá tham chiếu `o_flush_wb` — port này chưa từng tồn tại trong §18.3 |
| 8 | §19.1 | CLINT (U19) đánh dấu **optional**, ngoài phạm vi sinh RTL của lõi. Verify lõi drive IRQ pin trực tiếp từ testbench |

## rev 0.3 — sửa thêm (mâu thuẫn / thiếu sót phát hiện trong lúc parse)

| # | Mục sửa | Nội dung |
|---|---|---|
| 9 | §2.2 | Thêm C6 (`PR_DIV_IMPL == 0`), C7 (`PR_BUS_OUTSTANDING == 1`), C8 (LUTRAM FPGA-only) — trước đây chỉ nằm ở cột "Range hợp lệ", không phải ràng buộc elaboration |
| 10 | §4.1 CH12a | Bổ sung `w_csr_rd_en` / `w_csr_wr_en` — có ở §14.3 và §16.3 nhưng thiếu trong bảng channel |
| 11 | §4.1 CH12c *(mới)* | Thêm channel `w_memwb.valid` → `csr_file.i_instr_retire`. Trước rev 0.3, `i_instr_retire` **không có nguồn drive** nào trong §4.1 |
| 12 | §4.1 CH13a | Bổ sung `w_mem_pc_plus4` — có ở §14.3 và §17.3 nhưng thiếu trong bảng channel |
| 13 | §13.3 D1–D6 *(mới)* | Định nghĩa handshake MULDIV: `o_done` là **xung 1 chu kỳ**, `o_busy`/`o_done` không chồng nhau, hành vi khi `i_flush` |
| 14 | §14.5 | Định nghĩa `reg_req_sent` — trước đây dùng trong công thức gate D-bus nhưng không khai báo ở đâu. Kèm quan hệ với `o_mem_busy` / `o_mem_outstanding` |
| 15 | §15.5 | Làm rõ `lsu.o_addr_misaligned` **không** nối vào đường exception (EX đã chặn từ §10.6) — chỉ là điểm neo assertion A1 |
| 16 | §16.4 | `mstatush` đổi `RO` → `RW (WARL)`. Nhãn `RO` cũ mâu thuẫn với X2 (§16.6): `addr[11:10] == 2'b00` nên ghi **không** raise illegal |
| 17 | §17.9 | Vectored mode **chỉ** áp dụng cho interrupt; exception đồng bộ luôn nhảy `BASE` |
| 18 | §18.4 | Chốt chặn `FWD_EXMEM` khi `i_exmem_wb_sel == WB_MEM` — làm cho port `i_exmem_wb_sel` (§18.3) có tác dụng thay vì khai báo rồi bỏ trống |
| 19 | §22 O1, O2 | O1 đã một phần thành C8. O2 bổ sung critical path thứ hai qua đường CSR read tổ hợp |

---

**Tài liệu liên quan:**
- `rtl_rule.md` — RTL coding & naming rule (**bắt buộc tuân thủ**)
- `spec_verify.md` — Verification plan *(chưa tạo)*
- `spec_soc.md` — Memory map, peripheral, boot flow *(chưa tạo)*
