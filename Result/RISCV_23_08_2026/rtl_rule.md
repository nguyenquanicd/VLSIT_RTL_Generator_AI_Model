# RTL Coding Rule — RV32IM Project

| Mục | Giá trị |
|---|---|
| Ngôn ngữ | SystemVerilog-2012, synthesizable subset |
| Áp dụng cho | Toàn bộ file trong `rtl/` |
| Revision | 1.0 |

> Mọi tên tín hiệu trong `spec_parser.md` đều tuân theo tài liệu này.
> Khi có xung đột, **tài liệu này là nguồn chuẩn**.

---

## 1. Naming Convention — Tổng hợp

### 1.1 Bảng prefix (bắt buộc)

| Đối tượng | Prefix / Pattern | Ví dụ |
|---|---|---|
| Port input | `i_` | `i_alu_op`, `i_rs1_data` |
| Port output | `o_` | `o_result`, `o_br_taken` |
| Port bidirectional | `io_` | `io_pad_gpio` |
| Clock input | `i_clk_<domain>` | `i_clk_core` |
| Clock output | `o_clk_<domain>` | `o_clk_periph` |
| Reset input (active-LOW) | `i_resetn_<domain>` | `i_resetn_core` |
| Reset output (active-LOW) | `o_resetn_<domain>` | `o_resetn_core` |
| Register (gán trong `always_ff`) | `reg_` | `reg_pc`, `reg_mstatus_mie` |
| Wire / combinational | `w_` | `w_pc_nxt`, `w_alu_result` |
| Parameter | `PR_` | `PR_BOOT_ADDR`, `PR_XLEN` |
| Localparam | `LP_` | `LP_BE_W`, `LP_SHAMT_W` |
| Typedef (struct / enum) | hậu tố `_t` | `alu_op_t`, `idex_t` |
| Enum member | `UPPER_SNAKE` | `ALU_ADD`, `WB_SEL_MEM` |
| Package | hậu tố `_pkg` | `rv32im_pkg` |
| Module | `rv32im_<chức_năng>` | `rv32im_ex_stage` |
| Instance | `u_<tên_module_rút_gọn>` | `u_alu`, `u_ex_stage` |
| Generate block label | `g_` | `g_mult_seq` |
| Named `always` block | `p_` | `p_pc_update` |
| Assertion label | `a_` | `a_no_x_on_pc` |
| Macro (`define`) | `` | `RV32IM_ASSERT` |

### 1.2 Quy tắc bổ sung

| Quy tắc | Nội dung |
|---|---|
| **Active-low** | Chỉ dùng cho reset. Mọi tín hiệu điều khiển khác là **active-high**. Nếu bắt buộc phải có active-low khác, thêm hậu tố `_n`: `w_ready_n` |
| **Chữ** | Toàn bộ `lower_snake_case`, trừ `PR_`/`LP_`/enum member/macro |
| **Viết tắt** | Chỉ dùng danh sách chuẩn ở §1.3. Không tự chế |
| **Độ dài** | Tối đa 40 ký tự |
| **Cặp reg/wire** | Giá trị next của flop `reg_x` phải tên là `w_x_nxt` |
| **Cấm** | Tên trùng keyword SV (`input`, `logic`, `bit`, `time`, `wire`, `reg`, `signal`, `output`) |
| **Cấm** | Prefix trần (`i_`, `o_`, `w_`, `reg_` đứng một mình) |

### 1.3 Từ viết tắt được phép

| Viết tắt | Nghĩa | Viết tắt | Nghĩa |
|---|---|---|---|
| `addr` | address | `req` | request |
| `rdata` | read data | `rsp` | response |
| `wdata` | write data | `be` | byte enable |
| `en` | enable | `sel` | select |
| `nxt` | next | `cnt` | counter |
| `instr` | instruction | `exc` | exception |
| `irq` | interrupt request | `br` | branch |
| `fwd` | forward | `imm` | immediate |
| `rf` | register file | `lsu` | load-store unit |
| `csr` | control & status register | `pc` | program counter |
| `wb` | write back | `hz` | hazard |

---

## 2. Naming theo vị trí

### 2.1 Port

```systemverilog
input  logic                   i_clk_core,
input  logic                   i_resetn_core,
input  logic                   i_stall,
input  logic [PR_XLEN-1:0]     i_op_a,
output logic [PR_XLEN-1:0]     o_result,
output logic                   o_busy
```

**Nhóm tiền tố theo channel** khi port thuộc một giao thức:

```systemverilog
// I-bus: <dir>_<bus>_<channel>_<field>
output logic                   o_imem_req_valid,
input  logic                   i_imem_req_ready,
output logic [PR_XLEN-1:0]     o_imem_req_addr,
input  logic                   i_imem_rsp_valid,
input  logic [PR_XLEN-1:0]     i_imem_rsp_rdata
```

### 2.2 Internal signal

| Loại | Prefix | Sinh ra từ |
|---|---|---|
| Flop output | `reg_` | `always_ff` |
| Next-state của flop | `w_` + hậu tố `_nxt` | `always_comb` / `assign` |
| Combinational thuần | `w_` | `always_comb` / `assign` |
| Net nối 2 instance ở tầng cha | `w_` | khai báo trong module cha |

```systemverilog
logic [PR_XLEN-1:0] reg_pc;      // flop
logic [PR_XLEN-1:0] w_pc_nxt;    // next value
logic [PR_XLEN-1:0] w_pc_plus4;  // combinational thuần

always_comb begin : p_pc_mux
  w_pc_plus4 = reg_pc + PR_XLEN'(4);
  w_pc_nxt   = w_pc_plus4;
  if (i_redirect_valid) w_pc_nxt = i_redirect_pc;
end

always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_pc_reg
  if (!i_resetn_core)   reg_pc <= PR_BOOT_ADDR;
  else if (!i_stall)    reg_pc <= w_pc_nxt;
end
```

### 2.3 Parameter vs Localparam

| Loại | Prefix | Được override? | Dùng khi |
|---|---|---|---|
| `parameter` | `PR_` | **Có** | Người dùng lõi được phép đổi |
| `localparam` | `LP_` | **Không** | Giá trị suy ra từ `PR_`, hoặc hằng nội bộ |

```systemverilog
parameter  int unsigned PR_BUS_DATA_W = 32;
localparam int unsigned LP_BE_W       = PR_BUS_DATA_W / 8;   // suy ra
```

**Cấm hardcode số** trong RTL. Mọi hằng phải là `PR_`, `LP_`, hoặc enum member trong `rv32im_pkg`.
Ngoại lệ duy nhất được phép: `0`, `1` dùng làm giá trị boolean/increment.

### 2.4 Type

```systemverilog
typedef enum logic [3:0] {
  ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
  ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND, ALU_PASS_B
} alu_op_t;

typedef struct packed {
  logic                  valid;
  logic [PR_XLEN-1:0]    pc;
  logic [PR_INSTR_W-1:0] instr;
} ifid_t;
```

---

## 3. Module Structure

### 3.1 Thứ tự khai báo trong module

```
1. Header comment
2. module <name>
3. import <pkg>::*
4. #( parameter list )       -- PR_* trước, PR_* suy ra sau
5. ( port list )             -- theo thứ tự §3.2
6. localparam LP_*
7. Khai báo signal (reg_* rồi w_*)
8. always_comb / assign
9. always_ff
10. Instance submodule (u_*)
11. Assertion (bọc trong `ifndef SYNTHESIS)
12. endmodule
```

### 3.2 Thứ tự port

| Thứ tự | Nhóm |
|---|---|
| 1 | `i_clk_*` |
| 2 | `i_resetn_*` |
| 3 | Control input (`i_stall`, `i_flush`, `i_en`) |
| 4 | Data input theo luồng dataflow |
| 5 | Data output theo luồng dataflow |
| 6 | Status output (`o_busy`, `o_valid`, `o_error`) |
| 7 | Bus / external interface |
| 8 | Debug / trace (bọc bằng `PR_*_EN`) |

Mỗi nhóm cách nhau 1 dòng trống + comment `// ---- <tên nhóm> ----`.

### 3.3 Header template

```systemverilog
//==============================================================================
// Module      : rv32im_alu
// Description : Arithmetic Logic Unit cho RV32I. Thuần combinational.
// Parent      : rv32im_ex_stage
// Spec ref    : spec_parser.md §7.3
//==============================================================================
```

### 3.4 Template hoàn chỉnh

```systemverilog
//==============================================================================
// Module      : rv32im_alu
// Description : ALU cho RV32I, thuần combinational
// Parent      : rv32im_ex_stage
// Spec ref    : spec_parser.md §7.3
//==============================================================================
module rv32im_alu
  import rv32im_pkg::*;
#(
  parameter int unsigned PR_XLEN = 32
) (
  // ---- Data input ----
  input  alu_op_t            i_alu_op,
  input  logic [PR_XLEN-1:0] i_op_a,
  input  logic [PR_XLEN-1:0] i_op_b,

  // ---- Data output ----
  output logic [PR_XLEN-1:0] o_result
);

  localparam int unsigned LP_SHAMT_W = $clog2(PR_XLEN);

  logic [LP_SHAMT_W-1:0] w_shamt;
  logic [PR_XLEN-1:0]    w_result;

  assign w_shamt = i_op_b[LP_SHAMT_W-1:0];

  always_comb begin : p_alu_op_mux
    w_result = '0;                        // default -> chống latch
    unique case (i_alu_op)
      ALU_ADD    : w_result = i_op_a + i_op_b;
      ALU_SUB    : w_result = i_op_a - i_op_b;
      ALU_SLL    : w_result = i_op_a << w_shamt;
      ALU_SLT    : w_result = PR_XLEN'($signed(i_op_a) < $signed(i_op_b));
      ALU_SLTU   : w_result = PR_XLEN'(i_op_a < i_op_b);
      ALU_XOR    : w_result = i_op_a ^ i_op_b;
      ALU_SRL    : w_result = i_op_a >> w_shamt;
      ALU_SRA    : w_result = PR_XLEN'($signed(i_op_a) >>> w_shamt);
      ALU_OR     : w_result = i_op_a | i_op_b;
      ALU_AND    : w_result = i_op_a & i_op_b;
      ALU_PASS_B : w_result = i_op_b;
      default    : w_result = '0;
    endcase
  end

  assign o_result = w_result;

endmodule
```

---

## 4. Coding Rule

### 4.1 Bắt buộc

| # | Rule |
|---|---|
| R1 | Sequential logic **chỉ** dùng `always_ff @(posedge i_clk_<d> or negedge i_resetn_<d>)` |
| R2 | Combinational logic **chỉ** dùng `always_comb` hoặc `assign` |
| R3 | Trong `always_ff` chỉ dùng `<=`. Trong `always_comb` chỉ dùng `=`. **Không trộn** |
| R4 | Mọi `always_comb` phải **gán default cho toàn bộ output** ở dòng đầu → chống latch |
| R5 | Một signal chỉ được driver bởi **đúng một** `always` block hoặc `assign` |
| R6 | Mọi `case` phải có `default`. Dùng `unique case` cho enum đã liệt kê đủ |
| R7 | Kiểu dữ liệu dùng `logic`. **Cấm** `reg`, `wire`, `integer` trong RTL |
| R8 | Mọi block `always` phải có label `p_<tên>` |
| R9 | Một file = một module. Tên file = tên module + `.sv` |
| R10 | Width phải khớp tường minh. Dùng cast `PR_XLEN'(...)` thay vì để tool tự pad |
| R11 | Mọi module có clock phải nhận đủ `i_clk_*` + `i_resetn_*`. Module thuần comb **không** được có port clock |

### 4.2 Reset policy

| Loại flop | Cần reset? |
|---|---|
| Control flop (`valid`, FSM state, handshake) | **Bắt buộc** |
| CSR | **Bắt buộc** (giá trị theo spec) |
| Datapath flop (pipeline payload: pc, instr, alu_result...) | Không bắt buộc — tiết kiệm diện tích |
| Regfile | Theo `PR_RF_RESET_EN` |

Lý do bỏ reset datapath: `valid = 0` đã đảm bảo payload không bao giờ được dùng.

**Reset scheme:** asynchronous assert, **synchronous deassert**. Bộ đồng bộ reset nằm ở SoC top, ngoài lõi.

```systemverilog
always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_valid_reg
  if (!i_resetn_core) reg_valid <= 1'b0;
  else                reg_valid <= w_valid_nxt;
end
```

### 4.3 Clock policy

| Rule |
|---|
| Phase 1 chỉ có **một** clock domain: `i_clk_core` |
| **Cấm** gated clock trong RTL. Dùng enable trên flop (`if (i_en)`) |
| **Cấm** dùng cạnh xuống (`negedge i_clk_core`) |
| **Cấm** dùng clock làm data, hoặc data làm clock |
| Nếu sau này có nhiều domain: mọi crossing phải qua module `rv32im_cdc_*` chuyên dụng |

### 4.4 Cấm tuyệt đối

| # | Cấm | Lý do |
|---|---|---|
| P1 | `#delay` trong RTL | Không synthesize |
| P2 | `initial` block trong RTL | Chỉ dùng trong TB |
| P3 | `casex`, `casez` | Sinh mismatch sim/synth với `x`/`z` |
| P4 | `defparam` | Dùng `#()` khi instantiate |
| P5 | Implicit net (không khai báo mà dùng) | Bật `` `default_nettype none `` đầu file, `` `default_nettype wire `` cuối file |
| P6 | `always @(*)` | Dùng `always_comb` |
| P7 | Latch có chủ ý | — |
| P8 | Multi-driven net | — |
| P9 | Function có side effect / `static` variable | — |
| P10 | Số hardcode (magic number) | Xem §2.3 |
| P11 | `$random`, `$display` trong RTL | Chỉ trong TB |
| P12 | Port kiểu `inout` bên trong lõi | Chỉ được ở IO pad tầng SoC |

### 4.5 Instantiate

Luôn dùng **named port connection** và **named parameter**:

```systemverilog
rv32im_alu #(
  .PR_XLEN   (PR_XLEN)
) u_alu (
  .i_alu_op  (w_ex_alu_op),
  .i_op_a    (w_ex_op_a),
  .i_op_b    (w_ex_op_b),
  .o_result  (w_ex_alu_result)
);
```

Cấm positional connection (`.*` cũng cấm — làm khó trace tín hiệu).

---

## 5. Comment

| Loại | Quy tắc |
|---|---|
| Module header | Bắt buộc, theo §3.3 |
| Nhóm port | `// ---- <tên nhóm> ----` |
| Signal khai báo | Comment 1 dòng nếu tên chưa tự giải thích |
| Logic phức tạp | Comment **tại sao**, không comment **cái gì** |
| Ngôn ngữ | Tiếng Anh cho comment trong RTL, tiếng Việt cho spec `.md` |
| Cấm | Comment code chết. Xoá luôn, git giữ lịch sử |

---

## 6. Assertion (tuỳ chọn, khuyến khích)

Đặt cuối module, bọc bằng guard để không ảnh hưởng synthesis:

```systemverilog
`ifndef SYNTHESIS
  a_pc_aligned : assert property (
    @(posedge i_clk_core) disable iff (!i_resetn_core)
    (reg_valid |-> (reg_pc[1:0] == 2'b00))
  ) else $error("PC misaligned: %h", reg_pc);
`endif
```

---

## 7. Checklist trước khi commit

| # | Hạng mục | Đạt |
|---|---|---|
| 1 | Lint sạch (0 warning về latch, width, multi-driver, incomplete case) | ☐ |
| 2 | Toàn bộ tên tuân §1.1 | ☐ |
| 3 | Không còn magic number | ☐ |
| 4 | Mọi `always_comb` có default assignment | ☐ |
| 5 | Mọi `case` có `default` | ☐ |
| 6 | Mọi control flop có reset | ☐ |
| 7 | Không có construct trong §4.4 | ☐ |
| 8 | Instance dùng named connection | ☐ |
| 9 | Module header đầy đủ + trỏ đúng mục spec | ☐ |
| 10 | Elaborate không warning | ☐ |

---

## 8. Ví dụ đối chiếu Đúng / Sai

| Sai | Đúng | Lý do |
|---|---|---|
| `input clk` | `input logic i_clk_core` | Thiếu prefix, thiếu type |
| `input rst_n` | `input logic i_resetn_core` | Sai pattern reset |
| `reg [31:0] pc;` | `logic [PR_XLEN-1:0] reg_pc;` | Cấm `reg`, thiếu prefix, magic width |
| `wire [31:0] alu_out;` | `logic [PR_XLEN-1:0] w_alu_result;` | Cấm `wire`, thiếu prefix |
| `parameter BOOT = 32'h8000_0000;` | `parameter logic [PR_XLEN-1:0] PR_BOOT_ADDR = ...;` | Thiếu prefix `PR_` |
| `localparam BE_W = 4;` | `localparam int unsigned LP_BE_W = PR_BUS_DATA_W/8;` | Thiếu prefix, hardcode |
| `always @(*)` | `always_comb begin : p_xxx` | Cấm, thiếu label |
| `u_alu(w_a, w_b, w_c)` | `u_alu(.i_op_a(w_a), ...)` | Cấm positional |
| `if (state == 3)` | `if (reg_state == ST_EXEC)` | Magic number, thiếu prefix |

---

**Tài liệu liên quan:**
- `spec_parser.md` — RTL specification (Target / Overview / Sub-module)
- `spec_verify.md` — Verification plan *(chưa tạo)*
