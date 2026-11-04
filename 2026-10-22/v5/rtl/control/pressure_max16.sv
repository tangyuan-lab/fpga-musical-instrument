`default_nettype none
// 16路压力的四级同步最大值树，仅供状态显示；80ns延迟不进入声音控制路径。
module pressure_max16 #(
    parameter integer KEY_COUNT=16,ADC_BITS=12
)(input wire clk,rst_n,input wire [KEY_COUNT*ADC_BITS-1:0] values,output reg [ADC_BITS-1:0] maximum);
    wire [ADC_BITS-1:0] leaf[0:15];
    reg [ADC_BITS-1:0] pairs[0:7],quarters[0:3],halves[0:1];
    genvar g;generate for(g=0;g<16;g=g+1) begin:g_leaf
        if(g<KEY_COUNT) assign leaf[g]=values[g*ADC_BITS+:ADC_BITS];
        else assign leaf[g]=0;
    end endgenerate
    integer i;
    always @(posedge clk) begin
        if(!rst_n) begin
            maximum<=0;
            for(i=0;i<8;i=i+1) pairs[i]<=0;
            for(i=0;i<4;i=i+1) quarters[i]<=0;
            for(i=0;i<2;i=i+1) halves[i]<=0;
        end else begin
            for(i=0;i<8;i=i+1) pairs[i]<=leaf[i*2]>leaf[i*2+1] ? leaf[i*2]:leaf[i*2+1];
            for(i=0;i<4;i=i+1) quarters[i]<=pairs[i*2]>pairs[i*2+1] ? pairs[i*2]:pairs[i*2+1];
            for(i=0;i<2;i=i+1) halves[i]<=quarters[i*2]>quarters[i*2+1] ? quarters[i*2]:quarters[i*2+1];
            maximum<=halves[0]>halves[1] ? halves[0]:halves[1];
        end
    end
endmodule
`default_nettype wire
