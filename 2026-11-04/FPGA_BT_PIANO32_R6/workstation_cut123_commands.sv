`default_nettype none
// 控制仲裁：host为USB/蓝牙桥合并后的单事务入口，屏幕使用独立8项FIFO。
// 完成脉冲返回原host桥；屏幕操作或安全清音不能冒充远程控制的执行结果。
module workstation_cut123_commands(
    input wire clk,rst_n,
    input wire host_valid,input wire [7:0] host_op,input wire [31:0] host_value,host_aux,
    output reg host_done,output reg [7:0] host_result,
    input wire screen_valid,input wire [7:0] screen_op,screen_value,
    input wire safety_stop,timbre_pressed,input wire [4:0] live_patch,
    output wire app_valid,output reg [7:0] app_op,output reg [31:0] app_value,app_aux,
    input wire app_done,input wire [7:0] app_result,
    output wire legacy_valid,output reg [7:0] legacy_op,legacy_value,input wire legacy_error,
    output wire map_valid,output reg [15:0] map_descriptor,
    output wire adsr_valid,output reg [31:0] adsr_value,adsr_aux,
    input wire adsr_done,input wire [7:0] adsr_result,
    output reg [7:0] screen_result,
    output wire [111:0] command_feedback,
    input wire emergency_stop,host_cancel
);
    reg [31:0] staged_value,staged_aux;
    reg pending_host,pending_safety,pending_timbre;
    reg [7:0] pending_op;reg [31:0] pending_value,pending_aux;
    reg [72:0] queue[0:7];reg [3:0] count;reg [2:0] read_index,write_index;
    reg [2:0] state;reg owner;reg [7:0] op;reg [31:0] value,aux;
    wire cancel_host=host_cancel===1'b1;
    reg app_valid_q,legacy_valid_q,map_valid_q,adsr_valid_q;
    assign app_valid=app_valid_q && !(cancel_host && owner);
    assign legacy_valid=legacy_valid_q && !(cancel_host && owner);
    assign map_valid=map_valid_q && !(cancel_host && owner);
    assign adsr_valid=adsr_valid_q && !(cancel_host && owner);
    reg [15:0] service_wait;
    reg [7:0] completed_op,completed_result;reg [31:0] completed_serial,completed_value,completed_aux;
    assign command_feedback={completed_aux,completed_value,completed_serial,completed_result,completed_op};
    wire enqueue=screen_valid && (screen_op<8'h40 || (screen_op>=8'h40 && screen_op<=8'h62) || screen_op>=8'h80);
    wire dequeue=state==0 && !pending_safety && !pending_timbre && !pending_host && count!=0;
    wire [72:0] front=queue[read_index];
    task complete(input [7:0] result);
        begin
            completed_op<=op;completed_result<=result;completed_serial<=completed_serial+1'b1;completed_value<=value;completed_aux<=aux;
            if(owner) begin host_done<=1;host_result<=result;end
            else screen_result<=result;
            state<=0;
        end
    endtask
    always @(posedge clk) begin
        host_done<=0;app_valid_q<=0;legacy_valid_q<=0;map_valid_q<=0;adsr_valid_q<=0;
        if(!rst_n) begin
            state<=0;owner<=0;count<=0;read_index<=0;write_index<=0;service_wait<=0;
            pending_host<=0;pending_safety<=0;pending_timbre<=0;pending_op<=0;pending_value<=0;pending_aux<=0;
            staged_value<=0;staged_aux<=0;op<=0;value<=0;aux<=0;
            host_result<=0;screen_result<=0;app_op<=0;app_value<=0;app_aux<=0;
            legacy_op<=0;legacy_value<=0;map_descriptor<=0;adsr_value<=0;adsr_aux<=0;
            completed_op<=0;completed_result<=0;completed_serial<=0;completed_value<=0;completed_aux<=0;
        end else if(emergency_stop) begin
            // 清除旧播放/试听请求，避免紧急清音后一拍又执行排队的起音命令。
            state<=0;pending_host<=0;pending_safety<=0;pending_timbre<=0;
            count<=0;read_index<=0;write_index<=0;staged_value<=0;staged_aux<=0;
        end else begin
            if(host_valid && !cancel_host) begin pending_host<=1;pending_op<=host_op;pending_value<=host_value;pending_aux<=host_aux;end
            if(cancel_host) pending_host<=0;
            if(safety_stop) pending_safety<=1;
            if(timbre_pressed) pending_timbre<=1;
            if(screen_valid && screen_op>=8'h70 && screen_op<=8'h73) staged_value[(screen_op-8'h70)*8+:8]<=screen_value;
            if(screen_valid && screen_op>=8'h74 && screen_op<=8'h77) staged_aux[(screen_op-8'h74)*8+:8]<=screen_value;
            if(enqueue && (count<8 || dequeue)) begin
                queue[write_index]<=screen_op>=8'hc0 ? {1'b0,8'(screen_op-8'hc0),staged_aux,staged_value}:
                    screen_op>=8'h80 ? {1'b0,8'(screen_op-8'h80),32'd0,24'd0,screen_value}:screen_op<8'h40 ? {1'b1,screen_op,32'd0,24'd0,screen_value} :
                    {1'b0,8'(screen_op-8'h40),staged_aux,staged_value};
                write_index<=write_index+1'b1;
            end else if(enqueue) screen_result<=8'hfe;
            if(dequeue) read_index<=read_index+1'b1;
            case({enqueue && (count<8 || dequeue),dequeue})
                2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:begin end
            endcase
            // 蓝牙取消不清屏幕FIFO，也不产生实体清音；只撤销尚未完成的host服务。
            if(cancel_host && owner && state!=0)begin
                state<=0;service_wait<=0;
                app_valid_q<=0;legacy_valid_q<=0;map_valid_q<=0;adsr_valid_q<=0;
            end else case(state)
                0:begin
                    if(pending_safety || pending_timbre) begin
                        owner<=0;op<=pending_safety ? 8'd15:8'd12;value<=pending_safety ? 32'd0 : 32'd10;aux<=0;state<=1;
                        if(pending_safety && !safety_stop) pending_safety<=0;
                        else if(!pending_safety && !timbre_pressed) pending_timbre<=0;
                    end else if(pending_host && !cancel_host) begin
                        pending_host<=0;owner<=1;op<=pending_op;value<=pending_value;aux<=pending_aux;state<=1;
                    end else if(dequeue) begin
                        owner<=0;op<=front[71:64];value<=front[31:0];aux<=front[63:32];
                        if(front[72]) begin legacy_valid_q<=1;legacy_op<=front[71:64];legacy_value<=front[7:0];state<=4;end
                        else state<=1;
                    end
                end
                1:case(op)
                    // 混音总线：value为字段0..6，aux为目标；现场/伴奏仍由原模式服务持有。
                    52:if(value<=1)begin
                        if(aux<=100)begin legacy_valid_q<=1;legacy_op<=value==0?8'h09:8'h0b;legacy_value<=aux[7:0];state<=4;end
                        else complete(1);
                    end else if(value<=6)begin app_valid_q<=1;app_op<=op;app_value<=value;app_aux<=aux;state<=2;end
                    else complete(1);
                    1:if(value<=4) begin legacy_valid_q<=1;legacy_op<=5;legacy_value<=value[7:0];state<=4;end else complete(1);
                    30:if(value>=1 && value<=3) begin legacy_valid_q<=1;legacy_op<=8'h20;legacy_value<=value[7:0];state<=4;end else complete(1);
                    31:if(value<16) begin legacy_valid_q<=1;legacy_op<=8'h21;legacy_value<=value[7:0];state<=4;end else complete(1);
                    32:begin map_valid_q<=1;map_descriptor<=value[15:0];state<=4;end
                    34:begin
                        // USB保持原来的bank4/A12/D12+S12/R12协议。
                        // fix2屏幕按A16/D16和S16/R16打包；仅在屏幕入口规范化。
                        if(owner)begin adsr_valid_q<=1;adsr_value<=value;adsr_aux<=aux;state<=3;end
                        else if(live_patch==5'd10 && value[31:28]==0 && value[15:12]==0 &&
                                aux[31:28]==0 && aux[15:12]==0)begin
                            adsr_valid_q<=1;
                            adsr_value<={4'd0,value[27:16],value[11:0],4'd10};
                            adsr_aux<={8'd0,aux[27:16],aux[11:0]};state<=3;
                        end else complete(8'd4);
                    end
                    default:begin app_valid_q<=1;app_op<=op;app_value<=value;app_aux<=aux;state<=2;end
                endcase
                2:if(app_done) complete(app_result);else if(service_wait==16'd49999)complete(8'hfd);
                3:if(adsr_done) complete(adsr_result);else if(service_wait==16'd49999)complete(8'hfd);
                4:state<=5; // 命令进入模式服务，再等一拍读取其错误结果。
                5:complete(legacy_error ? 8'd1:8'd0);
                default:state<=0;
            endcase
            if(state==2 || state==3)service_wait<=service_wait+1'b1;else service_wait<=0;
        end
    end
endmodule
`default_nettype wire
