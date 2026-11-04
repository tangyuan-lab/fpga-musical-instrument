`default_nettype none
// 快速采集与低速显示分离；64字显示快照只在完整帧后发布，冻结不影响音频。
// 波形64点连续采样；李萨如32对同拍XY，可选1/4/16/64采样间隔。频谱64条覆盖0..6kHz。
module audio_observer(
    input wire clk,rst_n,clear,sample_tick,
    input wire signed [15:0] left,right,
    input wire signed [15:0] aligned_dry,effect_output,
    input wire liss_fx_pair,input wire [1:0] liss_stride,
    input wire [1:0] graph_kind,
    input wire freeze_graph,right_channel,
    input wire read_lock,input wire [5:0] read_address,
    input wire [5:0] host_address,
    output reg [15:0] read_data,host_data,
    output wire lock_granted,
    output reg [31:0] revision,
    output reg [63:0] peak_bins,peak_magnitudes,
    output reg ready,
    output wire fft_busy,
    output reg [7:0] graph_config
);
    wire [7:0] bin;wire [15:0] mag;wire valid,done;
    fft512_observer fft(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(sample_tick),
        .sample_in(right_channel ? right:left),.bin_index(bin),.magnitude(mag),.bin_valid(valid),.frame_done(done),.busy(fft_busy));
    reg [15:0] wave[0:63],liss[0:63],spectrum[0:63],display_ram[0:63];
    reg [5:0] wave_wp;reg [4:0] liss_wp;reg capture_full;
    reg liss_full,previous_pair;reg [1:0] previous_stride;
    reg [5:0] liss_divider;
    wire [5:0] stride_last=liss_stride==0 ? 6'd0:liss_stride==1 ? 6'd3:liss_stride==2 ? 6'd15:6'd63;
    reg [7:0] copying_config;
    reg copying;reg [5:0] copy_index;reg [1:0] copy_kind;
    reg [15:0] prev2,prev1;reg [7:0] prev_bin;
    reg [15:0] pm[0:3];reg [7:0] pb[0:3];
    reg request;reg [1:0] previous_kind;reg previous_channel;
    wire config_changed=graph_kind!=previous_kind||right_channel!=previous_channel||
        liss_fx_pair!=previous_pair||liss_stride!=previous_stride;
    integer k;
    assign lock_granted=read_lock&&!copying;
    always @(posedge clk)begin
        read_data<=display_ram[read_address];
        host_data<=display_ram[host_address];
        if(!rst_n||clear)begin
            wave_wp<=0;liss_wp<=0;capture_full<=0;copying<=0;copy_index<=0;copy_kind<=0;
            revision<=0;ready<=0;peak_bins<=0;peak_magnitudes<=0;prev2<=0;prev1<=0;prev_bin<=0;
            request<=0;previous_kind<=0;previous_channel<=0;
            liss_full<=0;previous_pair<=0;previous_stride<=0;liss_divider<=0;graph_config<=0;copying_config<=0;
            for(k=0;k<4;k=k+1)begin pm[k]<=0;pb[k]<=0;end
        end else begin
            previous_kind<=graph_kind;previous_channel<=right_channel;previous_pair<=liss_fx_pair;previous_stride<=liss_stride;
            if(config_changed)begin
                ready<=0;request<=0;copying<=0;wave_wp<=0;liss_wp<=0;liss_full<=0;capture_full<=0;liss_divider<=0;
            end
            if(sample_tick && !copying && !config_changed)begin
                wave[wave_wp]<=right_channel ? right:left;wave_wp<=wave_wp+1'b1;
                if(liss_divider==stride_last)begin
                    liss_divider<=0;
                    liss[{liss_wp,1'b0}]<=liss_fx_pair ? aligned_dry:left;
                    liss[{liss_wp,1'b1}]<=liss_fx_pair ? effect_output:right;
                    liss_wp<=liss_wp+1'b1;
                    if(liss_wp==31)begin liss_full<=1;if(graph_kind==2)request<=1;end
                end else liss_divider<=liss_divider+1'b1;
                if(wave_wp==63)begin capture_full<=1;if(graph_kind==0)request<=1;end
            end
            if(valid)begin
                if(bin<64)spectrum[bin[5:0]]<=mag;
                if(bin==0)begin
                    for(k=0;k<4;k=k+1)begin pm[k]<=0;pb[k]<=0;end
                    prev1<=mag;prev2<=0;prev_bin<=0;
                end else begin
                    // 局部极大值，排除DC；按检测幅值取最强四峰，频率非预填目标。
                    if(prev_bin!=0 && prev1>prev2 && prev1>=mag && prev1>16)begin
                        if(prev1>pm[0])begin pm[3]<=pm[2];pb[3]<=pb[2];pm[2]<=pm[1];pb[2]<=pb[1];pm[1]<=pm[0];pb[1]<=pb[0];pm[0]<=prev1;pb[0]<=prev_bin;end
                        else if(prev1>pm[1])begin pm[3]<=pm[2];pb[3]<=pb[2];pm[2]<=pm[1];pb[2]<=pb[1];pm[1]<=prev1;pb[1]<=prev_bin;end
                        else if(prev1>pm[2])begin pm[3]<=pm[2];pb[3]<=pb[2];pm[2]<=prev1;pb[2]<=prev_bin;end
                        else if(prev1>pm[3])begin pm[3]<=prev1;pb[3]<=prev_bin;end
                    end
                    prev2<=prev1;prev1<=mag;prev_bin<=bin;
                end
            end
            if(done)begin
                if(graph_kind==1)request<=1;
                if(!freeze_graph)begin
                    peak_bins<={8'd0,pb[3],8'd0,pb[2],8'd0,pb[1],8'd0,pb[0]};
                    peak_magnitudes<={pm[3],pm[2],pm[1],pm[0]};
                end
            end
            if(!copying && request && !freeze_graph && !read_lock && !config_changed &&
               (graph_kind==2 ? liss_full:capture_full))begin
                copying<=1;copy_index<=0;copy_kind<=graph_kind;request<=0;
                copying_config<={2'd0,graph_kind,liss_fx_pair,liss_stride,right_channel};
            end
            if(copying && !config_changed)begin
                case(copy_kind)
                    1:display_ram[copy_index]<=spectrum[copy_index];
                    2:display_ram[copy_index]<=liss[copy_index];
                    default:display_ram[copy_index]<=wave[copy_index];
                endcase
                if(copy_index==63)begin copying<=0;revision<=revision+1'b1;ready<=1;graph_config<=copying_config;end
                else copy_index<=copy_index+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
