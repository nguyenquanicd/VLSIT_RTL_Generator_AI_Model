#!/bin/bash
# VCS compile for rv32im_core testbench (Phase 4)
source /etc/profile.d/modules.sh && module load synopsys/vcs/X-2025.06
vcs -sverilog -full64 -timescale=1ns/1ps \
  -f /home/ltthinh/CLAUDE_PRO/src/tb/filelist_tb.f \
  +incdir+/home/ltthinh/CLAUDE_PRO/src/tb \
  -top rv32im_tb_top \
  -o /home/ltthinh/CLAUDE_PRO/sim/rv32im_tb \
  +define+SIMULATION \
  "$@"
