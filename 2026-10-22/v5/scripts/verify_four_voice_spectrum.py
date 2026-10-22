"""分析四频测试模式的 RTL 样本；这是仿真频谱，不是板卡录音。"""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
samples = np.loadtxt(ROOT / 'build/tests/four_voice_test_samples.csv')
assert len(samples) == 4096, 'Expected 4096 samples from tb_screen_performance_controls'
fs = 50_000_000 / 1024
window = np.hanning(len(samples))
spectrum = abs(np.fft.rfft((samples-samples.mean()) * window)) * 2 / window.sum()
frequencies = np.fft.rfftfreq(len(samples), 1/fs)
peaks=[]
for name,step in [('C4',23012828),('E4',28994347),('G4',34480283),('B4',43442435)]:
    target = step * fs / 2**32
    candidates = np.where(abs(frequencies-target) <= 1.5*fs/len(samples))[0]
    index = int(candidates[np.argmax(spectrum[candidates])])
    assert spectrum[index] > 500, f'Missing audible fundamental: {name}'
    assert abs(frequencies[index]-target) <= fs/len(samples), f'Wrong frequency: {name}'
    peaks.append({'note':name,'expected_hz':round(target,4),
                  'fft_peak_hz':round(float(frequencies[index]),4),'amplitude':round(float(spectrum[index]),2)})
assert len({p['fft_peak_hz'] for p in peaks}) == 4
report={'status':'passed','evidence':'RTL simulation; not hardware recording',
        'output_sample_rate_hz':fs,'samples':len(samples),'independent_voices':4,
        'oscillator_samples_per_second':4*fs,'fundamentals':peaks}
(ROOT/'build/tests/four_voice_spectrum.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS four independent fundamentals:', ', '.join(f"{p['note']}={p['fft_peak_hz']}Hz" for p in peaks))
