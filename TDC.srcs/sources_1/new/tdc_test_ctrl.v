`timescale 1ns / 1ps

module tdc_test_ctrl #(
    parameter DATA_WIDTH = 5
)(
    input wire                      clk_sys,      // 200MHz 时钟，用于 IDELAYE2 的 C 端口
    input wire                      reset_in,
    input wire [DATA_WIDTH-1:0]     vio_data,
    input wire                      vio_valid,
    output reg                      tdc_start,
    output reg                      tdc_reset
);

//------------------------------------------------------------------------------
// 删除 IDELAYCTRL - 使用 tdc_top 中的 IDELAYCTRL
//------------------------------------------------------------------------------
// 注释掉或删除以下代码：
// (* IODELAY_GROUP = "tdc_delay_group" *)
// IDELAYCTRL IDELAYCTRL_test_inst (
//     .RDY(),
//     .REFCLK(clk_ref200),
//     .RST(reset_in)
// );

//------------------------------------------------------------------------------
// 状态机定义（保持不变）
//------------------------------------------------------------------------------
localparam [3:0] IDLE           = 4'd0;
localparam [3:0] RESET_LOW      = 4'd1;
localparam [3:0] WAIT_DELAY     = 4'd2;
localparam [3:0] START_HIGH     = 4'd3;
localparam [3:0] START_WAIT     = 4'd4;
localparam [3:0] START_LOW      = 4'd5;
localparam [3:0] BEFORE_RESET   = 4'd6;
localparam [3:0] RESET_HIGH     = 4'd7;
localparam [3:0] DONE           = 4'd8;

reg [3:0] state;
reg [15:0] counter;
reg [DATA_WIDTH-1:0] delay_value;

// VIO valid 边沿检测
reg vio_valid_d1, vio_valid_d2;
wire vio_valid_posedge;

always @(posedge clk_sys) begin
    if(reset_in) begin
        vio_valid_d1 <= 1'b0;
        vio_valid_d2 <= 1'b0;
    end else begin
        vio_valid_d1 <= vio_valid;
        vio_valid_d2 <= vio_valid_d1;
    end
end

assign vio_valid_posedge = vio_valid_d1 & (~vio_valid_d2);

//------------------------------------------------------------------------------
// 延迟信号生成 - IDELAYE2 仍然属于 tdc_delay_group
//------------------------------------------------------------------------------
reg delay_trigger;
wire delay_trigger_delayed;
reg delay_load;

(* IODELAY_GROUP = "tdc_delay_group" *)  // 使用 tdc_top 的 IDELAYCTRL
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),
    .DELAY_SRC("DATAIN"),
    .HIGH_PERFORMANCE_MODE("TRUE"),
    .IDELAY_TYPE("VAR_LOAD"),
    .IDELAY_VALUE(0),
    .PIPE_SEL("FALSE"),
    .REFCLK_FREQUENCY(200.0),
    .SIGNAL_PATTERN("DATA")
)
IDELAYE2_delay_inst (
    .CNTVALUEOUT(),
    .DATAOUT(delay_trigger_delayed),
    .C(clk_sys),                    // 200MHz 时钟，用于 LD 信号同步
    .CE(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(delay_value),
    .DATAIN(delay_trigger),
    .IDATAIN(1'b0),
    .INC(1'b0),
    .LD(delay_load),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

// 延迟触发边沿检测
reg delay_trigger_delayed_d1;
wire delay_done;

always @(posedge clk_sys) begin
    if(reset_in) begin
        delay_trigger_delayed_d1 <= 1'b0;
    end else begin
        delay_trigger_delayed_d1 <= delay_trigger_delayed;
    end
end

assign delay_done = delay_trigger_delayed & (~delay_trigger_delayed_d1);

//------------------------------------------------------------------------------
// 主状态机（保持不变）
//------------------------------------------------------------------------------
always @(posedge clk_sys) begin
    if(reset_in) begin
        state <= IDLE;
        counter <= 16'd0;
        delay_value <= {DATA_WIDTH{1'b0}};
        delay_trigger <= 1'b0;
        delay_load <= 1'b0;
        tdc_start <= 1'b0;
        tdc_reset <= 1'b1;
    end
    else begin
        case(state)
            IDLE: begin
                tdc_start <= 1'b0;
                tdc_reset <= 1'b1;
                delay_trigger <= 1'b0;
                delay_load <= 1'b0;
                counter <= 16'd0;
                
                if(vio_valid_posedge) begin
                    delay_value <= vio_data;
                    delay_load <= 1'b1;
                    state <= RESET_LOW;
                end
            end
            
            RESET_LOW: begin
                delay_load <= 1'b0;
                tdc_reset <= 1'b0;
                counter <= counter + 1;
                
                if(counter >= 16'd2) begin
                    counter <= 16'd0;
                    delay_trigger <= 1'b1;
                    state <= WAIT_DELAY;
                end
            end
            
            WAIT_DELAY: begin
                if(delay_done) begin
                    delay_trigger <= 1'b0;
                    state <= START_HIGH;
                end
            end
            
            START_HIGH: begin
                tdc_start <= 1'b1;
                counter <= 16'd0;
                state <= START_WAIT;
            end
            
            START_WAIT: begin
                counter <= counter + 1;
                
                if(counter >= 16'd2) begin
                    counter <= 16'd0;
                    state <= START_LOW;
                end
            end
            
            START_LOW: begin
                tdc_start <= 1'b0;
                counter <= 16'd0;
                state <= BEFORE_RESET;
            end
            
            BEFORE_RESET: begin
                counter <= counter + 1;
                
                if(counter >= 16'd2) begin
                    counter <= 16'd0;
                    state <= RESET_HIGH;
                end
            end
            
            RESET_HIGH: begin
                tdc_reset <= 1'b1;
                state <= DONE;
            end
            
            DONE: begin
                if(~vio_valid) begin
                    state <= IDLE;
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule
