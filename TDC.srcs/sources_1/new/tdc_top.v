module tdc_top#(
	parameter STAGE 					 = 512,
	parameter GAP_BITS 					 = 9
)(
	input wire 							sg_start,
	input wire 							clk_sys,
	input wire 							reset    ,
	output wire                         cs_gap,
	output wire [GAP_BITS-1:0]			value_gap		
);

wire clk_bufg;

clk_wiz_0 clk_wiz_0_inst(
	.clk_out1(clk_bufg),
	.clk_in1(clk_sys)
);

wire valid_pre1;
wire valid_pre2;
wire valid_for_bubble_fix;//给气泡修复滤波模块用
wire valid_for_latch2bin;//给latch2bin模块使用
wire valid_for_bubble_fix_dly;//给气泡修复滤波模块使用的延时信号
wire valid_for_latch2bin_dly;//给latch2bin模块使用的延时信号
assign valid_for_bubble_fix_dly = valid_for_latch2bin;
// wire valid1;
// wire valid2;
// wire [STAGE-1:0]					value_latch;

wire bin_cs;
wire [GAP_BITS-1:0] bin;

wire sg_bufr;

BUFR #(
    .BUFR_DIVIDE("BYPASS"),   // Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8" 
    .SIM_DEVICE("7SERIES")  // Must be set to "7SERIES" 
 )
BUFR_INST (
    .O(sg_bufr),        // 1-bit output: Clock output port
    .CE(1'b1),          // 1-bit input: Active high, clock enable (Divided modes only)
    .CLR(1'b0),         // 1-bit input: Active high, asynchronous clear (Divided modes only)
    .I(sg_start)        // 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);

FDCE #(
	.INIT(1'b0) // Initial value of register (1'b0 or 1'b1)
) 
FDCE_INST2 (
	.Q(valid_pre1),      // 1-bit Data output
	.C(clk_bufg),      	// 1-bit Clock input
	.CE(1'b1),    		// 1-bit Clock enable input
	.CLR(1'b0),  		// 1-bit Asynchronous clear input
	.D(sg_bufr)       	// 1-bit Data input
);

FDCE #(
	.INIT(1'b0) // Initial value of register (1'b0 or 1'b1)
) 
FDCE_INST3 (
	.Q(valid_pre2),      // 1-bit Data output
	.C(clk_bufg),      // 1-bit Clock input
	.CE(1'b1),    // 1-bit Clock enable input
	.CLR(1'b0),  // 1-bit Asynchronous clear input
	.D(valid_pre1)       // 1-bit Data input
);

FDCE #(
	.INIT(1'b0) // Initial value of register (1'b0 or 1'b1)
) 
FDCE_INST4 (
	.Q(valid_for_bubble_fix),      // 1-bit Data output
	.C(clk_bufg),      // 1-bit Clock input
	.CE(1'b1),    // 1-bit Clock enable input
	.CLR(1'b0),  // 1-bit Asynchronous clear input
	.D(valid_pre2)       // 1-bit Data input
);

FDCE #(
	.INIT(1'b0) // Initial value of register (1'b0 or 1'b1)
) 
FDCE_INST5 (
	.Q(valid_for_latch2bin),      // 1-bit Data output
	.C(clk_bufg),      // 1-bit Clock input
	.CE(1'b1),    // 1-bit Clock enable input
	.CLR(1'b0),  // 1-bit Asynchronous clear input
	.D(valid_for_bubble_fix)       // 1-bit Data input
);

FDCE #(
	.INIT(1'b0) // Initial value of register (1'b0 or 1'b1)
) 
FDCE_INST6 (
	.Q(valid_for_latch2bin_dly),      // 1-bit Data output
	.C(clk_bufg),      // 1-bit Clock input
	.CE(1'b1),    // 1-bit Clock enable input
	.CLR(1'b0),  // 1-bit Asynchronous clear input
	.D(valid_for_latch2bin)       // 1-bit Data input
);

(* dont_touch="true" *)wire [STAGE-1:0] value_latch_raw;
(* dont_touch="true" *)wire [STAGE-1:0] value_latch_fixed;
(* dont_touch="true" *)wire [STAGE-1:0] value_latch_fixed_dly;

line_tdc#(
	.STAGE								(STAGE)

) line_tdc_inst(
	.sg_start 							(sg_bufr),
	.clk_bufg 							(clk_bufg),
	.reset 								(reset),
	.value_latch 						(value_latch_raw)
);

bubble_fix #(
	.STAGE(STAGE)
) bubble_fix_inst1 (
    .clk_bufg (clk_bufg),
    .reset    (reset),
    .valid    (valid_for_bubble_fix),
    .in_code  (value_latch_raw),
    .out_code (value_latch_fixed)
);

bubble_fix #(
	.STAGE(STAGE)
) bubble_fix_inst2 (
    .clk_bufg (clk_bufg),
    .reset    (reset),
    .valid    (valid_for_bubble_fix_dly),
    .in_code  (value_latch_raw),
    .out_code (value_latch_fixed_dly)
);

// latch2bin#(
// 	.GAP_BITS						    (GAP_BITS)
// ) latch2bin_inst(
// 	.clk_bufg 							(clk_bufg),
// 	.reset 								(reset),
// 	.valid 								(valid),
// 	.value_latch 						(value_latch_fixed),
// 	.bin_cs                             (cs_gap),
// 	.bin                                (value_gap)
// );



decode#(
	.GAP_BITS						    (GAP_BITS)
) decode_inst(
	.clk_bufg 							(clk_bufg),
	.reset 								(reset),
	.valid 								(valid_for_latch2bin),
	.valid_dly                          (valid_for_latch2bin_dly),
	.value_latch 						(value_latch_fixed),
	.value_latch_dly                    (value_latch_fixed_dly),
	.bin_cs                             (cs_gap),
	.bin                                (value_gap)
);
endmodule