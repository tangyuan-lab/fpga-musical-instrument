`timescale 1ns/1ps
module tb_midi_tracks_parser;
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,start=0,stop=0;reg [16:0] size=0;
    wire [15:0] address;reg [7:0] memory[0:65535],read0,read1;
    wire busy,ready,error;wire [3:0] code;wire [11:0] count;
    reg [10:0] index=0;wire [31:0] first,last;wire [3:0] channel;wire [6:0] note;wire [7:0] velocity;
    wire [6:0] tempos;reg [5:0] tempo_index=0;wire [31:0] tempo_tick;wire [23:0] tempo_us;
    wire [15:0] ppqn;wire [31:0] duration;
    reg [82:0] expected[0:2047];reg [55:0] expected_tempos[0:63];
    integer n,cycles,expected_count,expected_tempo_count,expected_error,expected_duration,expected_ppqn,pass;
    reg [4095:0] hex_path,expected_path,tempo_path;
    always @(posedge clk) begin read0<=memory[address];read1<=read0;end
    midi_tracks_parser dut(.clk(clk),.rst_n(rst_n),.start(start),.stop(stop),.file_size(size),
        .file_read_address(address),.file_read_data(read1),.busy(busy),.ready(ready),.error(error),.error_code(code),
        .event_count(count),.event_read_index(index),.event_start_tick(first),.event_end_tick(last),
        .event_channel(channel),.event_note(note),.event_velocity(velocity),.tempo_count(tempos),
        .tempo_read_index(tempo_index),.tempo_tick(tempo_tick),.tempo_us_per_quarter(tempo_us),.division_ppqn(ppqn),.parsed_duration(duration));
    initial begin
        if(!$value$plusargs("HEX=%s",hex_path) || !$value$plusargs("SIZE=%d",size) ||
           !$value$plusargs("ERROR=%d",expected_error))$fatal(1,"arguments");
        $readmemh(hex_path,memory,0,size-1);
        if(!expected_error) begin
            if(!$value$plusargs("EXPECTED=%s",expected_path) || !$value$plusargs("COUNT=%d",expected_count) ||
               !$value$plusargs("TEMPOS=%s",tempo_path) || !$value$plusargs("TEMPO_COUNT=%d",expected_tempo_count) ||
               !$value$plusargs("DURATION=%d",expected_duration) || !$value$plusargs("PPQN=%d",expected_ppqn))$fatal(1,"expected args");
            $readmemh(expected_path,expected,0,expected_count-1);$readmemh(tempo_path,expected_tempos,0,expected_tempo_count-1);
        end
        repeat(5) @(negedge clk);rst_n=1;
        if(!expected_error) begin
            @(negedge clk);start=1;@(negedge clk);start=0;cycles=0;
            while(count==0 && busy) begin @(negedge clk);cycles=cycles+1;if(cycles>250000)$fatal(1,"abort setup deadline");end
            if(count==0)$fatal(1,"abort setup failed");
            stop=1;@(negedge clk);stop=0;
            if(busy || ready)$fatal(1,"stop did not cancel parser");
        end
        // 同一RAM不复位，连续解析两遍；验证挂起表的串行初始化和旧结果隔离。
        for(pass=0;pass<2;pass=pass+1) begin
            @(negedge clk);start=1;@(negedge clk);start=0;cycles=0;
            while(busy) begin @(negedge clk);cycles=cycles+1;if(cycles>250000)$fatal(1,"parser deadline");end
            if(expected_error) begin
                if(!error || code!=expected_error || ready)$fatal(1,"expected error %0d got error=%0d code=%0d ready=%0d",expected_error,error,code,ready);
            end else begin
                if(!ready || error || count!=expected_count || tempos!=expected_tempo_count || duration!=expected_duration || ppqn!=expected_ppqn)
                    $fatal(1,"parse failed ready=%0d error=%0d code=%0d notes=%0d tempos=%0d duration=%0d ppqn=%0d",ready,error,code,count,tempos,duration,ppqn);
                for(n=0;n<expected_count;n=n+1) begin
                    index=n;repeat(3) @(negedge clk);
                    if({first,last,channel,note,velocity}!==expected[n])$fatal(1,"event %0d mismatch got %h expected %h",n,{first,last,channel,note,velocity},expected[n]);
                end
                for(n=0;n<expected_tempo_count;n=n+1) begin
                    tempo_index=n;repeat(3) @(negedge clk);
                    if({tempo_tick,tempo_us}!==expected_tempos[n])$fatal(1,"tempo %0d mismatch",n);
                end
            end
        end
        $display("PASS midi_tracks_parser bytes=%0d events=%0d error=%0d reparse=2 abort_restart=%0d",size,count,expected_error,!expected_error);$finish;
    end
    initial begin #20000000;$fatal(1,"parser simulation timeout");end
endmodule
