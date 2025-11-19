`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: eth_comm_ctrl
// Description: 以太网通信控制模块，管理接收和发送逻辑
//////////////////////////////////////////////////////////////////////////////////

module eth_comm_ctrl #(
    parameter GAP_BITS = 9
)(
    input wire                      clk_100MHz,
    input wire                      reset,
    
    // TDC 数据输入
    input wire                      cs_gap,
    input wire [GAP_BITS-1:0]       value_gap,
    input wire [22:0]               coarse_counter,
    
    // 以太网 FIFO 接口
    input wire                      gig_eth_rx_fifo_empty,
    input wire [31:0]               gig_eth_rx_fifo_q,
    output wire                     gig_eth_rx_fifo_rden,
    
    input wire                      gig_eth_tx_fifo_full,
    output wire [31:0]              gig_eth_tx_fifo_q,
    output wire                     gig_eth_tx_fifo_wren,
    
    // IDELAYE2 控制信号输出
    output reg [4:0]                sg_delay_value,
    output reg                      sg_delay_load,
    output reg [4:0]                rst_delay_value,
    output reg                      rst_delay_load
);

//------------------------------------------------------------------------------
// 发送逻辑 - 跨时钟域同步
//发送数据格式：{coarse_counter[22:0],value_gap_reg[GAP_BITS-1:0]} -粗计数+细计数
//------------------------------------------------------------------------------
(* ASYNC_REG = "TRUE" *) reg cs_gap_sync1;
(* ASYNC_REG = "TRUE" *) reg cs_gap_sync2;
reg cs_gap_sync3;

always @(posedge clk_100MHz) begin
    if(reset) begin
        cs_gap_sync1 <= 1'b0;
        cs_gap_sync2 <= 1'b0;
        cs_gap_sync3 <= 1'b0;
    end
    else begin
        cs_gap_sync1 <= cs_gap;
        cs_gap_sync2 <= cs_gap_sync1;
        cs_gap_sync3 <= cs_gap_sync2;
    end
end

wire cs_gap_posedge;
assign cs_gap_posedge = cs_gap_sync2 & (~cs_gap_sync3);

// 锁存数据
reg [GAP_BITS-1:0] value_gap_latch;
reg [22:0] coarse_counter_latch;

always @(posedge cs_gap) begin
    value_gap_latch <= value_gap;
    coarse_counter_latch <= coarse_counter;
end

// 发送状态机
reg tx_state;
localparam TX_IDLE = 1'b0;
localparam TX_SEND = 1'b1;

reg gig_eth_tx_fifo_wren_reg;
reg [31:0] tx_data_buffer;

assign gig_eth_tx_fifo_wren = gig_eth_tx_fifo_wren_reg;
assign gig_eth_tx_fifo_q = tx_data_buffer;

always @(posedge clk_100MHz) begin
    if(reset) begin
        tx_state <= TX_IDLE;
        gig_eth_tx_fifo_wren_reg <= 1'b0;
        tx_data_buffer <= 32'd0;
    end
    else begin
        case(tx_state)
            TX_IDLE: begin
                gig_eth_tx_fifo_wren_reg <= 1'b0;
                
                if(cs_gap_posedge) begin
                    tx_data_buffer <= {coarse_counter_latch, value_gap_latch};
                    tx_state <= TX_SEND;
                end
            end
            
            TX_SEND: begin
                if(~gig_eth_tx_fifo_full) begin
                    gig_eth_tx_fifo_wren_reg <= 1'b1;
                    tx_state <= TX_IDLE;
                end
                else begin
                    gig_eth_tx_fifo_wren_reg <= 1'b0;
                end
            end
            
            default: begin
                tx_state <= TX_IDLE;
            end
        endcase
    end
end

//------------------------------------------------------------------------------
// 接收逻辑 - 解析上位机命令
// 数据格式：
// {2'b10, 25'b0, sg_delay_value[4:0]}  - 配置 sg_start 延迟
// {2'b01, 25'b0, rst_delay_value[4:0]} - 配置 reset 延迟
//------------------------------------------------------------------------------
reg [2:0] rx_state;
reg [31:0] rx_data_buffer;
reg rx_fifo_rden_reg;

localparam RX_IDLE       = 3'd0;
localparam RX_READ       = 3'd1;
localparam RX_DECODE     = 3'd2;
localparam RX_LOAD_SG    = 3'd3;
localparam RX_LOAD_RST   = 3'd4;
localparam RX_WAIT       = 3'd5;

assign gig_eth_rx_fifo_rden = rx_fifo_rden_reg;

always @(posedge clk_100MHz) begin
    if(reset) begin
        rx_state <= RX_IDLE;
        rx_data_buffer <= 32'd0;
        rx_fifo_rden_reg <= 1'b0;
        sg_delay_value <= 5'd0;
        sg_delay_load <= 1'b0;
        rst_delay_value <= 5'd0;
        rst_delay_load <= 1'b0;
    end
    else begin
        case(rx_state)
            RX_IDLE: begin
                sg_delay_load <= 1'b0;
                rst_delay_load <= 1'b0;
                rx_fifo_rden_reg <= 1'b0;
                
                if(~gig_eth_rx_fifo_empty) begin
                    rx_state <= RX_READ;
                    rx_fifo_rden_reg <= 1'b1;
                end
            end
            
            RX_READ: begin
                rx_fifo_rden_reg <= 1'b0;
                rx_data_buffer <= gig_eth_rx_fifo_q;
                rx_state <= RX_DECODE;
            end
            
            RX_DECODE: begin
                case(rx_data_buffer[31:30])
                    2'b10: begin
                        sg_delay_value <= rx_data_buffer[4:0];
                        rx_state <= RX_LOAD_SG;
                    end
                    
                    2'b01: begin
                        rst_delay_value <= rx_data_buffer[4:0];
                        rx_state <= RX_LOAD_RST;
                    end
                    
                    default: begin
                        rx_state <= RX_IDLE;
                    end
                endcase
            end
            
            RX_LOAD_SG: begin
                sg_delay_load <= 1'b1;
                rx_state <= RX_WAIT;
            end
            
            RX_LOAD_RST: begin
                rst_delay_load <= 1'b1;
                rx_state <= RX_WAIT;
            end
            
            RX_WAIT: begin
                sg_delay_load <= 1'b0;
                rst_delay_load <= 1'b0;
                rx_state <= RX_IDLE;
            end
            
            default: begin
                rx_state <= RX_IDLE;
            end
        endcase
    end
end

endmodule