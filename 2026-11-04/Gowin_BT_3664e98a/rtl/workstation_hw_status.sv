`default_nettype none
// 0x3A/v1只读状态：mem域计数整包握手快照到50MHz，禁止逐位同步宽计数。
// 快照两端只由整机复位清零，DDR重初始化不会抹掉累计诊断数据。
module workstation_hw_status #(parameter [31:0] BUILD_ID=32'h26102943)(
    input wire app_clk,rst_n,mem_clk,mem_rst_n,pll_locked,calibrated,storage_ready,
    input wire request_fire,response_fire,response_error,command_fire,command_write,reinit,
    input wire sample_tick,sample_valid,input wire [5:0] voices,peak_voices,
    input wire deadline_error,parameter_error,input wire [31:0] timeout_count,
    output wire [399:0] status
);
    (* async_reg="true",syn_preserve=1 *) reg [1:0] mem_reset_release;
    always @(posedge mem_clk or negedge rst_n)
        if(!rst_n)mem_reset_release<=0;else mem_reset_release<={mem_reset_release[0],1'b1};
    wire monitor_mem_rst_n=mem_reset_release[1];
    reg [31:0] write_count,read_count,reinit_count;
    reg old_reinit;
    (* async_reg="true" *) reg [1:0] pll_sync;
    always @(posedge mem_clk or negedge monitor_mem_rst_n)begin
        if(!monitor_mem_rst_n)begin write_count<=0;read_count<=0;reinit_count<=0;old_reinit<=0;pll_sync<=0;end
        else begin
            pll_sync<={pll_sync[0],pll_locked};old_reinit<=reinit;
            if(reinit&&!old_reinit)reinit_count<=reinit_count+1'b1;
            if(mem_rst_n&&calibrated&&command_fire)begin
                if(command_write)write_count<=write_count+1'b1;else read_count<=read_count+1'b1;
            end
        end
    end
    wire [99:0] mem_snapshot;
    snapshot_cdc #(.WIDTH(100)) counters(
        .src_clk(mem_clk),.src_rst_n(monitor_mem_rst_n),
        .src_data({write_count,read_count,reinit_count,1'b0,mem_rst_n,calibrated,pll_sync[1]}),
        .dst_clk(app_clk),.dst_rst_n(rst_n),.dst_data(mem_snapshot),.dst_valid());
    reg [31:0] request_count,response_count,error_count,loss_count,audio_frames,max_cycles,frame_cycles;
    reg was_calibrated;
    always @(posedge app_clk or negedge rst_n)begin
        if(!rst_n)begin request_count<=0;response_count<=0;error_count<=0;loss_count<=0;
            audio_frames<=0;max_cycles<=0;frame_cycles<=0;was_calibrated<=0;end
        else begin
            was_calibrated<=mem_snapshot[1];
            if(was_calibrated&&!mem_snapshot[1])loss_count<=loss_count+1'b1;
            if(request_fire)request_count<=request_count+1'b1;
            if(response_fire)begin response_count<=response_count+1'b1;if(response_error)error_count<=error_count+1'b1;end
            if(sample_tick)frame_cycles<=0;else if(frame_cycles!=32'hffffffff)frame_cycles<=frame_cycles+1'b1;
            if(sample_valid)begin audio_frames<=audio_frames+1'b1;if(frame_cycles+1'b1>max_cycles)max_cycles<=frame_cycles+1'b1;end
        end
    end
    wire [7:0] flags={2'b00,parameter_error,deadline_error,mem_snapshot[2],storage_ready,mem_snapshot[1:0]};
    // 全部整数为小端；资源模块在前面加原有的请求类型和结果码，整帧payload共52字节。
    assign status={audio_frames,loss_count,16'd0,2'd0,peak_voices,2'd0,voices,timeout_count,max_cycles,
                   mem_snapshot[67:36],mem_snapshot[99:68],mem_snapshot[35:4],error_count,
                   response_count,request_count,BUILD_ID,flags,8'd1};
endmodule
`default_nettype wire
