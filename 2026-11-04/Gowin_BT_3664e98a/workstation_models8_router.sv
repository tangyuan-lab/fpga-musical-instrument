`default_nettype none
// 旋律按键通过held/ID通路进入共享32槽；旧drum_triggers输出仅保留接口，当前打击乐资格固定关闭。
// 16键按帧扫描，共17拍（340ns@50MHz）；扫描中保持本帧输入，模式变化时重新取得身份。
// 每帧锁存输入；映射/模式修改会取消本帧，已按住的实体键须松开后才能重新起音。
module workstation_models8_router #(
    parameter integer MELODIC_TIMBRES=10,ALLOW_FOLLOW_TIMBRE=1
)(
    input wire clk,rst_n,mode_changed,map_changed,
    input wire [2:0] mode,input wire [255:0] active_map,
    input wire [15:0] physical_keys,screen_keys,input wire [127:0] physical_velocity,
    output reg [15:0] physical_piano_keys,
    output wire [127:0] physical_notes,output wire [95:0] physical_timbres,
    output wire [15:0] screen_piano_keys,chord_keys,
    output reg [15:0] drum_triggers,output reg [127:0] drum_velocity
);
    wire performing=mode>=1 && mode<=3 && !mode_changed && !map_changed;
    reg [15:0] blocked,previous_physical,previous_screen,held_snapshot,rise_snapshot,screen_hits;
    reg [127:0] velocity_snapshot;
    reg [15:0] piano_accum,chord_accum,drum_accum,physical_chords;
    reg [127:0] drum_levels;
    reg scanning;reg [3:0] key_index;
    wire [15:0] descriptor=active_map[key_index*16+:16];
    wire melodic=descriptor[15:14]==0 && descriptor[7:0]<16 &&
        ((descriptor[13:8]==10||descriptor[13:8]==19||descriptor[13:8]==20) || (ALLOW_FOLLOW_TIMBRE && descriptor[13:8]==63));
    wire percussion=1'b0;
    wire [7:0] incoming=velocity_snapshot[key_index*8+:8];
    wire [7:0] current_level=drum_levels[descriptor[3:0]*8+:8];
    assign screen_piano_keys=performing && (mode==2 || mode==3) ? screen_keys:16'd0;
    assign chord_keys=performing ? physical_chords|screen_piano_keys:16'd0;
    // 以下为旧鼓号兼容函数，本版percussion固定为0，不构成实际鼓功能。
    // 此顺序不是原模型drum_index；以下转换到内置模型10..18注册表，绝不按低4位回绕。
    function automatic [4:0] builtin_drum(input [2:0] index);
        case(index)
            0:builtin_drum=14;1:builtin_drum=11;2:builtin_drum=12;3:builtin_drum=13;
            4:builtin_drum=15;5:builtin_drum=16;6:builtin_drum=17;7:builtin_drum=18;
        endcase
    endfunction
    function automatic [4:0] resolve_timbre(input [5:0] raw,input [4:0] follow);
        // 63是映射层哨兵，必须先在6位域判定；它从不进入5位引擎端口。
        if(raw==6'd63)resolve_timbre=follow;
        else if(raw>=10&&raw<=20)resolve_timbre=raw[4:0];
        else resolve_timbre=5'd31; // 无效编号显式拒绝，不能别名为钢琴或另一种鼓。
    endfunction
    genvar g;generate for(g=0;g<16;g=g+1) begin:g_metadata
        assign physical_notes[g*8+:8]=performing&&active_map[g*16+14+:2]==0 ? active_map[g*16+:8]:8'd0;
        assign physical_timbres[g*6+:6]=performing ? (active_map[g*16+14+:2]==1 ?
            {1'b0,builtin_drum(active_map[g*16+:3])}:active_map[g*16+8+:6]):6'd0;
    end endgenerate
    integer i;
    always @(posedge clk) begin
        drum_triggers<=0;
        if(!rst_n) begin
            blocked<=16'hffff;previous_physical<=0;previous_screen<=0;scanning<=0;key_index<=0;
            held_snapshot<=0;rise_snapshot<=0;screen_hits<=0;velocity_snapshot<=0;
            piano_accum<=0;chord_accum<=0;drum_accum<=0;drum_levels<=0;
            physical_piano_keys<=0;physical_chords<=0;drum_velocity<=0;
        end else if(!performing) begin
            // 停音优先于扫描提交，取消未提交的事件，防止下一帧重新触发。
            blocked<=physical_keys;previous_physical<=physical_keys;previous_screen<=screen_keys;
            scanning<=0;physical_piano_keys<=0;physical_chords<=0;drum_velocity<=0;
            piano_accum<=0;chord_accum<=0;drum_accum<=0;drum_levels<=0;screen_hits<=0;
        end else begin
            blocked<=blocked & physical_keys;
            if(!scanning) begin
                held_snapshot<=physical_keys & ~blocked;
                rise_snapshot<=physical_keys & ~blocked & ~previous_physical;
                previous_physical<=physical_keys;previous_screen<=screen_keys;
                screen_hits<=mode==1 ? screen_keys & ~previous_screen:16'd0;
                velocity_snapshot<=physical_velocity;
                piano_accum<=0;chord_accum<=0;drum_accum<=0;drum_levels<=0;
                key_index<=0;scanning<=1;
            end else begin
                if((melodic||percussion) && held_snapshot[key_index]) begin
                    piano_accum[key_index]<=1;
                    chord_accum[descriptor[3:0]]<=1;
                end
                if(percussion && rise_snapshot[key_index]) begin
                    drum_accum[descriptor[3:0]]<=1;
                    if(incoming>current_level) drum_levels[descriptor[3:0]*8+:8]<=incoming;
                end
                if(key_index==15) begin
                    // 最后一个槽在下一拍提交，确保第15键的非阻塞赋值已进入累加器。
                    scanning<=0;
                end else key_index<=key_index+1'b1;
            end
            if(!scanning) begin
                physical_piano_keys<=piano_accum;physical_chords<=chord_accum;
                drum_triggers<=drum_accum|screen_hits;
                for(i=0;i<16;i=i+1)
                    drum_velocity[i*8+:8]<=screen_hits[i] && drum_levels[i*8+:8]<160 ? 8'd160:drum_levels[i*8+:8];
            end
        end
    end
endmodule
`default_nettype wire
