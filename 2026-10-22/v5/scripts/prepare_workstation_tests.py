"""复用真实压力/串口延迟测试，加上工作站模式、映射及三路PCM混合路径。"""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]

def prepare():
    polarity=json.loads((ROOT/'config/instrument_registry.json').read_text(encoding='utf-8'))['pressure_inputs']['active_low_mask']
    if type(polarity) is not int or not 0<=polarity<=0xffff:raise ValueError('invalid pressure polarity mask')
    top=(ROOT/'rtl/board/instrument_workstation_top.sv').read_text(encoding='utf-8')
    match=re.search(r"ACTIVE_LOW_MASK = 16'h([0-9a-f]{4})",top)
    if not match or int(match[1],16)!=polarity:raise ValueError('run prepare_workstation.py before preparing matching pressure tests')
    src=(ROOT/'tests/tb_instrument_latency.sv').read_text(encoding='utf-8')
    src=src.replace('tb_instrument_latency','tb_workstation_latency')
    # 镜像ADC码保持同样的16码轻按压差，使用与正式顶层相同的逐键方向。
    idle_bus=''.join(f'{3000 if polarity&(1<<key) else 1095:03x}' for key in reversed(range(16)))
    src=src.replace("    reg [191:0] analog_values={16{12'd3000}};",
        f"    localparam [15:0] INPUT_POLARITY=16'h{polarity:04x};\n    localparam [191:0] ADC_IDLE=192'h{idle_bus};\n    reg [191:0] analog_values=ADC_IDLE;")
    src=src.replace("analog_values={16{12'd3000}};","analog_values=ADC_IDLE;")
    src=src.replace("analog_values[key*12+:12]=12'd2984;","analog_values[key*12+:12]=INPUT_POLARITY[key] ? 12'd2984 : 12'd1111;")
    src=src.replace('.KEY_COUNT(16),.CALIBRATION_SAMPLES(4)', '.KEY_COUNT(16),.CALIBRATION_SAMPLES(4),.ACTIVE_LOW_MASK(INPUT_POLARITY)')
    src=src.replace('    wire tick,pt_bck', '    wire pt_bck')
    src=src.replace('    wire signed [15:0] audio;', '''    wire tick;
    wire signed [15:0] audio,piano_pcm,drum_pcm;
    wire [2:0] mode,edit_bank;wire mode_changed,map_changed,command_error,command_valid;
    wire [7:0] command_op,command_value;wire [255:0] mapping;wire [3:0] edit_key;wire [15:0] descriptor;
    wire [6:0] v0,v1,v2;wire start_midi,stop_midi;
    wire [15:0] routed_keys,screen_piano,chord,drum_triggers;wire [95:0] mapped_timbres;
    wire [127:0] mapped_notes,drum_velocity;
    reg signed [15:0] midi_pcm=0;
    instrument_mode_control modes(.clk(clk),.rst_n(rst_n),.cmd_valid(command_valid),.mode_pressed(1'b0),
        .cmd_op(command_op),.cmd_value(command_value),.mode(mode),.mode_changed(mode_changed),.map_changed(map_changed),
        .command_error(command_error),.active_map(mapping),.edit_bank(edit_bank),.edit_key(edit_key),.edit_descriptor(descriptor),
        .piano_volume(v0),.drum_volume(v1),.midi_volume(v2),.midi_start(start_midi),.midi_stop(stop_midi));
    instrument_key_router router(.clk(clk),.rst_n(rst_n),.mode_changed(mode_changed),.map_changed(map_changed),.mode(mode),
        .active_map(mapping),.physical_keys(physical_keys),.screen_keys(touch_keys),.physical_velocity(physical_velocity),
        .physical_piano_keys(routed_keys),.physical_notes(mapped_notes),.physical_timbres(mapped_timbres),
        .screen_piano_keys(screen_piano),.chord_keys(chord),.drum_triggers(drum_triggers),.drum_velocity(drum_velocity));
    drum_synth drum_audio(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(mode_changed),
        .triggers(drum_triggers),.velocities(drum_velocity),.sample_out(drum_pcm));
    // 背景路保持零附近的合成载波；测延迟阶段关闭背景，避免背景非零掩盖起音。
    pcm_source_mixer mixer(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.samples({midi_pcm,drum_pcm,piano_pcm}),
        .volumes({v2,v1,v0}),.enables(3'b111),.sample_out(audio));''')
    src=src.replace('screen_touch_keys_rx #(.KEY_COUNT(16),.POLYPHONIC(1))','screen_touch_keys_rx #(.KEY_COUNT(16),.POLYPHONIC(1),.WORKSTATION_CONTROLS(1))')
    src=src.replace('.screen_rx_i(rx),.held_keys(touch_keys));','.screen_rx_i(rx),.held_keys(touch_keys),.command_valid(command_valid),.command_op(command_op),.command_value(command_value));')
    src=src.replace('.physical_keys(physical_keys),.physical_velocity(physical_velocity),.touch_keys(touch_keys)', '.physical_keys(routed_keys),.physical_velocity(physical_velocity),.touch_keys(screen_piano)')
    # 只替换旋律合成器输出，混音器端口仍驱动最终 audio。
    src=src.replace('.velocity_values(velocity),.sample_out(audio));','.velocity_values(velocity),.sample_out(piano_pcm));')
    src=src.replace('        wait(calibrated);','        uart_frame(5,3);\n        wait(calibrated);')
    src=src.replace('cases=6','cases=6 workstation_routing=PASS three_source_mixer=PASS')
    (ROOT/'tests/tb_workstation_latency.sv').write_text(src,encoding='utf-8')
    midi=(ROOT/'tests/tb_midi_player_top.sv').read_text(encoding='utf-8').replace('tb_midi_player_top','tb_midi_player_engine')
    midi=midi.replace('    midi_player_top dut (','''    reg external_play=0,external_stop=0;reg [9:0] divider=0;
    wire sample_tick=divider==1023;wire signed [15:0] pcm;wire file_ready,playing,parser_busy,parser_error;
    always @(posedge sys_clk) divider<=divider+1'b1;
    midi_player_engine dut (''')
    midi=midi.replace('.uart_tx_o(uart_tx_o), .led_n(led_n), .hp_bck(hp_bck), .hp_ws(hp_ws),\n        .hp_din(hp_din), .pa_en(pa_en)',
        '.uart_tx_o(uart_tx_o), .led_n(led_n), .sample_tick_i(sample_tick),.audio_ready_i(1\'b1),.play_enable_i(1\'b1),\n        .external_play(external_play),.external_stop(external_stop),.pcm_out(pcm),\n        .file_ready_o(file_ready),.playing_o(playing),.parser_busy_o(parser_busy),.parser_error_o(parser_error)')
    midi=midi.replace('        $display("PASS tb_midi_player_engine', '''        wait_cycles=0;
        while(pcm==0 && wait_cycles<20000) begin @(negedge sys_clk);wait_cycles=wait_cycles+1;end
        if(pcm==0 || !playing) $fatal(1,"external sample clock produced no MIDI PCM");
        external_stop=1;repeat(4) @(negedge sys_clk);external_stop=0;
        repeat(4) @(negedge sys_clk);
        if(playing || !file_ready) $fatal(1,"stop must retain uploaded file");
        external_play=1;@(negedge sys_clk);external_play=0;
        wait_cycles=0;
        while(!playing && wait_cycles<30000) begin @(negedge sys_clk);wait_cycles=wait_cycles+1;end
        if(!playing) $fatal(1,"screen external PLAY failed");
        $display("PASS tb_midi_player_engine''')
    (ROOT/'tests/tb_midi_player_engine.sv').write_text(midi,encoding='utf-8')

if __name__=='__main__':prepare()
