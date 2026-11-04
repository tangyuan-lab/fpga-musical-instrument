"""中文界面词条；只转换显示字符串，控件名和UART编号保持稳定。"""
import re

TEXT={
    'MUSIC STUDIO':'合成演奏工作站','HOME':'返回首页','Choose a mode':'请选择模式',
    'DRUM STUDIO':'鼓点模式','PIANO / LIVE':'弹琴模式','PERFORMANCE MIX':'混音模式','KEY ASSIGNMENT':'实体键设置',
    'PRESS MAX ----':'最高压力 ----','PRESS MAX ':'最高压力 ',
    'WAIT':'等待连接','READY':'音频就绪','AUDIO WAIT':'音频未就绪','MIDI NO FILE':'未载入 MIDI','MIDI ERROR':'MIDI 错误',
    'OCT 0':'原八度','OCT +1':'高八度','OCT -1':'低八度',
    'TONE TRI':'三角波','TONE SOFT':'柔和方波','TEST 4':'四音测试','TEST ON':'测试中','STOP ALL':'全部停止',
    'C4 - D#5  /  16 KEYS  /  LIVE CHORDS':'16 键 / C4-D#5 / 自动和弦识别',
    'SEQUENCER':'节奏编排','DRUM PADS':'鼓垫演奏','BPM 120':'速度 120','BPM ':'速度 ',
    'BEAT PLAY':'鼓点播放','BEAT STOP':'鼓点停止','ROCK':'摇滚','STRAIGHT':'四拍','EMPTY':'空白',
    'MIDI PLAY':'MIDI播放','MIDI STOP':'MIDI停止','START':'全播放','STOP':'全停止',
    'PIANO':'琴音','DRUM':'鼓音','MIDI':'曲音','PIA ':'琴 ','DRM ':'鼓 ','MID ':'曲 ','MUTE':'静音',
    'KICK':'大鼓','SNARE':'军鼓','C-HAT':'闭镲','O-HAT':'开镲','LO TOM':'低嗵','MID TOM':'中嗵','HI TOM':'高嗵',
    'CLAP':'拍手','RIM':'边击','RIDE':'叮镲','CRASH':'吊镲','COWBELL':'牛铃','SHAKER':'沙锤','TAMB':'铃鼓','WOOD':'木鱼','STICK':'鼓棒',
    'BANK DRUMS':'鼓点配置','BANK PIANO':'弹琴配置','BANK MIX':'混音配置','KEY 01':'实体键 01','KEY ':'实体键 ',
    'TYPE PIANO':'旋律音','TYPE DRUM':'打击乐','TONE TRIANGLE':'三角波','TONE SOFT SQUARE':'柔和方波','TONE DRUM KIT':'合成鼓组',
    'SAVE KEY':'保存当前键','RESET BANK':'恢复默认',
    'Screen keys keep their own sounds':'屏幕键使用当前模式的固定声音',
    '3 BANKS':'三套配置','16 KEYS':'16 个键','SAVED MAPS':'独立保存',
    'Saved - wait 1s before power off':'已保存，请等待 1 秒后断电',
    'Bank reset - wait 1s before power off':'已恢复默认，请等待 1 秒后断电',
    'Tap a pad. Build a beat.':'点击鼓垫演奏，或进入节奏编排',
    'Play keys - your chord appears above':'按下琴键演奏，上方自动识别和弦',
    'Edit a key, then SAVE KEY':'选择实体键和声音，修改后点击保存',
    'Choose a mode to start':'请选择模式，开始演奏',
    'Restoring saved key maps':'正在恢复已保存的实体键配置',
    'Ready - choose a mode':'准备就绪，请选择模式','NOTES':'音符组合',
}

def localize(widgets):
    for widget in widgets:
        fields=widget['fields']
        if 'txt' in fields:fields['txt']=TEXT.get(fields['txt'],fields['txt'])
        for lines in widget['events'].values():
            lines[:]=[re.sub(r'"([^"\n]*)"',lambda m:'"'+TEXT.get(m[1],m[1])+'"',line) for line in lines]

def quality_name(quality):
    special={'':'大三','m':'小三','dim':'减三','aug':'增三','5':'强力','m7b5':'半减七','7alt':'属七变'}
    if quality in special:return special[quality]
    result=quality.replace('(no5,11)','(省5,11)').replace('(no11)','(省11)').replace('(no5)','(省5)')
    for english,chinese in [('augMaj','增大'),('mMaj','小大'),('maj','大'),('aug','增'),('dim','减'),('m','小')]:
        if result.startswith(english):result=chinese+result[len(english):];break
    else:
        if result.startswith(('7','9','11','13')):result='属'+result
        elif result.startswith('6'):result='大'+result
    result=result.replace('sus','挂').replace('add','加')
    numbers={'13':'十三','11':'十一','9':'九','7':'七','6':'六','5':'五','4':'四','2':'二'}
    result=re.sub(r'^([大小属增减挂加]+)(13|11|9|7|6|5|4|2)',lambda m:m[1]+numbers[m[2]],result)
    return result.replace('挂2','挂二').replace('挂4','挂四')

def display_label_zh(names,bass=None):
    from chord_library import root_of
    preferred=[name for name in names if root_of(name)==bass] if bass is not None else []
    candidates=preferred or names
    labels=[root_of(name)+quality_name(name[len(root_of(name)):]) for name in candidates]
    width=lambda text:sum(16 if ord(c)<128 else 32 for c in text)
    result=labels[0]
    for label in labels[1:]:
        if width(result+'/'+label)>320:result=labels[0]+' +';break
        result+='/'+label
    assert width(result)<=320,result
    return result
