`default_nettype none
// 所有权0..15歌曲、16实体、17屏幕、18测试；只改增益目标，不重触发音符。
// 乘法后用22拍串行常数除法；UI控制不在音频计算期限内，不展开长的宽乘法/比较链。
module workstation_track_mix(
    input wire clk,rst_n,input wire [255:0] song_gains,input wire [6:0] piano_volume,midi_volume,
    output reg command_valid,input wire command_ready,command_done,command_error,
    output reg [4:0] command_owner,output reg [15:0] command_gain,output reg error
);
    reg [2:0] state;reg [4:0] cursor,count;
    reg [15:0] applied[0:18],base;
    reg [6:0] percent;
    reg [21:0] numerator,quotient;reg [7:0] remainder;
    wire [7:0] next_remainder={remainder[6:0],numerator[21]};
    wire subtract=next_remainder>=100;
    wire [21:0] next_quotient={quotient[20:0],subtract};
    integer i;
    always @(posedge clk)begin
        if(!rst_n)begin
            state<=0;cursor<=0;count<=0;base<=0;percent<=0;numerator<=0;quotient<=0;remainder<=0;
            command_valid<=0;command_owner<=0;command_gain<=0;error<=0;
            for(i=0;i<19;i=i+1)applied[i]<=16'hffff;
        end else case(state)
            0:begin
                base<=cursor<16 ? song_gains[cursor*16+:16]:16'h8000;
                percent<=cursor<16 ? (midi_volume>100 ? 7'd100:midi_volume):cursor<18 ? (piano_volume>100 ? 7'd100:piano_volume):7'd100;
                command_owner<=cursor;state<=1;
            end
            1:begin numerator<=base*percent+22'd50;quotient<=0;remainder<=0;count<=21;state<=2;end
            2:begin
                remainder<=subtract ? next_remainder-8'd100:next_remainder;
                numerator<={numerator[20:0],1'b0};quotient<=next_quotient;
                if(count==0)state<=3;else count<=count-1'b1;
            end
            3:if(applied[cursor]!=quotient[15:0])begin command_gain<=quotient[15:0];command_valid<=1;state<=4;end
                else begin cursor<=cursor==18 ? 0:cursor+1'b1;state<=0;end
            4:if(command_ready)begin command_valid<=0;state<=5;end
            5:if(command_done)begin
                if(command_error)error<=1;else applied[cursor]<=command_gain;
                cursor<=cursor==18 ? 0:cursor+1'b1;state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
