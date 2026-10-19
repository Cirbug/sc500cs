"""Read network diagnostics over OpenOCD; resume after a brief halt."""
import argparse, datetime, json, re, socket, time
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--samples',type=int,default=6)
p.add_argument('--interval',type=float,default=1)
p.add_argument('--out',default='')
a=p.parse_args()
names=['magic','sent','acked','frames','timeouts','bad','remote_frames','remote_errors',
       'state','dimensions','flags_type','red_min','shape_min','areas_width','red_center','red_max','shape_max']
records=[]
with socket.create_connection(('127.0.0.1',6666),5) as s:
 s.settimeout(8)
 def cmd(c):
  s.sendall(c.encode()+b'\x1a');b=b''
  while not b.endswith(b'\x1a'):
   t=s.recv(65536)
   if not t:raise RuntimeError('OpenOCD disconnected')
   b+=t
  return b[:-1].decode(errors='replace')
 for n in range(a.samples):
  if n:time.sleep(a.interval)
  previous=cmd('riscv0.cpu curstate').strip()
  try:
   cmd('halt')
   raw=cmd('capture {mdw 0x70004000 17}')
  finally:
   if previous=='running':cmd('resume')
  words=[]
  for line in raw.splitlines():
   m=re.search(r'0x[0-9a-fA-F]+:\s*(.*)',line)
   if m:words.extend(int(x,16) for x in m[1].split() if re.fullmatch('[0-9a-fA-F]{8}',x))
  if len(words)!=17:raise RuntimeError(raw)
  r=dict(zip(names,words));r['timestamp']=datetime.datetime.now().isoformat(timespec='milliseconds')
  r['monotonic']=time.monotonic();r['red_valid']=bool(words[10]&0x01000000)
  r['shape_valid']=bool(words[10]&0x02000000);r['failure']=bool(words[10]&0x80000000)
  r['shape_id']=(words[10]>>16)&255
  r['red_xy']=[words[14]>>16,words[14]&65535]
  records.append(r);print(json.dumps(r),flush=True)
 if len(records)>1:
  dt=records[-1]['monotonic']-records[0]['monotonic']
  summary={k:(records[-1][k]-records[0][k])&0xffffffff for k in ['frames','sent','acked','timeouts','bad','remote_frames','remote_errors']}
  summary.update(seconds=dt,fps=summary['frames']/dt)
  print('SUMMARY '+json.dumps(summary),flush=True)
 else:summary={}
if a.out:Path(a.out).write_text(json.dumps(dict(samples=records,summary=summary),indent=2))
