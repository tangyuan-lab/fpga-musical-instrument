`default_nettype none
// 独立蓝牙帧接收器。坏帧后等空闲，不在损坏数据内重新搜索55AA。
// 计数单位为clk周期；默认50 MHz，间隔250 ms，整帧2 s。
module r7_bt_frame_rx #(
    parameter integer MAX_PAYLOAD = 32,
    parameter integer GAP_CYCLES = 12_500_000,
    parameter integer FRAME_CYCLES = 100_000_000
)(
    input wire clk, rst_n,
    input wire [7:0] rx_data,
    input wire rx_valid, framing_error,
    output reg frame_valid, bad_frame,
    output reg [7:0] frame_type,
    output reg [15:0] frame_seq, frame_length,
    output reg [MAX_PAYLOAD*8-1:0] frame_payload
);
    localparam [3:0] SYNC1=0, SYNC2=1, VERSION=2, KIND=3,
        SEQ_LO=4, SEQ_HI=5, LEN_LO=6, LEN_HI=7, DATA=8,
        CRC_LO=9, CRC_HI=10, QUIET=11;
    reg [3:0] state;
    reg [31:0] gap_count, frame_count;
    reg [15:0] crc, length, index;
    reg [7:0] crc_lo;

    function automatic [15:0] crc_next(input [15:0] prior, input [7:0] byte_value);
        reg [15:0] c;
        integer b;
        begin
            c=prior^{byte_value,8'd0};
            for(b=0;b<8;b=b+1) c=c[15] ? (c<<1)^16'h1021 : c<<1;
            crc_next=c;
        end
    endfunction

    task reject_frame;
        begin state<=QUIET; gap_count<=0; frame_count<=0; bad_frame<=1; end
    endtask

    always @(posedge clk) begin
        frame_valid<=0;
        bad_frame<=0;
        if(!rst_n) begin
            state<=SYNC1; gap_count<=0; frame_count<=0;
            crc<=16'hffff; length<=0; index<=0; crc_lo<=0;
            frame_type<=0; frame_seq<=0; frame_length<=0; frame_payload<=0;
        end else if(state==QUIET) begin
            if(rx_valid!==1'b0 || framing_error!==1'b0) gap_count<=0;
            else if(gap_count>=GAP_CYCLES-1) begin state<=SYNC1; gap_count<=0; end
            else gap_count<=gap_count+1'b1;
        end else if(framing_error!==1'b0 || (rx_valid===1'b1 && (^rx_data)===1'bx) ||
                    (rx_valid!==1'b0 && rx_valid!==1'b1)) begin
            reject_frame();
        end else if(state!=SYNC1 &&
                   (frame_count>=FRAME_CYCLES-1 || gap_count>=GAP_CYCLES-1)) begin
            reject_frame();
        end else begin
            if(state==SYNC1) begin gap_count<=0; frame_count<=0; end
            else begin
                frame_count<=frame_count+1'b1;
                if(rx_valid) gap_count<=0; else gap_count<=gap_count+1'b1;
            end
            if(rx_valid) case(state)
                SYNC1:if(rx_data==8'h55) state<=SYNC2;
                SYNC2:if(rx_data==8'haa) state<=VERSION;
                      else if(rx_data!=8'h55) state<=SYNC1;
                VERSION:if(rx_data==1) begin
                    crc<=crc_next(16'hffff,rx_data); state<=KIND;
                    frame_payload<=0;
                end else reject_frame();
                KIND:begin frame_type<=rx_data; crc<=crc_next(crc,rx_data); state<=SEQ_LO; end
                SEQ_LO:begin frame_seq[7:0]<=rx_data; crc<=crc_next(crc,rx_data); state<=SEQ_HI; end
                SEQ_HI:begin frame_seq[15:8]<=rx_data; crc<=crc_next(crc,rx_data); state<=LEN_LO; end
                LEN_LO:begin length[7:0]<=rx_data; crc<=crc_next(crc,rx_data); state<=LEN_HI; end
                LEN_HI:if({rx_data,length[7:0]}<=MAX_PAYLOAD) begin
                    length<={rx_data,length[7:0]}; frame_length<={rx_data,length[7:0]};
                    crc<=crc_next(crc,rx_data); index<=0;
                    state<=({rx_data,length[7:0]}==0) ? CRC_LO:DATA;
                end else reject_frame();
                DATA:begin
                    frame_payload[index*8+:8]<=rx_data; crc<=crc_next(crc,rx_data);
                    if(index+1==length) state<=CRC_LO; else index<=index+1'b1;
                end
                CRC_LO:begin crc_lo<=rx_data; state<=CRC_HI; end
                CRC_HI:if({rx_data,crc_lo}==crc) begin
                    frame_valid<=1; state<=SYNC1; gap_count<=0; frame_count<=0;
                end else reject_frame();
                default:reject_frame();
            endcase
        end
    end
endmodule
`default_nettype wire
