# RTL Generation Flow — Guideline

Template commands: `/home/ltthinh/CLAUDE_PRO/claude_template/`

---

## Dùng lại flow cho project RTL mới

### Bước 0 — Copy template (1 lần per project)

```bash
# Project-scoped (recommend)
mkdir -p <new_project>/.claude/commands
cp /home/ltthinh/CLAUDE_PRO/claude_template/commands/*.md <new_project>/.claude/commands/
cp -r /home/ltthinh/CLAUDE_PRO/claude_template/schemas/ <new_project>/schemas/
```

### Chỉnh spec_parser.md cho design mới (3 chỗ)

Mở `.claude/commands/spec_parser.md`, chỉnh:
1. **Bước 2** — Section headers thực tế của spec mới
2. **Bước 6.1** — Tên parameter của design mới
3. **Bước 6.2** — Tên module RTL của design mới

Phần còn lại (ambiguity rules, gate logic, error handling) giữ nguyên.
Xem chi tiết: `claude_template/spec_parser_authoring_rules.md`

---

## Chuẩn bị (rv32im_core / server nội bộ)

```bash
source /etc/profile.d/modules.sh
module load synopsys/vcs/X-2025.06   # VCS simulation
module load oss-cad-suite             # Yosys + Verilator + Icarus
module load riscv                     # riscv-gcc (nếu cần compile test binary)
```

---

## Phase 1 — Parse Spec

**Input:** `spec_parser.md`
**Slash command:** `/spec_parser`

Claude đọc spec, trích xuất requirements, sinh ra `structured_spec.json` và RTM draft.
Schema validate theo `claude_template/schemas/structured_spec_schema.json`.

---

## Phase 2 — Config & Gate 2

**Slash command:** `/config_ui`

Chọn parameter cho design (boot addr, IRQ, CSR, M-ext, trace, v.v.).
Output sign vào `schemas/final_config.json`.

```json
// Ví dụ parameter rv32im_core
{
  "PR_BOOT_ADDR":    "0x80000000",
  "PR_M_EXT_EN":     true,
  "PR_CSR_EN":       true,
  "PR_IRQ_EN":       true,
  "PR_TRACE_EN":     true,
  "PR_RF_RESET_EN":  true,
  "PR_FWD_EN":       true
}
```

---

## Phase 3a — Generate RTL

**Slash command:** `/rtl_generator`

Sinh 18 module SystemVerilog vào `src/rtl/`, bao gồm `filelist.f`.
Naming convention bắt buộc theo `rtl_rule.md`.

**Kiểm tra ngay sau khi sinh:**

```bash
# Lint check — phải 0 warnings
cd /home/ltthinh/CLAUDE_PRO
verilator --lint-only --sv --Wall -f src/rtl/filelist.f --top-module rv32im_core

# Synthesis — area/timing report
yosys synth_rv32im.ys   # dùng GF180MCU lib (Sky130 không có trên server)
# PDK lib: /tools/PDK/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0/
#           build/synopsys/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80_full.lib
```

---

## Phase 3b — Generate SVA & Gate 3

**Slash command:** `/sva_generator`

Sinh SVA bind files dựa trên RTM. Compile check bằng VCS:

```bash
vcs -sverilog -full64 -f src/rtl/filelist.f [sva_files] -top rv32im_core
```

Output sign vào `schemas/rtm.json` (Gate 3).

---

## Phase 4 — Generate Testbench & Gate 4

**Slash command:** `/tb_generator`

Sinh TB top + 24 TC tasks vào `src/tb/tests/tc_0XX_*.sv`.
Output sign vào `schemas/selected_testplan.json` (Gate 4).

---

## Phase 5 — Verification & Gate 5

**Slash command:** `/verification`

### Bước 1: Compile TB

```bash
cd /home/ltthinh/CLAUDE_PRO          # PHẢI chạy từ project root
bash src/tb/run_vcs_compile.sh
# Output binary: sim/rv32im_tb
```

### Bước 2: Run simulation

```bash
cd sim
./rv32im_tb -suppress=ASLR_DETECTED_INFO 2>&1 | tee sim.log
```

### Bước 3: Kiểm tra kết quả

```bash
grep -E "(PASS|FAIL|Total)" sim.log
# Target: 24/24 PASS, Total errors: 0
```

Output sign vào `schemas/verification_report.json` (Gate 5).

---

## Gotchas

| Vấn đề | Fix |
|--------|-----|
| VCS không detect TC file thay đổi → chạy binary cũ | Xóa `csrc/` và `sim/rv32im_tb.daidir/`, compile lại |
| Compile TB từ sai thư mục | Luôn `cd /home/ltthinh/CLAUDE_PRO` trước khi chạy `run_vcs_compile.sh` |
| Sky130 không có trên server | Dùng GF180MCU thay thế cho synthesis |
| Verilator lint dùng lib stub trong `liberty/` | Dùng full lib trong đường dẫn PDK đầy đủ |

---

## Kết quả tham khảo (rv32im_core, 2026-08-19)

| Metric | Value |
|--------|-------|
| RTL modules | 18 |
| Lint warnings | 0 |
| Synthesis cells (GF180) | 13,050 |
| Chip area | ~378,000 µm² |
| SVA assertions | 35 |
| Test cases | 24 |
| Simulation result | **24/24 PASS** |
