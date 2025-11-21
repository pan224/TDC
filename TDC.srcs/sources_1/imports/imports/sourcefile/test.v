`timescale 1ns / 1ps
module test(
    input wire CPU_RESET,
    input wire SYS_CLK_P, //200Mhz
    input wire SYS_CLK_N,

//Port for GBE   
    input wire SGMIICLK_Q0_P,
    input wire SGMIICLK_Q0_N,
    output wire PHY_RESET_N,
    output wire [3:0] RGMII_TXD,
    output wire RGMII_TX_CTL,
    output wire RGMII_TXC,
    input wire [3:0] RGMII_RXD,
    input wire RGMII_RX_CTL,
    input wire RGMII_RXC,
    inout wire MDIO,
    output wire MDC
);

wire reset,sys_clk,clk_50MHz,clk_100MHz,clk_10MHz,clk_250MHz;
reg [20:0] con_clk_1Mhz;
wire clk_sgmii_i, clk_125MHz;
//wire for GBE 
wire [7:0] gig_eth_tx_tdata,gig_eth_rx_tdata;
wire gig_eth_tx_tvalid,gig_eth_rx_tvalid;
wire gig_eth_tx_tready,gig_eth_rx_tready;
wire gig_eth_tcp_use_fifo;
wire gig_eth_tx_fifo_wrclk;
wire [31:0] gig_eth_tx_fifo_q;
wire gig_eth_tx_fifo_wren;
wire gig_eth_tx_fifo_full;
wire gig_eth_rx_fifo_rdclk;
wire [31:0] gig_eth_rx_fifo_q;
wire gig_eth_rx_fifo_rden;
wire gig_eth_rx_fifo_empty;
wire [31:0] set_ipv4_addr;

//--------------------------------------------------------------------
//Clock and reset generate	
//--------------------------------------------------------------------

global_clock_reset global_clock_reset_inst
(
    .SYS_CLK_P(SYS_CLK_P),
    .SYS_CLK_N(SYS_CLK_N),
    .FORCE_RST(~CPU_RESET),
    //output
    .GLOBAL_RST(reset),
    .SYS_CLK(sys_clk),
    .CLK_OUT1(clk_50MHz),
    .CLK_OUT2(clk_100MHz),
    .CLK_OUT3(clk_10MHz),
    .CLK_OUT4(clk_250MHz)
);     

//clock generate for GBE 

IBUFDS_GTE2 #(
	.CLKCM_CFG("TRUE"),   // Refer to Transceiver User Guide
   .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
   .CLKSWING_CFG(2'b11)  // Refer to Transceiver User Guide
)
IBUFDS_GTE2_inst (
   .O(clk_sgmii_i),         // 1-bit output: Refer to Transceiver User Guide
   .ODIV2(), // 1-bit output: Refer to Transceiver User Guide
   .CEB(1'b0),     // 1-bit input: Refer to Transceiver User Guide
   .I(SGMIICLK_Q0_P),         // 1-bit input: Refer to Transceiver User Guide
   .IB(SGMIICLK_Q0_N)        // 1-bit input: Refer to Transceiver User Guide
);
    
BUFG BUFG_inst (
   .O(clk_125MHz), // 1-bit output: Clock output
   .I(clk_sgmii_i)  // 1-bit input: Clock input
);


//---------------------------------------------------------------
//GBE Module
//input from control fifo ; 125MHZ clock 
//output to cmd_fifo ; 100Mhz clock
//---------------------------------------------------------------

// 为 GBE 的 IODELAY 添加 IDELAYCTRL
(* IODELAY_GROUP = "tri_mode_ethernet_mac_iodelay_grp" *)
IDELAYCTRL IDELAYCTRL_gbe_inst (
    .RDY(),              // 1-bit output: Ready output
    .REFCLK(sys_clk),    // 1-bit input: 200MHz reference clock
    .RST(reset)          // 1-bit input: Active high reset
);

////GBE config to fifo mode
// 删除以下回环代码：
// assign gig_eth_tx_tdata = gig_eth_rx_tdata;
// assign gig_eth_tx_tvalid = gig_eth_rx_tvalid;
// assign gig_eth_rx_tready = gig_eth_tx_tready;

//    -- receive to cmd_fifo
assign gig_eth_tcp_use_fifo = 1'b1;  // 保留 FIFO 模式使能

//    -- set ip
assign set_ipv4_addr = {8'd192,8'd168,8'd2,8'd100};

gig_eth gig_eth_inst
(
//         -- asynchronous reset
   .GLBL_RST(reset),
//         -- clocks
   .GTX_CLK(clk_125MHz),
   .REF_CLK(sys_clk), // 200MHz for IODELAY
//         -- PHY interface
   .PHY_RESETN(PHY_RESET_N),
//         -- RGMII Interface
   .RGMII_TXD(RGMII_TXD),
   .RGMII_TX_CTL(RGMII_TX_CTL),
   .RGMII_TXC(RGMII_TXC),
   .RGMII_RXD(RGMII_RXD),
   .RGMII_RX_CTL(RGMII_RX_CTL),
   .RGMII_RXC(RGMII_RXC),
//         -- MDIO Interface
   .MDIO(MDIO),
   .MDC(MDC),
//         -- TCP
   .TCP_CONNECTION_RESET(1'b0),
   .TX_TDATA(gig_eth_tx_tdata),
   .TX_TVALID(gig_eth_tx_tvalid),
   .TX_TREADY(gig_eth_tx_tready),
   .RX_TDATA(gig_eth_rx_tdata),
   .RX_TVALID(gig_eth_rx_tvalid),
   .RX_TREADY(gig_eth_rx_tready),
//         -- FIFO
   .TCP_USE_FIFO(gig_eth_tcp_use_fifo),
   .TX_FIFO_WRCLK(gig_eth_tx_fifo_wrclk),
   .TX_FIFO_Q(gig_eth_tx_fifo_q),
   .TX_FIFO_WREN(gig_eth_tx_fifo_wren),
   .TX_FIFO_FULL(gig_eth_tx_fifo_full),
   
   .RX_FIFO_RDCLK(gig_eth_rx_fifo_rdclk),
   .RX_FIFO_Q(gig_eth_rx_fifo_q),
   .RX_FIFO_RDEN(gig_eth_rx_fifo_rden),
   .RX_FIFO_EMPTY(gig_eth_rx_fifo_empty),
   
   .SET_IPv4_ADDR(set_ipv4_addr)
);   

assign gig_eth_tx_fifo_wrclk = clk_100MHz;
assign gig_eth_rx_fifo_rdclk = clk_100MHz;

//------------------------------------------------------------------------------
//ila for test
//------------------------------------------------------------------------------ 
  
ila_0 ila_wd0 (
   .clk(clk_100MHz),
   .probe0({gig_eth_rx_fifo_q,
            gig_eth_tx_fifo_q,
            gig_eth_tx_fifo_full,
            gig_eth_rx_fifo_empty,
            gig_eth_rx_fifo_rden,
            gig_eth_tx_fifo_wren})
   ); 


// ila_tdc ila_latch2bin (
// 	.clk(clk_100MHz), // input wire clk
// 	.probe0({cs_gap, value_gap}) // input wire [9:0] probe0
// );
//------------------------------------------------------------------------------
// VIO 和测试控制模块
//------------------------------------------------------------------------------
wire [7:0] vio_data;
wire vio_valid;
wire vio_reset;
wire tdc_start;
wire tdc_reset;

// VIO IP 核例化
vio_0 vio_inst (
    .clk(clk_100MHz),
    .probe_out0(vio_data),      // 8-bit 延迟控制值 (0-140)
    .probe_out1(vio_valid),      // 1-bit 触发信号
    .probe_out2(vio_reset)      // 1-bit 复位信号
    
);

// 测试控制模块
tdc_test_ctrl_phase #(
    .DATA_WIDTH(8)  // 0-140 相位步数
) tdc_test_ctrl_inst (
    .clk_sys(sys_clk),          // 200MHz
    .vio_reset_in(vio_reset),
    // VIO 控制
    .vio_phase(vio_data),      // 相位步数
    .vio_valid(vio_valid),
    // TDC 控制信号
    .tdc_start(tdc_start),
    .tdc_reset(tdc_reset)
);

//------------------------------------------------------------------------------
// IDELAYCTRL for TDC - 统一管理所有 IDELAYE2
//------------------------------------------------------------------------------
(* IODELAY_GROUP = "tdc_delay_group" *)
IDELAYCTRL IDELAYCTRL_tdc_inst (
    .RDY(),              // 1-bit output: Ready output
    .REFCLK(sys_clk),    // 1-bit input: 200MHz reference clock
    .RST(reset)          // 1-bit input: Active high reset
);
//------------------------------------------------------------------------------
// IDELAYE2 延迟控制模块
//------------------------------------------------------------------------------
// IDELAYE2 控制信号
reg [4:0] sg_delay_value_reg;
reg sg_delay_load_reg;
reg [4:0] rst_delay_value_reg;
reg rst_delay_load_reg;
// 延迟后的信号
wire sg_start_delayed;
wire reset_delayed;
wire [4:0] sg_delay_value, rst_delay_value;
wire sg_delay_load, rst_delay_load;
wire tdc_start_raw, tdc_reset_raw;
assign tdc_start_raw = tdc_start;
assign tdc_reset_raw = tdc_reset;
tdc_delay_ctrl #(
    .DATA_WIDTH(5)
) tdc_delay_ctrl_inst (
    .clk_sys(sys_clk),// 200MHz
    .reset(reset),
    .sg_start_in(tdc_start_raw),
    .reset_in(tdc_reset_raw),
    .sg_delay_value(sg_delay_value),
    .sg_delay_load(sg_delay_load),
    .rst_delay_value(rst_delay_value),
    .rst_delay_load(rst_delay_load),
    .sg_start_delayed(sg_start_delayed),
    .reset_delayed(reset_delayed)
);

//------------------------------------------------------------------------------
// 时钟生成 - clk_bufg 用于 TDC（需要在使用前声明）
//------------------------------------------------------------------------------
(* clock_buffer_type = "bufg" *) wire clk_bufg;
clk_wiz_0 clk_wiz_0_inst(
    .clk_out1(clk_bufg),//400MHZ
    .clk_in1(sys_clk)// 200MHz
);
//------------------------------------------------------------------------------
// TDC 模块实例化 - 使用延迟后的信号
//------------------------------------------------------------------------------
parameter STAGE = 512;
parameter GAP_BITS = 9;
wire cs_gap;
wire [GAP_BITS-1:0] value_gap;
wire [22:0] coarse_counter;
tdc_top #(
    .STAGE(STAGE),
    .GAP_BITS(GAP_BITS)
) tdc_top_inst (
    .sg_start_delayed(sg_start_delayed),  // 延迟后的 start 信号
    .clk_bufg(clk_bufg),                  // 高频时钟400MHZ
    .reset_delayed(reset_delayed),        // 延迟后的 reset 信号
    .cs_gap(cs_gap),
    .value_gap(value_gap),
    .coarse_counter(coarse_counter)
);
//------------------------------------------------------------------------------
// 以太网通信控制模块
//------------------------------------------------------------------------------
eth_comm_ctrl #(
    .GAP_BITS(GAP_BITS)
) eth_comm_ctrl_inst (
    //
    .clk_100MHz(clk_100MHz),
    .reset(reset),
    // TDC 数据输入(发送)
    .cs_gap(cs_gap),
    .value_gap(value_gap),
    .coarse_counter(coarse_counter),
    // 以太网 FIFO 接口
    .gig_eth_rx_fifo_empty(gig_eth_rx_fifo_empty),
    .gig_eth_rx_fifo_q(gig_eth_rx_fifo_q),
    .gig_eth_rx_fifo_rden(gig_eth_rx_fifo_rden),
    .gig_eth_tx_fifo_full(gig_eth_tx_fifo_full),
    .gig_eth_tx_fifo_q(gig_eth_tx_fifo_q),
    .gig_eth_tx_fifo_wren(gig_eth_tx_fifo_wren),
    // IDELAYE2 控制信号输出(接收)
    .sg_delay_value(sg_delay_value),
    .sg_delay_load(sg_delay_load),
    .rst_delay_value(rst_delay_value),
    .rst_delay_load(rst_delay_load)
);

endmodule
