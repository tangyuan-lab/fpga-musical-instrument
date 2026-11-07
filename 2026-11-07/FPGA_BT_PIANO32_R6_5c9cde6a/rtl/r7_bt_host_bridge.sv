`default_nettype none
// 原commands接口接受单拍请求，没有ready；本桥只派发一份远程事务。
// USB与蓝牙完成分流。撤销仅作用于蓝牙owner，保留屏幕/实体命令。
module r7_bt_host_bridge(
    input wire clk,rst_n,global_stop,
    input wire usb_valid,input wire [7:0] usb_op,input wire [31:0] usb_value,usb_aux,
    output reg usb_done,output reg [7:0] usb_result,
    input wire bt_valid,input wire [7:0] bt_op,input wire [31:0] bt_value,bt_aux,
    output wire bt_ready,output reg bt_done,output reg [7:0] bt_result,
    input wire bt_cancel,
    output wire host_valid,output wire [7:0] host_op,output wire [31:0] host_value,host_aux,
    input wire host_done,input wire [7:0] host_result,
    output wire host_cancel,output wire remote_idle
);
    reg busy,owner_bt;reg [1:0] drain;
    wire usb_known=(^{usb_op,usb_value,usb_aux})!==1'bx;
    wire bt_known=(^{bt_op,bt_value,bt_aux})!==1'bx;
    wire idle=!busy && drain==0 && global_stop===1'b0;
    wire usb_fire=idle && usb_valid===1'b1 && usb_known;
    wire bt_fire=bt_valid===1'b1 && bt_ready;
    assign bt_ready=idle && usb_valid===1'b0 && bt_cancel===1'b0 && bt_known;
    reg dispatch_valid;
    reg [7:0] dispatch_op;
    reg [31:0] dispatch_value,dispatch_aux;
    // 单在途缓冲只含72位业务参数；序号、会话和整帧留在协议源。
    assign host_valid=dispatch_valid&&!host_cancel&&global_stop===1'b0;
    assign host_op=dispatch_op;
    assign host_value=dispatch_value;
    assign host_aux=dispatch_aux;
    assign host_cancel=busy && owner_bt && bt_cancel===1'b1;
    assign remote_idle=idle && usb_valid===1'b0;
    always @(posedge clk)begin
        if(usb_fire||bt_fire)begin
            dispatch_op<=usb_fire ? usb_op:bt_op;
            dispatch_value<=usb_fire ? usb_value:bt_value;
            dispatch_aux<=usb_fire ? usb_aux:bt_aux;
        end
    end
    always @(posedge clk) begin
        usb_done<=0;bt_done<=0;dispatch_valid<=0;
        if(!rst_n)begin busy<=0;owner_bt<=0;drain<=0;usb_result<=0;bt_result<=0;end
        else if(global_stop)begin
            busy<=0;drain<=2;
            if(busy && !owner_bt)begin usb_done<=1;usb_result<=8'd7;end
        end
        else begin
            if(drain!=0)drain<=drain-1'b1;
            if(host_cancel)begin busy<=0;drain<=2;end
            else if(busy && host_done===1'b1)begin
                busy<=0;
                if(owner_bt)begin bt_done<=1;bt_result<=host_result;end
                else begin usb_done<=1;usb_result<=host_result;end
            end
            if(usb_fire || bt_fire)begin
                busy<=1;owner_bt<=bt_fire;dispatch_valid<=1;
            end
            // 原USB资源服务只发单拍；被拒绝必须有显式结果，不能覆盖蓝牙owner。
            if(usb_valid===1'b1 && !usb_fire)begin usb_done<=1;usb_result<=usb_known ? 8'hf8:8'hf9;end
        end
    end
endmodule
`default_nettype wire
