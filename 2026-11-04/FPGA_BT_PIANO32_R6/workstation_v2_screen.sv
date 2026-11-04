`default_nettype none
// 屏幕链路只发送FPGA确认的状态，按字符生成命令；不展开96字节可变写缓存。
// 数字固定10位十进制，显示名最多32字节GB2312，命令以FF FF FF结束。
module workstation_v2_screen #(
    parameter integer CLKS_PER_BIT=434,REFRESH_CLOCKS=50000
)(
    input wire clk,rst_n,input wire [223:0] status_data,input wire [31:0] directory_revision,input wire [47:0] envelope_data,
    input wire [175:0] runtime_data,input wire [111:0] command_feedback,
    output reg [3:0] catalog_index,input wire [255:0] catalog_name,input wire catalog_ready,
    input wire [31:0] catalog_duration,input wire [5:0] catalog_sections,output wire tx
);
    reg [31:0] last_revision,counter,convert_value;reg [6:0] message;reg [5:0] convert_bit;
    reg [3:0] state,refresh_cycles;reg [6:0] position;reg [1:0] terminator;
    reg [39:0] bcd;reg [3:0] adjust_index;reg [255:0] name_latch;reg ready_latch,start;
    reg [7:0] tx_byte;wire busy,done;
    reg [223:0] status_latch;reg [175:0] runtime_latch;reg [111:0] feedback_latch;reg [47:0] envelope_latch;reg [31:0] snapshot;
    wire numeric=message<41;
    wire two_digits=numeric ? message>=10:catalog_index>=10;
    wire [3:0] prefix_length=numeric ? (two_digits ? 9:8) : (two_digits ? 8:7);
    wire [6:0] body_position=position-{3'd0,prefix_length};
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart(.clk(clk),.rst_n(rst_n),.start(start),.data(tx_byte),.tx(tx),.busy(busy),.done(done));
    function automatic [31:0] field_value(input [6:0] n,input [223:0] s);
        case(n)
            0:field_value={24'd0,s[7:0]};1:field_value={24'd0,s[15:8]};2:field_value={24'd0,s[23:16]};
            3:field_value={24'd0,s[31:24]};4:field_value={24'd0,s[39:32]};5:field_value={24'd0,s[47:40]};
            6:field_value=s[79:48];7:field_value=s[111:80];8:field_value=s[143:112];
            9:field_value={16'd0,s[159:144]};10:field_value={16'd0,s[175:160]};11:field_value=s[207:176];
            12:field_value={24'd0,s[215:208]};13:field_value={24'd0,s[223:216]};
            14,15,16,17:field_value={20'd0,envelope_latch[(n-14)*12+:12]};
            18:field_value=feedback_latch[47:16];19:field_value={24'd0,feedback_latch[15:8]};20:field_value={24'd0,feedback_latch[7:0]};
            21,22,23,24:field_value={24'd0,runtime_latch[(n-21)*8+:8]};
            25,26,27,28:field_value={24'd0,runtime_latch[32+(n-25)*8+:8]};
            29:field_value={24'd0,runtime_latch[71:64]};30:field_value={24'd0,runtime_latch[79:72]};
            31:field_value={16'd0,runtime_latch[95:80]};32:field_value=32'($signed(runtime_latch[103:96]))+32'd24;
            33:field_value={24'd0,runtime_latch[111:104]};34:field_value=runtime_latch[143:112];35:field_value=runtime_latch[175:144];
            36:field_value={16'd0,feedback_latch[63:48]};37:field_value={16'd0,feedback_latch[79:64]};
            38:field_value={16'd0,feedback_latch[95:80]};39:field_value={16'd0,feedback_latch[111:96]};
            40:field_value=snapshot;default:field_value=0;
        endcase
    endfunction
    function automatic [7:0] prefix_byte(input [6:0] p,input [6:0] m,input [3:0] c);
        integer local_position;reg number,two;
        begin
            number=m<41;two=number ? m>=10:c>=10;prefix_byte=0;
            if(p==0) prefix_byte=number || m[0] ? "r":"c";
            else if(number && p==1) prefix_byte="x";
            else begin
                local_position=int'(p)-(number ? 2:1);
                if(local_position==0) prefix_byte=two ? (number && m>=40 ? "4":number && m>=30 ? "3":number && m>=20 ? "2":"1"):8'h30+8'(number ? m:c);
                else if(two && local_position==1) prefix_byte=8'h30+8'(number ? (m>=40 ? m-40:m>=30 ? m-30:m>=20 ? m-20:m-10):c-10);
                else begin
                    local_position=local_position-(two ? 2:1);
                    case(local_position)
                        0:prefix_byte=".";1:prefix_byte=number || m[0] ? "v":"t";
                        2:prefix_byte=number || m[0] ? "a":"x";3:prefix_byte=number || m[0] ? "l":"t";4:prefix_byte="=";
                        default:prefix_byte=0;
                    endcase
                end
            end
        end
    endfunction
    integer i;reg [39:0] next_bcd;
    always @(posedge clk) begin
        start<=0;
        if(!rst_n) begin
            last_revision<=32'hffffffff;counter<=0;message<=0;state<=0;position<=0;terminator<=0;
            catalog_index<=0;bcd<=0;adjust_index<=0;convert_bit<=0;convert_value<=0;name_latch<=0;ready_latch<=0;tx_byte<=0;refresh_cycles<=0;
            status_latch<=0;runtime_latch<=0;feedback_latch<=0;envelope_latch<=0;snapshot<=0;
        end else case(state)
            0:if(counter<REFRESH_CLOCKS-1) counter<=counter+1'b1;
              else begin
                  counter<=0;
                  if(message==0 && directory_revision==last_revision && refresh_cycles!=15) begin status_latch<=status_data;runtime_latch<=runtime_data;feedback_latch<=command_feedback;envelope_latch<=envelope_data;snapshot<=snapshot+1'b1;end
                  if(directory_revision!=last_revision || (message==0 && refresh_cycles==15)) begin
                      last_revision<=directory_revision;message<=48;catalog_index<=0;refresh_cycles<=0;
                  end
                  state<=1;
              end
            1:begin
                position<=0;terminator<=0;name_latch<=catalog_name;ready_latch<=catalog_ready;
                if(numeric) begin
                    convert_value<=field_value(message,status_latch);
                    bcd<=0;adjust_index<=0;convert_bit<=0;state<=2;
                end else state<=3;
            end
            // Double-dabble分成“逐半字节加3”和“整体移位”两个状态，避免10路比较器并行展开。
            2:begin
                if(bcd[adjust_index*4+:4]>=5) bcd[adjust_index*4+:4]<=bcd[adjust_index*4+:4]+3;
                if(adjust_index==9) begin adjust_index<=0;state<=5;end
                else adjust_index<=adjust_index+1'b1;
            end
            5:begin
                bcd<={bcd[38:0],convert_value[31]};convert_value<=convert_value<<1;
                if(convert_bit==31) state<=3;
                else begin convert_bit<=convert_bit+1'b1;state<=2;end
            end
            3:if(!busy) begin
                if(terminator!=0) tx_byte<=8'hff;
                else if(position<prefix_length) tx_byte<=prefix_byte(position,message,catalog_index);
                else if(numeric) begin
                    tx_byte<=8'h30+{4'd0,bcd[39:36]};bcd<=bcd<<4;
                    if(body_position==9) terminator<=1;
                end else if(message[0]) begin tx_byte<=ready_latch ? "1":"0";terminator<=1;end
                else if(body_position==0) tx_byte<=8'h22;
                else if(name_latch[7:0]==0 || body_position==33) begin tx_byte<=8'h22;terminator<=1;end
                else begin tx_byte<=name_latch[7:0];name_latch<=name_latch>>8;end
                start<=1;state<=4;
            end
            4:if(done) begin
                // terminator=1表示正文已结束，随后发送三个FF。
                if(tx_byte==8'hff && terminator!=0) begin
                    if(terminator==3) begin
                        if(message>=48) begin
                            if(message[0] && catalog_index==11) message<=0;
                            else begin message<=message+1'b1;if(message[0]) catalog_index<=catalog_index+1'b1;end
                        end else if(message==40) begin message<=0;refresh_cycles<=refresh_cycles+1'b1;end
                        else message<=message+1'b1;
                        state<=0;
                    end else begin terminator<=terminator+1'b1;state<=3;end
                end else begin position<=position+1'b1;state<=3;end
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
