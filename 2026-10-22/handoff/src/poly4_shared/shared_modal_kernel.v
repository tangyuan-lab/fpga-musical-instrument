// Two independent modal contexts overlap ROM, state RAM and tagged arithmetic.
// KIND 0=piano, 1=legacy tom, 2=C body. All narrowing points match the
// accepted integer implementations; only the execution schedule changes.
module shared_modal_kernel #(parameter integer KIND=0)(
 input wire clk,rst_n,start,first,started,held,drum_C,
 input wire [4:0] note,input wire [16:0] age,input wire [15:0] pitch,
 output reg done,output reg active,output reg signed [63:0] sum,
 output reg param_request,input wire param_ready,param_valid,
 output reg [10:0] param_address,input wire [287:0] param_data,
 output reg sine_request,input wire sine_ready,sine_valid,
 output reg [11:0] sine_address,input wire signed [15:0] sine_data,
 output reg ram_request,output reg ram_write,input wire ram_ready,ram_valid,
 output reg [8:0] ram_address,output reg [159:0] ram_data,input wire [159:0] ram_q,
 output reg mul_request,mul_pair,input wire mul_ready,mul_valid,
 output reg signed [35:0] mul_a0,mul_a1,output reg signed [26:0] mul_b0,mul_b1,
 output reg [5:0] mul_tag,input wire [5:0] result_tag,
 input wire signed [62:0] product0,product1
);
 reg f_drum_C;
 wire is_tom=KIND==1||(KIND==3&&!f_drum_C);
 wire is_C=KIND==2||(KIND==3&&f_drum_C);
 wire [6:0] MODES=is_C?7'd49:7'd64;
 reg running,f_first,f_started,f_held;
 reg [4:0] f_note;reg [16:0] f_age;reg [15:0] f_pitch;
 reg [6:0] allocate_index,commit_index;
 reg [1:0] live,have_param,have_state,param_sent,read_sent;
 reg [1:0] env_sent,pg_sent,env_ready;
 reg envelope_pending,envelope_context;reg [1:0] state_stored;
 reg [1:0] phase_ready,sine_sent,have_sine,gain_sent,gain_ready,amp_sent,amp_ready;
 reg [5:0] index[0:1];
 reg [287:0] coefficient[0:1];reg [159:0] old_state[0:1];
 reg [31:0] next_main[0:1],next_onset[0:1],envelope[0:1];
 reg [31:0] next_phase[0:1],next_glide[0:1];
 reg [32:0] increment[0:1];reg signed [15:0] sine[0:1];
 reg [23:0] gained[0:1];
 reg param_owner,param_owner_delayed,sine_owner,ram_owner,ram_was_write;
 wire [287:0] normalized_parameter=is_tom?
  {56'd0,8'd0,param_data[191:168],8'd0,param_data[191:168],param_data[167:120],param_data[223:192],param_data[255:224],param_data[119:88],param_data[87:64]}:param_data;
 wire [159:0] normalized_state=is_tom?
  {32'd0,ram_q[111:80],8'd0,ram_q[79:56],8'd0,ram_q[55:32],ram_q[31:0]}:ram_q;
 integer k;reg chosen,found;
 reg [31:0] sm,so,gl,base,initial_phase;
 reg [23:0] dm,dd,gd,alias_factor;
 reg signed [33:0] frequency;
 wire result_context=result_tag[3];
 wire [2:0] result_operation=result_tag[2:0];

 function [31:0] source_main;
  input [287:0] p;input [159:0] s;
  begin
   if(KIND==0)source_main=f_first?{p[63:48],16'd0}:f_started?s[63:32]:0;
   else if(is_tom)source_main=f_first?p[231:200]:f_started?s[95:64]:0;
   else source_main=f_first?p[231:200]:s[95:64];
  end
 endfunction
 function [31:0] source_onset;
  input [287:0] p;input [159:0] s;
  begin
   if(KIND==0)source_onset=f_first?{p[63:48],16'd0}:f_started?s[31:0]:0;
   else if(is_tom)source_onset=f_first?p[199:168]:f_started?s[63:32]:0;
   else source_onset=f_first?p[199:168]:s[63:32];
  end
 endfunction
 function [31:0] source_glide;
  input [287:0] p;input [159:0] s;
  begin
   if(is_tom)source_glide=f_first?p[55:24]:f_started?s[31:0]:0;
   else source_glide=f_first?p[55:24]:s[31:0];
  end
 endfunction
 function [31:0] saturated_decay;
  input [31:0] value;input [32:0] drop;
  reg [33:0] difference;
  begin difference={2'b0,value}-{1'b0,drop};saturated_decay=difference[33]?0:difference[31:0];end
 endfunction
 function [32:0] rounded_drop;
  input [62:0] p;
  reg [32:0] d;
  begin
   if(is_tom)d={9'd0,p[47:24]}+p[23];
   else if(is_C)d={1'b0,(p[55:24]+p[23])};
   else d={1'b0,p[55:24]}+p[23];
   rounded_drop=d==0?33'd1:d;
  end
 endfunction

 reg [1:0] issue_eligible;reg [2:0] issue_operation[0:1];integer ic;
 always @*begin
  issue_eligible=0;issue_operation[0]=0;issue_operation[1]=0;
  for(ic=0;ic<2;ic=ic+1)if(running&&live[ic]&&have_param[ic]&&have_state[ic])begin
   if(!env_sent[ic])begin issue_eligible[ic]=1;issue_operation[ic]=0;end
   else if(!pg_sent[ic])begin issue_eligible[ic]=1;issue_operation[ic]=1;end
   else if(is_tom&&env_ready[ic]&&phase_ready[ic]&&!gain_sent[ic])begin issue_eligible[ic]=1;issue_operation[ic]=2;end
   else if(env_ready[ic]&&have_sine[ic]&&(!is_tom||gain_ready[ic])&&!amp_sent[ic])begin issue_eligible[ic]=1;issue_operation[ic]=3;end
  end
 end
 wire issue_context=!issue_eligible[0];
 wire [2:0] issue_op=issue_context?issue_operation[1]:issue_operation[0];
 wire [287:0] issue_coefficient=issue_context?coefficient[1]:coefficient[0];
 wire [159:0] issue_state=issue_context?old_state[1]:old_state[0];
 wire [31:0] issue_envelope=issue_context?envelope[1]:envelope[0];
 wire [32:0] issue_increment=issue_context?increment[1]:increment[0];
 wire signed [15:0] issue_sine=issue_context?sine[1]:sine[0];
 wire [23:0] issue_gained=issue_context?gained[1]:gained[0];
 always @*begin
  param_request=0;param_address=0;sine_request=0;sine_address=0;
  ram_request=0;ram_write=0;ram_address=0;ram_data=0;
  mul_request=0;mul_pair=0;mul_a0=0;mul_a1=0;mul_b0=0;mul_b1=0;mul_tag=0;
  chosen=0;found=0;sm=0;so=0;gl=0;base=0;initial_phase=0;dm=0;dd=0;gd=0;alias_factor=0;frequency=0;
  for(k=0;k<2;k=k+1)if(running&&live[k]&&!param_sent[k]&&!param_request)begin
   param_request=1;
   if(KIND==0)param_address={f_note,index[k]};
   else if(is_tom)param_address={3'd0,f_note[1:0],index[k]};
   else param_address={5'd0,index[k]};
  end
  for(k=0;k<2;k=k+1)if(running&&live[k]&&phase_ready[k]&&!sine_sent[k]&&!sine_request)begin
   sine_request=1;sine_address=KIND==0?{2'd0,next_phase[k][31:22]}:next_phase[k][31:20];
  end
  // Commit a completed next row, then retire after the tagged amplitude returns.
  for(k=0;k<2;k=k+1)if(running&&live[k]&&env_ready[k]&&phase_ready[k]&&!state_stored[k]&&!ram_request)begin
   ram_request=1;ram_write=1;
   ram_address=KIND==0?9'd256+index[k]:is_tom?9'd320+index[k]:{3'd0,index[k]};
   if(KIND==0)ram_data={64'd0,next_phase[k],next_main[k],next_onset[k]};
   else if(is_tom)ram_data={48'd0,next_phase[k],next_main[k][23:0],next_onset[k][23:0],next_glide[k]};
   else ram_data={32'd0,next_phase[k],next_main[k],next_onset[k],next_glide[k]};
  end
  for(k=0;k<2;k=k+1)if(running&&live[k]&&!read_sent[k]&&!ram_request)begin
   ram_request=1;
   ram_address=KIND==0?9'd256+index[k]:is_tom?9'd320+index[k]:{3'd0,index[k]};
  end
  // Narrow arbitration precedes the wide operand network.
  if(|issue_eligible)begin
   mul_request=1;mul_tag={2'b0,issue_context,issue_op};
   sm=source_main(issue_coefficient,issue_state);so=source_onset(issue_coefficient,issue_state);
   gl=source_glide(issue_coefficient,issue_state);
   if(KIND==0)begin
    dm=issue_coefficient[47:24]+(f_held?24'd0:24'd8192);
    dd=issue_coefficient[23:0]+(f_held?24'd0:24'd8192);
    base=issue_coefficient[127:96];
   end else begin
    dm=issue_coefficient[167:144];dd=issue_coefficient[143:120];
    gd=issue_coefficient[23:0];
    base=issue_coefficient[87:56];
   end
   case(issue_op)
    0:begin
     mul_pair=1;mul_a0={4'd0,sm};mul_a1={4'd0,so};mul_b0={3'd0,dm};mul_b1={3'd0,dd};
     if(is_C)begin mul_a0={{4{sm[31]}},sm};mul_a1={{4{so[31]}},so};end
    end
    1:begin
     mul_pair=KIND!=0;
     if(KIND==0)begin mul_a0={4'd0,base};mul_b0={11'd0,f_pitch};end
     else begin
      mul_a0={{4{gl[31]}},gl};mul_b0={3'd0,gd};mul_b1={11'd0,f_pitch};
      if(is_tom)begin
       frequency=$signed({2'b00,base})+$signed(gl);
       mul_a1=frequency<0?0:frequency>34'sh07fffffff ? 36'h07fffffff : {4'd0,frequency[31:0]};
      end else mul_a1=$signed(base+gl);
     end
    end
    2:begin
     mul_a0={12'd0,issue_envelope[23:0]};
     alias_factor=issue_increment>=33'h080000000 ? 0 : issue_increment<=33'h060000000 ? 24'd32768 : (33'h080000000-issue_increment)>>14;
     mul_b0={3'd0,alias_factor};
    end
    3:begin
     if(KIND==0)begin
      mul_a0=issue_increment>=33'h080000000 ? 0 : {4'd0,issue_envelope};
      mul_b0={11'd0,(issue_sine[15]?-issue_sine:issue_sine)};
     end else if(is_tom)begin mul_a0={{20{issue_sine[15]}},issue_sine};mul_b0={3'd0,issue_gained};end
     else begin mul_a0={{4{issue_envelope[31]}},issue_envelope};mul_b0={{11{issue_sine[15]}},issue_sine};end
    end
   endcase
  end
 end

 reg [31:0] src_m,src_o,src_g,phase_base;
 reg signed [57:0] glide_round;
 reg signed [33:0] glide_drop;
 reg [32:0] phase_increment;
 reg [32:0] env_difference;
 integer c;
 always @(posedge clk)begin
  if(!rst_n)begin
   running<=0;done<=0;active<=0;sum<=0;live<=0;allocate_index<=0;commit_index<=0;
   have_param<=0;have_state<=0;param_sent<=0;read_sent<=0;env_sent<=0;pg_sent<=0;
   envelope_pending<=0;envelope_context<=0;state_stored<=0;env_ready<=0;phase_ready<=0;sine_sent<=0;have_sine<=0;
   gain_sent<=0;gain_ready<=0;amp_sent<=0;amp_ready<=0;
   param_owner<=0;param_owner_delayed<=0;sine_owner<=0;ram_owner<=0;ram_was_write<=0;
  end else begin
   done<=0;envelope_pending<=0;param_owner_delayed<=param_owner;
   if(start)begin
    running<=1;live<=0;sum<=0;active<=0;allocate_index<=0;commit_index<=0;
    f_first<=first;f_started<=started;f_held<=held;f_note<=note;f_age<=age;f_pitch<=pitch;f_drum_C<=drum_C;
   end
   if(running)begin
    // Allocate at most one context per edge, after the previous write retires.
    if(allocate_index<MODES&&live!=2'b11)begin
     c=live[0]?1:0;live[c]<=1;index[c]<=allocate_index[5:0];allocate_index<=allocate_index+1'b1;
     have_param[c]<=0;have_state[c]<=0;param_sent[c]<=0;read_sent[c]<=0;env_sent[c]<=0;pg_sent[c]<=0;
     state_stored[c]<=0;env_ready[c]<=0;phase_ready[c]<=0;sine_sent[c]<=0;have_sine[c]<=0;
     gain_sent[c]<=0;gain_ready[c]<=0;amp_sent[c]<=0;amp_ready[c]<=0;
    end
    if(param_request&&param_ready)begin
     c=(live[0]&&!param_sent[0])?0:1;param_owner<=c[0];param_sent[c]<=1;
    end
    if(param_valid)begin
     coefficient[is_C?param_owner_delayed:param_owner]<=normalized_parameter;
     have_param[is_C?param_owner_delayed:param_owner]<=1;
    end
    if(sine_request&&sine_ready)begin
     c=(live[0]&&phase_ready[0]&&!sine_sent[0])?0:1;sine_owner<=c[0];sine_sent[c]<=1;
    end
    if(sine_valid)begin sine[sine_owner]<=sine_data;have_sine[sine_owner]<=1;end
    if(ram_request&&ram_ready)begin
     ram_was_write<=ram_write;
     if(ram_write)begin
      c=(live[0]&&env_ready[0]&&phase_ready[0]&&!state_stored[0])?0:1;
      state_stored[c]<=1;if(next_main[c]!=0)active<=1;
     end else begin
      c=(live[0]&&!read_sent[0])?0:1;ram_owner<=c[0];read_sent[c]<=1;
     end
    end
    if(ram_valid&&!ram_was_write)begin old_state[ram_owner]<=normalized_state;have_state[ram_owner]<=1;end
    if(mul_request&&mul_ready)begin
     case(mul_tag[2:0])
      0:env_sent[mul_tag[3]]<=1;
      1:pg_sent[mul_tag[3]]<=1;
      2:gain_sent[mul_tag[3]]<=1;
      3:amp_sent[mul_tag[3]]<=1;
     endcase
    end
    if(mul_valid)begin
     c=result_context;
     case(result_operation)
      0:begin
       src_m=source_main(coefficient[c],old_state[c]);src_o=source_onset(coefficient[c],old_state[c]);
       next_main[c]<=((!is_C&&f_first)||(is_C&&f_age<=coefficient[c][247:232]))?src_m:saturated_decay(src_m,rounded_drop(product0));
       next_onset[c]<=((!is_C&&f_first)||(is_C&&f_age<=coefficient[c][247:232]))?src_o:saturated_decay(src_o,rounded_drop(product1));
       envelope_pending<=1;envelope_context<=c[0];
      end
      1:begin
       src_g=source_glide(coefficient[c],old_state[c]);
       phase_increment=KIND==0?product0[47:15]:product1[47:15];increment[c]<=phase_increment;
       if(KIND==0)begin
        next_phase[c]<=f_first?coefficient[c][95:64]:(f_started?old_state[c][95:64]:32'd0)+phase_increment[31:0];
       end else begin
        glide_round=$signed(product0[56:0])+58'sd8388608;glide_drop=glide_round>>>24;
        if((is_tom&&f_first)||(is_C&&f_age<=coefficient[c][247:232]))next_glide[c]<=src_g;
        else if(glide_drop==0)next_glide[c]<=$signed(src_g)>0?src_g-1:$signed(src_g)<0?src_g+1:0;
        else next_glide[c]<=src_g-glide_drop;
        if(is_tom)next_phase[c]<=f_first?coefficient[c][119:88]:f_started?old_state[c][127:96]+phase_increment[31:0]:32'd0;
        else begin
         phase_base=f_first?coefficient[c][119:88]:old_state[c][127:96];
         next_phase[c]<=f_age>coefficient[c][247:232]?phase_base+phase_increment[31:0]:phase_base;
        end
       end
       phase_ready[c]<=1;
      end
      2:begin gained[c]<=product0[38:15];gain_ready[c]<=1;end
      3:begin
       if(KIND==0)sum<=sine[c][15]?sum-$signed(product0[55:0]):sum+$signed(product0[55:0]);
       else sum<=sum+$signed(product0[56:0]);
       amp_ready[c]<=1;
      end
     endcase
    end
    if((live[0]&&amp_ready[0]&&state_stored[0])||(live[1]&&amp_ready[1]&&state_stored[1]))begin
     c=(live[0]&&amp_ready[0]&&state_stored[0])?0:1;live[c]<=0;commit_index<=commit_index+1'b1;
     if(commit_index==MODES-1)begin done<=1;running<=0;end
    end
    if(envelope_pending)begin
     env_difference={1'b0,next_main[envelope_context]}-{1'b0,next_onset[envelope_context]};
     envelope[envelope_context]<=env_difference[32]||(is_C&&f_age<coefficient[envelope_context][247:232])?0:env_difference[31:0];
     env_ready[envelope_context]<=1;
    end
   end
  end
 end
endmodule
