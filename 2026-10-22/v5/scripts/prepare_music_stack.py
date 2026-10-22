"""准备独立的电脑校谱音源；不修改 FPGA，不传输音频到设备。"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, urllib.request, zipfile
import importlib.metadata,shutil

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'build/tools/music'
FLUID_VERSION = '2.6.1'
FLUID_URL = f'https://github.com/FluidSynth/fluidsynth/releases/download/v{FLUID_VERSION}/fluidsynth-v{FLUID_VERSION}-win10-x64-cpp11.zip'
FLUID_SHA = 'fab7a2e4b85675b66970f97a39bbc239729c5e0f237198b5922a6a73cbc8677c'
FONT_COMMIT = '684543d5e5efaef08d02be50dcda8d552478fa60'
FONT_SHA = '9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe'
FONT_ROOT = f'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/{FONT_COMMIT}/'
MUSE_URL='https://github.com/musescore/MuseScore/releases/download/v4.7.5/MuseScore-Studio-4.7.5.260831071-x86_64.msi'
MUSE_SHA='07b0f3292612e2df4c7e0632deb790add51b218f0ee33f7fecaa6111dd279ec6'

def download(url, target, expected=None):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        temporary = target.with_suffix(target.suffix+'.download')
        request = urllib.request.Request(url, headers={'User-Agent':'FPGA-Music-Workstation'})
        try:
            with urllib.request.urlopen(request, timeout=60) as stream, temporary.open('wb') as out:
                while block := stream.read(1024*1024): out.write(block)
            temporary.replace(target)
        finally: temporary.unlink(missing_ok=True)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    if expected and digest != expected: raise RuntimeError(f'SHA256 校验失败：{target}')
    print(target.name, digest, flush=True)
    return {'url':url, 'sha256':digest, 'path':str(target.relative_to(ROOT))}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--install-python',action='store_true')
    parser.add_argument('--with-musescore',action='store_true',help='解包官方MuseScore到工程工具目录，不注册系统安装');args=parser.parse_args()
    if args.install_python:
        lock=ROOT/'host_app/requirements_workstation.lock.txt'
        subprocess.run([sys.executable,'-m','pip','install','-r',str(lock if lock.exists() else ROOT/'host_app/requirements_workstation.txt')],check=True)
    archive=TOOLS/f'fluidsynth-{FLUID_VERSION}.zip'
    records=[download(FLUID_URL,archive,FLUID_SHA)]
    with zipfile.ZipFile(archive) as package:
        destination=(TOOLS/'fluidsynth').resolve()
        for entry in package.infolist():
            if not (destination/entry.filename).resolve().is_relative_to(destination):raise ValueError('下载包路径无效')
        package.extractall(destination)
    records.append(download(FONT_ROOT+'GeneralUser-GS.sf2',TOOLS/'GeneralUser-GS.sf2',FONT_SHA))
    records.append(download(FONT_ROOT+'documentation/LICENSE.txt',TOOLS/'GeneralUser-GS-LICENSE.txt'))
    executables=list((TOOLS/'fluidsynth').rglob('fluidsynth.exe'))
    if not executables:raise RuntimeError('下载包未包含 fluidsynth.exe')
    manifest={'fluidsynth':str(executables[0].relative_to(ROOT)),'soundfont':str((TOOLS/'GeneralUser-GS.sf2').relative_to(ROOT)),
              'font_commit':FONT_COMMIT,'resources':records}
    if args.with_musescore:
        archive=TOOLS/'MuseScore-4.7.5.msi';records.append(download(MUSE_URL,archive,MUSE_SHA))
        destination=TOOLS/'musescore';exe=destination/'MuseScore 4/bin/MuseScore4.exe'
        if not exe.is_file():
            result=subprocess.run(['msiexec.exe','/a',str(archive),'/qn',f'TARGETDIR={destination}',
                                   '/l*v',str(TOOLS/'musescore_extract.log')],timeout=300)
            if result.returncode not in (0,3010) or not exe.is_file():raise RuntimeError('MuseScore解包失败，请查看musescore_extract.log')
        manifest['musescore']=str(exe.relative_to(ROOT))
        records.append(download('https://raw.githubusercontent.com/musescore/MuseScore/v4.7.5/LICENSE.txt',TOOLS/'MuseScore-LICENSE.txt'))
    licenses=[]
    for package in ('verovio','partitura','PySide6','PySide6_Essentials','PySide6_Addons','shiboken6','mido'):
        distribution=importlib.metadata.distribution(package);destination=TOOLS/'licenses'/package;destination.mkdir(parents=True,exist_ok=True)
        copied=[]
        for entry in distribution.files or []:
            if entry.name.lower().startswith(('license','copying','notice')):
                source=distribution.locate_file(entry)
                if source.is_file():shutil.copy2(source,destination/source.name);copied.append(str((destination/source.name).relative_to(ROOT)))
        licenses.append({'package':package,'version':distribution.version,'license':distribution.metadata.get('License-Expression') or distribution.metadata.get('License'),
                         'files':copied})
    manifest['python_components']=licenses
    # 只锁定此应用的依赖闭包，避免把用户环境中无关的开发包写进安装清单。
    from packaging.requirements import Requirement
    pending=['pyserial','PySide6','mido','Pillow','PyMuPDF','numpy','opencv-python-headless','verovio','partitura'];locked={}
    while pending:
        package=pending.pop()
        try:distribution=importlib.metadata.distribution(package)
        except importlib.metadata.PackageNotFoundError:
            if package!='opencv-python-headless':raise
            distribution=importlib.metadata.distribution('opencv-python')
        canonical=distribution.metadata['Name'].lower().replace('_','-')
        if canonical in locked:continue
        locked[canonical]=distribution.version
        for dependency in distribution.requires or []:
            requirement=Requirement(dependency)
            if not requirement.marker or requirement.marker.evaluate({'extra':''}):pending.append(requirement.name)
    lock_text='# Windows x64 / Python '+sys.version.split()[0]+'; generated by prepare_music_stack.py\n'
    (ROOT/'host_app/requirements_workstation.lock.txt').write_text(lock_text+''.join(f'{name}=={version}\n' for name,version in sorted(locked.items())),encoding='utf-8')
    (TOOLS/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS 电脑音乐组件准备完成；音源仅用于本机参考试听',flush=True)

if __name__=='__main__':main()
