//------------------------------------------------------------------------------
// File: dl_sync.v
// Description: Delay line synchronizer with dead-zone time counter
//              Fixes: Issue #1 - Proper bin270_prev initialization
//                     Issue #2 - Missing dead-zone time counter logic
//------------------------------------------------------------------------------

`include "tdc_pkg.vh"

module dl_sync #(
    parameter DL_LENGTH = `DL_LENGTH,
    parameter FINE_WIDTH = `TDC_FINE_WIDTH
)(
    input  wire                    clk,
    input  wire                    reset_n,
    input  wire [DL_LENGTH-1:0]    delay_line_in,   // Delay line thermometer code
    input  wire                    strobe,          // Sampling strobe
    output reg  [FINE_WIDTH-1:0]   bin_out,         // Binary output
    output reg                     valid_out,       // Output valid signal
    output wire                    busy             // Busy during dead-zone time
);

    // Fix #1: Proper initialization of bin270_prev register
    // Initialize to known value to avoid X propagation in simulation
    reg [FINE_WIDTH-1:0] bin270_prev = BIN270_INIT;  // Fix #1: Explicit initialization
    
    // Fix #2: Missing dead-zone time counter logic
    // The VHDL variable v_deadtime was not properly converted
    // Add deadtime_cnt register and proper management
    reg [`DEADTIME_WIDTH-1:0] deadtime_cnt = DEADTIME_INIT;  // Fix #2: deadtime counter
    reg deadtime_active = 1'b0;                                // Fix #2: deadtime flag
    
    // State machine for synchronization
    reg [1:0] state = `IDLE_STATE;
    reg [1:0] next_state;
    
    // Thermometer to binary conversion intermediate
    reg [FINE_WIDTH-1:0] bin_current;
    integer i;
    
    // Fix #2: busy signal indicates dead-zone time
    assign busy = deadtime_active;
    
    // Thermometer to binary encoder
    // Counts the number of 1's in the thermometer code
    always @(*) begin
        bin_current = {FINE_WIDTH{1'b0}};
        for (i = 0; i < DL_LENGTH; i = i + 1) begin
            if (i < (1 << FINE_WIDTH)) begin
                bin_current = bin_current + {{(FINE_WIDTH-1){1'b0}}, delay_line_in[i]};
            end
        end
    end
    
    // State machine sequential logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= `IDLE_STATE;
            bin_out <= {FINE_WIDTH{1'b0}};
            valid_out <= 1'b0;
            bin270_prev <= BIN270_INIT;       // Fix #1: Proper reset value
            deadtime_cnt <= DEADTIME_INIT;     // Fix #2: Reset deadtime counter
            deadtime_active <= 1'b0;           // Fix #2: Clear deadtime flag
        end else begin
            state <= next_state;
            
            // Fix #2: Dead-zone time counter management
            // After a valid measurement, enter dead-zone for DEADTIME_CYCLES
            if (deadtime_active) begin
                if (deadtime_cnt == `DEADTIME_CYCLES) begin
                    deadtime_active <= 1'b0;
                    deadtime_cnt <= DEADTIME_INIT;
                end else begin
                    deadtime_cnt <= deadtime_cnt + 1'b1;
                end
            end
            
            case (state)
                `IDLE_STATE: begin
                    valid_out <= 1'b0;
                    if (strobe && !deadtime_active) begin  // Fix #2: Check deadtime
                        bin270_prev <= bin_current;         // Fix #1: Store previous value
                    end
                end
                
                `WAIT_STATE: begin
                    valid_out <= 1'b0;
                end
                
                `READY_STATE: begin
                    // Calculate difference and output
                    bin_out <= bin_current - bin270_prev;
                    valid_out <= 1'b1;
                    // Fix #2: Start dead-zone time counter after valid output
                    deadtime_active <= 1'b1;
                    deadtime_cnt <= DEADTIME_INIT;
                end
                
                `DEADTIME_STATE: begin
                    // Fix #2: Wait in this state during dead-zone time
                    valid_out <= 1'b0;
                end
                
                default: begin
                    valid_out <= 1'b0;
                end
            endcase
        end
    end
    
    // State machine combinational logic
    always @(*) begin
        next_state = state;
        
        case (state)
            `IDLE_STATE: begin
                if (strobe && !deadtime_active) begin  // Fix #2: Don't accept during deadtime
                    next_state = `WAIT_STATE;
                end
            end
            
            `WAIT_STATE: begin
                // Wait one cycle for delay line to settle
                next_state = `READY_STATE;
            end
            
            `READY_STATE: begin
                // Fix #2: Transition to dead-zone state
                next_state = `DEADTIME_STATE;
            end
            
            `DEADTIME_STATE: begin
                // Fix #2: Stay in deadtime until counter expires
                if (!deadtime_active) begin
                    next_state = `IDLE_STATE;
                end
            end
            
            default: begin
                next_state = `IDLE_STATE;
            end
        endcase
    end

endmodule
