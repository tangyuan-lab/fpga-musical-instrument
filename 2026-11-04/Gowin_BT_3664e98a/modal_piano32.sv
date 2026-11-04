`timescale 1ns/1ps
`default_nettype none

// 四个模态流水线共享32个逻辑声部。每声部64项均保留独立相位和双衰减状态。
// 状态RAM不复位；新一代音符的首帧从冻结系数初始化，不读取旧代历史作为有效数据。
// 这是钢琴后端；不把尚未接入的鼓模型声明为已实现的32鼓复音。
module modal_piano32 # (parameter EXTERNAL_PITCH=0,parameter REGISTER_INPUTS=1)(
    input wire clk,rst_n,sample_tick,panic,
    input wire [31:0] active,held,
    input wire [511:0] generation,
    input wire [223:0] notes,velocities,
    input wire [159:0] base_banks,
    input wire [31:0] pitch_word,
    output wire [4:0] pitch_addr,
    output reg busy,sample_valid,deadline_error,
    output reg signed [15:0] pcm,
    output reg signed [20:0] raw_mix,
    output reg [511:0] voice_pcm,
    output reg [31:0] finished,
    output reg [511:0] finished_generation,
    output reg [10:0] frame_cycles,
    output reg [10:0] max_frame_cycles
);
    reg [15:0] applied_generation[0:31];
    wire [31:0] frame_active,frame_held;reg [31:0] frame_first;
    wire [223:0] frame_notes,frame_velocity;
    wire [511:0] frame_generation;
    wire [159:0] frame_banks;
    wire [31:0] frame_ratio_word;
    assign frame_ratio_word=pitch_word;
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [39:0] note_map[0:127];
    initial $readmemh("piano_note_map.mem",note_map);
    reg [8:0] issue;
    reg issuing;
    reg [4:0] valid;
    reg [4:0] slot0,slot1,slot2,slot3,slot4;
    reg [3:0] group0,group1,group2,group3,group4;
    wire [4:0] issue_slot=issue[8:4];
    // 外部比例RAM是同步读：本拍请求下一拍发射的槽，空闲时预取槽0。
    wire [8:0] next_issue=issue+9'd1;
    assign pitch_addr=issuing && issue!=9'd511 ? next_issue[8:4]:5'd0;
    wire [6:0] issue_note=frame_notes[issue_slot*7+:7];
    wire [39:0] map_word=note_map[issue_note];
    wire [36:0] map_entry=map_word[36:0];
    wire [4:0] selected_bank=EXTERNAL_PITCH ? frame_banks[issue_slot*5+:5]:map_entry[36:32];
    wire [8:0] coefficient_address={selected_bank,issue[3:0]};
    wire [31:0] ratio=EXTERNAL_PITCH ? frame_ratio_word:map_entry[31:0];
    reg [31:0] ratio0;
    reg first0,first1;
    reg held0;
    reg audible0,audible1,audible2,audible3,audible4;
    wire signed [55:0] lane_finish[0:3];
    wire lane_quiet[0:3];
    reg post0,post1,post2;
    reg quiet_post0,quiet_post1,quiet_post2;
    reg [4:0] post_slot0,post_slot1;
    reg [4:0] post_slot2;
    reg [6:0] transition_age[0:31];
    reg signed [15:0] transition_tail[0:31];
    wire signed [15:0] previous_sample=$signed(voice_pcm[post_slot1*16+:16]);
    wire [6:0] blend_age=frame_first[post_slot1] ? (previous_sample==0 ? 7'd64:7'd0):
        (transition_age[post_slot1]<64 ? transition_age[post_slot1]+1'b1:7'd64);
    wire signed [15:0] blend_tail=frame_first[post_slot1] ? previous_sample:transition_tail[post_slot1];
    reg signed [23:0] blend_product;
    wire signed [15:0] blended_voice=blend_product[21:6];
    reg signed [62:0] velocity_product;
    reg signed [55:0] modal_sum;
    wire signed [25:0] raw_voice=26'(velocity_product>>>38);
    wire signed [15:0] clipped_voice=raw_voice>32767 ? 16'sd32767 : raw_voice< -32768 ? -16'sd32768:raw_voice[15:0];
    reg signed [20:0] accumulator;
    integer i;

    // REGISTER_INPUTS=0时由上层保证输入稳定至本帧结束；独立使用默认仍锁存。
    generate if(REGISTER_INPUTS)begin:private_frame
        reg [31:0] q_frame_active;assign frame_active=q_frame_active;
        reg [31:0] q_frame_held;assign frame_held=q_frame_held;
        reg [223:0] q_frame_notes;assign frame_notes=q_frame_notes;
        reg [223:0] q_frame_velocity;assign frame_velocity=q_frame_velocity;
        reg [511:0] q_frame_generation;assign frame_generation=q_frame_generation;
        reg [159:0] q_frame_banks;assign frame_banks=q_frame_banks;
        always @(posedge clk)begin
            if(!rst_n||panic)begin
                q_frame_active<=0;
                q_frame_held<=0;
                q_frame_notes<=0;
                q_frame_velocity<=0;
                q_frame_generation<=0;
                q_frame_banks<=0;
            end else if(sample_tick&&!busy)begin
                q_frame_active<=active;
                q_frame_held<=held;
                q_frame_notes<=notes;
                q_frame_velocity<=velocities;
                q_frame_generation<=generation;
                q_frame_banks<=base_banks;
            end
        end
    end else begin:shared_frame
        assign frame_active=active;
        assign frame_held=held;
        assign frame_notes=notes;
        assign frame_velocity=velocities;
        assign frame_generation=generation;
        assign frame_banks=base_banks;
        // synthesis translate_off
        reg [2207:0] checked_inputs;
        always @(posedge clk)begin
            if(rst_n&&!panic)begin
                if(sample_tick&&!busy)checked_inputs<={active,held,notes,velocities,generation,base_banks};
                else if(busy&&checked_inputs!=={active,held,notes,velocities,generation,base_banks})$fatal(1,"shared audio frame inputs changed while busy");
            end
        end
        // synthesis translate_on
    end endgenerate
    function automatic [31:0] decay_value(input [31:0] old_value,input [55:0] product);
        reg [32:0] rounded,drop;
        reg [33:0] difference;
        begin
            rounded={1'b0,product[55:24]}+product[23];
            drop=rounded==0 ? 33'd1:rounded;
            difference={2'b0,old_value}-{1'b0,drop};
            decay_value=difference[33] ? 32'd0:difference[31:0];
        end
    endfunction

    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1)begin:g_lane
        (* ram_style="block",syn_ramstyle="block_ram" *) reg [95:0] history[0:511];
        (* ram_style="block",syn_ramstyle="block_ram" *) reg signed [15:0] sine[0:1023];
        initial $readmemh("piano_sine.mem",sine);
        wire [127:0] coefficient0;
        modal_piano_coeff_rom #(.LANE(lane)) parameters(.clk(clk),.enable(rst_n&&!panic&&issuing),.address(coefficient_address),.data(coefficient0));
        reg [95:0] state0;
        reg [63:0] pitch_product1;
        reg [55:0] main_product1,onset_product1;
        reg [31:0] initial_phase1,old_phase1,initial_level1,old_main1,old_onset1;
        reg [31:0] phase2,main2,onset2;
        reg muted2;
        reg signed [15:0] sine3;
        reg [31:0] amplitude3;
        reg signed [48:0] amplitude_product4;
        reg signed [55:0] sum;
        reg quiet3,quiet4,quiet_sum;
        wire [31:0] main_source=first0 ? {coefficient0[63:48],16'd0}:state0[63:32];
        wire [31:0] onset_source=first0 ? {coefficient0[63:48],16'd0}:state0[31:0];
        wire [23:0] main_decay=coefficient0[47:24]+(held0 ? 24'd0:24'd8192);
        wire [23:0] onset_decay=coefficient0[23:0]+(held0 ? 24'd0:24'd8192);
        wire signed [55:0] contribution=audible4 ? {{7{amplitude_product4[48]}},amplitude_product4}:56'sd0;
        assign lane_finish[lane]=(group4==0 ? 56'sd0:sum)+contribution;
        assign lane_quiet[lane]=(group4==0 ? 1'b1:quiet_sum)&&quiet4;
        always @(posedge clk)begin
            // 仅写入有效流水拍；panic清除有效位，无须清整个历史数组。
            if(rst_n&&!panic&&issuing)begin
                state0<=history[issue];
            end
            if(!panic&&valid[0])begin
                pitch_product1<=coefficient0[127:96]*ratio0;
                main_product1<=main_source*main_decay;
                onset_product1<=onset_source*onset_decay;
                initial_phase1<=coefficient0[95:64];old_phase1<=state0[95:64];
                initial_level1<={coefficient0[63:48],16'd0};old_main1<=main_source;old_onset1<=onset_source;
            end
            if(!panic&&valid[1])begin
                main2<=first1 ? initial_level1:decay_value(old_main1,main_product1);
                onset2<=first1 ? initial_level1:decay_value(old_onset1,onset_product1);
                phase2<=first1 ? initial_phase1:old_phase1+32'(pitch_product1>>28);
                muted2<=(pitch_product1>>28)>=64'h80000000;
            end
            if(!panic&&valid[2])begin
                history[{slot2,group2}]<={phase2,main2,onset2};
                sine3<=sine[phase2[31:22]];
                amplitude3<=muted2||main2<onset2 ? 32'd0:main2-onset2;
                quiet3<=main2==0&&onset2==0;
            end
            if(!panic&&valid[3])begin amplitude_product4<=$signed(sine3)*$signed({1'b0,amplitude3});quiet4<=quiet3;end
            if(!rst_n||panic)begin sum<=0;quiet_sum<=0;end
            else if(valid[4])begin sum<=lane_finish[lane];quiet_sum<=lane_quiet[lane];end
        end
    end endgenerate

    always @(posedge clk)begin
        if(!rst_n||panic)begin
            busy<=0;sample_valid<=0;deadline_error<=0;issuing<=0;issue<=0;valid<=0;
            frame_first<=0;
            pcm<=0;raw_mix<=0;voice_pcm<=0;frame_cycles<=0;max_frame_cycles<=0;accumulator<=0;
            finished<=0;finished_generation<=0;quiet_post0<=0;quiet_post1<=0;quiet_post2<=0;
            post0<=0;post1<=0;post2<=0;post_slot0<=0;post_slot1<=0;post_slot2<=0;modal_sum<=0;velocity_product<=0;blend_product<=0;
            slot0<=0;slot1<=0;slot2<=0;slot3<=0;slot4<=0;group0<=0;group1<=0;group2<=0;group3<=0;group4<=0;
            ratio0<=0;first0<=0;first1<=0;held0<=0;audible0<=0;audible1<=0;audible2<=0;audible3<=0;audible4<=0;
            for(i=0;i<32;i=i+1)begin applied_generation[i]<=0;transition_age[i]<=64;transition_tail[i]<=0;end
        end else begin
            sample_valid<=0;finished<=0;
            valid<={valid[3:0],issuing};post0<=valid[4]&&group4==15;post1<=post0;post2<=post1;
            if(busy)frame_cycles<=frame_cycles+1'b1;
            if(sample_tick)begin
                if(busy)deadline_error<=1;
                else begin
                    busy<=1;issuing<=1;issue<=0;frame_cycles<=0;accumulator<=0;
                    
                    
                    for(i=0;i<32;i=i+1)frame_first[i]<=generation[i*16+:16]!=applied_generation[i];
                end
            end
            if(issuing)begin
                slot0<=issue_slot;group0<=issue[3:0];ratio0<=ratio;
                first0<=frame_first[issue_slot];held0<=frame_held[issue_slot];
                audible0<=frame_active[issue_slot]&&ratio!=0;
                if(issue==511)issuing<=0;else issue<=issue+1'b1;
            end
            slot1<=slot0;slot2<=slot1;slot3<=slot2;slot4<=slot3;
            group1<=group0;group2<=group1;group3<=group2;group4<=group3;
            first1<=first0;audible1<=audible0;audible2<=audible1;audible3<=audible2;audible4<=audible3;
            if(valid[4]&&group4==15)begin
                modal_sum<=lane_finish[0]+lane_finish[1]+lane_finish[2]+lane_finish[3];post_slot0<=slot4;
                quiet_post0<=lane_quiet[0]&&lane_quiet[1]&&lane_quiet[2]&&lane_quiet[3];
            end
            if(post0)begin velocity_product<=modal_sum*$signed({1'b0,frame_velocity[post_slot0*7+:7]});post_slot1<=post_slot0;quiet_post1<=quiet_post0;end
            if(post1)begin
                // 保留v74的64采样重触发交叉过渡；新音色计算不借用或清空其他声部历史。
                blend_product<=clipped_voice*$signed({1'b0,blend_age})+blend_tail*$signed(8'd64-{1'b0,blend_age});
                transition_age[post_slot1]<=blend_age;
                if(frame_first[post_slot1])transition_tail[post_slot1]<=previous_sample;
                post_slot2<=post_slot1;quiet_post2<=quiet_post1&&blend_age==64;
            end
            if(post2)begin
                voice_pcm[post_slot2*16+:16]<=blended_voice;
                accumulator<=accumulator+21'(blended_voice);
                applied_generation[post_slot2]<=frame_generation[post_slot2*16+:16];
                finished[post_slot2]<=frame_active[post_slot2]&&quiet_post2;
                finished_generation[post_slot2*16+:16]<=frame_generation[post_slot2*16+:16];
                if(post_slot2==31)begin
                    raw_mix<=accumulator+21'(blended_voice);pcm<=16'((accumulator+21'(blended_voice))>>>5);
                    sample_valid<=1;busy<=0;
                    if(frame_cycles>max_frame_cycles)max_frame_cycles<=frame_cycles;
                end
            end
        end
    end
endmodule
`default_nettype wire
