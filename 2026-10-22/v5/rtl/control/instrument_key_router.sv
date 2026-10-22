`default_nettype none
// 实体输入使用可编辑描述符；屏幕输入严格由当前模式决定，映射配置不能改屏幕键。
// 换模式/改映射后，已按住的实体键必须松开一次，避免换音色时意外重新触发。
module instrument_key_router #(
    parameter integer MELODIC_TIMBRES=2,
    parameter integer ALLOW_FOLLOW_TIMBRE=0
) (
    input wire clk,rst_n, mode_changed,map_changed,
    input wire [2:0] mode,
    input wire [255:0] active_map,
    input wire [15:0] physical_keys,screen_keys,
    input wire [127:0] physical_velocity,
    output reg [15:0] physical_piano_keys,
    output reg [127:0] physical_notes,
    output reg [95:0] physical_timbres,
    output reg [15:0] screen_piano_keys, chord_keys,drum_triggers,
    output reg [127:0] drum_velocity
);
    reg [15:0] blocked,previous_physical,previous_screen;
    reg [15:0] usable,physical_rise,screen_rise;
    reg [15:0] descriptor;
    wire performing=mode>=1 && mode<=3 && !mode_changed && !map_changed;
    reg [15:0] hit_keys,screen_hits;
    reg [63:0] hit_sounds;
    reg [127:0] hit_velocity;
    reg [15:0] hits_s2,hits_s3,screen_s2,screen_s3;
    // 固定切片的打包总线：每级只更新自身字节，避免仿真数组整表事件扩散。
    reg [511:0] group_max;
    reg [255:0] half_max;
    // 先锁存每个实体键的事件，再用平衡树取同鼓力度最大值。
    // 四拍流水线为80ns（50MHz），避免16次动态索引比较形成长串联路径。
    function automatic [7:0] max2(input [7:0] a,b);
        max2=a>b ? a : b;
    endfunction
    integer i,n;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin blocked<=16'hffff;previous_physical<=0;previous_screen<=0;end
        else if(mode_changed || map_changed) begin
            blocked<=physical_keys;previous_physical<=physical_keys;previous_screen<=screen_keys;
        end else begin blocked<=blocked & physical_keys;previous_physical<=physical_keys;previous_screen<=screen_keys;end
    end
    always @(*) begin
        usable=physical_keys & ~blocked;
        physical_rise=usable & ~previous_physical;
        screen_rise=screen_keys & ~previous_screen;
        physical_piano_keys=0; physical_notes=0;physical_timbres=0;
        screen_piano_keys=0;chord_keys=0;
        descriptor=0;n=0;
        if(performing) begin
            if(mode==2 || mode==3) screen_piano_keys=screen_keys;
            chord_keys=screen_piano_keys;
            for(i=0;i<16;i=i+1) begin
                descriptor=active_map[i*16+:16];
                physical_notes[i*8+:8]=descriptor[7:0];physical_timbres[i*6+:6]=descriptor[13:8];
                // V2增加自定义音色及63（跟随当前音色）；旧工程默认仍只允许0/1。
                if(descriptor[15:14]==0 &&
                   (descriptor[13:8]<MELODIC_TIMBRES || (ALLOW_FOLLOW_TIMBRE && descriptor[13:8]==63)) &&
                   descriptor[7:0]<16) begin
                    physical_piano_keys[i]=usable[i];
                end
            end
            // 每个音高固定一个输出位，仅对匹配的实体输入做OR归约。
            for(n=0;n<16;n=n+1) for(i=0;i<16;i=i+1)
                chord_keys[n]=chord_keys[n] | (physical_piano_keys[i] && physical_notes[i*8+:8]==8'(n));
        end
    end
    genvar key_index,drum_index,group_index;
    generate
        for(key_index=0;key_index<16;key_index=key_index+1) begin:g_hit_key
            wire [15:0] mapping=active_map[key_index*16+:16];
            always @(posedge clk) begin
                if(!rst_n || !performing) begin
                    hit_keys[key_index]<=0;hit_sounds[key_index*4+:4]<=0;hit_velocity[key_index*8+:8]<=0;
                end else begin
                    hit_keys[key_index]<=physical_rise[key_index] && mapping[15:14]==1 && mapping[13:8]==0 && mapping[7:0]<16;
                    hit_sounds[key_index*4+:4]<=mapping[3:0];
                    hit_velocity[key_index*8+:8]<=physical_velocity[key_index*8+:8];
                end
            end
        end
        for(drum_index=0;drum_index<16;drum_index=drum_index+1) begin:g_drum_reduce
            wire [15:0] requests;
            wire [127:0] candidates;
            for(key_index=0;key_index<16;key_index=key_index+1) begin:g_candidate
                assign requests[key_index]=hit_keys[key_index] && hit_sounds[key_index*4+:4]==4'(drum_index);
                assign candidates[key_index*8+:8]=requests[key_index] ? hit_velocity[key_index*8+:8] : 8'd0;
            end
            for(group_index=0;group_index<4;group_index=group_index+1) begin:g_group
                wire [7:0] group_value=max2(
                    max2(candidates[(group_index*4)*8+:8],candidates[(group_index*4+1)*8+:8]),
                    max2(candidates[(group_index*4+2)*8+:8],candidates[(group_index*4+3)*8+:8]));
                always @(posedge clk) begin
                    if(!rst_n || !performing) group_max[(drum_index*4+group_index)*8+:8]<=0;
                    else group_max[(drum_index*4+group_index)*8+:8]<=group_value;
                end
            end
            wire [7:0] left_value=max2(group_max[(drum_index*4)*8+:8],group_max[(drum_index*4+1)*8+:8]);
            wire [7:0] right_value=max2(group_max[(drum_index*4+2)*8+:8],group_max[(drum_index*4+3)*8+:8]);
            wire [7:0] output_value=max2(max2(half_max[(drum_index*2)*8+:8],half_max[(drum_index*2+1)*8+:8]),
                screen_s3[drum_index] ? 8'd160 : 8'd0);
            always @(posedge clk) begin
                if(!rst_n || !performing) begin
                    hits_s2[drum_index]<=0;hits_s3[drum_index]<=0;
                    half_max[(drum_index*2)*8+:8]<=0;half_max[(drum_index*2+1)*8+:8]<=0;
                    drum_triggers[drum_index]<=0;drum_velocity[drum_index*8+:8]<=0;
                end else begin
                    hits_s2[drum_index]<=|requests;
                    hits_s3[drum_index]<=hits_s2[drum_index];
                    half_max[(drum_index*2)*8+:8]<=left_value;
                    half_max[(drum_index*2+1)*8+:8]<=right_value;
                    drum_triggers[drum_index]<=hits_s3[drum_index] | screen_s3[drum_index];
                    drum_velocity[drum_index*8+:8]<=output_value;
                end
            end
        end
    endgenerate
    always @(posedge clk) begin
        if(!rst_n || !performing) begin screen_hits<=0;screen_s2<=0;screen_s3<=0;end
        else begin
            screen_hits<=mode==1 ? screen_rise : 16'd0;
            screen_s2<=screen_hits;screen_s3<=screen_s2;
        end
    end
endmodule
`default_nettype wire
