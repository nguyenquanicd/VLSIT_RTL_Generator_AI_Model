# Phase 1 · Spec Ingestion — /spec_parser

**Mục tiêu:** Đọc spec RTL dạng Markdown, tách requirement, gán REQ-ID, phân loại,
chấm ambiguity score, review mơ hồ với người dùng, và xuất `schemas/structured_spec.json`.

**Gate 1** phải được người dùng ký. Mọi phase sau đều phụ thuộc file output này.

---

## Quy tắc bắt buộc

1. Mỗi requirement: REQ-ID duy nhất dạng `REQ-NNN` (zero-padded, bắt đầu từ REQ-001).
2. `ambiguity_score > 0.3` → `needs_review: true` → **bắt buộc hỏi người dùng trước Gate 1**.
3. Requirement không hỏi lại được sau tối đa 3 lần → ghi `ambiguity_score: 0.35`, `needs_human_decision: true`, block Gate 1 cho đến khi người dùng quyết định giữ hay xoá.
4. Không sinh RTL, SVA, hay testbench trong phase này.
5. Output phải conform `schemas/structured_spec_schema.json`.

---

## Granularity guide — khi nào tách, khi nào gộp

| Tách thành 2+ REQ | Gộp thành 1 REQ |
|---|---|
| 2 behavior có thể fail độc lập (test riêng được) | Cùng một điều kiện kích hoạt, cùng một output |
| Một cái có parameter điều khiển, cái kia không | Không có SVA nào có thể check riêng từng cái |
| Khác category (functional vs timing) | Spec mô tả chúng như một nguyên tử |

**Heuristic:** Nếu có thể viết 2 SVA assertion riêng biệt → tách. Nếu chỉ cần 1 assertion → gộp.

---

## Bước 1 — Xác định file spec đầu vào

Kiểm tra theo thứ tự:
1. Nếu gọi với argument (`/spec_parser <file>`): dùng file đó.
2. Nếu không: tìm `.md` file chứa từ khoá `spec`, `rtl_spec` trong tên.
3. Vẫn không thấy: hỏi người dùng đường dẫn.

Đọc file toàn bộ. Validate sơ bộ: phải có ít nhất một trong các dấu hiệu sau: bảng parameter, danh sách module, port list, hoặc mô tả pipeline. Nếu không có → cảnh báo "Đây có vẻ không phải RTL spec. Tiếp tục? (yes/no)".

Thông báo: _"Đã đọc `<file>`, `<N>` dòng — bắt đầu phân tích..."_

---

## Bước 2 — Trích requirement

Đọc spec theo từng section, tìm các loại nội dung sau:

| Nguồn trong spec | Category | Granularity |
|---|---|---|
| Feature list ✅ (mandatory) | `functional` | 1 REQ per feature row |
| Feature list ⬜ (optional) | `functional` | 1 REQ per feature row, ghi rõ `optional: true` |
| Port list / bus protocol | `interface` | Nhóm port cùng protocol = 1 REQ; quy tắc handshake (B1–B10) = 1 REQ mỗi quy tắc |
| Timing / latency / penalty | `timing` | 1 REQ per latency spec |
| Exception / interrupt table | `functional` | 1 REQ per exception type hoặc nhóm tương tự |
| Elaboration constraint (C1–C5) | `constraint` | 1 REQ per constraint |
| Module behavior (§5–§18) | `functional` | 1 REQ per behavior block không tách được |

**Không tạo REQ-ID cho:**
- Nội dung chỉ giải thích lý do (rationale)
- Danh sách "out of scope"
- Comment / ví dụ waveform

---

## Bước 3 — Chấm ambiguity score + sinh sva_hint

**Ambiguity score:**

| Score | Mô tả | Ví dụ |
|---|---|---|
| 0.0–0.1 | Bảng tra cứu đầy đủ, không cần diễn giải | "B2: payload stable khi valid=1 và ready=0" |
| 0.1–0.3 | Cần đọc thêm context nhưng chỉ có 1 cách hiểu | "Load-use penalty 1 cycle" |
| 0.3–0.6 | Có thể hiểu ≥2 cách, thiếu chi tiết | "Precise exception" — commit point chưa nói rõ |
| 0.6–1.0 | Spec không đủ để implement | Requirement tự suy ra không có trong spec gốc |

**sva_hint** — ghi 1 trong các giá trị:
- `"property"` — dùng `assert property` với clock/reset
- `"static"` — dùng `initial $fatal` (elaboration check)
- `"cover"` — dùng `cover property` (reachability)
- `"assume"` — dùng `assume property` (constraint cho formal)
- `"sequence"` — cần định nghĩa sequence phức tạp trước

---

## Bước 4 — Review bắt buộc các requirement mơ hồ

Thực hiện **trước** khi hỏi người dùng chỉnh sửa tùy chọn.

Với từng REQ-ID có `needs_review: true`:

```
⚠ REQ-XXX [ambiguity: 0.45] — Lần hỏi 1/3
Text hiện tại: "..."
Vấn đề: <giải thích cụ thể tại sao mơ hồ>
Câu hỏi: <câu hỏi yes/no hoặc multiple-choice, không hỏi open-ended>
→
```

Sau khi người dùng trả lời:
1. Cập nhật text requirement.
2. Chấm lại score.
3. Nếu score ≤ 0.3 → resolved ✓, sang REQ tiếp theo.
4. Nếu score vẫn > 0.3 → hỏi tiếp (tối đa 3 lần).
5. Sau lần 3 vẫn > 0.3 → ghi `needs_human_decision: true`, block Gate 1 cho REQ này.

Khi tất cả đã review xong, hiển thị:
```
Review mơ hồ hoàn tất: X resolved, Y cần quyết định của người dùng.
```

Với mỗi REQ còn `needs_human_decision: true`, hỏi:
> **"REQ-XXX: Giữ nguyên với rủi ro hallucination, xoá, hay tách nhỏ hơn? (keep/delete/split)"**

---

## Bước 5 — Chỉnh sửa tùy chọn

Hiển thị danh sách đầy đủ theo nhóm category (sau khi đã review mơ hồ):

```
╔══ PHASE 1 · SPEC REVIEW ══════════════════════════════════════════════╗
║  Tổng: XX requirements  │  Resolved: YY  │  Pending decision: ZZ    ║
╠══ FUNCTIONAL (N) ════════════════════════════════════════════════════╣
║  REQ-001 [0.05] ✓  RV32I base integer: 40 instructions              ║
║  REQ-002 [0.08] ✓  RV32M: MUL MULH MULHSU MULHU DIV DIVU REM REMU  ║
║  ...                                                                 ║
╠══ INTERFACE (N) ═════════════════════════════════════════════════════╣
║  ...                                                                 ║
╠══ TIMING (N) ════════════════════════════════════════════════════════╣
║  ...                                                                 ║
╠══ CONSTRAINT (N) ════════════════════════════════════════════════════╣
║  ...                                                                 ║
╠══ CẦN QUYẾT ĐỊNH (needs_human_decision) ════════════════════════════╣
║  🔴 REQ-XXX [0.45] "..." — đã hỏi 3 lần, chưa resolve              ║
╚═══════════════════════════════════════════════════════════════════════╝
```

Hỏi: **"Bạn muốn chỉnh sửa, thêm, hoặc xoá requirement nào? (REQ-ID hoặc 'none')"**

Cho phép: chỉnh text, tách, merge, xoá, thêm mới.
Sau mỗi thao tác: chấm lại ambiguity, cập nhật sva_hint nếu cần.

---

## Bước 6 — Mapping

**6.1 REQ-ID → Parameter**

Đọc bảng §2.2 (Parameter) và §1.1 (Feature list), xây dựng:
```
PR_M_EXT_EN   → [REQ-002, REQ-017]
PR_CSR_EN     → [REQ-003, REQ-011, REQ-015]
...
```
Ghi vào trường `parameters_affected` của mỗi requirement.

**6.2 REQ-ID → RTL module**

Đọc bảng §3.2 (Module list), map từng requirement sang module RTL chịu trách nhiệm implement:
```
REQ-001 (PC sau reset)         → rv32im_if_stage (U03)
REQ-002 (RV32M decode)         → rv32im_decoder (U05), rv32im_muldiv (U11)
REQ-007 (Load-use penalty)     → rv32im_hazard_ctrl (U18)
...
```
Ghi vào trường `rtl_modules` của mỗi requirement. Phase 3 dùng trường này để biết module nào cần tag REQ-ID nào.

---

## Bước 7 — Gate 1

```
╔══ GATE 1 · SPEC REVIEW SUMMARY ════════════════════╗
║  Total requirements:      XX                      ║
║    Functional:            XX                      ║
║    Interface:             XX                      ║
║    Timing:                XX                      ║
║    Constraint:            XX                      ║
║  Ambiguity resolved:      XX / XX                 ║
║  needs_human_decision:    XX  ← phải = 0 để mở   ║
║  Parameters mapped:       15 (P01–P15)            ║
║  RTL modules mapped:      18 (U01–U18)            ║
╚════════════════════════════════════════════════════╝
```

Nếu `needs_human_decision > 0` → **Không mở Gate 1**. Yêu cầu giải quyết hết.

Hỏi: **"Xác nhận spec đủ rõ và mở Gate 1? (yes/no)"**
- `no` → quay Bước 5
- `yes` → ghi `schemas/structured_spec.json` (conform `schemas/structured_spec_schema.json`), set `gate_1_approved: true`

Thông báo: **"✓ Gate 1 đã ký. `schemas/structured_spec.json` ghi xong. Tiếp theo: `/config_ui`."**

---

## Xử lý lỗi

| Tình huống | Hành động |
|---|---|
| Spec file không tìm thấy | Hỏi đường dẫn |
| File không có dấu hiệu RTL spec | Cảnh báo, hỏi xác nhận trước khi tiếp tục |
| REQ trùng lặp (cùng behavior) | Đề xuất merge, chờ người dùng xác nhận |
| Spec < 10 requirements | Cảnh báo "Spec có vẻ thiếu" |
| Ambiguity > 0.3, người dùng muốn bỏ qua | Từ chối — giải thích: đây là nguyên nhân chính gây hallucination RTL |
| `structured_spec.json` đã tồn tại | Hỏi "Ghi đè? Lịch sử REQ-ID cũ sẽ mất." |
| Spec có section "out of scope" | Đọc để biết nhưng **không** tạo REQ-ID cho những hạng mục đó |
