`default_nettype none
// 整包跨时钟：源数据从发出请求到收到确认始终不变；只同步请求/确认位。
// 显示只需最新状态，允许跳过中间画面，不参与音频控制的事件交付。
// 两端复位应共同拉低；目标域可晚于源域释放（例如等待视频 PLL 锁定）。
module snapshot_cdc #(parameter integer WIDTH=116)(
    input wire src_clk,src_rst_n,input wire [WIDTH-1:0] src_data,
    input wire dst_clk,dst_rst_n,output reg [WIDTH-1:0] dst_data,
    output reg dst_valid
);
    reg [WIDTH-1:0] held_data;
    reg request,acknowledge;
    (* async_reg="true" *) reg [1:0] ack_sync,req_sync;
    always @(posedge src_clk or negedge src_rst_n) begin
        if(!src_rst_n) begin held_data<=0; request<=0; ack_sync<=0; end
        else begin
            ack_sync<={ack_sync[0],acknowledge};
            if(ack_sync[1]==request) begin held_data<=src_data; request<=~request; end
        end
    end
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if(!dst_rst_n) begin req_sync<=0; acknowledge<=0; dst_data<=0; dst_valid<=0; end
        else begin
            req_sync<={req_sync[0],request}; dst_valid<=0;
            if(req_sync[1]!=acknowledge) begin
                dst_data<=held_data; acknowledge<=req_sync[1]; dst_valid<=1;
            end
        end
    end
endmodule
`default_nettype wire

