# AXI_DOWNSCALER — Hardware IP Specification

## 1. Overview
AXI_DOWNSCALER là IP chuyển đổi độ rộng dữ liệu (data width downscaler) cho giao thức AXI4-Stream, chuyển dòng dữ liệu từ width đầu vào lớn (WIDTH_IN) sang width đầu ra nhỏ hơn (WIDTH_OUT), với ràng buộc WIDTH_IN là bội số nguyên của WIDTH_OUT. IP dùng cho các ứng dụng cần thu hẹp bus dữ liệu tổng quát (general-purpose data stream), không giới hạn cho một domain dữ liệu cụ thể (không phải video/image scaler).

## 2. Key Features
- Feature 1: Chuyển đổi width AXI4-Stream từ WIDTH_IN → WIDTH_OUT, với WIDTH_IN = N × WIDTH_OUT (N nguyên).
- Feature 2: FIFO nội bộ để gom (buffer) dữ liệu, phục vụ chiều trả dữ liệu về phía master (output side).
- Feature 3: Single clock domain — slave interface (input) và master interface (output) dùng chung 1 clock, không cần CDC.
- Feature 4: Reset active-low, asynchronous assert / synchronous deassert (i_resetn), theo `rtl_rule.md` §4.2.
- Feature 5: Hỗ trợ TLAST để đánh dấu kết thúc packet, giữ nguyên semantic qua downscaler.

## 3. Parameters
| Parameter   | Type | Default | Description |
|-------------|------|---------|-------------|
| WIDTH_IN    | int  | 64      | Độ rộng dữ liệu đầu vào (bit), phía slave (S_AXIS) |
| WIDTH_OUT   | int  | 32      | Độ rộng dữ liệu đầu ra (bit), phía master (M_AXIS). WIDTH_IN phải là bội số nguyên của WIDTH_OUT |
| FIFO_DEPTH  | int  | 16      | Số lượng entry của FIFO nội bộ dùng để buffer dữ liệu, có thể cấu hình qua parameter |

## 4. Interface

### 4.1 Clock & Reset
| Signal      | Direction | Description |
|-------------|-----------|-------------|
| i_clk       | input     | Clock chung cho cả slave và master interface |
| i_resetn    | input     | Reset active-low, asynchronous assert / synchronous deassert (theo `rtl_rule.md` §4.2) |

### 4.2 Input Ports (Slave AXI4-Stream — S_AXIS)
| Signal          | Direction | Width      | Description |
|-----------------|-----------|------------|-------------|
| i_s_axis_tdata  | input     | WIDTH_IN   | Dữ liệu đầu vào |
| i_s_axis_tvalid | input     | 1          | Slave data valid |
| o_s_axis_tready | output    | 1          | Downscaler sẵn sàng nhận dữ liệu |
| i_s_axis_tlast  | input     | 1          | Đánh dấu beat cuối của packet |
| i_s_axis_tkeep  | input     | WIDTH_IN/8 | Byte-valid qualifier (dùng cho beat cuối không đầy đủ) |

### 4.3 Output Ports (Master AXI4-Stream — M_AXIS)
| Signal          | Direction | Width       | Description |
|-----------------|-----------|-------------|-------------|
| o_m_axis_tdata  | output    | WIDTH_OUT   | Dữ liệu đầu ra sau khi downscale |
| o_m_axis_tvalid | output    | 1           | Master data valid |
| i_m_axis_tready | input     | 1           | Downstream consumer sẵn sàng nhận |
| o_m_axis_tlast  | output    | 1           | Đánh dấu beat cuối của packet (giữ nguyên semantic từ input) |
| o_m_axis_tkeep  | output    | WIDTH_OUT/8 | Byte-valid qualifier phía output |

### 4.4 Error Ports
| Signal          | Direction | Width | Description |
|-----------------|-----------|-------|-------------|
| o_err_fifo      | output    | 1     | Báo lỗi liên quan FIFO nội bộ (ví dụ FIFO overflow/underflow) |
| o_err_protocol  | output    | 1     | Báo lỗi liên quan protocol/data (tkeep=0 khi tvalid=1) |

> Ghi chú naming: Port dùng prefix `i_`/`o_` theo `rtl_rule.md` §1.1, kết hợp `s_`/`m_` để phân biệt slave/master AXI4-Stream side (ví dụ `i_s_axis_tdata`, `o_m_axis_tdata`).

> Ghi chú: Không sử dụng TSTRB, TUSER, TID, TDEST (theo xác nhận của user — chỉ dùng bộ tín hiệu AXI4-Stream cơ bản).

## 5. Functional Description

### 5.1 Width Conversion Datapath
Mỗi transaction WIDTH_IN-bit ở đầu vào được tách thành N = WIDTH_IN / WIDTH_OUT beat WIDTH_OUT-bit ở đầu ra, phát tuần tự ra M_AXIS theo thứ tự LSB-first (xem §5.3). TLAST của input beat cuối cùng sẽ được gán vào output beat cuối cùng tương ứng (beat thứ N của transaction đó).

### 5.2 Internal Buffering (FIFO)
IP có FIFO nội bộ để gom dữ liệu, phục vụ việc trả dữ liệu về phía master khi master chưa sẵn sàng nhận (i_m_axis_tready thấp) hoặc để làm mượt tốc độ giữa 2 phía. Độ sâu FIFO cấu hình qua parameter FIFO_DEPTH (default 16). Chính sách backpressure: dừng nhận ở slave (o_s_axis_tready = 0) khi FIFO đầy.

### 5.3 Beat Ordering
Khi split 1 transaction WIDTH_IN-bit thành N = WIDTH_IN / WIDTH_OUT beat ở output, thứ tự phát là **LSB-first**: byte/bit thấp nhất của i_s_axis_tdata được phát ở output beat đầu tiên, byte/bit cao nhất được phát ở beat cuối cùng.

## 6. Microarchitecture
- 1 clock domain duy nhất (i_clk), reset active-low, asynchronous assert / synchronous deassert (i_resetn).
- Datapath: S_AXIS → Width Split Logic → Internal FIFO → Output Beat Selector → M_AXIS.
- TBD: Pipeline stage count, chi tiết state machine điều khiển output beat sequencing.

## 7. Timing & Constraints
- Target: ASIC.
- Clock frequency: 800–1000 MHz (target); 2000 MHz là mục tiêu mở rộng (stretch goal) nếu khả thi với process/library được chọn.
- Throughput: sustained 1 output beat/cycle khi i_m_axis_tready luôn high và dữ liệu input liên tục (không backpressure) — tương đương full-rate streaming, không giới hạn nhân tạo.
- Latency: mục tiêu thấp, khoảng 2-4 cycle từ khi nhận beat input đầu tiên của transaction đến khi phát beat output đầu tiên tương ứng (do FIFO buffering + width-split logic). Con số chính xác sẽ chốt sau khi có microarchitecture chi tiết ở Phase 3a.

## 8. Register Map (nếu có)
Không có CSR/register map — IP hoạt động thuần streaming, không có control/status register (chưa được user xác nhận là có cần hay không — TBD nếu cần thêm sau).

## 9. Error Handling
- IP xuất 2 loại lỗi ra 2 output port riêng biệt (xem mục 4.4), cả hai đều là **pulse 1 chu kỳ clock** (không sticky, không cần clear — IP không có CSR):
  - `o_err_fifo`: pulse khi xảy ra FIFO overflow (ghi khi đầy) hoặc underflow (đọc khi rỗng).
  - `o_err_protocol`: pulse khi phát hiện i_s_axis_tkeep == 0 trong khi i_s_axis_tvalid == 1 (beat rỗng nhưng được đánh dấu valid).
- **Note (không phải RTL check)**: WIDTH_IN phải là bội số nguyên của WIDTH_OUT theo giả định thiết kế (xem mục 3). RTL **không** implement compile-time/elaboration check cho ràng buộc này — đây là trách nhiệm của **DV team**: testplan/testcase phải cover các cặp WIDTH_IN/WIDTH_OUT hợp lệ (bội số đúng) và có thể thêm negative-check ở testbench/scoreboard nếu cần verify config invalid bị reject ở môi trường tích hợp.

## 10. Notes / TBD
- Có cần CSR/status register (ngoài 2 error port đã có) không: chưa xác định. Nếu cần log lỗi lâu dài, có thể bổ sung optional sticky mode qua parameter (ERR_STICKY) ở version sau.
- Target: ASIC — cần thêm process node / library nếu có, hiện chưa cung cấp.
- Latency chính xác (2-4 cycle) sẽ được chốt lại sau khi RTL microarchitecture hoàn thiện ở Phase 3a.
