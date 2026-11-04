`timescale 1ns/1ps
`default_nettype none
// 32槽身份/力度控制；本版接收钢琴10、吉他19、Bass20，运行音色为5位，63跟随在外层解析。
// 统一音符身份与声部所有权。释音必须同时匹配来源键号和32位音符ID，
// 不能因旧松键报文误关抢占后分配的新音。普通曲谱保留4槽给实时输入。
module model_voice_control_models8_32 #(
    parameter integer TIMBRE_ROUTING=0
)(
    input wire clk,rst_n,sample_tick,panic,test_mode,
    input wire event_valid,output wire event_ready,
    input wire [2:0] event_op, // 0起音，1释音，2持续压力，3绝对音高比，4目标音高（统一引擎）
    input wire event_realtime,
    input wire [15:0] event_key,
    input wire [31:0] event_id,
    input wire [6:0] event_note,event_velocity,event_pressure,
    input wire [4:0] event_track,
    input wire [4:0] event_timbre,
    input wire [31:0] event_ratio, // UQ4.28，相对起音时选定的基准模型
    input wire adsr_enable,
    input wire [14:0] attack_step,decay_step,sustain_level,release_step,
    input wire [31:0] finished,
    input wire [511:0] finished_generation,
    output reg event_ack,
    output reg [2:0] event_result, // 0生效，1身份已过期，2无可用槽，3参数无效，4重复起音
    output reg [4:0] event_slot,
    output reg [31:0] active,held,
    output wire [511:0] generation,
    output wire [223:0] notes,velocities,pressures,
    output wire [159:0] banks,tracks,
    output wire [159:0] timbres,
    output wire [31:0] modal_mask,
    output wire [1023:0] ratios,
    output wire [479:0] envelopes,
    output reg [5:0] active_count,
    output reg [31:0] stolen_count,
    output reg env_busy
);
    reg [15:0] voice_generation[0:31];
    reg [31:0] voice_ratio[0:31];
    wire [79:0] owner_q;wire owner_valid,owner_busy;wire [59:0] envelope_q;wire envelope_valid;
    localparam IDLE=0,SCAN_READ=1,SCAN_WAIT=2,SCAN_CHECK=3,COMMIT=4,PITCH_COMMIT=5,COMMIT_PREP=6,PITCH_VALIDATE=7;
    reg [2:0] state;
    reg [4:0] scan_index;
    reg [31:0] scan_active,scan_held,serial_snapshot,distance;
    reg f_realtime,f_protected_first,f_adsr;reg [2:0] f_op;reg [15:0] f_key;reg [31:0] f_id,f_ratio;
    reg [6:0] f_note,f_velocity,f_pressure;reg [4:0] f_track;reg [4:0] f_timbre;
    reg [14:0] f_a,f_d,f_s,f_r;
    reg have_match,have_free,have_release,have_old;
    reg [4:0] match_slot,free_slot,release_slot,old_slot;
    reg [31:0] oldest_release,oldest;
    wire [4:0] chosen=have_free ? free_slot:have_release ? release_slot:old_slot;
    assign event_ready=state==IDLE&&rst_n&&!panic&&(!TIMBRE_ROUTING||(!env_busy&&!owner_busy));
    wire is_plucked=TIMBRE_ROUTING&&(f_timbre==19||f_timbre==20);
    wire is_modal=!TIMBRE_ROUTING||f_timbre==10;
    wire is_tom=1'b0;
    // 超出原始16键参考区时选最近模型，再计算比例；不生成或截短音色系数。
    wire [4:0] start_plucked_bank=f_timbre==20 ?
        (f_note<28 ? 5'd16:f_note>43 ? 5'd31:5'(f_note-28+16)):
        (f_note<60 ? 5'd0:f_note>75 ? 5'd15:5'(f_note-60));
    wire native_plucked=f_timbre==19 ? f_note>=60&&f_note<=75:f_note>=28&&f_note<=43;
    reg [63:0] start_pitch_product;
    wire [31:0] start_plucked_ratio=native_plucked ? 32'h10000000:start_pitch_product[55:24];
    wire start_ratio_ok=native_plucked||(!(|start_pitch_product[63:56])&&start_pitch_product[55:24]>=8192);
    // 通鼓note60为原调；UQ1.15可表达21..71，超范围明确拒绝而不是截断成另一音高。
    wire event_parameters_ok=(!is_modal||(f_note>=21&&f_note<=108))&&
        (!is_tom||(f_note>=21&&f_note<=71))&&(f_timbre==10||is_tom||is_plucked)&&
        (!is_plucked||(f_note>=21&&f_note<=108&&start_ratio_ok))&&f_velocity!=0&&f_track<19&&
        (!f_adsr||(f_a!=0&&f_d!=0&&f_r!=0));
    // 读快照、计算、提交三阶段更新；提交寄存器切断饱和判断到32槽写使能的长路径。
    reg voice_adsr[0:31];
    reg [1:0] env_phase;reg [4:0] env_slot;reg env_active;reg [1:0] env_stage;
    reg [14:0] env_next_level;reg [1:0] env_next_stage;reg env_write_valid,env_retire;
    reg start_ok_q,pitch_ok_q;reg [4:0] start_bank_q;reg [31:0] start_ratio_q,pitch_value_q;
    reg [14:0] env_level,env_a,env_d,env_s,env_r;
    wire [15:0] env_attack_sum={1'b0,env_level}+{1'b0,env_a};
    wire owner_write=rst_n&&!panic&&!env_busy&&state==COMMIT&&f_op==0&&start_ok_q&&!have_match&&(have_free||have_release||have_old);
    generate if(TIMBRE_ROUTING)begin:packed_owners
        voice_context_bank memory(.clk(clk),.rst_n(rst_n&&!panic),
            .write_enable(owner_write),.write_address(chosen),.write_owner({f_key,f_id,serial_snapshot}),
            .write_envelope({f_a,f_d,f_s,f_r}),.write_busy(owner_busy),
            .owner_request(!env_busy&&state==SCAN_READ),.owner_address(scan_index),.owner_data(owner_q),.owner_valid(owner_valid),
            .envelope_request(env_busy&&active[env_slot]&&voice_adsr[env_slot]),.envelope_address(env_slot),
            .envelope_data(envelope_q),.envelope_valid(envelope_valid));
    end else begin:original_owners
        (* ram_style="block",syn_ramstyle="block_ram" *) reg [79:0] owner_ram[0:31];reg [79:0] q;
        assign owner_q=q;assign owner_valid=1;
        assign owner_busy=0;assign envelope_q=0;assign envelope_valid=1;
        always @(posedge clk)begin q<=owner_ram[scan_index];if(owner_write)owner_ram[chosen]<={f_key,f_id,serial_snapshot};end
    end endgenerate
    reg [6:0] voice_note[0:31],voice_velocity[0:31],voice_pressure[0:31];
    reg [4:0] voice_bank[0:31],voice_track[0:31];
    reg [4:0] voice_timbre[0:31];
    reg [1:0] stage[0:31]; // 0起音，1衰减，2维持，3释音
    reg [14:0] level[0:31],a[0:31],d[0:31],s[0:31],r[0:31];
    reg [31:0] serial;
    wire [39:0] start_map;
    generate if(TIMBRE_ROUTING)begin:packed_note_map
        piano_note_rom memory(.clk(clk),.address(f_note),.data(start_map));
    end else begin:original_note_map
        reg [39:0] note_map[0:127];
        initial $readmemh("piano_note_map.mem",note_map);
        assign start_map=note_map[f_note];
    end endgenerate
    reg [31:0] relative_pitch[0:127],bank_reciprocal[0:31],gb_reciprocal[0:31];
    reg [63:0] absolute_pitch_product;
    always @(posedge clk)if(rst_n&&state==SCAN_READ)
        start_pitch_product<=relative_pitch[f_note]*gb_reciprocal[start_plucked_bank];

    generate if(TIMBRE_ROUTING)begin:pitch_tables
        initial begin
            $readmemh("pitch_c4_q24.mem",relative_pitch);
            $readmemh("bank_reciprocal_q28.mem",bank_reciprocal);
            $readmemh("gb_reciprocal_q28.mem",gb_reciprocal);
        end
    end endgenerate
    integer i;
    reg [15:0] envelope_sum;
    reg [2:0] count4[0:7];reg [3:0] count8[0:3];reg [4:0] count16[0:1];
    genvar g;
    generate for(g=0;g<32;g=g+1)begin:outputs
        assign generation[g*16+:16]=voice_generation[g];
        assign notes[g*7+:7]=voice_note[g];assign velocities[g*7+:7]=voice_velocity[g];
        assign pressures[g*7+:7]=voice_pressure[g];assign ratios[g*32+:32]=voice_ratio[g];
        assign banks[g*5+:5]=voice_bank[g];assign tracks[g*5+:5]=voice_track[g];
        assign timbres[g*5+:5]=voice_timbre[g];
        assign modal_mask[g]=active[g]&&(!TIMBRE_ROUTING||voice_timbre[g]==10||voice_timbre[g]==19||voice_timbre[g]==20);
        assign envelopes[g*15+:15]=level[g];
    end endgenerate
    // f_*为待接受事务的暂存参数；仅在IDLE更新，事务开始后保持。
    // 无效/取消周期的暂存值不参与提交，active/held/state等控制复位仍在原分支。
    // Pure note data follows IDLE, then freezes for the transaction. Keeping
    // panic/ready decode off this ROM address does not relax any commit guard.
    always @(posedge clk)if(state==IDLE)f_note<=event_note;
    // 与f_note同样只在IDLE预采样事务身份；提交仍经过原有ready/所有权/取消守卫。
    always @(posedge clk)begin
        if(!rst_n)begin f_realtime<=0;f_protected_first<=0;f_key<=0;end
        else if(state==IDLE)begin
            f_realtime<=event_realtime||test_mode;f_protected_first<=event_realtime&&!test_mode;f_key<=event_key;
        end
    end

    always @(posedge clk)begin
        if(!rst_n)begin f_adsr<=0;f_a<=0;f_d<=0;f_s<=0;f_r<=0;end
        else if(state==IDLE)begin
            f_adsr<=adsr_enable;f_a<=attack_step;f_d<=decay_step;f_s<=sustain_level;f_r<=release_step;
        end
    end
    // 事务数据在IDLE预采样；接收当拍仍取当拍输入，进入扫描后保持。
    // panic只清控制状态和有效声部，未提交暂存值不可产生写入或响应。
    // 这样数据寄存器的CE不再经过急停及包络忙组合路径，急停本身不延迟。
    always @(posedge clk)begin
        if(!rst_n)begin
            f_op<=0;f_id<=0;f_ratio<=0;f_velocity<=0;f_pressure<=0;f_track<=0;f_timbre<=0;
        end else if(state==IDLE)begin
            f_op<=event_op;f_id<=event_id;f_ratio<=event_ratio;
            f_velocity<=event_velocity;f_pressure<=event_pressure;f_track<=event_track;
            f_timbre<=TIMBRE_ROUTING ? event_timbre:5'd0;
        end
    end
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            active<=0;held<=0;event_ack<=0;event_result<=0;event_slot<=0;serial<=0;active_count<=0;stolen_count<=0;
            state<=IDLE;scan_index<=0;scan_active<=0;scan_held<=0;serial_snapshot<=0;distance<=0;
            absolute_pitch_product<=0;have_match<=0;have_free<=0;have_release<=0;have_old<=0;
            env_busy<=0;env_phase<=0;env_slot<=0;env_active<=0;env_stage<=0;
            env_level<=0;env_a<=0;env_d<=0;env_s<=0;env_r<=0;
            env_next_level<=0;env_next_stage<=0;env_write_valid<=0;env_retire<=0;
            start_ok_q<=0;pitch_ok_q<=0;start_bank_q<=0;start_ratio_q<=0;pitch_value_q<=0;
            match_slot<=0;free_slot<=0;release_slot<=0;old_slot<=0;oldest_release<=0;oldest<=0;
            for(i=0;i<8;i=i+1)count4[i]<=0;
            for(i=0;i<4;i=i+1)count8[i]<=0;
            for(i=0;i<2;i=i+1)count16[i]<=0;
            for(i=0;i<32;i=i+1)begin
                voice_generation[i]<=0;voice_note[i]<=0;voice_velocity[i]<=0;voice_pressure[i]<=0;
                voice_bank[i]<=0;voice_track[i]<=0;voice_timbre[i]<=0;voice_ratio[i]<=0;voice_adsr[i]<=0;stage[i]<=0;level[i]<=0;
                if(!TIMBRE_ROUTING)begin a[i]<=1;d[i]<=1;s[i]<=32767;r[i]<=1;end
            end
        end else begin
            event_ack<=0;
            for(i=0;i<8;i=i+1)count4[i]<=3'(active[i*4])+3'(active[i*4+1])+3'(active[i*4+2])+3'(active[i*4+3]);
            for(i=0;i<4;i=i+1)count8[i]<={1'b0,count4[i*2]}+{1'b0,count4[i*2+1]};
            for(i=0;i<2;i=i+1)count16[i]<={1'b0,count8[i*2]}+{1'b0,count8[i*2+1]};
            active_count<={1'b0,count16[0]}+{1'b0,count16[1]};
            for(i=0;i<32;i=i+1)begin
                if(active[i]&&finished[i]&&finished_generation[i*16+:16]==voice_generation[i])begin active[i]<=0;held[i]<=0;end
                if(!TIMBRE_ROUTING&&sample_tick&&active[i]&&voice_adsr[i])begin
                    case(stage[i])
                        0:begin
                            envelope_sum={1'b0,level[i]}+{1'b0,a[i]};
                            if(envelope_sum>=32767)begin level[i]<=32767;stage[i]<=1;end else level[i]<=envelope_sum[14:0];
                        end
                        1:if(level[i]<=s[i]||level[i]-s[i]<=d[i])begin level[i]<=s[i];stage[i]<=2;end else level[i]<=level[i]-d[i];
                        2:level[i]<=s[i];
                        3:if(level[i]<=r[i])begin level[i]<=0;active[i]<=0;held[i]<=0;end else level[i]<=level[i]-r[i];
                    endcase
                end
            end
            if(TIMBRE_ROUTING)begin
                if(sample_tick)begin env_busy<=1;env_slot<=0;env_phase<=0;end
                if(env_busy)begin
                    if(env_phase==0&&(!active[env_slot]||!voice_adsr[env_slot]||envelope_valid))begin
                        env_active<=active[env_slot]&&voice_adsr[env_slot];env_stage<=stage[env_slot];
                        env_level<=level[env_slot];env_a<=envelope_q[59:45];env_d<=envelope_q[44:30];
                        env_s<=envelope_q[29:15];env_r<=envelope_q[14:0];env_phase<=1;
                    end else if(env_phase==1)begin
                        env_next_level<=env_level;env_next_stage<=env_stage;env_retire<=0;
                        env_write_valid<=env_active;
                        case(env_stage)
                            0:if(env_attack_sum>=32767)begin env_next_level<=32767;env_next_stage<=1;end
                              else env_next_level<=env_attack_sum[14:0];
                            1:if(env_level<=env_s||env_level-env_s<=env_d)begin env_next_level<=env_s;env_next_stage<=2;end
                              else env_next_level<=env_level-env_d;
                            2:env_next_level<=env_s;
                            3:if(env_level<=env_r)begin env_next_level<=0;env_retire<=1;end
                              else env_next_level<=env_level-env_r;
                        endcase
                        env_phase<=2;
                    end else if(env_phase==2)begin
                        if(env_write_valid&&active[env_slot])begin
                            level[env_slot]<=env_next_level;stage[env_slot]<=env_next_stage;
                            if(env_retire)begin active[env_slot]<=0;held[env_slot]<=0;end
                        end
                        env_phase<=0;
                        if(env_slot==31)env_busy<=0;else env_slot<=env_slot+1'b1;
                    end
                end
            end
            // 包络扫描期间冻结身份事务；共用RAM不会把包络行误当成音符身份。
            if(!TIMBRE_ROUTING||!env_busy)case(state)
                IDLE:if(event_valid)begin

                    scan_active<=active;scan_held<=held;serial_snapshot<=serial;
                    have_match<=0;have_free<=0;have_release<=0;have_old<=0;oldest_release<=0;oldest<=0;
                    scan_index<=0;state<=SCAN_READ;
                end
                SCAN_READ:if(owner_valid)state<=SCAN_WAIT;
                SCAN_WAIT:begin distance<=serial_snapshot-owner_q[31:0];state<=SCAN_CHECK;end
                SCAN_CHECK:begin
                    if(scan_active[scan_index]&&owner_q[79:64]==f_key&&owner_q[63:32]==f_id)begin have_match<=1;match_slot<=scan_index;end
                    if(f_realtime||scan_index<28)begin
                        // 实时先选28..31受保护空槽；测试模式仍按0..31固定顺序遍历。
                        if(!scan_active[scan_index]&&(!have_free||(f_protected_first&&scan_index>=28&&free_slot<28)))begin have_free<=1;free_slot<=scan_index;end
                        if(scan_active[scan_index]&&!scan_held[scan_index]&&(!have_release||distance>oldest_release))begin
                            have_release<=1;release_slot<=scan_index;oldest_release<=distance;
                        end
                        if(scan_active[scan_index]&&(!have_old||distance>oldest))begin have_old<=1;old_slot<=scan_index;oldest<=distance;end
                    end
                    if(scan_index==31)state<=COMMIT_PREP;else begin scan_index<=scan_index+1'b1;state<=SCAN_READ;end
                end
                // 先锁存校验和音高；DSP输出不得直接形成所有声部的CE。
                COMMIT_PREP:begin
                    start_ok_q<=event_parameters_ok;
                    start_bank_q<=is_plucked ? start_plucked_bank:start_map[36:32];
                    start_ratio_q<=is_plucked ? start_plucked_ratio:start_map[31:0];
                    state<=COMMIT;
                end
                COMMIT:if(TIMBRE_ROUTING&&env_busy)begin event_ack<=0;end else begin
                    state<=IDLE;event_ack<=1;event_result<=0;
                    if(f_op==0)begin
                        if(!start_ok_q)event_result<=3;
                        else if(have_match)event_result<=4;
                        else if(!(have_free||have_release||have_old))event_result<=2;
                        else begin
                            event_slot<=chosen;serial<=serial+1'b1;
                            if(active[chosen])stolen_count<=stolen_count+1'b1;
                            for(i=0;i<32;i=i+1)if(chosen==i)begin
                                active[i]<=1;held[i]<=1;voice_generation[i]<=voice_generation[i]+1'b1;
                                voice_note[i]<=f_note;voice_velocity[i]<=f_velocity;voice_pressure[i]<=f_pressure;voice_track[i]<=f_track;
                                voice_timbre[i]<=f_timbre;
                                voice_bank[i]<=start_bank_q;
                                voice_ratio[i]<=start_ratio_q;
                                voice_adsr[i]<=f_adsr;stage[i]<=0;level[i]<=f_adsr ? 15'd0:15'd32767;
                                if(!TIMBRE_ROUTING)begin a[i]<=f_a;d[i]<=f_d;s[i]<=f_s;r[i]<=f_r;end
                            end
                        end
                    end else if(f_op>4||(f_op==4&&!TIMBRE_ROUTING))event_result<=3;
                    else if(!have_match||!active[match_slot])event_result<=1;
                    else if(f_op==4)begin
                        event_slot<=match_slot;
                        // 兼容波形的0..127音域由频率表处理，不受模型bank的UQ4.28范围限制。
                        if(voice_note[match_slot]==f_note)begin end
                        else if(voice_timbre[match_slot]>=11&&voice_timbre[match_slot]<=18)begin
                            if(f_note<21||f_note>71)event_result<=3;
                            else begin voice_note[match_slot]<=f_note;voice_ratio[match_slot]<=relative_pitch[f_note]<<4;end
                        end else if(voice_timbre[match_slot]==19||voice_timbre[match_slot]==20)begin
                            if(f_note<21||f_note>108)event_result<=3;
                            else begin absolute_pitch_product<=relative_pitch[f_note]*gb_reciprocal[voice_bank[match_slot]];
                                state<=PITCH_VALIDATE;event_ack<=0;end
                        end else if(voice_timbre[match_slot]!=10)voice_note[match_slot]<=f_note;
                        else if(f_note<21||f_note>108)event_result<=3;
                        else begin
                            // 共享一个变调乘法器；放入逐声部for分支会展开32套乘法/ROM读口。
                            absolute_pitch_product<=relative_pitch[f_note]*bank_reciprocal[voice_bank[match_slot]];
                            state<=PITCH_VALIDATE;event_ack<=0;
                        end
                    end
                    else begin
                        event_slot<=match_slot;
                        for(i=0;i<32;i=i+1)if(match_slot==i)case(f_op)
                            1:begin held[i]<=0;if(voice_adsr[i])stage[i]<=3;end
                            2:voice_pressure[i]<=f_pressure;
                            3:if(f_ratio==0||((voice_timbre[i]>=11&&voice_timbre[i]<=18)&&(f_ratio<32'd8192||f_ratio>=32'h20000000)))event_result<=3;else voice_ratio[i]<=f_ratio;
                        endcase
                    end
                end
                PITCH_VALIDATE:begin
                    pitch_ok_q<=!(|absolute_pitch_product[63:56])&&absolute_pitch_product[55:24]!=0;
                    pitch_value_q<=absolute_pitch_product[55:24];state<=PITCH_COMMIT;
                end
                PITCH_COMMIT:begin
                    // UQ4.28无法表达极端跨区间滑音时明确拒绝，不能溢出成另一音高。
                    if(!pitch_ok_q)event_result<=3;
                    else begin
                        voice_ratio[match_slot]<=pitch_value_q;
                        voice_note[match_slot]<=f_note;
                    end
                    event_ack<=1;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
