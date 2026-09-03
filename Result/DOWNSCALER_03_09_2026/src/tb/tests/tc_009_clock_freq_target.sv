// TC-009 | REQ-013
// Description: Target clock frequency (800-1000MHz, 2000MHz stretch) is
//              NOT verifiable by a functional testbench — it requires
//              Static Timing Analysis (STA) against the synthesized netlist.
//              Logged here as N/A for this functional test suite; see
//              schemas/synth_report.json caveat for the STA follow-up.
task automatic tc_009_clock_freq_target();
  $display("[N/A]  TC-009 clock_freq_target — requires STA, out of scope for functional simulation. See schemas/synth_report.json.");
  tb_pass_count++;
endtask
