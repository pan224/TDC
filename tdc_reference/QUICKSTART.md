# Quick Start Guide - TDC Reference Implementation

## Overview

This TDC (Time-to-Digital Converter) reference implementation provides correctly converted Verilog code from VHDL, with all common conversion issues fixed.

## Files Structure

```
tdc_reference/
├── tdc_pkg.vh              # Package with parameters and initialization values
├── delay_line.v            # Delay line module
├── dl_sync.v               # Delay line synchronizer with dead-zone logic
├── priority_encoder.v      # Priority encoder with CDC
├── tdc.v                   # Top-level TDC module
├── tb_tdc.v                # Testbench
├── README.md               # Detailed documentation
├── SECURITY_SUMMARY.md     # Security analysis
└── QUICKSTART.md          # This file
```

## Basic Usage

### 1. Include the package

```verilog
`include "tdc_pkg.vh"
```

### 2. Instantiate the TDC

```verilog
tdc #(
    .CHANNEL_WIDTH(9),
    .COARSE_WIDTH(16),
    .FINE_WIDTH(9),
    .TOTAL_WIDTH(25)
) my_tdc (
    .clk(system_clk),
    .reset_n(reset_n),
    .start_pulse(start_signal),
    .stop_pulse(stop_signal),
    .channel_sel(9'h000),
    .time_diff(time_measurement),
    .time_valid(measurement_ready),
    .busy(tdc_busy)
);
```

### 3. Use the TDC

```verilog
// Wait for TDC to be ready
if (!tdc_busy) begin
    // Send start pulse
    start_signal <= 1'b1;
    @(posedge clk);
    start_signal <= 1'b0;
    
    // ... some time later ...
    
    // Send stop pulse
    stop_signal <= 1'b1;
    @(posedge clk);
    stop_signal <= 1'b0;
end

// Wait for measurement
wait(measurement_ready);
$display("Time difference: %d", time_measurement);
```

## Running the Testbench

If you have Icarus Verilog or a similar simulator:

```bash
# Compile
iverilog -o tb_tdc tb_tdc.v tdc.v dl_sync.v delay_line.v priority_encoder.v

# Run
vvp tb_tdc

# View waveforms (if VCD generated)
gtkwave tb_tdc.vcd
```

For ModelSim/Questa:

```tcl
vlib work
vlog -sv tdc_pkg.vh delay_line.v dl_sync.v priority_encoder.v tdc.v tb_tdc.v
vsim -voptargs=+acc tb_tdc
run -all
```

For Vivado:

1. Add all .v and .vh files to project
2. Set tb_tdc as top module
3. Run simulation

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| CHANNEL_WIDTH | 9 | Width of channel selection |
| COARSE_WIDTH | 16 | Width of coarse time counter |
| FINE_WIDTH | 9 | Width of fine time measurement |
| DL_LENGTH | 270 | Number of delay elements |
| DEADTIME_CYCLES | 4 | Dead-zone duration in clock cycles |

## Timing Characteristics

- **Dead-zone time**: 4 clock cycles after each measurement
- **Measurement latency**: ~3 clock cycles from stop to valid
- **Resolution**: Depends on delay element size (technology dependent)
- **Range**: `2^(COARSE_WIDTH+FINE_WIDTH)` time units

## Common Operations

### Checking if TDC is Ready

```verilog
if (!busy && !measurement_ready) begin
    // TDC is ready for new measurement
end
```

### Reading Results

```verilog
always @(posedge clk) begin
    if (time_valid) begin
        // Extract coarse and fine parts
        fine_time <= time_diff[FINE_WIDTH-1:0];
        coarse_time <= time_diff[TOTAL_WIDTH-1:FINE_WIDTH];
    end
end
```

### Handling Multiple Measurements

```verilog
always @(posedge clk) begin
    case (state)
        IDLE: begin
            if (!busy) begin
                start_pulse <= 1'b1;
                state <= WAIT_STOP;
            end
        end
        
        WAIT_STOP: begin
            start_pulse <= 1'b0;
            // ... wait for event ...
            if (event_detected) begin
                stop_pulse <= 1'b1;
                state <= WAIT_RESULT;
            end
        end
        
        WAIT_RESULT: begin
            stop_pulse <= 1'b0;
            if (time_valid) begin
                // Process result
                result <= time_diff;
                state <= IDLE;
            end
        end
    endcase
end
```

## Troubleshooting

### Simulation shows X values

- Check that `reset_n` is properly asserted and de-asserted
- Ensure all clocks are running
- Verify all inputs are driven

### Measurements always zero

- Check that start and stop pulses are separated by some time
- Verify clock is running
- Ensure TDC is not in reset

### TDC always busy

- Check that you're waiting for `time_valid` before starting new measurement
- Verify dead-zone counter is working (4 cycles)
- Check state machine is transitioning correctly

## Advanced Configuration

### Simulation Mode

Set `SIMULATION` parameter to 1 for behavioral delay model:

```verilog
delay_line #(
    .LENGTH(270),
    .SIMULATION(1)  // Enable for simulation
) dl (...);
```

### Custom Dead-zone Time

Modify in tdc_pkg.vh:

```verilog
`define DEADTIME_CYCLES 8  // Increase dead-zone time
```

### Different Delay Line Length

```verilog
`define DL_LENGTH 512  // More delay elements for finer resolution
```

## Support

For detailed documentation, see:
- `README.md` - Complete documentation with all fixes explained
- `SECURITY_SUMMARY.md` - Security and quality analysis
- Source code comments - Inline documentation of all fixes

## What's Fixed

This implementation fixes all common VHDL-to-Verilog conversion issues:

1. ✅ Proper signal initialization (no X propagation)
2. ✅ Complete dead-zone time counter logic
3. ✅ Correct generate block initialization for simulation
4. ✅ Explicit sign handling in arithmetic operations
5. ✅ Proper clock domain crossing synchronization

All code is production-ready and synthesis-friendly!
