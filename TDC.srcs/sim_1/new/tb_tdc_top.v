`timescale 1ns / 1ps

module tb_tdc_top;
reg  reset;
reg  clk_sys;
reg  sg_start;
wire sg_bufr_raw;
wire valid_pre1;
wire valid_pre2;
wire valid_for_bubble_fix;//给气泡修复滤波模块用
wire valid_for_latch2bin;//给latch2bin模块使用
wire valid_for_bubble_fix_dly;//给气泡修复滤波模块使用的延时信号
wire valid_for_latch2bin_dly;//给latch2bin模块使用的延时信号
// wire valid1;
// wire valid2;
wire clk_bufg;
wire [511:0] data_reg0;
wire [511:0] data_reg1;
// wire [511:0] value_latch;
wire [511:0] value_latch_raw;
wire [510:0] value_latch_fixed;
wire [510:0] value_latch_fixed_dly;
wire FDRE_REF;
wire bin_cs1;
wire bin_cs2;
wire [8:0] bin1_reg;
wire [8:0] bin2_reg;
wire [8:0] value_gap;
wire cs_gap;
wire [31:0] realtime_for_coarse;


integer csv_fd;
real     delta_ps;
reg [8:0] value_sample;
reg [8:0] bin1_sample;
reg [8:0] bin2_sample;
reg [31:0] realtime_sample;
realtime last_clk_edge_time;
realtime start_time;
realtime next_clk_time;



tdc_top tdc_top_inst(
    .sg_start  (sg_start),
    .clk_sys   (clk_sys),
    .reset     (reset),
    .cs_gap    (cs_gap),
    .value_gap (value_gap)
);


assign data_reg0 = tdc_top_inst.line_tdc_inst.dat_reg0;
assign data_reg1 = tdc_top_inst.line_tdc_inst.dat_reg1;
assign FDRE_REF = tdc_top_inst.line_tdc_inst.FDCE_INST3.Q;
assign sg_bufr_raw = tdc_top_inst.sg_bufr_raw;
assign valid_pre1 = tdc_top_inst.valid_pre1;
assign valid_pre2 = tdc_top_inst.valid_pre2;
assign valid_for_bubble_fix = tdc_top_inst.valid_for_bubble_fix;
assign valid_for_latch2bin = tdc_top_inst.valid_for_latch2bin;
assign valid_for_bubble_fix_dly = valid_for_latch2bin;
assign valid_for_latch2bin_dly = tdc_top_inst.valid_for_latch2bin_dly;
assign clk_bufg = tdc_top_inst.clk_bufg;


assign value_latch_raw = tdc_top_inst.value_latch_raw;
assign value_latch_fixed = tdc_top_inst.value_latch_fixed;
assign value_latch_fixed_dly = tdc_top_inst.value_latch_fixed_dly;
assign bin_cs1 = tdc_top_inst.decode_inst.bin_cs1;
assign bin_cs2 = tdc_top_inst.decode_inst.bin_cs2;
assign bin1_reg = tdc_top_inst.decode_inst.bin1_reg;
assign bin2_reg = tdc_top_inst.decode_inst.bin2_reg;
assign realtime_for_coarse = tdc_top_inst.realtime_for_coarse;

initial begin
    clk_sys = 1'b0;
    forever #5 clk_sys = ~clk_sys; // 100MHz
end

initial begin
    reset    = 1'b1;
    sg_start = 1'b0;
    #200;
    reset = 1'b0;
    #1000; // 时间推进至 1200ns
    forever begin
        reset = 1'b1;
        #10;
        reset = 1'b0;
        #30;
        sg_start = 1'b1;
        #10;
        sg_start = 1'b0;
        #70.01;
    end
end


initial begin
    csv_fd = $fopen("tdc_capture.csv", "w");
    if (csv_fd == 0) begin
        $display("ERROR: Failed to open CSV file.");
        $finish;
    end
    $fwrite(csv_fd, "start_to_clk_ps,value_gap_at_cs_gap,bin1_reg,bin2_reg,realtime_coarse\n");
    // $fwrite(csv_fd, "start_to_clk_ps,value_gap_at_cs_gap\n");
    last_clk_edge_time = 0.0;
end

always @(posedge clk_bufg) begin
    last_clk_edge_time = $realtime;
end

always begin
    @(posedge sg_start);
    start_time = $realtime;
    #0; // allow concurrent clock edge updates
    if (last_clk_edge_time == start_time) begin
        next_clk_time = start_time;
    end
    else begin
        @(posedge clk_bufg);
        next_clk_time = $realtime;
    end
    delta_ps = (next_clk_time - start_time) * 1000.0;
    if (cs_gap) @(negedge cs_gap);//检查 cs_gap 是否为高，若是就等到下降沿，再阻塞到下一次上升沿时抓取
    @(posedge cs_gap);
    value_sample = value_gap;
    bin1_sample = bin1_reg;
    bin2_sample = bin2_reg;
    realtime_sample = realtime_for_coarse;
    $fwrite(csv_fd, "%0.0f,%0d,%0d,%0d,%0d\n", delta_ps, value_sample, bin1_sample, bin2_sample, realtime_sample);
    // $fwrite(csv_fd, "%0.0f,%0d\n", delta_ps, value_sample);
end

initial begin
    // #176300;//70.001*2500+1200
    #31200;//120.01*250+1200
    if (csv_fd) begin
        $fclose(csv_fd);
    end
    $finish;
end

endmodule
