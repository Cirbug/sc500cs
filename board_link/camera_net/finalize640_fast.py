"""Publish a tested performance variant separately from the validated old pair."""
from pathlib import Path
import hashlib,json,re,shutil,datetime,zipfile,xml.etree.ElementTree as ET
R=Path(__file__).resolve().parent
B=Path('C:/Users/21397/Desktop/bank/camera_net_20261020_fast')
O=R/'output640_fast'
sim=json.loads((B/'sim640/result.json').read_text())
native=json.loads((B/'native/result.json').read_text())
assert sim['status']==native['status']=='PASS'
files={Path(f.get('Path','')).name:Path(f.get('Path','')) for f in ET.parse(R/'eg_image_sink640_fast.al').findall('.//File')}
for n in ['preview_analyzer.v','packed_tag_ram640.v','preview_receiver.v']:
 assert files[n]==R/'v640_fast/rtl'/n
t=(B/'eg_640/final_timing.rpt').read_text()
sw,st=map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns',t).groups())
hw,ht=map(float,re.search(r'HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',t).groups())
assert sw>=0 and hw>=0 and st==ht==0
assert 'EG_IMAGE_SINK_BUILD_COMPLETE' in (B/'build_eg.log').read_text(encoding='utf-8-sig')
def normalized(s):
 v=int(re.search(r'result=([0-9a-fA-F]+)',s).group(1),16)
 if v&(1<<189):v&=~(((1<<64)-1)<<16)
 return v
same=[]
for n in sim['checks']:
 fast=(B/'sim640'/(n+'.log')).read_text()
 if 'ANALYZER_PASS' in fast:
  assert normalized(fast)==normalized((R/'output640'/(n+'.log')).read_text()),n
  same.append(n)
O.mkdir(exist_ok=True)
shutil.copy2(R/'output640/camera_network.bit',O/'camera_network.bit')
shutil.copy2(B/'eg_640/eg_image_sink.bit',O/'eg_image_sink.bit')
shutil.copytree(R/'output640/firmware',O/'firmware',dirs_exist_ok=True)
for name in ['final.area','final_timing.rpt']:
 shutil.copy2(B/'eg_640'/name,O/('EG4D20_'+name))
 shutil.copy2(R/'output640'/('PH1P35_'+name),O/('PH1P35_'+name))
for n in sim['checks']:shutil.copy2(B/'sim640'/(n+'.log'),O/(n+'.log'))
for p in (B/'native').glob('*.log'):shutil.copy2(p,O/('native_'+p.name))
shutil.copy2(B/'sim640/result.json',O/'simulation.json')
shutil.copy2(B/'native/result.json',O/'native_validation.json')
report={
 'status':'BUILD_AND_SIMULATION_PASS_HARDWARE_PENDING',
 'generated':datetime.datetime.now().isoformat(timespec='seconds'),
 'image':{'width':640,'height':360,'format':'RGB565','secondary_downsampling':False,'clock_hz':40000000},
 'changes':['row epoch tags instead of clearing 360 rows for every component',
            'synchronous RAM address prefetch eliminates scan and neighbour wait cycles',
            'queue read removes redundant wait cycle'],
 'preserved':['classification thresholds','eight-neighbour connectivity','all 230400 pixels','protocol v3','red acquisition/expiry rules'],
 'timing':{'setup_wns_ns':sw,'hold_wns_ns':hw,'coverage':re.search(r'STA coverage\s*:\s*(\S+)',t)[1]},
 'reference_result_comparison':same,
 'same_scene_native_simulation':native,
 'hardware':{'main640_reloaded':True,'auto_tracking_enabled':False,'slave_downloaded':False,
             'reason':'Windows reports USB driver code 52 for VID_0547 PID_1002; download failed',
             'fps':None,'flash_changed':False},
 'binaries':{n:hashlib.sha256((O/n).read_bytes()).hexdigest() for n in ['camera_network.bit','eg_image_sink.bit']}
}
(O/'validation.json').write_text(json.dumps(report,indent=2))
sources=list((R/'v640_fast').rglob('*.v'))+list((R/'v640_fast').rglob('*.sv'))+list((R/'v640_fast').rglob('*.py'))
sources += [R/n for n in ['eg_image_sink640_fast.al','build_eg640_fast.tcl','finalize640_fast.py','eg_image_sink_perf40.v','rtl/eg_recognition_pll40.v','timing_eg_perf40.sdc']]
(O/'source_sha256.json').write_text(json.dumps({p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},indent=2))
with zipfile.ZipFile(O/'source_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sources:z.write(p,p.relative_to(R).as_posix())
print(json.dumps(report,indent=2))
