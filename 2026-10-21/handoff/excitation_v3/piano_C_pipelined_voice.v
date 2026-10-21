// Accepted bank mapping: 0..15 = C4..D#5, 16 = C3. Banks 17..31 are zero.
// Arithmetic is unchanged; three extra clocks per mode pipeline the decay feedback.
// Reference-fitted oscillator bank: 24 partials, 64 independently decaying
// modes. ROM words are frequency/phase/amplitude/decay coefficients only.
// Every PCM frame is calculated live; no recorded waveform is stored.
module piano_C_pipelined_voice #(
    parameter integer ADSR_ENABLE = 0
) (
    output wire pp_request,input wire pp_ready,pp_valid,
    output wire [10:0] pp_address,input wire [127:0] pp_data,
    output wire ps_request,input wire ps_ready,ps_valid,
    output wire [9:0] ps_address,input wire [15:0] ps_data,
    input wire clk, rst_n, sample_tick,
    input wire note_on, note_off, note_active,
    input wire [4:0] note_index,
    input wire [6:0] velocity,
    input wire [15:0] pitch_ratio_q15,
    output wire signed [15:0] sample_out,
    output reg sample_valid
);
    localparam IDLE=0, ROM_WAIT=1, PARAMS=2, PITCH_WAIT=3,
        PITCH_DONE=4, MAIN_WAIT=5, MAIN_DONE=6, ONSET_WAIT=7,
        ONSET_DONE=8, SINE_WAIT=9, SINE_DONE=10, FINISH=11,
        OUTPUT_ENVELOPE=12, OUTPUT_CLIP=13, OUTPUT_BLEND=14,
        MAIN_COMMIT=15, ONSET_COMMIT=16, ENVELOPE_LAUNCH=17;
    localparam integer MODES=64;
    reg [4:0] state /* synthesis syn_encoding="onehot" */;
    reg [5:0] index;
    // Synchronous RAM keeps the oscillator bank compact for four voices.
    // A first trigger initializes all entries; started masks stale RAM after
    // reset so audio is zero without a wide reset fanout across RAM bits.
    reg [95:0] state_ram [0:MODES-1];
    reg [95:0] oscillator_q;
    reg [31:0] main_next, onset_next, phase_next;
    reg signed [55:0] mix;
    reg signed [63:0] velocity_q;
    reg signed [42:0] envelope_q;
    reg signed [15:0] clipped_q;
    reg signed [15:0] sample_pcm;
    assign sample_out = rst_n ? sample_pcm : 16'sd0;

    reg pending_trigger, released, frame_trigger, frame_held, started;
    reg [4:0] pending_note, active_note;
    reg [6:0] pending_velocity, frame_velocity;
    reg [15:0] frame_pitch;
    reg [6:0] transition_age;
    reg signed [15:0] transition_tail;

    reg [10:0] param_address;
    reg [127:0] param_q;

    reg [31:0] initial_phase;
    reg [15:0] peak;
    reg [23:0] decay, onset_decay;

    reg [9:0] sine_address;
    reg signed [15:0] sine_q;
    reg pp_pending,ps_pending,ps_loaded;
    assign pp_request=pp_pending;assign pp_address=param_address;
    assign ps_request=ps_pending;assign ps_address=sine_address;
    wire pp_issue=(state==IDLE&&sample_tick)||(state==SINE_DONE&&index!=MODES-1);
    wire ps_issue=state==PITCH_DONE;
    always @(posedge clk)begin
        if(!rst_n)begin pp_pending<=0;ps_pending<=0;ps_loaded<=0;param_q<=0;sine_q<=0;end
        else begin
            if(pp_ready)pp_pending<=0;
            if(ps_ready)ps_pending<=0;
            if(pp_valid)param_q<=pp_data;
            if(ps_valid)begin sine_q<=ps_data;ps_loaded<=1;end
            if(pp_issue)pp_pending<=1;
            if(ps_issue)begin ps_pending<=1;ps_loaded<=0;end
        end
    end
    wire [15:0] sine_magnitude = sine_q[15] ? -sine_q : sine_q;
    reg sine_negative, mode_muted;
    always @(posedge clk) begin
        if (rst_n && state==SINE_DONE) begin
            state_ram[index] <= {phase_next,main_next,onset_next};
            // GW5A supports write-through RAM; read-before-write is unsupported.
            oscillator_q <= {phase_next,main_next,onset_next};
        end else oscillator_q <= state_ram[index];
    end

    // One pipelined multiplier is time-shared by pitch, both envelopes, and
    // sinusoidal synthesis. 64*13+5 arithmetic cycles fit within the 1041/1042 clock frame.
    reg [31:0] multiply_a;
    reg [23:0] multiply_b;
    reg [55:0] multiply_q;
    always @(posedge clk) multiply_q <= multiply_a * multiply_b;
    wire [32:0] rounded_drop = {1'b0,multiply_q[55:24]} + multiply_q[23];
    wire [32:0] nonzero_drop = rounded_drop == 0 ? 33'd1 : rounded_drop;
    wire [31:0] main_source = frame_trigger ? {peak,16'd0} :
                                             started ? oscillator_q[63:32] : 32'd0;
    wire [31:0] onset_source = frame_trigger ? {peak,16'd0} :
                                              started ? oscillator_q[31:0] : 32'd0;
    reg [32:0] drop_q;
    wire [32:0] main_subtract = {1'b0,main_source} - drop_q;
    wire [32:0] onset_subtract = {1'b0,onset_source} - drop_q;
    wire [31:0] decayed_main = main_source > drop_q ?
                                      main_subtract[31:0] : 32'd0;
    wire [31:0] decayed_onset = onset_source > drop_q ?
                                      onset_subtract[31:0] : 32'd0;
    wire [31:0] next_onset = frame_trigger ? onset_source : decayed_onset;
    wire [31:0] next_envelope = main_next > onset_next ?
                                      main_next - onset_next : 32'd0;
    wire [32:0] bent_increment = multiply_q[47:15];
    wire [31:0] next_phase = frame_trigger ? initial_phase :
                   (started ? oscillator_q[95:64] : 32'd0) + bent_increment[31:0];
    wire signed [55:0] contribution = $signed(multiply_q);
    wire signed [63:0] velocity_mix = mix * $signed({1'b0,frame_velocity});
    wire signed [25:0] pcm_raw = velocity_q >>> 38;
    wire [15:0] adsr_gain;
    generate if (ADSR_ENABLE) begin : g_adsr
        adsr #(.ATTACK_STEP(16'd8192), .DECAY_STEP(16'd64),
               .SUSTAIN_LEVEL(16'd62259), .RELEASE_STEP(16'd32)) envelope (
            .sys_clk(clk), .sys_rst_n(rst_n), .sample_tick(sample_tick),
            .note_on(note_on), .note_off(note_off), .note_active(note_active),
            .gain(adsr_gain), .voice_active()
        );
    end else begin : g_no_adsr
        assign adsr_gain=16'hffff;
    end endgenerate
    wire signed [42:0] pcm_enveloped = ADSR_ENABLE ?
        (pcm_raw * $signed({1'b0,adsr_gain})) >>> 16 : pcm_raw;
    wire signed [15:0] pcm_clipped = envelope_q > 32767 ? 16'sd32767 :
        envelope_q < -32768 ? -16'sd32768 : envelope_q[15:0];
    wire signed [23:0] transition_mix =
        clipped_q * $signed({1'b0,transition_age}) +
        transition_tail * $signed(8'd64-{1'b0,transition_age});

    always @(posedge clk) begin
        if (!rst_n) begin
            state<=IDLE; index<=0; sample_pcm<=0; sample_valid<=0;
            main_next<=0; onset_next<=0; phase_next<=0; mix<=0; drop_q<=0;
            velocity_q<=0; envelope_q<=0; clipped_q<=0;
            pending_trigger<=0; pending_note<=0; pending_velocity<=0;
            active_note<=0; frame_velocity<=0; frame_pitch<=32768;
            released<=1; frame_trigger<=0; frame_held<=0; started<=0;
            transition_age<=64; transition_tail<=0;
            param_address<=0; initial_phase<=0; peak<=0; decay<=0;
            onset_decay<=0; sine_address<=0; sine_negative<=0;
            mode_muted<=0; multiply_a<=0; multiply_b<=0;
        end else begin
            sample_valid<=0;
            if (note_off) released<=1;
            if (note_on) begin
                pending_trigger<=1; pending_note<=note_index;
                pending_velocity<=velocity; released<=0;
            end
            case (state)
                IDLE: if (sample_tick) begin
                    index<=0; mix<=0; frame_pitch<=pitch_ratio_q15;
                    frame_trigger<=pending_trigger || note_on;
                    frame_held<=note_active && (!released || note_on) && !note_off;
                    if (pending_trigger || note_on) begin
                        pending_trigger<=0;
                        active_note<=note_on ? note_index : pending_note;
                        frame_velocity<=note_on ? velocity : pending_velocity;
                        param_address<={note_on ? note_index : pending_note,6'd0};
                        transition_tail<=sample_pcm;
                        transition_age<=started && sample_pcm!=0 ? 0 : 64;
                        started<=1;
                    end else begin
                        param_address<={active_note,6'd0};
                        if (transition_age<64) transition_age<=transition_age+1'b1;
                    end
                    state<=ROM_WAIT;
                end
                ROM_WAIT: if(pp_valid)state<=PARAMS;
                PARAMS: begin
                    initial_phase<=param_q[95:64]; peak<=param_q[63:48];
                    decay<=param_q[47:24]; onset_decay<=param_q[23:0];
                    multiply_a<=param_q[127:96]; multiply_b<={8'd0,frame_pitch};
                    state<=PITCH_WAIT;
                end
                PITCH_WAIT: state<=PITCH_DONE;
                PITCH_DONE: begin
                    phase_next<=next_phase; sine_address<=next_phase[31:22];
                    mode_muted<=bent_increment>=33'h080000000;
                    multiply_a<=main_source;
                    multiply_b<=decay + (frame_held ? 24'd0 : 24'd8192);
                    state<=MAIN_WAIT;
                end
                MAIN_WAIT: state<=MAIN_DONE;
                MAIN_DONE: begin
                    drop_q<=nonzero_drop;
                    multiply_a<=onset_source;
                    multiply_b<=onset_decay + (frame_held ? 24'd0 : 24'd8192);
                    state<=MAIN_COMMIT;
                end
                MAIN_COMMIT: begin
                    main_next<=frame_trigger ? main_source : decayed_main;
                    state<=ONSET_WAIT;
                end
                ONSET_WAIT: if(ps_loaded||ps_valid)state<=ONSET_DONE;
                ONSET_DONE: begin
                    drop_q<=nonzero_drop; state<=ONSET_COMMIT;
                end
                ONSET_COMMIT: begin
                    onset_next<=next_onset; state<=ENVELOPE_LAUNCH;
                end
                ENVELOPE_LAUNCH: begin
                    multiply_a<=mode_muted ? 32'd0 : next_envelope;
                    multiply_b<={8'd0,sine_magnitude}; sine_negative<=sine_q[15];
                    state<=SINE_WAIT;
                end
                SINE_WAIT: state<=SINE_DONE;
                SINE_DONE: begin
                    mix<=sine_negative ? mix-contribution : mix+contribution;
                    if (index==MODES-1) state<=FINISH;
                    else begin
                        index<=index+1'b1;
                        param_address<={active_note,index+6'd1}; state<=ROM_WAIT;
                    end
                end
                FINISH: begin
                    velocity_q<=velocity_mix; state<=OUTPUT_ENVELOPE;
                end
                OUTPUT_ENVELOPE: begin
                    envelope_q<=pcm_enveloped; state<=OUTPUT_CLIP;
                end
                OUTPUT_CLIP: begin
                    clipped_q<=pcm_clipped; state<=OUTPUT_BLEND;
                end
                OUTPUT_BLEND: begin
                    sample_pcm<=transition_mix[21:6];
                    sample_valid<=1; state<=IDLE;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
