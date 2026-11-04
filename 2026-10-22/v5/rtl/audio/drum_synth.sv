`default_nettype none
// 纯 HDL 打击乐：DDS 音调/下滑、LFSR 噪声、滤波与指数衰减，不含录制 PCM。
module drum_voice #(parameter [15:0] SEED=16'hace1) (
    input wire clk,rst_n,sample_tick,clear,trigger,
    input wire [3:0] instrument,
    input wire [7:0] velocity,
    output reg signed [15:0] sample_out,
    output wire idle
);
    reg [31:0] phase,step;reg [15:0] noise,level;reg [3:0] sound;
    reg signed [16:0] low_noise;
    wire signed [15:0] noise_wave=$signed(noise);
    wire signed [15:0] triangle=$signed({1'b0,(phase[31] ? ~phase[30:16] : phase[30:16])})-16'sd16384;
    reg signed [17:0] wave;
    reg signed [33:0] product;
    reg [3:0] decay_shift;
    assign idle=level==0;
    function automatic [31:0] frequency(input [3:0] id);
        case(id)
            0:frequency=32'd13194140;1:frequency=32'd15832967;
            2:frequency=32'd527765581;3:frequency=32'd466192930;
            4:frequency=32'd9675702;5:frequency=32'd14073749;6:frequency=32'd19351405;
            7:frequency=32'd79164837;8:frequency=32'd36943591;
            9:frequency=32'd281474977;10:frequency=32'd237494512;
            11:frequency=32'd48378512;12:frequency=32'd633318698;
            13:frequency=32'd422212465;14:frequency=32'd105553116;15:frequency=32'd158329674;
        endcase
    endfunction
    always @(*) begin
        decay_shift=9;wave=18'(triangle);
        case(sound)
            0:begin decay_shift=10;wave=18'(triangle);end
            1:begin decay_shift=9;wave=(18'(triangle)>>>1)+(18'(noise_wave)>>>2);end
            2:begin decay_shift=6;wave=(18'(noise_wave)-18'(low_noise))>>>1;end
            3:begin decay_shift=10;wave=(18'(noise_wave)-18'(low_noise))>>>1;end
            4,5,6:begin decay_shift=10;wave=18'(triangle)+(18'(noise_wave)>>>4);end
            7:begin decay_shift=8;wave=18'(noise_wave)>>>1;end
            8:begin decay_shift=7;wave=18'(triangle)+(18'(noise_wave)>>>3);end
            9:begin decay_shift=11;wave=(18'(noise_wave)>>>2)+(18'(triangle)>>>1);end
            10:begin decay_shift=12;wave=18'(noise_wave)>>>1;end
            11:begin decay_shift=9;wave=phase[31]^phase[29] ? 18'sd14000 : -18'sd14000;end
            12:begin decay_shift=7;wave=18'(noise_wave)>>>1;end
            13:begin decay_shift=9;wave=(18'(noise_wave)>>>2)+(18'(triangle)>>>1);end
            14:begin decay_shift=7;wave=18'(triangle);end
            15:begin decay_shift=6;wave=(18'(triangle)>>>1)+(18'(noise_wave)>>>3);end
        endcase
        product=wave*$signed({1'b0,level});
    end
    always @(posedge clk) begin
        if(!rst_n || clear) begin
            phase<=0;step<=0;noise<=SEED;level<=0;sound<=0;low_noise<=0;sample_out<=0;
        end else begin
            sample_out<=16'(product>>>15);
            if(trigger) begin
                phase<=32'h40000000;step<=frequency(instrument);sound<=instrument;
                level<={3'd0,velocity,5'd0};noise<=SEED ^ {8'h35,velocity};
            end else if(sample_tick) begin
                phase<=phase+step;
                noise<={noise[14:0],noise[15]^noise[13]^noise[12]^noise[10]};
                low_noise<=low_noise+((17'(noise_wave)-low_noise)>>>3);
                if(level>0) level<=level-((level>>decay_shift)+1'b1);
                if(sound==0 && step>32'd4398047) step<=step-((step-32'd4398047)>>8)-1'b1;
            end
        end
    end
endmodule

module drum_synth #(parameter integer VOICES=8) (
    input wire clk,rst_n,sample_tick,clear,
    input wire [15:0] triggers,
    input wire [127:0] velocities,
    output reg signed [15:0] sample_out
);
    reg [15:0] pending;reg [7:0] pending_velocity[0:15];
    reg [VOICES-1:0] fire;reg [3:0] sound[0:VOICES-1];reg [7:0] velocity[0:VOICES-1];
    wire [VOICES-1:0] idle;wire signed [15:0] pcm[0:VOICES-1];
    reg [$clog2(VOICES)-1:0] next_voice;
    integer id,slot,k;reg found;reg signed [31:0] sum;
    // 先选择请求，再优先重触发同鼓，其次空闲声部，最后循环替换。
    always @(*) begin
        id=0;found=0;
        for(integer p=0;p<16;p=p+1) if(pending[p] && !found) begin id=p;found=1;end
        slot=int'(next_voice);
        // fire 已分配但包络下一拍才起动，也必须视为占用，避免同时触发覆盖前一鼓。
        for(integer v=VOICES-1;v>=0;v=v-1) if(idle[v] && !fire[v]) slot=v;
        for(integer v=VOICES-1;v>=0;v=v-1) if((!idle[v] || fire[v]) && sound[v]==4'(id)) slot=v;
    end
    always @(posedge clk) begin
        if(!rst_n || clear) begin
            pending<=0;fire<=0;next_voice<=0;
            for(k=0;k<VOICES;k=k+1) begin sound[k]<=0;velocity[k]<=0;end
            for(k=0;k<16;k=k+1) pending_velocity[k]<=0;
        end else begin
            fire<=0;pending<=pending|triggers;
            for(k=0;k<16;k=k+1) if(triggers[k]) pending_velocity[k]<=velocities[k*8+:8];
            if(found) begin
                pending[id]<=triggers[id];sound[slot]<=4'(id);velocity[slot]<=pending_velocity[id];
                fire[slot]<=1;next_voice<=slot==VOICES-1 ? 0 : ($clog2(VOICES))'(slot+1);
            end
        end
    end
    genvar g;
    generate for(g=0;g<VOICES;g=g+1) begin:g_voice
        drum_voice #(.SEED(16'hace1^16'(g*371))) voice (
            .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.clear(clear),.trigger(fire[g]),
            .instrument(sound[g]),.velocity(velocity[g]),.sample_out(pcm[g]),.idle(idle[g]));
    end endgenerate
    always @(*) begin
        sum=0;for(integer v=0;v<VOICES;v=v+1) sum=sum+32'(pcm[v]);
    end
    always @(posedge clk) begin
        if(!rst_n || clear) sample_out<=0;
        else if((sum>>>2)>32767) sample_out<=32767;
        else if((sum>>>2)<-32768) sample_out<=-32768;
        else sample_out<=16'(sum>>>2);
    end
endmodule
`default_nettype wire
