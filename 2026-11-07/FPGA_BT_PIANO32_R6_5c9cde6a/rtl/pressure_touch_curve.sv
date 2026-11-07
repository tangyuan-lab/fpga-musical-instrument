`default_nettype none
// 实体压力键的演奏手感；只处理采集器给出的力度，不修改ADC、校准或开关滞回。
// 输入0..127，灵敏度为1/2/4/8倍，曲线为0线性/1轻触/2重手。
// 最低力度由协议限制为8..64；活动与释音仍由独立key_down决定，不能由最低力度造音。
module pressure_touch_curve(
    input wire [6:0] raw_velocity,
    input wire [1:0] sensitivity,curve,
    input wire [6:0] minimum_velocity,
    output wire [6:0] velocity
);
    wire [9:0] scaled={3'd0,raw_velocity}<<sensitivity;
    wire [6:0] x=scaled>=10'd127 ? 7'd127:scaled[6:0];
    reg [7:0] shaped;
    always @*begin
        shaped={1'b0,x};
        case(curve)
            1:if(x<32)shaped={1'b0,x}<<1;
              else if(x<64)shaped=8'd64+({1'b0,x}-8'd32);
              else shaped=8'd96+(({1'b0,x}-8'd64)>>1);
            2:if(x==127)shaped=8'd127;
              else if(x<64)shaped={1'b0,x}>>1;
              else shaped=8'd32+({1'b0,x}-8'd64)+(({1'b0,x}-8'd64)>>1);
            default:;
        endcase
    end
    assign velocity=shaped<minimum_velocity ? minimum_velocity:shaped[6:0];
endmodule
`default_nettype wire
