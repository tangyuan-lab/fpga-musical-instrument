`timescale 1ns/1ps
`default_nettype none
// DAC 前独立总增益：boost=0/1/2/3 对应 1/2/4/8 倍，音源与32声部余量不变。
// 增益用 Q8 表示，128 个采样帧线性过渡；超出16位时饱和并产生削波脉冲，禁止回绕。
module pcm_master_gain #(parameter LIMITER_CAPABLE=0)(
    input wire clk,rst_n,clear,sample_tick,
    input wire signed [15:0] sample_in,
    input wire [1:0] boost,
    input wire limiter_enabled,input wire [1:0] limiter_release,
    output wire signed [15:0] sample_out,
    output wire clipped,valid,limited,
    output wire [15:0] limiter_gain,
    output wire [18:0] peak_in,peak_out,
    output wire [12:0] gain_q8
);
    reg [12:0] gain,target;
    reg signed [14:0] step_base;
    reg [6:0] step_remainder,fraction;
    reg [7:0] remaining;
    wire [12:0] desired_gain=13'd256<<boost;
    wire signed [14:0] change=$signed({2'b00,desired_gain})-$signed({2'b00,gain});
    wire [7:0] fraction_sum={1'b0,fraction}+{1'b0,step_remainder};
    wire signed [14:0] stepped=$signed({2'b00,gain})+step_base+$signed({14'd0,fraction_sum[7]});
    assign gain_q8=gain;
    always @(posedge clk)begin
        if(!rst_n)begin
            gain<=256;target<=256;step_base<=0;step_remainder<=0;fraction<=0;remaining<=0;
        end else if(sample_tick)begin
            if(desired_gain!=target)begin
                target<=desired_gain;step_base<=change>>>7;
                step_remainder<=change[6:0];fraction<=0;remaining<=128;
            end else if(remaining!=0)begin
                gain<=remaining==1?target:stepped[12:0];
                fraction<=fraction_sum[6:0];remaining<=remaining-1'b1;
            end
        end
    end
    reg product_valid;
    reg signed [29:0] product;
    wire signed [29:0] scaled=product>>>8;
    always @(posedge clk)begin
        if(!rst_n||clear)begin product_valid<=0;product<=0;end
        else begin
            product_valid<=sample_tick;
            if(sample_tick)product<=sample_in*$signed({1'b0,gain});
        end
    end
    generate if(LIMITER_CAPABLE)begin:protected_output
        pcm_peak_limiter limiter(.clk(clk),.rst_n(rst_n),.clear(clear),.valid_in(product_valid),.enabled(limiter_enabled),
            .sample_in(scaled[18:0]),.release_preset(limiter_release),.sample_out(sample_out),.valid_out(valid),
            .clipped(clipped),.limited(limited),.gain_q15(limiter_gain),.peak_in(peak_in),.peak_out(peak_out));
    end else begin:legacy_output
        reg signed [15:0] output_q;reg clipped_q,valid_q;
        assign sample_out=output_q;assign clipped=clipped_q;assign valid=valid_q;
        assign limited=0;assign limiter_gain=32768;assign peak_in=0;assign peak_out=0;
        always @(posedge clk)begin
            if(!rst_n||clear)begin output_q<=0;clipped_q<=0;valid_q<=0;end
            else begin
                valid_q<=product_valid;clipped_q<=0;
            if(product_valid)begin
                output_q<=scaled>32767?16'sd32767:scaled< -32768?-16'sd32768:scaled[15:0];
                clipped_q<=scaled>32767||scaled< -32768;
            end
            end
        end
    end endgenerate
endmodule
`default_nettype wire
