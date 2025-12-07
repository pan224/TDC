//------------------------------------------------------------------------------
// File: delay_line.v
// Description: Delay line for TDC with proper simulation model initialization
//              Fixes: Issue #3 - Proper initialization in generate blocks
//------------------------------------------------------------------------------

`include "tdc_pkg.vh"

module delay_line #(
    parameter LENGTH = `DL_LENGTH,
    parameter SIMULATION = 0       // Set to 1 for simulation behavioral model
)(
    input  wire             clk,
    input  wire             reset_n,
    input  wire             start,    // Start pulse input
    output wire [LENGTH-1:0] tap_out  // Tapped delay line outputs
);

    // Fix #3: Proper initialization in generate blocks
    // Use explicit initialization for simulation model
    
    `ifdef SIMULATION
        // Behavioral model for simulation
        // Each delay element has explicit initialization
        reg [LENGTH-1:0] delay_chain = {LENGTH{1'b0}};  // Explicit initialization
        
        // Propagation delay model
        integer i;
        always @(start or delay_chain) begin
            delay_chain[0] = start;
            for (i = 1; i < LENGTH; i = i + 1) begin
                delay_chain[i] <= `DL_ELEMENT_DELAY delay_chain[i-1];
            end
        end
        
        assign tap_out = delay_chain;
        
    `else
        // Synthesis model using actual delay elements
        // For FPGA implementation, this would use CARRY4 or LUT primitives
        
        // Storage for delay chain with proper initialization
        (* keep = "true" *)
        (* dont_touch = "true" *)
        reg [LENGTH-1:0] delay_taps = {LENGTH{1'b0}};   // Fix #3: Explicit init
        
        genvar j;
        generate
            // First element: directly connected to start
            always @(posedge clk or negedge reset_n) begin
                if (!reset_n) begin
                    delay_taps[0] <= 1'b0;  // Fix #3: Reset initialization
                end else begin
                    delay_taps[0] <= start;
                end
            end
            
            // Subsequent elements: propagation chain
            // Fix #3: Each generated element has explicit initialization
            for (j = 1; j < LENGTH; j = j + 1) begin : delay_chain_gen
                always @(posedge clk or negedge reset_n) begin
                    if (!reset_n) begin
                        delay_taps[j] <= 1'b0;  // Fix #3: Explicit reset in each iteration
                    end else begin
                        delay_taps[j] <= delay_taps[j-1];
                    end
                end
            end
        endgenerate
        
        assign tap_out = delay_taps;
    `endif

endmodule
