//------------------------------------------------------------------------------
// File: tdc.v
// Description: Top-level TDC module with explicit sign handling
//              Fixes: Issue #4 - Explicit sign handling in arithmetic operations
//------------------------------------------------------------------------------

`include "tdc_pkg.vh"

module tdc #(
    parameter CHANNEL_WIDTH = `TDC_CHANNEL_WIDTH,
    parameter COARSE_WIDTH = `TDC_COARSE_WIDTH,
    parameter FINE_WIDTH = `TDC_FINE_WIDTH,
    parameter TOTAL_WIDTH = `TDC_TOTAL_WIDTH
)(
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire                       start_pulse,     // Start signal
    input  wire                       stop_pulse,      // Stop signal
    input  wire [CHANNEL_WIDTH-1:0]   channel_sel,     // Channel selection
    output reg  [TOTAL_WIDTH-1:0]     time_diff,       // Total time difference
    output reg                        time_valid,      // Time measurement valid
    output wire                       busy              // TDC busy
);

    // Internal signals
    wire [`DL_WIDTH-1:0] delay_line_start;
    wire [`DL_WIDTH-1:0] delay_line_stop;
    wire [FINE_WIDTH-1:0] fine_time_start;
    wire [FINE_WIDTH-1:0] fine_time_stop;
    wire start_valid, stop_valid;
    wire dl_sync_busy;
    
    // Coarse counter with proper initialization
    reg [COARSE_WIDTH-1:0] coarse_start = COARSE_INIT;  // Fix #4: Explicit init
    reg [COARSE_WIDTH-1:0] coarse_stop = COARSE_INIT;   // Fix #4: Explicit init
    reg [COARSE_WIDTH-1:0] coarse_counter = COARSE_INIT;
    
    // Registered fine time values
    reg [FINE_WIDTH-1:0] fine_start_reg;
    reg [FINE_WIDTH-1:0] fine_stop_reg;
    
    // State machine
    reg [1:0] state;
    localparam IDLE = 2'b00;
    localparam WAIT_START = 2'b01;
    localparam WAIT_STOP = 2'b10;
    localparam CALCULATE = 2'b11;
    
    assign busy = (state != IDLE) || dl_sync_busy;
    
    // Coarse counter - counts clock cycles
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            coarse_counter <= COARSE_INIT;  // Fix #4: Proper reset
        end else begin
            coarse_counter <= coarse_counter + 1'b1;
        end
    end
    
    // Delay line for start pulse
    delay_line #(
        .LENGTH(`DL_LENGTH),
        .SIMULATION(0)
    ) dl_start (
        .clk(clk),
        .reset_n(reset_n),
        .start(start_pulse),
        .tap_out(delay_line_start)
    );
    
    // Delay line for stop pulse
    delay_line #(
        .LENGTH(`DL_LENGTH),
        .SIMULATION(0)
    ) dl_stop (
        .clk(clk),
        .reset_n(reset_n),
        .start(stop_pulse),
        .tap_out(delay_line_stop)
    );
    
    // Synchronizer for start
    dl_sync #(
        .DL_LENGTH(`DL_LENGTH),
        .FINE_WIDTH(FINE_WIDTH)
    ) sync_start (
        .clk(clk),
        .reset_n(reset_n),
        .delay_line_in(delay_line_start),
        .strobe(start_pulse),
        .bin_out(fine_time_start),
        .valid_out(start_valid),
        .busy(dl_sync_busy)
    );
    
    // Synchronizer for stop
    dl_sync #(
        .DL_LENGTH(`DL_LENGTH),
        .FINE_WIDTH(FINE_WIDTH)
    ) sync_stop (
        .clk(clk),
        .reset_n(reset_n),
        .delay_line_in(delay_line_stop),
        .strobe(stop_pulse),
        .bin_out(fine_time_stop),
        .valid_out(stop_valid),
        .busy()  // Not used for stop
    );
    
    // Main state machine and calculation
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            time_diff <= {TOTAL_WIDTH{1'b0}};
            time_valid <= 1'b0;
            coarse_start <= COARSE_INIT;
            coarse_stop <= COARSE_INIT;
            fine_start_reg <= {FINE_WIDTH{1'b0}};
            fine_stop_reg <= {FINE_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    time_valid <= 1'b0;
                    if (start_valid) begin
                        // Capture start time
                        coarse_start <= coarse_counter;
                        fine_start_reg <= fine_time_start;
                        state <= WAIT_STOP;
                    end
                end
                
                WAIT_STOP: begin
                    if (stop_valid) begin
                        // Capture stop time
                        coarse_stop <= coarse_counter;
                        fine_stop_reg <= fine_time_stop;
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    // Fix #4: Explicit sign handling for arithmetic operations
                    // Use $signed() to ensure correct signed arithmetic
                    
                    // Calculate coarse time difference
                    // Fix #4: Cast to signed for proper subtraction
                    reg signed [COARSE_WIDTH:0] coarse_diff;  // Extra bit for sign
                    coarse_diff = $signed({1'b0, coarse_stop}) - $signed({1'b0, coarse_start});
                    
                    // Calculate fine time difference
                    // Fix #4: Cast to signed for proper subtraction
                    reg signed [FINE_WIDTH:0] fine_diff;  // Extra bit for sign
                    fine_diff = $signed({1'b0, fine_stop_reg}) - $signed({1'b0, fine_start_reg});
                    
                    // Fix #4: Handle borrow from coarse to fine time
                    // If fine time is negative, borrow one coarse count
                    if (fine_diff < 0) begin
                        // Fix #4: Use $signed for arithmetic
                        coarse_diff = coarse_diff - 1;
                        // Adjust fine time (add one coarse period worth of fine counts)
                        fine_diff = fine_diff + $signed({1'b0, `DL_LENGTH});
                    end
                    
                    // Fix #4: Combine coarse and fine with explicit sign handling
                    // Ensure proper concatenation and sign extension
                    time_diff <= {
                        $unsigned(coarse_diff[COARSE_WIDTH-1:0]),
                        $unsigned(fine_diff[FINE_WIDTH-1:0])
                    };
                    
                    time_valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Fix #4: Additional explicit sign handling for debug/monitoring
    // synthesis translate_off
    reg signed [TOTAL_WIDTH:0] time_diff_signed;
    always @(*) begin
        // Convert unsigned time_diff to signed for simulation viewing
        time_diff_signed = $signed({1'b0, time_diff});
    end
    
    initial begin
        $display("TDC Module Initialized:");
        $display("  Coarse width: %d bits", COARSE_WIDTH);
        $display("  Fine width: %d bits", FINE_WIDTH);
        $display("  Total width: %d bits", TOTAL_WIDTH);
        $display("  Fix #4: Using explicit $signed() for all arithmetic");
    end
    // synthesis translate_on

endmodule
