`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/05 16:09:50
// Design Name: 
// Module Name: decode
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module decode#(
    parameter GAP_BITS = 9
)(
	input wire 							clk_bufg,
	input wire 							reset,
	input wire 							valid,
    input wire 							valid_dly,
	input wire  [(2**GAP_BITS)-1:0]     value_latch,
    input wire  [(2**GAP_BITS)-1:0]     value_latch_dly,
	output reg                          bin_cs,
	output wire [GAP_BITS-1:0]			bin		
);

wire bin_cs1;
wire [GAP_BITS-1:0] bin1;
wire bin_cs2;
wire [GAP_BITS-1:0] bin2;

latch2bin#(
    .GAP_BITS 					 (GAP_BITS)

)latch2bin_inst1(
    .clk_bufg                           (clk_bufg),
    .reset                              (reset),
    .valid                              (valid),
    .value_latch                        (value_latch),
    .bin_cs                             (bin_cs1),
    .bin                                (bin1)
);    

latch2bin#(
    .GAP_BITS 					 (GAP_BITS)

)latch2bin_inst2(
    .clk_bufg                           (clk_bufg),
    .reset                              (reset),
    .valid                              (valid_dly),
    .value_latch                        (value_latch_dly),
    .bin_cs                             (bin_cs2),
    .bin                                (bin2)
);  
reg bin_cs_final;
reg [GAP_BITS-1:0] bin1_reg;
reg [GAP_BITS-1:0] bin2_reg;
reg [GAP_BITS-1:0] bin_final;


always@(posedge bin_cs1 or posedge reset) begin
    if(reset) begin
        bin1_reg <= 'd0;
    end
    else begin
        bin1_reg <= bin1;
    end
end

always@(posedge bin_cs2 or posedge reset) begin
    if(reset) begin
        bin2_reg <= 'd0;
    end
    else begin
        bin2_reg <= bin2;
    end
end

wire bin_cs_comb;
assign bin_cs_comb = bin_cs2 & bin_cs1;
always@(posedge clk_bufg) begin
    if(bin_cs_comb == 1'b1) begin
        if(bin1_reg <= 'd267 && bin2_reg >= 'd367) begin//bin1小于等于267，且bin2大于等于367,则认为是跨码片
            bin_final <= bin2_reg;
            bin_cs_final <= 1'b1;
        end
        else begin
            bin_final <= bin1_reg;
            bin_cs_final <= 1'b1;
        end
    end
    else begin
        bin_final <= bin_final;
        bin_cs_final <= 1'b0;
    end
end

assign bin = bin_final;
reg bin_cs_final_reg;
// assign bin_cs = bin_cs_final;
always @(posedge clk_bufg) begin
    bin_cs_final_reg <= bin_cs_final;
    bin_cs <= bin_cs_final_reg;
end

endmodule
