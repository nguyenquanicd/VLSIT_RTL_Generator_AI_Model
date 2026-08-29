# Phase 2 · Configuration — /config_ui

**Mục tiêu:** Thu thập và xác nhận cấu hình parameter cho IP. Xuất `schemas/final_config.json`
sau khi người dùng ký Gate 2.

**Không làm trong phase này:** sinh RTL, SVA, testbench, hay bất kỳ artifact code nào.

---

## Quy tắc bắt buộc

1. Không tự quyết định giá trị nào khác default — mọi thay đổi phải do người dùng xác nhận.
2. Gate 2 chỉ mở khi: **(a)** toàn bộ C1–C5 pass, **(b)** người dùng gõ xác nhận tường minh.
3. Mọi ràng buộc bị vi phạm phải bị từ chối ngay, không ghi vào config.
4. Ghi `gate_2_approved: false` cho đến khi người dùng xác nhận ở Bước 5.

---

## Bước 1 — Nạp tham số

Kiểm tra theo thứ tự ưu tiên:

1. Nếu `schemas/structured_spec.json` tồn tại → đọc trường `parameters` và `requirements` từ file đó.
2. Nếu không → đọc `spec_parser.md`, trích bảng §2.2 (Parameter TOP) và §1.1 (Feature list).
3. Nếu cả hai đều không tồn tại → dừng, thông báo: _"Không tìm thấy spec. Cần có `spec_parser.md` hoặc `schemas/structured_spec.json`."_

Từ dữ liệu đọc được, xây dựng bảng nội bộ gồm:
`name | type | default | valid_range | description | features_affected | req_ids_affected`

Bảng chuẩn cho `rv32im_core` (tham chiếu `spec_parser.md §2.2`) — dùng khi không có `structured_spec.json`:

| ID  | Tên                 | Default            | Range  | Tóm tắt                              | Feature       |
|-----|---------------------|--------------------|--------|--------------------------------------|---------------|
| P01 | `PR_BOOT_ADDR`      | `32'h8000_0000`    | align4 | PC sau reset                         | F01,F05       |
| P02 | `PR_MTVEC_RESET`    | `32'h0000_0000`    | align4 | Giá trị `mtvec` sau reset            | F11           |
| P03 | `PR_HART_ID`        | `32'h0`            | any    | Giá trị `mhartid` (read-only)        | F11           |
| P04 | `PR_M_EXT_EN`       | `1`                | 0/1    | RV32M bật/tắt                        | **F02**       |
| P05 | `PR_MULT_IMPL`      | `0`                | 0/1    | `0`=SEQ 33cy · `1`=COMB 1cy         | F17           |
| P06 | `PR_DIV_IMPL`       | `0`                | 0      | `0`=SEQ 34cy (**khoá Phase 1**)      | F17           |
| P07 | `PR_CSR_EN`         | `1`                | 0/1    | CSR file + trap bật/tắt              | F03,F11,F15   |
| P08 | `PR_IRQ_EN`         | `1`                | 0/1    | M-mode interrupts                    | F14           |
| P09 | `PR_COUNTER_EN`     | `1`                | 0/1    | `mcycle`/`minstret` 64-bit           | **F16** ⬜   |
| P10 | `PR_MTVEC_VEC_EN`   | `0`                | 0/1    | `mtvec` Vectored mode                | **F19** ⬜   |
| P11 | `PR_FWD_EN`         | `1`                | 0/1    | Full forwarding EX/MEM→EX            | F06           |
| P12 | `PR_RF_RESET_EN`    | `1`                | 0/1    | Reset regfile về 0 (sim determinism) | F09           |
| P13 | `PR_RF_IMPL`        | `0`                | 0/1    | `0`=flop array · `1`=RAM-style FPGA  | F09           |
| P14 | `PR_TRACE_EN`       | `0`                | 0/1    | Retire trace port                    | **F18** ⬜   |
| P15 | `PR_BUS_OUTSTANDING`| `1`                | 1      | Outstanding request (**khoá ở 1**)   | F10           |

---

## Bước 2 — Hiển thị bảng cấu hình

Hiển thị bảng tất cả 15 parameter với giá trị hiện tại (ban đầu = default). Chú thích rõ:
- `⬜ Tuỳ chọn` cho F16, F18, F19 — mặc định tắt (giá trị `0`)
- `[KHOÁ]` cho P06 (`PR_DIV_IMPL`) và P15 (`PR_BUS_OUTSTANDING`) — không thể thay đổi Phase 1
- Ghi chú dependency: C3 (P08→P07), C4 (P10→P07), C5 (P09→P07)

Sau khi hiển thị, hỏi người dùng:

> **"Bạn muốn thay đổi parameter nào so với default? Nhập ID (ví dụ: P05, P13) cách nhau bằng dấu phẩy,
> hoặc gõ `none` để giữ tất cả mặc định."**

---

## Bước 3 — Thu thập và validate thay đổi

Xử lý tuần tự từng parameter người dùng muốn thay đổi:

**3.1 Hiển thị context cho parameter đó:**
- Giá trị hiện tại và default
- Range hợp lệ
- Features và REQ-IDs bị ảnh hưởng
- Constraints liên quan (nếu có)

**3.2 Hỏi giá trị mới.**

**3.3 Validate ngay lập tức:**

| Constraint | Điều kiện | Lỗi nếu vi phạm |
|---|---|---|
| C1 | `PR_BOOT_ADDR % 4 == 0` | "Địa chỉ boot phải align 4 byte" |
| C2 | `PR_MTVEC_RESET % 4 == 0` | "Địa chỉ mtvec reset phải align 4 byte" |
| C3 | `PR_IRQ_EN=1 → PR_CSR_EN=1` | "IRQ cần CSR. Bật PR_CSR_EN trước." |
| C4 | `PR_MTVEC_VEC_EN=1 → PR_CSR_EN=1` | "Vectored mode cần CSR. Bật PR_CSR_EN trước." |
| C5 | `PR_COUNTER_EN=1 → PR_CSR_EN=1` | "Counter cần CSR. Bật PR_CSR_EN trước." |
| — | P06 và P15 không được thay đổi | "Parameter này khoá trong Phase 1." |

**3.4 Xử lý kết quả:**
- Vi phạm → Từ chối, giải thích, đề xuất cách sửa, hỏi lại.
- Hợp lệ → Cập nhật bảng, chuyển parameter tiếp theo.

**3.5 Sau khi xử lý hết danh sách**, hỏi: _"Bạn còn muốn thay đổi parameter nào nữa không?"_

---

## Bước 4 — Style constraints

Thông báo: _"Đọc `rtl_rule.md`..."_ và đọc file đó để liệt kê các rule đã có.

Hỏi người dùng:

> **"Bạn có muốn thêm style constraint nào ngoài `rtl_rule.md` không?
> Gõ bằng ngôn ngữ tự nhiên (ví dụ: 'không dùng for loop trong pipeline stage',
> 'mỗi module tối đa 200 dòng') hoặc gõ `none`."**

Nếu người dùng cung cấp constraints:
1. Phân tích ý định của từng constraint.
2. Chuyển đổi sang dạng lint rule ngắn gọn (text, không phải code).
3. Hiển thị bản diễn giải, hỏi: _"Lint rule trên có đúng ý bạn không?"_
4. Nếu đúng → ghi vào danh sách. Nếu không → hỏi lại.

---

## Bước 5 — Gate 2: Summary và xác nhận

Hiển thị bảng tổng kết theo format sau:

```
╔══ GATE 2 · CONFIG SUMMARY ═══════════════════════════╗
║  IP: rv32im_core   Spec rev: 0.2                    ║
╠══ Parameters thay đổi so với default ════════════════╣
║  (Liệt kê từng parameter đã thay đổi: tên, old→new) ║
║  (Nếu không có: "Tất cả giữ default")               ║
╠══ Constraints ════════════════════════════════════════╣
║  C1 [PASS/FAIL]  C2 [PASS/FAIL]  C3 [PASS/FAIL]    ║
║  C4 [PASS/FAIL]  C5 [PASS/FAIL]                     ║
╠══ Features enabled ═══════════════════════════════════╣
║  ✓ Mandatory: F01 F02 F03 F04 F05 F06 F07 F08       ║
║               F09 F10 F11 F12 F13 F14 F15 F17       ║
║  ✓ Optional:  (liệt kê các F đang bật)              ║
║  ✗ Disabled:  (liệt kê các F đang tắt)              ║
╠══ Style constraints ══════════════════════════════════╣
║  Nguồn gốc: rtl_rule.md + [N rule bổ sung]          ║
╚══════════════════════════════════════════════════════╝
```

Nếu có bất kỳ constraint nào FAIL → **Không mở Gate 2**. Thông báo lỗi và quay về Bước 3.

Nếu tất cả pass, hỏi:

> **"Bạn xác nhận cấu hình trên và mở Gate 2? Gõ `yes` để ký, hoặc `no` để chỉnh sửa."**

- `no` → Quay về Bước 3, cho phép chỉnh sửa.
- `yes` → Tiếp tục Bước 6.

---

## Bước 6 — Ghi output

1. Tạo thư mục `schemas/` nếu chưa tồn tại.
2. Ghi `schemas/final_config.json` với cấu trúc theo `schemas/final_config_schema.json`.
   - `gate_2_approved: true`
   - `approved_at`: timestamp hiện tại (dùng lệnh `date -Iseconds` nếu cần)
3. Thông báo:

> **"✓ Gate 2 đã ký. `schemas/final_config.json` đã được ghi.
> Phase 3 (RTL Generator + SVA Generator) có thể bắt đầu với `/rtl_generator`."**

---

## Xử lý lỗi

| Tình huống | Hành động |
|---|---|
| `spec_parser.md` và `structured_spec.json` đều không có | Dừng, yêu cầu file spec |
| `rtl_rule.md` không tồn tại | Tiếp tục bình thường, ghi nhận "không có rtl_rule.md" vào config |
| Người dùng nhập value ngoài range | Từ chối, giải thích range hợp lệ, hỏi lại |
| Constraint vi phạm sau thay đổi hàng loạt | Liệt kê tất cả vi phạm cùng lúc trước khi yêu cầu sửa |
| `schemas/final_config.json` đã tồn tại | Cảnh báo "File đã tồn tại — ghi đè?" trước khi overwrite |
