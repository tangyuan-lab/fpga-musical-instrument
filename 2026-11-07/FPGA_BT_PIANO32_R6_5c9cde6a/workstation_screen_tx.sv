`default_nettype none
// 状态 + 压力 + 频谱32 + 波形64 + 李萨如X/Y各64，统一文本帧发送。
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
    input wire [15:0] spectrum,wave,liss_x,liss_y,
    output wire [4:0] spec_addr,
    output wire [5:0] wave_addr,lx_addr,ly_addr,
    output wire screen_tx_o
);
    localparam integer LAST_FIELD=259;
    reg [31:0] startup;reg [8:0] cursor,field;
    reg [8:0] index;reg [2:0] state;
    reg [23:0] value;reg [15:0] last_keys,last_drums;reg [2:0] last_mode;
    reg [27:0] digits;
    reg start;reg [7:0] data;wire busy,done;
    reg [111:0] name;reg [3:0] name_length;
    reg [23:0] selected;
    reg [51:0] bcd_shift,bcd_next;reg [4:0] bcd_count;integer digit;
    reg [8:0] vn;reg [3:0] v_units,v_tens,v_hund;reg [1:0] vcase;
    always @(*) begin
        bcd_next=bcd_shift;
        for(digit=0;digit<7;digit=digit+1)
            if(bcd_next[24+digit*4+:4]>=5) bcd_next[24+digit*4+:4]=bcd_next[24+digit*4+:4]+4'd3;
        bcd_next=bcd_next<<1;
    end
    // 可视化字段的序号拆分（最多 63，两位十进制）
    always @(*) begin
        if(field<9'd68) begin vn=field-9'd36;vcase=0;end
        else if(field<9'd132) begin vn=field-9'd68;vcase=1;end
        else if(field<9'd196) begin vn=field-9'd132;vcase=2;end
        else begin vn=field-9'd196;vcase=3;end
        v_units=vn%10;v_tens=(vn/10)%10;v_hund=0;
    end
    // 地址组合生成：RAM 输出寄存一拍，正好在状态1取到数据。
    assign spec_addr = field[4:0]-5'd4;
    assign wave_addr = field[5:0]-6'd4;
    assign lx_addr   = field[5:0]-6'd4;
    assign ly_addr   = field[5:0]-6'd4;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx(.clk(clk),.rst_n(rst_n),.start(start),.data(data),
        .tx(screen_tx_o),.busy(busy),.done(done));
    always @(*) begin
        name=0;name_length=6;selected=0;
        if(field<9'd20) case(field)
            0:begin name={"rxMode",64'd0};selected={13'd0,mode};end
            1:begin name={"rxKeys",64'd0};selected=keys;end
            2:begin name={"rxDrums",56'd0};name_length=7;selected=drums;end
            3:begin name={"rxStep",64'd0};selected={12'd0,step_index};end
            4:begin name={"rxBpm",72'd0};name_length=5;selected={8'd0,bpm};end
            5:begin name={"rxFlags",56'd0};name_length=7;selected={8'd0,flags};end
            6:begin name={"rxBank",64'd0};selected={13'd0,edit_bank};end
            7:begin name={"rxKey",72'd0};name_length=5;selected={12'd0,edit_key};end
            8:begin name={"rxConfig",48'd0};name_length=8;selected={1'b0,edit_bank,edit_key,descriptor};end
            9:begin name={"rxVol48",56'd0};name_length=7;selected={9'd0,volumes[6:0]};end
            10:begin name={"rxVol49",56'd0};name_length=7;selected={9'd0,volumes[13:7]};end
            11:begin name={"rxVol50",56'd0};name_length=7;selected={9'd0,volumes[20:14]};end
            12:begin name={"rxPat48",56'd0};name_length=7;selected=patterns[15:0];end
            13:begin name={"rxPat49",56'd0};name_length=7;selected=patterns[31:16];end
            14:begin name={"rxPat50",56'd0};name_length=7;selected=patterns[47:32];end
            15:begin name={"rxPat51",56'd0};name_length=7;selected=patterns[63:48];end
            16:begin name={"rxSnd48",56'd0};name_length=7;selected={12'd0,track_sounds[3:0]};end
            17:begin name={"rxSnd49",56'd0};name_length=7;selected={12'd0,track_sounds[7:4]};end
            18:begin name={"rxSnd50",56'd0};name_length=7;selected={12'd0,track_sounds[11:8]};end
            default:begin name={"rxSnd51",56'd0};name_length=7;selected={12'd0,track_sounds[15:12]};end
        endcase
        else if(field<9'd36) begin
            name={"rxP",8'(48+((field-9'd20)/10)),8'(48+((field-9'd20)%10)),72'd0};name_length=5;
            selected={4'd0,pressure_values[(field-9'd20)*12+:12]};
        end else if(field<9'd68) begin
            name={"rxS",8'(48+v_tens),8'(48+v_units),72'd0};name_length=5;
            selected={8'd0,spectrum};
        end else if(field<9'd132) begin
            name={"rxW",8'(48+v_tens),8'(48+v_units),72'd0};name_length=5;
            selected={8'd0,wave};
        end else if(field<9'd196) begin
            name={"rxX",8'(48+v_tens),8'(48+v_units),72'd0};name_length=5;
            selected={8'd0,liss_x};
        end else begin
            name={"rxY",8'(48+v_tens),8'(48+v_units),72'd0};name_length=5;
            selected={8'd0,liss_y};
        end
    end
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
                    else begin field<=cursor;cursor<=cursor>=LAST_FIELD ? 0 : cursor+1'b1;end
                    state<=5;index<=0;
                end
                5:state<=1; // 等待同步RAM按新地址返回；下一拍才采样。
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
