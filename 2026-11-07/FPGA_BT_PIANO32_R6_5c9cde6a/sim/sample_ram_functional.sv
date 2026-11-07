`default_nettype none
// 仅整机功能回归使用的等时序RAM模型。物理字节使能由tb_fx_ram/tb_fx_response用原语验证。
// 不进入sources.json/综合；run记录必须明确标记，不能当物理RAM或时序签核证据。
module sample_ram #(parameter integer ADDRESS_WIDTH=12)(
    input wire clk,write_enable,input wire [ADDRESS_WIDTH-1:0] write_address,read_address,
    input wire signed [15:0] write_data,output reg signed [15:0] read_data
);
    reg signed [15:0] memory[0:(1<<ADDRESS_WIDTH)-1];
    reg signed [15:0] first_read;
    integer i;
    initial for(i=0;i<(1<<ADDRESS_WIDTH);i=i+1)memory[i]=0;
    always @(posedge clk)begin
        if(write_enable)memory[write_address]<=write_data;
        first_read<=memory[read_address];read_data<=first_read;
    end
endmodule
`default_nettype wire
