from pathlib import Path
import subprocess,zlib,struct,json
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(r'C:\Users\21397\Desktop\bank\camera_net_20261019\sim')
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'result.json').write_text(json.dumps({'status':'RUNNING'}))
def run(args,marker=None):
    p=subprocess.run([str(x) for x in args],cwd=OUT,capture_output=True,text=True)
    (OUT/(Path(str(args[0])).stem+'.log')).write_text(p.stdout+p.stderr)
    if p.returncode or '** Error' in p.stdout or '** Fatal' in p.stdout or marker and marker not in p.stdout:
        raise RuntimeError((p.stdout+p.stderr)[-6000:])
run([r'F:\win64\vlib.exe','work'])
files=[p for p in (ROOT/'vendor').glob('*.v') if p.name not in ['rgmii_interface.v','net_pll.v','ph1p_phy_pll_wrapper_d2616deaaa79.v','uiphyrst.v']]
files += [ROOT/'red_target_tracker_eg.v',ROOT/'rtl/preview_analyzer.v',ROOT/'rtl/preview_sender.v',ROOT/'rtl/preview_receiver.v',ROOT/'tests/tb_pair.sv']
run([r'F:\win64\vlog.exe','-sv','-work','work',*files])
run([r'F:\win64\vsim.exe','-c','-onfinish','exit','work.tb_pair','-do','run -all; quit -f'],'PAIR_IMAGE_PASS')
def packets(name):
    result=[]
    for line in (OUT/name).read_text().splitlines():
        f=bytes.fromhex(line);assert f[:8]==b'\x55'*7+b'\xd5'
        eth=f[8:];assert zlib.crc32(eth[:-4])==int.from_bytes(eth[-4:],'little')
        if eth[12:14]!=b'\x08\x00':continue
        ip=eth[14:];assert sum(struct.unpack('!10H',ip[:20]))%65535==65535%65535
        if ip[9]!=17:continue
        udp=ip[20:];length=int.from_bytes(udp[4:6],'big')
        result.append((ip[12:16],ip[16:20],struct.unpack('!HH',udp[:4]),udp[8:length]))
    return result
a=packets('ph1_frames.hex');b=packets('eg_frames.hex')
images=[]
for src,dst,ports,p in a:
    assert src==bytes([192,168,50,1]) and dst==bytes([192,168,50,2]) and ports==(6001,6002)
    assert p[:4]==b'PHIM'
    if len(p)==256:
        seq,chunk,total,size,fmt,typ=struct.unpack('!IHHHBB',p[4:16])
        assert (seq,total,size,fmt,typ)==(0,60,240,1,1)
        assert p[16:]==bytes(((chunk*240+i)&255)^0x5a for i in range(240))
        images.append(chunk)
    else:assert len(p)==16 and p[15]==0
assert images==[0,0]+list(range(1,60)),images
for src,dst,ports,p in b:
    assert ports==(6002,6001) and len(p)==40 and p[:4]==b'PACK' and p[15]==0
assert b[-1][3][-2:]==bytes([160,90])
report={'status':'PASS','image_pixels':14400,'forward_udp':len(a),'return_udp':len(b),'return_payload_bytes':40,'retries':1,'complete_frames':1,'checks':['actual two UDP/MAC stacks','FCS every frame','IP checksum','ports and addresses','every image byte','lost ACK and duplicate frame suppression','recognition result return','heartbeat without video']}
print(json.dumps(report))
logo=(ROOT/'anlogic_logo_rom_trim.v').read_text().replace('module anlogic_logo_rom','module anlogic_logo_rom_trim')
(OUT/'logo_trim_test.v').write_text(logo)
extra=[ROOT/'rtl/preview_capture.v',ROOT/'tests/tb_capture.sv',ROOT/'tests/tb_recovery.sv',
 ROOT/'tests/tb_logo.sv',ROOT/'tests/tb_receiver.sv',ROOT/'tests/tb_analyzer.sv',ROOT/'tests/tb_bridge.sv',ROOT/'rtl/network_result_bridge.v',ROOT.parents[1]/'user_source/hdl_source/anlogic_logo_rom.v',OUT/'logo_trim_test.v']
run([r'F:\win64\vlog.exe','-sv','-work','work',*extra])
for top,marker in [('tb_logo','LOGO_PASS'),('tb_recovery','RECOVERY_PASS'),('tb_receiver','RECEIVER_PASS'),('tb_capture','CAPTURE_PASS'),('tb_bridge','BRIDGE_PASS')]:
    run([r'F:\win64\vsim.exe','-c','-onfinish','exit','work.'+top,'-do','run -all; quit -f'],marker)
    shutil_log=OUT/(top+'.log');shutil_log.write_text((OUT/'vsim.log').read_text())
    report['checks'].append(marker)
for name,expected,red,col in [('rectangle',1,1,0xc4),('circle',3,1,0xc4),('triangle',4,1,0xc4),
 ('blue_circle',3,0,0x17),('blank',0,0,0),('diamond',0,1,0xc4)]:
    pixels=[]
    for y in range(90):
        for x in range(160):
            xx=x-80;yy=y-44;inside=False
            if name=='rectangle':inside=abs(xx)<=30 and abs(yy)<=22
            if name in ['circle','blue_circle']:inside=xx*xx+yy*yy<=28*28
            if name=='triangle':inside=-28<=yy<=28 and abs(xx)*56<=28*(yy+28)
            if name=='diamond':inside=abs(xx)+abs(yy)<=28
            pixels.append(col if inside else 0x92)
    path=OUT/(name+'.hex');path.write_text(''.join(f'{p:02x}\n' for p in pixels))
    run([r'F:\win64\vsim.exe','-c','-onfinish','exit','work.tb_analyzer',f'+PIXELS={path.as_posix()}',f'+SHAPE={expected}',f'+RED={red}','-do','run -all; quit -f'],'ANALYZER_PASS')
    (OUT/(name+'.log')).write_text((OUT/'vsim.log').read_text())
    report['checks'].append(name)
(OUT/'result.json').write_text(json.dumps(report,indent=2))
print('ALL_TESTS_PASS')
