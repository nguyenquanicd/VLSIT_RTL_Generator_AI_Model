# Rules — Authoring spec_parser.md for RTL Projects

Dùng file này mỗi khi viết mới hoặc điều chỉnh `spec_parser.md` cho một project RTL khác.

---

## R1 — Cấu trúc bắt buộc (không được bỏ)

Mọi `spec_parser.md` phải có đủ 7 bước sau, theo đúng thứ tự:

```
Bước 1: Xác định file spec đầu vào
Bước 2: Trích requirement → gán REQ-ID
Bước 3: Chấm ambiguity score + sinh sva_hint
Bước 4: Review bắt buộc (needs_review: true)
Bước 5: Chỉnh sửa tùy chọn của người dùng
Bước 6: Mapping (REQ → parameter, REQ → module)
Bước 7: Gate 1
```

Không bỏ Bước 4 dù spec "trông có vẻ rõ". Ambiguity ẩn thường không thấy cho đến Phase 3.

---

## R2 — REQ-ID granularity

**Tách thành 2+ REQ khi:**
- Hai behavior có thể fail độc lập (test riêng được)
- Một cái có parameter điều khiển (enable/disable), cái kia không
- Khác category (functional vs timing)
- Có thể viết 2 SVA assertion riêng biệt

**Gộp thành 1 REQ khi:**
- Cùng một điều kiện kích hoạt, cùng output
- Spec mô tả chúng như một nguyên tử
- Chỉ cần 1 SVA assertion để cover

**Không tạo REQ-ID cho:** rationale, out-of-scope list, ví dụ waveform, comment.

---

## R3 — Ambiguity score — ngưỡng cứng

| Score | Ý nghĩa | Hành động |
|-------|---------|-----------|
| 0.0–0.1 | Bảng tra cứu đầy đủ | Không cần hỏi |
| 0.1–0.3 | Một cách đọc duy nhất | Không cần hỏi |
| 0.3–0.6 | ≥2 cách hiểu khác nhau | `needs_review: true` — hỏi tối đa 3 lần |
| 0.6–1.0 | Không đủ để implement | Hỏi ngay, block Gate 1 cho đến khi resolve |

**Tuyệt đối không cho phép bỏ qua** requirement có score > 0.3 để tiếp tục. Đây là nguồn gốc chính của RTL hallucination.

---

## R4 — Mapping REQ → module là bắt buộc

Bước 6 phải hoàn thành trước Gate 1. Không có mapping → Phase 3 (`/rtl_generator`) không biết module nào implement requirement nào → module thiếu tag → RTM không trace được.

Khi viết spec_parser.md cho project mới:
- Đọc danh sách module RTL dự kiến từ spec (thường có section "Module List" hoặc block diagram)
- Ghi rõ tên section trong spec đó để Bước 6 reference đúng

---

## R5 — Gate 1 — điều kiện mở

```
needs_human_decision == 0   ← bắt buộc
Tất cả REQ có rtl_modules ≠ []
Tất cả REQ có parameters_affected (rỗng [] nếu không liên quan parameter)
structured_spec.json conform schema
```

Không mở Gate 1 nếu thiếu bất kỳ điều kiện nào, dù người dùng yêu cầu.

---

## R6 — Phần cần thay đổi khi dùng cho project mới

Các phần sau phụ thuộc vào project — phải viết lại:

| Phần | Phải thay bằng |
|------|---------------|
| Bước 2 · Nguồn trong spec | Section header thực tế của spec mới |
| Bước 6.1 · Parameter table | Tên parameter của design mới (VD: `FIFO_DEPTH`, `BUS_WIDTH`) |
| Bước 6.2 · RTL module list | Tên module thực tế của design mới |
| Bước 1 · Validate spec | Keyword đặc trưng của domain (processor ≠ memory controller ≠ FIFO) |

Phần còn lại (R1–R5, Xử lý lỗi, schema path) giữ nguyên.

---

## R7 — sva_hint phải chọn đúng loại

Chọn hint dựa trên nature của requirement, không phải theo cảm tính:

| Hint | Khi nào dùng |
|------|-------------|
| `"property"` | Behavior có cycle-by-cycle timing (handshake, latency, pipeline) |
| `"static"` | Giá trị cố định tại elaboration (parameter range, port width) |
| `"cover"` | Reachability — chứng minh scenario có thể xảy ra |
| `"assume"` | Constraint trên input (dành cho formal verification) |
| `"sequence"` | Multi-cycle pattern phức tạp cần sequence riêng |

---

## R8 — Tránh 3 lỗi phổ biến

1. **Over-splitting:** Tách quá nhỏ → REQ count phình to → Phase 4 sinh quá nhiều TC nhỏ vặt mà không cover behavior quan trọng. Áp dụng heuristic "1 SVA = 1 REQ".

2. **Thiếu mapping timing requirement:** Timing requirement (latency, penalty cycle) dễ bị gán sai sang functional module. Timing REQ phải map vào hazard_ctrl hoặc module pipeline control tương đương.

3. **Không validate spec đầu vào:** Nếu file truyền vào không có dấu hiệu RTL spec (không có port list / parameter table / module description) → sinh REQ từ tài liệu sai → toàn bộ flow sai. Luôn validate sơ bộ ở Bước 1.

---

## Checklist nhanh trước khi dùng spec_parser.md mới

- [ ] 7 bước đủ, đúng thứ tự
- [ ] Bước 2 reference đúng section header của spec mới
- [ ] Bước 6 có tên parameter và module thực tế
- [ ] Gate 1 yêu cầu `needs_human_decision == 0`
- [ ] Schema path trỏ đúng (`schemas/structured_spec_schema.json`)
- [ ] Không có hardcode tên cũ (`rv32im_`, `PR_M_EXT_EN`, v.v.) còn sót
