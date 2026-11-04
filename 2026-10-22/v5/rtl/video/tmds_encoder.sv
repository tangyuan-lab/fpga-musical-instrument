`default_nettype none
// DVI TMDS 8b->10b：先减少跳变，再控制累计直流偏差。消隐期输出控制码。
// 数据和控制同步延迟一个像素周期；蓝色通道的 c0/c1 承载 HSync/VSync。
module tmds_encoder(input wire clk,rst_n,de,c0,c1,input wire [7:0] data,
    output reg [9:0] symbol
);
    reg [8:0] qm;
    reg signed [5:0] disparity;
    reg [9:0] next_symbol;
    integer ones,balance,next_disparity,j;
    reg use_xnor;
    always @* begin
        ones=0;
        for(j=0;j<8;j=j+1) ones=ones+data[j];
        use_xnor=(ones>4 || (ones==4 && !data[0]));
        qm[0]=data[0];
        for(j=1;j<8;j=j+1) qm[j]=use_xnor ? ~(qm[j-1]^data[j]) : qm[j-1]^data[j];
        qm[8]=!use_xnor;
        ones=0;
        for(j=0;j<8;j=j+1) ones=ones+qm[j];
        balance=2*ones-8;
        next_disparity=$signed(disparity);
        if(!de) begin
            case({c1,c0})
                0: next_symbol=10'b1101010100;
                1: next_symbol=10'b0010101011;
                2: next_symbol=10'b0101010100;
                3: next_symbol=10'b1010101011;
            endcase
            next_disparity=0;
        end else if(disparity==0 || balance==0) begin
            next_symbol={~qm[8],qm[8],(qm[8] ? qm[7:0] : ~qm[7:0])};
            next_disparity=$signed(disparity)+(qm[8] ? balance : -balance);
        end else if((disparity>0 && balance>0)||(disparity<0 && balance<0)) begin
            next_symbol={1'b1,qm[8],~qm[7:0]};
            next_disparity=$signed(disparity)-balance+(qm[8] ? 2 : 0);
        end else begin
            next_symbol={1'b0,qm[8],qm[7:0]};
            next_disparity=$signed(disparity)+balance-(qm[8] ? 0 : 2);
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin symbol<=10'b1101010100; disparity<=0; end
        else begin symbol<=next_symbol; disparity<=next_disparity[5:0]; end
    end
endmodule
`default_nettype wire
