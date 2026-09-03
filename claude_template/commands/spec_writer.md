# Phase 0 · Spec Writer — /spec_writer

**Mục tiêu:** Tự động tạo file spec Markdown từ mô tả design của user, sẵn sàng để đưa vào `/spec_parser`.

**Usage:**
```
/spec_writer
```
Agent sẽ hỏi tuần tự, không hỏi tất cả cùng lúc.

---

## Nguyên tắc bắt buộc

1. **Hỏi tối đa 3 vòng** — không hỏi vòng vô tận, thiếu thông tin thì ghi `TBD` và note lại.
2. **Không tự suy diễn spec kỹ thuật** — nếu không chắc thì hỏi, không bịa số liệu.
3. **Output phải đủ để spec_parser chạy được** — ít nhất: tên IP, chức năng chính, interface, tham số chính.
4. **Lưu vào `spec/` folder** — tạo folder nếu chưa có.
5. **Format nhất quán** — dùng Markdown heading, bảng, bullet list để spec_parser dễ parse.

---

## Bước 1 — Hỏi thông tin cơ bản

Hỏi user (có thể hỏi tất cả trong 1 message):

```
Để tạo spec, mình cần biết:

1. Tên IP / module là gì? (ví dụ: downscaler, axi_bridge, uart_ctrl)
2. Chức năng chính là gì? (1-3 câu mô tả)
3. Interface: input/output chính là gì? (data width, bus type, clock?)
4. Có parameter nào cần configure không? (enable/disable feature, width, depth...)
5. Target: ASIC hay FPGA?
```

Nếu user cung cấp đủ → sang Bước 2.  
Nếu user mô tả ngắn gọn (ví dụ: "downscaler 4K về 1080p") → agent tự suy luận phần còn lại dựa trên domain knowledge, ghi rõ những phần đã tự điền.

---

## Bước 2 — Hỏi thêm chi tiết kỹ thuật (nếu cần)

Chỉ hỏi những gì còn thiếu sau Bước 1:

```
Thêm một vài câu hỏi kỹ thuật:

6. Pipeline hay combinational? Bao nhiêu stage?
7. Có reset không? Active-high hay active-low?
8. Clock domain: 1 hay nhiều?
9. Có interrupt / status register không?
10. Có CSR / register map không?
```

Nếu user không biết → dùng default hợp lý cho domain, ghi chú rõ.

---

## Bước 3 — Sinh spec.md

Dựa trên thông tin thu thập, sinh file `spec/<ip_name>_spec.md` với cấu trúc:

```markdown
# <IP_NAME> — Hardware IP Specification

## 1. Overview
<Mô tả chức năng chính, use case, target application>

## 2. Key Features
- Feature 1: ...
- Feature 2: ...

## 3. Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| PR_...    | bit  | 1       | ...         |

## 4. Interface
### 4.1 Clock & Reset
| Signal | Direction | Description |
|--------|-----------|-------------|

### 4.2 Input Ports
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|

### 4.3 Output Ports
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|

## 5. Functional Description
### 5.1 <Subsystem 1>
<Mô tả chi tiết>

### 5.2 <Subsystem 2>
<Mô tả chi tiết>

## 6. Microarchitecture
<Pipeline diagram, state machine, datapath nếu có>

## 7. Timing & Constraints
<Clock frequency, latency, throughput>

## 8. Register Map (nếu có)
| Address | Name | Access | Reset | Description |
|---------|------|--------|-------|-------------|

## 9. Error Handling
<Exception, invalid input behavior>

## 10. Notes / TBD
<Những gì còn chưa rõ, cần confirm thêm>
```

---

## Bước 4 — Review và confirm

In ra preview 20 dòng đầu của spec, sau đó hỏi:

```
Spec đã được tạo tại: spec/<ip_name>_spec.md

Bạn muốn:
  [1] Tiếp tục → chạy /autoflow với spec này
  [2] Chỉnh sửa thêm → mở file và sửa tay, xong gõ /autoflow spec/<ip_name>_spec.md
  [3] Hỏi thêm → agent tiếp tục hỏi để bổ sung
```

---

## Xử lý lỗi

| Tình huống | Hành động |
|------------|-----------|
| User mô tả quá ngắn (< 10 từ) | Hỏi lại: "Bạn có thể mô tả thêm về input/output không?" |
| Domain không quen (RF, analog, etc.) | Ghi rõ "TBD — cần domain expert confirm" ở section đó |
| Mâu thuẫn thông tin | Hỏi lại ngay, không tự chọn |
| User cung cấp file PDF/docx | Đọc file, extract thông tin rồi tiếp tục flow |
