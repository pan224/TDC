`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tdc_delay_ctrl
// Description: TDC 延迟控制模块，管理 sg_start 和 reset 的 IDELAYE2
//////////////////////////////////////////////////////////////////////////////////

module tdc_delay_ctrl #(
    parameter DATA_WIDTH = 5
)(
    input wire                      clk_sys,        // 200MHz 系统时钟
    input wire                      reset,
    
    // 原始信号输入
    input wire                      sg_start_in,
    input wire                      reset_in,
    
    // 延迟控制
    input wire [DATA_WIDTH-1:0]     sg_delay_value,
    input wire                      sg_delay_load,
    input wire [DATA_WIDTH-1:0]     rst_delay_value,
    input wire                      rst_delay_load,
    
    // 延迟后的信号输出
    output wire                     sg_start_delayed,
    output wire                     reset_delayed
);

//------------------------------------------------------------------------------
// sg_start 的 IDELAYE2 延迟
//------------------------------------------------------------------------------
(* IODELAY_GROUP = "tdc_delay_group" *)
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),
    .DELAY_SRC("DATAIN"),
    .HIGH_PERFORMANCE_MODE("TRUE"),
    .IDELAY_TYPE("VAR_LOAD"),
    .IDELAY_VALUE(0),
    .PIPE_SEL("FALSE"),
    .REFCLK_FREQUENCY(200.0),
    .SIGNAL_PATTERN("DATA")
)
IDELAYE2_sg_start (
    .CNTVALUEOUT(),
    .DATAOUT(sg_start_delayed),
    .C(clk_sys),
    .CE(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(sg_delay_value),
    .DATAIN(sg_start_in),
    .IDATAIN(1'b0),
    .INC(1'b0),
    .LD(sg_delay_load),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

//------------------------------------------------------------------------------
// reset 的 IDELAYE2 延迟
//------------------------------------------------------------------------------
(* IODELAY_GROUP = "tdc_delay_group" *)
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),
    .DELAY_SRC("DATAIN"),
    .HIGH_PERFORMANCE_MODE("TRUE"),
    .IDELAY_TYPE("VAR_LOAD"),
    .IDELAY_VALUE(0),
    .PIPE_SEL("FALSE"),
    .REFCLK_FREQUENCY(200.0),
    .SIGNAL_PATTERN("DATA")
)
IDELAYE2_reset (
    .CNTVALUEOUT(),
    .DATAOUT(reset_delayed),
    .C(clk_sys),
    .CE(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(rst_delay_value),
    .DATAIN(reset_in),
    .IDATAIN(1'b0),
    .INC(1'b0),
    .LD(rst_delay_load),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

endmodule