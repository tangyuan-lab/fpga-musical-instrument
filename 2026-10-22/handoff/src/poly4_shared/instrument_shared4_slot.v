`include "src/poly4_shared/resource_ports.vh"
module instrument_shared4_slot #(
    parameter integer PIANO_ADSR_ENABLE=0,
    parameter integer TOM_ADSR_ENABLE=0
)(
    output wire pp_request,input wire pp_ready,pp_valid,
    output wire [10:0] pp_address,input wire [127:0] pp_data,
    output wire ps_request,input wire ps_ready,ps_valid,
    output wire [9:0] ps_address,input wire [15:0] ps_data,
    output wire tp_request,input wire tp_ready,tp_valid,
    output wire [7:0] tp_address,input wire [255:0] tp_data,
    output wire ts_request,input wire ts_ready,ts_valid,
    output wire [11:0] ts_address,input wire [15:0] ts_data,
    output wire tn_request,input wire tn_ready,tn_valid,
    output wire [3:0] tn_address,input wire [127:0] tn_data,
    output wire cp_request,input wire cp_ready,cp_valid,
    output wire [7:0] cp_address,input wire [287:0] cp_data,output reg [2:0] cp_bank,
    input wire clk,rst_n,sample_tick,start,release_note,
    input wire piano_metadata_tick,tom_metadata_tick,
    input wire new_timbre,input wire [4:0] new_note,
    input wire [6:0] new_velocity,input wire [15:0] pitch_ratio_q15,
    input wire [6:0] output_gain,
    output reg busy,output reg held,
    output reg [15:0] level,
    output reg signed [15:0] sample_out,output reg sample_valid,
    output wire overrun
);

    `DRUM_JOB_WIRES(c_)
    `DRUM_JOB_WIRES(t_)
    `RESOURCE_WIRES(d_)
    `TOM_POST_WIRES
    `RESOURCE_WIRES(c_)
    `RESOURCE_WIRES(t_)
    `RESOURCE_WIRES(p_)
    wire [479:0] ram_q;
    reg timbre,frame_timbre,frame_busy,uses_C,frame_C;
    wire drum_busy,drum_C_owner,drum_active;wire signed [63:0] drum_sum;
    wire [1:0] drum_ready,drum_done;
    wire drum_param_request,drum_param_ready,drum_param_valid;wire [10:0] drum_param_address;wire [287:0] drum_param_data;
    wire drum_sine_request,drum_sine_ready,drum_sine_valid;wire [11:0] drum_sine_address;wire signed [15:0] drum_sine_data;
    wire C_cp_request;wire [7:0] C_cp_address;wire signed [15:0] C_cosine;reg C_cosine_valid;
    wire cancel_C=start&&new_timbre&&(new_note==1||new_note==2)&&timbre&&uses_C;
    wire frame_starts_tom=start?new_timbre&&(new_note==1||new_note==2):timbre&&!uses_C;
    wire frame_starts_C=start?new_timbre&&(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7):timbre&&uses_C;
    reg [1:0] header_partial;
    always @(posedge clk)begin
     if(!rst_n)header_partial<=0;
     else header_partial<={header_partial[0],cp_request&&cp_ready&&cp_address>=193&&cp_address<=215&&cp_address[0]};
    end
    reg [287:0] retained_parameter;wire [159:0] retained_row=ram_q[159:0];
    wire [287:0] normalized_tom_parameter=
     {56'd0,8'd0,tp_data[191:168],8'd0,tp_data[191:168],tp_data[167:120],tp_data[223:192],tp_data[255:224],tp_data[119:88],tp_data[87:64]};
    // The modal and post controllers own disjoint phases of a drum frame.
    // A single retained bank preserves their original capture edges. Piano
    // responses never update it; historical state remains in the state RAM.
    // drums_parameter_4 returns the registered grant after two edges.
    // Keep that same edge while giving every32bit lane a local enable.
    reg cp_grant_local;
    reg [8:0] cp_valid_lanes /* synthesis syn_dont_touch=1 */;
    always @(posedge clk)begin
     if(!rst_n)begin cp_grant_local<=0;cp_valid_lanes<=0;end
     else begin cp_grant_local<=cp_ready;cp_valid_lanes<={9{cp_grant_local}};end
    end
    wire [287:0] normalized_noise_parameter={160'd0,tn_data};
    genvar parameter_lane;
    generate for(parameter_lane=0;parameter_lane<9;parameter_lane=parameter_lane+1)begin:parameter_lanes
     always @(posedge clk)if(rst_n)begin
      if(cp_valid_lanes[parameter_lane])begin
       if(parameter_lane<4||!header_partial[1])
        retained_parameter[parameter_lane*32+:32]<=cp_data[parameter_lane*32+:32];
      end
      else if(tp_valid)retained_parameter[parameter_lane*32+:32]<=normalized_tom_parameter[parameter_lane*32+:32];
      else if(tn_valid)retained_parameter[parameter_lane*32+:32]<=normalized_noise_parameter[parameter_lane*32+:32];
     end
    end endgenerate
    // synthesis translate_off
    always @(negedge clk)if(rst_n&&cp_valid_lanes!=={9{cp_valid}})
     $fatal(1,"Local parameter enables changed the accepted capture edge");
    // synthesis translate_on
    shared_drum_modes #(.EXTERNAL_BANKS(1)) drum_modes(.clk(clk),.rst_n(rst_n),.abort_C(cancel_C),.request({(t_modal_request&&post_ready),c_modal_request}),
     .retained_parameter(retained_parameter),.retained_row(retained_row),
     .first({t_modal_first,c_modal_first}),.started({t_modal_started,c_modal_started}),
     .note({t_modal_note,c_modal_note}),.age({t_modal_age,c_modal_age}),.pitch({t_modal_pitch,c_modal_pitch}),
     .ready(drum_ready),.done(drum_done),.active(drum_active),.sum(drum_sum),.busy(drum_busy),.C_owner(drum_C_owner),
     .param_request(drum_param_request),.param_ready(drum_param_ready),.param_valid(drum_param_valid),.param_address(drum_param_address),.param_data(drum_param_data),
     .sine_request(drum_sine_request),.sine_ready(drum_sine_ready),.sine_valid(drum_sine_valid),.sine_address(drum_sine_address),.sine_data(drum_sine_data),`RESOURCE_LINK(d_));
    assign c_modal_ready=drum_ready[0];assign t_modal_ready=drum_ready[1];assign c_modal_done=drum_done[0];assign t_modal_done=drum_done[1];
    assign c_modal_sum=drum_sum;assign t_modal_sum=drum_sum;assign c_modal_active=drum_active;assign t_modal_active=drum_active;
    assign cp_request=drum_C_owner?drum_param_request:C_cp_request;assign cp_address=drum_C_owner?drum_param_address[7:0]:C_cp_address;
    assign tp_request=!drum_C_owner&&drum_param_request;assign tp_address=drum_param_address[7:0];
    assign drum_param_ready=drum_C_owner?cp_ready:tp_ready;assign drum_param_valid=drum_C_owner?cp_valid:tp_valid;
    assign drum_param_data=drum_C_owner?cp_data:{32'd0,tp_data};
    assign ts_request=!drum_C_owner&&drum_sine_request;assign ts_address=drum_sine_address;
    assign drum_sine_ready=drum_C_owner?drum_sine_request:ts_ready;assign drum_sine_valid=drum_C_owner?C_cosine_valid:ts_valid;
    assign drum_sine_data=drum_C_owner?C_cosine:ts_data;
    always @(posedge clk)begin if(!rst_n)C_cosine_valid<=0;else C_cosine_valid<=drum_C_owner&&drum_sine_request;end
    // Tom post work now uses client 0 through the common C controller.
    assign t_ram_request=0;assign t_ram_write=0;assign t_ram_address=0;assign t_ram_data=0;
    assign t_mul_request=0;assign t_mul_pair=0;assign t_mul_a0=0;assign t_mul_a1=0;
    assign t_mul_b0=0;assign t_mul_b1=0;assign t_mul_tag=0;
    wire [2:0] ram_req={p_ram_request,(t_ram_request|d_ram_request),c_ram_request};
    wire [2:0] ram_we={p_ram_write,(drum_busy?d_ram_write:t_ram_write),c_ram_write};
    wire [2:0] ram_ready,ram_valid,mul_ready,mul_valid;
    wire [188:0] products0,products1;wire [17:0] tags;
    wire [2:0] main_ready,main_valid;wire [479:0] main_q;
    wire piano_ram_ready,piano_ram_valid;wire [159:0] piano_ram_q;
    shared_voice_ram #(.WRITE_HOLD(1)) state_store(.clk(clk),.rst_n(rst_n),.request({1'b0,ram_req[1:0]}),.write_enable({1'b0,ram_we[1:0]}),
     .address({9'd0,(drum_busy?d_ram_address:t_ram_address),c_ram_address}),.write_data({160'd0,(drum_busy?d_ram_data:t_ram_data),c_ram_data}),
     .ready(main_ready),.response_valid(main_valid),.response_data(main_q));
    shared_piano_state_store piano_state(.clk(clk),.rst_n(rst_n),.request(p_ram_request),.write_enable(p_ram_write),
     .address(p_ram_address),.write_data(p_ram_data),.ready(piano_ram_ready),.response_valid(piano_ram_valid),.response_data(piano_ram_q));
    assign ram_ready={piano_ram_ready,main_ready[1:0]};assign ram_valid={piano_ram_valid,main_valid[1:0]};
    assign ram_q={piano_ram_q,main_q[319:0]};
    shared_voice_mul #(.RESPONSE_CYCLES(2),.PIANO_SECOND_LANE(1),.FIXED_DRUM_OWNER(1)) arithmetic(.clk(clk),.rst_n(rst_n),.drum_owner(drum_busy),
     .request({p_mul_request,(t_mul_request|d_mul_request),c_mul_request}),.pair({p_mul_pair,(drum_busy?d_mul_pair:t_mul_pair),c_mul_pair}),
     .a0({p_mul_a0,(drum_busy?d_mul_a0:t_mul_a0),c_mul_a0}),.a1({p_mul_a1,(drum_busy?d_mul_a1:t_mul_a1),c_mul_a1}),
     .b0({p_mul_b0,(drum_busy?d_mul_b0:t_mul_b0),c_mul_b0}),.b1({p_mul_b1,(drum_busy?d_mul_b1:t_mul_b1),c_mul_b1}),.tag({p_mul_tag,(drum_busy?d_mul_tag:t_mul_tag),c_mul_tag}),
     .ready(mul_ready),.response_valid(mul_valid),.product0(products0),.product1(products1),.response_tag(tags));
    assign c_ram_ready=ram_ready[0];assign c_ram_valid=ram_valid[0];assign c_ram_q=ram_q[0+:160];
    assign c_mul_ready=mul_ready[0];assign c_mul_valid=mul_valid[0];
    assign c_product0=products0[0+:63];assign c_product1=products1[0+:63];assign c_result_tag=tags[0+:6];
    assign t_ram_ready=ram_ready[1]&&!drum_busy;assign d_ram_ready=ram_ready[1]&&drum_busy;assign t_ram_valid=ram_valid[1]&&!drum_busy;assign d_ram_valid=ram_valid[1]&&drum_busy;assign t_ram_q=ram_q[160+:160];assign d_ram_q=ram_q[160+:160];
    assign t_mul_ready=mul_ready[1]&&!drum_busy;assign d_mul_ready=mul_ready[1]&&drum_busy;assign t_mul_valid=mul_valid[1]&&!drum_busy;assign d_mul_valid=mul_valid[1]&&drum_busy;
    assign t_product0=products0[63+:63];assign d_product0=products0[63+:63];assign t_product1=products1[63+:63];assign d_product1=products1[63+:63];assign t_result_tag=tags[6+:6];assign d_result_tag=tags[6+:6];
    assign p_ram_ready=ram_ready[2];assign p_ram_valid=ram_valid[2];assign p_ram_q=ram_q[320+:160];
    assign p_mul_ready=mul_ready[2];assign p_mul_valid=mul_valid[2];
    assign p_product0=products0[126+:63];assign p_product1=products1[126+:63];assign p_result_tag=tags[12+:6];
    reg key_gate;
    reg [10:0] quiet_frames;
    wire signed [15:0] piano_sample,tom_sample;
    wire piano_valid,tom_valid,tom_active,piano_overrun;
    wire C_valid,C_overrun,old_overrun;
    wire signed [15:0] C_sample;
    assign overrun=C_overrun|old_overrun|piano_overrun;
    wire chosen_valid=frame_timbre ? (frame_C ? C_valid : tom_valid) : piano_valid;
    wire signed [15:0] chosen_sample=frame_timbre ? (frame_C ? C_sample : tom_sample) : piano_sample;
    wire [15:0] magnitude=chosen_sample[15] ? -chosen_sample : chosen_sample;
    wire metadata_valid=frame_timbre?(frame_C?chosen_valid:tom_metadata_tick):piano_metadata_tick;
    wire [15:0] drop=(level>>8)==0 ? 16'd1 : level>>8;
    wire [15:0] level_decay=level>drop ? level-drop : 0;
    wire signed [23:0] scaled=chosen_sample*$signed({1'b0,output_gain});
    shared_piano_voice #(.ADSR_ENABLE(PIANO_ADSR_ENABLE)) piano(
        .pp_request(pp_request),.pp_ready(pp_ready),.pp_valid(pp_valid),.pp_address(pp_address),.pp_data(pp_data),
        .ps_request(ps_request),.ps_ready(ps_ready),.ps_valid(ps_valid),.ps_address(ps_address),.ps_data(ps_data),
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.note_on(start&&!new_timbre),
        .note_off(release_note&&!timbre),.note_active(held&&!timbre),
        .note_index(new_note),.velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
        .sample_out(piano_sample),.sample_valid(piano_valid),.overrun(piano_overrun),`RESOURCE_LINK(p_));
    shared_tom_adapter #(.ADSR_ENABLE(TOM_ADSR_ENABLE)) tom(
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick&&frame_starts_tom),.adsr_tick(sample_tick),.note_on(start&&new_timbre&&(new_note==1||new_note==2)),
        .note_off(release_note&&timbre),.note_active(key_gate&&timbre),.note_index(new_note),.velocity(new_velocity),
        .pitch_ratio_q15(pitch_ratio_q15),.sample_out(tom_sample),.sample_valid(tom_valid),
        .active(tom_active),.overrun(old_overrun),`TOM_POST_LINK,`DRUM_JOB_LINK(t_));
    shared_C_voice #(.ADSR_ENABLE(TOM_ADSR_ENABLE),.EXTERNAL_BANKS(1)) C_voice(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.enable(frame_starts_C),
        .cancel_C(cancel_C),
        .retained_parameter(retained_parameter),.retained_row(retained_row),
        .note_on(start&&new_timbre&&(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7)),.velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
        .note_off(release_note&&timbre&&uses_C),.note_active(key_gate&&timbre&&uses_C),
        .cp_request(C_cp_request),.cp_ready(cp_ready),.cp_valid(cp_valid),.cp_address(C_cp_address),.cp_data(cp_data),
        .sample_out(C_sample),.sample_valid(C_valid),.overrun(C_overrun),`TOM_POST_LINK,`TOM_NOISE_LINK,`RESOURCE_LINK(c_),`DRUM_JOB_LINK(c_),.modal_phase(drum_sine_address),.modal_cosine(C_cosine));
    always @(posedge clk)begin
        if(!rst_n)begin
            cp_bank<=0;busy<=0;held<=0;level<=0;sample_out<=0;sample_valid<=0;
            timbre<=0;frame_timbre<=0;uses_C<=0;frame_C<=0;frame_busy<=0;quiet_frames<=0;key_gate<=0;
        end else begin
            sample_valid<=0;
            if(sample_tick)begin frame_timbre<=start ? new_timbre : timbre;frame_busy<=busy||start;frame_C<=start ? (new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7) : uses_C;end
            if(chosen_valid)begin
                sample_valid<=1;sample_out<=frame_busy ? scaled>>>6 : 0;
            end
            if(metadata_valid)begin
                // All three sample registers hold their completed frame
                // through the metadata edge; no extra magnitude bank needed.
                level<=magnitude>level_decay ? magnitude : level_decay;
                if(busy&&!held&&magnitude<=1)begin
                    if(quiet_frames==1023)begin busy<=0;quiet_frames<=0;end
                    else quiet_frames<=quiet_frames+1'b1;
                end else quiet_frames<=0;
            end
            if(release_note)begin held<=0;key_gate<=0;end
            if(start&&new_timbre&&(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7))cp_bank<=new_note==7 ? 3'd5 : new_note==6 ? 3'd4 : new_note==5 ? 3'd3 : new_note==4 ? 3'd2 : new_note==3 ? 3'd1 : 3'd0;
            if(start)begin uses_C<=(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7);timbre<=new_timbre;held<=!new_timbre;key_gate<=1;busy<=1;quiet_frames<=0;level<=65535;end
        end
    end
    // synthesis translate_off
    always @(posedge clk)if(rst_n&&!$onehot0({cp_valid,tp_valid,tn_valid}))
     $fatal(1,"Drum parameter owners overlapped a retained-bank capture");
    // synthesis translate_on
endmodule
