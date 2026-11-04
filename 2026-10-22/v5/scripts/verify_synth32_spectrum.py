"""采集V2实际RTL的四音PCM并作FFT；不是电脑合成，也不是板卡模拟录音。"""
from pathlib import Path
import json,os,subprocess
import numpy as np
ROOT=Path(__file__).resolve().parents[1];TOOLS=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))

def main():
    env=os.environ.copy();env['PATH']=str(TOOLS)+os.pathsep+env['PATH']
    output=ROOT/'build/tests/tb_synth32_spectrum.vvp'
    for cmd in ([str(TOOLS/'iverilog.exe'),'-g2012','-I','rtl/audio','-s','tb_synth32_spectrum','-o',str(output),'rtl/audio/synth32.sv','tests/tb_synth32_spectrum.sv'],
                [str(TOOLS/'vvp.exe'),str(output)]):
        subprocess.run(cmd,cwd=ROOT,env=env,check=True,timeout=300)
    samples=np.loadtxt(ROOT/'build/tests/synth32_four_frequency_samples.csv');fs=50_000_000/1024
    assert len(samples)==8192
    window=np.hanning(len(samples));spectrum=abs(np.fft.rfft((samples-samples.mean())*window))*2/window.sum()
    frequencies=np.fft.rfftfreq(len(samples),1/fs);peaks=[]
    for name,note in (('C4',60),('E4',64),('G4',67),('B4',71)):
        expected=440*2**((note-69)/12);candidates=np.where(abs(frequencies-expected)<=1.5*fs/len(samples))[0]
        index=int(candidates[np.argmax(spectrum[candidates])])
        assert spectrum[index]>500,f'{name}: fundamental missing'
        assert abs(frequencies[index]-expected)<=fs/len(samples),f'{name}: frequency outside one FFT bin'
        peaks.append(dict(note=name,expected_hz=expected,fft_peak_hz=float(frequencies[index]),amplitude=float(spectrum[index])))
    assert len({p['fft_peak_hz'] for p in peaks})==4
    report=dict(status='passed',evidence='RTL synth32 PCM; not hardware recording',samples=len(samples),sample_rate_hz=fs,
        simultaneous_fundamentals=4,engine_capacity=32,fft_resolution_hz=fs/len(samples),peaks=peaks)
    (ROOT/'build/tests/synth32_spectrum.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS synth32 FFT: '+', '.join(f"{p['note']}={p['fft_peak_hz']:.3f}Hz" for p in peaks))
if __name__=='__main__':main()
