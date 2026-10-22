// Future keyboard integration only; intentionally absent from the accepted gprj.
// key_index 0..15 means physical K1..K16.
// Latch note_index on key-down. Release by the original physical key/voice owner;
// never recompute a held note's identity when low_c3_mode changes.
module key16_note_map (
    input  wire [3:0] key_index,
    input  wire       low_c3_mode,
    output wire [4:0] note_index
);
    assign note_index = low_c3_mode && key_index == 4'd0
                      ? 5'd16 : {1'b0, key_index};
endmodule
