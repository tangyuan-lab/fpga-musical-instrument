`default_nettype none
// 50MHz同域的屏幕15字状态。屏幕发送器在帧首快照；本模块不进入音频握手。
// 9教学/10效果/11吞吐/12现场单音/13包络颤音/14混音/15实体键位；第16字由TX追加版本提交。
module screen_status_mux(
    input wire [3:0] view,
    input wire [511:0] fx_status,audio_status,
    input wire [127:0] note_status,input wire [111:0] physical_pitch_map,
    input wire [255:0] lesson_status,
    input wire [15:0] physical_down,enabled_keys,
    input wire [47:0] envelope,
    input wire [4:0] live_patch,screen_patch,
    input wire signed [6:0] transpose,
    input wire signed [13:0] bend,
    input wire [7:0] vibrato_depth,vibrato_rate,
    input wire [5:0] voices,
    input wire [127:0] track_timbres,track_volumes,input wire [15:0] track_mutes,track_solos,
    input wire [6:0] live_volume,song_volume,input wire [1:0] master_boost,limiter_release,
    input wire limiter_enabled,input wire [7:0] live_send,song_send,
    input wire [111:0] command_feedback,
    output reg [479:0] telemetry
);
    wire signed [8:0] pitch_bias=$signed(note_status[47:40])+9'sd12;
    wire signed [8:0] transpose_bias=$signed(transpose)+9'sd24;
    wire signed [15:0] bend_bias=$signed(bend)+16'sd8192;
    integer k;
    always @*begin
        telemetry=480'd0;
        case(view)
            9:begin
                telemetry[0*32+:32]={24'd0,lesson_status[7:0]};
                telemetry[1*32+:32]={24'd0,lesson_status[15:8]};
                telemetry[2*32+:32]={24'd0,lesson_status[23:16]};
                telemetry[3*32+:32]={16'd0,lesson_status[47:32]};
                telemetry[4*32+:32]={16'd0,lesson_status[63:48]};
                telemetry[5*32+:32]={24'd0,lesson_status[71:64]};
                telemetry[6*32+:32]={24'd0,lesson_status[79:72]};
                telemetry[7*32+:32]={24'd0,lesson_status[87:80]};
                telemetry[8*32+:32]={16'd0,lesson_status[127:112]};
                telemetry[9*32+:32]={16'd0,lesson_status[111:96]};
                telemetry[10*32+:32]={24'd0,lesson_status[95:88]};
                telemetry[11*32+:32]={7'd0,lesson_status[144],lesson_status[143:128],lesson_status[31:24]};
                telemetry[12*32+:32]=lesson_status[255:224];
                telemetry[13*32+:32]={24'd0,command_feedback[7:0]};
                telemetry[14*32+:32]={24'd0,command_feedback[15:8]};
            end
            10:telemetry=fx_status[479:0];
            11:telemetry=audio_status[479:0];
            12:begin
                telemetry[0*32+:32]={31'd0,note_status[0]};
                telemetry[1*32+:32]={31'd0,note_status[1]};
                telemetry[2*32+:32]={24'd0,note_status[15:8]};
                telemetry[3*32+:32]={24'd0,note_status[23:16]};
                telemetry[4*32+:32]={24'd0,note_status[31:24]};
                telemetry[5*32+:32]={24'd0,note_status[39:32]};
                telemetry[6*32+:32]={23'd0,pitch_bias};
                telemetry[7*32+:32]=note_status[79:48]&32'h7fffffff;
                telemetry[8*32+:32]=note_status[111:80];
                telemetry[9*32+:32]={27'd0,live_patch};
                telemetry[10*32+:32]={27'd0,screen_patch};
                telemetry[11*32+:32]={23'd0,transpose_bias};
                telemetry[13*32+:32]={24'd0,command_feedback[7:0]};
                telemetry[14*32+:32]={24'd0,command_feedback[15:8]};
            end
            13:begin
                for(k=0;k<4;k=k+1)telemetry[k*32+:32]={20'd0,envelope[k*12+:12]};
                telemetry[4*32+:32]={24'd0,vibrato_depth};
                telemetry[5*32+:32]={24'd0,vibrato_rate};
                telemetry[6*32+:32]={16'd0,bend_bias};
                telemetry[13*32+:32]={24'd0,command_feedback[7:0]};
                telemetry[14*32+:32]={24'd0,command_feedback[15:8]};
            end
            14:begin
                // 两个独立轨各16bit：音色[4:0]、音量[11:5]、静音12、独奏13；其余保留0。
                for(k=0;k<16;k=k+1)telemetry[k*16+:16]={2'd0,track_solos[k],track_mutes[k],track_volumes[k*8+:7],track_timbres[k*8+:5]};
                telemetry[8*32+:32]={25'd0,live_volume};
                telemetry[9*32+:32]={25'd0,song_volume};
                telemetry[10*32+:32]={27'd0,limiter_release,limiter_enabled,master_boost};
                telemetry[11*32+:32]={24'd0,live_send};
                telemetry[12*32+:32]={24'd0,song_send};
                telemetry[13*32+:32]={16'd0,command_feedback[15:0]};
                telemetry[14*32+:32]=command_feedback[47:16];
            end
            15:begin
                for(k=0;k<4;k=k+1)telemetry[k*32+:32]={4'd0,physical_pitch_map[k*28+:28]};
                telemetry[7*32+:32]={16'd0,enabled_keys};
                telemetry[8*32+:32]={27'd0,live_patch};
                telemetry[9*32+:32]={27'd0,screen_patch};
                telemetry[10*32+:32]={23'd0,transpose_bias};
                telemetry[12*32+:32]={16'd0,physical_down};
                telemetry[13*32+:32]={26'd0,voices};
                telemetry[14*32+:32]={31'd0,lesson_status[2:0]>=1&&lesson_status[2:0]<=5};
            end
            default:;
        endcase
    end
endmodule
`default_nettype wire
