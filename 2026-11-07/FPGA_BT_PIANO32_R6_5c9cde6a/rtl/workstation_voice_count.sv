`default_nettype none
// 32槽观察计数：四位局部真值与进位保存归约，只有末级使用传播进位加法。
// 原实现已是平衡加法树；这里切短的是各级进位串联，不改变位图采样时刻或峰值更新沿。
module workstation_voice_count(input wire [31:0] mask,output wire [5:0] count);
    (* syn_keep=1 *) wire [5:0] rows[0:7];
    (* syn_keep=1 *) wire [5:0] level1[0:5];
    (* syn_keep=1 *) wire [5:0] level2[0:3];
    (* syn_keep=1 *) wire [5:0] level3[0:2];
    (* syn_keep=1 *) wire [5:0] level4[0:1];
    genvar i;
    generate for(i=0;i<8;i=i+1)begin:g_nibble
        wire [3:0] bits=mask[i*4+:4];
        wire [2:0] n;
        assign n[0]=^bits;
        assign n[1]=(bits[0]&bits[1])^(bits[2]&bits[3])^
                    ((bits[0]^bits[1])&(bits[2]^bits[3]));
        assign n[2]=&bits;
        assign rows[i]={3'd0,n};
    end endgenerate
    generate for(i=0;i<2;i=i+1)begin:g_first
        assign level1[2*i]=rows[3*i]^rows[3*i+1]^rows[3*i+2];
        assign level1[2*i+1]=((rows[3*i]&rows[3*i+1])|
             (rows[3*i]&rows[3*i+2])|(rows[3*i+1]&rows[3*i+2]))<<1;
    end endgenerate
    assign level1[4]=rows[6];assign level1[5]=rows[7];
    generate for(i=0;i<2;i=i+1)begin:g_second
        assign level2[2*i]=level1[3*i]^level1[3*i+1]^level1[3*i+2];
        assign level2[2*i+1]=((level1[3*i]&level1[3*i+1])|
             (level1[3*i]&level1[3*i+2])|(level1[3*i+1]&level1[3*i+2]))<<1;
    end endgenerate
    assign level3[0]=level2[0]^level2[1]^level2[2];
    assign level3[1]=((level2[0]&level2[1])|(level2[0]&level2[2])|
                     (level2[1]&level2[2]))<<1;
    assign level3[2]=level2[3];
    assign level4[0]=level3[0]^level3[1]^level3[2];
    assign level4[1]=((level3[0]&level3[1])|(level3[0]&level3[2])|
                     (level3[1]&level3[2]))<<1;
    // 合法总和0..32，六位保留完整结果；未知位仍进入末级算术，不能伪造已知计数。
    assign count=level4[0]+level4[1];
endmodule
`default_nettype wire
