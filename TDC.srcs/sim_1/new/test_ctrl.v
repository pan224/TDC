`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_tdc_test_ctrl_phase
// Description: tdc_test_ctrl_phase 模块的仿真测试台
//////////////////////////////////////////////////////////////////////////////////

module tb_tdc_test_ctrl_phase;

//------------------------------------------------------------------------------
// 参数定义
//------------------------------------------------------------------------------
parameter DATA_WIDTH = 8;
parameter CLK_PERIOD = 5.0;  // 200MHz 系统时钟周期 = 5ns

//------------------------------------------------------------------------------
// 信号声明
//------------------------------------------------------------------------------
// 时钟和复位
reg clk_sys;
reg vio_reset_in;

// VIO 控制信号
reg [DATA_WIDTH-1:0] vio_phase;
reg vio_valid;

// TDC 控制信号
wire tdc_start;
wire tdc_reset;

// 测试计数器
integer test_count;

//------------------------------------------------------------------------------
// DUT 实例化
//------------------------------------------------------------------------------
tdc_test_ctrl_phase #(
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk_sys(clk_sys),
    .vio_reset_in(vio_reset_in),
    .vio_phase(vio_phase),
    .vio_valid(vio_valid),
    .tdc_start(tdc_start),
    .tdc_reset(tdc_reset)
);

//------------------------------------------------------------------------------
// 时钟生成：200MHz (5ns 周期)
//------------------------------------------------------------------------------
initial begin
    clk_sys = 0;
    forever #(CLK_PERIOD/2) clk_sys = ~clk_sys;
end

//------------------------------------------------------------------------------
// 监控信号变化
//------------------------------------------------------------------------------
always @(posedge tdc_start) begin
    $display("[%0t] INFO: tdc_start pulse detected at phase=%0d", $time, vio_phase);
end

always @(negedge tdc_reset) begin
    $display("[%0t] INFO: tdc_reset goes LOW", $time);
end

always @(posedge tdc_reset) begin
    $display("[%0t] INFO: tdc_reset goes HIGH", $time);
end

// 监控状态机状态
always @(dut.state) begin
    case(dut.state)
        3'd0: $display("[%0t] STATE: IDLE", $time);
        3'd1: $display("[%0t] STATE: LOAD_PHASE", $time);
        3'd2: $display("[%0t] STATE: WAIT_READY", $time);
        3'd3: $display("[%0t] STATE: RESET_LOW", $time);
        3'd4: $display("[%0t] STATE: TRIGGER", $time);
        3'd5: $display("[%0t] STATE: WAIT_PULSE", $time);
        3'd6: $display("[%0t] STATE: RESET_HIGH", $time);
        3'd7: $display("[%0t] STATE: DONE", $time);
    endcase
end

//------------------------------------------------------------------------------
// 任务：发送 VIO 触发
//------------------------------------------------------------------------------
task send_vio_trigger;
    input [DATA_WIDTH-1:0] phase_value;
    begin
        $display("\n[%0t] ====== Starting test with phase=%0d ======", $time, phase_value);
        vio_phase = phase_value;
        @(posedge clk_sys);
        vio_valid = 1'b1;
        @(posedge clk_sys);
        @(posedge clk_sys);
        vio_valid = 1'b0;
        
        // 等待测试序列完成
        wait(dut.state == 3'd7);  // DONE 状态
        @(posedge clk_sys);
        @(posedge clk_sys);
        
        $display("[%0t] ====== Test completed for phase=%0d ======\n", $time, phase_value);
        test_count = test_count + 1;
    end
endtask

//------------------------------------------------------------------------------
// 主测试流程
//------------------------------------------------------------------------------
initial begin
    // 初始化信号
    vio_reset_in = 1'b1;
    vio_phase = 8'd0;
    vio_valid = 1'b0;
    test_count = 0;
    
    $display("\n");
    $display("========================================");
    $display("  TDC Test Control Phase Testbench");
    $display("========================================");
    $display("Clock Period: %0.1f ns (200MHz)", CLK_PERIOD);
    $display("Phase Steps: 56");
    $display("Phase Resolution: ~17.86 ps/step");
    $display("========================================\n");
    
    // 复位序列
    $display("[%0t] Applying reset...", $time);
    repeat(10) @(posedge clk_sys);
    vio_reset_in = 1'b0;
    $display("[%0t] Reset released", $time);
    repeat(20) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 1: Phase = 0 (0°, 0 ps)
    //--------------------------------------------------------------------------
    send_vio_trigger(8'd0);
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 2: Phase = 14 (90°, ~250 ps)
    //--------------------------------------------------------------------------
    send_vio_trigger(8'd14);
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 3: Phase = 28 (180°, ~500 ps)
    //--------------------------------------------------------------------------
    send_vio_trigger(8'd28);
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 4: Phase = 42 (270°, ~750 ps)
    //--------------------------------------------------------------------------
    send_vio_trigger(8'd42);
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 5: Phase = 55 (353°, ~982 ps)
    //--------------------------------------------------------------------------
    send_vio_trigger(8'd55);
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 6: 快速连续触发
    //--------------------------------------------------------------------------
    $display("\n[%0t] ====== Testing rapid triggers ======", $time);
    send_vio_trigger(8'd10);
    repeat(10) @(posedge clk_sys);
    send_vio_trigger(8'd20);
    repeat(10) @(posedge clk_sys);
    send_vio_trigger(8'd30);
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 7: 边界值测试
    //--------------------------------------------------------------------------
    $display("\n[%0t] ====== Testing boundary values ======", $time);
    send_vio_trigger(8'd0);    // 最小值
    repeat(30) @(posedge clk_sys);
    send_vio_trigger(8'd140);  // 最大值 (会被模块限制到 55)
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试用例 8: 相位递增测试
    //--------------------------------------------------------------------------
    $display("\n[%0t] ====== Testing incremental phases ======", $time);
    for(integer i = 0; i <= 55; i = i + 7) begin
        send_vio_trigger(i);
        repeat(30) @(posedge clk_sys);
    end
    
    //--------------------------------------------------------------------------
    // 测试总结
    //--------------------------------------------------------------------------
    repeat(100) @(posedge clk_sys);
    
    $display("\n");
    $display("========================================");
    $display("  Simulation Summary");
    $display("========================================");
    $display("Total tests completed: %0d", test_count);
    $display("Simulation time: %0t", $time);
    $display("========================================\n");
    
    $display("[%0t] Simulation finished successfully!", $time);
    $finish;
end

//------------------------------------------------------------------------------
// 超时保护
//------------------------------------------------------------------------------
initial begin
    #100000;  // 100 us 超时
    $display("\n[ERROR] Simulation timeout!");
    $finish;
end
endmodule