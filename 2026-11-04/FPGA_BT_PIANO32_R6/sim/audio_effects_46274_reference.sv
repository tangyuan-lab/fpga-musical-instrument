`default_nettype none
// 独立延迟和双梳状混响；保留直达声，效果存储不进入控制起音的等待路径。
// RAM不复位，启动清零由写指针有效范围屏蔽，避免把延迟线综合成触发器。
module audio_effects_46274_reference(
    input wire clk,rst_n,sample_tick,clear,
    input wire signed [15:0] dry,
    input wire [6:0] delay_mix,reverb_mix,feedback,
    input wire [11:0] delay_samples,
    output reg signed [15:0] wet
);
    (* ram_style="block",syn_ramstyle="block_ram" *) reg signed [15:0] delay_ram[0:4095];
    reg [11:0] pointer,valid_samples;reg [10:0] pa;reg [11:0] pb;
    reg signed [15:0] d,a,b;reg [2:0] state;reg signed [31:0] value;
    reg signed [15:0] input_sample;
    function automatic signed [15:0] clamp(input signed [31:0] x);
        clamp=x>32767 ? 32767 : x< -32768 ? -32768 : x[15:0];
    endfunction
    wire signed [15:0] read_a,read_b;
    sample_ram #(.ADDRESS_WIDTH(11)) ram_a(.clk(clk),.write_enable(state==1),.write_address(pa),.read_address(pa),
        .write_data(clamp(32'(input_sample)+(32'(a)*3>>>2))),.read_data(read_a));
    sample_ram #(.ADDRESS_WIDTH(12)) ram_b(.clk(clk),.write_enable(state==1),.write_address(pb),.read_address(pb),
        .write_data(clamp(32'(input_sample)+(32'(b)*5>>>3))),.read_data(read_b));
    always @(posedge clk) begin
        if(!rst_n || clear) begin pointer<=0;pa<=0;pb<=0;valid_samples<=0;wet<=0;state<=0;d<=0;a<=0;b<=0;input_sample<=0;value<=0;end
        else case(state)
            0:if(sample_tick) begin
                input_sample<=dry;
                d<=valid_samples>=delay_samples && delay_samples!=0 ? delay_ram[12'(pointer-delay_samples)] : 16'sd0;
                a<=valid_samples>=2048 ? read_a : 16'sd0;
                b<=valid_samples>=3072 ? read_b : 16'sd0;state<=1;
            end
            1:begin
                delay_ram[pointer]<=clamp(32'(input_sample)+(32'(d)*$signed({1'b0,feedback>96 ? 7'd96:feedback})>>>7));
                value<=32'(input_sample)+(32'(d)*$signed({1'b0,delay_mix})>>>7)+
                    ((32'(a)+32'(b))*$signed({1'b0,reverb_mix})>>>8);
                state<=2;
            end
            2:begin
                wet<=clamp(value);pointer<=pointer+1'b1;
                pa<=pa+1'b1;pb<=pb==3071 ? 0 : pb+1'b1;
                if(valid_samples!=4095) valid_samples<=valid_samples+1'b1;
                state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
