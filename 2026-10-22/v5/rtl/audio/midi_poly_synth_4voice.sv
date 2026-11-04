`default_nettype none

// MIDI 音高版本四声部合成器。每声部保存独立相位、力度和 ADSR 包络，
// 与现有 FSR 四声部核心相同地输出三角波或柔和方波。
module midi_poly_synth_4voice #(
    parameter integer MIX_SHIFT = 2,
    parameter [12:0] ATTACK_STEP = 13'd32,
    parameter [12:0] RELEASE_STEP = 13'd16
) (
    input  wire clk,
    input  wire rst_n,
    input  wire sample_tick,
    input  wire [1:0] timbre,
    input  wire note_on_valid,
    input  wire [6:0] note_on_note,
    input  wire [7:0] note_on_velocity,
    input  wire note_off_valid,
    input  wire [6:0] note_off_note,
    output wire signed [15:0] sample_out,
    output wire [3:0] voice_gate,
    output wire [3:0] voice_assigned,
    output wire [31:0] voice_status,
    input wire all_notes_off,
    input wire custom_write_enable,
    input wire [7:0] custom_write_address,
    input wire signed [15:0] custom_write_data,
    input wire [7:0] custom_attack_step,
    input wire [7:0] custom_release_step
);
    wire [3:0] voice_trigger;
    wire [3:0] voice_idle;
    wire [7:0] note0, note1, note2, note3;
    wire [7:0] vel0, vel1, vel2, vel3;
    reg [31:0] phase0;
    reg [31:0] phase1;
    reg [31:0] phase2;
    reg [31:0] phase3;
    wire signed [15:0] table_sample0, table_sample1, table_sample2, table_sample3;
    wire [7:0] wave_address0, wave_address1, wave_address2, wave_address3;
    wire [12:0] attack_step_value = (timbre == 2'd2 && custom_attack_step != 0) ?
                                    {5'd0, custom_attack_step} : ATTACK_STEP;
    wire [12:0] release_step_value = (timbre == 2'd2 && custom_release_step != 0) ?
                                     {5'd0, custom_release_step} : RELEASE_STEP;
    custom_wavetable_reader wave_reader (
        .clk(clk), .write_enable(custom_write_enable), .write_address(custom_write_address),
        .write_data(custom_write_data), .read_address0(wave_address0), .read_address1(wave_address1),
        .read_address2(wave_address2), .read_address3(wave_address3),
        .read_data0(table_sample0), .read_data1(table_sample1),
        .read_data2(table_sample2), .read_data3(table_sample3)
    );
    wire [12:0] level0 = {1'b0, vel0, 4'b0};
    wire [12:0] level1 = {1'b0, vel1, 4'b0};
    wire [12:0] level2 = {1'b0, vel2, 4'b0};
    wire [12:0] level3 = {1'b0, vel3, 4'b0};
    wire signed [15:0] sample0, sample1, sample2, sample3;
    wire signed [12:0] env0, env1, env2, env3;
    wire signed [17:0] sum = {{2{sample0[15]}},sample0} + {{2{sample1[15]}},sample1} +
                              {{2{sample2[15]}},sample2} + {{2{sample3[15]}},sample3};
    wire signed [17:0] scaled = sum >>> MIX_SHIFT;
    reg signed [15:0] saturated;

    function automatic [31:0] note_phase_step;
        input [6:0] note;
        begin
            // 预计算 MIDI 0～127 的相位增量。原先的除法、取模和可变移位
            // 会在一个系统时钟周期内形成很长的算术路径；常量查表保持相同
            // 的 48.828 kHz 频率标定，并让综合器使用浅层多路选择器。
            case (note)
                7'd0: note_phase_step = 32'h000afbea;
                7'd1: note_phase_step = 32'h000ba23e;
                7'd2: note_phase_step = 32'h000c5297;
                7'd3: note_phase_step = 32'h000d0dcd;
                7'd4: note_phase_step = 32'h000dd50d;
                7'd5: note_phase_step = 32'h000ea65e;
                7'd6: note_phase_step = 32'h000f84ca;
                7'd7: note_phase_step = 32'h001070da;
                7'd8: note_phase_step = 32'h00116b5f;
                7'd9: note_phase_step = 32'h00127320;
                7'd10: note_phase_step = 32'h00138b70;
                7'd11: note_phase_step = 32'h0014b478;
                7'd12: note_phase_step = 32'h0015f7d5;
                7'd13: note_phase_step = 32'h0017447d;
                7'd14: note_phase_step = 32'h0018a52e;
                7'd15: note_phase_step = 32'h001a1b9b;
                7'd16: note_phase_step = 32'h001baa1a;
                7'd17: note_phase_step = 32'h001d4cbc;
                7'd18: note_phase_step = 32'h001f0994;
                7'd19: note_phase_step = 32'h0020e1b4;
                7'd20: note_phase_step = 32'h0022d6bf;
                7'd21: note_phase_step = 32'h0024e641;
                7'd22: note_phase_step = 32'h002716e0;
                7'd23: note_phase_step = 32'h002968f0;
                7'd24: note_phase_step = 32'h002befaa;
                7'd25: note_phase_step = 32'h002e88fa;
                7'd26: note_phase_step = 32'h00314a5c;
                7'd27: note_phase_step = 32'h00343736;
                7'd28: note_phase_step = 32'h00375434;
                7'd29: note_phase_step = 32'h003a9978;
                7'd30: note_phase_step = 32'h003e1328;
                7'd31: note_phase_step = 32'h0041c368;
                7'd32: note_phase_step = 32'h0045ad7e;
                7'd33: note_phase_step = 32'h0049cc82;
                7'd34: note_phase_step = 32'h004e2dc0;
                7'd35: note_phase_step = 32'h0052d1e0;
                7'd36: note_phase_step = 32'h0057df54;
                7'd37: note_phase_step = 32'h005d11f4;
                7'd38: note_phase_step = 32'h006294b8;
                7'd39: note_phase_step = 32'h00686e6c;
                7'd40: note_phase_step = 32'h006ea868;
                7'd41: note_phase_step = 32'h007532f0;
                7'd42: note_phase_step = 32'h007c2650;
                7'd43: note_phase_step = 32'h008386d0;
                7'd44: note_phase_step = 32'h008b5afc;
                7'd45: note_phase_step = 32'h00939904;
                7'd46: note_phase_step = 32'h009c5b80;
                7'd47: note_phase_step = 32'h00a5a3c0;
                7'd48: note_phase_step = 32'h00afbea8;
                7'd49: note_phase_step = 32'h00ba23e8;
                7'd50: note_phase_step = 32'h00c52970;
                7'd51: note_phase_step = 32'h00d0dcd8;
                7'd52: note_phase_step = 32'h00dd50d0;
                7'd53: note_phase_step = 32'h00ea65e0;
                7'd54: note_phase_step = 32'h00f84ca0;
                7'd55: note_phase_step = 32'h01070da0;
                7'd56: note_phase_step = 32'h0116b5f8;
                7'd57: note_phase_step = 32'h01273208;
                7'd58: note_phase_step = 32'h0138b700;
                7'd59: note_phase_step = 32'h014b4780;
                7'd60: note_phase_step = 32'h015f7d50;
                7'd61: note_phase_step = 32'h017447d0;
                7'd62: note_phase_step = 32'h018a52e0;
                7'd63: note_phase_step = 32'h01a1b9b0;
                7'd64: note_phase_step = 32'h01baa1a0;
                7'd65: note_phase_step = 32'h01d4cbc0;
                7'd66: note_phase_step = 32'h01f09940;
                7'd67: note_phase_step = 32'h020e1b40;
                7'd68: note_phase_step = 32'h022d6bf0;
                7'd69: note_phase_step = 32'h024e6410;
                7'd70: note_phase_step = 32'h02716e00;
                7'd71: note_phase_step = 32'h02968f00;
                7'd72: note_phase_step = 32'h02befaa0;
                7'd73: note_phase_step = 32'h02e88fa0;
                7'd74: note_phase_step = 32'h0314a5c0;
                7'd75: note_phase_step = 32'h03437360;
                7'd76: note_phase_step = 32'h03754340;
                7'd77: note_phase_step = 32'h03a99780;
                7'd78: note_phase_step = 32'h03e13280;
                7'd79: note_phase_step = 32'h041c3680;
                7'd80: note_phase_step = 32'h045ad7e0;
                7'd81: note_phase_step = 32'h049cc820;
                7'd82: note_phase_step = 32'h04e2dc00;
                7'd83: note_phase_step = 32'h052d1e00;
                7'd84: note_phase_step = 32'h057df540;
                7'd85: note_phase_step = 32'h05d11f40;
                7'd86: note_phase_step = 32'h06294b80;
                7'd87: note_phase_step = 32'h0686e6c0;
                7'd88: note_phase_step = 32'h06ea8680;
                7'd89: note_phase_step = 32'h07532f00;
                7'd90: note_phase_step = 32'h07c26500;
                7'd91: note_phase_step = 32'h08386d00;
                7'd92: note_phase_step = 32'h08b5afc0;
                7'd93: note_phase_step = 32'h09399040;
                7'd94: note_phase_step = 32'h09c5b800;
                7'd95: note_phase_step = 32'h0a5a3c00;
                7'd96: note_phase_step = 32'h0afbea80;
                7'd97: note_phase_step = 32'h0ba23e80;
                7'd98: note_phase_step = 32'h0c529700;
                7'd99: note_phase_step = 32'h0d0dcd80;
                7'd100: note_phase_step = 32'h0dd50d00;
                7'd101: note_phase_step = 32'h0ea65e00;
                7'd102: note_phase_step = 32'h0f84ca00;
                7'd103: note_phase_step = 32'h1070da00;
                7'd104: note_phase_step = 32'h116b5f80;
                7'd105: note_phase_step = 32'h12732080;
                7'd106: note_phase_step = 32'h138b7000;
                7'd107: note_phase_step = 32'h14b47800;
                7'd108: note_phase_step = 32'h15f7d500;
                7'd109: note_phase_step = 32'h17447d00;
                7'd110: note_phase_step = 32'h18a52e00;
                7'd111: note_phase_step = 32'h1a1b9b00;
                7'd112: note_phase_step = 32'h1baa1a00;
                7'd113: note_phase_step = 32'h1d4cbc00;
                7'd114: note_phase_step = 32'h1f099400;
                7'd115: note_phase_step = 32'h20e1b400;
                7'd116: note_phase_step = 32'h22d6bf00;
                7'd117: note_phase_step = 32'h24e64100;
                7'd118: note_phase_step = 32'h2716e000;
                7'd119: note_phase_step = 32'h2968f000;
                7'd120: note_phase_step = 32'h2befaa00;
                7'd121: note_phase_step = 32'h2e88fa00;
                7'd122: note_phase_step = 32'h314a5c00;
                7'd123: note_phase_step = 32'h34373600;
                7'd124: note_phase_step = 32'h37543400;
                7'd125: note_phase_step = 32'h3a997800;
                7'd126: note_phase_step = 32'h3e132800;
                7'd127: note_phase_step = 32'h41c36800;
                default: note_phase_step = 32'd0;
            endcase
        end
    endfunction

    midi_voice_allocator_4 allocator (
        .clk(clk), .rst_n(rst_n),
        .note_on_valid(note_on_valid), .note_on_note(note_on_note), .note_on_velocity(note_on_velocity),
        .note_off_valid(note_off_valid), .note_off_note(note_off_note),
        .all_notes_off(all_notes_off), .voice_idle(voice_idle),
        .voice_gate(voice_gate), .voice_trigger(voice_trigger), .voice_assigned(voice_assigned),
        .voice_note0(note0), .voice_note1(note1), .voice_note2(note2), .voice_note3(note3),
        .voice_velocity0(vel0), .voice_velocity1(vel1), .voice_velocity2(vel2), .voice_velocity3(vel3)
    );

    // MIDI 音高到相位增量包含音级选择和八度移位。先把结果寄存，再送入
    // 相位累加器，避免一拍内同时完成查表、移位和 32 位加法。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase0 <= 32'd0;
            phase1 <= 32'd0;
            phase2 <= 32'd0;
            phase3 <= 32'd0;
        end else begin
            phase0 <= note_phase_step(note0[6:0]);
            phase1 <= note_phase_step(note1[6:0]);
            phase2 <= note_phase_step(note2[6:0]);
            phase3 <= note_phase_step(note3[6:0]);
        end
    end

    midi_poly_voice v0 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(voice_gate[0]), .retrigger(voice_trigger[0]), .timbre(timbre),
        .phase_step(phase0), .target_level(level0), .attack_step(attack_step_value), .release_step(release_step_value),
        .custom_sample(table_sample0), .wave_address(wave_address0), .sample_out(sample0), .current_level(env0), .idle(voice_idle[0])
    );
    midi_poly_voice v1 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(voice_gate[1]), .retrigger(voice_trigger[1]), .timbre(timbre),
        .phase_step(phase1), .target_level(level1), .attack_step(attack_step_value), .release_step(release_step_value),
        .custom_sample(table_sample1), .wave_address(wave_address1), .sample_out(sample1), .current_level(env1), .idle(voice_idle[1])
    );
    midi_poly_voice v2 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(voice_gate[2]), .retrigger(voice_trigger[2]), .timbre(timbre),
        .phase_step(phase2), .target_level(level2), .attack_step(attack_step_value), .release_step(release_step_value),
        .custom_sample(table_sample2), .wave_address(wave_address2), .sample_out(sample2), .current_level(env2), .idle(voice_idle[2])
    );
    midi_poly_voice v3 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(voice_gate[3]), .retrigger(voice_trigger[3]), .timbre(timbre),
        .phase_step(phase3), .target_level(level3), .attack_step(attack_step_value), .release_step(release_step_value),
        .custom_sample(table_sample3), .wave_address(wave_address3), .sample_out(sample3), .current_level(env3), .idle(voice_idle[3])
    );

    always @(*) begin
        if (scaled > 18'sd32767) saturated = 16'sh7fff;
        else if (scaled < -18'sd32768) saturated = -16'sd32768;
        else saturated = scaled[15:0];
    end
    assign sample_out = saturated;
    assign voice_status = {env3[12:5], env2[12:5], env1[12:5], env0[12:5]};
endmodule

// 单声部三角波/柔和方波和包络实现。
module midi_poly_voice (
    input wire clk, input wire rst_n, input wire sample_tick,
    input wire gate, input wire retrigger, input wire [1:0] timbre,
    input wire [31:0] phase_step, input wire [12:0] target_level,
    input wire [12:0] attack_step, input wire [12:0] release_step,
    input wire signed [15:0] custom_sample,
    output wire [7:0] wave_address,
    output reg signed [15:0] sample_out, output reg signed [12:0] current_level, output wire idle
);
    localparam [2:0] ENV_IDLE    = 3'd0;
    localparam [2:0] ENV_ATTACK  = 3'd1;
    localparam [2:0] ENV_DECAY   = 3'd2;
    localparam [2:0] ENV_SUSTAIN = 3'd3;
    localparam [2:0] ENV_RELEASE = 3'd4;
    localparam [12:0] DECAY_STEP = 13'd8;

    reg [31:0] phase;
    reg [7:0] blend;
    reg [2:0] envelope_stage;
    wire [12:0] sustain_level = target_level - (target_level >> 2);
    wire [12:0] folded = phase[31] ? ~phase[30:18] : phase[30:18];
    wire signed [15:0] triangle = ($signed({1'b0, folded}) - 16'sd4096) <<< 1;
    wire signed [15:0] square = phase[31] ? 16'sd4096 : -16'sd4096;
    wire signed [16:0] delta = {square[15], square} - {triangle[15], triangle};
    wire signed [24:0] blended_delta = delta * $signed({1'b0, blend});
    wire signed [16:0] blend_add = blended_delta >>> 8;
    wire signed [16:0] waveform = {triangle[15], triangle} + blend_add;
    wire signed [15:0] waveform_sample = waveform[15:0];
    wire signed [15:0] selected = (timbre == 2'd2) ? custom_sample :
                                   ((blend == 8'hff) ? square : waveform_sample);
    reg signed [15:0] waveform_pipeline;
    wire signed [28:0] scaled = waveform_pipeline * $signed({1'b0, current_level});
    wire signed [28:0] scaled_shifted = scaled >>> 12;
    assign idle = !gate && current_level == 0;
    assign wave_address = phase[31:24];

    // 与实时压力声部相同，波形选择和力度乘法各占一级流水。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            waveform_pipeline <= 16'sd0;
            sample_out <= 16'sd0;
        end else begin
            waveform_pipeline <= selected;
            sample_out <= scaled_shifted[15:0];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 32'd0;
            current_level <= 13'd0;
            blend <= 8'd0;
            envelope_stage <= ENV_IDLE;
        end else if (retrigger) begin
            phase <= 32'd0;
            current_level <= 13'd0;
            blend <= 8'd0;
            envelope_stage <= ENV_ATTACK;
        end else if (sample_tick) begin
            if (gate || current_level != 0) phase <= phase + phase_step;
            else phase <= 32'd0;

            if (!gate) begin
                envelope_stage <= ENV_RELEASE;
                if (current_level <= release_step) begin
                    current_level <= 13'd0;
                    envelope_stage <= ENV_IDLE;
                end else begin
                    current_level <= current_level - release_step;
                end
            end else begin
                case (envelope_stage)
                    ENV_IDLE, ENV_ATTACK: begin
                        envelope_stage <= ENV_ATTACK;
                        if (current_level >= target_level ||
                            target_level - current_level <= attack_step) begin
                            current_level <= target_level;
                            envelope_stage <= ENV_DECAY;
                        end else begin
                            current_level <= current_level + attack_step;
                        end
                    end
                    ENV_DECAY: begin
                        if (current_level <= sustain_level + DECAY_STEP) begin
                            current_level <= sustain_level;
                            envelope_stage <= ENV_SUSTAIN;
                        end else begin
                            current_level <= current_level - DECAY_STEP;
                        end
                    end
                    ENV_SUSTAIN: current_level <= sustain_level;
                    default: envelope_stage <= ENV_ATTACK;
                endcase
            end
            if (timbre == 2'd1 && blend < 8'hff) blend <= (blend > 8'd246) ? 8'hff : blend + 8'd8;
            else if (timbre != 2'd1 && blend != 0) blend <= (blend < 8'd8) ? 8'd0 : blend - 8'd8;
        end
    end
endmodule

`default_nettype wire
