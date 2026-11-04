`timescale 1ns/1ps
`default_nettype none

// 四声部事件分配器。
//
// 13 个键可能在同一帧产生多个起音事件。本模块先把事件锁存在 pending_on 中，
// 随后每个 50 MHz 时钟分配一个键；即使四键同时按下也只需约 80 ns，远低于
// 10 ms 延迟指标，同时避免用一条很长的组合逻辑一次完成全部分配。
//
// 新按键优先使用空闲声部；四个声部都在工作时，按轮询顺序替换一个旧声部。
// 松键只关闭属于该键的声部。声部包络完全归零后，voice_idle 才允许回收槽位。
module voice_allocator_4 #(
    parameter integer KEY_COUNT       = 13,
    parameter integer KEY_INDEX_WIDTH = 4
) (
    input  wire                                  clk,
    input  wire                                  rst_n,
    input  wire [KEY_COUNT-1:0]                  key_on_pulse,
    input  wire [KEY_COUNT-1:0]                  key_off_pulse,
    input  wire [3:0]                            voice_idle,
    output reg  [3:0]                            voice_gate,
    output reg  [3:0]                            voice_assigned,
    output reg  [3:0]                            voice_trigger,
    output reg  [4*KEY_INDEX_WIDTH-1:0]          voice_keys
);
    reg [KEY_COUNT-1:0] pending_on;
    reg [KEY_COUNT-1:0] pending_on_next;
    reg [3:0] voice_gate_next;
    reg [3:0] voice_assigned_next;
    reg [3:0] voice_trigger_next;
    reg [4*KEY_INDEX_WIDTH-1:0] voice_keys_next;
    reg [1:0] steal_pointer;
    reg [1:0] steal_pointer_next;
    reg event_valid;
    reg [KEY_INDEX_WIDTH-1:0] event_key;
    reg selected_valid;
    reg [1:0] selected_voice;

    integer key_index;
    integer voice_index;

    always @(*) begin
        // 若某键尚在等待分配时已经松开，直接取消该过期事件。
        pending_on_next     = (pending_on | key_on_pulse) & ~key_off_pulse;
        voice_gate_next     = voice_gate;
        voice_assigned_next = voice_assigned;
        voice_trigger_next  = 4'b0000;
        voice_keys_next     = voice_keys;
        steal_pointer_next  = steal_pointer;
        event_valid         = 1'b0;
        event_key           = {KEY_INDEX_WIDTH{1'b0}};
        selected_valid      = 1'b0;
        selected_voice      = 2'd0;

        // 松键比较只经过四个声部，与键盘总键数无关。
        for (voice_index = 0; voice_index < 4; voice_index = voice_index + 1) begin
            if (voice_assigned_next[voice_index] &&
                key_off_pulse[voice_keys_next[voice_index*KEY_INDEX_WIDTH +: KEY_INDEX_WIDTH]])
                voice_gate_next[voice_index] = 1'b0;

            if (voice_assigned_next[voice_index] &&
                !voice_gate_next[voice_index] && voice_idle[voice_index])
                voice_assigned_next[voice_index] = 1'b0;
        end

        // 每拍取 pending_on 中编号最小的一个键，其余事件留到后续时钟。
        for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1) begin
            if (pending_on_next[key_index] && !event_valid) begin
                event_valid = 1'b1;
                event_key   = key_index[KEY_INDEX_WIDTH-1:0];
            end
        end

        if (event_valid) begin
            pending_on_next[event_key] = 1'b0;

            // 同一个键在释音尚未结束时再次按下，优先重启原声部。
            for (voice_index = 0; voice_index < 4; voice_index = voice_index + 1) begin
                if (voice_assigned_next[voice_index] &&
                    voice_keys_next[voice_index*KEY_INDEX_WIDTH +: KEY_INDEX_WIDTH] == event_key &&
                    !selected_valid) begin
                    selected_valid = 1'b1;
                    selected_voice = voice_index[1:0];
                end
            end

            // 首选从未占用的槽位，其次复用正在释音的槽位。
            for (voice_index = 0; voice_index < 4; voice_index = voice_index + 1) begin
                if (!voice_assigned_next[voice_index] && !selected_valid) begin
                    selected_valid = 1'b1;
                    selected_voice = voice_index[1:0];
                end
            end
            for (voice_index = 0; voice_index < 4; voice_index = voice_index + 1) begin
                if (!voice_gate_next[voice_index] && !selected_valid) begin
                    selected_valid = 1'b1;
                    selected_voice = voice_index[1:0];
                end
            end

            // 第五个及后续同时按下的键采用轮询抢占，行为固定且便于复现。
            if (!selected_valid)
                selected_voice = steal_pointer_next;

            voice_assigned_next[selected_voice] = 1'b1;
            voice_gate_next[selected_voice]      = 1'b1;
            voice_trigger_next[selected_voice]   = 1'b1;
            voice_keys_next[selected_voice*KEY_INDEX_WIDTH +: KEY_INDEX_WIDTH] = event_key;
            steal_pointer_next = (selected_voice == 2'd3) ? 2'd0 : selected_voice + 2'd1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_on     <= {KEY_COUNT{1'b0}};
            voice_gate     <= 4'b0000;
            voice_assigned <= 4'b0000;
            voice_trigger  <= 4'b0000;
            voice_keys     <= {(4*KEY_INDEX_WIDTH){1'b0}};
            steal_pointer  <= 2'd0;
        end else begin
            pending_on     <= pending_on_next;
            voice_gate     <= voice_gate_next;
            voice_assigned <= voice_assigned_next;
            voice_trigger  <= voice_trigger_next;
            voice_keys     <= voice_keys_next;
            steal_pointer  <= steal_pointer_next;
        end
    end
endmodule

`default_nettype wire
