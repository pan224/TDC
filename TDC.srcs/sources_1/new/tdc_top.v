module tdc_top#(
    parameter STAGE 					 = 512,
    parameter GAP_BITS 					 = 9
)(
    input wire 							sg_start,
    input wire 							clk_sys,
    input wire 							reset,
    output wire                         cs_gap,
    output wire [GAP_BITS-1:0]			value_gap		
);

(* clock_buffer_type = "none" *) wire clk_bufg;

wire clk_ref200; // 由 clk_wiz_0 产生的 200MHz 参考时钟

clk_wiz_0 clk_wiz_0_inst(
    .clk_out1(clk_bufg),
    .clk_out2(clk_ref200),
    .clk_in1(clk_sys)
);

// IDELAYCTRL 原语,需要 200MHz 参考时钟
(* IODELAY_GROUP = "tdc_delay_group" *)
IDELAYCTRL IDELAYCTRL_inst (
    .RDY(),              // 1-bit output: Ready output
    .REFCLK(clk_ref200), // 1-bit input: Reference clock input (200MHz)
    .RST(1'b0)           // IDELAYCTRL 的 RST 不使用外部 reset
);

(* ASYNC_REG = "TRUE" *)wire valid_pre;
(* ASYNC_REG = "TRUE" *)wire valid_for_bubble_fix;
(* ASYNC_REG = "TRUE" *)wire valid_for_latch2bin;

wire sg_start_ibuf;
wire sg_bufr;
wire reset_ibuf;
wire reset_delayed;

// 添加 sg_start 的 IBUF
IBUF IBUF_sg_start (
    .O(sg_start_ibuf),
    .I(sg_start)
);

// 添加 reset 的 IBUF
IBUF IBUF_reset (
    .O(reset_ibuf),
    .I(reset)
);

// sg_start 的 IDELAYE2 延迟
(* IODELAY_GROUP = "tdc_delay_group" *)
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),
    .DELAY_SRC("IDATAIN"),
    .HIGH_PERFORMANCE_MODE("TRUE"),
    .IDELAY_TYPE("FIXED"),
    .IDELAY_VALUE(2),                // 600 + 4*78 = 912ps
    .PIPE_SEL("FALSE"),
    .REFCLK_FREQUENCY(200.0),
    .SIGNAL_PATTERN("DATA")
)
IDELAYE2_sg_start (
    .CNTVALUEOUT(),
    .DATAOUT(sg_bufr),
    .C(1'b0),
    .CE(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'b00000),
    .DATAIN(1'b0),
    .IDATAIN(sg_start_ibuf),
    .INC(1'b0),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

// reset 的 IDELAYE2 延迟
(* IODELAY_GROUP = "tdc_delay_group" *)
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),
    .DELAY_SRC("IDATAIN"),
    .HIGH_PERFORMANCE_MODE("TRUE"),
    .IDELAY_TYPE("FIXED"),
    .IDELAY_VALUE(21),                // 600 + 4*78 = 912ps
    .PIPE_SEL("FALSE"),
    .REFCLK_FREQUENCY(200.0),
    .SIGNAL_PATTERN("DATA")
)
IDELAYE2_reset (
    .CNTVALUEOUT(),
    .DATAOUT(reset_delayed),
    .C(1'b0),
    .CE(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'b00000),
    .DATAIN(1'b0),
    .IDATAIN(reset_ibuf),
    .INC(1'b0),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

// 将延迟后的信号送入触发器和延迟链
FDCE #(
    .INIT(1'b0)
) 
FDCE_INST2 (
    .Q(valid_pre),
    .C(clk_bufg),
    .CE(1'b1),
    .CLR(1'b0),
    .D(sg_bufr)
);

FDCE #(
    .INIT(1'b0)
) 
FDCE_INST4 (
    .Q(valid_for_bubble_fix),
    .C(clk_bufg),
    .CE(1'b1),
    .CLR(1'b0),
    .D(valid_pre)
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
    .sg_start(sg_bufr),
    .clk_bufg(clk_bufg),
    .reset(reset_delayed),           // 使用延迟后的 reset
    .value_latch(value_latch_raw)
);

bubble_fix #(
    .STAGE(STAGE)
) bubble_fix_inst1 (
    .clk_bufg(clk_bufg),
    .reset(reset_delayed),           // 使用延迟后的 reset
    .valid(valid_for_bubble_fix),
    .in_code(value_latch_raw),
    .out_code(value_latch_fixed)
);

latch2bin #(
    .GAP_BITS(GAP_BITS)
) latch2bin_inst1 (
    .clk_bufg(clk_bufg),
    .reset(reset_delayed),           // 使用延迟后的 reset
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
(* dont_touch="true" *)reg [31:0] counter_for_coarse;
always @(posedge clk_bufg) begin
    if (reset_sync1) begin
        counter_for_coarse <= 32'b0;
    end else begin
        counter_for_coarse <= counter_for_coarse + 1;
    end
end

(* dont_touch="true" *)reg [31:0] realtime_for_coarse;
reg [1:0] judge_start;

always @(posedge clk_bufg) begin
    if (reset_sync1) begin
        judge_start <= 2'b00;
        realtime_for_coarse <= 32'b0;
    end else begin
        judge_start <= {judge_start[0], valid_for_bubble_fix};
        
        if(judge_start == 2'b01) begin
            realtime_for_coarse <= counter_for_coarse;
        end
    end
end

endmodule