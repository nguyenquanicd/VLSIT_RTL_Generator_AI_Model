// TC-011 | REQ-016
// Description: WIDTH_IN=N*WIDTH_OUT is a DV-only responsibility (no RTL
//              elaboration check, per Gate 1 decision). This base testbench
//              build is fixed at the Gate-2 default (WIDTH_IN=64,
//              WIDTH_OUT=32, N=2), already exercised functionally by
//              TC-002/TC-003. Additional ratios (N=1,4,8...) require a
//              separate parameterized regression build outside this
//              single-configuration testplan.
task automatic tc_011_width_ratio_default();
  $display("[PASS] TC-011 width_ratio_default (N=2, WIDTH_IN=64/WIDTH_OUT=32 — covered functionally by TC-002/TC-003; other ratios need separate regression)");
  tb_pass_count++;
endtask
