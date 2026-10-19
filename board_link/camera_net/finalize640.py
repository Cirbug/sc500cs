"""Publish only the matched, timed and simulated 640x360 RGB565 pair."""
from pathlib import Path
import json,re,hashlib,shutil,datetime,zipfile,xml.etree.ElementTree as ET
R=Path(__file__).resolve().parent;B=Path('C:/Users/21397/Desktop/bank/camera_net_20261019');O=R/'output640'
main_files={Path(f.get('Path','')).name:Path(f.get('Path','')) for f in ET.parse(R/'camera_network640.al').findall('.//File')}
for n in ['camera_network.v','preview_sender.v','preview_capture.v','network_result_bridge.v']:
 assert main_files[n]==R/'v640/rtl'/n,('stale main source reference',n,main_files[n])
main_log=(B.parent/'camera_net_main640_build.log').read_text(encoding='utf-8-sig',errors='replace')
assert 'elaborate module preview_capture in v640/rtl/preview_capture.v' in main_log
assert 'elaborate module preview_sender in v640/rtl/preview_sender.v' in main_log
sim=json.loads((B/'sim640/result.json').read_text());assert sim['status']=='PASS' and sim['analysis_pixels']==230400
assert 'PACKED_RAM640_PASS' in (B/'ram640/primitive1.log').read_text()
assert 'GUARD640_PASS' in (B/'ram640/guard1.log').read_text()
assert 'RECEIVER_PASS' in (B/'receiver640/step2.log').read_text()
assert 'ANALYZER_PASS red=0' in (B/'ram640/scene1.log').read_text()
boards={}
for board,folder,bit,log,marker in [('PH1P35','fpga_640','camera_network.bit','camera_net_main640_build.log','CAMERA_NET_BUILD_COMPLETE'),('EG4D20','eg_640','eg_image_sink.bit','camera_net_eg640_build.log','EG_IMAGE_SINK_BUILD_COMPLETE')]:
 p=B/folder;t=(p/'final_timing.rpt').read_text();sw,st=map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns',t).groups());hw,ht=map(float,re.search(r'HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',t).groups())
 assert sw>=0 and hw>=0 and st==ht==0,(board,sw,hw)
 assert marker in (B.parent/log).read_text(encoding='utf-8-sig',errors='replace')
 assert (p/bit).stat().st_mtime>=(p/'final_timing.rpt').stat().st_mtime
 boards[board]={'file':bit,'sha256':hashlib.sha256((p/bit).read_bytes()).hexdigest(),'setup_wns_ns':sw,'hold_wns_ns':hw,'sta_coverage':re.search(r'STA coverage\s*:\s*(\S+)',t)[1]}
O.mkdir(exist_ok=True)
for board,folder in [('PH1P35','fpga_640'),('EG4D20','eg_640')]:
 shutil.copy2(B/folder/boards[board]['file'],O/boards[board]['file'])
 for n in ['final.area','final_timing.rpt']:shutil.copy2(B/folder/n,O/(board+'_'+n))
shutil.copy2(B/'sim640/result.json',O/'simulation.json')
for n in sim['checks']:shutil.copy2(B/'sim640'/(n+'.log'),O/(n+'.log'))
for folder,n,dest in [('ram640','primitive1.log','packed_ram_primitive.log'),('ram640','guard1.log','guard_primitive.log'),('ram640','scene1.log','real_scene_primitive.log'),('receiver640','step2.log','receiver_pixel_scoreboard.log')]:shutil.copy2(B/folder/n,O/dest)
files=list((R/'v640').rglob('*.v'))+list((R/'vendor').glob('*.v'))+[R/n for n in ['camera_network640.al','eg_image_sink640.al','build_main640.tcl','build_eg640.tcl','eg_image_sink_perf40.v','rtl/eg_recognition_pll40.v','timing_eg_perf40.sdc','timing_net.sdc','pin_net.adc']]
(O/'source_sha256.json').write_text(json.dumps({p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
report={'status':'BUILD_AND_SIMULATION_PASS','generated':datetime.datetime.now().isoformat(timespec='seconds'),'image':{'width':640,'height':360,'format':'RGB565','bytes_per_frame':460800,'analysis_pixels':230400,'secondary_downsampling':False,'analysis_clock_hz':40000000},'protocol':{'version':3,'chunks':960,'pixels_per_chunk':240,'payload_bytes_per_chunk':480,'udp_payload_bytes':496,'ack_bytes':48,'result_bytes':24,'wire_pixel_order':'RGB565 high byte first'},'boards':boards,'simulation':sim,'extra_validation':['native EG_PHY_BRAM32K bank/adjacent-pixel test','native RAM red acquisition/miss/expiry/border test','every received RGB565 pixel/address checked'],'hardware_validation':'PENDING','limitations':['No video compression added','Red/skin discrimination requires real-target validation','Auto tracking remains disabled during validation','SRAM downloads are volatile; Flash unchanged']}
(O/'validation.json').write_text(json.dumps(report,indent=2))
with zipfile.ZipFile(O/'source_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in R.rglob('*'):
  if p.is_file() and not any(t.startswith('output') or t.endswith('_Runs') or t=='__pycache__' for t in p.relative_to(R).parts):z.write(p,'camera_net/'+p.relative_to(R).as_posix())
firm=O/'firmware';firm.mkdir(exist_ok=True)
for n in ['build/anlu_app.elf','camera_net_ram.cfg','ph1p35_mcu_ir8.cfg','anlu_app_camera_net.launch']:shutil.copy2(R.parents[1]/'FDwork/anlu_app'/n,firm/Path(n).name)
print(json.dumps(report))
