`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_test
// Description: test.v 顶层模块的仿真文件
//////////////////////////////////////////////////////////////////////////////////

module tb_test;

//------------------------------------------------------------------------------
// 信号声明
//------------------------------------------------------------------------------
// 系统时钟和复位
reg  CPU_RESET;
reg  SYS_CLK_P;
reg  SYS_CLK_N;
reg  SGMIICLK_Q0_P;
reg  SGMIICLK_Q0_N;

// GBE 接口信号 - 改为 reg 类型并提供默认值
wire PHY_RESET_N;
wire MDIO;
wire MDC;
wire [3:0] RGMII_TXD;
wire RGMII_TX_CTL;
wire RGMII_TXC;

// RGMII 输入信号需要驱动
reg [3:0] RGMII_RXD;
reg RGMII_RX_CTL;
reg RGMII_RXC;

// 内部探测信号
wire sys_clk;
wire reset;
wire clk_bufg;
wire tdc_start;
wire tdc_reset;
wire cs_gap;
wire [8:0] value_gap;
wire [22:0] coarse_counter;
wire [511:0] value_latch_raw;
wire [511:0] value_latch_fixed;

// CSV 记录相关
integer csv_fd;
real delta_ps;
reg [8:0] value_sample;
reg [22:0] coarse_sample;
realtime last_clk_edge_time;
realtime start_time;
realtime next_clk_time;

// VIO 模拟信号
reg [4:0] vio_data;
reg vio_valid;

//------------------------------------------------------------------------------
// DUT 例化
//------------------------------------------------------------------------------
test test_inst (
    .CPU_RESET(CPU_RESET),
    .SYS_CLK_P(SYS_CLK_P),
    .SYS_CLK_N(SYS_CLK_N),
    .SGMIICLK_Q0_P(SGMIICLK_Q0_P),
    .SGMIICLK_Q0_N(SGMIICLK_Q0_N),
    .PHY_RESET_N(PHY_RESET_N),
    .MDIO(MDIO),
    .MDC(MDC),
    .RGMII_TXD(RGMII_TXD),
    .RGMII_RXD(RGMII_RXD),
    .RGMII_TX_CTL(RGMII_TX_CTL),
    .RGMII_RX_CTL(RGMII_RX_CTL),
    .RGMII_TXC(RGMII_TXC),
    .RGMII_RXC(RGMII_RXC)
);

//------------------------------------------------------------------------------
// 信号连接到内部节点（用于观察）
//------------------------------------------------------------------------------
assign sys_clk = test_inst.sys_clk;
assign reset = test_inst.reset;

// 使用条件赋值避免层次路径错误
generate
    if (1) begin : check_hierarchy
        assign clk_bufg = test_inst.clk_bufg;
        assign tdc_start = test_inst.tdc_start;
        assign tdc_reset = test_inst.tdc_reset;
        assign cs_gap = test_inst.cs_gap;
        assign value_gap = test_inst.value_gap;
        assign coarse_counter = test_inst.coarse_counter;
        assign value_latch_raw = test_inst.tdc_top_inst.value_latch_raw;
        assign value_latch_fixed = test_inst.tdc_top_inst.value_latch_fixed;
    end
endgenerate

//------------------------------------------------------------------------------
// 时钟生成
//------------------------------------------------------------------------------
// 200MHz 差分系统时钟
initial begin
    SYS_CLK_P = 1'b0;
    SYS_CLK_N = 1'b1;
    forever begin
        #2.5 SYS_CLK_P = ~SYS_CLK_P;
        SYS_CLK_N = ~SYS_CLK_P;
    end
end

// 125MHz SGMII 时钟（GBE 用）
initial begin
    SGMIICLK_Q0_P = 1'b0;
    SGMIICLK_Q0_N = 1'b1;
    forever begin
        #4 SGMIICLK_Q0_P = ~SGMIICLK_Q0_P;
        SGMIICLK_Q0_N = ~SGMIICLK_Q0_P;
    end
end

// RGMII 接收时钟（模拟 PHY 接收）
initial begin
    RGMII_RXC = 1'b0;
    RGMII_RXD = 4'b0;
    RGMII_RX_CTL = 1'b0;
    forever begin
        #4 RGMII_RXC = ~RGMII_RXC;  // 125MHz
    end
end

//------------------------------------------------------------------------------
// VIO 模拟 - 修正路径
//------------------------------------------------------------------------------
initial begin
    #1; // 等待 DUT 例化完成
    // 检查层次路径是否正确
    if ($test$plusargs("debug")) begin
        $display("Forcing VIO signals...");
    end
    
    // 根据实际层次路径强制连接
    force test_inst.vio_inst.probe_out0 = vio_data;
    force test_inst.vio_inst.probe_out1 = vio_valid;
end

//------------------------------------------------------------------------------
// 测试激励
//------------------------------------------------------------------------------
initial begin
    CPU_RESET = 1'b0;  // 低电平复位
    vio_data = 5'd0;
    vio_valid = 1'b0;
    
    $display("=================================================");
    $display("TDC Test Simulation Started at %0t", $time);
    $display("=================================================");
    
    #100;  // 初始延迟
    CPU_RESET = 1'b1;  // 释放复位
    
    // 等待系统稳定
    wait(reset == 1'b0);  // 等待内部复位释放
    #500;
    
    $display("System initialized. Starting tests at %0t", $time);
    
    // 配置初始延迟值
    @(posedge sys_clk);
    vio_data = 5'd5;  // 设置延迟为 5 tap (990ps)
    
    // 开始测试循环
    repeat(50) begin  // 运行 50 次测试
        @(posedge sys_clk);
        vio_valid = 1'b1;  // 拉高触发信号
        
        repeat(3) @(posedge sys_clk);
        vio_valid = 1'b0;  // 拉低触发信号
        
        // 等待测试完成
        wait(cs_gap == 1'b1);
        wait(cs_gap == 1'b0);
        
        // 延迟一段时间再开始下一次测试
        repeat(10) @(posedge sys_clk);
        
        // 改变延迟值
        vio_data = (vio_data + 1) % 32;
    end
    
    // 完成仿真
    #1000;
    $display("=================================================");
    $display("Test completed at %0t", $time);
    $display("=================================================");
    if (csv_fd) $fclose(csv_fd);
    $finish;
end

//------------------------------------------------------------------------------
// CSV 数据记录
//------------------------------------------------------------------------------
initial begin
    csv_fd = $fopen("tdc_test_capture.csv", "w");
    if (csv_fd == 0) begin
        $display("ERROR: Failed to open CSV file.");
        $finish;
    end
    $fwrite(csv_fd, "start_to_clk_ps,value_gap_at_cs_gap,coarse_counter,vio_delay_tap\n");
    last_clk_edge_time = 0.0;
end

// 记录最后一次时钟上升沿时间
always @(posedge clk_bufg) begin
    last_clk_edge_time = $realtime;
end

// 捕获 start 到下一个 clk_bufg 上升沿的时间差
always begin
    @(posedge tdc_start);
    start_time = $realtime;
    
    // 等待下一个时钟边沿
    @(posedge clk_bufg);
    next_clk_time = $realtime;
    
    delta_ps = (next_clk_time - start_time) * 1000.0;
    
    // 等待 cs_gap 有效并采样数据
    @(posedge cs_gap);
    #1;  // 小延迟确保数据稳定
    value_sample = value_gap;
    coarse_sample = coarse_counter;
    
    $fwrite(csv_fd, "%.1f,%0d,%0d,%0d\n", 
            delta_ps, value_sample, coarse_sample, vio_data);
    
    $display("[%0t] Delta=%.1fps, Gap=%0d, Coarse=%0d, VIO=%0d", 
             $time, delta_ps, value_sample, coarse_sample, vio_data);
end

//------------------------------------------------------------------------------
// 错误检测 - 修复后的版本
//------------------------------------------------------------------------------
reg timeout_flag;
initial begin
    forever begin
        @(posedge tdc_start);
        timeout_flag = 1'b0;
        
        fork
            // 超时检测分支
            begin
                #500;  // 500ns 超时
                if (!timeout_flag) begin
                    $display("WARNING @ %0t: No cs_gap detected after 500ns!", $time);
                end
            end
            
            // cs_gap 检测分支
            begin
                @(posedge cs_gap);
                timeout_flag = 1'b1;
            end
        // join_any
        
        disable fork;  // 杀死未完成的分支
    end
end

//------------------------------------------------------------------------------
// 实时监控
//------------------------------------------------------------------------------
always @(posedge cs_gap) begin
    $display("[MEASURE @ %8.3f ns] Value=%3d, Coarse=%6d, VIO_tap=%2d", 
             $realtime/1000.0, value_gap, coarse_counter, vio_data);
end

// // 监控 IDELAYCTRL 就绪状态
// initial begin
//     wait(reset == 1'b0);
//     #100;
//     if ($test$plusargs("verbose")) begin
//         $display("Monitoring IDELAYCTRL ready status...");
//         // 这里可以添加更多调试信息
//     end
// end

endmodule