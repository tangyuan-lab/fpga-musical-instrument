"""准备独立的Transcoda评测环境；不改变默认识谱引擎，不确认识别内容。"""
from pathlib import Path
import argparse,json,shutil,subprocess,sys

ROOT=Path(__file__).resolve().parents[1]
SOURCE_REVISION='d4e2e687d5679ae96ca4aa6f01e06a5b338cd488'
MODEL_REVISION='b529f8aa5d996d9224df3395b5b92d0867343c91'


def run(command,**kwargs):return subprocess.run([str(x) for x in command],check=True,**kwargs)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--python',help='Python3.12解释器路径')
    parser.add_argument('--skip-install',action='store_true',help='只核对已安装环境并保存清单，不访问包仓库');args=parser.parse_args()
    source=ROOT/'build/tools/transcoda';environment=ROOT/'build/tools/transcoda_env';python=environment/'Scripts/python.exe'
    if not source.exists():
        run(['git','clone','--no-checkout','https://github.com/btrkeks/transcoda.git',source])
        run(['git','-C',source,'checkout','--detach',SOURCE_REVISION])
    actual=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
    if actual!=SOURCE_REVISION:raise RuntimeError('评测源码版本不匹配；保留现有目录，请检查后使用指定版本')
    if not python.is_file():
        base=args.python
        if not base:
            uv=shutil.which('uv')
            if uv:base=subprocess.check_output([uv,'python','find','3.12'],text=True).strip()
        if not base:raise RuntimeError('需要Python3.12；请用 --python 指定解释器')
        version=subprocess.check_output([base,'-c','import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")'],text=True).strip()
        if version!='3.12':raise RuntimeError('该独立评测环境要求Python3.12')
        run([base,'-m','venv',environment])
    if not args.skip_install:run([python,'-m','pip','install','--disable-pip-version-check','-r',ROOT/'scripts/requirements_transcoda.txt'])
    freeze=subprocess.check_output([str(python),'-m','pip','freeze'],text=True);(environment/'requirements.lock').write_text(freeze,encoding='utf-8')
    # 只导入模型类，不实例化/下载模型；依赖检查也与GUI、Gowin进程分离。
    probe='import sys,json,torch;sys.path.insert(0,sys.argv[1]);from src.model import TranscodaModelForCausalLM;print(json.dumps({"torch":torch.__version__,"cuda":torch.cuda.is_available()}))'
    run([python,'-c',probe,source],timeout=120)
    licenses=environment/'licenses';licenses.mkdir(exist_ok=True);shutil.copyfile(source/'LICENSE',licenses/'transcoda_LICENSE')
    manifest=dict(source=str(source),source_revision=SOURCE_REVISION,python=str(python),model='btrkeks/transcoda-59M-zeroshot-v1',model_revision=MODEL_REVISION,
        dependency_import_passed=True,model_downloaded=False,inference_verified=False,default_engine=False)
    (environment/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Prepared Transcoda dependencies; model download and bounded PDF evaluation remain required')

if __name__=='__main__':main()
