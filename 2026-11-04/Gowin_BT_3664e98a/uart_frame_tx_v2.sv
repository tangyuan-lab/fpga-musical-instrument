`default_nettype none
// V2 ACK/NACK：55 AA、版本1、类型、序号LE、长度LE、payload、CRC16-CCITT LE。
// payload前两字节为原消息类型/状态。一次锁存后逐字节移出并更新CRC，
// 避免对96字节帧缓存做两套可变索引读取。busy期间完整响应保持独立。
module uart_frame_tx_v2 #(
    parameter integer CLKS_PER_BIT=434,MAX_RESPONSE=96
)(
    input wire clk,rst_n,response_valid,input wire [7:0] response_type,
    input wire [15:0] response_seq,input wire [7:0] response_length,
    input wire [MAX_RESPONSE*8-1:0] response_payload,
    output wire tx,output reg busy
);
    reg [7:0] type_reg,length_reg,byte_index;
    reg [15:0] seq_reg,crc;
    reg [MAX_RESPONSE*8-1:0] payload_reg;
    reg start,byte_pending;reg [7:0] tx_data;
    wire uart_busy,uart_done;
    function automatic [15:0] crc_next(input [15:0] prior,input [7:0] value);
        reg [15:0] work;integer bit_index;
        begin
            work=prior^{value,8'd0};
            for(bit_index=0;bit_index<8;bit_index=bit_index+1)
                work=work[15] ? (work<<1)^16'h1021:work<<1;
            crc_next=work;
        end
    endfunction
    always @(*) begin
        case(byte_index)
            0:tx_data=8'h55;1:tx_data=8'haa;2:tx_data=1;3:tx_data=type_reg;
            4:tx_data=seq_reg[7:0];5:tx_data=seq_reg[15:8];6:tx_data=length_reg;7:tx_data=0;
            default:tx_data=byte_index<8+length_reg ? payload_reg[7:0]:byte_index==8+length_reg ? crc[7:0]:crc[15:8];
        endcase
    end
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst(.clk(clk),.rst_n(rst_n),.start(start),.data(tx_data),.tx(tx),.busy(uart_busy),.done(uart_done));
    // payload仅在有效响应到达时初始化；空闲输出由busy屏蔽，不给宽数据寄存器施加复位。
    always @(posedge clk) begin
        if(response_valid && !busy && response_length<=MAX_RESPONSE) payload_reg<=response_payload;
        else if(busy && uart_done && byte_index>=8 && byte_index<8+length_reg) payload_reg<=payload_reg>>8;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin type_reg<=0;length_reg<=0;seq_reg<=0;byte_index<=0;crc<=16'hffff;start<=0;byte_pending<=0;busy<=0;end
        else begin
            start<=0;
            if(response_valid && !busy && response_length<=MAX_RESPONSE) begin
                type_reg<=response_type;length_reg<=response_length;seq_reg<=response_seq;
                byte_index<=0;crc<=16'hffff;byte_pending<=0;busy<=1;
            end else if(busy) begin
                if(!uart_busy && !byte_pending) begin
                    start<=1;byte_pending<=1;
                    if(byte_index>=2 && byte_index<8+length_reg) crc<=crc_next(crc,tx_data);
                end
                if(uart_done) begin
                    byte_pending<=0;
                    if(byte_index==9+length_reg) busy<=0;
                    else byte_index<=byte_index+1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
