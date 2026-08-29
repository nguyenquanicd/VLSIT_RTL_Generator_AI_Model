// Testbench filelist for rv32im_core
// Usage: vcs -f src/rtl/filelist.f -f src/tb/filelist_tb.f -top rv32im_tb_top ...
// TC files are `include'd inside rv32im_tb_top.sv — not listed here

// RTL source (package + 18 modules)
-f /home/ltthinh/VSLI_AI/Result/RISCV_24_08_2026/src/rtl/filelist.f

// TB models and top
/home/ltthinh/VSLI_AI/Result/RISCV_24_08_2026/src/tb/rv32im_mem_model.sv
/home/ltthinh/VSLI_AI/Result/RISCV_24_08_2026/src/tb/rv32im_clint_model.sv
/home/ltthinh/VSLI_AI/Result/RISCV_24_08_2026/src/tb/rv32im_tb_top.sv
