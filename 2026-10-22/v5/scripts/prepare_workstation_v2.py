"""生成V2独立顶层和Gowin工程；保留旧版及已确认的两片ADC接线。"""
from pathlib import Path
import re,sys
ROOT=Path(__file__).resolve().parents[1]

def prepare():
    old=(ROOT/'rtl/board/instrument_workstation_top.sv').read_text(encoding='utf-8')
    prefix=old[:old.index('    wire cmd_valid,command_error;')]
    prefix=prefix.replace('instrument_workstation_top','instrument_workstation_v2_top').replace('    parameter integer AUDIO_I2S = 0,\n','').replace('output wire [5:0] led_n','output wire [2:0] led_n')
    body=(ROOT/'rtl/board/workstation_v2_body.inc').read_text(encoding='utf-8')
    body=body.replace('assign pa_en=live_pa_en','assign pa_en=1\'b0')
    body=body.replace('assign led_n={~adc_fault,~calibrated,~midi_playing,~(|guide_keys),~live_audio_ready,~deadline_error}',
                      'assign led_n={~adc_fault,~(|guide_keys),~deadline_error}')
    tail=old[old.index('    mcp3208_dual_scan #'):]
    # V2状态回传使用四拍最大值树，替代旧显示路径的16次串联比较。
    tail=re.sub(r"        max_pressure = 13'd0;\n        for \(key_index.*?max_pressure = \{1'b0, pressure_values\[key_index\*ADC_BITS \+: ADC_BITS\]\};\n",'',tail,count=1,flags=re.S)
    # 保留题目计划中的硬件视频验证输出；面积优化针对存储结构，不删除功能。
    (ROOT/'rtl/board/instrument_workstation_v2_top.sv').write_text(prefix+body+tail,encoding='utf-8')
    # V2映射服务含独立的时序流水线，不能再从旧工作版字符串派生覆盖。
    if not (ROOT/'rtl/control/instrument_mode_control_v2.sv').is_file():
        raise FileNotFoundError('缺少独立V2映射服务源码')
    synth=(ROOT/'rtl/audio/synth32.sv').read_text(encoding='utf-8').replace('`include "synth32_pitch.inc"',(ROOT/'rtl/audio/synth32_pitch.inc').read_text(encoding='utf-8'))
    (ROOT/'rtl/audio/synth32_generated.sv').write_text(synth,encoding='utf-8')
    cst=(ROOT/'gowin/instrument_workstation.cst').read_text(encoding='utf-8')
    cst=re.sub(r'^.*"led_n\[[0-5]\]".*\n','',cst,flags=re.M)
    for name,pin in [('hp_bck','T21'),('hp_ws','U21'),('hp_din','P16')]:cst=re.sub(rf'IO_LOC "{name}" [^;]+;',f'IO_LOC "{name}" {pin};',cst)
    cst+='\n// V2标准I2S：PMOD0 IO2/3/4，必须接外置I2S DAC；板内PT8211数据脚不再驱动。\n'
    for i,pin in enumerate(['R17','R18','T18']):cst+=f'IO_LOC "led_n[{i}]" {pin};\nIO_PORT "led_n[{i}]" IO_TYPE=LVCMOS33 DRIVE=4 BANK_VCCIO=3.3;\n'
    cst=cst.replace('// HDMI、PT8211、PMOD0 LED 和 PMOD1 MCP3208 沿用已验证约束；','// HDMI与PMOD1 MCP3208保留；PMOD0 IO2/3/4输出标准I2S。')
    (ROOT/'gowin/instrument_workstation_v2.cst').write_text(cst,encoding='utf-8')
    sources=['common/reset_sync.sv','common/snapshot_cdc.sv','common/button_filter.sv','common/control_ram_sdp.sv','io/uart_rx.sv','io/uart_tx.sv','io/uart_frame_protocol.sv',
      'io/uart_frame_tx_v2.sv','io/midi_file_ram_sdp.sv','io/workstation_v2_resources.sv','io/workstation_v2_emergency.sv','io/screen_touch_keys_rx.sv','io/mcp3208_dual_scan.sv',
      'io/workstation_v2_screen.sv','control/pressure_key_matrix.sv','control/pressure_max16.sv','control/workstation_v2_router.sv','control/instrument_mode_control_v2.sv',
      'control/drum_sequencer.sv','control/workstation_v2_player.sv','control/workstation_v2_commands.sv','midi/midi_type0_parser_v2.sv','audio/synth32_generated.sv','audio/audio_effects.sv',
      'audio/sample_ram.sv','audio/i2s_tx.sv','audio/audio_startup.sv','audio/drum_synth.sv','video/video_pll.sv','video/video_timing.sv','video/tmds_encoder.sv',
      'video/dvi_tx.sv','video/gowin_dvi_ip/DVI_TX_Top.v','video/instrument_ui_1024x600.sv','board/instrument_workstation_v2_top.sv']
    tcl='set root [file normalize [file join [file dirname [info script]] ..]]\nset variant instrument_workstation_v2\n'
    tcl+='file mkdir [file join $root build gowin $variant]\ncd [file join $root build gowin $variant]\nset_device GW5AT-LV60PG484AC1/I0 -device_version B\n'
    for source in sources:tcl+='add_file -type verilog [file join $root rtl '+source.replace('/',' ')+']\n'
    (ROOT/'gowin/instrument_workstation_v2.sdc').write_text((ROOT/'gowin/instrument_full.sdc').read_text(encoding='utf-8'),encoding='utf-8')
    tcl+='add_file -type cst [file join $root gowin instrument_workstation_v2.cst]\nadd_file -type sdc [file join $root gowin instrument_workstation_v2.sdc]\n'
    for option,value in [('top_module','instrument_workstation_v2_top'),('output_base_name','instrument_workstation_v2'),('synthesis_tool','gowinsynthesis'),('verilog_std','sysv2017'),('global_freq','50.000'),('cst_warn_to_error','1'),('use_cpu_as_gpio','1'),('use_jtag_as_gpio','0'),('vccx','1.8')]:tcl+=f'set_option -{option} {value}\n'
    # Gowin route_option=1：默认算法在接近满载时可能长时间停在Routing Phase 0；
    # 候选算法保持同一网表、约束和时序门禁，只改变布线搜索策略。
    tcl+='set_option -route_option 1\nrun all\n';(ROOT/'gowin/build_instrument_workstation_v2.tcl').write_text(tcl,encoding='utf-8')
    (ROOT/'gowin/build_instrument_workstation_v2_syn.tcl').write_text(tcl.replace('run all\n','run syn\n'),encoding='utf-8')
    pnr=tcl[:tcl.index('add_file -type verilog')]
    pnr+='add_file -type netlist [file join $root build gowin $variant impl gwsynthesis instrument_workstation_v2.vg]\n'
    pnr+=tcl[tcl.index('add_file -type cst'):].replace('run all\n','run pnr\n')
    (ROOT/'gowin/build_instrument_workstation_v2_pnr.tcl').write_text(pnr,encoding='utf-8')
    import xml.etree.ElementTree as ET
    tree=ET.parse(ROOT/'gowin/instrument_workstation.gprj');files=tree.find('FileList');files.clear()
    for source in sources:ET.SubElement(files,'File',path='../rtl/'+source,type='file.verilog',enable='1')
    for filename,kind in [('instrument_workstation_v2.cst','cst'),('instrument_workstation_v2.sdc','sdc')]:ET.SubElement(files,'File',path=filename,type='file.'+kind,enable='1')
    ET.indent(tree,space='    ');tree.write(ROOT/'gowin/instrument_workstation_v2.gprj',encoding='utf-8',xml_declaration=True)
    print('Prepared V2: standard I2S, 32 voices, original ADC pins; external DAC required')
if __name__=='__main__':prepare()
