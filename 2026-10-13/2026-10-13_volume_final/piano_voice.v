// 实时钢琴近似声部：谐波波表、力度相关起音、
// 变化的频谱、自然衰减和松键制音器。不使用录制的 PCM。
module piano_voice (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               note_on,
    input  wire               note_active,
    input  wire        [31:0] phase_step,
    input  wire        [6:0]  velocity,
    output wire signed [15:0] sample_out
);
    reg [31:0] phase_acc = 32'd0;
    wire [31:0] next_phase = phase_acc + phase_step;
    wire [9:0] rom_addr = sample_tick ? next_phase[31:22] :
                                       phase_acc[31:22];

    reg signed [15:0] attack_table [0:1023];
    reg signed [15:0] body_table   [0:1023];
    reg signed [15:0] tail_table   [0:1023];
    reg signed [15:0] attack_q = 16'sd0;
    reg signed [15:0] body_q = 16'sd0;
    reg signed [15:0] tail_q = 16'sd0;
    initial begin
        $readmemh("mem/piano_attack_1024x16.mem", attack_table);
        $readmemh("mem/piano_body_1024x16.mem", body_table);
        $readmemh("mem/piano_tail_1024x16.mem", tail_table);
    end

    reg [23:0] amplitude = 24'd0;
    reg [23:0] attack_target = 24'd0;
    reg signed [24:0] attack_step = 25'sd0;
    reg [6:0] attack_frames = 7'd0;
    reg [7:0] brightness = 8'd0;
    reg [5:0] brightness_div = 6'd0;
    reg [7:0] body_mix = 8'd0;
    reg [8:0] body_div = 9'd0;

    // 按住时琴弦自己衰减；松开按键则启用
    // 一个快得多的制音器。包络用 24 位是为了保住衰减的精度。
    wire [23:0] held_drop = (amplitude >> 16) + 24'd1;
    wire [23:0] damper_drop = (amplitude >> 11) + 24'd1;
    wire signed [24:0] attack_amplitude_next =
        $signed({1'b0, amplitude}) + attack_step;

    always @(posedge clk) begin
        attack_q <= attack_table[rom_addr];
        body_q   <= body_table[rom_addr];
        tail_q   <= tail_table[rom_addr];

        if (!rst_n) begin
            phase_acc        <= 32'd0;
            amplitude        <= 24'd0;
            attack_target    <= 24'd0;
            attack_step      <= 25'sd0;
            attack_frames    <= 7'd0;
            brightness       <= 8'd0;
            brightness_div   <= 6'd0;
            body_mix         <= 8'd0;
            body_div         <= 9'd0;
        end else if (note_on) begin
            attack_target    <= {velocity, 17'd0};
            attack_step      <= ($signed({1'b0, velocity, 17'd0}) -
                                 $signed({1'b0, amplitude})) >>> 6;
            attack_frames    <= 7'd0;
            brightness       <= {velocity, 1'b0};
            brightness_div   <= 6'd0;
            body_mix         <= 8'hff;
            body_div         <= 9'd0;
            if (amplitude <= 24'd131_072)
                phase_acc     <= 32'd0;
            // 其他情况下保持相位，并从上一个包络值开始变化，
            // 在 64 个音频帧内到达新的力度目标。
        end else if (sample_tick) begin
            phase_acc <= next_phase;

            if (!note_active) begin
                amplitude <= (amplitude > damper_drop) ?
                             amplitude - damper_drop : 24'd0;
            end else if (attack_frames < 7'd64) begin
                amplitude <= (attack_frames == 7'd63) ?
                             attack_target :
                             attack_amplitude_next[23:0];
                attack_frames <= attack_frames + 7'd1;
            end else begin
                amplitude <= (amplitude > held_drop) ?
                             amplitude - held_drop : 24'd0;
            end

            brightness_div <= brightness_div + 6'd1;
            if (brightness_div == 6'd63 && brightness != 8'd0)
                brightness <= brightness - 8'd1;

            body_div <= body_div + 9'd1;
            if (body_div == 9'h1ff && body_mix != 8'd0)
                body_mix <= body_mix - 8'd1;
        end
    end

    // 先把明亮的琴槌谐波过渡到主体频谱，然后
    // 随琴弦延音把整个声音过渡到较安静的尾音。
    wire signed [17:0] attack_ext = {{2{attack_q[15]}}, attack_q};
    wire signed [17:0] body_ext = {{2{body_q[15]}}, body_q};
    wire signed [18:0] tail_ext = {{3{tail_q[15]}}, tail_q};
    wire signed [17:0] attack_delta = attack_ext - body_ext;
    wire signed [26:0] bright_product = attack_delta *
                                         $signed({1'b0, brightness});
    wire signed [26:0] bright_sum =
        $signed({{9{body_ext[17]}}, body_ext}) +
        (bright_product >>> 8);
    reg signed [17:0] bright_wave = 18'sd0;
    wire signed [18:0] body_delta =
        $signed({bright_wave[17], bright_wave}) - tail_ext;
    wire signed [27:0] body_product = body_delta *
                                      $signed({1'b0, body_mix});
    wire signed [27:0] body_sum =
        $signed({{9{tail_ext[18]}}, tail_ext}) +
        (body_product >>> 8);
    reg signed [18:0] piano_wave = 19'sd0;
    reg signed [35:0] amplitude_product = 36'sd0;

    always @(posedge clk) begin
        if (!rst_n) begin
            bright_wave <= 18'sd0;
            piano_wave <= 19'sd0;
            amplitude_product <= 36'sd0;
        end else begin
            bright_wave <= bright_sum[17:0];
            piano_wave <= body_sum[18:0];
            amplitude_product <= $signed(piano_wave) *
                                 $signed({1'b0, amplitude[23:8]});
        end
    end

    assign sample_out = rst_n ? amplitude_product[31:16] : 16'sd0;
endmodule
