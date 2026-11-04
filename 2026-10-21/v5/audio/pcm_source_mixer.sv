`default_nettype none
// 可扩展 N 路 PCM 接口：每路有独立16位样本、0..100音量及使能。
// 增益逐采样平滑，流水线宽位累加，最终限幅；新增音源不直接驱动 DAC 引脚。
module pcm_source_mixer #(parameter integer SOURCES=3) (
    input wire clk,rst_n,sample_tick,
    input wire [SOURCES*16-1:0] samples,
    input wire [SOURCES*7-1:0] volumes,
    input wire [SOURCES-1:0] enables,
    output reg signed [15:0] sample_out
);
    reg [8:0] gain [0:SOURCES-1];
    reg signed [25:0] product [0:SOURCES-1];
    reg signed [31:0] sum;
    integer i,j;
    function automatic [8:0] target_gain(input [6:0] volume,input active);
        reg [23:0] scaled;
        begin scaled=volume*24'd656;
            target_gain=!active ? 0 : scaled>=65536 ? 9'd256 : scaled[16:8];end
    endfunction
    always @(posedge clk) begin
        if(!rst_n) begin
            for(i=0;i<SOURCES;i=i+1) begin gain[i]<=0;product[i]<=0;end
            sample_out<=0;
        end else begin
            for(i=0;i<SOURCES;i=i+1) begin
                if(sample_tick) begin
                    if(gain[i]<target_gain(volumes[i*7+:7],enables[i])) gain[i]<=gain[i]+1'b1;
                    else if(gain[i]>target_gain(volumes[i*7+:7],enables[i])) gain[i]<=gain[i]-1'b1;
                end
                product[i]<=$signed(samples[i*16+:16])*$signed({1'b0,gain[i]});
            end
            if(sum>32767) sample_out<=32767;
            else if(sum< -32768) sample_out<=-32768;
            else sample_out<=sum[15:0];
        end
    end
    always @(*) begin
        sum=0;
        for(j=0;j<SOURCES;j=j+1) sum=sum+(32'(product[j])>>>8);
    end
endmodule
`default_nettype wire
