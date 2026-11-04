`default_nettype none
// 48kHz延迟与双梳状混响。32K×16延时RAM提供最长600ms，不依赖DDR。
// RAM不复位；有效样本数屏蔽启动/取消后的旧内容。读地址后等待两拍再取数。
module audio_effects #(parameter SEPARATE_SEND=0)(
    input wire clk,rst_n,sample_tick,clear,
    input wire signed [15:0] dry,send_in,
    input wire [6:0] delay_mix,reverb_mix,feedback,
    input wire [14:0] delay_samples,
    output reg signed [15:0] wet,send_chain,
    output reg clipped,valid,
    output reg signed [15:0] delay_component,reverb_component
);
    reg [14:0] pointer,delay_address,active_delay;
    reg [15:0] valid_samples;
    reg [10:0] pa;reg [11:0] pb;
    reg [2:0] state;
    reg signed [15:0] input_sample,direct_sample,d,a,b;
    reg [6:0] frame_delay_mix,frame_reverb_mix,frame_feedback;
    reg [7:0] delay_gain,frame_delay_gain;
    reg [14:0] frame_delay;
    reg signed [31:0] value,send_value,delay_value,reverb_value;
    wire [14:0] requested_delay=delay_samples>28800 ? 15'd28800:delay_samples;
    wire signed [15:0] read_delay,read_a,read_b;
    function automatic signed [15:0] clamp(input signed [31:0] x);
        clamp=x>32767 ? 16'sd32767:x< -32768 ? 16'sh8000:x[15:0];
    endfunction
    sample_ram #(.ADDRESS_WIDTH(15)) delay_memory(.clk(clk),.write_enable(state==4),
        .write_address(pointer),.read_address(delay_address),
        .write_data(clamp(32'(input_sample)+(32'(d)*$signed({1'b0,frame_feedback})>>>7))),.read_data(read_delay));
    sample_ram #(.ADDRESS_WIDTH(11)) ram_a(.clk(clk),.write_enable(state==4),.write_address(pa),.read_address(pa),
        .write_data(clamp(32'(input_sample)+(32'(a)*7>>>3))),.read_data(read_a));
    sample_ram #(.ADDRESS_WIDTH(12)) ram_b(.clk(clk),.write_enable(state==4),.write_address(pb),.read_address(pb),
        .write_data(clamp(32'(input_sample)+(32'(b)*13>>>4))),.read_data(read_b));
    wire signed [31:0] delay_product=32'(d)*$signed({1'b0,frame_delay_mix});
    wire signed [31:0] delay_scaled=(delay_product>>>7)*$signed({1'b0,frame_delay_gain})>>>7;
    wire signed [31:0] reverb_scaled=((32'(a)+32'(b))*$signed({1'b0,frame_reverb_mix}))>>>7;
    always @(posedge clk)begin
        clipped<=0;valid<=0;
        if(!rst_n||clear)begin
            pointer<=0;delay_address<=0;active_delay<=0;valid_samples<=0;pa<=0;pb<=0;state<=0;
            wet<=0;send_chain<=0;delay_component<=0;reverb_component<=0;
            input_sample<=0;direct_sample<=0;d<=0;a<=0;b<=0;
            value<=0;send_value<=0;delay_value<=0;reverb_value<=0;
            frame_delay_mix<=0;frame_reverb_mix<=0;frame_feedback<=0;
            delay_gain<=0;frame_delay_gain<=0;frame_delay<=0;
        end else case(state)
            0:if(sample_tick)begin
                // 换延迟时间先用128采样淡出，静音点换地址再淡入，避免直接跳读爆音。
                if(requested_delay!=active_delay)begin
                    if(delay_gain!=0)delay_gain<=delay_gain-1'b1;
                    else active_delay<=requested_delay;
                end else if(delay_gain<128)delay_gain<=delay_gain+1'b1;
                input_sample<=SEPARATE_SEND?send_in:dry;direct_sample<=dry;
                frame_delay_mix<=delay_mix;frame_reverb_mix<=reverb_mix;
                frame_feedback<=feedback>96 ? 7'd96:feedback;
                frame_delay_gain<=delay_gain;frame_delay<=active_delay;
                delay_address<=pointer-active_delay;state<=1;
            end
            1:state<=2;
            2:state<=3;
            3:begin
                d<=valid_samples>={1'b0,frame_delay}&&frame_delay!=0 ? read_delay:16'sd0;
                a<=valid_samples>=2048 ? read_a:16'sd0;
                b<=valid_samples>=3072 ? read_b:16'sd0;state<=4;
            end
            4:begin
                value<=32'(direct_sample)+delay_scaled+reverb_scaled;
                send_value<=32'(input_sample)+delay_scaled+reverb_scaled;
                delay_value<=delay_scaled;reverb_value<=reverb_scaled;state<=5;
            end
            5:begin
                wet<=clamp(value);send_chain<=clamp(send_value);
                delay_component<=clamp(delay_value);reverb_component<=clamp(reverb_value);
                clipped<=value>32767||value< -32768||send_value>32767||send_value< -32768;
                valid<=1;pointer<=pointer+1'b1;pa<=pa+1'b1;pb<=pb==3071 ? 0:pb+1'b1;
                if(valid_samples<32768)valid_samples<=valid_samples+1'b1;
                state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
