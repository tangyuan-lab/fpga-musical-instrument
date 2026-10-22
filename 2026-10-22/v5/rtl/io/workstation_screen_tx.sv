`default_nettype none
// 工作站状态输出：page0 的 rx*.val 是共享数据接口，各逻辑界面只负责展示。
// 优先刷新模式/按键/鼓触发，慢速后台扫描配置和真实压力。数值用双移位 BCD，避免除法。
module workstation_screen_tx #(
    parameter integer CLKS_PER_BIT=434,STARTUP_CYCLES=50_000_000
) (
    input wire clk,rst_n,
    input wire [2:0] mode,edit_bank,
    input wire [15:0] keys,drums,descriptor,track_sounds,
    input wire [3:0] step_index,edit_key,
    input wire [7:0] bpm,flags,
    input wire [63:0] patterns,
    input wire [20:0] volumes,
    input wire [191:0] pressure_values,
    output wire screen_tx_o
);
    reg [31:0] startup;reg [5:0] cursor,field;
    reg [4:0] index;reg [2:0] state;
    reg [23:0] value;reg [15:0] last_keys,last_drums;reg [2:0] last_mode;
    reg [27:0] digits;
    reg start;reg [7:0] data;wire busy,done;
    reg [111:0] name;reg [3:0] name_length;
    reg [23:0] selected;
    reg [51:0] bcd_shift,bcd_next;reg [4:0] bcd_count;integer digit;
    // 24个系统周期转换一个24位数，UART每字节需要4340周期，不降低吞吐。
    always @(*) begin
        bcd_next=bcd_shift;
        for(digit=0;digit<7;digit=digit+1)
            if(bcd_next[24+digit*4+:4]>=5) bcd_next[24+digit*4+:4]=bcd_next[24+digit*4+:4]+4'd3;
        bcd_next=bcd_next<<1;
    end
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx(.clk(clk),.rst_n(rst_n),.start(start),.data(data),
        .tx(screen_tx_o),.busy(busy),.done(done));
    always @(*) begin
        name=0;name_length=6;selected=0;
        case(field)
            0:begin name={"rxMode",64'd0};selected={13'd0,mode};end
            1:begin name={"rxKeys",64'd0};selected=keys;end
            2:begin name={"rxDrums",56'd0};name_length=7;selected=drums;end
            3:begin name={"rxStep",64'd0};selected={12'd0,step_index};end
            4:begin name={"rxBpm",72'd0};name_length=5;selected={8'd0,bpm};end
            5:begin name={"rxFlags",56'd0};name_length=7;selected={8'd0,flags};end
            6:begin name={"rxBank",64'd0};selected={13'd0,edit_bank};end
            7:begin name={"rxKey",72'd0};name_length=5;selected={12'd0,edit_key};end
            8:begin name={"rxConfig",48'd0};name_length=8;selected={1'b0,edit_bank,edit_key,descriptor};end
            9,10,11:begin name={"rxVol",8'(48+field-9),64'd0};selected={9'd0,volumes[(field-9)*7+:7]};end
            12,13,14,15:begin name={"rxPat",8'(48+field-12),64'd0};selected=patterns[(field-12)*16+:16];end
            16,17,18,19:begin name={"rxSnd",8'(48+field-16),64'd0};selected={12'd0,track_sounds[(field-16)*4+:4]};end
            default:begin
                if(field<30) begin name={"rxP",8'(48+field-20),80'd0};name_length=4;end
                else begin name={"rxP1",8'(48+field-30),72'd0};name_length=5;end
                selected={4'd0,pressure_values[(field-20)*12+:12]};
            end
        endcase
    end
    // 每条属性命令使用锁存值；下一条命令可以抢先发送最新按键，不中断 FF 结束符。
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            startup<=0;cursor<=0;field<=0;index<=0;state<=0;value<=0;digits<=0;
            start<=0;data<=0;last_keys<=16'hffff;last_drums<=16'hffff;last_mode<=7;bcd_shift<=0;bcd_count<=0;
        end else begin
            start<=0;
            if(startup<STARTUP_CYCLES) startup<=startup+1'b1;
            else case(state)
                0:begin
                    if(mode!=last_mode) field<=0;
                    else if(keys!=last_keys) field<=1;
                    else if(drums!=last_drums) field<=2;
                    else begin field<=cursor;cursor<=cursor==35 ? 0 : cursor+1'b1;end
                    state<=1;index<=0;
                end
                1:begin value<=selected;bcd_shift<={28'd0,selected};bcd_count<=0;state<=2;end
                2:begin
                    bcd_shift<=bcd_next;
                    if(bcd_count==23) begin digits<=bcd_next[51:24];state<=3;end
                    else bcd_count<=bcd_count+1'b1;
                end
                3:if(!busy && !start) begin
                    start<=1;
                    if(index<name_length) data<=name[111-index*8-:8];
                    else case(index-name_length)
                        0:data<=".";1:data<="v";2:data<="a";3:data<="l";4:data<="=";
                        5,6,7,8,9,10,11:data<=8'h30+{4'd0,digits[27-(index-name_length-5)*4-:4]};
                        default:data<=8'hff;
                    endcase
                    if(index==name_length+14) state<=4;else index<=index+1'b1;
                end
                4:if(!busy && !start) begin
                    if(field==0) last_mode<=value[2:0];
                    if(field==1) last_keys<=value[15:0];
                    if(field==2) last_drums<=value[15:0];
                    state<=0;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
