`default_nettype none
// 每轨后级增益：无符号Q1.15，32768=0dB；目标值由轨道/角色/段落混音控制器提供。
// 每次命令从当前值重新斜坡，128个采样后精确到达目标；不改力度，不重触发音符。
// frame_done后所有轨道属于同一采样快照。合成器应在frame_done后启动本帧运算。
module track_gain_bank #(parameter integer OWNERS=18)(
    input wire clk,rst_n,sample_tick,
    input wire command_valid,output wire command_ready,input wire [4:0] command_owner,
    input wire [15:0] command_gain,output reg command_done,command_error,
    input wire [4:0] read_owner,output reg [15:0] read_gain,
    output reg initialized,frame_done,deadline_error
);
    localparam IDLE=3'd0,CMD_WAIT=3'd1,CMD_WRITE=3'd2,SCAN_WAIT=3'd3,SCAN_WRITE=3'd4;
    reg [2:0] state;reg [4:0] init_index,scan_index,pending_owner;
    reg [15:0] pending_gain;reg pending_tick;
    // word = {误差7, 余数7, 有符号步长10, 剩余采样8, 目标16, 当前16}。
    // 不复位RAM；32拍串行初始化，避免整阵列复位退化为大量寄存器。
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [63:0] context_ram[0:31];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [15:0] gain_mirror[0:31];
    reg [63:0] context_read;
    wire [4:0] internal_address=(state==CMD_WAIT || state==CMD_WRITE) ? pending_owner:scan_index;
    wire signed [16:0] difference=$signed({1'b0,pending_gain})-$signed({1'b0,context_read[15:0]});
    wire [7:0] fractional_sum={1'b0,context_read[63:57]}+{1'b0,context_read[56:50]};
    wire signed [17:0] next_wide=$signed({2'b0,context_read[15:0]})+
        $signed({{8{context_read[49]}},context_read[49:40]})+$signed({17'd0,fractional_sum[7]});
    wire [15:0] next_gain=context_read[39:32]==1 ? context_read[31:16]:next_wide[15:0];
    wire [63:0] ramp_word=context_read[39:32]==0 ? context_read:
        {fractional_sum[6:0],context_read[56:40],8'(context_read[39:32]-1'b1),context_read[31:16],next_gain};
    wire [63:0] command_word=difference==0 ? {32'd0,pending_gain,pending_gain}:
        {7'd0,difference[6:0],difference[16:7],8'd128,pending_gain,context_read[15:0]};
    wire write_enable=rst_n && (!initialized || state==CMD_WRITE || state==SCAN_WRITE);
    wire [4:0] write_address=!initialized ? init_index:state==CMD_WRITE ? pending_owner:scan_index;
    wire [63:0] write_word=!initialized ? 64'h0000000080008000:state==CMD_WRITE ? command_word:ramp_word;
    assign command_ready=initialized && state==IDLE && !pending_tick && !sample_tick;
    // 独立同步读口供声部流水线使用；复制窄current字段，避免三端口RAM退化。
    always @(posedge clk) begin
        context_read<=context_ram[internal_address];
        read_gain<=initialized && read_owner<OWNERS ? gain_mirror[read_owner]:16'd32768;
        if(write_enable) begin context_ram[write_address]<=write_word;gain_mirror[write_address]<=write_word[15:0];end
    end
    always @(posedge clk) begin
        command_done<=0;frame_done<=0;
        if(!rst_n) begin
            initialized<=0;init_index<=0;scan_index<=0;pending_owner<=0;pending_gain<=32768;
            state<=IDLE;pending_tick<=0;command_error<=0;deadline_error<=0;
        end else if(!initialized) begin
            if(init_index==31) initialized<=1;
            else init_index<=init_index+1'b1;
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
                CMD_WAIT:state<=CMD_WRITE;
                CMD_WRITE:begin command_done<=1;state<=IDLE;end
                SCAN_WAIT:state<=SCAN_WRITE;
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
