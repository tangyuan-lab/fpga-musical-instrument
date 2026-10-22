"""由现有独立引脚/音频测试生成 16 键边界回归，保留原 13 键回归。"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

audio = (ROOT/'tests/tb_screen_touch_audio_path.sv').read_text(encoding='utf-8')
audio = audio.replace('tb_screen_touch_audio_path', 'tb_screen_touch16_audio_path')
audio = audio.replace('KEY_COUNT = 13', 'KEY_COUNT = 16').replace('[12:0] physical', '[15:0] physical')
for name in ('touch_keys','held_keys','key_on_pulse','key_off_pulse'):
    audio = audio.replace('[12:0] '+name, '[15:0] '+name)
audio = audio.replace('[103:0]', '[127:0]').replace('104\'d', '128\'d').replace('13\'h', '16\'h').replace('13\'d0', '16\'d0')
audio = audio.replace('wire [3:0] active_key_count', 'wire [4:0] active_key_count')
audio = audio.replace('.CLKS_PER_BIT(CLKS_PER_BIT), .POLYPHONIC', '.KEY_COUNT(KEY_COUNT), .CLKS_PER_BIT(CLKS_PER_BIT), .POLYPHONIC')
audio = audio.replace('#(.TOUCH_VELOCITY', '#(.KEY_COUNT(KEY_COUNT), .TOUCH_VELOCITY').replace('#(.MIX_SHIFT', '#(.KEY_COUNT(KEY_COUNT), .MIX_SHIFT')
extra = '\n'.join(f'''        send_frame(8'h01, 8'd{key});
        expect_note(4'd{key}, 32'd{phase});
        repeat (100) next_audio_sample();
        send_frame(8'h00, 8'd{key});
        expect_silence();''' for key,phase in [(13,48762484),(14,51662052),(15,54734038)])
extra += '''
        // 范围外键 16 不得产生触摸状态；全 16 键计数不得回绕为 0。
        send_frame(8'h01, 8'd16);
        if (touch_keys !== 0) $fatal(1, "out-of-range key accepted");
        physical_keys = 16'hffff;
        repeat (32) @(negedge clk);
        if (active_key_count !== 5'd16) $fatal(1, "16-key count overflow");
        physical_keys = 0;
        repeat (32) @(negedge clk);
        expect_silence();
        // 清理 allocator 的轮询状态，保留后续四声部固定槽位回归。
        rst_n = 0;
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (5) @(negedge clk);
'''
audio = audio.replace('        // 同音双来源', extra+'\n        // 同音双来源')
(ROOT/'tests/tb_screen_touch16_audio_path.sv').write_text(audio, encoding='utf-8')

tx = (ROOT/'tests/tb_serial_screen_nextion_tx.sv').read_text(encoding='utf-8')
tx = tx.replace('tb_serial_screen_nextion_tx','tb_serial_screen_nextion16_tx').replace('[155:0]','[191:0]').replace("156'd", "192'd")
tx = tx.replace('reg [3:0] active_key_count', 'reg [4:0] active_key_count').replace("active_key_count = 4'd2", "active_key_count = 5'd16")
tx = tx.replace('.CLKS_PER_BIT(CLKS_PER_BIT), .STARTUP', '.KEY_COUNT(16), .CLKS_PER_BIT(CLKS_PER_BIT), .STARTUP')
tx = tx.replace('<= 15', '<= 18').replace('< 13', '< 16').replace('expect_command(1, "2")', 'expect_command(1, "10")')
tx = tx.replace('default: initial_pressure_text', '12: initial_pressure_text = "A0C";\n                13: initial_pressure_text = "A0D";\n                14: initial_pressure_text = "A0E";\n                default: initial_pressure_text').replace('default: initial_pressure_text = "A0C"', 'default: initial_pressure_text = "A0F"')
(ROOT/'tests/tb_serial_screen_nextion16_tx.sv').write_text(tx, encoding='utf-8')

pressure = (ROOT/'tests/tb_13key_audio_path.sv').read_text(encoding='utf-8').replace('tb_13key_audio_path','tb_16key_pressure_audio_path').replace('KEY_COUNT = 13','KEY_COUNT = 16')
pressure = pressure.replace('wire [3:0] active_key_count','wire [4:0] active_key_count').replace('.CALIBRATION_SAMPLES(4)', '.KEY_COUNT(KEY_COUNT), .CALIBRATION_SAMPLES(4)').replace('poly_synth_4voice synth', 'poly_synth_4voice #(.KEY_COUNT(KEY_COUNT)) synth')
pressure = pressure.replace("set_key_sample(4,  12'd2750)", "set_key_sample(13, 12'd2750)").replace("set_key_sample(7,  12'd2700)", "set_key_sample(14, 12'd2700)").replace("set_key_sample(12, 12'd2600)", "set_key_sample(15, 12'd2600)").replace("16'hc740", "16'hfed0")
pressure = pressure.replace('        nonzero_count = 0;', '''        if (voice_phase_steps !== {32'd54734038,32'd51662052,32'd48762484,32'd23012828})
            $fatal(1, "added sensor keys did not map to C#5/D5/D#5");
        nonzero_count = 0;''')
pressure = pressure.replace('        $display("PASS', '''        set_all_samples(12'd2600);
        repeat (24) adc_frame();
        if (active_key_count !== 5'd16) $fatal(1, "pressure active count overflow");
        $display("PASS''')
pressure = pressure.replace('从 13 路', '从 16 路').replace('C4、E4、G4、C5', 'C4、C#5、D5、D#5')
(ROOT/'tests/tb_16key_pressure_audio_path.sv').write_text(pressure, encoding='utf-8')

build = (ROOT/'gowin/build_instrument_touch.tcl').read_text(encoding='utf-8').replace('set variant instrument_touch', 'set variant instrument_touch16')
if '{rtl audio i2s_tx.sv}' not in build:
    build = build.replace('{rtl audio pt8211_tx.sv}', '{rtl audio pt8211_tx.sv}\n    {rtl audio i2s_tx.sv}')
(ROOT/'gowin/build_instrument_touch16.tcl').write_text(build, encoding='utf-8')
