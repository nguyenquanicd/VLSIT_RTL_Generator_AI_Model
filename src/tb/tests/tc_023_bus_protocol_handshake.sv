// TC-023 | REQ-F10
// Bus valid-ready handshake: when i_imem_req_ready=0, request payload must be stable
// Uses force/release to stall the ready signal
task automatic tc_023_bus_protocol_handshake();
  logic [31:0] captured_addr;
  u_mem.clear_mem();
  write_instr(0, 32'h0000_0013); // NOP
  write_instr(1, 32'h0000_0013);
  write_instr(2, 32'h0000_006F);
  do_reset(5);

  // Wait until core issues first instruction fetch
  begin : wait_fetch_blk
    int unsigned cy;
    cy = 0;
    while (!o_imem_req_valid && cy < 20) begin
      @(posedge i_clk_core);
      cy++;
    end
  end
  captured_addr = o_imem_req_addr;

  // Hold ready low for 3 cycles — addr must remain stable
  force i_imem_req_ready = 1'b0;
  repeat(3) begin
    @(posedge i_clk_core);
    if (o_imem_req_valid && o_imem_req_addr !== captured_addr) begin
      $error("[FAIL] TC-023: I-bus addr changed while ready=0: was=0x%08h now=0x%08h",
             captured_addr, o_imem_req_addr);
      error_count++;
    end
  end
  release i_imem_req_ready;

  wait_clk(10);
  $display("[PASS] TC-023 bus_protocol_handshake");
  wait_clk(5);
endtask
