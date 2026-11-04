`default_nettype none
// 8项双时钟FIFO：Gray指针跨域，存储不复位；empty/full隔离未初始化载荷。
module workstation_async_fifo #(parameter integer WIDTH=8, ADDRESS_BITS=3)(
    input wire wr_clk,wr_rst_n,wr_valid,output wire wr_ready,input wire [WIDTH-1:0] wr_data,
    input wire rd_clk,rd_rst_n,output wire rd_valid,input wire rd_ready,output wire [WIDTH-1:0] rd_data
);
    localparam integer PTR=ADDRESS_BITS+1;
    reg [WIDTH-1:0] memory[0:(1<<ADDRESS_BITS)-1];
    reg [PTR-1:0] wbin,wgray,rbin,rgray;
    (* async_reg="true" *) reg [PTR-1:0] rgray_w1,rgray_w2,wgray_r1,wgray_r2;
    reg full,empty;
    wire [PTR-1:0] wn=wbin+(wr_valid&&!full);
    wire [PTR-1:0] rn=rbin+(rd_ready&&!empty);
    wire [PTR-1:0] wg=(wn>>1)^wn,rg=(rn>>1)^rn;
    wire [PTR-1:0] full_compare={~rgray_w2[PTR-1:PTR-2],rgray_w2[PTR-3:0]};
    assign wr_ready=wr_rst_n&&!full;
    assign rd_valid=rd_rst_n&&!empty;
    assign rd_data=memory[rbin[ADDRESS_BITS-1:0]];
    always @(posedge wr_clk)if(wr_valid&&wr_ready)memory[wbin[ADDRESS_BITS-1:0]]<=wr_data;
    always @(posedge wr_clk or negedge wr_rst_n)begin
        if(!wr_rst_n)begin wbin<=0;wgray<=0;full<=0;rgray_w1<=0;rgray_w2<=0;end
        else begin
            rgray_w1<=rgray;rgray_w2<=rgray_w1;
            wbin<=wn;wgray<=wg;full<=wg==full_compare;
        end
    end
    always @(posedge rd_clk or negedge rd_rst_n)begin
        if(!rd_rst_n)begin rbin<=0;rgray<=0;empty<=1;wgray_r1<=0;wgray_r2<=0;end
        else begin
            wgray_r1<=wgray;wgray_r2<=wgray_r1;
            rbin<=rn;rgray<=rg;empty<=rg==wgray_r2;
        end
    end
endmodule
`default_nettype wire
