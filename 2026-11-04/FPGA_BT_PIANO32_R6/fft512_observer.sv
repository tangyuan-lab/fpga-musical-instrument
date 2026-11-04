`default_nettype none
// 512点实输入FFT，逐级/2，完整输出0..255正频率点；频率=bin*48000/512。
// 矩形窗；幅值采用|Re|+|Im|，不是校准功率谱。计算期间丢弃观察样本，不阻塞合成。
// RAM不整片复位；仅在512点全部写入后计算，valid前的数据不能用于显示。
module fft512_observer(
    input wire clk,rst_n,clear,sample_tick,
    input wire signed [15:0] sample_in,
    output reg [7:0] bin_index,
    output reg [15:0] magnitude,
    output reg bin_valid,frame_done,
    output wire busy
);
    reg signed [15:0] real_ram[0:511],imag_ram[0:511];
    reg [31:0] twiddle[0:255];
    initial $readmemh("observer_twiddle.mem",twiddle);
    reg [3:0] state,stage;reg [8:0] capture;reg [7:0] butterfly,bin;
    reg [8:0] addr_a,addr_b;reg [7:0] tw_addr;
    reg [31:0] tw_q;
    reg signed [15:0] ar,ai,br,bi;
    reg signed [31:0] p0,p1,p2,p3;
    reg signed [32:0] tr,ti;
    reg signed [15:0] mr,mi;
    wire [8:0] reverse_capture={capture[0],capture[1],capture[2],capture[3],capture[4],capture[5],capture[6],capture[7],capture[8]};
    wire [8:0] half_width=9'd1<<stage;
    wire [8:0] offset={1'b0,butterfly}&(half_width-1'b1);
    wire [8:0] base=({1'b0,butterfly}>>stage)<<(stage+1'b1);
    wire [16:0] abs_r=mr[15] ? -$signed({mr[15],mr}):{1'b0,mr};
    wire [16:0] abs_i=mi[15] ? -$signed({mi[15],mi}):{1'b0,mi};
    wire [17:0] mag_sum={1'b0,abs_r}+{1'b0,abs_i};
    assign busy=state!=0;
    always @(posedge clk)begin
        bin_valid<=0;frame_done<=0;
        if(!rst_n||clear)begin
            state<=0;stage<=0;capture<=0;butterfly<=0;bin<=0;addr_a<=0;addr_b<=0;tw_addr<=0;
            bin_index<=0;magnitude<=0;bin_valid<=0;frame_done<=0;tw_q<=0;
            ar<=0;ai<=0;br<=0;bi<=0;p0<=0;p1<=0;p2<=0;p3<=0;tr<=0;ti<=0;mr<=0;mi<=0;
        end else case(state)
            0:if(sample_tick)begin
                real_ram[reverse_capture]<=sample_in;imag_ram[reverse_capture]<=0;
                if(capture==511)begin capture<=0;stage<=0;butterfly<=0;state<=1;end
                else capture<=capture+1'b1;
            end
            1:begin addr_a<=base|offset;addr_b<=base|offset|half_width;
                tw_addr<=8'(offset<<(8-stage));state<=2;end
            2:begin ar<=real_ram[addr_a];ai<=imag_ram[addr_a];tw_q<=twiddle[tw_addr];state<=3;end
            3:begin br<=real_ram[addr_b];bi<=imag_ram[addr_b];state<=4;end
            4:begin
                p0<=$signed(tw_q[31:16])*$signed(br);p1<=$signed(tw_q[15:0])*$signed(bi);
                p2<=$signed(tw_q[15:0])*$signed(br);p3<=$signed(tw_q[31:16])*$signed(bi);state<=5;
            end
            5:begin tr<=($signed({p0[31],p0})-$signed({p1[31],p1}))>>>15;
                ti<=($signed({p2[31],p2})+$signed({p3[31],p3}))>>>15;state<=6;end
            6:begin real_ram[addr_a]<=($signed(ar)+tr)>>>1;imag_ram[addr_a]<=($signed(ai)+ti)>>>1;state<=7;end
            7:begin
                real_ram[addr_b]<=($signed(ar)-tr)>>>1;imag_ram[addr_b]<=($signed(ai)-ti)>>>1;
                if(butterfly==255)begin
                    butterfly<=0;
                    if(stage==8)begin bin<=0;state<=8;end else begin stage<=stage+1'b1;state<=1;end
                end else begin butterfly<=butterfly+1'b1;state<=1;end
            end
            8:begin mr<=real_ram[{1'b0,bin}];mi<=imag_ram[{1'b0,bin}];state<=9;end
            9:begin
                bin_index<=bin;magnitude<=mag_sum>65535 ? 16'hffff:mag_sum[15:0];bin_valid<=1;
                if(bin==255)begin frame_done<=1;state<=0;end else begin bin<=bin+1'b1;state<=8;end
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
