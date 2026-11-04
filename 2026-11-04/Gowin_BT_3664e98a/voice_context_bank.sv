`default_nettype none
// 一个SP32保存32个声部的身份80位及ADSR参数60位，字宽/数值精度不变。
// 每行8字：0..2身份、3..4包络参数，其余保留；不复位RAM，只使缓存失效。
// 起音写入优先；包络扫描优先于普通身份扫描，两个读缓存互不覆盖。
module voice_context_bank(
    input wire clk,rst_n,
    input wire write_enable,input wire [4:0] write_address,
    input wire [79:0] write_owner,input wire [59:0] write_envelope,
    output wire write_busy,
    input wire owner_request,input wire [4:0] owner_address,
    output reg [79:0] owner_data,output wire owner_valid,
    input wire envelope_request,input wire [4:0] envelope_address,
    output reg [59:0] envelope_data,output wire envelope_valid
);
    localparam IDLE=0,WRITE=1,OWNER0=2,OWNER1=3,OWNER2=4,ENV0=5,ENV1=6;
    reg [2:0] state,word_index;reg [4:0] row,owner_tag,envelope_tag;
    reg owner_cached,envelope_cached;reg [159:0] payload;
    reg [31:0] read_low,read_middle;
    wire need_envelope=envelope_request&&!envelope_valid;
    wire need_owner=owner_request&&!owner_valid;
    wire accept_write=rst_n&&state==IDLE&&write_enable;
    wire launch_env=rst_n&&state==IDLE&&!write_enable&&need_envelope;
    wire launch_owner=rst_n&&state==IDLE&&!write_enable&&!need_envelope&&need_owner;
    assign owner_valid=owner_cached&&owner_tag==owner_address&&!write_enable&&state!=WRITE;
    assign envelope_valid=envelope_cached&&envelope_tag==envelope_address&&!write_enable&&state!=WRITE;
    assign write_busy=state!=IDLE;
    wire enable=rst_n&&(accept_write||state==WRITE||launch_env||launch_owner||state==OWNER0||state==OWNER1||state==ENV0);
    wire writing=accept_write||state==WRITE;
    wire [8:0] address=accept_write ? {1'b0,write_address,3'd0}:
        state==WRITE ? {1'b0,row,word_index}:
        launch_env ? {1'b0,envelope_address,3'd3}:
        launch_owner ? {1'b0,owner_address,3'd0}:
        state==OWNER0 ? {1'b0,row,3'd1}:state==OWNER1 ? {1'b0,row,3'd2}:{1'b0,row,3'd4};
    wire [159:0] new_payload={4'd0,write_envelope,16'd0,write_owner};
    wire [31:0] write_data=accept_write ? new_payload[31:0]:payload[word_index*32+:32];
    wire [31:0] q;
    SP #(.BIT_WIDTH(32),.READ_MODE(1'b0),.WRITE_MODE(2'b00),.RESET_MODE("SYNC")) memory(
        .DO(q),.DI(write_data),.AD({address,1'b0,4'b1111}),.BLKSEL(3'd0),.WRE(writing),
        .CLK(clk),.CE(enable),.OCE(1'b1),.RESET(1'b0));
    always @(posedge clk)begin
        if(!rst_n)begin
            state<=IDLE;word_index<=0;row<=0;owner_tag<=0;envelope_tag<=0;
            owner_cached<=0;envelope_cached<=0;payload<=0;read_low<=0;read_middle<=0;
            owner_data<=0;envelope_data<=0;
        end else case(state)
            IDLE:if(accept_write)begin
                payload<=new_payload;row<=write_address;word_index<=1;state<=WRITE;
                if(owner_tag==write_address)owner_cached<=0;
                if(envelope_tag==write_address)envelope_cached<=0;
            end else if(launch_env)begin row<=envelope_address;state<=ENV0;end
              else if(launch_owner)begin row<=owner_address;state<=OWNER0;end
            WRITE:if(word_index==4)state<=IDLE;else word_index<=word_index+1'b1;
            OWNER0:begin read_low<=q;state<=OWNER1;end
            OWNER1:begin read_middle<=q;state<=OWNER2;end
            OWNER2:begin owner_data<={q[15:0],read_middle,read_low};owner_tag<=row;owner_cached<=1;state<=IDLE;end
            ENV0:begin read_low<=q;state<=ENV1;end
            ENV1:begin envelope_data<={q[27:0],read_low};envelope_tag<=row;envelope_cached<=1;state<=IDLE;end
            default:state<=IDLE;
        endcase
    end
endmodule
`default_nettype wire
