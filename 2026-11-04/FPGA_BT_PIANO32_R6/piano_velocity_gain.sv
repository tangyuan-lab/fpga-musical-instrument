`default_nettype none
// Bounded UQ1.23 excitation gain. Native modal bands follow their bank on transpose.
// Only shifts/adds: v=127 is exactly unity in every profile and band.
module piano_velocity_gain(
    input wire [6:0] velocity,
    input wire [1:0] profile,
    input wire [31:0] native_frequency,
    output reg [23:0] gain
);
    wire [7:0] x={1'b0,velocity}+8'd1;
    wire [12:0] seven_x=({5'd0,x}<<3)-{5'd0,x};
    wire [12:0] thirtyone_x=({5'd0,x}<<5)-{5'd0,x};
    always @*begin
        gain=24'd8388608;
        if(native_frequency>=32'd223696213)case(profile)
            1:gain=24'd4194304+({16'd0,x}<<15);
            2:gain=24'd1048576+({11'd0,seven_x}<<13);
            3:gain=24'd262144+({11'd0,thirtyone_x}<<11);
            default:;
        endcase
        else if(native_frequency>=32'd53687091)case(profile)
            1:gain=24'd7340032+({16'd0,x}<<13);
            2:gain=24'd6291456+({16'd0,x}<<14);
            3:gain=24'd4194304+({16'd0,x}<<15);
            default:;
        endcase
    end
endmodule
`default_nettype wire
