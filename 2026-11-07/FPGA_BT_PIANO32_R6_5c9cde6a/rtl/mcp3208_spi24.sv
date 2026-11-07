`default_nettype none
// 一个MCP3208 mode0事务的物理层，CS高至少HALF_PERIOD+1拍。
// done在最后下降沿前组合有效，采样调度可在同沿锁存已经接收的12位。
module mcp3208_spi24 #(parameter integer HALF_PERIOD=25)(
    input wire clk,rst_n,enable,chip,input wire [2:0] channel,input wire miso,
    output reg sclk,mosi,cs0_n,cs1_n,output wire [11:0] sample_data,output wire done);
    localparam integer HALF_COUNT_WIDTH=(HALF_PERIOD<=1)?1:$clog2(HALF_PERIOD+1);
    reg active;reg [HALF_COUNT_WIDTH-1:0] half_count;reg [4:0] bit_count;
    reg [23:0] tx_shift,rx_shift;
    wire edge_due=HALF_PERIOD<=1||half_count==HALF_PERIOD-1;
    assign sample_data=rx_shift[11:0];
    assign done=rst_n&&enable&&active&&edge_due&&sclk&&bit_count==24;
    function automatic [23:0] make_command(input [2:0] ch);
        make_command={8'h06|{7'd0,ch[2]},ch[1:0],6'd0,8'd0};
    endfunction
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin active<=0;half_count<=0;bit_count<=0;tx_shift<=0;rx_shift<=0;sclk<=0;mosi<=0;cs0_n<=1;cs1_n<=1;end
        else if(!enable)begin active<=0;half_count<=0;sclk<=0;cs0_n<=1;cs1_n<=1;end
        else if(!active)begin
            sclk<=0;mosi<=0;cs0_n<=1;cs1_n<=1;
            if(half_count==HALF_PERIOD)begin
                half_count<=0;active<=1;bit_count<=0;rx_shift<=0;tx_shift<=make_command(channel);
                if(!chip)cs0_n<=0;else cs1_n<=0;
            end else half_count<=half_count+1'b1;
        end else if(edge_due)begin
            half_count<=0;
            if(!sclk)begin
                sclk<=1;if(bit_count>=12&&bit_count<=23)rx_shift<={rx_shift[22:0],miso};
                bit_count<=bit_count+1'b1;
            end else begin
                sclk<=0;
                if(bit_count==24)begin active<=0;mosi<=0;cs0_n<=1;cs1_n<=1;end
                else begin tx_shift<={tx_shift[22:0],1'b0};mosi<=tx_shift[22];end
            end
        end else half_count<=half_count+1'b1;
    end
endmodule
`default_nettype wire
