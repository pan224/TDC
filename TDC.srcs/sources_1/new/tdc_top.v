module tdc_top#(
	parameter STAGE 					 = 512,
	parameter GAP_BITS 					 = 9
)(
	input wire 							sg_start_delayed,  // 延迟后的 start 信号
	input wire 							clk_bufg,          // 时钟信号400MHZ
	input wire 							reset_delayed,     // 延迟后的 reset 信号
	output wire                         cs_gap,
	output wire [GAP_BITS-1:0]			value_gap,
	output wire [22:0]                  coarse_counter		
);

(* ASYNC_REG = "TRUE" *)wire valid_pre1;
(* ASYNC_REG = "TRUE" *)wire valid_pre2;
(* ASYNC_REG = "TRUE" *)wire valid_for_bubble_fix;
(* ASYNC_REG = "TRUE" *)wire valid_for_latch2bin;

// 将延迟后的信号送入触发器和延迟链
FDCE #(
	.INIT(1'b0)
) 
FDCE_INST2 (
	.Q(valid_pre1),
	.C(clk_bufg),
	.CE(1'b1),
	.CLR(1'b0),
	.D(sg_start_delayed)
);

FDCE #(
	.INIT(1'b0)
) 
FDCE_INST3 (
	.Q(valid_pre2),
	.C(clk_bufg),
	.CE(1'b1),
	.CLR(1'b0),
	.D(valid_pre1)
);

FDCE #(
    .INIT(1'b0)
) 
FDCE_INST4 (
    .Q(valid_for_bubble_fix),
    .C(clk_bufg),
    .CE(1'b1),
    .CLR(1'b0),
    .D(valid_pre2)
);

FDCE #(
    .INIT(1'b0)
) 
FDCE_INST5 (
    .Q(valid_for_latch2bin),
    .C(clk_bufg),
    .CE(1'b1),
    .CLR(1'b0),
    .D(valid_for_bubble_fix)
);

(* dont_touch="true" *)wire [STAGE-1:0] value_latch_raw;
(* dont_touch="true" *)wire [STAGE-1:0] value_latch_fixed;

(* keep_hierarchy = "soft" *) line_tdc#(
    .STAGE(STAGE)
) line_tdc_inst(
    .sg_start(sg_start_delayed),
    .clk_bufg(clk_bufg),
    .reset(reset_delayed),
    .value_latch(value_latch_raw)
);

bubble_fix #(
    .STAGE(STAGE)
) bubble_fix_inst1 (
    .clk_bufg(clk_bufg),
    .reset(reset_delayed),
    .valid(valid_for_bubble_fix),
    .in_code(value_latch_raw),
    .out_code(value_latch_fixed)
);

latch2bin #(
    .GAP_BITS(GAP_BITS)
) latch2bin_inst1 (
    .clk_bufg(clk_bufg),
    .reset(reset_delayed),
    .valid(valid_for_latch2bin),
    .value_latch(value_latch_fixed),
    .bin_cs(cs_gap),
    .bin(value_gap)
);

// reset 同步打拍
(* ASYNC_REG = "TRUE" *)reg reset_sync0;
(* ASYNC_REG = "TRUE" *)reg reset_sync1;
always @(posedge clk_bufg) begin
    reset_sync0 <= reset_delayed;
    reset_sync1 <= reset_sync0;
end

// 粗计数器使用同步后的 reset
(* dont_touch="true" *)reg [22:0] counter_for_coarse;
always @(posedge clk_bufg) begin
    if (reset_sync1) begin
        counter_for_coarse <= 23'b0;
    end else begin
        counter_for_coarse <= counter_for_coarse + 1;
    end
end

(* dont_touch="true" *)reg [22:0] realtime_for_coarse;
reg [1:0] judge_start;

always @(posedge clk_bufg) begin
    if (reset_sync1) begin
        judge_start <= 2'b00;
        realtime_for_coarse <= 23'b0;
    end else begin
        judge_start <= {judge_start[0], valid_for_bubble_fix};
        
        if(judge_start == 2'b01) begin
            realtime_for_coarse <= counter_for_coarse;
        end
    end
end

assign coarse_counter = realtime_for_coarse;

endmodule