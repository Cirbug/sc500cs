from pathlib import Path
import subprocess,json,re
R=Path(__file__).resolve().parents[2]
V=R/'v640_fast'
O=Path('C:/Users/21397/Desktop/bank/camera_net_20261020_fast/native')
O.mkdir(parents=True,exist_ok=True)
def run(args,name,marker=None):
 p=subprocess.run([str(x) for x in args],cwd=O,capture_output=True,text=True)
 s=p.stdout+p.stderr;(O/(name+'.log')).write_text(s)
 if p.returncode or '** Error' in s or '** Fatal' in s or (marker and marker not in s):
  raise RuntimeError(s[-3500:])
 print(name,'PASS',flush=True)
 return s
ref=(R/'v640/shape_features640.v').read_text().replace('SHAPE_COMPONENT_FEATURES_V','SHAPE_COMPONENT_FEATURES_REFERENCE_V').replace('module shape_component_features','module shape_component_features_reference')
(O/'features_reference.v').write_text(ref)
run(['F:/win64/vlib.exe','work'],'vlib')
run(['F:/win64/vlog.exe','-sv','D:/New Folder/sim_release/eg4/eg_phy_bram32k.v',
 'D:/New Folder/sim_release/eg4/eg_phy_glbl.v',V/'rtl/packed_tag_ram640.v',
 V/'rtl/preview_analyzer.v',O/'features_reference.v',
 *[V/'tests'/f for f in ['tb_epoch640.sv','tb_packed_ram640.sv','tb_guard640.sv','tb_scene640.sv']]],'compile')
for top,marker in [('tb_epoch640','EPOCH640_PASS'),('tb_packed_ram640','PACKED_RAM640_PASS'),('tb_guard640','GUARD640_PASS')]:
 run(['F:/win64/vsim.exe','-c','-onfinish','exit','work.'+top,'work.glbl','-do','run -all; quit -f'],top,marker)
s=run(['F:/win64/vsim.exe','-c','-onfinish','exit','work.tb_scene640','work.glbl',
 '-gPROC_HZ=40000000','+PIXELS=C:/Users/21397/Desktop/bank/camera_net_20261019/sim640/real_scene.hex',
 '+SHAPE=-1','+RED=0','-do','run -all; quit -f'],'real_scene','ANALYZER_PASS')
old=(R/'output640/real_scene_primitive.log').read_text()
def normalized(s):
 v=int(re.search(r'result=([0-9a-fA-F]+)',s).group(1),16)
 if v & (1<<189):v &= ~(((1<<64)-1)<<16)
 return v
assert normalized(s)==normalized(old),'Real scene classification changed'
cycles=int(re.search(r'ANALYSIS_CYCLES=(\d+)',s).group(1))
(O/'result.json').write_text(json.dumps({'status':'PASS','native_ram':True,'reference_cycles':4842814,'fast_cycles':cycles,'speedup':4842814/cycles,'same_scene_result':'identical except cycle telemetry'},indent=2))
print('NATIVE_FAST_PASS',cycles,flush=True)
