`timescale 1ns/1ps
`default_nettype none
// 压力采样仍来自完整ADC帧；复用一套计算单元逐键处理，最后原子发布整帧。
// 中文注释语义：基线是松键平均值；滤波每帧前进1/2^FILTER_SHIFT；ON/OFF保持滞回。
// 输入帧须间隔至少3*KEY_COUNT+2拍。忙时收到新帧会锁存frame_overrun，不能默默丢帧。
module pressure_key_matrix_serial #(
    parameter integer KEY_COUNT=13,ADC_BITS=12,CALIBRATION_SAMPLES=64,FILTER_SHIFT=2,
    parameter [ADC_BITS-1:0] PRESS_ON=12'd16,PRESS_OFF=12'd8,PRESS_FULL=12'd2048,
    parameter [KEY_COUNT-1:0] ACTIVE_LOW_MASK={KEY_COUNT{1'b1}}
)(
    input wire clk,rst_n,adc_ready,sample_frame_valid,
    input wire [KEY_COUNT*ADC_BITS-1:0] adc_samples,
    input wire [KEY_COUNT-1:0] key_enable,
    output reg calibrated,
    output wire [KEY_COUNT*ADC_BITS-1:0] baseline_values,pressure_values,
    output reg [KEY_COUNT*8-1:0] velocity_values,
    output reg [KEY_COUNT-1:0] key_down,key_on_pulse,key_off_pulse,
    output reg [$clog2(KEY_COUNT+1)-1:0] active_key_count,
    output wire frame_busy,output reg frame_overrun
);
    localparam integer INDEX_BITS=KEY_COUNT<=1?1:$clog2(KEY_COUNT);
    localparam integer COUNT_BITS=$clog2(KEY_COUNT+1);
    localparam integer CAL_BITS=CALIBRATION_SAMPLES<=1?1:$clog2(CALIBRATION_SAMPLES);
    localparam integer SUM_BITS=ADC_BITS+CAL_BITS;
    localparam IDLE=0,SCAN=1,COMMIT=2,FETCH=3,FILTER=4;
    reg [2:0] state;
    reg [INDEX_BITS-1:0] slot;
    reg [CAL_BITS-1:0] calibration_count;
    // 校准时存累加和，完成后原地转换为基线；两种用途不同时存在。
    reg [KEY_COUNT*SUM_BITS-1:0] baseline_sum;
    reg [KEY_COUNT*ADC_BITS-1:0] pressure,captured,next_pressure;
    reg [KEY_COUNT*8-1:0] next_velocity;
    reg [KEY_COUNT-1:0] next_down,next_on,next_off;
    reg [COUNT_BITS-1:0] next_count;
    reg frame_calibration;
    reg [KEY_COUNT-1:0] previous_enable;
    wire newly_enabled=|(key_enable & ~previous_enable);
    genvar key;
    generate for(key=0;key<KEY_COUNT;key=key+1)begin:baseline_output
        assign baseline_values[key*ADC_BITS+:ADC_BITS]=calibrated?baseline_sum[key*SUM_BITS+:ADC_BITS]:{ADC_BITS{1'b0}};
    end endgenerate
    // 屏蔽无采集板或未安装压力片的通道；输出立即归零，状态在下一完整帧提交。
    genvar enabled_key;
    generate for(enabled_key=0;enabled_key<KEY_COUNT;enabled_key=enabled_key+1)begin:g_enable
        assign pressure_values[enabled_key*ADC_BITS+:ADC_BITS]=key_enable[enabled_key] ? pressure[enabled_key*ADC_BITS+:ADC_BITS]:{ADC_BITS{1'b0}};
    end endgenerate
    assign frame_busy=state!=IDLE;

    function automatic [ADC_BITS-1:0] filter_step;
        input [ADC_BITS-1:0] old_value,new_value;
        reg [ADC_BITS:0] difference,step;
        begin
            if(FILTER_SHIFT==0)filter_step=new_value;
            else if(new_value>old_value)begin
                difference=new_value-old_value;
                step=(difference+((1<<FILTER_SHIFT)-1))>>FILTER_SHIFT;
                filter_step=old_value+step[ADC_BITS-1:0];
            end else if(old_value>new_value)begin
                difference=old_value-new_value;
                step=(difference+((1<<FILTER_SHIFT)-1))>>FILTER_SHIFT;
                filter_step=old_value-step[ADC_BITS-1:0];
            end else filter_step=old_value;
        end
    endfunction
    // 基线差值映射到0..255。2048旧配置保留原来的取位，兼容旧回归。
    // 其他量程用常量Q16比例：除法只在参数展开时求常量，数据通路没有除法器。
    // 乘积最大约255*65536，32位含舍入位足够；饱和前误差不超过1个8位力度码。
    localparam integer VELOCITY_SPAN=PRESS_FULL>PRESS_ON?PRESS_FULL-PRESS_ON:1;
    localparam [23:0] VELOCITY_SCALE=((32'd255<<16)+(VELOCITY_SPAN>>1))/VELOCITY_SPAN;
    function automatic [7:0] normalize_velocity;
        input [ADC_BITS-1:0] value;
        reg [ADC_BITS-1:0] delta;
        reg [31:0] product,rounded;
        begin
            delta=0;product=0;rounded=0;
            if(value<PRESS_ON)normalize_velocity=0;
            else if(value>=PRESS_FULL)normalize_velocity=255;
            else begin
                delta=value-PRESS_ON;
                if(PRESS_FULL==12'd2048)normalize_velocity=delta[10:3]==0?8'd1:delta[10:3];
                else if(PRESS_FULL==12'd4095 && PRESS_ON==12'd16)begin
                    // Q16比例为4097；0<=delta<=4078时，舍入乘积严格等于(delta+8)>>4。
                    // 13位加法保留进位，逐码与乘法分支一致，移除压力扫描关键路径的DSP乘法。
                    rounded=({1'b0,delta}+13'd8)>>4;
                    normalize_velocity=rounded==0?8'd1:rounded[7:0];
                end else begin
                    product=delta*VELOCITY_SCALE;rounded=(product+32'd32768)>>16;
                    normalize_velocity=rounded==0?8'd1:rounded>255?8'd255:rounded[7:0];
                end
            end
        end
    endfunction
    function automatic [ADC_BITS-1:0] average;
        input [SUM_BITS-1:0] value;
        reg [SUM_BITS:0] remainder;reg [SUM_BITS-1:0] quotient;integer bit_index;
        begin
            if((CALIBRATION_SAMPLES&(CALIBRATION_SAMPLES-1))==0)
                average=value>>$clog2(CALIBRATION_SAMPLES);
            else begin
                // 参数不是2的幂时按常量做精确二进制除法；仅校准路径使用，不近似基线。
                remainder=0;quotient=0;
                for(bit_index=SUM_BITS-1;bit_index>=0;bit_index=bit_index-1)begin
                    remainder={remainder[SUM_BITS-1:0],value[bit_index]};
                    if(remainder>=CALIBRATION_SAMPLES)begin
                        remainder=remainder-CALIBRATION_SAMPLES;quotient[bit_index]=1;
                    end
                end
                average=quotient[ADC_BITS-1:0];
            end
        end
    endfunction
    wire [ADC_BITS-1:0] sample_value=captured[slot*ADC_BITS+:ADC_BITS];
    wire [ADC_BITS-1:0] base_value=baseline_sum[slot*SUM_BITS+:ADC_BITS];
    wire [ADC_BITS:0] raw_difference=ACTIVE_LOW_MASK[slot]?
        ({1'b0,base_value}-{1'b0,sample_value}):({1'b0,sample_value}-{1'b0,base_value});
    reg [ADC_BITS:0] raw_difference_q;
    wire [ADC_BITS-1:0] raw_pressure_q=raw_difference_q[ADC_BITS] ? {ADC_BITS{1'b0}}:raw_difference_q[ADC_BITS-1:0];
    reg [ADC_BITS-1:0] old_pressure_q,filtered;
    // A full ADC frame is far slower than this three-cycle/key pipeline.
    // Separate input selection/subtraction, filtering, and velocity conversion.
    always @(posedge clk)begin
        // 保留一位符号，负差值在滤波级饱和为0；避免槽选择/减法/判负串到寄存器RESET。
        if(state==FETCH)begin raw_difference_q<=raw_difference;old_pressure_q<=pressure[slot*ADC_BITS+:ADC_BITS];end
        if(state==FILTER)filtered<=filter_step(old_pressure_q,raw_pressure_q);
    end
    wire new_down=!key_enable[slot] ? 1'b0:!key_down[slot]&&filtered>=PRESS_ON?1'b1:
                  key_down[slot]&&filtered<=PRESS_OFF?1'b0:key_down[slot];
    wire [SUM_BITS-1:0] sum_value=baseline_sum[slot*SUM_BITS+:SUM_BITS]+sample_value;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;slot<=0;calibration_count<=0;calibrated<=0;
            baseline_sum<=0;pressure<=0;captured<=0;
            next_pressure<=0;next_velocity<=0;next_down<=0;next_on<=0;next_off<=0;next_count<=0;
            velocity_values<=0;key_down<=0;key_on_pulse<=0;key_off_pulse<=0;active_key_count<=0;
            frame_calibration<=0;frame_overrun<=0;previous_enable<=0;
        end else begin
            previous_enable<=key_enable;
            key_on_pulse<=0;key_off_pulse<=0;
            if(sample_frame_valid&&state!=IDLE)frame_overrun<=1;
            if(newly_enabled)begin
                // 重新启用通道必须重新校准；不能沿用屏蔽期间的零基线制造起音。
                state<=IDLE;calibration_count<=0;calibrated<=0;baseline_sum<=0;
                pressure<=0;velocity_values<=0;key_off_pulse<=key_down;key_down<=0;active_key_count<=0;
            end else if(calibrated&&!adc_ready)begin
                // ADC掉线优先于扫描和提交：一个时钟内释音，丢弃尚未发布的中间结果。
                state<=IDLE;key_off_pulse<=key_down;key_down<=0;
                pressure<=0;velocity_values<=0;active_key_count<=0;
            end else case(state)
                IDLE:if(adc_ready&&sample_frame_valid)begin
                    captured<=adc_samples;slot<=0;frame_calibration<=!calibrated;
                    next_down<=key_down;next_on<=0;next_off<=0;next_count<=0;state<=FETCH;
                end
                FETCH:state<=FILTER;
                FILTER:state<=SCAN;
                SCAN:begin
                    if(frame_calibration)begin
                        if(!key_enable[slot])baseline_sum[slot*SUM_BITS+:SUM_BITS]<=0;
                        else if(calibration_count==CALIBRATION_SAMPLES-1)baseline_sum[slot*SUM_BITS+:SUM_BITS]<={{CAL_BITS{1'b0}},average(sum_value)};
                        else baseline_sum[slot*SUM_BITS+:SUM_BITS]<=sum_value;
                    end else begin
                        next_pressure[slot*ADC_BITS+:ADC_BITS]<=key_enable[slot] ? filtered:0;
                        next_velocity[slot*8+:8]<=key_enable[slot] ? normalize_velocity(filtered):0;
                        next_down[slot]<=new_down;next_on[slot]<=!key_down[slot]&&new_down;
                        next_off[slot]<=key_down[slot]&&!new_down;
                        next_count<=next_count+new_down;
                    end
                    if(slot==KEY_COUNT-1)state<=COMMIT;else begin slot<=slot+1'b1;state<=FETCH;end
                end
                COMMIT:begin
                    if(frame_calibration)begin
                        if(calibration_count==CALIBRATION_SAMPLES-1)calibrated<=1;
                        else calibration_count<=calibration_count+1'b1;
                    end else begin
                        pressure<=next_pressure;velocity_values<=next_velocity;key_down<=next_down;
                        key_on_pulse<=next_on;key_off_pulse<=next_off;active_key_count<=next_count;
                    end
                    state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if(KEY_COUNT<1||ADC_BITS<12||CALIBRATION_SAMPLES<1||PRESS_FULL<=PRESS_ON)$fatal(1,"Invalid pressure scanner parameters");
    end
    // synthesis translate_on
endmodule
`default_nettype wire
