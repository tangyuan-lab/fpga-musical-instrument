`timescale 1ns/1ps
`include "sim/parser_timing_reference.sv"
module tb_parser_timing;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,start=0,stop=0;reg [16:0] original_size=0,candidate_size=0;
    reg [7:0] bytes[0:4095];integer base=0;
    reg [7:0] file_data[0:1];wire [15:0] address[0:1];
    reg [10:0] event_index=0;reg [5:0] tempo_index=0;
    integer case_base[0:8],case_size[0:8];reg case_error[0:8];
    wire busy[0:1];
    wire ready[0:1];
    wire error[0:1];
    wire [3:0] error_code[0:1];
    wire [11:0] event_count[0:1];
    wire [31:0] event_start_tick[0:1];
    wire [31:0] event_end_tick[0:1];
    wire [3:0] event_channel[0:1];
    wire [6:0] event_note[0:1];
    wire [7:0] event_velocity[0:1];
    wire [6:0] tempo_count[0:1];
    wire [31:0] tempo_tick[0:1];
    wire [23:0] tempo_us_per_quarter[0:1];
    wire [15:0] division_ppqn[0:1];
    wire [31:0] parsed_duration[0:1];
    midi_tracks_parser_timing_reference original(.clk(clk),.rst_n(rst_n),.start(start),.stop(stop),
        .file_size(original_size),.file_read_address(address[0]),.file_read_data(file_data[0]),
        .event_read_index(event_index),.tempo_read_index(tempo_index),
        .busy(busy[0]),
        .ready(ready[0]),
        .error(error[0]),
        .error_code(error_code[0]),
        .event_count(event_count[0]),
        .event_start_tick(event_start_tick[0]),
        .event_end_tick(event_end_tick[0]),
        .event_channel(event_channel[0]),
        .event_note(event_note[0]),
        .event_velocity(event_velocity[0]),
        .tempo_count(tempo_count[0]),
        .tempo_tick(tempo_tick[0]),
        .tempo_us_per_quarter(tempo_us_per_quarter[0]),
        .division_ppqn(division_ppqn[0]),
        .parsed_duration(parsed_duration[0]));
    midi_tracks_parser candidate(.clk(clk),.rst_n(rst_n),.start(start),.stop(stop),
        .file_size(candidate_size),.file_read_address(address[1]),.file_read_data(file_data[1]),
        .event_read_index(event_index),.tempo_read_index(tempo_index),
        .busy(busy[1]),
        .ready(ready[1]),
        .error(error[1]),
        .error_code(error_code[1]),
        .event_count(event_count[1]),
        .event_start_tick(event_start_tick[1]),
        .event_end_tick(event_end_tick[1]),
        .event_channel(event_channel[1]),
        .event_note(event_note[1]),
        .event_velocity(event_velocity[1]),
        .tempo_count(tempo_count[1]),
        .tempo_tick(tempo_tick[1]),
        .tempo_us_per_quarter(tempo_us_per_quarter[1]),
        .division_ppqn(division_ppqn[1]),
        .parsed_duration(parsed_duration[1]));
    always @(posedge clk)begin file_data[0]<=bytes[base+address[0]];file_data[1]<=bytes[base+address[1]];end
    integer cycles=0,completed=0,checked_events=0;
    always @(negedge clk)if(rst_n)begin
        cycles=cycles+1;
        if(address[0]!==address[1])$fatal(1,"parser read address mismatch");
        if(busy[0]!==busy[1])$fatal(1,"parser busy mismatch cycle %0d",cycles);
        if(ready[0]!==ready[1])$fatal(1,"parser ready mismatch cycle %0d",cycles);
        if(error[0]!==error[1])$fatal(1,"parser error mismatch cycle %0d",cycles);
        if(error_code[0]!==error_code[1])$fatal(1,"parser error_code mismatch cycle %0d",cycles);
        if(event_count[0]!==event_count[1])$fatal(1,"parser event_count mismatch cycle %0d",cycles);
        if(tempo_count[0]!==tempo_count[1])$fatal(1,"parser tempo_count mismatch cycle %0d",cycles);
        if(division_ppqn[0]!==division_ppqn[1])$fatal(1,"parser division_ppqn mismatch cycle %0d",cycles);
        if(parsed_duration[0]!==parsed_duration[1])$fatal(1,"parser parsed_duration mismatch cycle %0d",cycles);
        if(ready[0]&&{event_start_tick[0],event_end_tick[0],event_channel[0],event_note[0],event_velocity[0],tempo_tick[0],tempo_us_per_quarter[0]}!==
            {event_start_tick[1],event_end_tick[1],event_channel[1],event_note[1],event_velocity[1],tempo_tick[1],tempo_us_per_quarter[1]})$fatal(1,"parser published event/tempo mismatch");
    end
    task automatic parse(input integer c,input integer change_size);
        integer n;
        begin
            @(negedge clk);base=case_base[c];original_size=case_size[c];candidate_size=case_size[c];start=1;
            @(negedge clk);start=0;n=0;
            while(busy[0]&&n<6000)begin
                @(negedge clk);n=n+1;
                if(change_size!=0&&n==100)begin candidate_size=0;start=1;end
                if(change_size!=0&&n==101)start=0;
            end
            if(busy[0]||error[0]!==case_error[c]||ready[0]===case_error[c])$fatal(1,"parser case %0d result err=%b ready=%b",c,error[0],ready[0]);
            completed=completed+1;
            if(ready[0])begin
                for(integer j=0;j<event_count[0];j=j+1)begin event_index=j;repeat(4)@(negedge clk);checked_events=checked_events+1;end
                for(integer j=0;j<tempo_count[0];j=j+1)begin tempo_index=j;repeat(4)@(negedge clk);end
            end
        end
    endtask
    initial begin
        for(integer j=0;j<4096;j=j+1)bytes[j]=0;
        $readmemh("sim/parser_timing_bytes.mem",bytes);
        case_base[0]=0;case_size[0]=35;case_error[0]=1'b0;
        case_base[1]=35;case_size[1]=49;case_error[1]=1'b0;
        case_base[2]=84;case_size[2]=38;case_error[2]=1'b1;
        case_base[3]=122;case_size[3]=30;case_error[3]=1'b1;
        case_base[4]=152;case_size[4]=30;case_error[4]=1'b1;
        case_base[5]=182;case_size[5]=34;case_error[5]=1'b1;
        case_base[6]=216;case_size[6]=35;case_error[6]=1'b1;
        case_base[7]=251;case_size[7]=35;case_error[7]=1'b1;
        case_base[8]=286;case_size[8]=0;case_error[8]=1'b1;
        repeat(5)@(negedge clk);rst_n=1;
        for(integer j=0;j<9;j=j+1)parse(j,0);
        parse(0,1);parse(1,1);
        @(negedge clk);base=case_base[0];original_size=case_size[0];candidate_size=case_size[0];start=1;
        @(negedge clk);start=0;repeat(20)@(negedge clk);stop=1;@(negedge clk);stop=0;
        parse(1,0);
        if(completed!=12||checked_events<5)$fatal(1,"parser test vacuous");
        complete_test("tb_parser_timing",cycles);$display("PASS tb_parser_timing cases=%0d cycles=%0d events=%0d",completed,cycles,checked_events);$finish;
    end
    initial begin #3000000;$fatal(1,"parser test timeout");end
endmodule
