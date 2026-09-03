// TC-ALL | REQ-007, REQ-008, REQ-009
// Description: Shared AXI4-Stream driver/monitor BFM tasks (plain SV, no
//              UVM) operating directly on the global tb_* signals declared
//              in axi_downscaler_tb_signals.sv. tready/tvalid are read at
//              negedge (stable, glitch-free) and checked starting from the
//              SAME negedge the opposite signal is asserted — the check
//              predicts the outcome of the upcoming posedge, since the
//              combinational status signal cannot change again until that
//              edge. One extra negedge is waited after a positive detection
//              to let that accepting/popping posedge actually occur before
//              the driven signal is deasserted.

task automatic axis_send_s_beat(
  input logic [LP_WIDTH_IN-1:0]     data,
  input logic                       last,
  input logic [(LP_WIDTH_IN/8)-1:0] keep
);
  @(negedge tb_clk);
  tb_s_tdata  = data;
  tb_s_tkeep  = keep;
  tb_s_tlast  = last;
  tb_s_tvalid = 1'b1;
  while (!tb_s_tready) @(negedge tb_clk);
  @(negedge tb_clk);
  tb_s_tvalid = 1'b0;
endtask

task automatic axis_recv_m_beat(
  output logic [LP_WIDTH_OUT-1:0]     data_out,
  output logic                        tlast_out,
  output logic [(LP_WIDTH_OUT/8)-1:0] tkeep_out
);
  @(negedge tb_clk);
  tb_m_tready = 1'b1;
  while (!tb_m_tvalid) @(negedge tb_clk);
  data_out  = tb_m_tdata;
  tlast_out = tb_m_tlast;
  tkeep_out = tb_m_tkeep;
  @(negedge tb_clk);
  tb_m_tready = 1'b0;
endtask
