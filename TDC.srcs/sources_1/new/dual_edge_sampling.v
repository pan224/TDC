`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/10 15:54:48
// Design Name: 
// Module Name: dual_edge_sampling
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


module dual_edge_sampling #(
    parameter BITS = 1
)(
    input wire clk,
    input wire [BITS-1:0] d,
    output wire [BITS-1:0] q
);
(* ASYNC_REG = "TRUE" *)reg [BITS-1:0] q_d1, q_d2;

always @(posedge clk) begin
        q_d1 <= d ^ q_d2;
end

always @(negedge clk) begin
        q_d2 <= d ^ q_d1;
end

assign q = q_d1 ^ q_d2;
endmodule
