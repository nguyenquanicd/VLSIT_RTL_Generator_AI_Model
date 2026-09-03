# Master Guideline — RTL Gen Flow (Auto Mode)

Đây là guideline để chạy toàn bộ flow tự động với 1 lệnh duy nhất.  
Phù hợp cho: project mới, spec đã chuẩn bị sẵn.

---

## Chuẩn bị (1 lần per project)

### 1. Setup môi trường

```bash
cd ~/DOWNSCALER          # hoặc tên project folder
source sourceme.sh       # load tools + set $PROJECT_ROOT
```

### 2. Chuẩn bị spec_parser.md

Đây là bước **duy nhất cần làm thủ công** trước khi chạy auto flow.

Chỉnh `.claude/commands/spec_parser.md` tại 3 chỗ:
1. **Bước 2** — Section headers của spec mới
2. **Bước 6.1** — Tên parameter của design mới  
3. **Bước 6.2** — Tên module RTL của design mới

Xem chi tiết: `claude_template/spec_parser_authoring_rules.md`

### 3. Chuẩn bị file spec

Đặt file spec vào project folder:
```
DOWNSCALER/
└── spec/
    └── downscaler_spec.md    ← viết spec tại đây
```

---

## Chạy Auto Flow

```
/autoflow spec/downscaler_spec.md
```

Flow sẽ tự chạy qua 6 phase. Agent **dừng 3 lần** để bạn review:

```
Phase 1 → [DỪNG Gate 1] → Phase 2 (auto) → Phase 3a ─┐
                                                        ├─ song song
                                          Phase 4  ────┘
          → Phase 3b → [DỪNG Gate 3b] → Phase 5 → [DỪNG Gate 5] → Phase 6
```

---

## 3 Gate Cần Human Review

### Gate 1 — Spec Quality
Agent sẽ hỏi: **"Approve Gate 1? (yes/no)"**

Bạn cần kiểm tra:
- Số REQ-ID có đủ không?
- Ambiguity còn không (needs_human_decision > 0)?
- Module mapping có đúng không?

Nếu "no" → sửa spec → chạy lại `/autoflow`

### Gate 3b — SVA Review  
Agent sẽ hỏi: **"Approve Gate 3b? (yes/no)"**

Bạn cần đọc: `src/sva/GATE3_REVIEW.md`
- Property có đúng intent không?
- Property nào vacuous → cần thêm stimulus sau

Nếu "no" → sửa SVA thủ công → gõ "yes" để tiếp tục

### Gate 5 — Verification Sign-off
Agent sẽ hỏi: **"Sign off Gate 5? (yes/no)"**

Bạn cần kiểm tra:
- Tất cả TC PASS chưa?
- Mutation score có chấp nhận được không (< 85% là locked)?
- REQ-IDs nào cần thêm TC để improve?

---

## Resume nếu bị interrupt

```bash
/autoflow spec/downscaler_spec.md --from phase3b   # resume từ SVA
/autoflow spec/downscaler_spec.md --from phase5    # resume từ verification
/autoflow spec/downscaler_spec.md --from phase6    # chỉ gen PDF
```

Agent tự đọc `schemas/` để biết gate nào đã ký.

---

## Output sau khi hoàn tất

```
DOWNSCALER/
├── schemas/
│   ├── structured_spec.json      ← Gate 1
│   ├── final_config.json         ← Gate 2
│   ├── rtm.json                  ← Gate 3b
│   ├── selected_testplan.json    ← Gate 4
│   └── verification_report.json  ← Gate 5
├── src/
│   ├── rtl/   ← 18+ modules
│   ├── sva/   ← SVA properties
│   └── tb/    ← testbench + TCs
└── docs/
    ├── specification.md
    └── specification.pdf          ← Phase 6
```

---

## So sánh: Manual vs Auto

| | Manual | Auto (`/autoflow`) |
|-|--------|-------------------|
| Số lệnh cần gõ | 7 slash commands | 1 lệnh |
| Gate review | Mỗi gate 1 lần hỏi | Chỉ 3 gate quan trọng |
| RTL + TB | Phải gõ riêng | Tự chạy song song |
| PDF | Phải gọi thêm | Tự gen cuối flow |
| Thời gian | ~30-60 phút tương tác | ~5 phút tương tác |

---

## Khi nào dùng Manual thay vì Auto?

- Spec phức tạp, cần review từng REQ-ID kỹ
- Muốn custom RTL rule trước khi gen
- Debug lỗi ở phase cụ thể
- Chạy lại 1 phase đơn lẻ

Manual flow xem tại: `guideline.md`
