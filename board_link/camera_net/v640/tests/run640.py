from pathlib import Path
import subprocess,json,struct,zlib
R=Path(__file__).resolve().parents[2];V=R/'v640'
O=Path('C:/Users/21397/Desktop/bank/camera_net_20261019/sim640');O.mkdir(exist_ok=True)
(O/'result.json').write_text('{"status":"RUNNING"}')
def run(args,name,marker=None):
 p=subprocess.run([str(x) for x in args],cwd=O,capture_output=True,text=True)
 (O/(name+'.log')).write_text(p.stdout+p.stderr)
 if p.returncode or '** Error' in p.stdout or '** Fatal' in p.stdout or marker and marker not in p.stdout:raise RuntimeError((p.stdout+p.stderr)[-4500:])
run(['F:/win64/vlib.exe','work'],'vlib')
vendor=[p for p in (R/'vendor').glob('*.v') if p.name not in ['rgmii_interface.v','net_pll.v','ph1p_phy_pll_wrapper_d2616deaaa79.v','uiphyrst.v']]
rtl=[V/'rtl'/n for n in ['packed_tag_ram640.v','preview_analyzer.v','preview_capture.v','preview_sender.v','preview_receiver.v','network_result_bridge.v']]
run(['F:/win64/vlog.exe','-sv','+define+MODEL_SIM',*vendor,*rtl,*sorted((V/'tests').glob('tb_*.sv'))],'vlog')
checks=[]
def sim(top,name,args=[],marker=None):
 if top in ['tb_analyzer640','tb_pair640']:args=['-gPROC_HZ=40000000',*args]
 run(['F:/win64/vsim.exe','-c','-onfinish','exit','work.'+top,*args,'-do','run -all; quit -f'],name,marker);checks.append(name);print(name,'PASS',flush=True)
def col(r,g,b):return ((r>>3)<<11)|((g>>2)<<5)|(b>>3)
for name,shape,red,c in [('rectangle',1,1,col(208,48,32)),('circle',3,1,col(208,48,32)),('triangle',4,1,col(208,48,32)),('blue_circle',3,0,col(16,144,224)),('blank',0,0,0),('diamond',0,1,col(208,48,32)),('small_red',1,1,col(208,48,32)),('right_red',1,1,col(208,48,32)),('warm_skin',1,0,col(176,112,32)),('shadow_red',1,1,col(80,48,32)),('pale_red',1,1,col(136,104,88)),('large_area',1,1,col(208,48,32))]:
 cx=570 if name=='right_red' else 320;cy=280 if name=='right_red' else 180;pix=[]
 for y in range(360):
  for x in range(640):
   xx=x-cx;yy=y-cy;inside=False
   if name in ['rectangle','right_red','warm_skin','shadow_red','pale_red']:inside=abs(xx)<=40 and abs(yy)<=32
   if name=='small_red':inside=abs(xx)<=12 and abs(yy)<=12
   if name in ['circle','blue_circle']:inside=xx*xx+yy*yy<=84*84
   if name=='triangle':inside=-84<=yy<=84 and abs(xx)*168<=84*(yy+84)
   if name=='diamond':inside=abs(xx)+abs(yy)<=84
   if name=='large_area':inside=abs(xx)<=200 and abs(yy)<=100
   pix.append(c if inside else col(144,144,160))
 path=O/(name+'.hex');path.write_text(''.join(f'{p:04x}\n' for p in pix))
 sim('tb_analyzer640',name,[f'+PIXELS={path.as_posix()}',f'+SHAPE={shape}',f'+RED={red}',f'+XC={cx}',f'+YC={cy}'],'ANALYZER_PASS')
sim('tb_packed_ram640','packed_ram',marker='PACKED_RAM640_PASS')
sim('tb_guard640','guard',marker='GUARD640_PASS')
sim('tb_bridge640','bridge',marker='BRIDGE640_PASS')
sim('tb_capture640','capture',marker='CAPTURE640_PASS')
sim('tb_receiver640','receiver',marker='RECEIVER_PASS')
sim('tb_recovery640','recovery',marker='RECOVERY_PASS')
sim('tb_pair640','pair',marker='PAIR_IMAGE_PASS')
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
 assert p[:4]==b'PHIM' and p[14]==3
 if len(p)==496:
  ch=int.from_bytes(p[8:10],'big');assert int.from_bytes(p[10:12],'big')==960
  expected=b''.join(struct.pack('!H',0x8410|(((k*13)^(k>>8)^(k>>16))&0x18e3)) for k in range(ch*240,(ch+1)*240))
  assert p[16:]==expected,('pixel stream mismatch',ch);chunks.append(ch)
assert chunks==[0,0]+list(range(1,960))
assert all(len(p)==48 and p[:4]==b'PACK' and p[14]==3 for p in b)
(O/'result.json').write_text(json.dumps({'status':'PASS','width':640,'height':360,'format':'RGB565','analysis_pixels':230400,'analysis_clock_hz':40000000,'checks':checks,'udp_fcs_and_every_pixel':'PASS'},indent=2))
print('ALL_640_TESTS_PASS')
