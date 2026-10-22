`timescale 1ns/1ps
`default_nettype none

module tb_video_1024x600;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire [10:0] x;
    wire [9:0] y;
    wire de;
    wire hs_n;
    wire vs_n;
    wire frame_start;
    wire [23:0] rgb;
    reg enc_de = 1'b0;
    reg c0 = 1'b0;
    reg c1 = 1'b0;
    reg [7:0] pixel = 8'd0;
    wire [9:0] symbol;
    integer active_count = 0;
    integer hsync_low_count = 0;
    integer vsync_low_count = 0;
    integer n;
    integer j;
    integer ones;
    integer running_disparity = 0;
    reg [7:0] qm;
    reg [7:0] decoded;
    reg [7:0] wanted;
    reg [9:0] expected_token;

    always #5 clk = ~clk;

    video_timing u_timing (
        .clk(clk), .rst_n(rst_n), .x(x), .y(y),
        .de(de), .hs_n(hs_n), .vs_n(vs_n), .frame_start(frame_start)
    );

    pressure_audio_ui_1024x600 u_ui (
        .x(x), .y(y), .pressure(12'd224), .volume(13'd4096),
        .gate(1'b1), .adc_ready(1'b1), .calibrated(1'b1),
        .audio_ready(1'b1), .fault(1'b0), .rgb(rgb)
    );

    tmds_encoder u_encoder (
        .clk(clk), .rst_n(rst_n), .de(enc_de), .c0(c0), .c1(c1),
        .data(pixel), .symbol(symbol)
    );

    initial begin
        #12 rst_n = 1'b1;

        // 核对四种消隐控制码以及数据编码可逆、累计直流偏差受控。
        for (n = 0; n < 4; n = n + 1) begin
            @(negedge clk);
            enc_de = 1'b0;
            {c1, c0} = n;
            @(posedge clk); #1;
            case (n)
                0: expected_token = 10'b1101010100;
                1: expected_token = 10'b0010101011;
                2: expected_token = 10'b0101010100;
                3: expected_token = 10'b1010101011;
            endcase
            if (symbol !== expected_token)
                $fatal(1, "TMDS control token mismatch");
        end

        for (n = 0; n < 1024; n = n + 1) begin
            @(negedge clk);
            enc_de = 1'b1;
            pixel = (n * 73 + n / 256) % 256;
            wanted = pixel;
            @(posedge clk); #1;
            qm = symbol[9] ? ~symbol[7:0] : symbol[7:0];
            decoded[0] = qm[0];
            for (j = 1; j < 8; j = j + 1)
                decoded[j] = symbol[8] ? qm[j] ^ qm[j-1] : ~(qm[j] ^ qm[j-1]);
            if (decoded !== wanted)
                $fatal(1, "TMDS decode mismatch");
            ones = 0;
            for (j = 0; j < 10; j = j + 1)
                ones = ones + symbol[j];
            running_disparity = running_disparity + 2*ones - 10;
            if (running_disparity > 8 || running_disparity < -8)
                $fatal(1, "TMDS DC imbalance: %0d", running_disparity);
        end
    end

    initial begin
        wait(rst_n);
        @(negedge clk);
        wait(frame_start);
        repeat (1_344 * 635) begin
            @(negedge clk);
            if (de) active_count = active_count + 1;
            if (!hs_n) hsync_low_count = hsync_low_count + 1;
            if (!vs_n) vsync_low_count = vsync_low_count + 1;

            if (x == 50 && y == 50 && rgb !== 24'h20_cc_88)
                $fatal(1, "ready status color mismatch");
            if (x == 200 && y == 470 && rgb !== 24'h37_b8_ee)
                $fatal(1, "pressure bar color mismatch");
            if (x == 700 && y == 470 && rgb !== 24'hb0_72_ff)
                $fatal(1, "volume bar color mismatch");
            if (x == 480 && y == 450 && rgb !== 24'h20_d8_9b)
                $fatal(1, "gate indicator color mismatch");
        end

        if (active_count != 1024 * 600)
            $fatal(1, "active pixel count mismatch: %0d", active_count);
        if (hsync_low_count != 20 * 635)
            $fatal(1, "HSYNC width mismatch: %0d", hsync_low_count);
        if (vsync_low_count != 3 * 1344)
            $fatal(1, "VSYNC width mismatch: %0d", vsync_low_count);

        $display("PASS tb_video_1024x600");
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "video test timeout");
    end
endmodule

`default_nettype wire
