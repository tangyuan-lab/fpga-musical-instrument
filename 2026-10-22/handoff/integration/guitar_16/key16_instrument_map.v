// Input adapter only: keyboard scanning and polyphonic ownership are external.
module key16_instrument_map(
 input wire [3:0] key_index,
 input wire [1:0] timbre,
 input wire low_c3_mode,
 output wire [4:0] note_index,
 output wire valid
);
 assign valid=(timbre==0)||(timbre==2)||((timbre==1)&&(key_index<8));
 assign note_index=(timbre==0&&low_c3_mode&&key_index==0) ? 5'd16 : {1'b0,key_index};
endmodule
