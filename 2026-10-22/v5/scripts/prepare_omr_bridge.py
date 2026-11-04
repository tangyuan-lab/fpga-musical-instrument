"""固定OMR转换依赖到独立venv，保留各组件许可及完整安装清单。"""
from pathlib import Path
import json,subprocess,sys,venv


def main():
    root=Path(__file__).resolve().parents[1];folder=root/'build/tools/omr_bridge';python=folder/'Scripts/python.exe'
    if not python.is_file():venv.EnvBuilder(with_pip=True).create(folder)
    requirements=root/'scripts/requirements_omr_bridge.txt'
    subprocess.run([str(python),'-m','pip','install','--disable-pip-version-check','-r',str(requirements)],check=True)
    frozen=subprocess.check_output([str(python),'-m','pip','freeze'],text=True)
    (folder/'requirements.lock').write_text(frozen,encoding='utf-8')
    license_code="""import importlib.metadata as m,pathlib,shutil,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(exist_ok=True)
for name in ('converter21','music21'):
 d=m.distribution(name)
 for f in d.files or []:
  if 'license' in f.name.lower() and '.dist-info' in str(f):
   p=pathlib.Path(d.locate_file(f));shutil.copyfile(p,out/(name+'_'+p.name))
"""
    subprocess.run([str(python),'-c',license_code,str(folder/'licenses')],check=True)
    (folder/'manifest.json').write_text(json.dumps(dict(python=str(python),packages={'converter21':'4.0.2','music21':'10.5.0'},purpose='kern bridge only; no OMR model'),indent=2),encoding='utf-8')
    print('Prepared isolated kern bridge: '+str(python))

if __name__=='__main__':main()
