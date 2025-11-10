`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/06 13:40:01
// Design Name: 
// Module Name: bubble_fix
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


module bubble_fix #(
    parameter STAGE = 512
)(
    input  wire               clk_bufg,
    input  wire               reset,
    input wire               valid,
    input  wire [STAGE-1:0]   in_code,
    output wire  [STAGE-1:0]   out_code
);


    reg [STAGE-1:0] in_code_reg;

    always @(posedge valid) begin
        if (reset) begin
            in_code_reg <= {STAGE{1'b0}};
        end else begin
            in_code_reg <= in_code;
        end
    end


    wire [STAGE-1:0] bubble_free;

    // 0 号与末尾特殊处理
    assign bubble_free[0]        = in_code_reg[0]        | (in_code_reg[1]);
    assign bubble_free[STAGE-1]  = in_code_reg[STAGE-1]  | (in_code_reg[STAGE-2]);

    genvar i;
    generate
        for (i = 1; i < STAGE-1; i = i + 1) begin : GEN_BUBBLE
            // 如果当前位置为 0 但左右都是 1，则修补成 1
            assign bubble_free[i] = in_code_reg[i] |
                                    (in_code_reg[i-1] & in_code_reg[i+1]);
        end
    endgenerate

    assign out_code = bubble_free;
    // 可选：打一拍寄存器，保证后级时序
    // always @(posedge clk_bufg) begin
    //     if (reset) begin
    //         out_code <= {STAGE{1'b0}};
    //     end else begin
    //         out_code <= bubble_free;
    //     end
    // end
endmodule
