`default_nettype none
// 控制仲裁：USB一次只有一个待确认事务，屏幕使用8项FIFO。
// 完成脉冲按请求来源返回，屏幕操作或安全清音绝不冒充USB的执行结果。
module workstation_v2_commands(
    input wire clk,rst_n,
    input wire host_valid,input wire [7:0] host_op,input wire [31:0] host_value,host_aux,
    output reg host_done,output reg [7:0] host_result,
    input wire screen_valid,input wire [7:0] screen_op,screen_value,
    input wire safety_stop,timbre_pressed,input wire [3:0] live_patch,
    output reg app_valid,output reg [7:0] app_op,output reg [31:0] app_value,app_aux,
    input wire app_done,input wire [7:0] app_result,
    output reg legacy_valid,output reg [7:0] legacy_op,legacy_value,input wire legacy_error,
    output reg map_valid,output reg [15:0] map_descriptor,
    output reg adsr_valid,output reg [31:0] adsr_value,adsr_aux,
    input wire adsr_done,input wire [7:0] adsr_result,
    output reg [7:0] screen_result,
    output wire [111:0] command_feedback,
    input wire emergency_stop
);
    reg [31:0] staged_value,staged_aux;
    reg pending_host,pending_safety,pending_timbre;
    reg [7:0] pending_op;reg [31:0] pending_value,pending_aux;
    reg [72:0] queue[0:7];reg [3:0] count;reg [2:0] read_index,write_index;
    reg [2:0] state;reg owner;reg [7:0] op;reg [31:0] value,aux;
    reg [7:0] completed_op,completed_result;reg [31:0] completed_serial,completed_value,completed_aux;
    assign command_feedback={completed_aux,completed_value,completed_serial,completed_result,completed_op};
    wire enqueue=screen_valid && (screen_op<8'h40 || (screen_op>=8'h40 && screen_op<=8'h62));
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
        host_done<=0;app_valid<=0;legacy_valid<=0;map_valid<=0;adsr_valid<=0;
        if(!rst_n) begin
            state<=0;owner<=0;count<=0;read_index<=0;write_index<=0;
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
            if(host_valid) begin pending_host<=1;pending_op<=host_op;pending_value<=host_value;pending_aux<=host_aux;end
            if(safety_stop) pending_safety<=1;
            if(timbre_pressed) pending_timbre<=1;
            if(screen_valid && screen_op>=8'h70 && screen_op<=8'h73) staged_value[(screen_op-8'h70)*8+:8]<=screen_value;
            if(screen_valid && screen_op>=8'h74 && screen_op<=8'h77) staged_aux[(screen_op-8'h74)*8+:8]<=screen_value;
            if(enqueue && (count<8 || dequeue)) begin
                queue[write_index]<=screen_op<8'h40 ? {1'b1,screen_op,32'd0,24'd0,screen_value} :
                    {1'b0,8'(screen_op-8'h40),staged_aux,staged_value};
                write_index<=write_index+1'b1;
            end else if(enqueue) screen_result<=8'hfe;
            if(dequeue) read_index<=read_index+1'b1;
            case({enqueue && (count<8 || dequeue),dequeue})
                2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:begin end
            endcase
            case(state)
                0:begin
                    if(pending_safety || pending_timbre) begin
                        owner<=0;op<=pending_safety ? 8'd15:8'd12;value<=pending_safety ? 32'd0 : (live_patch==0 ? 32'd1:32'd0);aux<=0;state<=1;
                        if(pending_safety && !safety_stop) pending_safety<=0;
                        else if(!pending_safety && !timbre_pressed) pending_timbre<=0;
                    end else if(pending_host) begin
                        pending_host<=0;owner<=1;op<=pending_op;value<=pending_value;aux<=pending_aux;state<=1;
                    end else if(dequeue) begin
                        owner<=0;op<=front[71:64];value<=front[31:0];aux<=front[63:32];
                        if(front[72]) begin legacy_valid<=1;legacy_op<=front[71:64];legacy_value<=front[7:0];state<=4;end
                        else state<=1;
                    end
                end
                1:case(op)
                    1:if(value<=4) begin legacy_valid<=1;legacy_op<=5;legacy_value<=value[7:0];state<=4;end else complete(1);
                    30:if(value>=1 && value<=3) begin legacy_valid<=1;legacy_op<=8'h20;legacy_value<=value[7:0];state<=4;end else complete(1);
                    31:if(value<16) begin legacy_valid<=1;legacy_op<=8'h21;legacy_value<=value[7:0];state<=4;end else complete(1);
                    32:begin map_valid<=1;map_descriptor<=value[15:0];state<=4;end
                    34:begin adsr_valid<=1;adsr_value<=value;adsr_aux<=aux;state<=3;end
                    default:begin app_valid<=1;app_op<=op;app_value<=value;app_aux<=aux;state<=2;end
                endcase
                2:if(app_done) complete(app_result);
                3:if(adsr_done) complete(adsr_result);
                4:state<=5; // 命令进入模式服务，再等一拍读取其错误结果。
                5:complete(legacy_error ? 8'd1:8'd0);
                default:state<=0;
            endcase
        end
    end
endmodule
`default_nettype wire
