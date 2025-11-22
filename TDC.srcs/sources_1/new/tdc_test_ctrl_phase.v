`timescale 1ns / 1ps

module tdc_test_ctrl_phase #(
    parameter DATA_WIDTH = 8  // 0-140 相位步数

)(
    input wire                      clk_sys,
    input wire                      vio_reset_in,
    
    // VIO 控制
    input wire [DATA_WIDTH-1:0]     vio_phase,      // 相位步数
    input wire                      vio_valid,
    input wire                      sel_function,   // 0=单次脉冲, 1=扫描模式   
    
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
reg [DATA_WIDTH-1:0] phase_value;  // 实际使用的相位值
//T_VCO=1000MHZ，1ns
//1° = 1ns/56 ≈ 17.86ps
//2500ps ≈ 140 步
dynamic_phase_pulse_gen #(
    .PHASE_STEPS(56),
    .PULSE_WIDTH(2)
) phase_gen_inst (
    .clk_ref(clk_sys),
    .reset(vio_reset_in),
    .target_phase(phase_value[7:0]),  
    .phase_load(phase_load),
    .trigger(trigger_pulse),
    .pulse_out(tdc_start),
    .phase_ready(phase_ready)
);

//------------------------------------------------------------------------------
// 测试序列控制状态机
//------------------------------------------------------------------------------
localparam IDLE             = 4'd0;
localparam LOAD_PHASE       = 4'd1;
localparam WAIT_READY       = 4'd2;
localparam RESET_LOW        = 4'd3;
localparam TRIGGER          = 4'd4;
localparam WAIT_PULSE       = 4'd5;
localparam RESET_HIGH       = 4'd6;
localparam DONE             = 4'd7;
localparam SCAN_NEXT        = 4'd8;  // 新状态：扫描下一个相位
localparam SCAN_WAIT        = 4'd9;  // 新状态：扫描等待
localparam SCAN_COMPLETE    = 4'd10; // 新状态：扫描完成

reg [3:0] state;
reg [15:0] counter;
reg [DATA_WIDTH-1:0] scan_counter;  // 扫描计数器
reg scan_mode;                       // 扫描模式标志

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

//------------------------------------------------------------------------------
// 主控制状态机
//------------------------------------------------------------------------------
always @(posedge clk_sys) begin
    if(vio_reset_in) begin
        state <= IDLE;
        counter <= 16'd0;
        phase_load <= 1'b0;
        trigger_pulse <= 1'b0;
        tdc_reset <= 1'b1;
        scan_counter <= {DATA_WIDTH{1'b0}};
        scan_mode <= 1'b0;
        phase_value <= {DATA_WIDTH{1'b0}};
    end
    else begin
        case(state)
            IDLE: begin
                tdc_reset <= 1'b1;
                trigger_pulse <= 1'b0;
                phase_load <= 1'b0;
                counter <= 16'd0;
                
                if(vio_valid_posedge) begin
                    // 根据 sel_function 决定模式
                    if(sel_function == 1'b1) begin
                        // 扫描模式：从 0 到 140
                        scan_mode <= 1'b1;
                        scan_counter <= 8'd0;
                        phase_value <= 8'd0;
                    end
                    else begin
                        // 单次模式：使用 vio_phase
                        scan_mode <= 1'b0;
                        phase_value <= vio_phase;
                    end
                    
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
                counter <= counter + 1'b1;
                if(counter >= 16'd2) begin  // 保持脉冲 10ns
                    trigger_pulse <= 1'b0;
                end
                if(counter >= 16'd20) begin  // 等待 100ns
                    counter <= 16'd0;
                    state <= RESET_HIGH;
                end
            end
            
            RESET_HIGH: begin
                tdc_reset <= 1'b1;
                
                // 判断是否继续扫描
                if(scan_mode) begin
                    state <= SCAN_NEXT;
                end
                else begin
                    state <= DONE;
                end
            end
            
            SCAN_NEXT: begin
                counter <= counter + 1'b1;
                
                // 等待一段时间再进行下一次扫描
                if(counter >= 16'd20) begin  // 等待 100ns
                    counter <= 16'd0;
                    
                    // 检查是否完成所有相位扫描
                    if(scan_counter >= 8'd140) begin
                        state <= SCAN_COMPLETE;
                    end
                    else begin
                        // 准备下一个相位
                        scan_counter <= scan_counter + 1'b1;
                        phase_value <= scan_counter + 1'b1;
                        phase_load <= 1'b1;
                        state <= LOAD_PHASE;
                    end
                end
            end
            
            SCAN_COMPLETE: begin
                scan_mode <= 1'b0;
                scan_counter <= 8'd0;
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