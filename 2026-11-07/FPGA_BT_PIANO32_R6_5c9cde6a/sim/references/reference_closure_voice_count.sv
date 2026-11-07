`default_nettype none
// 32槽观察计数：显式扩位的平衡树；组合输出与输入位图属于同一采样时刻。
module reference_closure_voice_count(input wire [31:0] mask,output wire [5:0] count);
    wire [1:0] pairs[0:15];
    wire [2:0] groups4[0:7];
    wire [3:0] groups8[0:3];
    wire [4:0] groups16[0:1];
    genvar i;
    generate
        for(i=0;i<16;i=i+1)begin:g2
            assign pairs[i]={1'b0,mask[2*i]}+{1'b0,mask[2*i+1]};
        end
        for(i=0;i<8;i=i+1)begin:g4
            assign groups4[i]={1'b0,pairs[2*i]}+{1'b0,pairs[2*i+1]};
        end
        for(i=0;i<4;i=i+1)begin:g8
            assign groups8[i]={1'b0,groups4[2*i]}+{1'b0,groups4[2*i+1]};
        end
        for(i=0;i<2;i=i+1)begin:g16
            assign groups16[i]={1'b0,groups8[2*i]}+{1'b0,groups8[2*i+1]};
        end
    endgenerate
    assign count={1'b0,groups16[0]}+{1'b0,groups16[1]};
endmodule
`default_nettype wire
