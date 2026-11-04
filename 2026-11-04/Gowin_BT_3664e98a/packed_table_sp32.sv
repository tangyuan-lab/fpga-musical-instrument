`timescale 1ns/1ps
`default_nettype none
// 宽而浅的配置行按32位连续打包进单端口RAM；不为每个字段独占半空存储块。
// 写请求必须间隔至少WORDS+1拍；读地址保持到read_valid，整行一次性提交。
module packed_table_sp32 #(parameter integer WIDTH=160,ADDRESS_WIDTH=7)(
    input wire clk,rst_n,write_enable,
    input wire [ADDRESS_WIDTH-1:0] write_address,read_address,
    input wire [WIDTH-1:0] write_data,output reg [WIDTH-1:0] read_data,
    output wire read_valid,write_busy,output reg overflow
);
    localparam integer WORDS=(WIDTH+31)/32,ROWS=1<<ADDRESS_WIDTH,BANKS=(ROWS*WORDS+511)/512;
    localparam integer IW=WORDS<=1 ? 1:$clog2(WORDS),MW=$clog2(BANKS*512);
    localparam IDLE=0,ISSUE=1,LATCH=2,WRITE=3;
    reg [1:0] state;reg [IW-1:0] index;reg [ADDRESS_WIDTH-1:0] row,tag;
    reg [WORDS*32-1:0] write_buffer,read_buffer;reg cached;
    wire [MW-1:0] address=row*WORDS+index;
    wire [31:0] bank_index=32'(address)>>9;
    wire [31:0] bank_data[0:BANKS-1];wire [31:0] word=bank_data[bank_index];
    assign write_busy=state==WRITE||write_enable;
    assign read_valid=cached&&tag==read_address&&!write_busy;
    genvar g;generate for(g=0;g<BANKS;g=g+1)begin:bank
        SP #(.BIT_WIDTH(32),.READ_MODE(1'b0),.WRITE_MODE(2'b00),.RESET_MODE("SYNC")) ram(
            .DO(bank_data[g]),.DI(write_buffer[index*32+:32]),.AD({address[8:0],1'b0,4'b1111}),
            .BLKSEL(3'b000),.WRE(state==WRITE),.CLK(clk),.CE((state==ISSUE||state==WRITE)&&bank_index==g),
            .OCE(1'b1),.RESET(1'b0));
    end endgenerate
    wire [WORDS*32-1:0] collected=(read_buffer&~({{(WORDS*32-32){1'b0}},32'hffffffff}<<(index*32)))|
        ({{(WORDS*32-32){1'b0}},word}<<(index*32));
    always @(posedge clk)begin
        if(!rst_n)begin state<=IDLE;index<=0;row<=0;tag<=0;cached<=0;overflow<=0;read_data<=0;read_buffer<=0;write_buffer<=0;end
        else if(write_enable)begin
            if(state==WRITE)overflow<=1;
            state<=WRITE;index<=0;row<=write_address;write_buffer<={{(WORDS*32-WIDTH){1'b0}},write_data};cached<=0;
        end else case(state)
            IDLE:if(!cached||tag!=read_address)begin row<=read_address;index<=0;state<=ISSUE;end
            ISSUE:state<=LATCH;
            LATCH:begin
                read_buffer<=collected;
                if(index==WORDS-1)begin read_data<=collected[WIDTH-1:0];tag<=row;cached<=1;state<=IDLE;end
                else begin index<=index+1'b1;state<=ISSUE;end
            end
            WRITE:if(index==WORDS-1)begin state<=IDLE;index<=0;end else index<=index+1'b1;
        endcase
    end
endmodule
`default_nettype wire
