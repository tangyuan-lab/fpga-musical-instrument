`default_nettype none
// 屏幕五字节协议。输入为UART字节，valid在校验字节所在周期成立。
// 不保存按键、不认识播放器；滑动窗口和帧间超时保持原语义。
module screen_frame_rx #(parameter integer FRAME_TIMEOUT_CYCLES=138880)(
    input wire clk,rst_n,input wire [7:0] rx_data,input wire rx_valid,rx_framing_error,
    output wire frame_valid,output wire [7:0] frame_op,frame_value,
    output reg rx_activity,output reg frame_error
);
    localparam integer FRAME_COUNT_WIDTH=(FRAME_TIMEOUT_CYCLES<2)?1:$clog2(FRAME_TIMEOUT_CYCLES);
    reg [31:0] byte_window;reg [2:0] window_count;
    reg [FRAME_COUNT_WIDTH-1:0] frame_gap_count;
    wire candidate=rx_valid && window_count==4 && byte_window[31:16]==16'ha55a;
    wire checksum_ok=rx_data==(8'hff ^ byte_window[15:8] ^ byte_window[7:0]);
    assign frame_valid=candidate&&checksum_ok;
    assign frame_op=byte_window[15:8];assign frame_value=byte_window[7:0];
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin byte_window<=0;window_count<=0;frame_gap_count<=0;rx_activity<=0;frame_error<=0;end
        else begin
            frame_error<=0;
            if(rx_framing_error)begin byte_window<=0;window_count<=0;frame_gap_count<=0;frame_error<=1;end
            else if(rx_valid)begin
                byte_window<={byte_window[23:0],rx_data};frame_gap_count<=0;rx_activity<=~rx_activity;
                if(window_count<4)window_count<=window_count+1'b1;
                if(candidate&&!checksum_ok)frame_error<=1;
            end else if(window_count!=0)begin
                if(frame_gap_count>=FRAME_TIMEOUT_CYCLES-1)begin byte_window<=0;window_count<=0;frame_gap_count<=0;end
                else frame_gap_count<=frame_gap_count+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
