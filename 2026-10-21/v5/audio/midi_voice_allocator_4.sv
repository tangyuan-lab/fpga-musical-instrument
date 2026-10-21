`default_nettype none

// MIDI 四声部声部槽分配器。一个音符事件在一个系统时钟内完成分配；
// 正在释音的声部优先回收，四声部都忙时按轮询指针抢占最旧槽位。
module midi_voice_allocator_4 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        note_on_valid,
    input  wire [6:0]  note_on_note,
    input  wire [7:0]  note_on_velocity,
    input  wire        note_off_valid,
    input  wire [6:0]  note_off_note,
    input  wire        all_notes_off,
    input  wire [3:0]  voice_idle,
    output reg  [3:0]  voice_gate,
    output reg  [3:0]  voice_trigger,
    output reg  [3:0]  voice_assigned,
    output reg  [7:0]  voice_note0,
    output reg  [7:0]  voice_note1,
    output reg  [7:0]  voice_note2,
    output reg  [7:0]  voice_note3,
    output reg  [7:0]  voice_velocity0,
    output reg  [7:0]  voice_velocity1,
    output reg  [7:0]  voice_velocity2,
    output reg  [7:0]  voice_velocity3
);
    reg [1:0] steal_pointer;
    reg [1:0] selected_voice;
    reg selected_valid;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voice_gate <= 4'd0;
            voice_trigger <= 4'd0;
            voice_assigned <= 4'd0;
            voice_note0 <= 8'd0;
            voice_note1 <= 8'd0;
            voice_note2 <= 8'd0;
            voice_note3 <= 8'd0;
            voice_velocity0 <= 8'd0;
            voice_velocity1 <= 8'd0;
            voice_velocity2 <= 8'd0;
            voice_velocity3 <= 8'd0;
            steal_pointer <= 2'd0;
        end else begin
            voice_trigger <= 4'd0;

            if (all_notes_off)
                voice_gate <= 4'd0;

            // 释音完成后回收槽位；gate 先由 Note Off 清零，包络归零后才释放 assigned。
            for (i = 0; i < 4; i = i + 1) begin
                if (voice_assigned[i] && !voice_gate[i] && voice_idle[i])
                    voice_assigned[i] <= 1'b0;
            end

            if (note_off_valid && !all_notes_off) begin
                if (voice_assigned[0] && voice_note0[6:0] == note_off_note) voice_gate[0] <= 1'b0;
                if (voice_assigned[1] && voice_note1[6:0] == note_off_note) voice_gate[1] <= 1'b0;
                if (voice_assigned[2] && voice_note2[6:0] == note_off_note) voice_gate[2] <= 1'b0;
                if (voice_assigned[3] && voice_note3[6:0] == note_off_note) voice_gate[3] <= 1'b0;
            end

            if (note_on_valid && !all_notes_off) begin
                selected_valid = 1'b0;
                selected_voice = steal_pointer;

                // 同音重触发优先复用原声部，避免相同音高叠加造成音量突然翻倍。
                if (voice_assigned[0] && voice_note0[6:0] == note_on_note) begin selected_valid = 1'b1; selected_voice = 2'd0; end
                else if (voice_assigned[1] && voice_note1[6:0] == note_on_note) begin selected_valid = 1'b1; selected_voice = 2'd1; end
                else if (voice_assigned[2] && voice_note2[6:0] == note_on_note) begin selected_valid = 1'b1; selected_voice = 2'd2; end
                else if (voice_assigned[3] && voice_note3[6:0] == note_on_note) begin selected_valid = 1'b1; selected_voice = 2'd3; end

                if (!selected_valid) begin
                    if (!voice_assigned[0] || (!voice_gate[0] && voice_idle[0])) begin selected_valid = 1'b1; selected_voice = 2'd0; end
                    else if (!voice_assigned[1] || (!voice_gate[1] && voice_idle[1])) begin selected_valid = 1'b1; selected_voice = 2'd1; end
                    else if (!voice_assigned[2] || (!voice_gate[2] && voice_idle[2])) begin selected_valid = 1'b1; selected_voice = 2'd2; end
                    else if (!voice_assigned[3] || (!voice_gate[3] && voice_idle[3])) begin selected_valid = 1'b1; selected_voice = 2'd3; end
                end

                case (selected_voice)
                    2'd0: begin voice_assigned[0] <= 1'b1; voice_gate[0] <= 1'b1; voice_trigger[0] <= 1'b1; voice_note0 <= note_on_note; voice_velocity0 <= note_on_velocity; end
                    2'd1: begin voice_assigned[1] <= 1'b1; voice_gate[1] <= 1'b1; voice_trigger[1] <= 1'b1; voice_note1 <= note_on_note; voice_velocity1 <= note_on_velocity; end
                    2'd2: begin voice_assigned[2] <= 1'b1; voice_gate[2] <= 1'b1; voice_trigger[2] <= 1'b1; voice_note2 <= note_on_note; voice_velocity2 <= note_on_velocity; end
                    default: begin voice_assigned[3] <= 1'b1; voice_gate[3] <= 1'b1; voice_trigger[3] <= 1'b1; voice_note3 <= note_on_note; voice_velocity3 <= note_on_velocity; end
                endcase
                steal_pointer <= (selected_voice == 2'd3) ? 2'd0 : selected_voice + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
