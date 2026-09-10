# RTL Generation Flow — Guideline

**Git repo:** `https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model` (hoặc `git clone` về `~/VLSIT_RTL_Generator_AI_Model`)
**Template commands:** `.claude/commands/` (Claude Code slash commands)
**RTL coding rules:** `rtl_rule.md`

---

## Bước 0 — Setup môi trường

```bash
cd ~/VLSIT_RTL_Generator_AI_Model
source sourceme.sh          # load tools + set $PROJECT_ROOT
```

`sourceme.sh` tự động load:
- `synopsys/vcs/X-2025.06` — simulation
- `oss-cad-suite` — Yosys 0.58 + Verilator 5.041
- `riscv` — riscv-gcc 14.2.0
- export `$PROJECT_ROOT` = git repo root

---

## Bước 0b — Chuẩn bị cho project mới

Slash commands đã có sẵn trong `.claude/commands/` — không cần copy thêm.

Chỉnh `spec_parser.md` (hoặc `.claude/commands/spec_parser.md`) cho design mới:
1. **Bước 2** — Section headers thực tế của spec mới
2. **Bước 6.1** — Tên parameter của design mới
3. **Bước 6.2** — Tên module RTL của design mới

Chi tiết xem `claude_template/spec_parser_authoring_rules.md`.

---

## Flow tổng quan

```
source sourceme.sh

/spec_parser <spec.md>              → schemas/structured_spec.json   (Gate 1)
/config_ui                          → schemas/final_config.json       (Gate 2)

        ┌───────────────────────────────────┐
  /rtl_generator                  /tb_generator      ← song song được
  src/rtl/ + lint + synth         src/tb/tests/
  Gate 3a                         Gate 4
        └───────────────────────────────────┘

/sva_generator                      → schemas/rtm.json                (Gate 3b)
/verification                       → schemas/verification_report.json (Gate 5)
/spec_pdf_generator                 → docs/specification.pdf           (Phase 6)
```

> RTL và TB có thể chạy song song sau Gate 2 vì `/tb_generator` không đọc RTL source.
> Phase 6 chỉ chạy được sau khi Gate 5 đã ký.

---

## Phase 1 — Parse Spec

```
/spec_parser <spec_file.md>
```

Output: `schemas/structured_spec.json` (Gate 1 phải ký mới tiếp tục).

---

## Phase 2 — Config

```
/config_ui
```

Output: `schemas/final_config.json` (Gate 2).

---

## Phase 3a — Generate RTL

```
/rtl_generator
```

Sinh `src/rtl/` (18 modules) + `src/rtl/filelist.f`.

**Lint check sau khi sinh:**
```bash
source sourceme.sh
verilator --lint-only --sv --Wall -f src/rtl/filelist.f --top-module <top_module>
# Phải 0 warnings
```

**Synthesis (GF180MCU — Sky130 không có trên server):**
```bash
yosys scripts/synth_gf180.sh
# PDK: /tools/PDK/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0/
#      build/synopsys/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80_full.lib
```

---

## Phase 3b — Generate SVA

```
/sva_generator
```

Sinh `src/sva/` + `src/sva/filelist_sva.f`. Output: `schemas/rtm.json` (Gate 3b).

---

## Phase 4 — Generate Testbench

```
/tb_generator
```

Sinh `src/tb/` (TB top + models + TC files). Output: `schemas/selected_testplan.json` (Gate 4).

---

## Phase 5 — Verification

```
/verification
```

### Thủ công nếu cần:

**Bước 1 — Compile TB + Run (Icarus Verilog — open-source):**
```bash
source /etc/profile.d/modules.sh && module load oss-cad-suite
cd $PROJECT_ROOT
bash src/tb/run_icarus_sim.sh       # PHẢI chạy từ PROJECT_ROOT
# Binary: sim/axi_downscaler_tb  |  Log: sim/sim.log
```

**Hoặc dùng VCS (nếu có):**
```bash
source sourceme.sh
cd $PROJECT_ROOT
bash src/tb/run_vcs_compile.sh      # PHẢI chạy từ PROJECT_ROOT
# Binary: sim/simv (hoặc work/simv tuỳ script)
```

**Bước 2 — Run sim (VCS only — Icarus đã chạy trong script trên):**
```bash
cd $PROJECT_ROOT/sim
./rv32im_tb -suppress=ASLR_DETECTED_INFO 2>&1 | tee sim.log
```

**Bước 3 — Kiểm tra:**
```bash
grep -E "\[PASS\]|\[FAIL\]|\[N/A\]|TESTBENCH SUMMARY" sim/sim.log
# Target: TESTBENCH SUMMARY: N PASS, 0 FAIL
```

Output: `schemas/verification_report.json` (Gate 5).

---

## Cấu trúc thư mục

```
VLSIT_RTL_Generator_AI_Model/   ← git root
├── docs/                       ← GENERATED — spec PDF output
│   ├── specification.md        ← Markdown source
│   └── specification.pdf       ← PDF (nếu pandoc/weasyprint có sẵn)
├── .claude/
│   └── commands/               ← 7 slash commands (spec_parser ... spec_pdf_generator)
├── claude_template/
│   ├── commands/               ← bản gốc của slash commands (backup)
│   ├── schemas/                ← JSON schema validate từng gate
│   └── spec_parser_authoring_rules.md
├── Result/                     ← lưu trữ kết quả các lần gen
│   ├── RISCV_24_08_2026/       ← spec v0.2 | 24/24 PASS | Gate 1–5 hoàn tất
│   │   ├── src/rtl/            ← 18 modules
│   │   ├── src/sva/            ← 35 assertions
│   │   ├── src/tb/             ← TB top + 24 TCs
│   │   ├── schemas/            ← 5 gate artifacts
│   │   └── spec_parser.md
│   ├── RISCV_23_08_2026/       ← spec v0.4 | 191 REQ | Gate 1–3b hoàn tất
│   └── DOWNSCALER_03_09_2026/  ← AXI Downscaler 64b→32b | 12/16 REQ s/o | Gate 1–5 hoàn tất
│       ├── src/rtl/            ← 18 modules (12731 cells, 371k µm²)
│       ├── src/sva/            ← 181 properties
│       ├── schemas/            ← structured_spec + config + rtm
│       ├── PROGRESS.md         ← checkpoint trạng thái
│       └── spec_parser.md
├── schemas/                    ← Gate artifacts project hiện tại (tracked)
├── src/                        ← GENERATED (gitignored)
├── sim/                        ← GENERATED (gitignored)
├── work/                       ← GENERATED (gitignored)
├── rtl_rule.md
├── sourceme.sh
├── guideline.md
└── .gitignore
```

---

## Gotchas

| Vấn đề | Fix |
|--------|-----|
| VCS không detect thay đổi TC file | Xóa `csrc/` và `sim/*.daidir/`, compile lại |
| `run_vcs_compile.sh` fail | Phải chạy từ `$PROJECT_ROOT`, không được chạy từ subfolder |
| Sky130 không có trên server | Dùng GF180MCU cho synthesis |
| `structured_spec.json` thiếu khi chạy `/tb_generator` | TB dùng REQ-IDs từ `rtm.json` thay thế |
| Slash command không nhận diện | Kiểm tra `.claude/commands/*.md` có đúng tên không |
| Icarus: `$realtime` trong CU-scope task → crash VPI type=600 | Thay bằng `longint'($time)` — Icarus 13.0 devel bug |
| Icarus: `disable fork` trong `automatic` task → assertion fail | Dùng done-flag `fork...join` pattern thay `join_any` |
| Icarus: `#(real_param)` delay trong CU-scope task → hang | Dùng literal delay hoặc `@(posedge clk)` |
| Icarus: TB signals file thiếu timescale → VCD crash | Thêm `` `timescale 1ns/1ps `` vào đầu file TB signals |

---

## Kết quả tham khảo (rv32im_core, 2026-08)

| Metric | Value |
|--------|-------|
| RTL modules | 18 |
| Lint warnings | 0 |
| Synthesis cells (GF180) | 13,050 |
| Chip area | ~378,000 µm² |
| SVA assertions | 35 |
| Test cases | 24 |
| Simulation | **24/24 PASS** |
| Mutation sign-off | 8/23 REQ-IDs |

## Kết quả tham khảo (axi_downscaler, 2026-09-03)

| Metric | Value |
|--------|-------|
| IP | AXI Downscaler 64b→32b |
| RTL modules | 4 |
| Lint warnings | 0 |
| Synthesis (GF180) | 2 corners PASS |
| SVA assertions | 19 |
| Test cases | 12 (11 PASS, 1 N/A-STA) |
| Simulation (Icarus Verilog 13.0) | **12/12 PASS** |
| Mutation (all modules) | fifo=100% · m_axis=100% · top=91.7% · width_split=87.5% |
| Sign-off | **12/16 REQ-IDs** |
