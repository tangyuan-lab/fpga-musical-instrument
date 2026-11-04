`timescale 1ns/1ps
module tb_chord;
 `include "sim/result.svh"
 reg clk=0,rst_n=0,panic=0,start=0;always #10 clk=~clk;
 reg [31:0] active=0,held=0;reg [223:0] notes=0;reg [159:0] tracks=0;
 wire [63:0] result;wire busy;
 workstation_chord dut(.*);
 integer root,kind,inv,i,j,n,checks=0,expected,match_count,expected_root,expected_kind;
 reg [11:0] mask,rotated;reg [63:0] saved;
 function automatic [11:0] pattern(input integer k);
  case(k)
   1:pattern='h091;2:pattern='h089;3:pattern='h049;4:pattern='h111;5:pattern='h085;6:pattern='h0a1;
   7:pattern='h891;8:pattern='h491;9:pattern='h489;10:pattern='h449;11:pattern='h249;default:pattern=0;
  endcase
 endfunction
 task automatic run;
  integer w;
  begin
   @(negedge clk);start=1;@(negedge clk);start=0;
   w=0;while(busy&&w<200)begin @(negedge clk);w=w+1;end
   if(w>=200||(^result)===1'bx)$fatal(1,"chord timeout/X");
   checks=checks+1;
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  // 十二根音、十一模板、三个转位，并额外重复八度；参考独立枚举全部匹配。
  for(root=0;root<12;root=root+1)for(kind=1;kind<=11;kind=kind+1)for(inv=0;inv<3;inv=inv+1)begin
   active=0;held=0;notes=0;tracks=0;n=0;mask=0;
   for(i=0;i<12;i=i+1)if(pattern(kind)&(1<<i))begin
    active[n]=1;held[n]=1;notes[n*7+:7]=48+root+i+(n<inv ? 12:0);tracks[n*5+:5]=n[0] ? 17:16;
    mask[(root+i)%12]=1;n=n+1;
   end
   active[n]=1;held[n]=1;notes[n*7+:7]=notes[6:0]+12;tracks[n*5+:5]=16;
   // 伴奏、测试、释放尾音即使有不同音高，也不应进入集合。
   active[29]=1;held[29]=1;notes[29*7+:7]=47;tracks[29*5+:5]=0;
   active[30]=1;held[30]=1;notes[30*7+:7]=46;tracks[30*5+:5]=18;
   active[31]=1;held[31]=0;notes[31*7+:7]=45;tracks[31*5+:5]=16;
   run();match_count=0;
   for(i=0;i<12;i=i+1)begin
    rotated=(mask>>i)|(mask<<(12-i));
    for(j=1;j<=11;j=j+1)if(rotated==pattern(j))begin match_count=match_count+1;expected_root=i;expected_kind=j;end
   end
   if(result[11:0]!==mask)$fatal(1,"chord source mask");
   if(match_count==1)begin
    if(result[27:24]!=3||result[15:12]!=expected_root||result[23:20]!=expected_kind)$fatal(1,"chord classification");
   end else if(result[27:24]!=4||result[15:12]!=15)$fatal(1,"chord ambiguity");
  end
  active=0;held=0;run();if(result[27:24]!=0)$fatal(1,"empty chord");
  active=1;held=1;notes[6:0]=60;tracks[4:0]=16;run();if(result[27:24]!=1)$fatal(1,"single note");
  active=3;held=3;notes[13:7]=62;tracks[9:5]=17;run();if(result[27:24]!=2)$fatal(1,"two notes");
  @(negedge clk);start=1;@(negedge clk);start=0;repeat(10)@(negedge clk);panic=1;
  @(negedge clk);if(result!==0||busy)$fatal(1,"chord panic");panic=0;
  notes[6:0]=61;run();if(!result[1]||result[0])$fatal(1,"chord restart transpose");
  complete_test("tb_chord",checks);$display("PASS tb_chord checks=%0d",checks);$finish;
 end
 initial begin #2000000;$fatal(1,"chord global timeout");end
endmodule
