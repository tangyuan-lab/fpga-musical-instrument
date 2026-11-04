`timescale 1ns/1ps
`default_nettype none
// 四类原生模态共享乘法级；kind（模型类型）只选择字段和各自原有的截位/符号规则。
// E0接收至E6输出，共7个寄存级，II=1；外层同步状态/系数读取另占1级。
// 不管理声部所有权、ADSR、力度或自然尾音期限；这些边界由父层统一控制。
module shared_modal_math #(parameter integer TAG_WIDTH=9,parameter integer DAMPING_ENABLE=0,parameter integer VELOCITY_TONE_ENABLE=0)(
    input wire clk,rst_n,in_valid,
    input wire [TAG_WIDTH-1:0] in_tag,
    input wire [1:0] kind,
    input wire first,held,
    input wire damping_active,input wire [23:0] damping_loss,
    input wire [47:0] damping_native,
    input wire excitation_active,input wire [23:0] excitation_gain,
    input wire [16:0] age,
    input wire [31:0] piano_pitch, // 钢琴UQ4.28；鼓比例为独立的UQ1.15接口。
    input wire [15:0] drum_pitch,
    input wire [255:0] coefficient,
    input wire [127:0] state,
    // E5预提交标签与E6数据同一笔，仅供父层把身份校验提前，不增加输出延迟。
    output wire precommit_valid,
    output wire [TAG_WIDTH-1:0] precommit_tag,
    output wire [1:0] precommit_kind,
    output reg out_valid,
    output reg [TAG_WIDTH-1:0] out_tag,
    output reg [1:0] out_kind,
    output reg signed [63:0] contribution,
    output reg [127:0] next_state,
    output reg [15:0] quiet_bound,
    output reg quiet
);
    localparam [1:0] PIANO=0,TOM=1,EXCITATION=2,PLUCKED=3;
    // 各lane有效位必须保留本地副本；只保留控制寄存器，不阻止DSP吸收数据寄存器。
    (* syn_preserve=1 *) reg [5:0] valid;
    reg [TAG_WIDTH-1:0] tags[0:5];
    reg [1:0] kinds[0:5];
    assign precommit_valid=valid[5];
    assign precommit_tag=tags[5];
    assign precommit_kind=kinds[5];

    // E0：保留原生状态布局；宽度适配只在共享乘法的输入端进行。
    reg [31:0] main0,onset0,phase0,ratio0;
    reg signed [31:0] glide0;
    reg signed [32:0] frequency0;
    reg [23:0] main_factor0,onset_factor0,glide_factor0;
    reg first0,advance0,active0;
    reg excite0,excite1;
    wire [31:0] input_tom_glide=first ? coefficient[119:88]:state[31:0];
    wire signed [33:0] tom_frequency=$signed({2'b00,coefficient[255:224]})+
        $signed({{2{input_tom_glide[31]}},input_tom_glide});
    wire [31:0] bounded_tom_frequency=tom_frequency<0 ? 32'd0:
        tom_frequency>34'sh07fffffff ? 32'h7fffffff:tom_frequency[31:0];
    wire [31:0] input_exc_glide=first ? coefficient[55:24]:state[31:0];
    // 激励鼓先在32位相加回绕；不能套用Tom的非负饱和频率规则。
    wire signed [31:0] excitation_step=$signed(coefficient[87:56]+input_exc_glide);
    wire signed [32:0] main_multiplier_input=kinds[0]==EXCITATION ?
        $signed({main0[31],main0}):$signed({1'b0,main0});
    wire signed [32:0] onset_multiplier_input=kinds[0]==EXCITATION ?
        $signed({onset0[31],onset0}):$signed({1'b0,onset0});

    // E1：只有这组包络/相位/滑音乘法器，三模型不各自实例化旧流水线。
    // 正数钢琴/Tom补0，激励鼓符号扩展；以下各级显式恢复原native结果宽度。
    reg signed [57:0] main_product1,onset_product1;
    reg signed [65:0] pitch_product1;
    reg signed [56:0] glide_product1;
    reg [31:0] main1,onset1,phase1;
    reg signed [31:0] glide1;
    reg first1,advance1,active1;
    wire [32:0] piano_round_main={1'b0,main_product1[55:24]}+{32'd0,main_product1[23]};
    wire [32:0] piano_round_onset={1'b0,onset_product1[55:24]}+{32'd0,onset_product1[23]};
    wire [32:0] piano_gain_main={1'b0,main_product1[54:23]}+{32'd0,main_product1[22]};
    wire [32:0] piano_gain_onset={1'b0,onset_product1[54:23]}+{32'd0,onset_product1[22]};
    wire [24:0] tom_round_main={1'b0,main_product1[47:24]}+{24'd0,main_product1[23]};
    wire [24:0] tom_round_onset={1'b0,onset_product1[47:24]}+{24'd0,onset_product1[23]};
    // 激励鼓的舍入加法必须32位回绕，不能用钢琴的33位舍入代替。
    wire [31:0] exc_round_main=main_product1[55:24]+{31'd0,main_product1[23]};
    wire [31:0] exc_round_onset=onset_product1[55:24]+{31'd0,onset_product1[23]};
    wire [32:0] tom_increment=pitch_product1[47:15];
    wire signed [57:0] tom_glide_round=$signed({glide_product1[56],glide_product1})+58'sd8388608;
    wire signed [33:0] tom_glide_drop=34'(tom_glide_round>>>24);
    wire signed [56:0] exc_glide_round=glide_product1+57'sd8388608;
    wire signed [31:0] exc_glide_drop=$signed(exc_glide_round[55:24]);
    wire signed [31:0] glide_unit=glide1>0 ? 32'sd1:glide1<0 ? -32'sd1:32'sd0;

    // E2：舍入与相位/滑音更新；E3再做原生宽度的饱和减法，避免串接长借位链。
    reg [32:0] drop_main2,drop_onset2;
    reg [31:0] main2,onset2,phase2;
    reg signed [31:0] glide2;
    reg advance2,active2,muted2;
    reg [23:0] alias2;
    wire [33:0] piano_main_difference={2'b00,main2}-{1'b0,drop_main2};
    wire [33:0] piano_onset_difference={2'b00,onset2}-{1'b0,drop_onset2};
    wire [32:0] exc_main_difference={1'b0,main2}-{1'b0,drop_main2[31:0]};
    wire [32:0] exc_onset_difference={1'b0,onset2}-{1'b0,drop_onset2[31:0]};
    reg [31:0] main3,onset3,phase3;
    reg signed [31:0] glide3;
    reg active3,muted3;
    reg [23:0] alias3;

    // E4：双包络差分和下一状态打包。钢琴/激励鼓包络虽同为32位，振幅符号不同。
    reg [31:0] envelope4,phase4;
    reg [23:0] alias4;
    reg [127:0] state4;
    reg quiet4;
    // E5：各自原波形同步ROM；只共享后续振幅乘法，禁止把三张表假设为同一张。
    (* syn_romstyle="block_rom" *) reg signed [15:0] piano_sine[0:1023];
    (* syn_romstyle="block_rom" *) reg [14:0] tom_quarter[0:1023];
    (* syn_romstyle="block_rom" *) reg signed [15:0] excitation_quarter[0:1023];
    initial $readmemh("piano_sine.mem",piano_sine);
    initial $readmemh("tom_sine_quarter.mem",tom_quarter);
    initial $readmemh("excitation_cosine_quarter.mem",excitation_quarter);
    wire [11:0] angle=phase4[31:20];
    wire [9:0] quarter_address=angle[10] ? 10'd0-angle[9:0]:angle[9:0];
    reg signed [15:0] piano_wave5,excitation_magnitude5;
    reg [14:0] tom_magnitude5;
    reg negative5,endpoint5;
    reg [31:0] envelope5;
    reg [47:0] alias_product5;
    reg [127:0] state5;
    reg quiet5;
    wire signed [15:0] tom_magnitude=endpoint5 ? 16'sd32767:$signed({1'b0,tom_magnitude5});
    wire signed [15:0] tom_wave=negative5 ? -tom_magnitude:tom_magnitude;
    wire signed [15:0] excitation_wave=endpoint5 ? 16'sd0:
        negative5 ? -excitation_magnitude5:excitation_magnitude5;
    wire signed [15:0] shared_wave=kinds[5]==PIANO ? piano_wave5:(kinds[5]==TOM||kinds[5]==PLUCKED) ? tom_wave:excitation_wave;
    wire signed [32:0] shared_envelope=(kinds[5]==PIANO||kinds[5]==PLUCKED) ? $signed({1'b0,envelope5}):
        kinds[5]==TOM ? $signed({9'd0,alias_product5[38:15]}):$signed({envelope5[31],envelope5});
    wire signed [48:0] shared_amplitude=shared_wave*shared_envelope;
    // G/B 的自然尾音依据原生包络，不因升调的 Nyquist 静音提前回收声部。
    wire [31:0] plucked_bound=state5[63:32]>=state5[31:0] ? state5[63:32]-state5[31:0]:32'd0;
    wire [31:0] retirement_bound=kinds[5]==PLUCKED ? plucked_bound:envelope5;
    // E6：钢琴原49位、Tom原57→56位、激励鼓原48位的符号扩展分别保留。
    wire signed [56:0] tom_native_amplitude={{8{shared_amplitude[48]}},shared_amplitude};
    wire signed [55:0] tom_native_contribution=tom_native_amplitude[55:0];
    function automatic [23:0] add_loss(input [23:0] native_loss,extra_loss);
        reg [24:0] sum;
        begin sum={1'b0,native_loss}+{1'b0,extra_loss};add_loss=sum[24] ? 24'hffffff:sum[23:0];end
    endfunction
    integer i;
    always @(posedge clk)begin
        if(in_valid)begin
            tags[0]<=in_tag;kinds[0]<=kind;first0<=first;
            excite0<=VELOCITY_TONE_ENABLE&&kind==PIANO&&first&&excitation_active;
            main0<=0;onset0<=0;phase0<=0;glide0<=0;frequency0<=0;ratio0<=0;
            main_factor0<=0;onset_factor0<=0;glide_factor0<=0;advance0<=0;active0<=0;
            case(kind)
                PIANO:begin
                    main0<=first ? {coefficient[63:48],16'd0}:state[63:32];
                    onset0<=first ? {coefficient[63:48],16'd0}:state[31:0];
                    phase0<=first ? coefficient[95:64]:state[95:64];
                    frequency0<=$signed({1'b0,coefficient[127:96]});ratio0<=piano_pitch;
                    // native先24位加法，溢出回绕后再乘；松键不是直接改包络幅度。
                    main_factor0<=VELOCITY_TONE_ENABLE&&first&&excitation_active ? excitation_gain:
                        DAMPING_ENABLE&&damping_active ? add_loss(damping_native[47:24],damping_loss):coefficient[47:24]+(held ? 24'd0:24'd8192);
                    onset_factor0<=VELOCITY_TONE_ENABLE&&first&&excitation_active ? excitation_gain:
                        DAMPING_ENABLE&&damping_active ? add_loss(damping_native[23:0],damping_loss):coefficient[23:0]+(held ? 24'd0:24'd8192);
                    advance0<=!first;active0<=1;
                end
                PLUCKED:begin
                    main0<=first ? {coefficient[63:48],16'd0}:state[63:32];
                    onset0<=first ? {coefficient[63:48],16'd0}:state[31:0];
                    phase0<=first ? coefficient[95:64]:state[95:64];
                    frequency0<=$signed({1'b0,coefficient[127:96]});
                    ratio0<=coefficient[128] ? 32'd32768:{13'd0,piano_pitch[31:13]};
                    main_factor0<=DAMPING_ENABLE&&damping_active ? add_loss(damping_native[47:24],damping_loss):coefficient[47:24];
                    onset_factor0<=DAMPING_ENABLE&&damping_active ? add_loss(damping_native[23:0],damping_loss):coefficient[23:0];
                    advance0<=!first;active0<=1;
                end
                TOM:begin
                    main0<=first ? {8'd0,coefficient[191:168]}:{8'd0,state[79:56]};
                    onset0<=first ? {8'd0,coefficient[191:168]}:{8'd0,state[55:32]};
                    phase0<=first ? coefficient[223:192]:state[111:80];glide0<=$signed(input_tom_glide);
                    frequency0<=$signed({1'b0,bounded_tom_frequency});ratio0<={16'd0,drum_pitch};
                    main_factor0<=coefficient[167:144];onset_factor0<=coefficient[143:120];glide_factor0<=coefficient[87:64];
                    advance0<=!first;active0<=1;
                end
                EXCITATION:begin
                    main0<=first ? coefficient[231:200]:state[95:64];
                    onset0<=first ? coefficient[199:168]:state[63:32];
                    phase0<=first ? coefficient[119:88]:state[127:96];glide0<=$signed(input_exc_glide);
                    frequency0<=$signed({excitation_step[31],excitation_step});ratio0<={16'd0,drum_pitch};
                    main_factor0<=coefficient[167:144];onset_factor0<=coefficient[143:120];glide_factor0<=coefficient[23:0];
                    advance0<=age>{1'b0,coefficient[247:232]};active0<=age>={1'b0,coefficient[247:232]};
                end
                default:begin end
            endcase
        end
        if(valid[0])begin
            main_product1<=main_multiplier_input*$signed({1'b0,main_factor0});
            onset_product1<=onset_multiplier_input*$signed({1'b0,onset_factor0});
            pitch_product1<=frequency0*$signed({1'b0,ratio0});
            glide_product1<=glide0*$signed({1'b0,glide_factor0});
            main1<=main0;onset1<=onset0;phase1<=phase0;glide1<=glide0;
            first1<=first0;advance1<=advance0;active1<=active0;
            excite1<=excite0;
        end
        if(valid[1])begin
            main2<=main1;onset2<=onset1;phase2<=phase1;glide2<=glide1;
            advance2<=advance1;active2<=active1;muted2<=0;alias2<=0;drop_main2<=0;drop_onset2<=0;
            case(kinds[1])
                PIANO:begin
                    if(VELOCITY_TONE_ENABLE&&excite1)begin
                        main2<=piano_gain_main[31:0];onset2<=piano_gain_onset[31:0];
                    end
                    drop_main2<=piano_round_main==0 ? 33'd1:piano_round_main;
                    drop_onset2<=piano_round_onset==0 ? 33'd1:piano_round_onset;
                    phase2<=first1 ? phase1:phase1+32'($unsigned(pitch_product1[63:0])>>28);
                    muted2<=($unsigned(pitch_product1[63:0])>>28)>=64'h80000000;
                end
                PLUCKED:begin
                    drop_main2<=exc_round_main==0 ? 33'd1:{1'b0,exc_round_main};
                    drop_onset2<=exc_round_onset==0 ? 33'd1:{1'b0,exc_round_onset};
                    phase2<=first1 ? phase1:phase1+tom_increment[31:0];
                    muted2<=tom_increment>=33'h080000000;
                end
                TOM:begin
                    drop_main2<=tom_round_main==0 ? 33'd1:{8'd0,tom_round_main};
                    drop_onset2<=tom_round_onset==0 ? 33'd1:{8'd0,tom_round_onset};
                    phase2<=phase1+(first1 ? 32'd0:tom_increment[31:0]);
                    glide2<=first1 ? glide1:tom_glide_drop==0 ? glide1-glide_unit:32'($signed(glide1)-tom_glide_drop);
                    alias2<=tom_increment>=33'h080000000 ? 24'd0:tom_increment<=33'h060000000 ? 24'd32768:
                        24'((33'h080000000-tom_increment)>>14);
                end
                EXCITATION:begin
                    drop_main2<=exc_round_main==0 ? 33'd1:{1'b0,exc_round_main};
                    drop_onset2<=exc_round_onset==0 ? 33'd1:{1'b0,exc_round_onset};
                    phase2<=advance1 ? phase1+pitch_product1[46:15]:phase1;
                    glide2<=advance1 ? glide1-(exc_glide_drop!=0 ? exc_glide_drop:glide_unit):glide1;
                end
                default:begin end
            endcase
        end
        if(valid[2])begin
            main3<=main2;onset3<=onset2;phase3<=phase2;glide3<=glide2;
            active3<=active2;muted3<=muted2;alias3<=alias2;
            if(advance2)case(kinds[2])
                PIANO,PLUCKED:begin
                    main3<=piano_main_difference[33] ? 32'd0:piano_main_difference[31:0];
                    onset3<=piano_onset_difference[33] ? 32'd0:piano_onset_difference[31:0];
                end
                TOM:begin
                    main3<={1'b0,main2[23:0]}>drop_main2[24:0] ? {8'd0,24'({1'b0,main2[23:0]}-drop_main2[24:0])}:32'd0;
                    onset3<={1'b0,onset2[23:0]}>drop_onset2[24:0] ? {8'd0,24'({1'b0,onset2[23:0]}-drop_onset2[24:0])}:32'd0;
                end
                EXCITATION:begin
                    main3<=exc_main_difference[32] ? 32'd0:exc_main_difference[31:0];
                    onset3<=exc_onset_difference[32] ? 32'd0:exc_onset_difference[31:0];
                end
                default:begin end
            endcase
        end
        if(valid[3])begin
            phase4<=phase3;alias4<=alias3;quiet4<=main3==0&&onset3==0;
            envelope4<=active3&&!muted3&&main3>=onset3 ? main3-onset3:32'd0;
            case(kinds[3])
                PIANO,PLUCKED:state4<={32'd0,phase3,main3,onset3};
                TOM:state4<={16'd0,phase3,main3[23:0],onset3[23:0],glide3};
                EXCITATION:state4<={phase3,main3,onset3,glide3};
                default:begin state4<=0;envelope4<=0;quiet4<=1;end
            endcase
        end
        if(valid[4])begin
            state5<=state4;quiet5<=quiet4;envelope5<=envelope4;
            // Tom原24×24 alias乘法只作用Tom，钢琴/激励鼓幅度不经该比例截位。
            alias_product5<=envelope4[23:0]*alias4;
            case(kinds[4])
                PIANO:piano_wave5<=piano_sine[phase4[31:22]];
                TOM,PLUCKED:begin
                    tom_magnitude5<=tom_quarter[quarter_address];negative5<=angle[11];endpoint5<=angle[10]&&angle[9:0]==0;
                end
                EXCITATION:begin
                    excitation_magnitude5<=excitation_quarter[quarter_address];negative5<=angle[11]^angle[10];endpoint5<=angle[10]&&angle[9:0]==0;
                end
                default:begin end
            endcase
        end
        for(i=1;i<6;i=i+1)if(valid[i-1])begin tags[i]<=tags[i-1];kinds[i]<=kinds[i-1];end
        if(!rst_n)begin
            valid<=0;out_valid<=0;out_tag<=0;out_kind<=0;contribution<=0;next_state<=0;quiet<=1;quiet_bound<=0;
        end else begin
            valid<={valid[4:0],in_valid};out_valid<=valid[5];
            if(valid[5])begin
                out_tag<=tags[5];out_kind<=kinds[5];next_state<=state5;quiet<=quiet5;quiet_bound<=|retirement_bound[31:15] ? 16'd32768:retirement_bound[15:0];
                case(kinds[5])
                    PIANO,PLUCKED:contribution<={{15{shared_amplitude[48]}},shared_amplitude};
                    TOM:contribution<={{8{tom_native_contribution[55]}},tom_native_contribution};
                    EXCITATION:contribution<={{16{shared_amplitude[47]}},shared_amplitude[47:0]};
                    default:begin contribution<=0;next_state<=0;quiet<=1;quiet_bound<=0;end
                endcase
            end
        end
    end
endmodule
`default_nettype wire
