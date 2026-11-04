`default_nettype none
// 曲谱调度器：文件解析、Tempo时间基、跳转恢复和分段配器全部在FPGA。
// 每轮扫描使用同一tick快照，音符命令保持到接收；暂停/跳转清音后按目标位置重建。
module workstation_cut123_player(
    input wire clk,rst_n,command_valid,input wire [7:0] command_op,
    input wire [31:0] command_value,command_aux,
    input wire validation_start,validation_release,
    output wire validation_done,output wire [31:0] validation_duration,output wire [175:0] runtime_data,
    output reg command_done,output reg [7:0] command_result,
    input wire [31:0] song_ready_mask,input wire [7:0] patch_ready_mask,
    output reg [1:0] selected_song,input wire selected_ready,
    input wire [16:0] selected_size,input wire [31:0] duration,
    output wire [15:0] file_read_address,input wire [7:0] file_read_data,
    input wire [5:0] section_count,output wire [6:0] section_address,input wire [191:0] section_data,
    output reg playing,paused,output wire parser_busy,parser_error,
    output reg [31:0] tick,output reg [4:0] section,
    output reg loop_enabled,output reg [31:0] loop_a,loop_b,
    output reg [4:0] live_timbre,screen_timbre,
    output wire signed [6:0] live_transpose,
    output reg signed [13:0] bend,output reg [7:0] vibrato_depth,vibrato_rate,
    output reg [6:0] delay_mix,reverb_mix,feedback,output reg [11:0] delay_time,
    output reg panic,
    output reg event_valid,input wire event_ready,
    output reg [1:0] event_op,event_source,output reg [31:0] event_id,
    output reg [6:0] event_note,event_velocity,output reg [4:0] event_timbre,
    output reg [15:0] drum_triggers,output reg [127:0] drum_velocities,
    output reg [15:0] guide_keys,
    output wire [3:0] event_track,output wire [255:0] track_gains,output wire [63:0] channel_map,
    output wire [127:0] track_timbres,track_volumes,output wire [15:0] track_mutes,track_solos,
    input wire emergency_stop,emergency_abort,
    input wire lesson_begin,lesson_prepare,lesson_hold,lesson_reader_enable,
    input wire [10:0] lesson_reader_index,
    output wire lesson_quiet,lesson_parsed,output wire [11:0] lesson_event_count,
    output wire [31:0] lesson_event_start,lesson_event_end,
    output wire [6:0] lesson_event_note,output wire [3:0] lesson_event_track
);
    // 本候选保留钢琴10、吉他19与Bass20；鼓编号明确返回不支持。
    function automatic valid_timbre(input [31:0] v);
        valid_timbre=v==10||v==19||v==20;
    endfunction
    // 控制面先锁存数据和宽资格，再提交；紧急停止仍优先，音频数据通路不增加拍数。
    reg command_valid_q;reg [7:0] command_op_q;reg [31:0] command_value_q,command_aux_q;
    (* syn_preserve=1 *) reg command_timbre_ok_q,command_track_ok_q,command_volume_ok_q;
    always @(posedge clk)begin
        if(!rst_n||emergency_stop||emergency_abort)command_valid_q<=0;
        else command_valid_q<=command_valid;
        if(command_valid)begin
            command_op_q<=command_op;command_value_q<=command_value;command_aux_q<=command_aux;
            command_timbre_ok_q<=valid_timbre(command_value);
            command_track_ok_q<=command_aux<16;command_volume_ok_q<=command_value<=100;
        end
    end
    // 仅在完整配器读取后提交section；后台扫描不能改变当前段或覆盖写地址。
    reg [4:0] scan_section;
    reg [3:0] section_wait;
    reg parse_start,parse_stop;wire parsed;wire [3:0] parser_code;
    reg pending_lesson_prepare;
    wire [11:0] event_count;reg [11:0] index;wire [31:0] start_tick,end_tick;
    wire [6:0] note;wire [7:0] velocity;wire [3:0] part;
    wire [6:0] tempo_count;reg [6:0] tempo_index;
    assign validation_done=parsed;
    wire [31:0] tempo_tick;wire [23:0] tempo_value;wire [15:0] ppqn;
    midi_tracks_parser parser(.clk(clk),.rst_n(rst_n),.start(parse_start),.stop(parse_stop),
        .file_size(selected_size),.file_read_address(file_read_address),.file_read_data(file_read_data),
        .busy(parser_busy),.ready(parsed),.error(parser_error),.error_code(parser_code),
        .event_count(event_count),.event_read_index(lesson_reader_enable ? lesson_reader_index:index[10:0]),.event_start_tick(start_tick),.event_end_tick(end_tick),
        .event_note(note),.event_velocity(velocity),.event_channel(part),.tempo_count(tempo_count),.tempo_read_index(tempo_index[5:0]),
        .tempo_tick(tempo_tick),.tempo_us_per_quarter(tempo_value),.division_ppqn(ppqn),.parsed_duration(validation_duration));
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [17:0] flags[0:2047];
    reg [17:0] flags_read;reg clear_flags;reg [31:0] epoch;
    wire fired=flags_read[17:2]==epoch[15:0] && flags_read[0];
    wire held=flags_read[17:2]==epoch[15:0] && flags_read[1];
    reg [10:0] flag_init;reg flags_initialized;
    always @(posedge clk) begin
        if(!rst_n||clear_flags) begin flag_init<=0;flags_initialized<=0;end
        else if(!flags_initialized) begin
            if(flag_init==2047) flags_initialized<=1;
            else flag_init<=flag_init+1'b1;
        end
    end
    reg [3:0] state;reg flushing;reg [31:0] snapshot;
    assign lesson_quiet=!flushing&&!pending_lesson_prepare&&!event_valid&&!playing;
    assign lesson_parsed=parsed;
    assign lesson_event_count=event_count;assign lesson_event_start=start_tick;assign lesson_event_end=end_tick;
    assign lesson_event_note=note;
    wire automatic_restart=playing&&!paused&&parsed&&!parser_busy&&!flushing&&
        ((loop_enabled&&loop_b>loop_a&&tick>=loop_b)||tick>=duration);
    reg [23:0] tempo,candidate_tempo;reg [63:0] clock_accum;reg [8:0] speed;
    // Tempo/PPQN/变速为控制面参数，乘法结果提前一拍寄存，保持64位累加不截断极端输入。
    // 参数变化至时基生效最多增加1个50MHz周期；事件先后和MIDI tick单位不变。
    reg [63:0] threshold;reg [31:0] step_size;
    always @(posedge clk)begin
        if(!rst_n)begin threshold<=64'd2500000000;step_size<=0;end
        else begin threshold<={40'd0,tempo}*64'd5000;step_size<=ppqn*speed;end
    end
    reg [127:0] part_timbres,part_volumes;reg [15:0] mute_mask,solo_mask;
    assign track_timbres=part_timbres;assign track_volumes=part_volumes;
    assign track_mutes=mute_mask;assign track_solos=solo_mask;
    reg [3:0] precount_beats;reg [31:0] precount_remaining;reg [15:0] precount_phase;
    reg signed [7:0] transpose;reg auto_start,was_busy;
    reg signed [7:0] section_transpose;
    assign runtime_data={{8'd0,tempo},loop_b,{3'd0,screen_timbre},8'(live_transpose),{7'd0,speed},
                         solo_mask[7:0],mute_mask[7:0],part_volumes[31:0],part_timbres[31:0]};
    assign live_transpose=7'($signed(transpose)+$signed(section_transpose));
    reg [31:0] timbre_overrides,volume_overrides;
    reg [31:0] masks_override,live_override_valid;
    wire [127:0] override_timbres_read,override_volumes_read;wire [31:0] override_masks_read;wire [4:0] override_live_read;
    // 先形成待提交数据，再由一位资格寄存器驱动宽音量CE；循环边界优先级仍在原FSM。
    reg section_volumes_apply;reg [127:0] section_volumes_data;
    always @(posedge clk)if(state==2)
        section_volumes_data<=volume_overrides[scan_section] ? override_volumes_read : {{12{8'd100}},section_data[127:96]};
    always @(posedge clk)begin
        if(!rst_n)part_volumes<={16{8'd100}};
        else if(command_valid_q&&command_op_q==25&&command_volume_ok_q&&command_track_ok_q)
            part_volumes[command_aux_q[3:0]*8+:8]<=command_value_q[7:0];
        else if(section_volumes_apply)part_volumes<=section_volumes_data;
    end
    reg [63:0] channel_tracks;
    assign lesson_event_track=channel_tracks[part*4+:4];
    assign channel_map=channel_tracks;
    wire [3:0] current_track=channel_tracks[part*4+:4];
    assign event_track=current_track;
    genvar track;
    generate for(track=0;track<16;track=track+1)begin:g_gain
        wire enabled=!mute_mask[track]&&(solo_mask==0||solo_mask[track]);
        assign track_gains[track*16+:16]=enabled ? 16'((part_volumes[track*8+:8]*32'd21474836+32768)>>16):16'd0;
    end endgenerate
    function automatic [127:0] replace_part(input [127:0] word,input [3:0] position,input [7:0] value);
        begin replace_part=word;replace_part[position*8+:8]=value;end
    endfunction
    // 数据不复位，有效位屏蔽未写内容；整字写减少变址写入译码与布线。
    wire write_timbres=rst_n && command_valid_q && command_op_q==24 && command_timbre_ok_q && command_track_ok_q;
    wire write_volumes=rst_n && command_valid_q && command_op_q==25 && command_volume_ok_q && command_track_ok_q;
    wire write_masks=rst_n && command_valid_q && (command_op_q==26 || command_op_q==27);
    wire write_live=rst_n && command_valid_q && command_op_q==12 && command_timbre_ok_q;
    control_ram_sp32 #(.WIDTH(128)) timbre_memory(.clk(clk),.write_enable(write_timbres),.write_address(section),.read_address(scan_section),
        .write_data(replace_part(part_timbres,command_aux_q[3:0],command_value_q[7:0])),.read_data(override_timbres_read));
    control_ram_sp32 #(.WIDTH(128)) volume_memory(.clk(clk),.write_enable(write_volumes),.write_address(section),.read_address(scan_section),
        .write_data(replace_part(part_volumes,command_aux_q[3:0],command_value_q[7:0])),.read_data(override_volumes_read));
    control_ram_sp32 #(.WIDTH(32)) mask_memory(.clk(clk),.write_enable(write_masks),.write_address(section),.read_address(scan_section),
        .write_data(command_op_q==26 ? {solo_mask,command_value_q[15:0]}:{command_value_q[15:0],mute_mask}),.read_data(override_masks_read));
    control_ram_sp32 #(.WIDTH(5)) live_memory(.clk(clk),.write_enable(write_live),.write_address(section),.read_address(scan_section),
        .write_data(command_value_q[4:0]),.read_data(override_live_read));
    reg test_running;reg [5:0] test_index,test_count;reg [31:0] test_timer;
    reg [4:0] test_timbre;reg [6:0] test_note;
    wire part_enabled=valid_timbre({27'd0,part_timbres[current_track*8+:5]});
    // 同步事件RAM先读完，再寄存判定；下一拍只组合短资格，避免RAM数据直达valid深链。
    reg event_held_q,event_fired_q,event_due_q,event_ended_q,event_enabled_q;
    reg [4:0] event_timbre_q;reg signed [8:0] event_pitch_q;
    always @(posedge clk)if(rst_n&&state==6)begin
        event_held_q<=held;event_fired_q<=fired;event_due_q<=start_tick<=snapshot;
        event_ended_q<=end_tick<=snapshot;event_enabled_q<=part_enabled;
        event_timbre_q<=part_timbres[current_track*8+:5];
        event_pitch_q<=$signed({2'b0,note})+$signed(transpose)+$signed(section_transpose);
    end
    wire [31:0] weighted_velocity={9'd0,velocity[6:0],16'd0};
    always @(posedge clk) begin
        flags_read<=flags[index[10:0]];
        if(rst_n && !flags_initialized) flags[flag_init]<=0;
        else if(rst_n&&state==8&&event_valid&&event_ready)
            flags[index[10:0]]<={epoch[15:0],event_op==1,1'b1};
        else if(rst_n&&state==7&&index<event_count&&playing&&!paused&&!event_fired_q&&event_due_q&&
            (event_ended_q||!event_enabled_q))flags[index[10:0]]<={epoch[15:0],1'b0,1'b1};
    end
    assign section_address={selected_song,scan_section};
    function automatic [3:0] drum_number(input [6:0] n);
        case(n) 36:drum_number=0;38:drum_number=1;42:drum_number=2;46:drum_number=3;41:drum_number=4;43:drum_number=5;45:drum_number=6;
            39:drum_number=7;37:drum_number=8;51:drum_number=9;49:drum_number=10;56:drum_number=11;default:drum_number=n[3:0];endcase
    endfunction
    task restart_scan;
        begin event_valid<=0;flushing<=1;state<=12;scan_section<=0;section_wait<=0;index<=0;tempo_index<=0;clock_accum<=0;guide_keys<=0;end
    endtask
    always @(posedge clk) begin
        section_volumes_apply<=0;command_done<=0;parse_start<=0;parse_stop<=0;panic<=0;drum_triggers<=0;clear_flags<=0;
        if(!rst_n) begin
            precount_beats<=0;precount_remaining<=0;precount_phase<=0;pending_lesson_prepare<=0;
            channel_tracks<=64'hfedcba9876543210;selected_song<=0;playing<=0;paused<=0;tick<=0;section<=0;scan_section<=0;loop_enabled<=0;loop_a<=0;loop_b<=0;
            live_timbre<=10;screen_timbre<=10;bend<=0;vibrato_depth<=0;vibrato_rate<=5;
            delay_mix<=0;reverb_mix<=0;feedback<=48;delay_time<=3000;
            epoch<=1;flushing<=0;state<=0;section_wait<=0;snapshot<=0;index<=0;tempo_index<=0;tempo<=500000;candidate_tempo<=500000;
            section_volumes_apply<=0;
            clock_accum<=0;speed<=100;transpose<=0;section_transpose<=0;part_timbres<={16{8'd10}};
            mute_mask<=0;solo_mask<=0;auto_start<=0;was_busy<=0;event_valid<=0;event_op<=0;event_id<=0;event_note<=0;event_velocity<=0;event_timbre<=0;
            drum_velocities<=0;guide_keys<=0;command_result<=0;timbre_overrides<=0;volume_overrides<=0;masks_override<=0;
            test_running<=0;test_index<=0;test_count<=0;test_timer<=0;test_timbre<=0;test_note<=60;event_source<=2;live_override_valid<=0;
        end else if(emergency_stop) begin
            playing<=0;paused<=0;tick<=0;section<=0;auto_start<=0;test_running<=0;guide_keys<=0;pending_lesson_prepare<=0;
            // 仅清音允许后台验证继续；ABORT才终止解析器。
            parse_stop<=emergency_abort;restart_scan();
        end else begin
            if(validation_start) begin parse_start<=1;parse_stop<=0;playing<=0;paused<=0;auto_start<=0;restart_scan();end
            if(validation_release) begin parse_stop<=1;auto_start<=0;playing<=0;restart_scan();end
            if(lesson_begin)begin playing<=0;paused<=0;auto_start<=0;test_running<=0;restart_scan();end
            if(lesson_prepare)pending_lesson_prepare<=1;
            if(pending_lesson_prepare&&!flushing&&!event_valid)begin parse_start<=1;pending_lesson_prepare<=0;end
            was_busy<=parser_busy;
            if(auto_start && parsed && !parser_busy) begin auto_start<=0;playing<=1;paused<=0;
                precount_remaining<=precount_beats*ppqn;precount_phase<=0;end
            // 失败校验后重新解析：保留启动意图一拍，等待解析器清除上次错误。
            if(parser_error && !parse_start) begin playing<=0;auto_start<=0;end
            if(playing && !paused && parsed && !parser_busy && !flushing) begin
                if(clock_accum+step_size>=threshold) begin
                    clock_accum<=clock_accum+step_size-threshold;
                    if(precount_remaining!=0)begin
                        precount_remaining<=precount_remaining-1'b1;
                        precount_phase<=precount_phase==0 ? ppqn-1'b1:precount_phase-1'b1;
                    end else tick<=tick+1'b1;
                end
                else clock_accum<=clock_accum+step_size;
                if(loop_enabled && loop_b>loop_a && tick>=loop_b) begin tick<=loop_a;restart_scan();end
                else if(tick>=duration) begin playing<=0;restart_scan();end
            end
            if(command_valid_q) begin
                command_done<=1;command_result<=0;
                // 单端口覆盖表异址写占用读端：若正要消费读值，重新等待读窗口。
                if((write_timbres||write_volumes||write_masks||write_live) && state==2) begin
                    section_wait<=0;state<=1;
                end
                case(command_op_q)
                    2:if(command_value_q==0 && song_ready_mask[command_value_q[1:0]]) begin
                        selected_song<=command_value_q[1:0];parse_stop<=1;playing<=0;paused<=0;tick<=0;section<=0;restart_scan();
                        timbre_overrides<=0;volume_overrides<=0;masks_override<=0;live_override_valid<=0;loop_enabled<=0;
                    end else command_result<=1;
                    3:if(lesson_hold)command_result<=4;else if(selected_ready) begin
                        if(!parsed) begin parse_start<=1;auto_start<=1;restart_scan();end
                        else begin playing<=1;paused<=0;
                            if(!playing)begin precount_remaining<=precount_beats*ppqn;precount_phase<=0;end
                        end
                    end else command_result<=2;
                    4:begin paused<=!paused;restart_scan();end
                    5,15:begin playing<=0;paused<=0;tick<=0;section<=0;auto_start<=0;test_running<=0;restart_scan();end
                    6:if(parsed) begin tick<=command_value_q>duration ? duration:command_value_q;restart_scan();end else command_result<=3;
                    7:loop_a<=command_value_q>duration ? duration:command_value_q;
                    8:loop_b<=command_value_q>duration ? duration:command_value_q;
                    9:loop_enabled<=command_value_q!=0;
                    10:if(command_value_q>=50 && command_value_q<=200) speed<=command_value_q[8:0];else command_result<=1;
                    11:if($signed(command_value_q)>=-24 && $signed(command_value_q)<=24) begin transpose<=command_value_q[7:0];restart_scan();end else command_result<=1;
                    12,13:if(command_timbre_ok_q) begin
                        if(command_op_q==12) begin live_timbre<=command_value_q[4:0];live_override_valid[section]<=1;end
                        else screen_timbre<=command_value_q[4:0];
                    end else command_result<=4;
                    14,28,29:if(command_value_q==0 && command_op_q!=14) begin test_running<=0;restart_scan();end
                        else if(command_op_q!=14 || (command_timbre_ok_q)) begin
                            playing<=0;paused<=0;restart_scan();test_running<=1;test_index<=0;
                            test_count<=command_op_q==14 ? 1 : command_op_q==28 ? 4:32;
                            test_timbre<=command_op_q==14 ? command_value_q[4:0]:10;
                            test_note<=command_aux_q[6:0]==0 ? 60:command_aux_q[6:0];
                            test_timer<=command_op_q==14 && command_aux_q[31:8]!=0 && command_aux_q[31:8]<=5000 ? command_aux_q[31:8]*50000 : 250000000;
                        end else command_result<=4;
                    16:if($signed(command_value_q)>=-4096 && $signed(command_value_q)<=4096) bend<=14'(command_value_q);else command_result<=1;
                    17:vibrato_depth<=command_value_q>255 ? 255:command_value_q[7:0];
                    18:vibrato_rate<=command_value_q>20 ? 20:command_value_q[7:0];
                    19:delay_mix<=command_value_q>100 ? 100:command_value_q[6:0];
                    20:reverb_mix<=command_value_q>100 ? 100:command_value_q[6:0];
                    21:delay_time<=command_value_q>4095 ? 4095:command_value_q[11:0];
                    22:feedback<=command_value_q>96 ? 96:command_value_q[6:0];
                    23:if(command_value_q<section_count) begin scan_section<=command_value_q[4:0];section_wait<=0;state<=10;end else command_result<=1;
                    24:if(command_timbre_ok_q && command_track_ok_q) begin
                        timbre_overrides[section]<=1;part_timbres[command_aux_q[3:0]*8+:8]<=command_value_q[7:0];
                    end else command_result<=4;
                    25:if(command_volume_ok_q && command_track_ok_q) begin
                        volume_overrides[section]<=1;
                    end else command_result<=1;
                    26:begin mute_mask<=command_value_q[15:0];masks_override[section]<=1;end
                    27:begin solo_mask<=command_value_q[15:0];masks_override[section]<=1;end
                    39:if(!playing&&!paused)channel_tracks<={command_aux_q,command_value_q};else command_result<=4;
                    40:if(command_value_q<=8)precount_beats<=command_value_q[3:0];else command_result<=1;
                    45:if(command_aux_q!=10 || command_value_q>3)command_result<=1;
                    44:if(!valid_timbre(command_aux_q) || command_value_q[31:24]!=0 ||
                        (command_value_q[23:22]!=0 && (command_value_q[19:0]<4096 || command_value_q[19:0]>524287)) ||
                        (command_aux_q==10 && command_value_q[23:22]==3))command_result<=1;
                    41,42,43:begin end // 实际合唱参数由audio_params在本次成功ACK后按帧提交。
                    46:if(command_value_q>4)command_result<=1;
                    47:if(command_value_q<50||command_value_q>600)command_result<=1;
                    51:if(command_value_q>1||command_aux_q>3)command_result<=1;
                    52:if(command_value_q<2||command_value_q>6||
                        (command_value_q==2&&command_aux_q>3)||(command_value_q==3&&command_aux_q>1)||
                        ((command_value_q==4||command_value_q==5)&&command_aux_q>128)||
                        (command_value_q==6&&command_aux_q>3))command_result<=1;
                    default:command_result<=8'h7f;
                endcase
            end else if(validation_start||validation_release||automatic_restart||lesson_begin||(pending_lesson_prepare&&!flushing))begin
                // 重定位/校验取消优先：禁止下面的普通扫描再次写state/index覆盖restart_scan。
            end else if(flushing)begin
                event_source<=2;
                case(state)
                    12:state<=13;
                    13:state<=14;
                    14:if(index>=event_count)begin
                        if(epoch[15:0]==16'hffff)clear_flags<=1;
                        epoch<=epoch+1'b1;flushing<=0;index<=0;state<=0;
                    end else if(held)begin event_op<=0;event_id<={epoch[19:0],index};event_valid<=1;state<=15;end
                    else begin index<=index+1'b1;state<=12;end
                    15:if(event_valid&&event_ready)begin event_valid<=0;index<=index+1'b1;state<=12;end
                    default:state<=12;
                endcase
            end else if(test_running) begin
                if(test_timer==0) begin test_running<=0;restart_scan();end
                else begin
                    test_timer<=test_timer-1'b1;
                    if(event_valid) begin if(event_ready) begin event_valid<=0;test_index<=test_index+1'b1;end end
                    else if(test_index<test_count) begin
                        event_valid<=1;event_op<=1;event_source<=3;event_id<=16'hf000+test_index;event_velocity<=100;event_timbre<=test_timbre;
                        if(test_count==1) event_note<=test_note;
                        else if(test_count==4) case(test_index) 0:event_note<=60;1:event_note<=64;2:event_note<=67;default:event_note<=71;endcase
                        else event_note<=48+test_index;
                    end
                end
            end else if(parsed && !parser_busy && !parser_error && flags_initialized && !lesson_hold) begin
                event_source<=2;
                case(state)
                    0:begin snapshot<=tick;scan_section<=0;tempo_index<=0;candidate_tempo<=500000;state<=1;guide_keys<=0;end
                    1:if(section_wait==14)begin section_wait<=0;state<=2;end else section_wait<=section_wait+1'b1;
                    2:begin
                        if(section_count!=0 && snapshot>=section_data[63:32] && scan_section+1<section_count) begin scan_section<=scan_section+1'b1;state<=1;end
                        else begin
                            if(section_count!=0) begin
                                section<=scan_section;
                                part_timbres<=timbre_overrides[scan_section] ? override_timbres_read : {{12{8'd10}},section_data[95:64]};
                                section_volumes_apply<=1;
                                mute_mask<=masks_override[scan_section] ? override_masks_read[15:0] : section_data[131:128];
                                solo_mask<=masks_override[scan_section] ? override_masks_read[31:16] : section_data[139:136];
                                live_timbre<=live_override_valid[scan_section] ? override_live_read:section_data[148:144];
                                section_transpose<=section_data[159:152];
                            end
                            state<=3;
                        end
                    end
                    3:state<=4;
                    4:begin
                        if(tempo_index<tempo_count && tempo_tick<=snapshot) candidate_tempo<=tempo_value==0 ? 500000:tempo_value;
                        if(tempo_index+1<tempo_count && tempo_tick<=snapshot) begin tempo_index<=tempo_index+1'b1;state<=3;end
                        else begin
                            // 扫描结束才提交有效速度；中间表项不能进入演奏时基，避免反复扫表改变实际速度。
                            tempo<=(tempo_index<tempo_count && tempo_tick<=snapshot) ? (tempo_value==0 ? 24'd500000:tempo_value):candidate_tempo;
                            index<=0;state<=5;
                        end
                    end
                    5:state<=6;
                    6:state<=7;
                    7:begin
                        if(index>=event_count) state<=0;
                        else if(playing && !paused && precount_remaining==0) begin
                            if(event_held_q && (event_ended_q || !event_enabled_q)) begin
                                event_op<=0;event_id<={epoch[19:0],index};event_valid<=1;state<=8;
                            end else if(!event_fired_q && event_due_q) begin
                                
                                if(!event_ended_q && event_enabled_q) begin
                                    // 无鼓候选只接受10/19/20；旧鼓分支不可达，不再旁路已寄存的资格。
                                    if(event_pitch_q>=0 && event_pitch_q<=127) begin
                                        event_op<=1;event_id<={epoch[19:0],index};event_note<=event_pitch_q[6:0];
                                        event_velocity<=weighted_velocity[22:16];
                                        event_timbre<=event_timbre_q;event_valid<=1;state<=8;
                                    end else state<=9;
                                end else state<=9;
                            end else state<=9;
                            if(start_tick>=snapshot && start_tick<snapshot+ppqn && current_track==0 && note>=60 && note<=75) guide_keys[note-60]<=1;
                        end else state<=0;
                    end
                    8:if(event_valid && event_ready) begin event_valid<=0;state<=9;end
                    9:begin index<=index+1'b1;state<=5;end
                    10:if(section_wait==14)begin section_wait<=0;state<=11;end else section_wait<=section_wait+1'b1;
                    11:begin tick<=section_data[31:0];restart_scan();end
                    default:state<=0;
                endcase
            end
            if(playing&&precount_remaining!=0)guide_keys<=precount_phase<ppqn/2 ? 16'hffff:16'd0;
        end
    end
endmodule
`default_nettype wire
