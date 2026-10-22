`timescale 1ns/1ps
module tb_key16_note_map;
    reg [3:0] key_index = 0;
    reg low_c3_mode = 0;
    wire [4:0] note_index;
    integer key, mode, expected, checks = 0;
    key16_note_map dut (.key_index(key_index), .low_c3_mode(low_c3_mode), .note_index(note_index));
    initial begin
        for (mode = 0; mode < 2; mode = mode + 1) begin
            low_c3_mode = mode;
            for (key = 0; key < 16; key = key + 1) begin
                key_index = key;
                #1;
                expected = mode && key == 0 ? 16 : key;
                if (note_index !== expected[4:0])
                    $fatal(1, "Mapping failed key=%0d mode=%0d note=%0d", key, mode, note_index);
                checks = checks + 1;
            end
        end
        // Exercise both directions of the mode switch on K1.
        key_index = 0; low_c3_mode = 0; #1;
        if (note_index !== 5'd0) $fatal(1, "K1 default must be C4");
        low_c3_mode = 1; #1;
        if (note_index !== 5'd16) $fatal(1, "C3 ID must retain its fifth bit");
        low_c3_mode = 0; #1;
        if (note_index !== 5'd0) $fatal(1, "Return to C4 failed");
        $display("PASS keyboard map: 32 combinations; K1 C4/C3 switch; five-bit note ID");
        $finish;
    end
endmodule
