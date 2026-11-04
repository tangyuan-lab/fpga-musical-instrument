`timescale 1ns/1ps
`default_nettype none

// 统一32槽的代际/音色交接；只有标签变化触发，不把普通力度或音高变化当成新音。
// 保留原钢琴规则：首次静音起音直接透传；非零旧输出先保留一帧，再经64采样完成过渡。
module voice_transition32_reference # (parameter REGISTER_INPUTS=1)(
    input wire clk,rst_n,panic,start,
    input wire [31:0] active32,
    input wire [511:0] generation512,
    input wire [159:0] timbres160,
    input wire [511:0] voice_pcm512,
    output reg busy,valid,deadline_error,
    output reg [511:0] pcm_out512
);
    wire [31:0] frame_active;
    wire [511:0] frame_generation,frame_pcm;
    wire [159:0] frame_timbres;
    generate if(REGISTER_INPUTS)begin:private_frame
        reg [31:0] q_active;
        reg [511:0] q_generation,q_pcm;
        reg [159:0] q_timbres;
        assign frame_active=q_active;
        assign frame_generation=q_generation;
        assign frame_timbres=q_timbres;
        assign frame_pcm=q_pcm;
        // 数据快照不复位；busy只在接受start后置位，首个扫描拍读取的必为已锁存帧。
        always @(posedge clk)begin
            if(rst_n&&!panic&&start&&!busy)begin
                q_active<=active32;
                q_generation<=generation512;
                q_timbres<=timbres160;
                q_pcm<=voice_pcm512;
            end
        end
    end else begin:shared_frame
        assign frame_active=active32;
        assign frame_generation=generation512;
        assign frame_timbres=timbres160;
        assign frame_pcm=voice_pcm512;
        // synthesis translate_off
        reg [1215:0] checked_inputs;
        always @(posedge clk)begin
            if(rst_n&&!panic)begin
                if(start&&!busy)checked_inputs<={active32,generation512,timbres160,voice_pcm512};
                else if(busy&&checked_inputs!=={active32,generation512,timbres160,voice_pcm512})
                    $fatal(1,"voice_transition32 shared frame inputs changed while busy");
            end
        end
        // synthesis translate_on
    end endgenerate

    reg [31:0] tag_valid;
    // 小型私有状态不整阵列复位；tag_valid是唯一历史有效性依据，避免失活旧音重新混入。
    reg [15:0] applied_generation[0:31];
    reg [4:0] applied_timbre[0:31];
    reg [6:0] transition_age[0:31];
    reg signed [15:0] transition_tail[0:31];
    reg scanning;
    reg [4:0] scan_slot;
    wire signed [15:0] current_pcm=$signed(frame_pcm[scan_slot*16+:16]);
    // 输出切片自身保存该槽上次已输出PCM；无需再复制一组512位last_pcm寄存器。
    wire signed [15:0] last_pcm=$signed(pcm_out512[scan_slot*16+:16]);
    wire changed=frame_generation[scan_slot*16+:16]!=applied_generation[scan_slot] ||
                 frame_timbres[scan_slot*5+:5]!=applied_timbre[scan_slot];
    reg [6:0] selected_age;
    reg signed [15:0] selected_tail;
    always @* begin
        selected_age=7'd64;
        selected_tail=16'sd0;
        if(frame_active[scan_slot]&&tag_valid[scan_slot])begin
            if(changed)begin
                selected_age=last_pcm==16'sd0 ? 7'd64:7'd0;
                selected_tail=last_pcm;
            end else begin
                selected_age=transition_age[scan_slot]<7'd64 ? transition_age[scan_slot]+7'd1:7'd64;
                selected_tail=transition_tail[scan_slot];
            end
        end
    end

    // 差17位覆盖[-65535,65535]；系数有符号8位覆盖[0,64]；乘积25位、累加26位。
    // tail+((new-tail)*age >>> 6)与原双乘法权重求和逐点一致，负数向负无穷取整。
    wire signed [16:0] difference=$signed({current_pcm[15],current_pcm})-
                                        $signed({selected_tail[15],selected_tail});
    wire signed [7:0] coefficient=$signed({1'b0,selected_age});
    reg pipe_valid,pipe_active;
    reg [4:0] pipe_slot;
    reg signed [24:0] pipe_product;
    reg signed [15:0] pipe_tail;
    wire signed [25:0] product_extended=$signed({pipe_product[24],pipe_product});
    wire signed [25:0] tail_extended=$signed({{10{pipe_tail[15]}},pipe_tail});
    wire signed [25:0] mixed=tail_extended+(product_extended>>>6);
    // 合法凸组合本身不会超16位；保留显式饱和边界，禁止极值处回绕。
    wire signed [15:0] clipped=mixed>26'sd32767 ? 16'sd32767:
                              mixed< -26'sd32768 ? 16'sh8000:mixed[15:0];

    always @(posedge clk)begin
        if(!rst_n||panic)begin
            busy<=1'b0;
            valid<=1'b0;
            deadline_error<=1'b0;
            pcm_out512<=512'd0;
            tag_valid<=32'd0;
            scanning<=1'b0;
            scan_slot<=5'd0;
            pipe_valid<=1'b0;
            pipe_active<=1'b0;
            pipe_slot<=5'd0;
        end else begin
            valid<=1'b0;
            pipe_valid<=scanning;
            if(start)begin
                if(busy)deadline_error<=1'b1;
                else begin
                    busy<=1'b1;
                    scanning<=1'b1;
                    scan_slot<=5'd0;
                end
            end
            if(scanning)begin
                pipe_slot<=scan_slot;
                pipe_active<=frame_active[scan_slot];
                pipe_product<=difference*coefficient;
                pipe_tail<=selected_tail;
                tag_valid[scan_slot]<=frame_active[scan_slot];
                transition_age[scan_slot]<=selected_age;
                transition_tail[scan_slot]<=selected_tail;
                applied_generation[scan_slot]<=frame_generation[scan_slot*16+:16];
                applied_timbre[scan_slot]<=frame_timbres[scan_slot*5+:5];
                if(scan_slot==5'd31)scanning<=1'b0;
                else scan_slot<=scan_slot+5'd1;
            end
            if(pipe_valid)begin
                pcm_out512[pipe_slot*16+:16]<=pipe_active ? clipped:16'sd0;
                if(pipe_slot==5'd31)begin
                    busy<=1'b0;
                    valid<=1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
