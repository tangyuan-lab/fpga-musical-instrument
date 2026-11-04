`timescale 1ns/1ps
`default_nettype none

module tb_serial_screen_nextion16_tx;
    localparam integer CLKS_PER_BIT = 16;
    localparam integer BIT_NS = CLKS_PER_BIT * 10;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [191:0] pressure_values = 192'd0;
    reg [4:0] active_key_count = 5'd16;
    reg midi_mode = 1'b0;
    reg audio_ready = 1'b1;
    reg file_ready = 1'b0;
    reg parser_busy = 1'b1;
    reg playing = 1'b0;
    reg screen_rx_i = 1'b1;
    wire screen_tx_o;
    wire rx_activity;
    reg [7:0] received [0:4095];
    reg [7:0] decoded;
    integer received_count = 0;
    integer checked_count = 0;
    integer bit_index;
    integer key_index;

    always #5 clk = ~clk;

    serial_screen_nextion_tx #(
        .KEY_COUNT(16), .CLKS_PER_BIT(CLKS_PER_BIT), .STARTUP_DELAY_CYCLES(32),
        .UPDATE_PERIOD_CYCLES(100)
    ) dut (
        .clk(clk), .rst_n(rst_n), .pressure_values(pressure_values),
        .active_key_count(active_key_count), .midi_mode(midi_mode),
        .audio_ready(audio_ready), .file_ready(file_ready),
        .parser_busy(parser_busy), .playing(playing),
        .screen_rx_i(screen_rx_i), .screen_tx_o(screen_tx_o), .rx_activity(rx_activity)
    );

    // 独立按位采样 FPGA TX 引脚：验证真实发送字节，而非内部启动寄存器。
    initial forever begin
        @(negedge screen_tx_o);
        if (rst_n) begin
            #(BIT_NS/2);
            if (screen_tx_o !== 1'b0)
                $fatal(1, "invalid UART start bit");
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                #(BIT_NS);
                decoded[bit_index] = screen_tx_o;
            end
            #(BIT_NS);
            if (screen_tx_o !== 1'b1)
                $fatal(1, "invalid UART stop bit");
            received[received_count] = decoded;
            received_count = received_count + 1;
        end
    end

    task automatic expect_byte(input [7:0] expected);
        begin
            wait (received_count > checked_count);
            if (received[checked_count] !== expected)
                $fatal(1, "byte %0d: got %02x expected %02x", checked_count,
                       received[checked_count], expected);
            checked_count = checked_count + 1;
        end
    endtask

    task automatic expect_command(input integer component, input string value);
        string command_text;
        integer index;
        begin
            command_text = $sformatf("t%0d.txt=\"%s\"", component, value);
            for (index = 0; index < command_text.len(); index = index + 1)
                expect_byte(command_text[index]);
            expect_byte(8'hff); expect_byte(8'hff); expect_byte(8'hff);
        end
    endtask

    task automatic send_rx_byte(input [7:0] value, input reg valid_stop);
        integer index;
        begin
            @(negedge clk);
            screen_rx_i = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            for (index = 0; index < 8; index = index + 1) begin
                screen_rx_i = value[index];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end
            screen_rx_i = valid_stop;
            repeat (CLKS_PER_BIT) @(negedge clk);
            screen_rx_i = 1'b1;
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    task automatic expect_zero_pressures;
        integer index;
        begin
            for (index = 3; index <= 18; index = index + 1)
                expect_command(index, "000");
        end
    endtask

    function automatic string initial_pressure_text(input integer index);
        begin
            case (index)
                0: initial_pressure_text = "123";
                1: initial_pressure_text = "A01";
                2: initial_pressure_text = "A02";
                3: initial_pressure_text = "A03";
                4: initial_pressure_text = "A04";
                5: initial_pressure_text = "A05";
                6: initial_pressure_text = "A06";
                7: initial_pressure_text = "A07";
                8: initial_pressure_text = "A08";
                9: initial_pressure_text = "A09";
                10: initial_pressure_text = "A0A";
                11: initial_pressure_text = "A0B";
                12: initial_pressure_text = "A0C";
                13: initial_pressure_text = "A0D";
                14: initial_pressure_text = "A0E";
                default: initial_pressure_text = "A0F";
            endcase
        end
    endfunction

    initial begin
        for (key_index = 0; key_index < 16; key_index = key_index + 1)
            pressure_values[key_index*12 +: 12] = 12'ha00 + key_index;
        pressure_values[11:0] = 12'h123;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (20) @(negedge clk);
        if (screen_tx_o !== 1'b1)
            $fatal(1, "startup delay did not keep TX idle");

        expect_command(0, "LIVE");
        // 在发送中改变输入：第一帧剩余字段必须继续使用整帧快照。
        @(negedge clk);
        pressure_values = 192'd0;
        pressure_values[11:0] = 12'hfff;
        active_key_count = 4'd4;
        midi_mode = 1'b1;
        playing = 1'b1;
        expect_command(1, "10");
        // 实时模式 READY 不依赖 MIDI 文件是否上传或解析。
        expect_command(2, "READY");
        for (key_index = 0; key_index < 16; key_index = key_index + 1)
            expect_command(key_index + 3, initial_pressure_text(key_index));

        expect_command(0, "MIDI");
        expect_command(1, "4");
        expect_command(2, "PLAY");
        expect_command(3, "FFF");
        for (key_index = 4; key_index <= 18; key_index = key_index + 1)
            expect_command(key_index, "000");

        @(negedge clk);
        playing = 1'b0;
        parser_busy = 1'b1;
        pressure_values = 192'd0;
        expect_command(0, "MIDI"); expect_command(1, "4");
        expect_command(2, "WAIT"); expect_zero_pressures();
        @(negedge clk);
        parser_busy = 1'b0;
        file_ready = 1'b1;
        expect_command(0, "MIDI"); expect_command(1, "4");
        expect_command(2, "READY"); expect_zero_pressures();

        // 合法回传字节翻转活动标志；坏停止位不会被计作有效回传。
        send_rx_byte(8'h01, 1'b1);
        if (rx_activity !== 1'b1) $fatal(1, "first RX byte did not toggle activity");
        send_rx_byte(8'hff, 1'b1);
        if (rx_activity !== 1'b0) $fatal(1, "second RX byte did not toggle activity");
        send_rx_byte(8'h00, 1'b0);
        if (rx_activity !== 1'b0) $fatal(1, "framing error counted as valid RX");
        @(negedge clk);
        rst_n = 1'b0;
        #1;
        if (screen_tx_o !== 1'b1 || rx_activity !== 1'b0)
            $fatal(1, "reset did not restore idle state");
        $display("PASS tb_serial_screen_nextion16_tx pin_bytes=%0d snapshots=4 rx=2", checked_count);
        $finish;
    end

    initial begin
        #5_000_000;
        $fatal(1, "timeout: received=%0d checked=%0d", received_count, checked_count);
    end
endmodule

`default_nettype wire
