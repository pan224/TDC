`timescale 1ns / 1ps

module tb_tdc_top;

// 时钟和复位
reg clk_sys;
reg reset;

// VIO 模拟信号（在仿真中直接赋值）
reg [4:0] vio_data;
reg vio_valid;

// TDC 信号
wire tdc_start;
wire tdc_reset;
wire cs_gap;
wire [8:0] value_gap;
wire [22:0] coarse_counter;

// 实例化测试控制模块
tdc_test_ctrl #(
    .DATA_WIDTH(5)
) tdc_test_ctrl_inst (
    .clk_sys(clk_sys),
    .clk_ref200(clk_sys),
    .reset_in(reset),
    .vio_data(vio_data),
    .vio_valid(vio_valid),
    .tdc_start(tdc_start),
    .tdc_reset(tdc_reset)
);

// 实例化 TDC 模块
tdc_top #(
    .STAGE(512),
    .GAP_BITS(9)
) tdc_top_inst (
    .sg_start(tdc_start),
    .clk_sys(clk_sys),
    .reset(tdc_reset),
    .sg_delay_value(5'd0),
    .sg_delay_load(1'b0),
    .rst_delay_value(5'd0),
    .rst_delay_load(1'b0),
    .cs_gap(cs_gap),
    .value_gap(value_gap),
    .coarse_counter(coarse_counter)
);

//------------------------------------------------------------------------------
// 时钟生成：200MHz
//------------------------------------------------------------------------------
initial begin
    clk_sys = 1'b0;
    forever #2.5 clk_sys = ~clk_sys;
end

//------------------------------------------------------------------------------
// 仿真激励：模拟 VIO 操作
//------------------------------------------------------------------------------
initial begin
    // 初始化
    reset = 1'b1;
    vio_data = 5'd0;
    vio_valid = 1'b0;
    
    #100;
    reset = 1'b0;
    
    #1000; // 等待系统稳定
    
    // 测试 1: vio_data = 0
    $display("=== Test 1: vio_data = 0 ===");
    vio_data = 5'd0;
    vio_valid = 1'b1;
    #20;
    vio_valid = 1'b0;
    #500;
    
    // 测试 2: vio_data = 5
    $display("=== Test 2: vio_data = 5 ===");
    vio_data = 5'd5;
    vio_valid = 1'b1;
    #20;
    vio_valid = 1'b0;
    #500;
    
    // 测试 3: vio_data = 10
    $display("=== Test 3: vio_data = 10 ===");
    vio_data = 5'd10;
    vio_valid = 1'b1;
    #20;
    vio_valid = 1'b0;
    #500;
    
    // 测试 4: vio_data = 25
    $display("=== Test 4: vio_data = 25 ===");
    vio_data = 5'd25;
    vio_valid = 1'b1;
    #20;
    vio_valid = 1'b0;
    #500;
    
    $display("Simulation completed.");
    $finish;
end

//------------------------------------------------------------------------------
// 监控输出
//------------------------------------------------------------------------------
always @(posedge cs_gap) begin
    $display("Time=%0t: cs_gap asserted, value_gap=%0d, coarse=%0d", 
             $realtime, value_gap, coarse_counter);
end

//------------------------------------------------------------------------------
// 波形转储
//------------------------------------------------------------------------------
initial begin
    $dumpfile("tb_tdc_top.vcd");
    $dumpvars(0, tb_tdc_top);
end

endmodule