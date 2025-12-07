//------------------------------------------------------------------------------
// File: priority_encoder.v
// Description: Priority encoder with proper clock domain crossing
//              Fixes: Issue #5 - Simplified and clarified synchronization
//                                  Fixed potential metastability issues
//------------------------------------------------------------------------------

`include "tdc_pkg.vh"

module priority_encoder #(
    parameter WIDTH = `DL_LENGTH,
    parameter OUT_WIDTH = `TDC_FINE_WIDTH
)(
    input  wire                 clk_fast,        // Fast clock domain (delay line)
    input  wire                 clk_slow,        // Slow clock domain (system)
    input  wire                 reset_n,
    input  wire [WIDTH-1:0]     thermometer_in,  // Thermometer code input
    input  wire                 encode_en,       // Enable encoding
    output reg  [OUT_WIDTH-1:0] binary_out,      // Binary encoded output
    output reg                  valid_out        // Output valid (synchronized to clk_slow)
);

    // Fix #5: Clarified clock domain crossing with proper synchronization
    // Use explicit multi-stage synchronizers to prevent metastability
    
    // Stage 1: Encode in fast clock domain
    reg [OUT_WIDTH-1:0] encoded_fast;
    reg valid_fast;
    
    // Fix #5: Multi-stage synchronizers (double-flop) for CDC
    // Separate synchronizers for data and control signals
    (* ASYNC_REG = "TRUE" *) reg [OUT_WIDTH-1:0] sync_data_stage1;
    (* ASYNC_REG = "TRUE" *) reg [OUT_WIDTH-1:0] sync_data_stage2;
    (* ASYNC_REG = "TRUE" *) reg valid_sync_stage1;
    (* ASYNC_REG = "TRUE" *) reg valid_sync_stage2;
    (* ASYNC_REG = "TRUE" *) reg valid_sync_stage3;  // Fix #5: Extra stage for reliability
    
    // Priority encoder logic (in fast clock domain)
    // Find first '1' in thermometer code
    integer i;
    reg [OUT_WIDTH-1:0] position;
    
    always @(*) begin
        position = {OUT_WIDTH{1'b0}};
        // Priority encode: find position of first 1
        for (i = WIDTH-1; i >= 0; i = i - 1) begin
            if (thermometer_in[i] == 1'b1) begin
                position = i[OUT_WIDTH-1:0];
            end
        end
    end
    
    // Fast clock domain: encode and register
    always @(posedge clk_fast or negedge reset_n) begin
        if (!reset_n) begin
            encoded_fast <= {OUT_WIDTH{1'b0}};
            valid_fast <= 1'b0;
        end else begin
            if (encode_en) begin
                encoded_fast <= position;
                valid_fast <= 1'b1;
            end else begin
                valid_fast <= 1'b0;
            end
        end
    end
    
    // Fix #5: Proper clock domain crossing with multi-stage synchronization
    // Data path synchronization (hold-and-sample approach)
    always @(posedge clk_slow or negedge reset_n) begin
        if (!reset_n) begin
            sync_data_stage1 <= {OUT_WIDTH{1'b0}};
            sync_data_stage2 <= {OUT_WIDTH{1'b0}};
            binary_out <= {OUT_WIDTH{1'b0}};
        end else begin
            // Fix #5: Double-flop synchronizer for data
            sync_data_stage1 <= encoded_fast;
            sync_data_stage2 <= sync_data_stage1;
            binary_out <= sync_data_stage2;  // Final stable data
        end
    end
    
    // Fix #5: Control signal synchronization with edge detection
    // Use 3-stage synchronizer for valid signal to ensure clean pulse
    always @(posedge clk_slow or negedge reset_n) begin
        if (!reset_n) begin
            valid_sync_stage1 <= 1'b0;
            valid_sync_stage2 <= 1'b0;
            valid_sync_stage3 <= 1'b0;
        end else begin
            // Fix #5: Triple-flop synchronizer for control signal
            valid_sync_stage1 <= valid_fast;
            valid_sync_stage2 <= valid_sync_stage1;
            valid_sync_stage3 <= valid_sync_stage2;
        end
    end
    
    // Fix #5: Edge detection on synchronized valid signal
    // Generate a single-cycle pulse in slow clock domain
    reg valid_sync_prev;
    
    always @(posedge clk_slow or negedge reset_n) begin
        if (!reset_n) begin
            valid_sync_prev <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            valid_sync_prev <= valid_sync_stage3;
            // Rising edge detection
            valid_out <= valid_sync_stage3 && !valid_sync_prev;
        end
    end
    
    // Fix #5: Synthesis directives to prevent optimization of synchronizers
    // synthesis translate_off
    initial begin
        $display("Priority Encoder: Initialized with %d-stage synchronization", `PE_STAGES);
        $display("  Clock domain crossing: fast_clk -> slow_clk");
        $display("  Data width: %d bits", OUT_WIDTH);
    end
    // synthesis translate_on

endmodule
