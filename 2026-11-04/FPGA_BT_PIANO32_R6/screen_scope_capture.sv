`default_nettype none
// True consecutive 48kHz samples -> one min/max pair per 4ms column.
// No multiplier, no audio feedback; one small SDP block RAM absorbs display stalls.
module screen_scope_capture #(
    parameter integer SAMPLES_PER_COLUMN=192, ADDRESS_WIDTH=6
)(
    input wire clk,rst_n,clear,enable,sample_tick,right_channel,pop,
    input wire signed [15:0] left,right,
    output wire [23:0] pair_data,
    output wire [ADDRESS_WIDTH:0] available,
    output reg overflow
);
    localparam integer CW=$clog2(SAMPLES_PER_COLUMN);
    reg [CW-1:0] count;
    reg signed [15:0] low_sample,high_sample;
    reg [ADDRESS_WIDTH:0] write_seq,read_seq;
    wire signed [15:0] sample_value=right_channel ? right:left;
    wire signed [15:0] next_low=count==0 || sample_value<low_sample ? sample_value:low_sample;
    wire signed [15:0] next_high=count==0 || sample_value>high_sample ? sample_value:high_sample;
    function automatic [11:0] amplitude_code(input signed [15:0] s);
        begin amplitude_code={~s[15],s[14:4]};end
    endfunction
    assign available=write_seq-read_seq;
    wire full=available==(1<<ADDRESS_WIDTH);
    wire write_enable=rst_n && !clear && enable && sample_tick && count==SAMPLES_PER_COLUMN-1 && !full;
    wire [23:0] write_pair={amplitude_code(next_high),amplitude_code(next_low)};
    wire [31:0] ram_word;
    // In GW5A 16/32-bit SDP modes the low ADA bits are byte write enables.
    SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(32),.BIT_WIDTH_1(32),
        .BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) memory(
        .DO(ram_word),.DI({8'd0,write_pair}),.BLKSELA(3'd0),.BLKSELB(3'd0),
        .ADA((14'(write_seq[ADDRESS_WIDTH-1:0])<<5)|14'd15),
        .ADB(14'(read_seq[ADDRESS_WIDTH-1:0])<<5),
        .CLKA(clk),.CLKB(clk),.CEA(write_enable),.CEB(1'b1),.OCE(1'b1),.RESET(1'b0));
    assign pair_data=ram_word[23:0];
    always @(posedge clk)begin
        if(!rst_n || clear)begin
            count<=0;low_sample<=0;high_sample<=0;write_seq<=0;read_seq<=0;overflow<=0;
        end else begin
            if(pop && available!=0)read_seq<=read_seq+1'b1;
            if(enable && sample_tick)begin
                low_sample<=next_low;high_sample<=next_high;
                if(count==SAMPLES_PER_COLUMN-1)begin
                    count<=0;
                    if(full)overflow<=1;else write_seq<=write_seq+1'b1;
                end else count<=count+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
