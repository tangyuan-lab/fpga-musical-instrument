`default_nettype none
// 115200/8N1，空闲高电平；仅在 !busy 时接收 start，发送完成产生 done。
module uart_tx #(parameter integer CLKS_PER_BIT=434)(
    input wire clk,rst_n,start,input wire [7:0] data,
    output reg tx,busy,done
);
    reg [9:0] frame;
    reg [3:0] bit_index;
    reg [15:0] ticks;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin tx<=1; busy<=0; done<=0; frame<=10'h3ff; bit_index<=0; ticks<=0; end
        else begin
            done<=0;
            if(!busy) begin
                tx<=1;
                if(start) begin
                    frame<={1'b1,data,1'b0}; tx<=0; busy<=1;
                    ticks<=CLKS_PER_BIT-1; bit_index<=0;
                end
            end else if(ticks!=0) ticks<=ticks-1'b1;
            else if(bit_index==9) begin busy<=0; done<=1; tx<=1; end
            else begin
                bit_index<=bit_index+1'b1; frame<={1'b1,frame[9:1]};
                tx<=frame[1]; ticks<=CLKS_PER_BIT-1;
            end
        end
    end
endmodule
`default_nettype wire
