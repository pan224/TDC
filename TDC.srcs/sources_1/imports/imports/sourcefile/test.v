`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CCNU
// Engineer: WD
// 
// Create Date: 23/06/2021
// Design Name: 
// Module Name: test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:// 
//////////////////////////////////////////////////////////////////////////////////


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
//
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




////GBE config to fifo mode
//    -- loopback
assign gig_eth_tx_tdata = gig_eth_rx_tdata;
assign gig_eth_tx_tvalid = gig_eth_rx_tvalid;
assign gig_eth_rx_tready = gig_eth_tx_tready;

//    -- receive to cmd_fifo
assign    gig_eth_tcp_use_fifo = 1'b1;

//    -- set ip
assign  set_ipv4_addr = {8'd192,8'd168,8'd2,8'd100};

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
//------------------------------------------------------------------------------
assign gig_eth_tx_fifo_q = gig_eth_rx_fifo_q;

assign gig_eth_rx_fifo_rden = (~gig_eth_rx_fifo_empty)&(~gig_eth_tx_fifo_full);
assign gig_eth_tx_fifo_wren = (~gig_eth_rx_fifo_empty)&(~gig_eth_tx_fifo_full);

//------------------------------------------------------------------------------
//ila for test
//------------------------------------------------------------------------------ 
assign gig_eth_tx_fifo_wrclk = clk_100MHz;
//assign gig_eth_tx_fifo_q = 32'd0;
// assign gig_eth_tx_fifo_wren = 1'b1;


assign gig_eth_rx_fifo_rdclk = clk_100MHz;
// assign gig_eth_rx_fifo_rden = 1'b1;
  
ila_0 ila_wd0 (
   .clk(clk_100MHz),
   .probe0({gig_eth_rx_fifo_q,
            gig_eth_tx_fifo_full,
            gig_eth_rx_fifo_empty,
            gig_eth_rx_fifo_rden,
            gig_eth_tx_fifo_wren})
   ); 

//------------------------------------------------------------------------------


endmodule
