`default_nettype none
// 所有计数在50MHz域；窗口也是该时钟，不冒充独立晶振测量或模拟起音延迟。
// 一个DAC帧包含左右各16bit；声部采样量独立统计实际完成帧的有效声部数。
module audio_runtime_metrics #(parameter integer WINDOW_CYCLES=50_000_000)(
    input wire clk,rst_n,clear,sample_tick,sample_valid,
    input wire [5:0] completed_voices,active_voices,
    output reg [511:0] snapshot
);
    reg [31:0] timer,output_count,complete_count,voice_count,period_cycles;
    reg [31:0] min_period,max_period,max_compute,frame_cycles,total_complete,revision;
    reg [31:0] missed,unexpected;
    reg pending,seen_tick;
    wire [31:0] elapsed=frame_cycles+1'b1;
    always @(posedge clk)begin
        if(!rst_n||clear)begin
            timer<=0;output_count<=0;complete_count<=0;voice_count<=0;period_cycles<=0;
            min_period<=32'hffffffff;max_period<=0;max_compute<=0;frame_cycles<=0;
            total_complete<=0;revision<=0;missed<=0;unexpected<=0;pending<=0;seen_tick<=0;snapshot<=0;
        end else begin
            if(period_cycles!=32'hffffffff)period_cycles<=period_cycles+1'b1;
            if(frame_cycles!=32'hffffffff)frame_cycles<=frame_cycles+1'b1;
            if(sample_tick)begin
                output_count<=output_count+1'b1;frame_cycles<=0;period_cycles<=0;seen_tick<=1;
                if(seen_tick)begin
                    if(period_cycles+1'b1<min_period)min_period<=period_cycles+1'b1;
                    if(period_cycles+1'b1>max_period)max_period<=period_cycles+1'b1;
                end
                if(pending&&!sample_valid)missed<=missed+1'b1;
            end
            if(sample_valid)begin
                complete_count<=complete_count+1'b1;total_complete<=total_complete+1'b1;
                voice_count<=voice_count+{26'd0,completed_voices};
                if(!pending)unexpected<=unexpected+1'b1;
                if(pending&&elapsed>max_compute)max_compute<=elapsed;
            end
            if(sample_tick)pending<=1;else if(sample_valid)pending<=0;
            if(timer==WINDOW_CYCLES-1)begin
                timer<=0;output_count<=0;complete_count<=0;voice_count<=0;revision<=revision+1'b1;
                snapshot<={32'd48000,{26'd0,active_voices},total_complete,frame_cycles,revision+1'b1,
                    {26'd0,completed_voices},unexpected,missed,max_compute,max_period,
                    (min_period==32'hffffffff ? 32'd0:min_period),
                    (output_count+32'(sample_tick))*32'd4,
                    voice_count+(sample_valid?{26'd0,completed_voices}:32'd0),
                    complete_count+32'(sample_valid),output_count+32'(sample_tick),32'(WINDOW_CYCLES)};
            end else timer<=timer+1'b1;
        end
    end
endmodule
`default_nettype wire
