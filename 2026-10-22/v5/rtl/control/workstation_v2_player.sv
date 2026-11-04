`default_nettype none
// 曲谱调度器：文件解析、Tempo时间基、跳转恢复和分段配器全部在FPGA。
// 每轮扫描使用同一tick快照，音符命令保持到接收；暂停/跳转清音后按目标位置重建。
module workstation_v2_player(
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
    output reg [3:0] live_timbre,screen_timbre,
    output wire signed [6:0] live_transpose,
    output reg signed [13:0] bend,output reg [7:0] vibrato_depth,vibrato_rate,
    output reg [6:0] delay_mix,reverb_mix,feedback,output reg [11:0] delay_time,
    output reg panic,
    output reg event_valid,input wire event_ready,
    output reg [1:0] event_op,event_source,output reg [15:0] event_id,
    output reg [6:0] event_note,event_velocity,output reg [3:0] event_timbre,
    output reg [15:0] drum_triggers,output reg [127:0] drum_velocities,
    output reg [15:0] guide_keys,
    input wire emergency_stop,emergency_abort
);
    reg parse_start,parse_stop;wire parsed;wire [3:0] parser_code;
    wire [11:0] event_count;reg [11:0] index;wire [31:0] start_tick,end_tick;
    wire [6:0] note;wire [7:0] velocity;wire [1:0] part;
    wire [6:0] tempo_count;reg [6:0] tempo_index;
    assign validation_done=parsed;
    wire [31:0] tempo_tick;wire [23:0] tempo_value;wire [15:0] ppqn;
    midi_type0_parser_v2 parser(.clk(clk),.rst_n(rst_n),.start(parse_start),.stop(parse_stop),
        .file_size(selected_size),.file_read_address(file_read_address),.file_read_data(file_read_data),
        .busy(parser_busy),.ready(parsed),.error(parser_error),.error_code(parser_code),
        .event_count(event_count),.event_read_index(index),.event_start_tick(start_tick),.event_end_tick(end_tick),
        .event_note(note),.event_velocity(velocity),.event_part(part),.tempo_count(tempo_count),.tempo_read_index(tempo_index),
        .tempo_tick(tempo_tick),.tempo_us_per_quarter(tempo_value),.division_ppqn(ppqn),.parsed_duration(validation_duration));
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [33:0] flags[0:2047];
    reg [33:0] flags_read;reg [31:0] epoch;
    wire fired=flags_read[33:2]==epoch && flags_read[0];
    wire held=flags_read[33:2]==epoch && flags_read[1];
    reg [10:0] flag_init;reg flags_initialized;
    always @(posedge clk) begin
        if(!rst_n) begin flag_init<=0;flags_initialized<=0;end
        else if(!flags_initialized) begin
            if(flag_init==2047) flags_initialized<=1;
            else flag_init<=flag_init+1'b1;
        end
    end
    reg [3:0] state;reg [31:0] snapshot;
    reg [23:0] tempo,candidate_tempo;reg [63:0] clock_accum;reg [8:0] speed;
    wire [63:0] threshold={40'd0,tempo}*64'd5000;
    wire [31:0] step_size=ppqn*speed;
    reg [31:0] part_timbres,part_volumes;reg [3:0] mute_mask,solo_mask;
    reg signed [7:0] transpose;reg auto_start,was_busy;
    reg signed [7:0] section_transpose;
    assign runtime_data={{8'd0,tempo},loop_b,{4'd0,screen_timbre},8'(live_transpose),{7'd0,speed},
                         {4'd0,solo_mask},{4'd0,mute_mask},part_volumes,part_timbres};
    assign live_transpose=7'($signed(transpose)+$signed(section_transpose));
    reg [31:0] timbre_overrides,volume_overrides;
    reg [31:0] masks_override,live_override_valid;
    wire [31:0] override_timbres_read,override_volumes_read;wire [7:0] override_masks_read;wire [3:0] override_live_read;
    function automatic [31:0] replace_part(input [31:0] word,input [1:0] position,input [7:0] value);
        case(position)
            0:replace_part={word[31:8],value};1:replace_part={word[31:16],value,word[7:0]};
            2:replace_part={word[31:24],value,word[15:0]};default:replace_part={value,word[23:0]};
        endcase
    endfunction
    // 数据不复位，有效位屏蔽未写内容；整字写减少变址写入译码与布线。
    wire write_timbres=rst_n && command_valid && command_op==24 && command_value<10 && command_aux<4 && (command_value<2 || patch_ready_mask[command_value-2]);
    wire write_volumes=rst_n && command_valid && command_op==25 && command_value<=100 && command_aux<4;
    wire write_masks=rst_n && command_valid && (command_op==26 || command_op==27);
    wire write_live=rst_n && command_valid && command_op==12 && command_value<10 && (command_value<2 || patch_ready_mask[command_value-2]);
    control_ram_sdp timbre_memory(.clk(clk),.write_enable(write_timbres),.write_address(section),.read_address(section),
        .write_data(replace_part(part_timbres,command_aux[1:0],command_value[7:0])),.read_data(override_timbres_read));
    control_ram_sdp volume_memory(.clk(clk),.write_enable(write_volumes),.write_address(section),.read_address(section),
        .write_data(replace_part(part_volumes,command_aux[1:0],command_value[7:0])),.read_data(override_volumes_read));
    control_ram_sdp #(.WIDTH(8)) mask_memory(.clk(clk),.write_enable(write_masks),.write_address(section),.read_address(section),
        .write_data(command_op==26 ? {solo_mask,command_value[3:0]}:{command_value[3:0],mute_mask}),.read_data(override_masks_read));
    control_ram_sdp #(.WIDTH(4)) live_memory(.clk(clk),.write_enable(write_live),.write_address(section),.read_address(section),
        .write_data(command_value[3:0]),.read_data(override_live_read));
    reg signed [31:0] transposed;
    reg test_running;reg [5:0] test_index,test_count;reg [31:0] test_timer;
    reg [3:0] test_timbre;reg [6:0] test_note;
    wire part_enabled=!mute_mask[part] && (solo_mask==0 || solo_mask[part]) && part_volumes[part*8+:8]!=0;
    wire [31:0] weighted_velocity=velocity*part_volumes[part*8+:8]*32'd656;
    always @(posedge clk) begin
        flags_read<=flags[index[10:0]];
        if(rst_n && !flags_initialized) flags[flag_init]<=0;
        else if(rst_n && state==7 && index<event_count && playing && !paused) begin
            if(held && (end_tick<=snapshot || !part_enabled)) flags[index[10:0]]<={epoch,1'b0,1'b1};
            else if(!fired && start_tick<=snapshot) flags[index[10:0]]<={epoch,(end_tick>snapshot && part_enabled && (part!=3 || part_timbres[part*8+:4]>=2)),1'b1};
        end
    end
    assign section_address={selected_song,section};
    function automatic [3:0] drum_number(input [6:0] n);
        case(n) 36:drum_number=0;38:drum_number=1;42:drum_number=2;46:drum_number=3;41:drum_number=4;43:drum_number=5;45:drum_number=6;
            39:drum_number=7;37:drum_number=8;51:drum_number=9;49:drum_number=10;56:drum_number=11;default:drum_number=n[3:0];endcase
    endfunction
    task restart_scan;
        begin epoch<=epoch+1'b1;event_valid<=0;panic<=1;state<=0;section<=0;index<=0;tempo_index<=0;clock_accum<=0;end
    endtask
    always @(posedge clk) begin
        command_done<=0;parse_start<=0;parse_stop<=0;panic<=0;drum_triggers<=0;
        if(!rst_n) begin
            selected_song<=0;playing<=0;paused<=0;tick<=0;section<=0;loop_enabled<=0;loop_a<=0;loop_b<=0;
            live_timbre<=0;screen_timbre<=0;bend<=0;vibrato_depth<=0;vibrato_rate<=5;
            delay_mix<=0;reverb_mix<=0;feedback<=48;delay_time<=3000;
            epoch<=1;state<=0;snapshot<=0;index<=0;tempo_index<=0;tempo<=500000;candidate_tempo<=500000;
            clock_accum<=0;speed<=100;transpose<=0;section_transpose<=0;part_timbres<=32'h00000001;part_volumes<={4{8'd100}};
            mute_mask<=1;solo_mask<=0;auto_start<=0;was_busy<=0;event_valid<=0;event_op<=0;event_id<=0;event_note<=0;event_velocity<=0;event_timbre<=0;
            drum_velocities<=0;guide_keys<=0;command_result<=0;timbre_overrides<=0;volume_overrides<=0;masks_override<=0;
            test_running<=0;test_index<=0;test_count<=0;test_timer<=0;test_timbre<=0;test_note<=60;event_source<=2;live_override_valid<=0;
        end else if(emergency_stop) begin
            playing<=0;paused<=0;tick<=0;auto_start<=0;test_running<=0;guide_keys<=0;
            // 仅清音允许后台验证继续；ABORT才终止解析器。
            parse_stop<=emergency_abort;restart_scan();
        end else begin
            if(validation_start) begin parse_start<=1;parse_stop<=0;playing<=0;paused<=0;auto_start<=0;restart_scan();end
            if(validation_release) begin parse_stop<=1;auto_start<=0;playing<=0;end
            was_busy<=parser_busy;
            if(auto_start && parsed && !parser_busy) begin auto_start<=0;playing<=1;paused<=0;end
            if(parser_error) begin playing<=0;auto_start<=0;end
            if(playing && !paused && parsed && !parser_busy) begin
                if(clock_accum+step_size>=threshold) begin clock_accum<=clock_accum+step_size-threshold;tick<=tick+1'b1;end
                else clock_accum<=clock_accum+step_size;
                if(loop_enabled && loop_b>loop_a && tick>=loop_b) begin tick<=loop_a;restart_scan();end
                else if(tick>=duration) begin playing<=0;restart_scan();end
            end
            if(command_valid) begin
                command_done<=1;command_result<=0;
                case(command_op)
                    2:if(command_value<4 && song_ready_mask[command_value[1:0]]) begin
                        selected_song<=command_value[1:0];parse_stop<=1;playing<=0;paused<=0;tick<=0;restart_scan();
                        timbre_overrides<=0;volume_overrides<=0;masks_override<=0;live_override_valid<=0;loop_enabled<=0;
                    end else command_result<=1;
                    3:if(selected_ready) begin
                        if(!parsed) begin parse_start<=1;auto_start<=1;restart_scan();end
                        else begin playing<=1;paused<=0;end
                    end else command_result<=2;
                    4:begin paused<=!paused;restart_scan();end
                    5,15:begin playing<=0;paused<=0;tick<=0;auto_start<=0;test_running<=0;parse_stop<=1;restart_scan();end
                    6:if(parsed) begin tick<=command_value>duration ? duration:command_value;restart_scan();end else command_result<=3;
                    7:loop_a<=command_value>duration ? duration:command_value;
                    8:loop_b<=command_value>duration ? duration:command_value;
                    9:loop_enabled<=command_value!=0;
                    10:if(command_value>=50 && command_value<=200) speed<=command_value[8:0];else command_result<=1;
                    11:if($signed(command_value)>=-24 && $signed(command_value)<=24) begin transpose<=command_value[7:0];restart_scan();end else command_result<=1;
                    12,13:if(command_value<10 && (command_value<2 || patch_ready_mask[command_value-2])) begin
                        if(command_op==12) begin live_timbre<=command_value[3:0];live_override_valid[section]<=1;end
                        else screen_timbre<=command_value[3:0];
                    end else command_result<=4;
                    14,28,29:if(command_value==0 && command_op!=14) begin test_running<=0;restart_scan();end
                        else if(command_op!=14 || (command_value<10 && (command_value<2 || patch_ready_mask[command_value-2]))) begin
                            playing<=0;paused<=0;restart_scan();test_running<=1;test_index<=0;
                            test_count<=command_op==14 ? 1 : command_op==28 ? 4:32;
                            test_timbre<=command_op==14 ? command_value[3:0]:0;
                            test_note<=command_aux[6:0]==0 ? 60:command_aux[6:0];
                            test_timer<=command_op==14 && command_aux[31:8]!=0 && command_aux[31:8]<=5000 ? command_aux[31:8]*50000 : 250000000;
                        end else command_result<=4;
                    16:if($signed(command_value)>=-4096 && $signed(command_value)<=4096) bend<=14'(command_value);else command_result<=1;
                    17:vibrato_depth<=command_value>255 ? 255:command_value[7:0];
                    18:vibrato_rate<=command_value>20 ? 20:command_value[7:0];
                    19:delay_mix<=command_value>100 ? 100:command_value[6:0];
                    20:reverb_mix<=command_value>100 ? 100:command_value[6:0];
                    21:delay_time<=command_value>4095 ? 4095:command_value[11:0];
                    22:feedback<=command_value>96 ? 96:command_value[6:0];
                    23:if(command_value<section_count) begin section<=command_value[4:0];state<=10;end else command_result<=1;
                    24:if(command_value<10 && command_aux<4 && (command_value<2 || patch_ready_mask[command_value-2])) begin
                        timbre_overrides[section]<=1;part_timbres[command_aux*8+:8]<=command_value[7:0];
                    end else command_result<=4;
                    25:if(command_value<=100 && command_aux<4) begin
                        volume_overrides[section]<=1;part_volumes[command_aux*8+:8]<=command_value[7:0];
                    end else command_result<=1;
                    26:begin mute_mask<=command_value[3:0];masks_override[section]<=1;end
                    27:begin solo_mask<=command_value[3:0];masks_override[section]<=1;end
                    default:command_result<=8'h7f;
                endcase
            end else if(test_running) begin
                if(test_timer==0) begin test_running<=0;restart_scan();end
                else begin
                    test_timer<=test_timer-1'b1;
                    if(event_valid) begin if(event_ready) begin event_valid<=0;test_index<=test_index+1'b1;end end
                    else if(test_index<test_count) begin
                        event_valid<=1;event_op<=1;event_source<=0;event_id<=16'hf000+test_index;event_velocity<=100;event_timbre<=test_timbre;
                        if(test_count==1) event_note<=test_note;
                        else if(test_count==4) case(test_index) 0:event_note<=60;1:event_note<=64;2:event_note<=67;default:event_note<=71;endcase
                        else event_note<=48+test_index;
                    end
                end
            end else if(parsed && !parser_busy && !parser_error && flags_initialized) begin
                event_source<=2;
                case(state)
                    0:begin snapshot<=tick;section<=0;tempo_index<=0;candidate_tempo<=500000;state<=1;guide_keys<=0;end
                    1:state<=2;
                    2:begin
                        if(section_count!=0 && snapshot>=section_data[63:32] && section+1<section_count) begin section<=section+1'b1;state<=1;end
                        else begin
                            if(section_count!=0) begin
                                part_timbres<=timbre_overrides[section] ? override_timbres_read : section_data[95:64];
                                part_volumes<=volume_overrides[section] ? override_volumes_read : section_data[127:96];
                                mute_mask<=masks_override[section] ? override_masks_read[3:0] : section_data[131:128];
                                solo_mask<=masks_override[section] ? override_masks_read[7:4] : section_data[139:136];
                                live_timbre<=live_override_valid[section] ? override_live_read:section_data[147:144];
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
                        else if(playing && !paused) begin
                            if(held && (end_tick<=snapshot || !part_enabled)) begin
                                event_op<=0;event_id<={4'd0,index};event_valid<=1;state<=8;
                            end else if(!fired && start_tick<=snapshot) begin
                                
                                if(end_tick>snapshot && part_enabled) begin
                                    transposed=$signed({1'b0,note})+$signed(transpose)+$signed(section_transpose);
                                    if(part==3 && part_timbres[part*8+:4]<2) begin drum_triggers[drum_number(note)]<=1;drum_velocities[drum_number(note)*8+:8]<={1'b0,weighted_velocity[22:16]};state<=9;end
                                    else if(transposed>=0 && transposed<=127) begin
                                        event_op<=1;event_id<={4'd0,index};event_note<=transposed[6:0];
                                        event_velocity<=weighted_velocity[22:16];
                                        event_timbre<=part_timbres[part*8+:4];event_valid<=1;state<=8;
                                    end else state<=9;
                                end else state<=9;
                            end else state<=9;
                            if(start_tick>=snapshot && start_tick<snapshot+ppqn && part==0 && note>=60 && note<=75) guide_keys[note-60]<=1;
                        end else state<=0;
                    end
                    8:if(event_valid && event_ready) begin event_valid<=0;state<=9;end
                    9:begin index<=index+1'b1;state<=5;end
                    10:state<=11;
                    11:begin tick<=section_data[31:0];restart_scan();end
                    default:state<=0;
                endcase
            end
        end
    end
endmodule
`default_nettype wire
