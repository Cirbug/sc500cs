"""Read the existing REC1 DDR snapshot mailbox without writing SD media."""
import socket,time,json,argparse,datetime
from pathlib import Path
import struct,zlib
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--reuse',action='store_true');p.add_argument('--capture-only',action='store_true');a=p.parse_args();out=Path(a.out);out.mkdir(exist_ok=True)
s=socket.create_connection(('127.0.0.1',6666),5);s.settimeout(45)
def cmd(c):
 s.sendall(c.encode()+b'\x1a');b=b''
 while not b.endswith(b'\x1a'):
  t=s.recv(65536)
  if not t:raise RuntimeError('OpenOCD disconnected')
  b+=t
 return b[:-1].decode(errors='replace').strip()
def words(x):return [int(v,0) for v in x.split()]
previous=cmd('riscv0.cpu curstate')
try:
 cmd('halt')
 assert words(cmd('read_memory 0x70001000 32 1'))==[0x52454331]
 state=words(cmd('read_memory 0x70001004 32 1'))[0]
 if state&1:raise RuntimeError('Snapshot already busy; do not interrupt it')
 if not a.reuse:cmd('mww 0x70001004 1');time.sleep(.15)
 state=words(cmd('read_memory 0x70001004 32 1'))[0]
 assert state==2,('capture status',state,cmd('read_memory 0x70001010 32 4'))
 if not a.reuse:
  metadata={'captured':datetime.datetime.now().isoformat(timespec='milliseconds'),'status':state,'net_words':words(cmd('read_memory 0x70004000 32 17'))}
  (out/'capture.json').write_text(json.dumps(metadata,indent=2))
 print('SNAPSHOT_READY',flush=True)
finally:
 if previous=='running':cmd('resume')
if a.capture_only:
 s.close();raise SystemExit(0)
scene=[(x,y) for y in range(0,360,16) for x in range(0,640,16)]
roi=[(x,y) for y in range(210,294,8) for x in range(208,304,8)]
indices=sorted(set((y*640+x)//4 for x,y in scene+roi));data={}
for st in range(0,len(indices),80):
 batch=indices[st:st+80];previous=cmd('riscv0.cpu curstate')
 try:
  cmd('halt')
  tcl='set snapshot_out {}; foreach snapshot_i {'+' '.join(map(str,batch))+'''} {
   mww 0x70001020 $snapshot_i
   set snapshot_poll 0
   while {[lindex [read_memory 0x70001024 32 1] 0] & 1} {
    incr snapshot_poll
    if {$snapshot_poll>100} {error "snapshot read timeout"}
   }
   foreach snapshot_w [read_memory 0x70001030 32 4] {lappend snapshot_out $snapshot_w}
  }; set snapshot_out'''
  vals=words(cmd(tcl));assert len(vals)==4*len(batch)
  for j,i in enumerate(batch):data[i]=vals[j*4:j*4+4]
 finally:
  if previous=='running':cmd('resume')
 (out/'partial.json').write_text(json.dumps(data))
 if st%160==0:print('READ',min(st+80,len(indices)),'/',len(indices),flush=True)
s.close()
def rgb(x,y):
 v=data[(y*640+x)//4][x%4];return ((v>>16)&255,(v>>8)&255,v&255)
def png(path,w,h,values,scale):
 def chunk(t,b):return struct.pack('!I',len(b))+t+b+struct.pack('!I',zlib.crc32(t+b))
 rows=[]
 for y in range(h):
  row=b'\0'+b''.join(bytes(c)*scale for c in values[y*w:(y+1)*w])
  rows.extend([row]*scale)
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!IIBBBBB',w*scale,h*scale,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b''))
png(out/'scene.png',40,23,[rgb(x,y) for x,y in scene],16)
png(out/'object_roi.png',12,11,[rgb(x,y) for x,y in roi],24)
(out/'pixels.json').write_text(json.dumps({'snapshot_dimensions':[640,360],'roi':[208,210,304,294],'data':data}))
print('SNAPSHOT_READ_COMPLETE',flush=True)
