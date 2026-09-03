---
title: "AXI_DOWNSCALER — Hardware IP Specification"
revision: "1.0"
date: "2026-09-03"
status: "Released"
---

| Field       | Value                    |
|-------------|--------------------------|
| IP Name     | `axi_downscaler`         |
| Revision    | 1.0                      |
| Date        | 2026-09-03               |
| Status      | Released                 |
| Tool Flow   | Claude Code RTL Gen Flow |

---

## Quick Reference

### Module Hierarchy

```
axi_downscaler_top
├── axi_downscaler_width_split   (S_AXIS slave, width-split N=WIDTH_IN/WIDTH_OUT, protocol error detect)
├── axi_downscaler_fifo          (internal FWFT buffering FIFO, overflow/underflow detect)
└── axi_downscaler_m_axis_if     (M_AXIS master, FIFO pop, handshake — pure combinational)
```

### Parameter Summary

| Parameter    | Default | Description |
|--------------|---------|-------------|
| `PR_WIDTH_IN`   | 64 | S_AXIS input data width (bit) |
| `PR_WIDTH_OUT`  | 32 | M_AXIS output data width (bit); `PR_WIDTH_IN` phải là bội số nguyên của `PR_WIDTH_OUT` (không có RTL elaboration check — trách nhiệm DV, xem REQ-016) |
| `PR_FIFO_DEPTH` | 16 | Số entry của FIFO nội bộ |

### Feature Matrix

| Feature | Enabled | Ghi chú |
|---------|---------|---------|
| Width downscale (N=WIDTH_IN/WIDTH_OUT split, LSB-first) | ✓ | REQ-001, REQ-002 |
| TLAST propagation | ✓ | REQ-003 |
| Internal buffering FIFO + backpressure | ✓ | REQ-004 |
| FIFO overflow/underflow error pulse | ✓ | REQ-005 |
| Protocol error pulse (tkeep=0 & tvalid=1) | ✓ | REQ-006 |
| AMBA AXI4-Stream handshake compliance | ✓ | REQ-007 |
| TSTRB/TUSER/TID/TDEST sideband signals | ✗ (loại trừ có chủ đích) | REQ-012 |
| CSR / register map | ✗ (không có, thiết kế thuần streaming) | — |

---

## 01 — Overview

### 1.1 Introduction

`axi_downscaler` là IP chuyển đổi độ rộng dữ liệu (data width downscaler) cho giao thức
AXI4-Stream, chuyển dòng dữ liệu từ width đầu vào lớn (`WIDTH_IN`) sang width đầu ra nhỏ
hơn (`WIDTH_OUT`), với ràng buộc `WIDTH_IN` là bội số nguyên của `WIDTH_OUT`. IP dùng cho
các ứng dụng cần thu hẹp bus dữ liệu tổng quát (general-purpose data stream), không giới
hạn cho một domain dữ liệu cụ thể.

Target: ASIC, process GF180MCU (180nm), single clock domain.

### 1.2 Key Features

- Chuyển đổi width AXI4-Stream từ `WIDTH_IN` → `WIDTH_OUT`, với `WIDTH_IN` = N × `WIDTH_OUT`.
- Thứ tự phát output beat: **LSB-first**.
- FIFO nội bộ (`FIFO_DEPTH` entry, cấu hình được) để buffer dữ liệu phía output.
- Hỗ trợ TLAST, giữ nguyên semantic qua downscaler.
- 2 error port riêng biệt: `o_err_fifo` (FIFO overflow/underflow) và `o_err_protocol`
  (tkeep=0 khi tvalid=1), cả hai đều là pulse 1 chu kỳ clock.
- Zero-gap back-to-back transaction acceptance (chained-accept) — đạt full-rate throughput
  khi input liên tục và `i_m_axis_tready` luôn high.

### 1.3 Top-Level Parameters

| Parameter       | Type         | Default | Description |
|-----------------|--------------|---------|-------------|
| `PR_WIDTH_IN`   | int unsigned | 64      | S_AXIS input data width (bit) |
| `PR_WIDTH_OUT`  | int unsigned | 32      | M_AXIS output data width (bit) |
| `PR_FIFO_DEPTH` | int unsigned | 16      | Số entry FIFO nội bộ |

### 1.4 Module Hierarchy

```
axi_downscaler_top
├── axi_downscaler_width_split   S_AXIS slave interface — width split (LSB-first),
│                                  TLAST propagation, protocol error detect, FIFO push
├── axi_downscaler_fifo          Generic FWFT sync FIFO, overflow/underflow error detect
└── axi_downscaler_m_axis_if     M_AXIS master interface — FIFO pop, handshake
                                   (thuần combinational, không có clock/reset port)
```

---

## 02 — Port List

### Clock & Reset

| Port        | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `i_clk`     | input     | 1     | Clock chung cho cả S_AXIS và M_AXIS |
| `i_resetn`  | input     | 1     | Reset active-low, asynchronous assert / synchronous deassert |

### S_AXIS Slave Interface

| Port              | Direction | Width           | Description |
|-------------------|-----------|-----------------|-------------|
| `i_s_axis_tdata`  | input     | `WIDTH_IN`      | Dữ liệu đầu vào |
| `i_s_axis_tvalid` | input     | 1               | Slave data valid |
| `o_s_axis_tready` | output    | 1               | Downscaler sẵn sàng nhận dữ liệu |
| `i_s_axis_tlast`  | input     | 1               | Đánh dấu beat cuối packet |
| `i_s_axis_tkeep`  | input     | `WIDTH_IN/8`    | Byte-valid qualifier |

### M_AXIS Master Interface

| Port              | Direction | Width           | Description |
|-------------------|-----------|-----------------|-------------|
| `o_m_axis_tdata`  | output    | `WIDTH_OUT`     | Dữ liệu đầu ra sau downscale |
| `o_m_axis_tvalid` | output    | 1               | Master data valid |
| `i_m_axis_tready` | input     | 1               | Downstream consumer sẵn sàng nhận |
| `o_m_axis_tlast`  | output    | 1               | Đánh dấu beat cuối packet |
| `o_m_axis_tkeep`  | output    | `WIDTH_OUT/8`   | Byte-valid qualifier phía output |

### Error Status

| Port             | Direction | Width | Description |
|------------------|-----------|-------|-------------|
| `o_err_fifo`     | output    | 1     | Pulse 1-cycle khi FIFO overflow hoặc underflow |
| `o_err_protocol` | output    | 1     | Pulse 1-cycle khi `i_s_axis_tkeep==0` & `i_s_axis_tvalid==1` |

> Không có port TSTRB, TUSER, TID, TDEST — loại trừ có chủ đích (REQ-012).
> Không có CSR / register map — IP hoạt động thuần streaming.

---

## 03 — Clock & Reset

### Clock Domains

| Domain | Signal  | Description |
|--------|---------|-------------|
| Core   | `i_clk` | 1 clock domain duy nhất, dùng chung cho cả S_AXIS và M_AXIS (không cần CDC) |

### Reset Strategy

- Active-low, **asynchronous assert / synchronous deassert** (`i_resetn`), theo `rtl_rule.md` §4.2.
- Control flop (FSM state, counter, FIFO pointer/count) có reset; datapath payload flop
  (`reg_data`, `reg_tlast`, `reg_tkeep`, FIFO memory) không cần reset — được gate bởi
  `reg_state`/`o_empty` nên không bao giờ đọc giá trị garbage.
- Sau reset deassert: `o_s_axis_tready=1` (idle, FIFO rỗng), `o_err_fifo=0`, `o_err_protocol=0`
  (verified bởi TC-001 và SVA `a_top_errors_clear_on_reset`, `a_top_ready_after_reset`).

### Target Clock Frequency

- 800–1000 MHz (target), 2000 MHz (stretch goal, không committed) — theo REQ-013.
- **Chưa được verify bằng STA** trong flow này (chỉ mới qua Yosys cell-mapping). Xem §08.

---

## 04 — Microarchitecture

### Datapath Overview

```
S_AXIS ──▶ [axi_downscaler_width_split] ──push──▶ [axi_downscaler_fifo] ──pop──▶ [axi_downscaler_m_axis_if] ──▶ M_AXIS
                    │                                                                    │
              o_err_protocol                                                       (tvalid = !empty)
                                              o_err_fifo (OR of overflow/underflow, tại top)
```

### Module Description

| Module | Function |
|--------|----------|
| `axi_downscaler_width_split` | FSM 2 state (`ST_IDLE`/`ST_BUSY`) latch 1 transaction S_AXIS, tách thành N=`WIDTH_IN`/`WIDTH_OUT` sub-beat (LSB-first), push tuần tự vào FIFO. Hỗ trợ **chained-accept**: có thể accept transaction mới ngay tại cycle push sub-beat cuối cùng của transaction hiện tại (zero-gap, REQ-014). |
| `axi_downscaler_fifo` | FIFO đồng bộ, first-word-fall-through (FWFT), độ sâu `FIFO_DEPTH`, phát hiện overflow (push khi full) / underflow (pop khi empty). |
| `axi_downscaler_m_axis_if` | Thuần combinational: `tvalid = !fifo_empty` (không phụ thuộc `tready`, tuân thủ AMBA IHI 0051), `pop = tvalid && tready`. |

### Width-Split Addressing

Địa chỉ slice được tính qua các wire kích thước `LP_ADDR_W = $clog2(WIDTH_IN)` bit (thay
vì cast `int` 32-bit) để tránh sinh ra dead logic không thể kích hoạt được ở synthesis —
cải thiện trực tiếp mutation testing score (xem §07).

### Backpressure Policy

`o_s_axis_tready` chỉ high khi (`ST_IDLE` hoặc đang finishing sub-beat cuối) **và** FIFO
chưa đầy. Khi FIFO đầy, slave dừng nhận dữ liệu mới (REQ-004).

---

## 05 — CSR / Register Map

Không áp dụng — `axi_downscaler` không có CSR/register map, hoạt động thuần streaming
(không có control/status register ngoài 2 error pulse port ở §02).

---

## 06 — Functional Description

### 6.1 Width Conversion (S_AXIS → internal push)

Mỗi transaction `WIDTH_IN`-bit ở S_AXIS được tách thành N = `WIDTH_IN`/`WIDTH_OUT` beat
`WIDTH_OUT`-bit, phát tuần tự theo thứ tự **LSB-first**: byte/bit thấp nhất của
`i_s_axis_tdata` phát ở output beat đầu tiên. `i_s_axis_tlast` của beat input được gán
vào sub-beat cuối cùng tương ứng (REQ-001, REQ-002, REQ-003).

### 6.2 Internal Buffering (FIFO)

FIFO nội bộ (FWFT, độ sâu `FIFO_DEPTH`) buffer dữ liệu phía output khi
`i_m_axis_tready` chưa sẵn sàng hoặc để làm mượt tốc độ giữa 2 phía. Backpressure: dừng
nhận ở slave (`o_s_axis_tready=0`) khi FIFO đầy (REQ-004).

### 6.3 M_AXIS Output

`o_m_axis_tvalid` phụ thuộc thuần vào trạng thái FIFO (`!empty`), không phụ thuộc tổ hợp
vào `i_m_axis_tready` — tuân thủ AMBA AXI4-Stream: dữ liệu ổn định khi
`tvalid=1 & tready=0` (REQ-007).

### 6.4 Error Handling

- `o_err_fifo`: pulse 1-cycle khi FIFO overflow (ghi khi đầy) hoặc underflow (đọc khi rỗng).
  Theo thiết kế, backpressure structurally ngăn overflow/underflow xảy ra qua traffic hợp
  lệ — verified bằng TC-006 (random stress, không bao giờ thấy pulse giả) (REQ-005).
- `o_err_protocol`: pulse 1-cycle khi `i_s_axis_tkeep==0` trong khi `i_s_axis_tvalid==1`
  (beat rỗng nhưng đánh dấu valid) (REQ-006).

### 6.5 Throughput & Latency

- Throughput: sustained 1 output beat/cycle (full-rate) khi input liên tục và
  `i_m_axis_tready` luôn high — đạt được nhờ cơ chế chained-accept trong FSM
  `axi_downscaler_width_split` (REQ-014, verified bằng TC-003).
- Latency: đo được ~2-3 cycle từ khi accept beat input đầu tiên đến khi phát beat output
  đầu tiên (soft guideline, không có hard SVA check theo quyết định Gate 1) (REQ-015).

### 6.6 DV Responsibility

`WIDTH_IN` = N × `WIDTH_OUT` là ràng buộc thiết kế **không được RTL/SVA enforce**
(quyết định tường minh ở Gate 1) — DV team chịu trách nhiệm cover các cặp tỷ lệ hợp lệ
trong testplan (REQ-016).

---

## 07 — Verification Summary

### Simulation Results

| Metric          | Value |
|------------------|-------|
| Total TC         | 12    |
| PASS             | 11    |
| N/A (cần STA)    | 1 (TC-009) |
| FAIL             | 0     |
| SVA violations   | 0     |
| Tool             | VCS X-2025.06 |

### Test Coverage (theo category REQ-ID)

| REQ-ID Group | Total | Covered by TC | % |
|--------------|-------|----------------|---|
| Functional   | 7     | 7              | 100% |
| Interface    | 5     | 5              | 100% |
| Timing       | 3     | 3 (2 soft/N-A) | 100% |
| Constraint   | 1     | 1 (DV-only)    | 100% |

### Mutation Testing (theo module — 4 module RTL)

| Module | Mutations | Killed | Survived | Score |
|--------|-----------|--------|----------|-------|
| `axi_downscaler_fifo`         | 12 | 12 | 0 | **100%** |
| `axi_downscaler_m_axis_if`    | 12 | 12 | 0 | **100%** |
| `axi_downscaler_top`          | 12 | 11 | 1 | **91.7%** |
| `axi_downscaler_width_split`  | 24 | 21 | 3 | **87.5%** |

Ngưỡng sign-off: ≥ 85%. `axi_downscaler_width_split.sv` ban đầu chỉ đạt 75% — cải thiện
lên 87.5% qua 2 fix thật: (1) bổ sung TC-012 với data pattern đa dạng (all-0, all-1,
walking-bit, case `tlast=0`) bắt được 2 gap test thật (stuck-at bit trên `reg_data`,
thiếu coverage `tlast=0`); (2) sửa RTL loại bỏ cast `int'(...)` dư thừa trong phép tính
địa chỉ slice, loại bỏ dead logic thật (không chỉ thêm test). 3 mutation còn sống được
xác định là equivalent mutant (logic FSM 1-bit `ST_IDLE`/`ST_BUSY` không thể kích hoạt
theo cách Yosys mutate với N=2).

### Sign-Off Summary

| Status       | Count |
|--------------|-------|
| Signed-off   | 12    |
| Locked       | 4     |
| Total REQ    | 16    |

REQ-ID LOCK còn lại (có chủ đích, không phải fail): REQ-012 (loại trừ sideband signal —
không thể assert "một port không tồn tại"), REQ-013 (cần STA riêng), REQ-015/016 (theo
quyết định Gate 1: soft guideline / DV-only).

> **Cập nhật 2026-09-03**: bổ sung SVA cho REQ-008 (`a_ws_s_axis_payload_no_x_when_valid`,
> `a_ws_s_axis_tready_no_x`) và REQ-009 (`a_m_axis_payload_no_x_when_valid`,
> `a_m_axis_tvalid_no_x`) — no-X check trên payload/status khi tvalid=1. Cả 2 đã được
> sign-off. Mutation score không đổi (chỉ thêm assertion, không đổi RTL logic).

---

## 08 — Synthesis Report

### Summary

| Metric        | Value        |
|---------------|--------------|
| PDK           | GF180MCU (gf180mcu_fd_sc_mcu7t5v0) |
| Corner TT     | tt_025C_1v80 — PASS |
| Corner SS     | ss_125C_1v62 — PASS |
| Total Cells   | ~1670 |
| Chip Area     | ~78,000 µm² (~55% sequential) |
| Timing Status | **TBD — chưa chạy STA** |

### Known Caveat

Target clock 800MHz–2GHz (REQ-013) **chưa được verify bằng Static Timing Analysis**.
Bước synthesis hiện tại chỉ chạy Yosys `stat` (cell mapping/area), không có SDC constraint
hay timing closure check. GF180MCU là process 180nm; tần số 800MHz–2GHz gần như chắc chắn
không khả thi với thiết kế combinational hiện tại trên node này. Khuyến nghị: review lại
target frequency hoặc chạy STA (OpenSTA) với SDC constraint ở bước tiếp theo.

### Tool Versions

| Tool       | Version    |
|------------|------------|
| Yosys      | 0.58+35    |
| VCS        | X-2025.06  |
| Verilator  | 5.041      |

---

## 09 — Requirements Traceability Matrix (RTM)

| REQ-ID | Description (short) | RTL File | SVA | TC | Sim | Mut | S/O |
|--------|---------------------|----------|-----|----|----|-----|-----|
| REQ-001 | Width downscale: N=WIDTH_IN/WIDTH_OUT beat split | axi_downscaler_width_split.sv | ✓ | TC-002, TC-003, TC-012 | ✓ | 87.5% | ✓ |
| REQ-002 | Beat ordering: LSB-first | axi_downscaler_width_split.sv | ✓ | TC-002, TC-012 | ✓ | 87.5% | ✓ |
| REQ-003 | TLAST propagation → last output beat | axi_downscaler_width_split.sv | ✓ | TC-002, TC-012 | ✓ | 87.5% | ✓ |
| REQ-004 | Internal FIFO buffer + backpressure | axi_downscaler_width_split.sv, axi_downscaler_fifo.sv | ✓ | TC-005 | ✓ | 87.5% | ✓ |
| REQ-005 | err_fifo: pulse on overflow/underflow | axi_downscaler_fifo.sv | ✓ | TC-006 | ✓ | 100.0% | ✓ |
| REQ-006 | err_protocol: pulse on tkeep=0 & tvalid=1 | axi_downscaler_width_split.sv | ✓ | TC-007 | ✓ | 87.5% | ✓ |
| REQ-007 | AXI4-Stream handshake compliance (AMBA IHI 0051) | axi_downscaler_width_split.sv, axi_downscaler_m_axis_if.sv | ✓ | TC-004 | ✓ | 87.5% | ✓ |
| REQ-008 | S_AXIS port set | axi_downscaler_width_split.sv, axi_downscaler_top.sv | ✓ | TC-002 | ✓ | 87.5% | ✓ |
| REQ-009 | M_AXIS port set | axi_downscaler_m_axis_if.sv, axi_downscaler_top.sv | ✓ | TC-002 | ✓ | 91.7% | ✓ |
| REQ-010 | Error port set (err_fifo, err_protocol) | axi_downscaler_top.sv | ✓ | TC-006, TC-007 | ✓ | 91.7% | ✓ |
| REQ-011 | Clock & reset: 1 domain, async-assert/sync-deassert | axi_downscaler_width_split.sv, axi_downscaler_top.sv | ✓ | TC-001 | ✓ | 87.5% | ✓ |
| REQ-012 | Excluded sideband signals (no TSTRB/TUSER/TID/TDEST) | axi_downscaler_top.sv | ✗ (structural) | TC-008 | ✓ | 91.7% | LOCK |
| REQ-013 | Target clock 800-1000MHz (2000MHz stretch) | — | ✗ (cần STA) | TC-009 | N/A | N/A | LOCK |
| REQ-014 | Throughput: sustained 1 beat/cycle full-rate | axi_downscaler_width_split.sv, axi_downscaler_m_axis_if.sv | ✓ | TC-003 | ✓ | 87.5% | ✓ |
| REQ-015 | Latency ~2-4 cycle (soft guideline) | — | ✗ (sva_hint=none, Gate 1) | TC-010 | ✓ | N/A | LOCK |
| REQ-016 | WIDTH_IN = N×WIDTH_OUT (DV-only, không RTL check) | — | ✗ (Gate 1 decision) | TC-011 | ✓ | N/A | LOCK |

---

## Phụ lục — Quyết định thiết kế quan trọng

| Quyết định | Lý do |
|------------|-------|
| Port naming `i_`/`o_` + `s_`/`m_` (thay vì AXI chuẩn thuần) | Theo `rtl_rule.md` §1.1, thống nhất với coding convention của project |
| Reset async-assert/sync-deassert (thay vì fully sync) | Theo `rtl_rule.md` §4.2, nhất quán với toàn bộ IP khác trong project |
| Beat ordering LSB-first | Convention phổ biến công nghiệp (tham chiếu Xilinx AXI4-Stream Data Width Converter) |
| Error port pulse 1-cycle (không sticky) | Đơn giản hoá interface, không cần CSR/clear mechanism |
| WIDTH_IN=N×WIDTH_OUT không RTL check | Quyết định tường minh ở Gate 1 — trách nhiệm DV, tránh phức tạp hoá RTL với elaboration check |
| Latency soft guideline, không SVA cứng | Quyết định tường minh ở Gate 1 — latency là mục tiêu tham khảo, chưa committed |
