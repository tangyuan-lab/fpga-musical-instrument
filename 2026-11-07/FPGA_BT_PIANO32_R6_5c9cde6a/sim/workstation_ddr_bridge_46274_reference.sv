`default_nettype none
// 应用字节地址→DDR x32字地址。单在途事务，两个8项FIFO完成50/100MHz跨域。
// 读返回不可反压：单在途保证响应FIFO有空间；校准丢失异步作废两侧事务。
module workstation_ddr_bridge_46274_reference #(parameter integer TIMEOUT=1000000)(
    input wire app_clk,app_rst_n,mem_clk,mem_rst_n,calibrated,
    input wire req_valid,output wire req_ready,input wire req_write,
    input wire [31:0] req_address,input wire [255:0] req_data,input wire [31:0] req_mask,
    output wire resp_valid,input wire resp_ready,output wire resp_error,output wire [255:0] resp_data,
    output wire ready,output reg reinit_request,
    output wire [2:0] cmd,output wire cmd_en,input wire cmd_ready,output wire [28:0] addr,
    output wire [255:0] wr_data,output wire [31:0] wr_data_mask,
    output wire wr_data_en,wr_data_end,input wire wr_data_rdy,
    input wire [255:0] rd_data,input wire rd_data_valid,rd_data_end
);
    wire reset_async_n=app_rst_n&&mem_rst_n&&calibrated;
    (* async_reg="true", syn_preserve=1 *) reg [2:0] app_release,mem_release;
    always @(posedge app_clk or negedge reset_async_n)
        if(!reset_async_n)app_release<=0;else app_release<={app_release[1:0],1'b1};
    always @(posedge mem_clk or negedge reset_async_n)
        if(!reset_async_n)mem_release<=0;else mem_release<={mem_release[1:0],1'b1};
    wire ar=app_release[2],mr=mem_release[2];
    // 两侧均释放后才接收新事务；某一侧停钟时不提前发布就绪。
    // 两组同步器由同一取消条件异步清零，校准丢失不能留下旧在线状态。
    (* async_reg="true", syn_preserve=1 *) reg [1:0] mem_online_app,app_online_mem;
    always @(posedge app_clk or negedge ar)
        if(!ar)mem_online_app<=0;else mem_online_app<={mem_online_app[0],mr};
    always @(posedge mem_clk or negedge mr)
        if(!mr)app_online_mem<=0;else app_online_mem<={app_online_mem[0],ar};
    wire app_online=ar&&mem_online_app[1],mem_online=mr&&app_online_mem[1];
    assign ready=app_online;
    reg app_pending;
    wire rq_ready,rq_valid,rq_take;
    wire [320:0] rq_data;
    wire rp_ready,rp_valid,rp_take;
    reg [256:0] rp_data;
    wire [256:0] rp_out;
    reg rp_send;
    assign req_ready=app_online&&!app_pending&&rq_ready;
    always @(posedge app_clk or negedge ar)begin
        if(!ar)app_pending<=0;
        else begin
            if(req_valid&&req_ready)app_pending<=1;
            if(resp_valid&&resp_ready)app_pending<=0;
        end
    end
    workstation_async_fifo #(.WIDTH(321)) requests(
        .wr_clk(app_clk),.wr_rst_n(ar),.wr_valid(req_valid&&req_ready),.wr_ready(rq_ready),
        .wr_data({req_write,req_address,req_data,req_mask}),
        .rd_clk(mem_clk),.rd_rst_n(mr),.rd_valid(rq_valid),.rd_ready(rq_take),.rd_data(rq_data));
    workstation_async_fifo #(.WIDTH(257)) responses(
        .wr_clk(mem_clk),.wr_rst_n(mr),.wr_valid(rp_send),.wr_ready(rp_ready),.wr_data(rp_data),
        .rd_clk(app_clk),.rd_rst_n(ar),.rd_valid(rp_valid),.rd_ready(rp_take),.rd_data(rp_out));
    assign resp_valid=app_online&&rp_valid;
    assign resp_error=rp_out[256];assign resp_data=rp_out[255:0];
    assign rp_take=resp_ready&&resp_valid;
    localparam IDLE=0,ISSUE=1,WAIT_READ=2,RESPOND=3;
    reg [1:0] state;
    reg is_write,cmd_sent,data_sent;
    reg [31:0] address_q,mask_q;
    reg [255:0] data_q;
    // 超时先于下次计数溢出作废事务；只存0..TIMEOUT+1，不展开无用的32位进位链。
    localparam integer TIMER_WIDTH=TIMEOUT<2 ? 2:$clog2(TIMEOUT+2);
    reg [TIMER_WIDTH-1:0] timer;
    assign rq_take=state==IDLE&&mem_online&&!reinit_request;
    assign cmd=is_write ? 3'b000:3'b001;
    assign addr={1'b0,address_q[29:2]};
    assign cmd_en=mr&&state==ISSUE&&!cmd_sent;
    assign wr_data=data_q;assign wr_data_mask=mask_q;
    assign wr_data_en=mr&&state==ISSUE&&is_write&&!data_sent;
    assign wr_data_end=wr_data_en;
    wire cmd_fire=cmd_en&&cmd_ready,data_fire=wr_data_en&&wr_data_rdy;
    always @(posedge mem_clk or negedge mr)begin
        if(!mr)begin state<=IDLE;is_write<=0;cmd_sent<=0;data_sent<=0;address_q<=0;mask_q<=0;data_q<=0;
            rp_send<=0;rp_data<=0;timer<=0;reinit_request<=0;end
        else begin
            rp_send<=0;
            if(state!=IDLE)timer<=timer+1'b1;
            if(state!=IDLE&&timer>=TIMEOUT)begin
                reinit_request<=1;state<=IDLE;
            end else case(state)
                IDLE:if(rq_valid&&rq_take)begin
                    {is_write,address_q,data_q,mask_q}<=rq_data;
                    cmd_sent<=0;data_sent<=0;timer<=0;
                    if(rq_data[319:318]!=0||rq_data[292:288]!=0)begin rp_data<={1'b1,256'd0};state<=RESPOND;end
                    else state<=ISSUE;
                end
                ISSUE:begin
                    if(cmd_fire)cmd_sent<=1;
                    if(data_fire)data_sent<=1;
                    if((cmd_sent||cmd_fire)&&(!is_write||data_sent||data_fire))begin
                        timer<=0;
                        if(is_write)begin rp_data<=0;state<=RESPOND;end
                        else state<=WAIT_READ;
                    end
                end
                WAIT_READ:if(rd_data_valid)begin
                    rp_data<={!rd_data_end,rd_data};state<=RESPOND;
                end
                RESPOND:if(rp_ready)begin rp_send<=1;state<=IDLE;end
            endcase
        end
    end
endmodule
`default_nettype wire
