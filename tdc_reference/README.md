# TDC Reference Implementation - VHDL to Verilog Conversion Fixes

This directory contains a reference TDC (Time-to-Digital Converter) implementation with all common VHDL-to-Verilog conversion issues properly fixed.

## Files

1. **tdc_pkg.vh** - Package file with proper parameter definitions
2. **delay_line.v** - Delay line module with simulation model
3. **dl_sync.v** - Delay line synchronizer with dead-zone logic
4. **priority_encoder.v** - Priority encoder with proper CDC
5. **tdc.v** - Top-level TDC with explicit sign handling

## Issues Fixed

### Issue #1: Signal Initialization Problems (tdc_pkg.vh, dl_sync.v)

**Problem**: In VHDL-to-Verilog conversion, signal initialization was often lost or improperly converted, leading to 'X' propagation in simulation.

**Fix in tdc_pkg.vh**:
- Added explicit `parameter` definitions for initialization values
- Created `BIN270_INIT`, `DEADTIME_INIT`, `COARSE_INIT` parameters
- Used these in register declarations across modules

**Fix in dl_sync.v**:
```verilog
// Before (typical conversion error):
reg [FINE_WIDTH-1:0] bin270_prev;  // No initialization

// After (fixed):
reg [FINE_WIDTH-1:0] bin270_prev = BIN270_INIT;  // Explicit initialization
```

### Issue #2: Missing Dead-zone Time Counter Logic (dl_sync.v)

**Problem**: The VHDL variable `v_deadtime` was not properly converted to Verilog, resulting in missing dead-zone management logic.

**Fix in dl_sync.v**:
- Added `deadtime_cnt` register to count dead-zone cycles
- Added `deadtime_active` flag to indicate busy state
- Implemented `DEADTIME_STATE` in state machine
- Connected `busy` output to indicate when TDC cannot accept new measurements

```verilog
// Added dead-zone counter:
reg [`DEADTIME_WIDTH-1:0] deadtime_cnt = DEADTIME_INIT;
reg deadtime_active = 1'b0;

// Dead-zone management in state machine:
if (deadtime_active) begin
    if (deadtime_cnt == `DEADTIME_CYCLES) begin
        deadtime_active <= 1'b0;
        deadtime_cnt <= DEADTIME_INIT;
    end else begin
        deadtime_cnt <= deadtime_cnt + 1'b1;
    end
end
```

### Issue #3: Simulation Model Issues (delay_line.v)

**Problem**: Generate blocks in converted code lacked proper initialization, causing undefined behavior in simulation.

**Fix in delay_line.v**:
- Added explicit initialization in all generate blocks
- Separate behavioral model for simulation with `SIMULATION` parameter
- Each generated delay element has explicit reset handling

```verilog
// Fixed generate block with proper initialization:
for (j = 1; j < LENGTH; j = j + 1) begin : delay_chain_gen
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            delay_taps[j] <= 1'b0;  // Explicit reset in each iteration
        end else begin
            delay_taps[j] <= delay_taps[j-1];
        end
    end
end
```

### Issue #4: Explicit Sign Handling (tdc.v)

**Problem**: VHDL's automatic type conversions were not properly translated, causing sign errors in arithmetic operations.

**Fix in tdc.v**:
- Used `$signed()` for all signed arithmetic operations
- Added extra bits for sign extension where needed
- Explicit handling of borrow in coarse/fine time calculations

```verilog
// Before (incorrect):
coarse_diff = coarse_stop - coarse_start;  // May not handle signs correctly

// After (fixed):
reg signed [COARSE_WIDTH:0] coarse_diff;  // Extra bit for sign
coarse_diff = $signed({1'b0, coarse_stop}) - $signed({1'b0, coarse_start});

// Explicit borrow handling:
if (fine_diff < 0) begin
    coarse_diff = coarse_diff - 1;  // Signed arithmetic
    fine_diff = fine_diff + $signed({1'b0, `DL_LENGTH});
end
```

### Issue #5: Priority Encoder Synchronization (priority_encoder.v)

**Problem**: Clock domain crossing logic was unclear and lacked proper metastability protection.

**Fix in priority_encoder.v**:
- Implemented explicit multi-stage synchronizers
- Separated data and control signal synchronization
- Added ASYNC_REG attributes for synthesis tools
- Implemented edge detection for control signals

```verilog
// Multi-stage synchronization with ASYNC_REG:
(* ASYNC_REG = "TRUE" *) reg [OUT_WIDTH-1:0] sync_data_stage1;
(* ASYNC_REG = "TRUE" *) reg [OUT_WIDTH-1:0] sync_data_stage2;
(* ASYNC_REG = "TRUE" *) reg valid_sync_stage1;
(* ASYNC_REG = "TRUE" *) reg valid_sync_stage2;
(* ASYNC_REG = "TRUE" *) reg valid_sync_stage3;  // Extra stage for reliability

// Edge detection on synchronized valid:
valid_out <= valid_sync_stage3 && !valid_sync_prev;
```

## Usage

To use these modules in your design:

1. Include the package file:
```verilog
`include "tdc_pkg.vh"
```

2. Instantiate the TDC:
```verilog
tdc #(
    .CHANNEL_WIDTH(9),
    .COARSE_WIDTH(16),
    .FINE_WIDTH(9)
) tdc_inst (
    .clk(clk),
    .reset_n(reset_n),
    .start_pulse(start),
    .stop_pulse(stop),
    .channel_sel(channel),
    .time_diff(time_measurement),
    .time_valid(valid),
    .busy(busy)
);
```

## Simulation

For simulation, set the `SIMULATION` parameter:

```verilog
delay_line #(
    .LENGTH(270),
    .SIMULATION(1)  // Enable behavioral model
) dl_inst (...);
```

## Synthesis Considerations

- All synchronizers use ASYNC_REG attributes for proper constraint generation
- Delay chain uses dont_touch and keep attributes to prevent optimization
- Dead-zone logic ensures proper recovery time between measurements
- All arithmetic operations are explicitly signed to ensure correct synthesis

## Testing

Each module includes:
- Explicit initialization for clean simulation
- Reset handling for all registers
- Comments explaining the fixes
- Synthesis directives where appropriate

## Interface Compatibility

All modules maintain standard Verilog interfaces (NOT VHDL record-based interfaces) for easy integration with existing designs.
