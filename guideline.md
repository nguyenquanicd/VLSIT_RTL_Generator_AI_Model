# Hướng dẫn sử dụng VLSIT RTL Design & Verification Flow 

Hướng dẫn cho chế độ **tự động** và **từng bước**, đối chiếu với command prompt Claude Code trong `.claude/commands/` và project skill cho Codex CLI trong `.agents/skills/`.

**Mục tiêu:** chuyển đặc tả phần cứng thành RTL, assertions, testbench và tài liệu; dùng công cụ EDA để kiểm tra và kỹ sư để review kết quả.

## 1. Chuẩn bị

### Môi trường

- Claude Code để thực hiện các slash command, hoặc Codex CLI để thực hiện project skill.
- Linux/Bash với Verilator, Yosys và simulator phù hợp. Các script hiện giả định có Environment Modules.
- GF180MCU Liberty libraries nếu chạy technology-mapped synthesis.
- VCS nếu cần chạy đường kiểm chứng SVA hiện có. Đường chạy Icarus bỏ qua SVA.
- Công cụ chuyển PDF phù hợp; script `scripts/md_to_pdf.py` sử dụng Python và Matplotlib.

Tại **project root** — thư mục chứa `sourceme.sh`, `.claude/commands/` và `.agents/skills/` — kiểm tra đường dẫn công cụ/PDK rồi chạy trong terminal Bash:

```bash
source sourceme.sh
```

Script thiết lập `PROJECT_ROOT` theo vị trí của chính nó, nạp các module EDA/toolchain được khai báo và thiết lập đường dẫn PDK. **Bản hiện tại không tự nạp VCS.** Nếu dùng VCS trên môi trường gốc:

```bash
module load synopsys/vcs/X-2025.06
```

Tên module và đường dẫn `/tools/PDK` cần điều chỉnh theo máy thực tế. Trên Windows, sử dụng môi trường Linux phù hợp như WSL hoặc máy chủ EDA; các lệnh Bash không chạy trực tiếp trong PowerShell.

### Đặc tả và prompt

1. Đặt đặc tả tại `spec/<ip_name>_spec.md`, mô tả rõ chức năng, interface, parameter, clock/reset, timing và error behavior.
2. Kiểm tra đủ **9 command** trong `.claude/commands/` và quy tắc coding trong `rtl_rule.md`.
3. Khi đổi IP, cập nhật parser mapping **và các prompt liên quan**: configuration, danh sách module, SVA, test plan và tài liệu. Một số template có thể gắn với cấu trúc thiết kế tham khảo; cần cập nhật đồng bộ thay vì chỉ sửa parser.
4. Chuẩn bị schema tại đường dẫn các prompt yêu cầu; bản mẫu nằm trong `claude_template/schemas/`.

> Một số snapshot có thể chứa artifact đầu vào trùng tên với prompt trong `.claude/commands/`. Hãy xác định vai trò và nguồn gốc của file trước khi dùng làm baseline.

## 2. Chọn cách chạy

| Chế độ | Khi sử dụng | Cách thực hiện |
|---|---|---|
| **Tự động** | Spec và prompt đã được chuẩn bị cho IP đích. | Claude Code: `/autoflow`; Codex CLI: `$source-command-autoflow`. |
| **Từng bước** | Cần kiểm soát cấu hình, review chi tiết, debug hoặc chạy lại một phase. | Gọi từng command hoặc skill theo bảng ở mục 4. |

**Các lệnh bắt đầu bằng `/` được nhập trong hội thoại Claude Code; skill bắt đầu bằng `$source-command-...` được gọi trong Codex CLI.** Cả hai đều là hướng dẫn cho agent, không phải chương trình shell độc lập.

Ví dụ trong Codex CLI tại project root:

```text
$source-command-autoflow
Dùng spec/<ip_name>_spec.md
```

Để chạy riêng một phase, gọi skill tương ứng, ví dụ `$source-command-spec-parser`. README có bảng ánh xạ đầy đủ giữa 9 skill và command.

## 3. Chạy tự động

Với spec đã có:

```text
/autoflow spec/<ip_name>_spec.md
```

Nếu cần agent hỗ trợ soạn spec từ mô tả:

```text
/autoflow --describe
```

Luồng thực hiện:

```text
Spec → Parse → [Gate 1: review] → Config
     → RTL + lint/synthesis và Testbench
     → SVA → [Gate 3b: review]
     → Verification → [Gate 5: review] → Markdown/PDF
```

Theo `/autoflow`, Gate 2 dùng giá trị mặc định hoặc override đã được cung cấp; Gate 2 và Gate 4 được tự xác nhận khi đạt điều kiện. Các command chạy riêng có thể yêu cầu xác nhận bổ sung — cần làm rõ chế độ với agent trước khi bắt đầu.

RTL và TB có thể được chuẩn bị độc lập sau Gate 2; trong một session, orchestrator cho phép chạy tuần tự. **Compile testbench vẫn cần RTL**, nên không thể chốt compile pass chỉ bằng việc sinh xong TB.

## 4. Chạy từng bước

Thực hiện theo thứ tự dưới đây; Phase 4 được đặt trước Phase 3b để có testbench phục vụ kiểm tra assertions.

| Bước | Claude Code command | Codex CLI skill | Kết quả cần kiểm tra |
|---|---|---|---|
| 1 — Parse spec | `/spec_parser spec/<ip_name>_spec.md` | `$source-command-spec-parser` | `structured_spec.json`: REQ-ID, ambiguity, mapping requirement → parameter/module. |
| 2 — Config | `/config_ui` | `$source-command-config-ui` | `final_config.json`: giá trị parameter và các constraint đã được xác nhận. |
| 3a — RTL | `/rtl_generator` | `$source-command-rtl-generator` | `src/rtl/`, file list; kết quả lint và synthesis thực tế. |
| 4 — Testbench | `/tb_generator` | `$source-command-tb-generator` | `src/tb/`, `selected_testplan.json`; TC coverage và compile check. |
| 3b — Assertions | `/sva_generator` | `$source-command-sva-generator` | `src/sva/`, bind, `rtm.json`; property đúng ý nghĩa và compile hợp lệ. |
| 5 — Verification | `/verification` | `$source-command-verification` | Simulation, mutation, verification gaps và `verification_report.json`. |
| 6 — Documentation | `/spec_pdf_generator` | `$source-command-spec-pdf-generator` | `docs/specification.md` và PDF khi có công cụ; theo flow chuẩn cần Gate 5 đã ký. |

Các JSON artifact trong bảng được lưu ở `schemas/`. Nếu chưa có simulator hoặc synthesis tool cần thiết, phải ghi rõ bước chưa chạy; không xem artifact đã sinh là bằng chứng kiểm chứng đạt.

## 5. Ba điểm review quan trọng

| Gate | Kỹ sư cần kiểm tra | Điều kiện để tiếp tục |
|---|---|---|
| **Gate 1 — Spec** | Yêu cầu đầy đủ, không còn quyết định mơ hồ chưa xử lý; mapping đúng. | Xác nhận spec làm baseline cho các bước sau. |
| **Gate 3b — SVA** | Property diễn đạt đúng intent; bind đúng tín hiệu; phân biệt assert/cover và nhận diện vacuity. Đọc `GATE3_REVIEW.md` nếu được tạo. | Xác nhận ý nghĩa property; ghi rõ property chưa được kích hoạt bởi stimulus. |
| **Gate 5 — Verification** | Kết quả từng TC, SVA thực sự đã chạy hay chưa, mutation score và requirement còn thiếu bằng chứng. | Review dựa trên log thực thi và ký các requirement đủ điều kiện. |

RTM (*Requirement Traceability Matrix*) nối **REQ-ID → RTL → SVA → TC → kết quả → sign-off**.

- Theo prompt hiện tại, mutation score **< 85%** khóa sign-off của requirement tương ứng. `N/A` có thể được cho phép theo chính sách của flow, nhưng không phải kết quả mutation pass.
- Gate 5 đã ký **không đồng nghĩa tất cả requirements đã sign-off**; vẫn có thể còn mục locked/pending.
- TC `N/A`, kiểm tra cấu trúc hoặc phép đo không có tiêu chí pass/fail phải được phân biệt với kiểm tra chức năng đạt. Synthesis không thay thế STA để xác nhận tần số.

## 6. Tiếp tục sau khi gián đoạn

```text
/autoflow spec/<ip_name>_spec.md --from phase3b
/autoflow spec/<ip_name>_spec.md --from phase5
/autoflow spec/<ip_name>_spec.md --from phase6
```

Trong Codex CLI, gọi `$source-command-autoflow` và nêu spec cùng phase cần tiếp tục, ví dụ: “Tiếp tục `spec/<ip_name>_spec.md` từ phase3b”.

Agent đọc artifact trong `schemas/` để tiếp tục. Trước khi resume, xác nhận spec, config, RTL và báo cáo cùng thuộc một phiên bản thiết kế. Nếu đầu vào đã thay đổi, chạy lại các bước bị ảnh hưởng; không tái sử dụng approval hoặc kết quả cũ một cách mặc định.

## 7. Đầu ra

```text
<project>/
├── schemas/
│   ├── structured_spec.json       # Requirements đã phân tích
│   ├── final_config.json          # Cấu hình đã chốt
│   ├── synth_report.json          # Kết quả synthesis nếu đã chạy
│   ├── rtm.json                   # Traceability và trạng thái sign-off
│   ├── selected_testplan.json     # Danh sách TC và mapping
│   └── verification_report.json   # Tổng hợp verification
├── src/
│   ├── rtl/                      # RTL + compile file list
│   ├── sva/                      # Assertions + bind + file list
│   └── tb/                       # Testbench, models/BFM và tests/
├── sim/ hoặc work/               # Đầu ra thực thi, tùy script
└── docs/
    ├── specification.md
    └── specification.pdf         # Nếu đã chuyển PDF thành công
```

Số module, test và artifact cụ thể phụ thuộc IP cũng như cấu hình. Ví dụ snapshot và cách đọc giới hạn của chúng được trình bày ở mục **Ví dụ thiết kế tham khảo** cuối README.

## 8. Chạy công cụ và xử lý lỗi

Các lệnh sau nhập trong **terminal Bash**, tại root của project thiết kế tương ứng.

**Lint toàn thiết kế** — thay `<top_module>` bằng tên top thực tế:

```bash
verilator --lint-only --sv --Wall -f src/rtl/filelist.f --top-module <top_module>
```

**Synthesis** — khi project đã có script `.ys` phù hợp:

```bash
yosys -l src/rtl/synth_tt.log src/rtl/synth_gf180_tt.ys
yosys -l src/rtl/synth_ss.log src/rtl/synth_gf180_ss.ys
```

| Vấn đề | Cách xử lý |
|---|---|
| Không nhận slash command | Kiểm tra project đang mở và `.claude/commands/`. |
| Không tìm thấy tool/module/PDK | Điều chỉnh môi trường và đường dẫn trong setup/script; `sourceme.sh` không tự cài công cụ. |
| Compile snapshot lỗi đường dẫn | Sửa đường dẫn tuyệt đối trong file lists và compile script cho máy hiện tại. |
| VCS không cập nhật TC | Kiểm tra include/file list; dọn cache build của đúng project rồi compile lại. |
| Yosys không đọc được cấu trúc SystemVerilog | Chọn frontend phù hợp như slang khi cần; kiểm tra Liberty có cell thực, không dùng file header-only. |
| Icarus lỗi task, delay hoặc waveform | Kiểm tra cú pháp và workaround trong script/testbench của project; không áp dụng máy móc cho mọi phiên bản. |
| Artifact/schema hoặc báo cáo không khớp | Đối chiếu baseline, source và log; sửa tính nhất quán trước khi tiếp tục hoặc ký gate. |

Để xem một lệnh chạy cụ thể cùng các giới hạn của snapshot minh họa, tham khảo mục **Ví dụ thiết kế tham khảo** ở cuối README.

> **Lưu ý với snapshot:** một số log cuối cùng và mutation working files không có trong repository. Báo cáo lưu sẵn là tài liệu tham khảo; muốn xác nhận thiết kế hiện tại cần chạy lại và lưu đủ bằng chứng. Compile TB riêng cũng không thay thế verification có SVA và mutation.
