`default_nettype none
// Explicit stage-event counters; they do not claim to cover modal/analog clipping.
module pcm_gain_stats(
    input wire clk,rst_n,clear,voice_clip,fx_clip,master_clip,output_valid,limited,
    input wire [18:0] peak_in,peak_out,
    output wire [223:0] snapshot
);
    reg [31:0] voice_count,fx_count,master_count,limited_count,input_peak,output_peak,sample_count;
    assign snapshot={sample_count,output_peak,input_peak,limited_count,master_count,fx_count,voice_count};
    function automatic [31:0] increment(input [31:0] v);increment=v==32'hffffffff ? v : v+1'b1;endfunction
    always @(posedge clk)begin
        if(!rst_n||clear)begin
            voice_count<=0;fx_count<=0;master_count<=0;limited_count<=0;input_peak<=0;output_peak<=0;sample_count<=0;
        end else begin
            if(voice_clip)voice_count<=increment(voice_count);
            if(fx_clip)fx_count<=increment(fx_count);
            if(master_clip)master_count<=increment(master_count);
            if(output_valid)begin
                sample_count<=increment(sample_count);
                if(limited)limited_count<=increment(limited_count);
                if(peak_in>input_peak)input_peak<={13'd0,peak_in};
                if(peak_out>output_peak)output_peak<={13'd0,peak_out};
            end
        end
    end
endmodule
`default_nettype wire
