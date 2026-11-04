`default_nettype none

// MIDI Type 0 解析器。
//
// 文件已经由 midi_file_store 写入片内 RAM，本模块通过同步读口逐字节
// 解析 MThd/MTrk、VLQ、Tempo、Note On/Off 和 Running Status。电脑不会把
// 已经换算好的音符时间发送给 FPGA；音符的绝对 tick、结束 tick 和力度都由
// 这里产生并保存。事件 RAM 用读索引接口提供给后级调度器，避免把 256 个
// 事件全部展开成顶层端口。
module midi_type0_parser #(
    parameter integer MAX_EVENTS = 256,
    parameter integer MAX_TEMPOS = 32
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        stop,
    input  wire [16:0] file_size,
    output wire [15:0] file_read_address,
    input  wire [7:0]  file_read_data,
    output reg         busy,
    output reg         ready,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [8:0]  event_count,
    input  wire [8:0]  event_read_index,
    output wire [31:0] event_start_tick,
    output wire [31:0] event_end_tick,
    output wire [6:0]  event_note,
    output wire [7:0]  event_velocity,
    output reg  [5:0]  tempo_count,
    input  wire [5:0]  tempo_read_index,
    output wire [31:0] tempo_tick,
    output wire [23:0] tempo_us_per_quarter,
    output reg  [15:0] division_ppqn
);
    localparam integer EVENT_INDEX_WIDTH = 8;

    localparam [5:0] ST_IDLE          = 6'd0;
    localparam [5:0] ST_H0            = 6'd1;
    localparam [5:0] ST_H1            = 6'd2;
    localparam [5:0] ST_H2            = 6'd3;
    localparam [5:0] ST_H3            = 6'd4;
    localparam [5:0] ST_HL0           = 6'd5;
    localparam [5:0] ST_HL1           = 6'd6;
    localparam [5:0] ST_HL2           = 6'd7;
    localparam [5:0] ST_HL3           = 6'd8;
    localparam [5:0] ST_FMT0          = 6'd9;
    localparam [5:0] ST_FMT1          = 6'd10;
    localparam [5:0] ST_TRKNO0        = 6'd11;
    localparam [5:0] ST_TRKNO1        = 6'd12;
    localparam [5:0] ST_DIV0          = 6'd13;
    localparam [5:0] ST_DIV1          = 6'd14;
    localparam [5:0] ST_M0            = 6'd15;
    localparam [5:0] ST_M1            = 6'd16;
    localparam [5:0] ST_M2            = 6'd17;
    localparam [5:0] ST_M3            = 6'd18;
    localparam [5:0] ST_TL0           = 6'd19;
    localparam [5:0] ST_TL1           = 6'd20;
    localparam [5:0] ST_TL2           = 6'd21;
    localparam [5:0] ST_TL3           = 6'd22;
    localparam [5:0] ST_DELTA_START   = 6'd23;
    localparam [5:0] ST_DELTA_BYTE    = 6'd24;
    localparam [5:0] ST_STATUS        = 6'd25;
    localparam [5:0] ST_DATA1         = 6'd26;
    localparam [5:0] ST_DATA2         = 6'd27;
    localparam [5:0] ST_META_TYPE     = 6'd28;
    localparam [5:0] ST_META_LEN      = 6'd29;
    localparam [5:0] ST_META_SKIP     = 6'd30;
    localparam [5:0] ST_TEMPO0        = 6'd31;
    localparam [5:0] ST_TEMPO1        = 6'd32;
    localparam [5:0] ST_TEMPO2        = 6'd33;
    localparam [5:0] ST_SYSEX_LEN     = 6'd34;
    localparam [5:0] ST_SYSEX_SKIP    = 6'd35;
    localparam [5:0] ST_FINALIZE       = 6'd36;
    localparam [5:0] ST_ERROR          = 6'd37;

    reg [5:0] state;
    reg [16:0] track_end;
    reg [16:0] file_position;
    reg [31:0] track_length;
    reg [31:0] absolute_tick;
    reg [31:0] vlq_value;
    reg [3:0]  vlq_count;
    reg [7:0]  running_status;
    reg [7:0]  data1_reg;
    reg [7:0]  meta_type;
    reg [31:0] meta_remaining;
    reg meta_empty;
    reg [31:0] tempo_work;
    reg [31:0] sysex_remaining;
    reg [7:0]  finalize_index;
    reg [15:0] division_reg;
    reg [1:0]  parse_phase;

    // 起点、音高和力度只在 Note On 时写一次，打包后可推断为一组简单双口
    // BSRAM。结束时间在 Note Off/重触发/收尾时只写一次。同步读口避免把
    // 256 个事件展开成大规模异步多路器，后级在下一个采样节拍使用数据。
    (* ram_style = "block", syn_ramstyle = "block_ram" *) reg [46:0] event_info_mem [0:MAX_EVENTS-1];
    (* ram_style = "block", syn_ramstyle = "block_ram" *) reg [31:0] event_end_mem  [0:MAX_EVENTS-1];
    reg [46:0] event_info_read;
    reg [31:0] event_end_read;
    reg [31:0] tempo_tick_read;
    reg [23:0] tempo_us_read;
    reg event_end_write_enable;
    reg [7:0] event_end_write_address;
    reg [31:0] event_end_write_data;
    reg [8:0]  active_slot [0:127];
    reg        active_valid[0:127];

    reg [31:0] tempo_tick_mem [0:MAX_TEMPOS-1];
    reg [23:0] tempo_us_mem   [0:MAX_TEMPOS-1];

    // RAM 地址仍为 16 位，file_position 的第 17 位只用于准确表示
    // 65536 字节文件的末尾位置，避免地址回绕后再次解析文件开头。
    assign file_read_address    = file_position[15:0];
    assign event_start_tick    = event_info_read[46:15];
    assign event_note          = event_info_read[14:8];
    assign event_velocity      = event_info_read[7:0];
    assign event_end_tick      = event_end_read;
    assign tempo_tick          = tempo_tick_read;
    assign tempo_us_per_quarter = tempo_us_read;

    wire [31:0] vlq_next = {vlq_value[24:0], file_read_data[6:0]};
    wire [31:0] current_meta_len = vlq_next;
    wire [31:0] current_track_len = {track_length[31:8], file_read_data};
    wire [7:0] current_command = running_status[7:4];
    integer i;

    always @(posedge clk) begin
        event_info_read <= event_info_mem[event_read_index[EVENT_INDEX_WIDTH-1:0]];
        event_end_read  <= event_end_mem[event_read_index[EVENT_INDEX_WIDTH-1:0]];
        // Tempo 表也使用同步读出。索引译码和 32 位节拍比较因此分处
        // 不同时钟周期，整合工程不会形成跨模块的长组合路径。
        tempo_tick_read <= tempo_tick_mem[tempo_read_index];
        tempo_us_read   <= tempo_us_mem[tempo_read_index];
        if (event_end_write_enable)
            event_end_mem[event_end_write_address] <= event_end_write_data;
    end

    task automatic fail_parse;
        input [3:0] code;
        begin
            error_code <= code;
            error <= 1'b1;
            busy <= 1'b0;
            ready <= 1'b0;
            state <= ST_ERROR;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            file_position <= 17'd0;
            busy              <= 1'b0;
            ready             <= 1'b0;
            error             <= 1'b0;
            error_code        <= 4'd0;
            event_count       <= 9'd0;
            tempo_count       <= 6'd1;
            division_ppqn     <= 16'd480;
            track_end         <= 17'd0;
            track_length      <= 32'd0;
            absolute_tick     <= 32'd0;
            vlq_value         <= 32'd0;
            vlq_count         <= 4'd0;
            running_status    <= 8'd0;
            data1_reg         <= 8'd0;
            meta_type         <= 8'd0;
            meta_remaining    <= 32'd0;
            meta_empty        <= 1'b1;
            tempo_work        <= 32'd0;
            sysex_remaining   <= 32'd0;
            finalize_index    <= 8'd0;
            division_reg      <= 16'd480;
            parse_phase       <= 2'd0;
            event_end_write_enable <= 1'b0;
            event_end_write_address <= 8'd0;
            event_end_write_data <= 32'd0;
            for (i = 0; i < 128; i = i + 1) begin
                active_valid[i] <= 1'b0;
                active_slot[i]  <= 9'd0;
            end
            tempo_tick_mem[0] <= 32'd0;
            tempo_us_mem[0]   <= 24'd500000;
        end else begin
            // 每次解析步骤之间有两拍同步 RAM 等待，足够让零值标志更新。
            // 将 32 位归零比较与地址使能译码分开，避免 50 MHz 下形成长路径。
            meta_empty <= (meta_remaining == 0);
            event_end_write_enable <= 1'b0;
            if (stop) begin
                state <= ST_IDLE;
                busy  <= 1'b0;
                ready <= 1'b0;
                parse_phase <= 2'd0;
            end else begin
                // 文件 RAM 的同步读口后还有一级 bank 选择输出寄存器。
                // 地址改变后等待两拍，再让状态机读取数据。MIDI 文件只在
                // 播放前解析，增加一拍不会影响实时发声，却能切断长路径。
                if (busy && parse_phase != 2'd2) begin
                    parse_phase <= parse_phase + 1'b1;
                end else begin
                    if (busy) parse_phase <= 2'd0;
                case (state)
                    ST_IDLE: begin
                        if (start) begin
                            if (file_size < 17'd22) begin
                                fail_parse(4'd7);
                            end else begin
                                state             <= ST_H0;
                                file_position      <= 17'd0;
                                busy              <= 1'b1;
                                ready             <= 1'b0;
                                error             <= 1'b0;
                                error_code        <= 4'd0;
                                event_count       <= 9'd0;
                                tempo_count       <= 6'd1;
                                division_ppqn     <= 16'd480;
                                absolute_tick     <= 32'd0;
                                running_status    <= 8'd0;
                                tempo_tick_mem[0] <= 32'd0;
                                tempo_us_mem[0]   <= 24'd500000;
                                for (i = 0; i < 128; i = i + 1)
                                    active_valid[i] <= 1'b0;
                            end
                        end
                    end
                    ST_H0: begin
                        if (file_read_data != 8'h4d) fail_parse(4'd1);
                        else begin file_position <= file_position + 1'b1; state <= ST_H1; end
                    end
                    ST_H1: begin
                        if (file_read_data != 8'h54) fail_parse(4'd1);
                        else begin file_position <= file_position + 1'b1; state <= ST_H2; end
                    end
                    ST_H2: begin
                        if (file_read_data != 8'h68) fail_parse(4'd1);
                        else begin file_position <= file_position + 1'b1; state <= ST_H3; end
                    end
                    ST_H3: begin
                        if (file_read_data != 8'h64) fail_parse(4'd1);
                        else begin file_position <= file_position + 1'b1; state <= ST_HL0; end
                    end
                    ST_HL0: begin
                        if (file_read_data != 8'd0) fail_parse(4'd2);
                        else begin file_position <= file_position + 1'b1; state <= ST_HL1; end
                    end
                    ST_HL1: begin
                        if (file_read_data != 8'd0) fail_parse(4'd2);
                        else begin file_position <= file_position + 1'b1; state <= ST_HL2; end
                    end
                    ST_HL2: begin
                        if (file_read_data != 8'd0) fail_parse(4'd2);
                        else begin file_position <= file_position + 1'b1; state <= ST_HL3; end
                    end
                    ST_HL3: begin
                        if (file_read_data != 8'd6) fail_parse(4'd2);
                        else begin file_position <= file_position + 1'b1; state <= ST_FMT0; end
                    end
                    ST_FMT0: begin
                        if (file_read_data != 8'd0) fail_parse(4'd3);
                        else begin file_position <= file_position + 1'b1; state <= ST_FMT1; end
                    end
                    ST_FMT1: begin
                        if (file_read_data != 8'd0) fail_parse(4'd3);
                        else begin file_position <= file_position + 1'b1; state <= ST_TRKNO0; end
                    end
                    ST_TRKNO0: begin
                        if (file_read_data != 8'd0) fail_parse(4'd4);
                        else begin file_position <= file_position + 1'b1; state <= ST_TRKNO1; end
                    end
                    ST_TRKNO1: begin
                        if (file_read_data != 8'd1) fail_parse(4'd4);
                        else begin file_position <= file_position + 1'b1; state <= ST_DIV0; end
                    end
                    ST_DIV0: begin
                        division_reg[15:8] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        state <= ST_DIV1;
                    end
                    ST_DIV1: begin
                        if (division_reg[15] || file_read_data == 8'd0)
                            fail_parse(4'd5);
                        else begin
                            division_reg[7:0] <= file_read_data;
                            division_ppqn <= {division_reg[15:8], file_read_data};
                            file_position <= file_position + 1'b1;
                            state <= ST_M0;
                        end
                    end
                    ST_M0: begin
                        if (file_read_data != 8'h4d) fail_parse(4'd6);
                        else begin file_position <= file_position + 1'b1; state <= ST_M1; end
                    end
                    ST_M1: begin
                        if (file_read_data != 8'h54) fail_parse(4'd6);
                        else begin file_position <= file_position + 1'b1; state <= ST_M2; end
                    end
                    ST_M2: begin
                        if (file_read_data != 8'h72) fail_parse(4'd6);
                        else begin file_position <= file_position + 1'b1; state <= ST_M3; end
                    end
                    ST_M3: begin
                        if (file_read_data != 8'h6b) fail_parse(4'd6);
                        else begin file_position <= file_position + 1'b1; state <= ST_TL0; end
                    end
                    ST_TL0: begin
                        track_length[31:24] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        state <= ST_TL1;
                    end
                    ST_TL1: begin
                        track_length[23:16] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        state <= ST_TL2;
                    end
                    ST_TL2: begin
                        track_length[15:8] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        state <= ST_TL3;
                    end
                    ST_TL3: begin
                        if (current_track_len > file_size - 17'd22)
                            fail_parse(4'd7);
                        else begin
                            track_length[7:0] <= file_read_data;
                            track_end <= 17'd22 + current_track_len[16:0];
                            file_position <= 17'd22;
                            state <= ST_DELTA_START;
                        end
                    end
                    ST_DELTA_START: begin
                        if (file_position >= track_end) begin
                            finalize_index <= 8'd0;
                            state <= ST_FINALIZE;
                        end else begin
                            vlq_value <= 32'd0;
                            vlq_count <= 4'd0;
                            state <= ST_DELTA_BYTE;
                        end
                    end
                    ST_DELTA_BYTE: begin
                        file_position <= file_position + 1'b1;
                        vlq_value <= vlq_next;
                        vlq_count <= vlq_count + 1'b1;
                        if (vlq_count >= 4'd4) fail_parse(4'd8);
                        else if (!file_read_data[7]) begin
                            absolute_tick <= absolute_tick + vlq_next;
                            state <= ST_STATUS;
                        end
                    end
                    ST_STATUS: begin
                        if (file_position >= track_end) begin
                            finalize_index <= 8'd0;
                            state <= ST_FINALIZE;
                        end else if (file_read_data == 8'hff) begin
                            file_position <= file_position + 1'b1;
                            state <= ST_META_TYPE;
                        end else if (file_read_data == 8'hf0 || file_read_data == 8'hf7) begin
                            file_position <= file_position + 1'b1;
                            vlq_value <= 32'd0;
                            vlq_count <= 4'd0;
                            state <= ST_SYSEX_LEN;
                        end else if (file_read_data >= 8'h80 && file_read_data <= 8'hef) begin
                            running_status <= file_read_data;
                            file_position <= file_position + 1'b1;
                            state <= ST_DATA1;
                        end else if (running_status >= 8'h80 && running_status <= 8'hef) begin
                            data1_reg <= file_read_data;
                            file_position <= file_position + 1'b1;
                            if (current_command == 4'hc || current_command == 4'hd)
                                state <= ST_DELTA_START;
                            else
                                state <= ST_DATA2;
                        end else begin
                            fail_parse(4'd9);
                        end
                    end
                    ST_DATA1: begin
                        if (file_read_data[7]) begin
                            fail_parse(4'd9);
                        end else begin
                            data1_reg <= file_read_data;
                            file_position <= file_position + 1'b1;
                            if (running_status[7:4] == 4'hc || running_status[7:4] == 4'hd)
                                state <= ST_DELTA_START;
                            else
                                state <= ST_DATA2;
                        end
                    end
                    ST_DATA2: begin
                        if (file_read_data[7]) begin
                            fail_parse(4'd9);
                        end else begin
                        file_position <= file_position + 1'b1;
                        // MIDI 通道 10（低四位为 9）通常是打击乐，第一版默认忽略。
                        if (running_status[3:0] != 4'd9 &&
                            running_status[7:4] == 4'h9 && file_read_data != 8'd0) begin
                            if (active_valid[data1_reg]) begin
                                event_end_write_enable <= 1'b1;
                                event_end_write_address <= active_slot[data1_reg][7:0];
                                event_end_write_data <= absolute_tick;
                            end
                            if (event_count < MAX_EVENTS) begin
                                event_info_mem[event_count[EVENT_INDEX_WIDTH-1:0]] <=
                                    {absolute_tick, data1_reg[6:0], file_read_data};
                                active_slot[data1_reg] <= event_count;
                                active_valid[data1_reg] <= 1'b1;
                                event_count <= event_count + 1'b1;
                            end else fail_parse(4'd10);
                        end else if (running_status[3:0] != 4'd9 &&
                                    (running_status[7:4] == 4'h8 ||
                                     (running_status[7:4] == 4'h9 && file_read_data == 8'd0))) begin
                            if (active_valid[data1_reg]) begin
                                event_end_write_enable <= 1'b1;
                                event_end_write_address <= active_slot[data1_reg][7:0];
                                event_end_write_data <= absolute_tick;
                                active_valid[data1_reg] <= 1'b0;
                            end
                        end
                        state <= ST_DELTA_START;
                        end
                    end
                    ST_META_TYPE: begin
                        meta_type <= file_read_data;
                        file_position <= file_position + 1'b1;
                        vlq_value <= 32'd0;
                        vlq_count <= 4'd0;
                        state <= ST_META_LEN;
                    end
                    ST_META_LEN: begin
                        file_position <= file_position + 1'b1;
                        vlq_value <= vlq_next;
                        vlq_count <= vlq_count + 1'b1;
                        if (vlq_count >= 4'd4) fail_parse(4'd11);
                        else if (!file_read_data[7]) begin
                            meta_remaining <= current_meta_len;
                            if (meta_type == 8'h51 && current_meta_len == 32'd3) begin
                                tempo_work <= 32'd0;
                                state <= ST_TEMPO0;
                            end else begin
                                state <= ST_META_SKIP;
                            end
                        end
                    end
                    ST_TEMPO0: begin
                        tempo_work[23:16] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        state <= ST_TEMPO1;
                    end
                    ST_TEMPO1: begin
                        tempo_work[15:8] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        state <= ST_TEMPO2;
                    end
                    ST_TEMPO2: begin
                        tempo_work[7:0] <= file_read_data;
                        file_position <= file_position + 1'b1;
                        if (tempo_count < MAX_TEMPOS) begin
                            tempo_tick_mem[tempo_count] <= absolute_tick;
                            tempo_us_mem[tempo_count] <= {tempo_work[23:8], file_read_data};
                            tempo_count <= tempo_count + 1'b1;
                        end
                        state <= ST_DELTA_START;
                    end
                    ST_META_SKIP: begin
                        if (meta_empty) state <= ST_DELTA_START;
                        else begin
                            meta_remaining <= meta_remaining - 1'b1;
                            file_position <= file_position + 1'b1;
                        end
                    end
                    ST_SYSEX_LEN: begin
                        file_position <= file_position + 1'b1;
                        vlq_value <= vlq_next;
                        vlq_count <= vlq_count + 1'b1;
                        if (vlq_count >= 4'd4) fail_parse(4'd12);
                        else if (!file_read_data[7]) begin
                            sysex_remaining <= vlq_next;
                            state <= ST_SYSEX_SKIP;
                        end
                    end
                    ST_SYSEX_SKIP: begin
                        if (sysex_remaining == 0) state <= ST_DELTA_START;
                        else begin
                            sysex_remaining <= sysex_remaining - 1'b1;
                            file_position <= file_position + 1'b1;
                        end
                    end
                    ST_FINALIZE: begin
                        if (active_valid[finalize_index]) begin
                            event_end_write_enable <= 1'b1;
                            event_end_write_address <= active_slot[finalize_index][7:0];
                            event_end_write_data <= absolute_tick + 1'b1;
                            active_valid[finalize_index] <= 1'b0;
                        end
                        if (finalize_index == 8'd127) begin
                            busy  <= 1'b0;
                            ready <= 1'b1;
                            state <= ST_IDLE;
                        end else begin
                            finalize_index <= finalize_index + 1'b1;
                        end
                    end
                    ST_ERROR: begin
                        busy <= 1'b0;
                        if (start) state <= ST_IDLE;
                    end
                    default: state <= ST_IDLE;
                endcase
                end
            end
        end
    end
endmodule

`default_nettype wire

