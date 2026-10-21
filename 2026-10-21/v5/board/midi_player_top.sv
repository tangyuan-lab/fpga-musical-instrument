`default_nettype none

// 完整 MIDI 播放演示顶层。
// USB-C 串口只接收完整 MIDI 文件和 PLAY/STOP 控制；文件解析、Tempo、音符
// 调度、四声部相位累加、包络和 PT8211 串行输出全部在 FPGA 内完成。
module midi_player_top #(
    // 0 对应板载 PT8211；1 对应外接标准 I2S DAC，需使用匹配的引脚约束。
    parameter integer AUDIO_I2S = 0
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    output wire [7:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en
);
    localparam integer MAX_PAYLOAD = 132;
    wire rst_n;
    wire [7:0] rx_data;
    wire rx_valid;
    wire framing_error;
    wire frame_valid;
    wire bad_frame;
    wire [7:0] frame_type;
    wire [15:0] frame_seq;
    wire [15:0] frame_length;
    wire [MAX_PAYLOAD*8-1:0] frame_payload;

    wire file_ready;
    wire play_request;
    wire stop_request;
    wire write_busy;
    wire [1:0] store_status;
    wire [16:0] file_size;
    wire mem_write_en;
    wire [15:0] mem_write_address;
    wire [7:0] mem_write_data;
    wire [15:0] file_read_address;
    wire [7:0] file_read_data;
    wire parser_busy;
    wire parser_ready;
    wire parser_error;
    wire [3:0] parser_error_code;
    wire [8:0] event_count;
    wire [8:0] event_read_index;
    wire [31:0] event_start_tick;
    wire [31:0] event_end_tick;
    wire [6:0] event_note;
    wire [7:0] event_velocity;
    wire [5:0] tempo_count;
    wire [5:0] tempo_read_index;
    wire [31:0] tempo_tick;
    wire [23:0] tempo_us_per_quarter;
    wire [15:0] division_ppqn;
    reg parser_start;
    reg parser_stop;
    reg play_pending;
    reg parser_ready_d;
    reg scheduler_start;
    reg [1:0] timbre_select;
    reg [7:0] play_timbre_reg;
    wire note_on_valid;
    wire [6:0] note_on_note;
    wire [7:0] note_on_velocity;
    wire note_off_valid;
    wire [6:0] note_off_note;
    wire playing;
    wire finished;
    wire [7:0] current_voice_count;
    wire sample_tick;
    wire audio_ready;
    wire signed [15:0] midi_sample;
    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [31:0] voice_status;
    wire timbre_ready;
    wire [1:0] timbre_status;
    wire [7:0] timbre_attack;
    wire [7:0] timbre_release;
    wire timbre_write_busy;
    wire wave_write_enable;
    wire [7:0] wave_write_address;
    wire signed [15:0] wave_write_data;
    reg response_valid;
    reg [7:0] response_type;
    reg [15:0] response_seq;
    reg [7:0] response_length;
    reg [127:0] response_payload;
    wire response_busy;
    reg response_pending;
    reg [7:0] pending_response_type;
    reg [15:0] pending_response_seq;
    reg [15:0] pending_response_length;
    reg [31:0] pending_response_word;
    reg [24:0] led_counter;

    wire response_waiting_for_write =
        (pending_response_type == 8'h11 && write_busy) ||
        (pending_response_type == 8'h21 && timbre_write_busy);
    wire play_timbre_invalid = pending_response_type == 8'h13 &&
        (pending_response_length != 16'd1 || pending_response_word[7:0] > 8'd2 ||
         (pending_response_word[7:0] == 8'd2 && !timbre_ready));
    wire play_engine_busy = pending_response_type == 8'h13 &&
                            (parser_busy || playing || play_pending);
    wire [7:0] pending_status =
        (pending_response_type == 8'h01) ?
            ((pending_response_length == 16'd4) ? 8'd0 : 8'd1) :
        (pending_response_type == 8'h90) ? 8'd0 :
        play_timbre_invalid ? 8'd3 :
        play_engine_busy ? 8'd3 :
        ((pending_response_type == 8'h20 || pending_response_type == 8'h21 ||
          pending_response_type == 8'h22) ? {6'd0, timbre_status} :
                                             {6'd0, store_status});

    reset_sync reset_inst (.clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n));
    uart_rx #(.CLKS_PER_BIT(434)) rx_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx(uart_rx_i), .data(rx_data),
        .valid(rx_valid), .framing_error(framing_error)
    );
    uart_frame_protocol #(.MAX_PAYLOAD(MAX_PAYLOAD)) protocol_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx_data(rx_data), .rx_valid(rx_valid),
        .frame_valid(frame_valid), .bad_frame(bad_frame), .frame_type(frame_type),
        .frame_seq(frame_seq), .frame_length(frame_length), .frame_payload(frame_payload)
    );
    midi_file_store #(.FILE_BYTES(65536), .MAX_PAYLOAD(MAX_PAYLOAD)) store_inst (
        .clk(sys_clk), .rst_n(rst_n), .frame_valid(frame_valid), .frame_type(frame_type),
        .frame_seq(frame_seq),
        .frame_length(frame_length), .frame_payload(frame_payload), .file_ready(file_ready),
        .play_request(play_request), .stop_request(stop_request), .last_status(store_status),
        .write_busy(write_busy), .mem_write_en(mem_write_en), .mem_write_address(mem_write_address),
        .mem_write_data(mem_write_data), .file_size(file_size), .read_address(file_read_address),
        .read_data(file_read_data)
    );
    midi_file_ram_sdp file_ram (
        .clk(sys_clk), .write_enable(mem_write_en), .write_address(mem_write_address),
        .write_data(mem_write_data), .read_address(file_read_address), .read_data(file_read_data)
    );
    timbre_file_store #(.MAX_PAYLOAD(MAX_PAYLOAD)) timbre_store (
        .clk(sys_clk), .rst_n(rst_n), .frame_valid(frame_valid), .frame_type(frame_type),
        .frame_seq(frame_seq),
        .frame_length(frame_length), .frame_payload(frame_payload), .timbre_ready(timbre_ready),
        .last_status(timbre_status), .attack_step(timbre_attack), .release_step(timbre_release),
        .write_busy(timbre_write_busy),
        .wave_write_enable(wave_write_enable), .wave_write_address(wave_write_address),
        .wave_write_data(wave_write_data)
    );
    midi_type0_parser #(.MAX_EVENTS(256), .MAX_TEMPOS(32)) parser_inst (
        .clk(sys_clk), .rst_n(rst_n), .start(parser_start), .stop(parser_stop),
        .file_size(file_size), .file_read_address(file_read_address), .file_read_data(file_read_data),
        .busy(parser_busy), .ready(parser_ready), .error(parser_error), .error_code(parser_error_code),
        .event_count(event_count), .event_read_index(event_read_index),
        .event_start_tick(event_start_tick), .event_end_tick(event_end_tick),
        .event_note(event_note), .event_velocity(event_velocity),
        .tempo_count(tempo_count), .tempo_read_index(tempo_read_index),
        .tempo_tick(tempo_tick), .tempo_us_per_quarter(tempo_us_per_quarter),
        .division_ppqn(division_ppqn)
    );
    midi_player_scheduler scheduler_inst (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick && audio_ready),
        .start(scheduler_start), .stop(stop_request), .parser_ready(parser_ready),
        .division_ppqn(division_ppqn), .event_count(event_count), .event_read_index(event_read_index),
        .event_start_tick(event_start_tick), .event_end_tick(event_end_tick),
        .event_note(event_note), .event_velocity(event_velocity),
        .tempo_count(tempo_count), .tempo_read_index(tempo_read_index),
        .tempo_tick(tempo_tick), .tempo_us_per_quarter(tempo_us_per_quarter),
        .note_on_valid(note_on_valid), .note_on_note(note_on_note), .note_on_velocity(note_on_velocity),
        .note_off_valid(note_off_valid), .note_off_note(note_off_note), .playing(playing),
        .finished(finished), .current_voice_count(current_voice_count)
    );
    midi_poly_synth_4voice #(.MIX_SHIFT(2)) synth_inst (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick), .timbre(timbre_select),
        .custom_write_enable(wave_write_enable), .custom_write_address(wave_write_address),
        .custom_write_data(wave_write_data), .custom_attack_step(timbre_attack),
        .custom_release_step(timbre_release), .all_notes_off(stop_request),
        .note_on_valid(note_on_valid), .note_on_note(note_on_note), .note_on_velocity(note_on_velocity),
        .note_off_valid(note_off_valid), .note_off_note(note_off_note), .sample_out(midi_sample),
        .voice_gate(voice_gate), .voice_assigned(voice_assigned), .voice_status(voice_status)
    );
    audio_startup audio_startup_inst (
        .clk(sys_clk), .rst_n(rst_n), .audio_ready(audio_ready), .pa_en(pa_en)
    );
    generate if (AUDIO_I2S) begin : g_i2s
    i2s_tx audio_tx (
        .clk(sys_clk), .rst_n(rst_n), .sample_left(midi_sample), .sample_right(midi_sample),
        .sample_tick(sample_tick), .hp_bck(hp_bck), .hp_ws(hp_ws), .hp_din(hp_din)
    );
    end else begin : g_pt8211
    pt8211_tx audio_tx (
        .clk(sys_clk), .rst_n(rst_n), .sample_left(midi_sample), .sample_right(midi_sample),
        .sample_tick(sample_tick), .hp_bck(hp_bck), .hp_ws(hp_ws), .hp_din(hp_din)
    );
    end endgenerate
    uart_frame_tx #(.CLKS_PER_BIT(434), .MAX_RESPONSE(16)) response_tx (
        .clk(sys_clk), .rst_n(rst_n), .response_valid(response_valid),
        .response_type(response_type), .response_seq(response_seq),
        .response_length(response_length), .response_payload(response_payload),
        .tx(uart_tx_o), .busy(response_busy)
    );

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            parser_start <= 1'b0;
            parser_stop <= 1'b0;
            play_pending <= 1'b0;
            parser_ready_d <= 1'b0;
            scheduler_start <= 1'b0;
            timbre_select <= 2'd0;
            play_timbre_reg <= 8'd0;
            response_valid <= 1'b0;
            response_type <= 8'h81;
            response_seq <= 16'd0;
            response_length <= 8'd0;
            response_payload <= 128'd0;
            response_pending <= 1'b0;
            pending_response_type <= 8'd0;
            pending_response_seq <= 16'd0;
            pending_response_length <= 16'd0;
            pending_response_word <= 32'd0;
            led_counter <= 25'd0;
        end else begin
            parser_start <= 1'b0;
            parser_stop <= 1'b0;
            scheduler_start <= 1'b0;
            response_valid <= 1'b0;
            parser_ready_d <= parser_ready;
            led_counter <= led_counter + 1'b1;

            // midi_file_store 在收到 PLAY 帧的时钟沿用非阻塞赋值产生
            // play_request，所以这个脉冲会在下一拍到达本模块；此时
            // frame_valid 和 frame_payload 已经失效，必须使用前一拍锁存的
            // play_timbre_reg，避免漏掉启动请求或读取到下一帧数据。
            if (frame_valid && frame_type == 8'h13 && frame_length == 16'd1)
                play_timbre_reg <= frame_payload[7:0];
            if (play_request && play_timbre_reg <= 8'd2 &&
                !(play_timbre_reg == 8'd2 && !timbre_ready) &&
                !parser_busy && !playing && !play_pending) begin
                parser_start  <= 1'b1;
                play_pending  <= 1'b1;
                timbre_select <= play_timbre_reg[1:0];
            end
            if (stop_request) begin
                parser_stop <= 1'b1;
                play_pending <= 1'b0;
            end
            // parser_ready 的上升沿表示整份 MIDI 已经在 FPGA 内解析完成。
            if (play_pending && parser_ready && !parser_ready_d && !parser_busy) begin
                scheduler_start <= 1'b1;
                play_pending <= 1'b0;
            end

            // 先锁存请求，再等待文件/音色分块真正写入 RAM 后应答。这样电脑收到
            // ACK 时，本帧数据已经被 FPGA 消化完毕，下一块不会覆盖暂存区。
            if (frame_valid && !response_pending) begin
                response_pending        <= 1'b1;
                pending_response_type   <= frame_type;
                pending_response_seq    <= frame_seq;
                pending_response_length <= frame_length;
                pending_response_word   <= frame_payload[31:0];
            end

            if (response_pending && !response_busy && !response_waiting_for_write) begin
                response_valid <= 1'b1;
                response_pending <= 1'b0;
                response_type <= (pending_status == 0) ? 8'h81 : 8'h82;
                response_seq <= pending_response_seq;
                response_payload <= 128'd0;
                response_payload[7:0] <= pending_response_type;
                response_payload[15:8] <= pending_status;
                if (pending_response_type == 8'h01 && pending_response_length == 16'd4) begin
                    response_length <= 8'd6;
                    response_payload[47:16] <= pending_response_word;
                end else if (pending_response_type == 8'h90) begin
                    response_length <= 8'd7;
                    response_payload[23:16] <= {2'd0, timbre_ready, audio_ready,
                                                file_ready, parser_busy, parser_ready, playing};
                    response_payload[31:24] <= current_voice_count;
                    // STATUS 第 5 个 payload 字节的低两位仍为音色编号；
                    // bit2 和高四位补充解析错误及错误码，便于板上定位静音。
                    response_payload[39:32] <= {parser_error_code, 1'b0,
                                                 parser_error, timbre_select};
                    response_payload[55:40] <= {7'd0, event_count};
                end else begin
                    response_length <= 8'd2;
                end
            end
        end
    end

    // LED7：音频就绪；LED6：文件已接收；LED5：正在解析；LED4：正在播放；
    // LED0..3：当前四个声部，低电平点亮；解析错误时 LED0/LED1 同步闪烁。
    assign led_n = parser_error ? ~(led_counter[24] ? 8'b00000011 : 8'b00000000) :
                   {~audio_ready, ~file_ready, ~parser_busy, ~playing,
                    ~voice_gate[3], ~voice_gate[2], ~voice_gate[1], ~voice_gate[0]};
    wire _unused = &{1'b0, write_busy, bad_frame, framing_error, finished,
                     current_voice_count, voice_assigned, voice_status, store_status,
                     parser_error_code, timbre_status, timbre_attack, timbre_release};
endmodule

`default_nettype wire
