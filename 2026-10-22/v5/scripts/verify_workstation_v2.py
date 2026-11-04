"""检查V2串口屏源码的控件、计时器和事件边界；不冒充USART HMI官方TFT编译。"""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[1]
def main():
    manifest=ROOT/'screen/TJC1060X570/design/workstation_v2/controls_manifest.json'
    hmi=ROOT/'screen/TJC1060X570/generated/instrument_workstation_v2/instrument_workstation_v2.HMI'
    spec=json.loads(manifest.read_text(encoding='utf-8'))
    widgets={x['objname']:x for x in spec['widgets']}
    assert spec['model']=='TJC1060X570_011'
    assert all(50<=x['fields']['tim']<=65535 for x in spec['widgets'] if x['type']=='timer')
    assert widgets['tmUi']['fields']['tim']==100 and widgets['tmHeart']['fields']['tim']==150
    assert all(f'rx{i}' in widgets for i in range(41))
    assert hmi.exists() and hmi.stat().st_size>0
    assert len(widgets)<255
    restore=widgets['tmRestore']['events']['codestimer-']
    locate=widgets['locate']['events']['codesdown-']
    assert any('tmRestore.en=0' in line for line in restore)
    assert 'dragTick.val=dragTick.val+scratch2.val' in locate
    sys.path.insert(0,str(ROOT/'scripts'))
    from verify_workstation import WorkstationModel
    model=WorkstationModel(spec);values=model.values
    model.run('page0','codesloadend-')
    model.run('tmRestore');assert values['eeSlot.val']==1 and values['tmRestore.en']==1,'restore must process only one slot per timer tick'
    for _ in range(47):model.run('tmRestore')
    assert values['eeSlot.val']==0 and values['tmRestore.en']==0
    assert model.packets[-1][2:4]==bytes([0x27,1]),'restore must acknowledge boot'
    values.update({'rx7.val':480,'tch0':512});model.run('locate','codesdown-');assert values['dragTick.val']==240,'short score seek'
    values.update({'rx7.val':1000123,'tch0':992});model.run('locate','codesdown-');assert values['dragTick.val']==1000123,'seek end boundary'
    for key in range(16):values[f'held{key}.val']=1
    model.run('home','codesup-');assert all(values[f'held{k}.val']==0 for k in range(16))
    model.packets.clear();values.update({'envPatch.val':2,'envA.val':16,'envD.val':12,'envS.val':2100,'envR.val':50})
    model.run('envApply','codesup-')
    packet_data={p[2]:p[3] for p in model.packets}
    value=sum(packet_data[0x70+i]<<(8*i) for i in range(4));aux=sum(packet_data[0x74+i]<<(8*i) for i in range(4))
    assert value==2+(16<<4)+(12<<16) and aux==2100+(50<<12) and model.packets[-1][2]==0x62
    assert values['envDirty.val']==2
    values.update({'view.val':9,'rx3.val':2,'rx14.val':16,'rx15.val':12,'rx16.val':2100,'rx17.val':50,'rx40.val':1})
    model.run('tmUi');assert values['envDirty.val']==0,'ADSR displayed only after FPGA readback'
    values.update({'view.val':8,'lastSnap.val':1,'rx40.val':2,'pendingSerial.val':9,'pendingOp.val':25,'pendingValue.val':37,'pendingAux.val':1,
                   'rx18.val':10,'rx20.val':24,'rx19.val':0,'rx36.val':37,'rx37.val':0,'rx38.val':1,'rx39.val':0,'hint.txt':'待确认'})
    model.run('tmUi');assert values['hint.txt']=='待确认','unrelated PC command must not confirm screen draft'
    values.update({'rx40.val':3,'rx20.val':25,'rx26.val':37,'part.val':1});model.run('tmUi')
    assert '已生效' in values['hint.txt'] and values['partVolume.val']==37
    values.update({'view.val':7,'rx31.val':50});model.run('playAdjust0','codesup-');assert values['pendingValue.val']==50
    values.update({'view.val':8,'partVolume.val':0});model.run('partAdjust0','codesup-');assert values['pendingValue.val']==0
    assert spec['full_gb2312']
    print(f'PASS V2 HMI source controls={len(spec["widgets"])} timers=50..1000ms rx=41 official TFT pending')
if __name__=='__main__':main()
