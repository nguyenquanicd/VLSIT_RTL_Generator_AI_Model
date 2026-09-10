#!/bin/bash
# Source this file to set up the RTL flow environment (100% open-source EDA)
# Usage: source sourceme.sh

# Project root = git repo root (wherever this file lives)
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Open-source EDA tools (oss-cad-suite) ────────────────────────────────────
source /etc/profile.d/modules.sh
module load oss-cad-suite   # Yosys 0.58 · Verilator 5.041 · Icarus 13.0
                             # SymbiYosys (sby) · cocotb 2.1 · GTKWave
                             # nextpnr · yosys-smtbmc · slang plugin

# ── RISC-V bare-metal toolchain ──────────────────────────────────────────────
module load riscv            # riscv64-unknown-elf-gcc 14.2.0

# ── PDK paths ────────────────────────────────────────────────────────────────
export PDK_ROOT="/tools/PDK"
export PDK_GF180="$PDK_ROOT/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0"
export PDK_GF180_LIB_TT="$PDK_GF180/build/synopsys/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80_full.lib"
export PDK_GF180_LIB_SS="$PDK_GF180/build/synopsys/gf180mcu_fd_sc_mcu7t5v0__ss_125C_1v62_full.lib"

# ── Convenience aliases ───────────────────────────────────────────────────────
# Lint với Verilator
alias lint='verilator --lint-only --sv --Wall -f "$PROJECT_ROOT/src/rtl/filelist.f" --top-module'

# Simulation với Icarus (thay thế VCS)
alias isim='iverilog -g2012 -f "$PROJECT_ROOT/src/rtl/filelist.f"'

# Formal verification với SymbiYosys
alias formal='sby -f'

# Synthesis với Yosys + GF180MCU
alias synth-gf180='yosys -p "
  plugin -i slang;
  read_slang -f $PROJECT_ROOT/src/rtl/filelist.f;
  hierarchy -check -top \$TOP;
  proc; opt; techmap;
  dfflibmap -liberty $PDK_GF180_LIB_TT;
  abc -liberty $PDK_GF180_LIB_TT;
  stat -liberty $PDK_GF180_LIB_TT;
"'

echo "PROJECT_ROOT = $PROJECT_ROOT"
echo ""
echo "Open-source EDA tools loaded:"
echo "  Simulator  : Icarus Verilog $(iverilog -V 2>&1 | head -1 | grep -oP 'version \S+')"
echo "  Lint       : Verilator $(verilator --version 2>/dev/null | head -1)"
echo "  Synthesis  : $(yosys --version 2>/dev/null)"
echo "  Formal     : SymbiYosys $(sby --version 2>/dev/null)"
echo "  Cocotb     : $(cocotb-config --version 2>/dev/null)"
echo "  RISC-V GCC : $(riscv64-unknown-elf-gcc --version 2>/dev/null | head -1)"
echo "  PDK        : GF180MCU (TT 025C 1v80 · SS 125C 1v62)"
echo ""
echo "Aliases: lint · isim · formal · synth-gf180"
