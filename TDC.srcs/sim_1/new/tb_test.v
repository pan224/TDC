`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for test module - Focus on ETH transmission and cs_gap signals
//////////////////////////////////////////////////////////////////////////////////

module tb_test_eth_transmission;

//------------------------------------------------------------------------------
// 参数定义
//------------------------------------------------------------------------------
parameter CLK_PERIOD_200M = 5.0;    // 200MHz = 5ns
parameter PHASE_VALUE = 8'd50;       // 50 * 17.86ps ≈ 893ps

//------------------------------------------------------------------------------
// 信号声明
//------------------------------------------------------------------------------
// 系统时钟和复位
reg CPU_RESET;
reg SYS_CLK_P;
reg SYS_CLK_N;

// 以太网接口 (简化，只声明必要的)
wire PHY_RESET_N;
wire [3:0] RGMII_TXD;
wire RGMII_TX_CTL;
wire RGMII_TXC;
reg [3:0] RGMII_RXD;
reg RGMII_RX_CTL;
reg RGMII_RXC;
wire MDIO;
wire MDC;

// 内部探测信号 (通过层次化访问)
wire clk_100MHz;
wire clk_bufg;
wire cs_gap;
wire [8:0] value_gap;
wire [22:0] coarse_counter;
wire gig_eth_tx_fifo_wren;
wire [31:0] gig_eth_tx_fifo_q;
wire gig_eth_tx_fifo_full;
wire cs_gap_sync1, cs_gap_sync2, cs_gap_sync3;
wire cs_gap_posedge;

//------------------------------------------------------------------------------
// DUT 实例化
//------------------------------------------------------------------------------
test dut (
    .CPU_RESET(CPU_RESET),
    .SYS_CLK_P(SYS_CLK_P),
    .SYS_CLK_N(SYS_CLK_N),
    .PHY_RESET_N(PHY_RESET_N),
    .RGMII_TXD(RGMII_TXD),
    .RGMII_TX_CTL(RGMII_TX_CTL),
    .RGMII_TXC(RGMII_TXC),
    .RGMII_RXD(RGMII_RXD),
    .RGMII_RX_CTL(RGMII_RX_CTL),
    .RGMII_RXC(RGMII_RXC),
    .MDIO(MDIO),
    .MDC(MDC)
);

//------------------------------------------------------------------------------
// 层次化信号访问
//------------------------------------------------------------------------------
assign clk_100MHz = dut.clk_100MHz;
assign clk_bufg = dut.clk_bufg;
assign cs_gap = dut.cs_gap;
assign value_gap = dut.value_gap;
assign coarse_counter = dut.coarse_counter;

// 以太网发送 FIFO 信号
assign gig_eth_tx_fifo_wren = dut.gig_eth_tx_fifo_wren;
assign gig_eth_tx_fifo_q = dut.gig_eth_tx_fifo_q;
assign gig_eth_tx_fifo_full = dut.gig_eth_tx_fifo_full;

// 跨时钟域同步信号
assign cs_gap_sync1 = dut.eth_comm_ctrl_inst.cs_gap_sync1;
assign cs_gap_sync2 = dut.eth_comm_ctrl_inst.cs_gap_sync2;
assign cs_gap_sync3 = dut.eth_comm_ctrl_inst.cs_gap_sync3;
assign cs_gap_posedge = dut.eth_comm_ctrl_inst.cs_gap_posedge;

//------------------------------------------------------------------------------
// VIO 信号模拟
//------------------------------------------------------------------------------
reg [7:0] vio_phase;
reg vio_valid;
reg vio_reset;

// 将模拟的 VIO 信号连接到 DUT
initial begin
    force dut.vio_data = vio_phase;
    force dut.vio_valid = vio_valid;
    force dut.tdc_test_ctrl_inst.vio_reset_in = vio_reset;
end

//------------------------------------------------------------------------------
// 差分时钟生成 - 200MHz
//------------------------------------------------------------------------------
initial begin
    SYS_CLK_P = 0;
    SYS_CLK_N = 1;
    forever begin
        #(CLK_PERIOD_200M/2) SYS_CLK_P = ~SYS_CLK_P;
        SYS_CLK_N = ~SYS_CLK_P;
    end
end

//------------------------------------------------------------------------------
// RGMII 接收时钟 - 125MHz (简化，不接收数据)
//------------------------------------------------------------------------------
initial begin
    RGMII_RXC = 0;
    forever #4 RGMII_RXC = ~RGMII_RXC;
end

initial begin
    RGMII_RXD = 4'b0;
    RGMII_RX_CTL = 1'b0;
end

//------------------------------------------------------------------------------
// 测试激励
//------------------------------------------------------------------------------
initial begin
    // 初始化
    CPU_RESET = 1'b0;  // 低电平复位
    vio_reset = 1'b1;
    vio_phase = 8'd0;
    vio_valid = 1'b0;
    
    $display("=== Simulation Start ===");
    $display("Time: %0t ns", $time);
    
    // 复位
    #100;
    CPU_RESET = 1'b1;  // 释放复位
    #50;
    vio_reset = 1'b0;
    
    // 等待时钟稳定和 MMCM 锁定
    $display("Waiting for clocks to stabilize...");
    wait(dut.clk_bufg !== 1'bx);
    repeat(100) @(posedge clk_100MHz);
    
    $display("\n=== Test 1: Single TDC Measurement (Phase = 50) ===");
    $display("Target delay: 50 * 17.86ps = 893ps");
    
    // 设置相位值为 50
    vio_phase = PHASE_VALUE;
    #20;
    
    // 触发测量
    @(posedge dut.clk_sys);
    vio_valid = 1'b1;
    $display("Time: %0t ns - VIO triggered, phase = %0d", $time, vio_phase);
    
    // 保持 valid 高电平一段时间
    repeat(10) @(posedge dut.clk_sys);
    vio_valid = 1'b0;
    
    // 等待 TDC 测量完成
    wait(cs_gap == 1'b1);
    $display("\nTime: %0t ns - cs_gap asserted!", $time);
    $display("  TDC Results:");
    $display("    value_gap = %0d", value_gap);
    $display("    coarse_counter = %0d", coarse_counter);
    
    // 等待信号跨时钟域同步
    @(posedge clk_100MHz);
    repeat(5) @(posedge clk_100MHz);
    
    $display("\nTime: %0t ns - Cross-domain synchronization:", $time);
    $display("    cs_gap_sync1 = %b", cs_gap_sync1);
    $display("    cs_gap_sync2 = %b", cs_gap_sync2);
    $display("    cs_gap_sync3 = %b", cs_gap_sync3);
    
    // 等待边沿检测
    wait(cs_gap_posedge == 1'b1);
    $display("\nTime: %0t ns - cs_gap_posedge detected!", $time);
    
    // 观察 TX FIFO 写入
    @(posedge clk_100MHz);
    if(gig_eth_tx_fifo_wren) begin
        $display("\nTime: %0t ns - TX FIFO Write:", $time);
        $display("    wren = %b", gig_eth_tx_fifo_wren);
        $display("    data = 0x%08h", gig_eth_tx_fifo_q);
        $display("    data breakdown:");
        $display("      coarse_counter[22:0] = %0d (0x%06h)", 
                 gig_eth_tx_fifo_q[31:9], gig_eth_tx_fifo_q[31:9]);
        $display("      value_gap[8:0] = %0d (0x%03h)", 
                 gig_eth_tx_fifo_q[8:0], gig_eth_tx_fifo_q[8:0]);
    end
    
    // 等待发送完成
    repeat(10) @(posedge clk_100MHz);
    
    $display("\n=== Test 2: Multiple Measurements ===");
    
    // 第二次测量
    repeat(100) @(posedge dut.clk_sys);
    vio_phase = PHASE_VALUE;
    @(posedge dut.clk_sys);
    vio_valid = 1'b1;
    $display("\nTime: %0t ns - Second measurement triggered", $time);
    repeat(10) @(posedge dut.clk_sys);
    vio_valid = 1'b0;
    
    wait(cs_gap_posedge == 1'b1);
    @(posedge clk_100MHz);
    if(gig_eth_tx_fifo_wren) begin
        $display("\nTime: %0t ns - Second TX FIFO Write:", $time);
        $display("    data = 0x%08h", gig_eth_tx_fifo_q);
    end
    
    // 第三次测量
    repeat(100) @(posedge dut.clk_sys);
    vio_phase = PHASE_VALUE;
    @(posedge dut.clk_sys);
    vio_valid = 1'b1;
    $display("\nTime: %0t ns - Third measurement triggered", $time);
    repeat(10) @(posedge dut.clk_sys);
    vio_valid = 1'b0;
    
    wait(cs_gap_posedge == 1'b1);
    @(posedge clk_100MHz);
    if(gig_eth_tx_fifo_wren) begin
        $display("\nTime: %0t ns - Third TX FIFO Write:", $time);
        $display("    data = 0x%08h", gig_eth_tx_fifo_q);
    end
    
    // 结束仿真
    repeat(100) @(posedge clk_100MHz);
    
    $display("\n=== Simulation Summary ===");
    $display("Total simulation time: %0t ns", $time);
    $display("Phase setting: %0d (%.2f ps delay)", PHASE_VALUE, PHASE_VALUE * 17.86);
    $display("=== Simulation End ===");
    
    $finish;
end

//------------------------------------------------------------------------------
// 监控关键信号变化
//------------------------------------------------------------------------------
// 监控 cs_gap 信号
always @(posedge cs_gap) begin
    $display(">>> [%0t ns] cs_gap rising edge", $time);
end

always @(negedge cs_gap) begin
    $display(">>> [%0t ns] cs_gap falling edge", $time);
end

// 监控 TX FIFO 写入
always @(posedge clk_100MHz) begin
    if(gig_eth_tx_fifo_wren) begin
        $display(">>> [%0t ns] TX FIFO Write: 0x%08h", $time, gig_eth_tx_fifo_q);
    end
end

// 监控跨时钟域同步
always @(posedge clk_100MHz) begin
    if(cs_gap_posedge) begin
        $display(">>> [%0t ns] cs_gap_posedge detected in 100MHz domain", $time);
    end
end

//------------------------------------------------------------------------------
// 超时保护
//------------------------------------------------------------------------------
initial begin
    #50000;  // 50us 超时
    $display("\n!!! Simulation Timeout !!!");
    $finish;
end

//------------------------------------------------------------------------------
// 波形文件生成
//------------------------------------------------------------------------------
initial begin
    $dumpfile("tb_test_eth.vcd");
    $dumpvars(0, tb_test_eth_transmission);
    
    // 重点监控的信号
    $dumpvars(1, dut.clk_sys);
    $dumpvars(1, dut.clk_100MHz);
    $dumpvars(1, dut.clk_bufg);
    $dumpvars(1, dut.cs_gap);
    $dumpvars(1, dut.value_gap);
    $dumpvars(1, dut.coarse_counter);
    
    // 跨时钟域信号
    $dumpvars(1, cs_gap_sync1);
    $dumpvars(1, cs_gap_sync2);
    $dumpvars(1, cs_gap_sync3);
    $dumpvars(1, cs_gap_posedge);
    
    // 以太网发送信号
    $dumpvars(1, gig_eth_tx_fifo_wren);
    $dumpvars(1, gig_eth_tx_fifo_q);
    $dumpvars(1, gig_eth_tx_fifo_full);
    
    // VIO 模拟信号
    $dumpvars(1, vio_phase);
    $dumpvars(1, vio_valid);
end

//------------------------------------------------------------------------------
// 时钟频率检查
//------------------------------------------------------------------------------
real clk_100M_period;
time last_100M_edge;

initial begin
    last_100M_edge = 0;
    @(posedge clk_100MHz);
    forever begin
        @(posedge clk_100MHz);
        clk_100M_period = ($time - last_100M_edge);
        last_100M_edge = $time;
        
        // 检查时钟频率是否正确 (100MHz = 10ns)
        if(clk_100M_period > 10.5 || clk_100M_period < 9.5) begin
            $display("WARNING: clk_100MHz period = %0.2f ns (expected 10ns)", clk_100M_period);
        end
    end
end

endmodule