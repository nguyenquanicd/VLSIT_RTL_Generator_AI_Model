#!/usr/bin/env bash
# run_icarus_sim.sh — Icarus Verilog 13.0 compile + simulate for axi_downscaler
# Must be run from DOWNSCALER_03_09_2026/ (PROJECT_ROOT)
#
# Icarus 13.0 workarounds applied in source:
#   - `timescale 1ns/1ps in tb_signals.sv (not in RTL files)
#   - clock uses literal #5, not #(LP_CLK_PERIOD_NS/2)
#   - $realtime replaced with longint'($time) in tc_010 (VPI type=600 bug)
#   - disable fork replaced with done-flag fork..join in tc_006
#   - #1; delays replaced with @(negedge tb_clk) in tc_007

set -euo pipefail

source /etc/profile.d/modules.sh
module load oss-cad-suite

mkdir -p sim

echo "=== Icarus Verilog compile ==="
iverilog -g2012 -o sim/axi_downscaler_tb \
    src/rtl/axi_downscaler_fifo.sv \
    src/rtl/axi_downscaler_width_split.sv \
    src/rtl/axi_downscaler_m_axis_if.sv \
    src/rtl/axi_downscaler_top.sv \
    src/tb/axi_downscaler_tb_signals.sv \
    src/tb/axi_downscaler_bfm.sv \
    src/tb/axi_downscaler_tb_top.sv \
    src/tb/tests/tc_001_reset_default_state.sv \
    src/tb/tests/tc_002_basic_downscale_transfer.sv \
    src/tb/tests/tc_003_back_to_back_throughput.sv \
    src/tb/tests/tc_004_m_axis_handshake_stall.sv \
    src/tb/tests/tc_005_fifo_backpressure.sv \
    src/tb/tests/tc_006_no_spurious_err_fifo.sv \
    src/tb/tests/tc_007_protocol_error_detect.sv \
    src/tb/tests/tc_008_excluded_sideband_signals.sv \
    src/tb/tests/tc_009_clock_freq_target.sv \
    src/tb/tests/tc_010_latency_measurement.sv \
    src/tb/tests/tc_011_width_ratio_default.sv \
    src/tb/tests/tc_012_bit_toggle_coverage.sv \
    2>&1 | tee sim/compile.log

echo "=== Simulation ==="
vvp sim/axi_downscaler_tb 2>&1 | tee sim/sim.log

echo ""
echo "=== Results ==="
grep -E "\[PASS\]|\[FAIL\]|\[N/A\]|\[INFO\]|TESTBENCH SUMMARY" sim/sim.log || true

# Exit 1 if any FAIL in TESTBENCH SUMMARY line
if grep -qE "TESTBENCH SUMMARY:.*[1-9][0-9]* FAIL" sim/sim.log; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
exit 0
