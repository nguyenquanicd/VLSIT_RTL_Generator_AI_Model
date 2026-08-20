`default_nettype none
// TC-020 | REQ-F14
// Simple CLINT model: generates timer and SW interrupts on demand
// Uses plain always (not always_ff) so tasks can also drive countdown vars
module rv32im_clint_model (
  input  logic i_clk,
  input  logic i_resetn,
  output logic o_irq_timer,
  output logic o_irq_sw,
  output logic o_irq_ext
);
  assign o_irq_ext = 1'b0;

  int unsigned timer_countdown;
  int unsigned sw_countdown;

  // Countdown logic — plain always (not always_ff) so tasks can share writes
  always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
      o_irq_timer     <= 1'b0;
      o_irq_sw        <= 1'b0;
    end else begin
      if (timer_countdown > 0) begin
        timer_countdown <= timer_countdown - 1;
        o_irq_timer <= (timer_countdown == 1) ? 1'b1 : 1'b0;
      end else begin
        o_irq_timer <= 1'b0;
      end
      if (sw_countdown > 0) begin
        sw_countdown <= sw_countdown - 1;
        o_irq_sw <= (sw_countdown == 1) ? 1'b1 : 1'b0;
      end else begin
        o_irq_sw <= 1'b0;
      end
    end
  end

  initial begin
    timer_countdown = 0;
    sw_countdown    = 0;
    o_irq_timer     = 1'b0;
    o_irq_sw        = 1'b0;
  end

  // Tasks called from tb_top to inject IRQs
  task automatic set_timer_irq(input int unsigned delay_cycles);
    timer_countdown = delay_cycles;
  endtask

  task automatic set_sw_irq(input int unsigned delay_cycles);
    sw_countdown = delay_cycles;
  endtask

  task automatic clear_irqs();
    timer_countdown = 0;
    sw_countdown    = 0;
  endtask

endmodule
`default_nettype wire
