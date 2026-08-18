#!/bin/bash
# Yosys synthesis with GF180MCU TT corner
set -e
cd /home/ltthinh/CLAUDE_PRO

module load oss-cad-suite 2>/dev/null || true

LIB=/tools/PDK/GF180/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0/build/synopsys/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80_full.lib
FILES=$(grep '^/' src/rtl/filelist.f | tr '\n' ' ')

yosys << YEOF
read_verilog -sv $FILES
hierarchy -top rv32im_core
synth -top rv32im_core
dfflibmap -liberty $LIB
abc -liberty $LIB
stat -liberty $LIB
YEOF
