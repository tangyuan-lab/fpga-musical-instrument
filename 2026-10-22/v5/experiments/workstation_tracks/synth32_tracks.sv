`default_nettype none
// 32个独立振荡器状态，按固定9拍时隙计算；50MHz下288拍完成一帧，
// 低于1024拍采样周期。音符命令只在帧间提交，避免同一状态读写冲突。
// source=0实体、1屏幕、2伴奏、3测试；0..3号槽仅实时输入可以使用。
module synth32_tracks #(
    parameter integer VOICES=32
)(
    input wire clk,rst_n,sample_tick,panic,
    input wire command_valid, output wire command_ready,
    input wire [1:0] command_op,command_source,
    input wire [15:0] command_id,
    input wire [6:0] command_note,command_velocity,
    input wire [3:0] command_timbre,
    input wire [4:0] command_owner,
    input wire gain_valid,output wire gain_ready,input wire [4:0] gain_owner,input wire [15:0] gain_target,
    output wire gain_done,gain_error,output reg sample_done,
    input wire [7:0] custom_ready,
    input wire signed [13:0] bend,
    input wire [7:0] vibrato_depth,vibrato_rate,
    input wire table_write,input wire [10:0] table_address,input wire signed [15:0] table_data,
    input wire parameter_write,input wire [3:0] parameter_bank,
    input wire [11:0] attack_step,decay_step,sustain_level,release_step,
    output reg signed [15:0] pcm,
    output reg [5:0] voice_count,
    output wire [31:0] active_mask,
    output wire deadline_error
);
    wire frame_tick,gain_initialized,gain_deadline;
    wire [15:0] owner_gain;reg voice_deadline_error;
    reg [4:0] pending_owner,owner_read;
    // 归属只在新起音提交时写入，普通改音量不改相位、音色、包络或原始力度。
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [4:0] voice_owner[0:31];
    track_gain_bank #(.OWNERS(18)) gains(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .command_valid(gain_valid),.command_ready(gain_ready),.command_owner(gain_owner),.command_gain(gain_target),
        .command_done(gain_done),.command_error(gain_error),.read_owner(owner_read),.read_gain(owner_gain),
        .initialized(gain_initialized),.frame_done(frame_tick),.deadline_error(gain_deadline));
    assign deadline_error=voice_deadline_error || gain_deadline;
    reg active[0:VOICES-1],gate[0:VOICES-1];
    reg [1:0] source[0:VOICES-1];reg [15:0] identity[0:VOICES-1];
    reg [6:0] note[0:VOICES-1],velocity[0:VOICES-1];
    reg [3:0] timbre[0:VOICES-1];
    reg [31:0] phase[0:VOICES-1];reg [11:0] envelope[0:VOICES-1];
    reg [2:0] stage[0:VOICES-1];reg [15:0] age[0:VOICES-1];reg [15:0] serial;
    reg [11:0] atk[0:9],dec[0:9],sus[0:9],rel[0:9];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg signed [15:0] waves[0:2047];
    reg [10:0] read_address;reg signed [15:0] wave_read;
    always @(posedge clk) begin
        if(table_write) waves[table_address]<=table_data;
        wave_read<=waves[read_address];
    end
    reg busy;reg [3:0] step;reg [5:0] slot;
    reg [5:0] frame_voice_count;
    reg [31:0] next_phase,increment;
    reg [11:0] next_envelope;reg [2:0] next_stage;
    reg signed [15:0] waveform;
    reg signed [28:0] product;
    reg signed [35:0] sum;
    reg signed [36:0] velocity_product;
    reg signed [53:0] gain_product;
    reg [31:0] lfo;wire [7:0] lfo_magnitude=lfo[30] ? ~lfo[29:22]:lfo[29:22];
    wire signed [8:0] lfo_triangle=lfo[31] ? -$signed({1'b0,lfo_magnitude}) : $signed({1'b0,lfo_magnitude});
    wire signed [21:0] modulation=$signed(lfo_triangle)*$signed({1'b0,vibrato_depth});
    // depth=255约±一个半音；速率单位Hz。三角LFO在半周期及周期边界连续。
    wire signed [13:0] total_bend=$signed(bend)+14'($signed(modulation)>>>4);
    reg signed [47:0] pitch_product;
    integer i;
    reg [1:0] allocation_state,pending_op,pending_source;
    reg [15:0] pending_id,oldest_age;
    reg [6:0] pending_note,pending_velocity;
    reg [3:0] pending_timbre;
    reg [5:0] allocation_slot,match_slot,free_slot,oldest_slot;
    reg match_valid,free_valid,oldest_valid;
    wire [5:0] chosen_slot=match_valid ? match_slot:free_valid ? free_slot:oldest_slot;
    // 每拍扫描一个槽，共32拍加一次提交；音频计算期间暂停，不与振荡器状态写冲突。
    assign command_ready=!busy && allocation_state==0 && !frame_tick && !panic && gain_initialized;
    genvar g;generate for(g=0;g<VOICES;g=g+1) begin:g_active
        assign active_mask[g]=active[g];
    end endgenerate
    wire owner_write=rst_n && !panic && !busy && !frame_tick && allocation_state==2 && pending_op==1 &&
        pending_owner<18 && pending_timbre<10 && (pending_timbre<2 || custom_ready[pending_timbre-2]) &&
        (match_valid || free_valid || oldest_valid);
    always @(posedge clk) begin
        owner_read<=voice_owner[slot];
        if(owner_write) voice_owner[chosen_slot]<=pending_owner;
    end
    // 相位步进以实际Fs=50MHz/1024计算；由生成脚本输出128项常量。
    function automatic [31:0] pitch(input [6:0] n);
        begin
            case(n)
                7'd0:pitch=32'd719151;
                7'd1:pitch=32'd761914;
                7'd2:pitch=32'd807220;
                7'd3:pitch=32'd855219;
                7'd4:pitch=32'd906073;
                7'd5:pitch=32'd959951;
                7'd6:pitch=32'd1017033;
                7'd7:pitch=32'd1077509;
                7'd8:pitch=32'd1141581;
                7'd9:pitch=32'd1209463;
                7'd10:pitch=32'd1281381;
                7'd11:pitch=32'd1357576;
                7'd12:pitch=32'd1438302;
                7'd13:pitch=32'd1523828;
                7'd14:pitch=32'd1614439;
                7'd15:pitch=32'd1710439;
                7'd16:pitch=32'd1812147;
                7'd17:pitch=32'd1919903;
                7'd18:pitch=32'd2034066;
                7'd19:pitch=32'd2155018;
                7'd20:pitch=32'd2283162;
                7'd21:pitch=32'd2418926;
                7'd22:pitch=32'd2562762;
                7'd23:pitch=32'd2715152;
                7'd24:pitch=32'd2876604;
                7'd25:pitch=32'd3047655;
                7'd26:pitch=32'd3228878;
                7'd27:pitch=32'd3420877;
                7'd28:pitch=32'd3624293;
                7'd29:pitch=32'd3839805;
                7'd30:pitch=32'd4068132;
                7'd31:pitch=32'd4310035;
                7'd32:pitch=32'd4566323;
                7'd33:pitch=32'd4837851;
                7'd34:pitch=32'd5125525;
                7'd35:pitch=32'd5430304;
                7'd36:pitch=32'd5753207;
                7'd37:pitch=32'd6095311;
                7'd38:pitch=32'd6457757;
                7'd39:pitch=32'd6841755;
                7'd40:pitch=32'd7248587;
                7'd41:pitch=32'd7679610;
                7'd42:pitch=32'd8136263;
                7'd43:pitch=32'd8620071;
                7'd44:pitch=32'd9132647;
                7'd45:pitch=32'd9675702;
                7'd46:pitch=32'd10251050;
                7'd47:pitch=32'd10860609;
                7'd48:pitch=32'd11506414;
                7'd49:pitch=32'd12190621;
                7'd50:pitch=32'd12915513;
                7'd51:pitch=32'd13683509;
                7'd52:pitch=32'd14497173;
                7'd53:pitch=32'd15359220;
                7'd54:pitch=32'd16272527;
                7'd55:pitch=32'd17240142;
                7'd56:pitch=32'd18265294;
                7'd57:pitch=32'd19351405;
                7'd58:pitch=32'd20502099;
                7'd59:pitch=32'd21721217;
                7'd60:pitch=32'd23012828;
                7'd61:pitch=32'd24381242;
                7'd62:pitch=32'd25831026;
                7'd63:pitch=32'd27367019;
                7'd64:pitch=32'd28994347;
                7'd65:pitch=32'd30718440;
                7'd66:pitch=32'd32545054;
                7'd67:pitch=32'd34480283;
                7'd68:pitch=32'd36530588;
                7'd69:pitch=32'd38702809;
                7'd70:pitch=32'd41004198;
                7'd71:pitch=32'd43442435;
                7'd72:pitch=32'd46025656;
                7'd73:pitch=32'd48762484;
                7'd74:pitch=32'd51662052;
                7'd75:pitch=32'd54734038;
                7'd76:pitch=32'd57988693;
                7'd77:pitch=32'd61436880;
                7'd78:pitch=32'd65090107;
                7'd79:pitch=32'd68960566;
                7'd80:pitch=32'd73061175;
                7'd81:pitch=32'd77405619;
                7'd82:pitch=32'd82008396;
                7'd83:pitch=32'd86884869;
                7'd84:pitch=32'd92051312;
                7'd85:pitch=32'd97524968;
                7'd86:pitch=32'd103324105;
                7'd87:pitch=32'd109468076;
                7'd88:pitch=32'd115977386;
                7'd89:pitch=32'd122873760;
                7'd90:pitch=32'd130180214;
                7'd91:pitch=32'd137921133;
                7'd92:pitch=32'd146122350;
                7'd93:pitch=32'd154811237;
                7'd94:pitch=32'd164016792;
                7'd95:pitch=32'd173769738;
                7'd96:pitch=32'd184102625;
                7'd97:pitch=32'd195049936;
                7'd98:pitch=32'd206648209;
                7'd99:pitch=32'd218936151;
                7'd100:pitch=32'd231954772;
                7'd101:pitch=32'd245747521;
                7'd102:pitch=32'd260360429;
                7'd103:pitch=32'd275842266;
                7'd104:pitch=32'd292244700;
                7'd105:pitch=32'd309622474;
                7'd106:pitch=32'd328033585;
                7'd107:pitch=32'd347539477;
                7'd108:pitch=32'd368205249;
                7'd109:pitch=32'd390099873;
                7'd110:pitch=32'd413296419;
                7'd111:pitch=32'd437872302;
                7'd112:pitch=32'd463909545;
                7'd113:pitch=32'd491495042;
                7'd114:pitch=32'd520720858;
                7'd115:pitch=32'd551684531;
                7'd116:pitch=32'd584489400;
                7'd117:pitch=32'd619244949;
                7'd118:pitch=32'd656067170;
                7'd119:pitch=32'd695078954;
                7'd120:pitch=32'd736410499;
                7'd121:pitch=32'd780199746;
                7'd122:pitch=32'd826592837;
                7'd123:pitch=32'd875744605;
                7'd124:pitch=32'd927819089;
                7'd125:pitch=32'd982990083;
                7'd126:pitch=32'd1041441715;
                7'd127:pitch=32'd1103369062;

                default:pitch=0;
            endcase
        end
    endfunction
    function automatic signed [15:0] triangle(input [31:0] p);
        reg [14:0] folded;
        begin folded=p[31] ? ~p[30:16] : p[30:16];triangle=$signed({1'b0,folded})-16'sd16384;end
    endfunction
    always @(posedge clk) begin
        sample_done<=0;
        if(!rst_n) begin
            pcm<=0;voice_count<=0;frame_voice_count<=0;busy<=0;step<=0;slot<=0;sum<=0;serial<=0;
            lfo<=0;voice_deadline_error<=0;read_address<=0;next_phase<=0;next_envelope<=0;
            next_stage<=0;waveform<=0;product<=0;increment<=0;pitch_product<=0;
            allocation_state<=0;allocation_slot<=0;match_slot<=0;free_slot<=0;oldest_slot<=0;
            match_valid<=0;free_valid<=0;oldest_valid<=0;oldest_age<=0;
            velocity_product<=0;gain_product<=0;pending_owner<=0;
            pending_op<=0;pending_source<=0;pending_id<=0;pending_note<=0;pending_velocity<=0;pending_timbre<=0;
            for(i=0;i<VOICES;i=i+1) begin
                active[i]<=0;gate[i]<=0;phase[i]<=0;envelope[i]<=0;stage[i]<=0;
                source[i]<=0;identity[i]<=0;note[i]<=0;velocity[i]<=0;timbre[i]<=0;age[i]<=0;
            end
            for(i=0;i<10;i=i+1) begin atk[i]<=64;dec[i]<=8;sus[i]<=3072;rel[i]<=32;end
            // 拨弦音快速起音、明显衰减；管乐音起音较缓、维持较强。
            atk[0]<=256;dec[0]<=5;sus[0]<=1024;rel[0]<=24;
            atk[1]<=16;dec[1]<=4;sus[1]<=3500;rel[1]<=12;
        end else if(panic) begin
            busy<=0;pcm<=0;sum<=0;voice_count<=0;frame_voice_count<=0;allocation_state<=0;
            for(i=0;i<VOICES;i=i+1) begin active[i]<=0;gate[i]<=0;envelope[i]<=0;stage[i]<=0;end
        end else begin
            if(parameter_write && parameter_bank<10) begin
                atk[parameter_bank]<=attack_step==0 ? 1 : attack_step;
                dec[parameter_bank]<=decay_step==0 ? 1 : decay_step;
                sus[parameter_bank]<=sustain_level;
                rel[parameter_bank]<=release_step==0 ? 1 : release_step;
            end
            if(command_valid && command_ready) begin
                pending_op<=command_op;pending_source<=command_source;pending_id<=command_id;
                pending_owner<=command_owner;
                pending_note<=command_note;pending_velocity<=command_velocity;pending_timbre<=command_timbre;
                match_valid<=0;free_valid<=0;oldest_valid<=0;oldest_age<=16'hffff;
                allocation_slot<=0;allocation_state<=1;
            end else if(!busy && !frame_tick) begin
                if(allocation_state==1) begin
                    if(active[allocation_slot] && identity[allocation_slot]==pending_id && source[allocation_slot]==pending_source) begin
                        match_valid<=1;match_slot<=allocation_slot;
                    end
                    if(!free_valid && !active[allocation_slot] && (pending_source<2 || allocation_slot>=4)) begin
                        free_valid<=1;free_slot<=allocation_slot;
                    end
                    if(allocation_slot>=4 && age[allocation_slot]<=oldest_age) begin
                        oldest_valid<=1;oldest_slot<=allocation_slot;oldest_age<=age[allocation_slot];
                    end
                    if(allocation_slot==VOICES-1) allocation_state<=2;
                    else allocation_slot<=allocation_slot+1'b1;
                end else if(allocation_state==2) begin
                    allocation_state<=0;
                    if(pending_op==0 || pending_op==2 || pending_op==3) begin
                        if(match_valid) begin
                            if(pending_op==0) gate[match_slot]<=0;
                            else begin velocity[match_slot]<=pending_velocity;if(pending_op==3) note[match_slot]<=pending_note;end
                        end
                    end else if(pending_op==1 && pending_owner<18 && pending_timbre<10 &&
                        (pending_timbre<2 || custom_ready[pending_timbre-2]) && (match_valid || free_valid || oldest_valid)) begin
                        // 实时输入优先取低编号空槽；伴奏不可使用或抢占0..3保留槽。
                        active[chosen_slot]<=1;gate[chosen_slot]<=1;source[chosen_slot]<=pending_source;
                        identity[chosen_slot]<=pending_id;note[chosen_slot]<=pending_note;velocity[chosen_slot]<=pending_velocity;
                        timbre[chosen_slot]<=pending_timbre;phase[chosen_slot]<=0;envelope[chosen_slot]<=0;stage[chosen_slot]<=1;
                        age[chosen_slot]<=serial;serial<=serial+1'b1;
                    end
                end
            end
            if(frame_tick) begin
                if(busy) voice_deadline_error<=1;
                else begin busy<=1;slot<=0;step<=0;sum<=0;frame_voice_count<=0;end
                lfo<=lfo+{24'd0,vibrato_rate}*32'd87961;
            end else if(busy) begin
                case(step)
                    0: begin
                        increment<=pitch(note[slot]);
                        if(total_bend>=0) pitch_product<=$signed({1'b0,(note[slot]==127 ? 32'd0:pitch(note[slot]+7'd1)-pitch(note[slot]))})*$signed(total_bend);
                        else pitch_product<=$signed({1'b0,(note[slot]==0 ? 32'd0:pitch(note[slot])-pitch(note[slot]-7'd1))})*$signed(total_bend);
                        step<=1;
                    end
                    1: begin
                        // bend=±4096为±一个半音，端点使用相邻音高精确步进，保持相位连续。
                        next_phase<=phase[slot]+increment+32'($signed(pitch_product)>>>12);
                        next_envelope<=envelope[slot];next_stage<=stage[slot];
                        if(!gate[slot]) begin
                            next_stage<=4;
                            next_envelope<=envelope[slot]<=rel[timbre[slot]] ? 0 : envelope[slot]-rel[timbre[slot]];
                        end else case(stage[slot])
                            1: if(4095-envelope[slot]<=atk[timbre[slot]]) begin next_envelope<=4095;next_stage<=2;end
                               else next_envelope<=envelope[slot]+atk[timbre[slot]];
                            2: if(envelope[slot]<=sus[timbre[slot]] || envelope[slot]-sus[timbre[slot]]<=dec[timbre[slot]]) begin
                                   next_envelope<=sus[timbre[slot]];next_stage<=3;end
                               else next_envelope<=envelope[slot]-dec[timbre[slot]];
                            3: next_envelope<=sus[timbre[slot]];
                            default:next_stage<=1;
                        endcase
                        read_address<={3'(timbre[slot]-2),phase[slot][31:24]};step<=2;
                    end
                    2: step<=3; // 同步BSRAM读口延迟。
                    3: begin
                        if(timbre[slot]>=2) waveform<=wave_read>>>1;
                        else if(timbre[slot]==0) waveform<=triangle(phase[slot])+(triangle(phase[slot]<<1)>>>2);
                        else waveform<=triangle(phase[slot])+(triangle(phase[slot]*3)>>>3);
                        step<=4;
                    end
                    4: begin product<=$signed(waveform)*$signed({1'b0,next_envelope});step<=5;end
                    // 后级Q1.15增益拆为两个DSP时隙；37+17位乘法保留完整54位结果。
                    5: begin velocity_product<=$signed(product)*$signed({1'b0,velocity[slot]});step<=6;end
                    6: begin gain_product<=$signed(velocity_product)*$signed({1'b0,owner_gain});step<=7;end
                    7: begin
                        if(active[slot]) begin
                            sum<=sum+($signed(gain_product)>>>34);
                            phase[slot]<=next_phase;envelope[slot]<=next_envelope;stage[slot]<=next_stage;
                            if(!gate[slot] && next_envelope==0) active[slot]<=0;
                            else frame_voice_count<=frame_voice_count+1'b1;
                        end
                        step<=8;
                    end
                    8: begin
                        if(slot==VOICES-1) begin
                            // 统计与PCM同帧提交，外部状态查询不再读到计算中间值。
                            voice_count<=frame_voice_count;sample_done<=1;
                            if((sum>>>3)>32767) pcm<=32767;
                            else if((sum>>>3)<-32768) pcm<=-32768;
                            else pcm<=16'(sum>>>3);
                            busy<=0;
                        end else begin slot<=slot+1'b1;step<=0;end
                    end
                    default:begin busy<=0;voice_deadline_error<=1;end
                endcase
            end
        end
    end
endmodule
`default_nettype wire
