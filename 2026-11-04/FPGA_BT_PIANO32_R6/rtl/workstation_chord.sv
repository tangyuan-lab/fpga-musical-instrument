`timescale 1ns/1ps
`default_nettype none
// 在完整音源快照上串行识别；只读取仍按住的现场声部，不参与音频ready链。
// status: 0空/1单音/2双音/3唯一和弦/4歧义/5未知；未知根音使用15。
module workstation_chord(
    input wire clk,rst_n,panic,start,
    input wire [31:0] active,held,
    input wire [223:0] notes,
    input wire [159:0] tracks,
    output reg [63:0] result,
    output wire busy
);
    reg [2:0] state;
    reg [4:0] slot;
    reg [11:0] pcs;
    reg [6:0] lowest;
    reg [5:0] held_count;
    reg [3:0] root,kind,match_root,match_kind;
    reg [7:0] match_count;
    reg [15:0] revision;
    reg [3:0] count_pc;
    integer i;
    assign busy=state!=0;
    function automatic [3:0] pitch_class(input [6:0] note);
        reg [6:0] n;
        begin
            n=note;
            if(n>=96)n=n-96;
            if(n>=48)n=n-48;
            if(n>=24)n=n-24;
            if(n>=12)n=n-12;
            pitch_class=n[3:0];
        end
    endfunction
    function automatic [11:0] pattern(input [3:0] k);
        case(k)
            1:pattern=12'h091;2:pattern=12'h089;3:pattern=12'h049;
            4:pattern=12'h111;5:pattern=12'h085;6:pattern=12'h0a1;
            7:pattern=12'h891;8:pattern=12'h491;9:pattern=12'h489;
            10:pattern=12'h449;11:pattern=12'h249;default:pattern=0;
        endcase
    endfunction
    wire [6:0] note=notes[slot*7+:7];
    wire [4:0] owner=tracks[slot*5+:5];
    wire live_note=active[slot]&&held[slot]&&(owner==16||owner==17);
    reg [6:0] note_q;
    reg live_note_q;
    wire [23:0] rotated={pcs,pcs}>>root;
    always @*begin
        count_pc=0;
        for(i=0;i<12;i=i+1)count_pc=count_pc+{3'd0,pcs[i]};
    end
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            state<=0;slot<=0;pcs<=0;lowest<=127;held_count<=0;note_q<=0;live_note_q<=0;
            root<=0;kind<=1;match_count<=0;match_root<=15;match_kind<=0;
            result<=0;revision<=0;
        end else case(state)
            0:if(start)begin
                state<=1;slot<=0;pcs<=0;lowest<=127;held_count<=0;
                root<=0;kind<=1;match_count<=0;match_root<=15;match_kind<=0;
            end
            1:begin
                // 先选槽，再计算音级/最低音；音频快照在这段扫描期间保持不变。
                note_q<=note;live_note_q<=live_note;state<=4;
            end
            4:begin
                if(live_note_q)begin
                    pcs[pitch_class(note_q)]<=1;
                    if(note_q<lowest)lowest<=note_q;
                    held_count<=held_count+1'b1;
                end
                if(slot==31)state<=2;else begin slot<=slot+1'b1;state<=1;end
            end
            2:begin
                if(rotated[11:0]==pattern(kind))begin
                    match_count<=match_count+1'b1;match_root<=root;match_kind<=kind;
                end
                if(kind==11)begin
                    kind<=1;
                    if(root==11)state<=3;else root<=root+1'b1;
                end else kind<=kind+1'b1;
            end
            3:begin
                // 整个64位结果只在发布沿改变，USB读到的是单域原子快照。
                result<= {7'd0,revision,held_count,lowest,
                    (count_pc==0 ? 4'd0:count_pc==1 ? 4'd1:count_pc==2 ? 4'd2:
                     match_count==1 ? 4'd3:match_count>1 ? 4'd4:4'd5),
                    (match_count==1 ? match_kind:4'd0),
                    (count_pc==0 ? 4'd15:pitch_class(lowest)),
                    (match_count==1 ? match_root:4'd15),pcs};
                revision<=revision+1'b1;state<=0;
            end
            default:state<=0;
        endcase
    end
`ifndef SYNTHESIS
    always @(posedge clk)if(rst_n&&!panic)begin
        if(start&&busy)$fatal(1,"chord snapshot overlapped");
        if(state==1&&(^live_note===1'bx))$fatal(1,"chord effective ownership X");
        if(state==1&&live_note&&(^note===1'bx))$fatal(1,"chord effective note X");
    end
`endif
endmodule
`default_nettype wire
