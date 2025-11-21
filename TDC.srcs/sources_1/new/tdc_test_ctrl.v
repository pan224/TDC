`timescale 1ns / 1ps

module tdc_test_ctrl_phase #(
    parameter DATA_WIDTH = 8  // 0-140 相位步数

)(
    input wire                      clk_sys,
    input wire                      vio_reset_in,
    
    // VIO 控制
    input wire [DATA_WIDTH-1:0]     vio_phase,      // 相位步数
    input wire                      vio_valid,
    
    // TDC 控制信号
    output wire                     tdc_start,
    output reg                      tdc_reset
);

//------------------------------------------------------------------------------
// 动态相位脉冲生成器
//------------------------------------------------------------------------------
wire phase_ready;
reg phase_load;
reg trigger_pulse;
//T_VCO=1000MHZ，1ns
//1° = 1ns/56 ≈ 17.86ps
//2500ps ≈ 140 步
dynamic_phase_pulse_gen #(
    .PHASE_STEPS(56),
    .PULSE_WIDTH(2)
) phase_gen_inst (
    .clk_ref(clk_sys),
    .reset(vio_reset_in),
    .target_phase(vio_phase),
    .phase_load(phase_load),
    .trigger(trigger_pulse),
    .pulse_out(tdc_start),
    .phase_ready(phase_ready)
);

//------------------------------------------------------------------------------
// 测试序列控制
//------------------------------------------------------------------------------
localparam IDLE         = 3'd0;
localparam LOAD_PHASE   = 3'd1;
localparam WAIT_READY   = 3'd2;
localparam RESET_LOW    = 3'd3;
localparam TRIGGER      = 3'd4;
localparam WAIT_PULSE   = 3'd5;
localparam RESET_HIGH   = 3'd6;
localparam DONE         = 3'd7;

reg [2:0] state;
reg [15:0] counter;

// VIO 边沿检测
reg vio_valid_d1, vio_valid_d2;
wire vio_valid_posedge;

always @(posedge clk_sys) begin
    if(vio_reset_in) begin
        vio_valid_d1 <= 1'b0;
        vio_valid_d2 <= 1'b0;
    end
    else begin
        vio_valid_d1 <= vio_valid;
        vio_valid_d2 <= vio_valid_d1;
    end
end

assign vio_valid_posedge = vio_valid_d1 & ~vio_valid_d2;

always @(posedge clk_sys) begin
    if(vio_reset_in) begin
        state <= IDLE;
        counter <= 16'd0;
        phase_load <= 1'b0;
        trigger_pulse <= 1'b0;
        tdc_reset <= 1'b1;
    end
    else begin
        case(state)
            IDLE: begin
                tdc_reset <= 1'b1;
                trigger_pulse <= 1'b0;
                phase_load <= 1'b0;
                counter <= 16'd0;
                
                if(vio_valid_posedge) begin
                    phase_load <= 1'b1;  // 触发相位调整
                    state <= LOAD_PHASE;
                end
            end
            
            LOAD_PHASE: begin
                phase_load <= 1'b0;
                state <= WAIT_READY;
            end
            
            WAIT_READY: begin
                if(phase_ready) begin
                    state <= RESET_LOW;
                end
            end
            
            RESET_LOW: begin
                tdc_reset <= 1'b0;
                counter <= counter + 1'b1;
                
                if(counter >= 16'd8) begin  // 等待 40ns
                    counter <= 16'd0;
                    state <= TRIGGER;
                end
            end
            
            TRIGGER: begin
                trigger_pulse <= 1'b1;
                state <= WAIT_PULSE;
            end
            
            WAIT_PULSE: begin
                trigger_pulse <= 1'b0;
                counter <= counter + 1'b1;
                
                if(counter >= 16'd8) begin  // 等待 40ns
                    counter <= 16'd0;
                    state <= RESET_HIGH;
                end
            end
            
            RESET_HIGH: begin
                tdc_reset <= 1'b1;
                state <= DONE;
            end
            
            DONE: begin
                if(~vio_valid) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule