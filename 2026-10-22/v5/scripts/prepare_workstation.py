"""建立独立工作站顶层，复用旧工程硬件和 MIDI 服务；不会修改旧顶层。"""
from pathlib import Path
import json,re
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]

def generate_constraints(registry):
    """根据已确认的两组SPI接线生成工作站专用约束，信号电气属性跟随端口职责。"""
    groups=registry['pressure_inputs']['spi_pins']
    roles=('sclk','miso','mosi','cs_n')
    if not isinstance(groups,list) or len(groups)!=2:
        raise ValueError('pressure_inputs.spi_pins must contain exactly two MCP3208 pin groups')
    pinout={}
    for chip,group in enumerate(groups):
        if not isinstance(group,dict) or set(group)!=set(roles):
            raise ValueError(f'MCP{chip} requires sclk/miso/mosi/cs_n pins')
        for role,pin in group.items():
            if not isinstance(pin,str) or not re.fullmatch(r'[A-Z]{1,2}[1-9][0-9]?',pin):
                raise ValueError(f'invalid FPGA pin: MCP{chip}.{role}={pin!r}')
            pinout[f'mcp{chip}_{role}']=pin
    if len(set(pinout.values()))!=8:raise ValueError('SPI pins must be distinct')
    constraints=(ROOT/'gowin/instrument_full.cst').read_text(encoding='utf-8')
    start=constraints.index('// PMOD1 =')
    end=constraints.index('IO_LOC "mcp0_sclk"',start)
    description='// 工作站SPI约束由 pressure_inputs.spi_pins 生成，采集板从左到右为SCLK/MISO/MOSI/CS。\n'
    for chip in range(2):
        description+=f'// 第{chip+1}块：'+', '.join(f'{role}={pinout[f"mcp{chip}_{role}"]}' for role in roles)+'。\n'
    description+='// 改脚号同时保留MISO输入、MOSI/SCLK/CS输出的3.3V电气设置。\n'
    constraints=constraints[:start]+description+constraints[end:]
    pattern=r'(?m)^IO_LOC "(mcp[01]_(?:sclk|miso|mosi|cs_n))"\s+[A-Z]+\d+;'
    constraints,count=re.subn(pattern,lambda m:f'IO_LOC "{m[1]}" {pinout[m[1]]};',constraints)
    if count!=8:raise ValueError('SPI template must contain exactly eight IO_LOC assignments')
    # 检查整个工程中的球号重复，包含HDMI一条端口绑定两个差分球号的写法。
    used={}
    for port,balls in re.findall(r'IO_LOC "([^"]+)"\s+([^;]+);',constraints):
        for ball in balls.split(','):
            ball=ball.strip()
            if ball in used:raise ValueError(f'pin {ball} is assigned to {used[ball]} and {port}')
            used[ball]=port
    (ROOT/'gowin/instrument_workstation.cst').write_text(constraints,encoding='utf-8')

def prepare():
    registry=json.loads((ROOT/'config/instrument_registry.json').read_text(encoding='utf-8'))
    # 一位对应一路压力：0为按压升压（3.3V→FSR→CHx→下拉电阻→GND），1为按压降压。
    # SPI协议、数字采样宽度及后级基线/滤波保持不变；只覆盖独立工作站的默认方向。
    polarity=registry['pressure_inputs']['active_low_mask']
    if type(polarity) is not int or not 0<=polarity<=0xffff:
        raise ValueError('pressure_inputs.active_low_mask must be an integer in 0..65535')
    generate_constraints(registry)
    midi=(ROOT/'rtl/board/midi_player_top.sv').read_text(encoding='utf-8')
    midi=midi.replace('module midi_player_top #(', 'module midi_player_engine #(')
    start=midi.index('    output wire       hp_bck,')
    end=midi.index('\n);',start)
    midi=midi[:start]+'''    input wire sample_tick_i,audio_ready_i,play_enable_i,external_play,external_stop,
    output wire signed [15:0] pcm_out,
    output wire file_ready_o,playing_o,parser_busy_o,parser_error_o
'''+midi[end:]
    midi=midi.replace('    wire play_request;','    wire store_play_request;\n    wire play_request=play_enable_i && file_ready && (store_play_request || external_play);')
    midi=midi.replace('    wire stop_request;','    wire store_stop_request;\n    wire stop_request=store_stop_request || external_stop || !play_enable_i;')
    midi=midi.replace('    wire sample_tick;', '    wire sample_tick=sample_tick_i;')
    midi=midi.replace('    wire audio_ready;', '    wire audio_ready=audio_ready_i;')
    midi=midi.replace('.play_request(play_request), .stop_request(stop_request)', '.play_request(store_play_request), .stop_request(store_stop_request)')
    midi=midi.replace('(parser_busy || playing || play_pending);', '(parser_busy || playing || play_pending || !play_enable_i);')
    start=midi.index('    audio_startup audio_startup_inst (')
    end=midi.index('    uart_frame_tx #',start)
    midi=midi[:start]+'''    // 音频端口由上层统一采样时钟和唯一串行发送器驱动。
    assign pcm_out=midi_sample;
    assign file_ready_o=file_ready;assign playing_o=playing;
    assign parser_busy_o=parser_busy;assign parser_error_o=parser_error;
'''+midi[end:]
    midi=midi.replace('// 完整 MIDI 播放演示顶层。', '// MIDI PCM 服务：从旧独立播放器提取，UART 文件格式保持兼容。')
    (ROOT/'rtl/board/midi_player_engine.sv').write_text(midi,encoding='utf-8')
    old=(ROOT/'rtl/board/instrument_full_top.sv').read_text(encoding='utf-8')
    # 保留已验证的 HDMI 实例和两片 ADC 硬件接口，替换应用和音频组织方式。
    header=old[old.index('module instrument_full_top #('):old.index('    localparam integer ACTIVE_COUNT_WIDTH')]
    header=header.replace('instrument_full_top','instrument_workstation_top')
    header,replacements=re.subn(r'parameter \[KEY_COUNT-1:0\] ACTIVE_LOW_MASK = [^,\n]+,',
        f"// 0表示按压后ADC上升；接3.3V的裸FSR须在CHx端有到GND的分压电阻。\n    parameter [KEY_COUNT-1:0] ACTIVE_LOW_MASK = 16'h{polarity:04x},",header)
    if replacements!=1:raise ValueError('workstation pressure polarity parameter was not found exactly once')
    decl=old[old.index('    localparam integer ACTIVE_COUNT_WIDTH'):old.index('    assign hpd_en')]
    decl=decl.replace('    reg midi_mode;','    wire midi_mode=app_mode==3;')
    decl=decl.replace('    wire live_synth_rst_n = rst_n && !midi_mode;', '    wire live_synth_rst_n = rst_n && !mode_changed && !map_changed && !performance_stop && app_mode>=1 && app_mode<=3;')
    # MIDI 状态从独立接口取得，LED 只作观察而不再作为跨模块数据接口。
    decl=decl.replace('wire midi_audio_ready = ~midi_led_n[7];','wire midi_audio_ready = live_audio_ready;')
    decl=decl.replace('wire midi_file_ready = ~midi_led_n[6];','wire midi_file_ready;')
    decl=decl.replace('wire midi_parser_busy = ~midi_led_n[5];','wire midi_parser_busy;')
    decl=decl.replace('wire midi_playing = ~midi_led_n[4];','wire midi_playing;')
    decl=decl.replace('    wire [15:0] live_voice_keys;', '    wire [15:0] live_voice_keys;')
    hw=old[old.index('    mcp3208_dual_scan #'):old.index('    audio_startup #')]
    video=old[old.index('    always @(*) begin\n        max_pressure'):old.index('    wire _unused')]
    # HDMI 继续显示真实输入/压力，不修改既有图形模块。
    body=(ROOT/'rtl/board/workstation_body.inc').read_text(encoding='utf-8')
    early='    wire [2:0] app_mode;\n    wire mode_changed,map_changed,performance_stop;\n'
    body=body.replace('    wire [2:0] app_mode;\n','').replace('    wire cmd_valid,mode_changed,map_changed,command_error;','    wire cmd_valid,command_error;')
    result='`timescale 1ns/1ps\n`default_nettype none\n// 工作站顶层由 scripts/prepare_workstation.py 组合硬件与应用，修改应用请编辑 workstation_body.inc。\n'+header+early+decl+body+hw+video+'endmodule\n`default_nettype wire\n'
    (ROOT/'rtl/board/instrument_workstation_top.sv').write_text(result,encoding='utf-8')
    tcl=(ROOT/'gowin/build_instrument_touch16.tcl').read_text(encoding='utf-8')
    tcl=tcl.replace('set variant instrument_touch16','set variant instrument_workstation')
    tcl=tcl.replace('gowin instrument_full.cst','gowin instrument_workstation.cst')
    extras=['control instrument_mode_control.sv','control instrument_key_router.sv','control drum_sequencer.sv','audio drum_synth.sv','audio pcm_source_mixer.sv','io workstation_screen_tx.sv','board midi_player_engine.sv','board instrument_workstation_top.sv']
    tcl=tcl.replace('    {rtl board instrument_full_top.sv}', '\n'.join('    {rtl '+x+'}' for x in extras))
    tcl=tcl.replace('-top_module instrument_full_top','-top_module instrument_workstation_top')
    (ROOT/'gowin/build_instrument_workstation.tcl').write_text(tcl,encoding='utf-8')
    (ROOT/'gowin/build_instrument_workstation_pnr.tcl').write_text(
        '# 只在脚本已核对RTL/SDC/电气属性与旧网表一致后使用。\n'
        'set root [file normalize [file join [file dirname [info script]] ..]]\n'
        'set variant instrument_workstation\n'
        'cd [file join $root build gowin $variant]\n'
        'set_device GW5AT-LV60PG484AC1/I0 -device_version B\n'
        'add_file -type netlist [file join $root build gowin $variant impl gwsynthesis instrument_workstation.vg]\n'
        'add_file -type cst [file join $root gowin instrument_workstation.cst]\n'
        'add_file -type sdc [file join $root gowin instrument_full.sdc]\n'
        'set_option -top_module instrument_workstation_top\n'
        'set_option -output_base_name $variant\n'
        'set_option -global_freq 50.000\n'
        'set_option -cst_warn_to_error 1\n'
        'set_option -use_cpu_as_gpio 1\n'
        'set_option -use_jtag_as_gpio 0\n'
        'set_option -vccx 1.8\n'
        'run pnr\n',encoding='utf-8')
    project=ET.parse(ROOT/'gowin/instrument_touch16.gprj')
    files=project.find('FileList')
    files.clear()
    for parts in re.findall(r'\{(rtl [^{}]+\.s?v)\}',tcl):
        ET.SubElement(files,'File',path='../'+'/'.join(parts.split()),type='file.verilog',enable='1')
    for extension in ('cst','sdc'):
        stem='instrument_workstation' if extension=='cst' else 'instrument_full'
        ET.SubElement(files,'File',path=f'{stem}.{extension}',type=f'file.{extension}',enable='1')
    ET.indent(project,space='    ')
    project.write(ROOT/'gowin/instrument_workstation.gprj',encoding='utf-8',xml_declaration=True)

if __name__=='__main__': prepare()
