//------------------------------------------------------------------------------
// File: tdc_pkg.vh
// Description: TDC Package with proper signal initialization
//              Fixes: Proper default values and initialization for all parameters
//------------------------------------------------------------------------------

`ifndef TDC_PKG_VH
`define TDC_PKG_VH

// TDC Configuration Parameters
`define TDC_CHANNEL_WIDTH 9        // Width of TDC channel number
`define TDC_COARSE_WIDTH 16        // Width of coarse counter
`define TDC_FINE_WIDTH 9           // Width of fine time measurement
`define TDC_TOTAL_WIDTH (`TDC_COARSE_WIDTH + `TDC_FINE_WIDTH)

// Delay Line Parameters
`define DL_LENGTH 270              // Number of delay elements in chain
`define DL_WIDTH `DL_LENGTH        // Width to match delay line length

// Dead-zone Time Parameters (Issue #2 fix)
`define DEADTIME_CYCLES 4          // Number of cycles for dead-zone time
`define DEADTIME_WIDTH 3           // Width needed for deadtime counter (log2(DEADTIME_CYCLES+1))

// Priority Encoder Parameters
`define PE_STAGES 3                // Number of synchronization stages

// Fix #1: Proper initialization values as parameters (not just defines)
// These can be used for register initialization
parameter TDC_INIT_VALUE = 0;
parameter BIN270_INIT = 9'h000;    // Explicit initialization for bin270_prev
parameter DEADTIME_INIT = 3'h0;    // Explicit initialization for deadtime counter
parameter COARSE_INIT = 16'h0000;  // Explicit initialization for coarse counter

// State machine encoding for dl_sync
`define IDLE_STATE 2'b00
`define WAIT_STATE 2'b01
`define READY_STATE 2'b10
`define DEADTIME_STATE 2'b11

// Simulation delays (use in behavioral models only)
`ifdef SIMULATION
  `define DL_ELEMENT_DELAY #0.1    // 100ps delay per element in simulation
  `define SYNC_DELAY #0.5          // Synchronization delay
`else
  `define DL_ELEMENT_DELAY         // No delay in synthesis
  `define SYNC_DELAY
`endif

`endif // TDC_PKG_VH
