// 64 independent chirped, exponentially decaying modes and four procedural
// noise bands. ROMs hold scalar generator coefficients only (never audio).
module tom_ram_voice #(
    parameter integer ADSR_ENABLE = 0
) (
    output wire tp_request,input wire tp_ready,tp_valid,
    output wire [7:0] tp_address,input wire [255:0] tp_data,
    output wire ts_request,input wire ts_ready,ts_valid,
    output wire [11:0] ts_address,input wire [15:0] ts_data,
    output wire tn_request,input wire tn_ready,tn_valid,
    output wire [3:0] tn_address,input wire [127:0] tn_data,
    input wire clk, rst_n, sample_tick,
    input wire note_on, note_off, note_active,
    input wire [4:0] note_index,
    input wire [6:0] velocity,
    input wire [15:0] pitch_ratio_q15,
    output reg signed [15:0] sample_out,
    output reg sample_valid,
    output reg active,
    output reg overrun
);
    localparam IDLE=0, WAIT_ROM=1, LOAD=2, ENV_WAIT=3, ENV_DONE=4,
        PITCH_WAIT=5, PITCH_DONE=6, GAIN_WAIT=7, GAIN_DONE=8,
        MAC_WAIT=9, MAC_DONE=10, NWAIT=11, NLOAD=12, NE_WAIT=13,
        NE_DONE=14, NL_WAIT=15, NL_DONE=16, NM_WAIT=17, NM_DONE=18,
        VELOCITY=19, VWAIT=20, VDONE=21, AWAIT=22, FINISH=23, WAIT_FETCH=24;
    reg [4:0] state;
    reg [5:0] index;
    reg [1:0] band, bank, pending_bank;
    reg pending_trigger, frame_trigger, started, frame_active;
    reg [6:0] pending_velocity, frame_velocity;
    reg [15:0] frame_pitch;
    reg [3:0] noise_address;
    reg [255:0] param_q;
    reg [127:0] noise_q;
    reg fetch_active;
    reg tp_pending,ts_pending,tn_pending,ts_loaded;
    reg [11:0] sine_address;
    reg [7:0] shared_param_address;
    assign tp_request=tp_pending;assign tp_address=shared_param_address;
    assign ts_request=ts_pending;assign ts_address=sine_address;
    assign tn_request=tn_pending;assign tn_address=noise_address;
    // Rows 0..63 hold modal state. Rows 64..67 hold all four noise
    // bands, using the otherwise unused depth of the same four RAM blocks.
    // No reset is needed: frame_trigger/started mask unwritten state exactly
    // as for the existing modal bank. Noise parameters have their own ROM.
    reg [111:0] state_ram [0:127] /* synthesis syn_ramstyle="block_ram" */;
    reg [111:0] state_q;
    reg [31:0] phase_next;
    reg [23:0] main_next,onset_next;
    reg signed [31:0] glide_next;
    reg [23:0] noise_main_next,noise_onset_next;
    reg signed [31:0] hi_next,lo_next;
    wire noise_state = state==NWAIT || state==NLOAD || state==NE_WAIT ||
        state==NE_DONE || state==NL_WAIT || state==NL_DONE ||
        state==NM_WAIT || state==NM_DONE;
    wire [6:0] state_address = noise_state ? {1'b1,4'b0000,band} : {1'b0,index};
    wire state_write = rst_n && (state==MAC_DONE || state==NM_DONE);
    wire [111:0] state_input = noise_state ?
        {noise_main_next,noise_onset_next,hi_next,lo_next} :
        {phase_next,main_next,onset_next,glide_next};
    always @(posedge clk) begin
        if (state_write) begin
            state_ram[state_address] <= state_input;
            state_q <= state_input;
        end else state_q <= state_ram[state_address];
    end
    reg signed [15:0] sine_q;


    // Two envelope pipelines and one signed shared arithmetic pipeline.
    reg [23:0] ea,eb,ec,ed;
    reg [47:0] ep,eq;
    reg signed [31:0] sa;
    reg [23:0] sb;
    reg signed [56:0] sp;
    always @(posedge clk) begin
        ep<=ea*eb; eq<=ec*ed;
        sp<=sa*$signed({1'b0,sb});
    end
    function [23:0] decayed;
        input [23:0] value;
        input [47:0] product;
        reg [24:0] drop;
        reg [25:0] difference;
        begin
            drop={1'b0,product[47:24]}+product[23];
            if(drop==0) drop=1;
            difference={2'b00,value}-{1'b0,drop};
            decayed=difference[25] ? 24'd0 : difference[23:0];
        end
    endfunction
    function [31:0] rng_next;
        input [31:0] value;
        reg [31:0] a;
        begin a=value^(value<<13);a=a^(a>>17);rng_next=a^(a<<5);end
    endfunction
    wire [1:0] requested_bank=note_index<3 ? note_index[1:0] : 2'd3;
    wire trigger_now=pending_trigger||note_on;
    wire fetch_request=(state==IDLE&&sample_tick)||(state==LOAD&&index!=63);
    wire [5:0] following_index=index+6'd1;
    wire [1:0] first_bank=trigger_now ? (note_on ? requested_bank : pending_bank) : bank;
    wire [7:0] fetch_mode=state==IDLE ? {first_bank,6'd0} : {bank,following_index};
    wire noise_request=(state==MAC_DONE&&index==63)||(state==NM_DONE&&band!=3);
    always @(posedge clk)begin
        if(!rst_n)begin
            shared_param_address<=0;fetch_active<=0;param_q<=0;noise_q<=0;sine_q<=0;
            tp_pending<=0;ts_pending<=0;tn_pending<=0;ts_loaded<=0;
        end else begin
            if(tp_ready)tp_pending<=0;
            if(ts_ready)ts_pending<=0;
            if(tn_ready)tn_pending<=0;
            if(tp_valid)begin param_q<=tp_data;fetch_active<=0;end
            if(ts_valid)begin sine_q<=ts_data;ts_loaded<=1;end
            if(tn_valid)noise_q<=tn_data;
            if(fetch_request)begin shared_param_address<=fetch_mode;tp_pending<=1;fetch_active<=1;end
            if(state==PITCH_DONE)begin ts_pending<=1;ts_loaded<=0;end
            if(noise_request)tn_pending<=1;
        end
    end
    wire [23:0] msrc=frame_trigger ? param_q[191:168] : started ? state_q[79:56] : 24'd0;
    wire [23:0] osrc=frame_trigger ? param_q[191:168] : started ? state_q[55:32] : 24'd0;
    wire signed [31:0] gsrc=frame_trigger ? $signed(param_q[119:88]) : started ? $signed(state_q[31:0]) : 32'sd0;
    reg [23:0] main_source,onset_source;
    reg signed [31:0] glide_source;
    reg [31:0] initial_phase,base_step;
    reg signed [55:0] mix;
    reg [23:0] env_value;
    reg [15:0] alias_gain;
    wire signed [57:0] glide_round=$signed(sp)+58'sd8388608;
    wire signed [33:0] glide_drop=glide_round>>>24;
    wire signed [33:0] frequency=$signed({2'b00,base_step})+$signed(glide_source);
    wire [32:0] bent_increment=sp[47:15];
    wire [31:0] computed_phase=frame_trigger ? initial_phase : started ? state_q[111:80]+bent_increment[31:0] : 32'd0;
    reg [31:0] rng;
    reg signed [15:0] white;
    wire signed [31:0] old_hi=frame_trigger||!started ? 32'sd0 : $signed(state_q[63:32]);
    wire signed [31:0] old_lo=frame_trigger||!started ? 32'sd0 : $signed(state_q[31:0]);
    wire signed [31:0] computed_hi=old_hi+(sp>>>16);
    wire signed [31:0] computed_lo=old_lo+(sp>>>16);
    wire [23:0] nmain=frame_trigger ? main_source : decayed(main_source,ep);
    wire [23:0] nonset=frame_trigger ? onset_source : decayed(onset_source,eq);
    wire [24:0] envelope_difference={1'b0,nmain}-{1'b0,nonset};
    // Q13.11 envelope times Q1.15 sine, then integer PCM.
    wire signed [31:0] raw_pcm=mix>>>26;
    reg signed [31:0] pcm;
    wire [15:0] adsr_gain;
    generate if(ADSR_ENABLE) begin:g_adsr
        adsr envelope(.sys_clk(clk),.sys_rst_n(rst_n),.sample_tick(sample_tick),
            .note_on(note_on),.note_off(note_off),.note_active(note_active),
            .gain(adsr_gain),.voice_active());
    end else begin:g_no_adsr
        assign adsr_gain=16'hffff;
    end endgenerate
    integer j;
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;index<=0;band<=0;bank<=0;pending_bank<=0;
            pending_trigger<=0;frame_trigger<=0;started<=0;frame_active<=0;
            pending_velocity<=0;frame_velocity<=0;frame_pitch<=32768;
            noise_address<=0;sine_address<=0;
            phase_next<=0;main_next<=0;onset_next<=0;glide_next<=0;
            ea<=0;eb<=0;ec<=0;ed<=0;sa<=0;sb<=0;
            main_source<=0;onset_source<=0;glide_source<=0;
            initial_phase<=0;base_step<=0;mix<=0;env_value<=0;alias_gain<=0;
            rng<=32'h12345678;white<=0;hi_next<=0;lo_next<=0;pcm<=0;
            sample_out<=0;sample_valid<=0;active<=0;overrun<=0;
            noise_main_next<=0;noise_onset_next<=0;
        end else begin
            sample_valid<=0;
            if(sample_tick && state!=IDLE)overrun<=1;
            if(note_on)begin pending_trigger<=1;pending_bank<=requested_bank;pending_velocity<=velocity;end
            case(state)
                IDLE: if(sample_tick) begin
                    index<=0;mix<=0;frame_active<=0;frame_pitch<=pitch_ratio_q15;
                    frame_trigger<=trigger_now;
                    if(trigger_now)begin
                        pending_trigger<=0;bank<=note_on ? requested_bank : pending_bank;
                        frame_velocity<=note_on ? velocity : pending_velocity;
                        rng<=rng_next(32'h12345678);white<=rng_next(32'h12345678)>>16;
                    end else begin
                        rng<=rng_next(rng);white<=rng_next(rng)>>16;
                    end
                    state<=WAIT_FETCH;
                end
                WAIT_FETCH:if(tp_valid)state<=LOAD;
                WAIT_ROM:if(!fetch_active||tp_valid)state<=LOAD;
                LOAD:begin
                    main_source<=msrc;onset_source<=osrc;glide_source<=gsrc;
                    initial_phase<=param_q[223:192];base_step<=param_q[255:224];
                    ea<=msrc;eb<=param_q[167:144];ec<=osrc;ed<=param_q[143:120];
                    sa<=gsrc;sb<=param_q[87:64];state<=ENV_WAIT;
                end
                ENV_WAIT:state<=ENV_DONE;
                ENV_DONE:begin
                    main_next<=nmain;onset_next<=nonset;
                    env_value<=envelope_difference[24] ? 24'd0 : envelope_difference[23:0];
                    if(nmain!=0)frame_active<=1;
                    if(frame_trigger)glide_next<=glide_source;
                    else if(glide_drop==0)glide_next<=glide_source>0 ? glide_source-1 : glide_source<0 ? glide_source+1 : 0;
                    else glide_next<=glide_source-glide_drop;
                    sa<=frequency<0 ? 0 : frequency>34'sh07fffffff ? 32'h7fffffff : frequency[31:0];
                    sb<={8'd0,frame_pitch};state<=PITCH_WAIT;
                end
                PITCH_WAIT:state<=PITCH_DONE;
                PITCH_DONE:begin
                    phase_next<=computed_phase;sine_address<=computed_phase[31:20];
                    ea<=env_value;
                    eb<=bent_increment>=33'h080000000 ? 0 : bent_increment<=33'h060000000 ? 24'd32768 : (33'h080000000-bent_increment)>>14;
                    state<=GAIN_WAIT;
                end
                GAIN_WAIT:if(ts_loaded||ts_valid)state<=GAIN_DONE;
                GAIN_DONE:begin sa<={{16{sine_q[15]}},sine_q};sb<=ep>>15;state<=MAC_WAIT;end
                MAC_WAIT:state<=MAC_DONE;
                MAC_DONE:begin
                    mix<=mix+sp;
                    if(index==63)begin band<=0;noise_address<={bank,2'd0};state<=NWAIT;end
                    else begin index<=index+1'b1;state<=WAIT_ROM;end
                end
                NWAIT:if(tn_valid)state<=NLOAD;
                NLOAD:begin
                    main_source<=frame_trigger ? noise_q[127:104] : started ? state_q[111:88] : 0;
                    onset_source<=frame_trigger ? noise_q[127:104] : started ? state_q[87:64] : 0;
                    ea<=frame_trigger ? noise_q[127:104] : started ? state_q[111:88] : 0;
                    ec<=frame_trigger ? noise_q[127:104] : started ? state_q[87:64] : 0;
                    eb<=noise_q[103:80];ed<=noise_q[79:56];
                    sa<=$signed(white)-old_hi;sb<={8'd0,noise_q[47:32]};state<=NE_WAIT;
                end
                NE_WAIT:state<=NE_DONE;
                NE_DONE:begin
                    noise_main_next<=nmain;noise_onset_next<=nonset;
                    env_value<=envelope_difference[24] ? 24'd0 : envelope_difference[23:0];
                    if(nmain!=0)frame_active<=1;
                    hi_next<=computed_hi;sa<=computed_hi-old_lo;
                    sb<={8'd0,noise_q[23:8]};state<=NL_WAIT;
                end
                NL_WAIT:state<=NL_DONE;
                NL_DONE:begin
                    lo_next<=computed_lo;sa<=hi_next-computed_lo;sb<=env_value;state<=NM_WAIT;
                end
                NM_WAIT:state<=NM_DONE;
                NM_DONE:begin
                    mix<=mix+sp;
                    if(band==3)state<=VELOCITY;
                    else begin band<=band+1'b1;noise_address<={bank,band+2'd1};state<=NWAIT;end
                end
                VELOCITY:begin sa<=raw_pcm;sb<={17'd0,frame_velocity};state<=VWAIT;end
                VWAIT:state<=VDONE;
                VDONE:begin
                    pcm<=sp>>>7;sa<=sp>>>7;sb<={8'd0,adsr_gain};state<=AWAIT;
                end
                AWAIT:state<=FINISH;
                FINISH:begin
                    if(ADSR_ENABLE)begin
                        if((sp>>>16)>32767)sample_out<=32767;
                        else if((sp>>>16)<-32768)sample_out<=-32768;
                        else sample_out<=sp>>>16;
                    end else begin
                        if(pcm>32767)sample_out<=32767;
                        else if(pcm < -32768)sample_out<=-32768;
                        else sample_out<=pcm[15:0];
                    end
                    started<=started||frame_trigger;active<=frame_active;
                    sample_valid<=1;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
