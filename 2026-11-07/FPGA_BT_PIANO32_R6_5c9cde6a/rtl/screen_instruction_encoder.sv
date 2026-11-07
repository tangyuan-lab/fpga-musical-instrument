`default_nettype none
// 将一条名称/uint32指令编码为字节。与UART握手，三字节FF结束符保持原周期。
module screen_instruction_encoder(input wire clk,rst_n,start,
    input wire [127:0] instruction_name,input wire [31:0] instruction_value,input wire raw_instruction,
    input wire uart_busy,output reg byte_start,output reg [7:0] byte_data,
    output wire advance_field,done);
    reg [3:0] state;reg [127:0] name;reg [79:0] digits;reg [3:0] digit_count,ff_count;
    reg [31:0] binary_value;reg [39:0] bcd_value,bcd_adjusted;reg [5:0] convert_step;
    integer bcd_digit,ascii_digit;
    wire busy=uart_busy;wire send=byte_start;
    assign advance_field=state==6&&!busy&&!send&&ff_count==2;
    assign done=state==7&&!busy&&!send;
    // 逐拍double-dabble：每拍十个独立4位加3后移1位，32拍覆盖整个uint32。
    // 比组合32位除10多几十拍，但仍远短于UART一字节时间；不修改音频与采样调度。
    always @*begin
        bcd_adjusted=bcd_value;
        for(bcd_digit=0;bcd_digit<10;bcd_digit=bcd_digit+1)
            if(bcd_value[bcd_digit*4+:4]>=5)bcd_adjusted[bcd_digit*4+:4]=bcd_value[bcd_digit*4+:4]+4'd3;
    end

    always @(posedge clk)begin
        byte_start<=0;
        if(!rst_n)begin state<=0;name<=0;digits<=0;digit_count<=0;ff_count<=0;
            binary_value<=0;bcd_value<=0;convert_step<=0;byte_data<=0;end
        else case(state)
            0:if(start)begin name<=instruction_name;binary_value<=instruction_value;
                bcd_value<=0;convert_step<=0;digits<=0;digit_count<=0;state<=3;end
            3:begin
                bcd_value<={bcd_adjusted[38:0],binary_value[31]};binary_value<=binary_value<<1;
                convert_step<=convert_step+1'b1;
                if(convert_step==31)state<=10;
            end
            4:if(!busy&&!send)begin
                if(name[127:120]!=0)begin byte_data<=name[127:120];name<=name<<8;byte_start<=1;end
                else if(raw_instruction)begin ff_count<=0;state<=6;end
                else state<=5;
            end
            5:if(!busy&&!send)begin
                if(digit_count!=0)begin byte_data<=digits[7:0];digits<=digits>>8;digit_count<=digit_count-1'b1;byte_start<=1;end
                else begin ff_count<=0;state<=6;end
            end
            6:if(!busy&&!send)begin byte_data<=8'hff;byte_start<=1;
                if(ff_count==2)begin state<=7;end else ff_count<=ff_count+1'b1;end
            7:if(!busy&&!send)state<=0;
            10:begin
                for(ascii_digit=0;ascii_digit<10;ascii_digit=ascii_digit+1)
                    digits[ascii_digit*8+:8]<={4'd3,bcd_value[39-ascii_digit*4-:4]};
                digit_count<=10;state<=11;
            end
            11:if(digit_count>1 && digits[7:0]==8'd48)begin digits<=digits>>8;digit_count<=digit_count-1'b1;end
                else state<=4;

            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
