// RTL
-f src/rtl/filelist.f
// TB
src/tb/axi_downscaler_tb_signals.sv
src/tb/axi_downscaler_bfm.sv
src/tb/axi_downscaler_tb_top.sv
// TCs
src/tb/tests/tc_001_reset_default_state.sv
src/tb/tests/tc_002_basic_downscale_transfer.sv
src/tb/tests/tc_003_back_to_back_throughput.sv
src/tb/tests/tc_004_m_axis_handshake_stall.sv
src/tb/tests/tc_005_fifo_backpressure.sv
src/tb/tests/tc_006_no_spurious_err_fifo.sv
src/tb/tests/tc_007_protocol_error_detect.sv
src/tb/tests/tc_008_excluded_sideband_signals.sv
src/tb/tests/tc_009_clock_freq_target.sv
src/tb/tests/tc_010_latency_measurement.sv
src/tb/tests/tc_011_width_ratio_default.sv
src/tb/tests/tc_012_bit_toggle_coverage.sv
