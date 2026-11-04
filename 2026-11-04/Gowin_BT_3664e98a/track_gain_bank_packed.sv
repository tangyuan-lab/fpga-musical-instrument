`default_nettype none
// 每轨后级增益：无符号Q1.15，32768=0dB；目标值由轨道/角色/段落混音控制器提供。
// 每次命令从当前值重新斜坡，128个采样后精确到达目标；不改力度，不重触发音符。
// frame_done后所有轨道属于同一采样快照。合成器应在frame_done后启动本帧运算。
module track_gain_bank_packed #(parameter integer OWNERS=18)(
    input wire clk,rst_n,sample_tick,
    input wire command_valid,output wire command_ready,input wire [4:0] command_owner,
    input wire [15:0] command_gain,output reg command_done,command_error,
    input wire [4:0] read_owner,output reg [15:0] read_gain,
    output reg initialized,frame_done,deadline_error,output wire [15:0] percussion_gain
);
    localparam IDLE=3'd0,CMD_WAIT=3'd1,CMD_WRITE=3'd2,SCAN_WAIT=3'd3,SCAN_WRITE=3'd4;
    reg [2:0] state;reg [4:0] init_index,scan_index,pending_owner;
    reg [15:0] pending_gain;reg pending_tick;
    // word = {误差7, 余数7, 有符号步长10, 剩余采样8, 当前16}。
    // difference=128*floor(difference/128)+余数；128次累加精确到终点，无须另存目标16位。
    // 保留完整Q1.15输出与负差值向下取整，不改变128采样曲线、接口或初始化时序。
    // 数据不复位；保留原64拍初始化时序，越界初始化地址不写入。有效上下文按OWNERS裁剪。
    reg [47:0] context_read;wire context_valid=1'b1,context_busy=1'b0;reg init_issued;
    reg [OWNERS*48-1:0] contexts;integer context_index;
    reg [OWNERS*16-1:0] gain_mirror;integer mirror_index;
    // OWNERS是轨道归属数量，不是复音数。仍保留32个独立声部。
    generate if(OWNERS>4) begin:g_percussion
        assign percussion_gain=initialized ? gain_mirror[64+:16]:16'd32768;
    end else begin:g_no_percussion
        assign percussion_gain=16'd32768;
    end endgenerate

    wire [4:0] internal_address=(state==CMD_WAIT || state==CMD_WRITE) ? pending_owner:scan_index;
    wire signed [16:0] difference=$signed({1'b0,pending_gain})-$signed({1'b0,context_read[15:0]});
    wire [7:0] fractional_sum={1'b0,context_read[47:41]}+{1'b0,context_read[40:34]};
    wire signed [17:0] next_wide=$signed({2'b0,context_read[15:0]})+
        $signed({{8{context_read[33]}},context_read[33:24]})+$signed({17'd0,fractional_sum[7]});
    wire [15:0] next_gain=context_read[23:16]==0 ? context_read[15:0]:next_wide[15:0];
    wire [47:0] ramp_word=context_read[23:16]==0 ? context_read:
        {fractional_sum[6:0],context_read[40:24],8'(context_read[23:16]-1'b1),next_gain};
    wire [47:0] command_word=difference==0 ? {32'd0,pending_gain}:
        {7'd0,difference[6:0],difference[16:7],8'd128,context_read[15:0]};
    wire write_enable=rst_n && ((!initialized&&!init_issued) || state==CMD_WRITE || state==SCAN_WRITE);
    wire [4:0] write_address=!initialized ? init_index:state==CMD_WRITE ? pending_owner:scan_index;
    wire [47:0] write_word=!initialized ? 48'h000000008000:state==CMD_WRITE ? command_word:ramp_word;
    assign command_ready=initialized && state==IDLE && !pending_tick && !sample_tick && !context_busy;
    // Parallel decode/masked-OR avoids cascading the voice-to-owner mux into
    // a variable-index gain mux. Read latency and invalid-owner unity stay exact.
    reg [15:0] selected_gain;integer read_index;
    always @*begin
        selected_gain=0;
        for(read_index=0;read_index<OWNERS;read_index=read_index+1)
            selected_gain=selected_gain|(gain_mirror[read_index*16+:16]&{16{read_owner==read_index}});
        if(read_owner>=OWNERS)selected_gain[15]=1'b1;
    end
    // 独立同步读口供声部流水线使用；复制窄current字段，避免三端口RAM退化。
    always @(posedge clk) begin

        read_gain<=initialized ? selected_gain:16'd32768;
        if(write_enable)for(mirror_index=0;mirror_index<OWNERS;mirror_index=mirror_index+1)if(write_address==mirror_index)gain_mirror[mirror_index*16+:16]<=write_word[15:0];
    end
    always @(posedge clk)begin
        context_read<=internal_address<OWNERS ? contexts[internal_address*48+:48]:48'd0;
        if(write_enable)for(context_index=0;context_index<OWNERS;context_index=context_index+1)
            if(write_address==context_index)contexts[context_index*48+:48]<=write_word;
    end
    always @(posedge clk) begin
        command_done<=0;frame_done<=0;
        if(!rst_n) begin
            initialized<=0;init_index<=0;init_issued<=0;scan_index<=0;pending_owner<=0;pending_gain<=32768;
            state<=IDLE;pending_tick<=0;command_error<=0;deadline_error<=0;
        end else if(!initialized) begin
            if(!init_issued)init_issued<=1;
            else if(!context_busy)begin
                init_issued<=0;
                if(init_index==31)initialized<=1;else init_index<=init_index+1'b1;
            end
        end else begin
            if(sample_tick) begin
                if(pending_tick || state==SCAN_WAIT || state==SCAN_WRITE) deadline_error<=1;
                else pending_tick<=1;
            end
            case(state)
                IDLE:begin
                    if(sample_tick || pending_tick) begin pending_tick<=0;scan_index<=0;state<=SCAN_WAIT;end
                    else if(command_valid) begin
                        command_error<=command_owner>=OWNERS;
                        if(command_owner>=OWNERS) command_done<=1;
                        else begin pending_owner<=command_owner;pending_gain<=command_gain;state<=CMD_WAIT;end
                    end
                end
                CMD_WAIT:if(context_valid)state<=CMD_WRITE;
                CMD_WRITE:begin command_done<=1;state<=IDLE;end
                SCAN_WAIT:if(context_valid)state<=SCAN_WRITE;
                SCAN_WRITE:begin
                    if(scan_index==OWNERS-1) begin frame_done<=1;state<=IDLE;end
                    else begin scan_index<=scan_index+1'b1;state<=SCAN_WAIT;end
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
