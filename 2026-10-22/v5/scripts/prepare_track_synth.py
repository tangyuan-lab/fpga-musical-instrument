"""从保留的32声部核心生成逐轨后级增益候选；不覆盖整机RTL或构建清单。"""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[1]


def main():
    source=(ROOT/'rtl/audio/synth32.sv').read_text(encoding='utf-8')
    original_hash=hashlib.sha256(source.encode()).hexdigest()
    def replace(old,new):
        nonlocal source
        if source.count(old)!=1:raise RuntimeError('核心结构变化，需复核生成器：'+old[:80])
        source=source.replace(old,new,1)
    replace('module synth32 #(','module synth32_tracks #(')
    replace('固定7拍时隙计算；50MHz下224拍完成一帧','固定9拍时隙计算；50MHz下288拍完成一帧')
    source=source.replace('sample_tick','frame_tick').replace('deadline_error','voice_deadline_error')
    replace('input wire clk,rst_n,frame_tick,panic,','input wire clk,rst_n,sample_tick,panic,')
    replace('input wire [3:0] command_timbre,','''input wire [3:0] command_timbre,
    input wire [4:0] command_owner,
    input wire gain_valid,output wire gain_ready,input wire [4:0] gain_owner,input wire [15:0] gain_target,
    output wire gain_done,gain_error,output reg sample_done,''')
    replace('output reg voice_deadline_error','output wire deadline_error')
    replace('    reg active[0:VOICES-1],gate[0:VOICES-1];','''    wire frame_tick,gain_initialized,gain_deadline;
    wire [15:0] owner_gain;reg voice_deadline_error;
    reg [4:0] pending_owner,owner_read;
    // 归属只在新起音提交时写入，普通改音量不改相位、音色、包络或原始力度。
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [4:0] voice_owner[0:31];
    wire owner_write=rst_n && !panic && !busy && !frame_tick && allocation_state==2 && pending_op==1 &&
        pending_owner<18 && pending_timbre<10 && (pending_timbre<2 || custom_ready[pending_timbre-2]) &&
        (match_valid || free_valid || oldest_valid);
    always @(posedge clk) begin
        owner_read<=voice_owner[slot];
        if(owner_write) voice_owner[chosen_slot]<=pending_owner;
    end
    track_gain_bank #(.OWNERS(18)) gains(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .command_valid(gain_valid),.command_ready(gain_ready),.command_owner(gain_owner),.command_gain(gain_target),
        .command_done(gain_done),.command_error(gain_error),.read_owner(owner_read),.read_gain(owner_gain),
        .initialized(gain_initialized),.frame_done(frame_tick),.deadline_error(gain_deadline));
    assign deadline_error=voice_deadline_error || gain_deadline;
    reg active[0:VOICES-1],gate[0:VOICES-1];''')
    # 以下组合控制引用必须放在声明之后，兼容Gowin/Icarus的严格名称绑定。
    a=source.index('    wire owner_write=');b=source.index('    track_gain_bank',a)
    owner_logic=source[a:b];source=source[:a]+source[b:]
    anchor='    // 相位步进以实际Fs='
    at=source.index(anchor);source=source[:at]+owner_logic+source[at:]
    replace('reg [2:0] step;','reg [3:0] step;')
    replace('    reg signed [35:0] sum;','''    reg signed [35:0] sum;
    reg signed [36:0] velocity_product;
    reg signed [53:0] gain_product;''')
    replace('&& !panic;','&& !panic && gain_initialized;')
    replace('    always @(posedge clk) begin\n        if(!rst_n) begin','    always @(posedge clk) begin\n        sample_done<=0;\n        if(!rst_n) begin')
    replace('            pending_op<=0;','            velocity_product<=0;gain_product<=0;pending_owner<=0;\n            pending_op<=0;')
    replace('                pending_note<=command_note;','                pending_owner<=command_owner;\n                pending_note<=command_note;')
    replace('end else if(pending_op==1 && pending_timbre<10 &&','end else if(pending_op==1 && pending_owner<18 && pending_timbre<10 &&')
    a=source.index('                    5: begin');b=source.index('                    6: begin',a);c=source.index('                    default:',b)
    update=source[a:b].replace('5: begin','7: begin',1).replace('step<=6;','step<=8;')
    old='($signed(product)*$signed({1\'b0,velocity[slot]})>>>19)'
    if old not in update:raise RuntimeError('原始力度乘法结构已变化')
    update=update.replace(old,'($signed(gain_product)>>>34)')
    finish=source[b:c].replace('6: begin','8: begin',1).replace('voice_count<=frame_voice_count;','voice_count<=frame_voice_count;sample_done<=1;')
    pipeline='''                    // 后级Q1.15增益拆为两个DSP时隙；37+17位乘法保留完整54位结果。
                    5: begin velocity_product<=$signed(product)*$signed({1'b0,velocity[slot]});step<=6;end
                    6: begin gain_product<=$signed(velocity_product)*$signed({1'b0,owner_gain});step<=7;end
'''
    source=source[:a]+pipeline+update+finish+source[c:]
    source=source.replace('`include "synth32_pitch.inc"',(ROOT/'rtl/audio/synth32_pitch.inc').read_text(encoding='utf-8'))
    target=ROOT/'experiments/workstation_tracks/synth32_tracks.sv';target.write_text(source,encoding='utf-8')
    (target.parent/'synth_source.json').write_text(json.dumps(dict(original_synth_sha256=original_hash,
        generated_sha256=hashlib.sha256(source.encode()).hexdigest(),integrated=False),indent=2),encoding='utf-8')
    print('Prepared independent 32-voice track-gain candidate')

if __name__=='__main__':main()
