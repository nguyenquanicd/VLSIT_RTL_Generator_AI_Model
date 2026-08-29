#!/bin/bash
# Source this file to set up the RTL flow environment
# Usage: source sourceme.sh

# Project root = git repo root (wherever this file lives)
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# EDA tools
source /etc/profile.d/modules.sh
module load synopsys/vcs/X-2025.06   # VCS simulation
module load oss-cad-suite             # Yosys 0.58 + Verilator 5.041 + Icarus
module load riscv                     # riscv64-unknown-elf-gcc 14.2.0

# Convenience aliases
alias lint='verilator --lint-only --sv --Wall -f "$PROJECT_ROOT/src/rtl/filelist.f" --top-module'
alias synth='yosys "$PROJECT_ROOT/scripts/synth_gf180.sh"'

echo "PROJECT_ROOT = $PROJECT_ROOT"
echo "Tools loaded: VCS X-2025.06 | Yosys 0.58 | Verilator 5.041 | riscv-gcc 14.2.0"
