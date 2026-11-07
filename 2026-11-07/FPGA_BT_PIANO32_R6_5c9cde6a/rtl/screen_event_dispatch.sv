`default_nettype none
// 屏幕协议事件按目的地分发；ACK仅进入显示协议服务，普通控制进入业务适配器。
module screen_event_dispatch(input wire valid,input wire [7:0] op,value,
    output wire control_valid,output wire [7:0] control_op,control_value,
    output wire wave_valid,output wire [7:0] wave_op,wave_value);
    wire wave_event=op==8'h6a||op==8'h6c||op==8'h6d;
    assign control_valid=valid&&!wave_event;
    assign control_op=op;assign control_value=value;
    assign wave_valid=valid&&wave_event;
    assign wave_op=op;assign wave_value=value;
endmodule
`default_nettype wire
