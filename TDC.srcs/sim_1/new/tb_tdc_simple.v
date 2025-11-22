`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 简化的 TDC 测试控制仿真（不依赖 dynamic_phase_pulse_gen）
//////////////////////////////////////////////////////////////////////////////////

module tb_tdc_simple;

parameter CLK_PERIOD = 5.0;  // 200MHz

// 信号声明
reg clk_sys;
reg vio_reset_in;
reg [7:0] vio_phase;
reg vio_valid;
reg sel_function;

wire tdc_start;
wire tdc_reset;

// 计数器
integer pulse_count;
integer test_num;

// DUT 实例化
tdc_test_ctrl_phase #(
    .DATA_WIDTH(8)
) dut (
    .clk_sys(clk_sys),
    .vio_reset_in(vio_reset_in),
    .vio_phase(vio_phase),
    .vio_valid(vio_valid),
    .sel_function(sel_function),
    .tdc_start(tdc_start),
    .tdc_reset(tdc_reset)
);

// 时钟生成
initial begin
    clk_sys = 0;
    forever #(CLK_PERIOD/2) clk_sys = ~clk_sys;
end

// 监控脉冲
always @(posedge tdc_start) begin
    pulse_count = pulse_count + 1;
    $display("[%0t] Pulse #%0d detected", $time, pulse_count);
end

// 监控状态变化
always @(dut.state) begin
    $display("[%0t] State changed to: %0d", $time, dut.state);
end

// 主测试流程
initial begin
    // 初始化
    vio_reset_in = 1'b1;
    vio_phase = 8'd0;
    vio_valid = 1'b0;
    sel_function = 1'b0;
    pulse_count = 0;
    test_num = 0;
    
    $display("\n========================================");
    $display("  TDC Test Control Simple Testbench");
    $display("========================================\n");
    
    // 复位
    $display("[%0t] Applying reset...", $time);
    repeat(10) @(posedge clk_sys);
    vio_reset_in = 1'b0;
    $display("[%0t] Reset released", $time);
    repeat(20) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试 1: 单次模式
    //--------------------------------------------------------------------------
    test_num = test_num + 1;
    $display("\n[%0t] ===== Test %0d: Single Pulse Mode =====", $time, test_num);
    
    vio_phase = 8'd10;
    sel_function = 1'b0;
    pulse_count = 0;
    
    @(posedge clk_sys);
    vio_valid = 1'b1;
    @(posedge clk_sys);
    @(posedge clk_sys);
    vio_valid = 1'b0;
    
    // 等待完成
    wait(dut.state == 4'd7);  // DONE 状态
    repeat(10) @(posedge clk_sys);
    
    if(pulse_count == 1) begin
        $display("[PASS] Test %0d: Single pulse generated", test_num);
    end else begin
        $display("[FAIL] Test %0d: Expected 1 pulse, got %0d", test_num, pulse_count);
    end
    
    repeat(20) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试 2: 扫描模式（小范围测试）
    //--------------------------------------------------------------------------
    test_num = test_num + 1;
    $display("\n[%0t] ===== Test %0d: Scan Mode (0-10) =====", $time, test_num);
    
    vio_phase = 8'd0;  // 在扫描模式下会被忽略
    sel_function = 1'b1;
    pulse_count = 0;
    
    @(posedge clk_sys);
    vio_valid = 1'b1;
    @(posedge clk_sys);
    @(posedge clk_sys);
    vio_valid = 1'b0;
    
    // 等待扫描完成（限制扫描范围以加快仿真）
    // 注意：需要修改 tdc_test_ctrl 模块支持可配置扫描范围，
    // 或者等待足够长时间
    wait(dut.state == 4'd7 && dut.scan_mode == 1'b0);
    repeat(10) @(posedge clk_sys);
    
    $display("[INFO] Test %0d: Scan completed with %0d pulses", test_num, pulse_count);
    
    if(pulse_count == 141) begin
        $display("[PASS] Test %0d: Correct number of pulses", test_num);
    end else begin
        $display("[WARN] Test %0d: Expected 141 pulses, got %0d", test_num, pulse_count);
    end
    
    repeat(50) @(posedge clk_sys);
    
    //--------------------------------------------------------------------------
    // 测试总结
    //--------------------------------------------------------------------------
    $display("\n========================================");
    $display("  Simulation Summary");
    $display("========================================");
    $display("Total tests: %0d", test_num);
    $display("Simulation time: %0t", $time);
    $display("========================================\n");
    
    $display("[%0t] Simulation completed successfully!", $time);
    $finish;
end

// 超时保护
initial begin
    #1000000;  // 1 ms
    $display("\n[ERROR] Simulation timeout at %0t!", $time);
    $display("Current state: %0d", dut.state);
    $display("Pulse count: %0d", pulse_count);
    $finish;
end

// 波形记录
initial begin
    $dumpfile("tb_tdc_simple.vcd");
    $dumpvars(0, tb_tdc_simple);
end

endmodule
