`default_nettype none
// 段落小配置表：写命令与读出的当前段相同；换段时调度器等待完整读取窗口。
// 单端口SP32每表一块，写同址时旁路新值；异址写拍不承诺读数据有效。
module control_ram_sp32 #(parameter integer WIDTH=32,ADDRESS_WIDTH=5)(
    input wire clk,write_enable,input wire [ADDRESS_WIDTH-1:0] write_address,read_address,
    input wire [WIDTH-1:0] write_data,output wire [WIDTH-1:0] read_data
);
    localparam integer WORDS=(WIDTH+31)/32;
    wire [8:0] address=write_enable ? 9'(write_address):9'(read_address);wire [WORDS*32-1:0] raw;
    reg forward_valid;reg [WIDTH-1:0] forward_data;
    generate if(WIDTH<=8)begin:small_registers
        reg [(1<<ADDRESS_WIDTH)*WIDTH-1:0] values;reg [WIDTH-1:0] q;integer i;
        always @(posedge clk)begin
            q<=values[read_address*WIDTH+:WIDTH];
            if(write_enable)for(i=0;i<(1<<ADDRESS_WIDTH);i=i+1)if(write_address==i)values[i*WIDTH+:WIDTH]<=write_data;
        end
        assign raw=32'(q);
    end else begin:block_memory
    wire [WORDS*32-1:0] padded_data=write_data;
    for(genvar word_index=0;word_index<WORDS;word_index=word_index+1)begin:g_word
        SP #(.BIT_WIDTH(32),.READ_MODE(1'b0),.WRITE_MODE(2'b00),.RESET_MODE("SYNC")) memory(
            .DO(raw[word_index*32+:32]),.DI(padded_data[word_index*32+:32]),.AD({address,1'b0,4'b1111}),.BLKSEL(3'd0),.WRE(write_enable),
            .CLK(clk),.CE(1'b1),.OCE(1'b1),.RESET(1'b0));
    end
    end endgenerate
    always @(posedge clk)begin forward_valid<=write_enable&&write_address==read_address;if(write_enable)forward_data<=write_data;end
    assign read_data=forward_valid ? forward_data:raw[WIDTH-1:0];
endmodule
`default_nettype wire
