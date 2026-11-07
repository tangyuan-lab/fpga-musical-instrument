`default_nettype none
module uart_frame_tx_v2 #(
    parameter integer CLKS_PER_BIT=434,MAX_RESPONSE=96
)(
    input wire clk,rst_n,response_valid,input wire [7:0] response_type,
    input wire [15:0] response_seq,input wire [7:0] response_length,
    input wire [MAX_RESPONSE*8-1:0] response_payload,
    output wire tx,output wire busy
);
    wire byte_start,uart_busy,uart_done;wire [7:0] byte_data;
    binary_frame_tx #(.MAX_RESPONSE(MAX_RESPONSE)) protocol(
        .clk(clk),.rst_n(rst_n),.response_valid(response_valid),.response_type(response_type),
        .response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),
        .byte_start(byte_start),.byte_data(byte_data),.uart_busy(uart_busy),.uart_done(uart_done),.busy(busy));
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst(.clk(clk),.rst_n(rst_n),.start(byte_start),
        .data(byte_data),.tx(tx),.busy(uart_busy),.done(uart_done));
endmodule
`default_nettype wire
