`timescale 1ns/1ps
`default_nettype none
// 屏幕旧音量0..100映射到统一引擎源轨0实体/1触摸/2曲谱；测试轨3固定0dB。
// 只发送变化的目标，保持valid到ready，再等待done；持续音不重触发。
module source_mix_sync(
    input wire clk,rst_n,input wire [6:0] piano_volume,midi_volume,drum_volume,
    output reg command_valid,input wire command_ready,command_done,command_error,
    output reg [4:0] command_owner,output reg [15:0] command_gain,output reg error
);
    reg [2:0] state;reg [2:0] cursor;reg [7:0] applied[0:4];reg [6:0] level;
    reg [31:0] product;integer i;
    wire [6:0] desired=cursor<2 ? (piano_volume>100 ? 7'd100:piano_volume):
        cursor==2 ? (midi_volume>100 ? 7'd100:midi_volume):cursor==4 ? (drum_volume>100 ? 7'd100:drum_volume):7'd100;
    always @(posedge clk)begin
        if(!rst_n)begin state<=0;cursor<=0;level<=0;product<=0;command_valid<=0;command_owner<=0;command_gain<=0;error<=0;
            for(i=0;i<5;i=i+1)applied[i]<=255;
        end else case(state)
            0:if(applied[cursor]!={1'b0,desired})begin level<=desired;command_owner<={2'd0,cursor};state<=1;end else cursor<=cursor==4 ? 0:cursor+1'b1;
            1:begin product<=level*32'd21474836;state<=2;end // round(level*32768/100)，不推断除法器。
            2:begin command_gain<=16'((product+32768)>>16);command_valid<=1;state<=3;end
            3:if(command_ready)begin command_valid<=0;state<=4;end
            4:if(command_done)begin
                if(command_error)error<=1;else applied[cursor]<={1'b0,level};
                cursor<=cursor==4 ? 0:cursor+1'b1;state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
