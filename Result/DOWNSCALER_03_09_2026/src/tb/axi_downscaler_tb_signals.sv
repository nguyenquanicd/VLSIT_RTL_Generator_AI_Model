// TC-ALL | REQ-ALL
// Description: Compilation-unit-scope testbench signals shared by tb_top,
//              the BFM tasks, and every TC task. DUT output ports (m_*,
//              err_*, s_tready) are only ever READ here, never assigned,
//              so there is no conflict with their structural (port) driver.
localparam int unsigned LP_WIDTH_IN      = 64;
localparam int unsigned LP_WIDTH_OUT     = 32;
localparam int unsigned LP_FIFO_DEPTH    = 16;
localparam real         LP_CLK_PERIOD_NS = 10.0;

logic                        tb_clk;
logic                        tb_resetn;

logic [LP_WIDTH_IN-1:0]      tb_s_tdata;
logic                        tb_s_tvalid;
logic                        tb_s_tready;
logic                        tb_s_tlast;
logic [(LP_WIDTH_IN/8)-1:0]  tb_s_tkeep;

logic [LP_WIDTH_OUT-1:0]     tb_m_tdata;
logic                        tb_m_tvalid;
logic                        tb_m_tready;
logic                        tb_m_tlast;
logic [(LP_WIDTH_OUT/8)-1:0] tb_m_tkeep;

logic                        tb_err_fifo;
logic                        tb_err_protocol;

int unsigned                 tb_pass_count;
int unsigned                 tb_fail_count;
