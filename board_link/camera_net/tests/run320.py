from pathlib import Path
import subprocess,json,struct,zlib,argparse
ap=argparse.ArgumentParser();ap.add_argument("--proc-hz",type=int,default=25000000);options=ap.parse_args()
R=Path(__file__).resolve().parents[1]
O=Path('C:/Users/21397/Desktop/bank/camera_net_20261019/sim320');O.mkdir(exist_ok=True)
(O/'result.json').write_text('{"status":"RUNNING"}')
def run(args,name,marker=None):
 p=subprocess.run([str(x) for x in args],cwd=O,capture_output=True,text=True)
 (O/(name+'.log')).write_text(p.stdout+p.stderr)
 if p.returncode or '** Error' in p.stdout or '** Fatal' in p.stdout or marker and marker not in p.stdout:raise RuntimeError((p.stdout+p.stderr)[-5000:])
run(['F:/win64/vlib.exe','work'],'vlib')
v=[p for p in (R/'vendor').glob('*.v') if p.name not in ['rgmii_interface.v','net_pll.v','ph1p_phy_pll_wrapper_d2616deaaa79.v','uiphyrst.v']]
run(['F:/win64/vlog.exe','-sv',*v,*[R/'rtl'/n for n in ['preview_analyzer.v','preview_capture.v','preview_sender.v','preview_receiver.v','network_result_bridge.v']],*[R/'tests'/n for n in ['tb_analyzer320.sv','tb_pair320.sv','tb_bridge320.sv','tb_capture320.sv','tb_receiver320.sv','tb_recovery320.sv','tb_red_guard320.sv']]],'vlog')
checks=[]
def sim(top,name,args=[],marker=None):
 if top in ['tb_analyzer320','tb_red_guard320','tb_pair320']:args=[f'-gPROC_HZ={options.proc_hz}',*args]
 run(['F:/win64/vsim.exe','-c','-onfinish','exit','work.'+top,*args,'-do','run -all; quit -f'],name,marker);checks.append(name);print(name,'PASS',flush=True)
for name,shape,red,col in [('rectangle',1,1,0xc4),('circle',3,1,0xc4),('triangle',4,1,0xc4),('blue_circle',3,0,0x17),('blank',0,0,0),('diamond',0,1,0xc4),('small_red',1,1,0xc4),('right_red',1,1,0xc4),('dim_red',1,1,0x60),('noisy_circle',3,1,0xc4),('warm_skin',1,0,0xac),('shadow_red',1,1,0x44),('muted_red',1,1,0x68),('pale_red',1,1,0x8d),('red_speck',0,0,0xc4)]:
 cx=280 if name=='right_red' else 160;cy=90;pix=[]
 for y in range(180):
  for x in range(320):
   xx=x-cx;yy=y-cy;inside=False
   if name in ['rectangle','right_red','dim_red','warm_skin','shadow_red','muted_red','pale_red']:inside=abs(xx)<=20 and abs(yy)<=16
   if name=='red_speck':inside=abs(xx)<=4 and abs(yy)<=4
   if name=='small_red':inside=abs(xx)<=6 and abs(yy)<=6
   if name in ['circle','blue_circle','noisy_circle']:inside=xx*xx+yy*yy<=42*42
   if name=='triangle':inside=-42<=yy<=42 and abs(xx)*84<=42*(yy+42)
   if name=='diamond':inside=abs(xx)+abs(yy)<=42
   if name=='noisy_circle' and ((x*37+y*17)%113==0):inside=False
   pix.append(col if inside else 0x92)
 path=O/(name+'.hex');path.write_text(''.join(f'{p:02x}\n' for p in pix))
 sim('tb_analyzer320',name,[f'+PIXELS={path.as_posix()}',f'+SHAPE={shape}',f'+RED={red}',f'+XC={cx}',f'+YC={cy}',f'+DIAG={1 if name=="warm_skin" else 2 if name=="red_speck" else 0}'],'ANALYZER_PASS')
sim('tb_red_guard320','red_guard',marker='RED_GUARD320_PASS')
sim('tb_bridge320','bridge',marker='BRIDGE320_PASS')
sim('tb_capture320','capture',marker='CAPTURE320_PASS')
sim('tb_receiver320','receiver',marker='RECEIVER_PASS')
sim('tb_recovery320','recovery',marker='RECOVERY_PASS')
sim('tb_pair320','pair',marker='PAIR_IMAGE_PASS')
def packets(name):
 out=[]
 for line in (O/name).read_text().splitlines():
  f=bytes.fromhex(line);assert f[:8]==b'\x55'*7+b'\xd5';eth=f[8:]
  assert zlib.crc32(eth[:-4])==int.from_bytes(eth[-4:],'little')
  if eth[12:14]!=b'\x08\x00':continue
  ip=eth[14:];assert sum(struct.unpack('!10H',ip[:20]))%65535==0
  if ip[9]==17:
   u=ip[20:];out.append(u[8:int.from_bytes(u[4:6],'big')])
 return out
a=packets('ph1_frames.hex');b=packets('eg_frames.hex');chunks=[]
for p in a:
 assert p[:4]==b'PHIM' and p[14]==2
 if len(p)==256:
  ch=int.from_bytes(p[8:10],'big');assert int.from_bytes(p[10:12],'big')==240
  assert p[16:]==bytes((((ch*240+i)&255)^0x5a) for i in range(240));chunks.append(ch)
assert chunks==[0,0]+list(range(1,240))
assert all(len(p)==48 and p[:4]==b'PACK' for p in b)
(O/'result.json').write_text(json.dumps({'status':'PASS','width':320,'height':180,'analysis_pixels':57600,'analysis_clock_hz':options.proc_hz,'checks':checks,'udp_fcs_and_every_pixel':'PASS'},indent=2))
print('ALL_320_TESTS_PASS')
