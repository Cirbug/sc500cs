"""Publish only a matched, simulated, timing-clean pair of SRAM images."""
from pathlib import Path
import re,json,hashlib,shutil,datetime,zipfile
ROOT=Path(__file__).resolve().parent
BANK=Path(r'C:\Users\21397\Desktop\bank\camera_net_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
sim=json.loads((BANK/'sim/result.json').read_text())
required={'rectangle','circle','triangle','blue_circle','blank','diamond','BRIDGE_PASS','CAPTURE_PASS','RECEIVER_PASS','RECOVERY_PASS','LOGO_PASS','recognition result return'}
assert sim['status']=='PASS' and required<=set(sim['checks']),'Incomplete simulation'
outputs={}
for board,folder,bit,logname,marker in [
 ('PH1P35','fpga_recognition','camera_network.bit','camera_net_recognition_build.log','CAMERA_NET_BUILD_COMPLETE'),
 ('EG4D20','eg_recognition','eg_image_sink.bit','camera_net_eg_recognition_build.log','EG_IMAGE_SINK_BUILD_COMPLETE')]:
    build=BANK/folder;timing=(build/'final_timing.rpt').read_text()
    sw,st=map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns',timing).groups())
    hw,ht=map(float,re.search(r'HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing).groups())
    assert sw>=0 and hw>=0 and st==0 and ht==0,(board,sw,st,hw,ht)
    log=(BANK.parent/logname).read_text(encoding='utf-8-sig',errors='replace')
    assert marker in log and ' ERROR:' not in log,board+' build incomplete'
    p=build/bit;assert p.exists() and p.stat().st_mtime>=(build/'final_timing.rpt').stat().st_mtime
    outputs[board]={'file':bit,'sha256':sha(p),'setup_wns_ns':sw,'hold_wns_ns':hw,
        'sta_coverage':re.search(r'STA coverage\s*:\s*(\S+)',timing)[1]}
# Verify top still matches the main source from which prepare.py generated it.
baseline=json.loads((ROOT/'baseline.json').read_text())
assert baseline['main_sha256']==sha(ROOT.parents[1]/'user_source/hdl_source/design_top_wrapper.v'),'Main changed; rerun prepare/build'
# No duplicate physical pins after removing the two legacy conflicting ports.
adc=(ROOT/'pin_net.adc').read_text(encoding='utf-8-sig')
locations=re.findall(r'LOCATION\s*=\s*(\w+)',adc)
assert len(locations)==len(set(locations)),'Duplicate pin assignment'
assert 'O_screen_pwm' not in adc and 'I_rst_n' not in adc
out=ROOT/'output';out.mkdir(exist_ok=True)
for board,folder in [('PH1P35','fpga_recognition'),('EG4D20','eg_recognition')]:
    shutil.copy2(BANK/folder/outputs[board]['file'],out/outputs[board]['file'])
    for name in ['final.area','final_timing.rpt']:
        shutil.copy2(BANK/folder/name,out/(board+'_'+name))
shutil.copy2(BANK/'sim/result.json',out/'simulation.json')
for name in ['tb_bridge','tb_capture','tb_logo','tb_receiver','tb_recovery','rectangle','circle','triangle','blue_circle','blank','diamond']:
    shutil.copy2(BANK/'sim'/(name+'.log'),out/(name+'.log'))
functional=[p for folder in [ROOT/'rtl',ROOT/'vendor'] for p in folder.glob('*.v')]
functional+=[ROOT/n for n in ['design_top_wrapper_net.v','anlogic_logo_rom_trim.v','red_target_tracker_eg.v','eg_image_sink.v','pin_net.adc','timing_net.sdc','timing_eg.sdc']]
manifest={str(p.relative_to(ROOT)):sha(p) for p in functional}
(out/'source_sha256.json').write_text(json.dumps(manifest,indent=2))
report={'status':'BUILD_AND_SIMULATION_PASS','generated':datetime.datetime.now().isoformat(timespec='seconds'),
 'mode':'PH1 camera + HDMI; EG red tracking and rectangle/circle/triangle recognition; 40-byte replies',
 'image':{'width':160,'height':90,'format':'RGB332','interval_seconds':1},
 'boards':outputs,'simulation':sim,'pin_check':'PASS','main_source_unchanged':True,
 'hardware_validation':'NOT_YET_TESTED_WITH_THIS_INTEGRATED_PAIR',
 'previous_hardware_pass':'Old standalone 64-byte echo only; not image recognition evidence'}
(out/'validation.json').write_text(json.dumps(report,indent=2))
with zipfile.ZipFile(out/'source_snapshot.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for p in ROOT.rglob('*'):
        if p.is_file() and not any(part in ['output','__pycache__'] or part.endswith('_Runs') for part in p.relative_to(ROOT).parts):
            archive.write(p,'camera_net/'+p.relative_to(ROOT).as_posix())
    # Preserve the camera baseline needed by the generated project after recovery.
    for p in (ROOT.parents[1]/'user_source').rglob('*'):
        if p.is_file():archive.write(p,'baseline/user_source/'+p.relative_to(ROOT.parents[1]/'user_source').as_posix())
    for p in (ROOT.parents[1]/'td_project/al_ip').rglob('*'):
        if p.is_file():archive.write(p,'baseline/td_project/al_ip/'+p.relative_to(ROOT.parents[1]/'td_project/al_ip').as_posix())
    for name in ['camera_to_dsi_display.al','camera_to_dsi_display.sdc']:
        archive.write(ROOT.parents[1]/'td_project'/name,'baseline/td_project/'+name)
shutil.copy2(out/'source_snapshot.zip',BANK/'source_snapshot.zip')
print(json.dumps(report,ensure_ascii=False))
