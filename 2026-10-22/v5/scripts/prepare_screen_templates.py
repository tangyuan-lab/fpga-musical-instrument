"""把使用者自行取得的HMI模板导入本机；不下载、不改写模板。"""
from pathlib import Path
import argparse,hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--minimal',required=True,type=Path);parser.add_argument('--factory',required=True,type=Path);args=parser.parse_args()
    spec=ROOT/'screen/TJC1060X570/vendor/templates.lock.json'
    if not spec.is_file():raise RuntimeError('此入口用于GitHub导出的模板清单，请使用导出目录中的脚本')
    records=json.loads(spec.read_text(encoding='utf-8'))
    checked=[]
    for kind in ('minimal','factory'):
        source=getattr(args,kind).resolve();record=records[kind]
        if hashlib.sha256(source.read_bytes()).hexdigest()!=record['sha256']:
            raise ValueError(f'{kind}模板与本版基线不一致；请使用对应模板或另行适配生成器')
        destination=(ROOT/record['destination']).resolve()
        if not destination.is_relative_to(ROOT):raise ValueError('模板目标路径越界')
        if destination.exists() and source!=destination and destination.read_bytes()!=source.read_bytes():
            raise ValueError('目标已有不同模板，请先保留备份再处理：'+str(destination))
        checked.append((source,destination))
    for source,destination in checked:
        destination.parent.mkdir(parents=True,exist_ok=True)
        if source!=destination:shutil.copyfile(source,destination)
    print('PASS 模板摘要一致，已导入；原始模板未修改')

if __name__=='__main__':main()
