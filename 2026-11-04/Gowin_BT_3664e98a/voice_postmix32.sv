`timescale 1ns/1ps
`default_nettype none
// 原始力度已由音源使用；此处独立应用可选ADSR、持续压力和每轨后级增益。
// 32槽固定扫描，无整曲归一化。输出固定保留32音叠加余量，溢出显式报告。
module voice_postmix32 #(parameter REGISTER_INPUTS=1)(
    input wire clk,rst_n,panic,start,
    input wire [511:0] voice_pcm,
    input wire [479:0] envelopes,
    input wire [223:0] pressures,
    input wire [159:0] tracks,
    output wire [4:0] gain_owner,
    input wire [15:0] track_gain,
    output reg busy,valid,clipped,deadline_error,
    output reg signed [15:0] pcm,
    output reg signed [22:0] raw_mix,
    output reg [543:0] voice_scaled
);
    wire [511:0] frame_pcm;wire [479:0] frame_envelopes;wire [223:0] frame_pressures;wire [159:0] frame_tracks;
    reg issuing;reg [4:0] issue;reg [3:0] pipe_valid;
    reg [4:0] slot0,slot1,slot2,slot3;
    reg signed [15:0] sample0;
    reg [15:0] env0,pressure0,pressure1,gain1,gain2;
    reg signed [32:0] env_product1,pressure_product2;
    reg signed [33:0] gain_product3;
    reg signed [22:0] accumulator;
    wire [14:0] issue_envelope=frame_envelopes[issue*15+:15];
    wire [6:0] issue_pressure=frame_pressures[issue*7+:7];
    wire [15:0] pressure_gain=16'(issue_pressure*16'd258)+(issue_pressure>=64 ? 16'd1:16'd0)+(issue_pressure==127 ? 16'd1:16'd0);
    wire signed [16:0] env_sample=17'(env_product1>>>15);
    wire signed [16:0] pressure_sample=17'(pressure_product2>>>15);
    wire signed [17:0] contribution=18'(gain_product3>>>15);
    wire signed [22:0] mixed=accumulator+23'(contribution);
    wire signed [22:0] attenuated=mixed>>>5;
    assign gain_owner=frame_tracks[issue*5+:5];
    // REGISTER_INPUTS=0时由上层保证输入稳定至本帧结束；独立使用默认仍锁存。
    generate if(REGISTER_INPUTS)begin:private_frame
        reg [511:0] q_frame_pcm;assign frame_pcm=q_frame_pcm;
        reg [479:0] q_frame_envelopes;assign frame_envelopes=q_frame_envelopes;
        reg [223:0] q_frame_pressures;assign frame_pressures=q_frame_pressures;
        reg [159:0] q_frame_tracks;assign frame_tracks=q_frame_tracks;
        always @(posedge clk)begin
            if(!rst_n||panic)begin
                q_frame_pcm<=0;
                q_frame_envelopes<=0;
                q_frame_pressures<=0;
                q_frame_tracks<=0;
            end else if(start&&!busy)begin
                q_frame_pcm<=voice_pcm;
                q_frame_envelopes<=envelopes;
                q_frame_pressures<=pressures;
                q_frame_tracks<=tracks;
            end
        end
    end else begin:shared_frame
        assign frame_pcm=voice_pcm;
        assign frame_envelopes=envelopes;
        assign frame_pressures=pressures;
        assign frame_tracks=tracks;
        // synthesis translate_off
        reg [1375:0] checked_inputs;
        always @(posedge clk)begin
            if(rst_n&&!panic)begin
                if(start&&!busy)checked_inputs<={voice_pcm,envelopes,pressures,tracks};
                else if(busy&&checked_inputs!=={voice_pcm,envelopes,pressures,tracks})$fatal(1,"shared audio frame inputs changed while busy");
            end
        end
        // synthesis translate_on
    end endgenerate
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            busy<=0;valid<=0;clipped<=0;deadline_error<=0;pcm<=0;raw_mix<=0;voice_scaled<=0;
            issuing<=0;issue<=0;pipe_valid<=0;accumulator<=0;
            sample0<=0;env0<=0;pressure0<=0;pressure1<=0;gain1<=0;gain2<=0;env_product1<=0;pressure_product2<=0;gain_product3<=0;
            slot0<=0;slot1<=0;slot2<=0;slot3<=0;
        end else begin
            valid<=0;pipe_valid<={pipe_valid[2:0],issuing};
            if(start)begin
                if(busy)deadline_error<=1;
                else begin
                    busy<=1;issuing<=1;issue<=0;accumulator<=0;
                    
                end
            end
            if(issuing)begin
                sample0<=$signed(frame_pcm[issue*16+:16]);env0<=issue_envelope==32767 ? 16'd32768:{1'b0,issue_envelope};pressure0<=pressure_gain;slot0<=issue;
                if(issue==31)issuing<=0;else issue<=issue+1'b1;
            end
            if(pipe_valid[0])begin env_product1<=sample0*$signed({1'b0,env0});pressure1<=pressure0;gain1<=track_gain;slot1<=slot0;end
            if(pipe_valid[1])begin pressure_product2<=env_sample*$signed({1'b0,pressure1});gain2<=gain1;slot2<=slot1;end
            if(pipe_valid[2])begin gain_product3<=pressure_sample*$signed({1'b0,gain2});slot3<=slot2;end
            if(pipe_valid[3])begin
                accumulator<=mixed;voice_scaled[slot3*17+:17]<=17'(contribution);
                if(slot3==31)begin
                    raw_mix<=mixed;pcm<=attenuated>32767 ? 16'sd32767:attenuated< -32768 ? -16'sd32768:attenuated[15:0];
                    clipped<=attenuated>32767||attenuated< -32768;busy<=0;valid<=1;
                end
            end
        end
    end
endmodule
`default_nettype wire
