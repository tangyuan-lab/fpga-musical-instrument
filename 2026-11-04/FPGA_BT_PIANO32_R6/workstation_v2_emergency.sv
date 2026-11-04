`default_nettype none
// CRC已由上游帧解析器验收。0x3B一字节位图：bit0清音、bit1取消资源事务。
// 普通ACK借用资源模块的输出寄存器并锁住后续请求；只暂存紧急ACK元数据。
// 动作立即产生一拍脉冲，UART发送不可在字节中途抢占，避免增加两份768位寄存器。
module workstation_v2_emergency(
    input wire clk,rst_n,
    input wire frame_valid,input wire [7:0] frame_type,input wire [15:0] frame_seq,frame_length,
    input wire [1055:0] payload,
    output wire normal_frame_valid,output reg panic,abort_upload,
    input wire normal_response_valid,input wire [15:0] normal_response_seq,
    input wire [7:0] normal_response_length,input wire [767:0] normal_response_payload,
    output wire normal_response_busy,
    output reg response_valid,output wire [15:0] response_seq,
    output wire [7:0] response_length,output wire [767:0] response_payload,input wire response_busy
);
    reg normal_pending,urgent_pending,outgoing_urgent;
    reg [15:0] urgent_seq;
    reg [7:0] urgent_result;
    wire emergency_frame=frame_valid && frame_type==8'h3b;
    wire valid_action=frame_length==1 && payload[7:2]==0 && payload[1:0]!=0;
    // 锁住普通请求直到UART锁存普通ACK；资源FSM进入idle后也不能改写这份缓冲。
    assign normal_frame_valid=frame_valid && frame_type!=8'h3b && !normal_pending && !normal_response_valid;
    assign normal_response_busy=response_busy || response_valid || normal_pending || urgent_pending;
    assign response_seq=outgoing_urgent ? urgent_seq:normal_response_seq;
    assign response_length=outgoing_urgent ? 8'd2:normal_response_length;
    assign response_payload=outgoing_urgent ? {752'd0,urgent_result,8'h3b}:normal_response_payload;
    always @(posedge clk) begin
        response_valid<=0;panic<=0;abort_upload<=0;
        if(!rst_n) begin
            normal_pending<=0;urgent_pending<=0;urgent_seq<=0;urgent_result<=0;outgoing_urgent<=0;
        end else begin
            if(normal_response_valid) begin
                normal_pending<=1;
            end
            if(emergency_frame) begin
                // 重试清音/取消均幂等；队列已满时保留旧ACK，主机会用同序号重试。
                if(valid_action) begin panic<=payload[0] || payload[1];abort_upload<=payload[1];end
                if(!urgent_pending) begin urgent_pending<=1;urgent_seq<=frame_seq;urgent_result<=valid_action ? 8'd0:8'd1;end
            end
            if(!response_busy && !response_valid) begin
                if(urgent_pending) begin
                    response_valid<=1;outgoing_urgent<=1;urgent_pending<=0;
                end else if(normal_pending) begin
                    response_valid<=1;outgoing_urgent<=0;normal_pending<=0;
                end
            end
        end
    end
endmodule
`default_nettype wire
