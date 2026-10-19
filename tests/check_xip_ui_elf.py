"""Offline XIP address/section/startup checks; does not program hardware."""
import argparse, re, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('elf',type=Path)
p.add_argument('--tools',type=Path,default=Path('F:/AnlogicFpga/FD_2026.1/toolchain/gcc/riscv/ph1p35/bin'))
a=p.parse_args()
def tool(name,*args):
    return subprocess.check_output([str(a.tools/('riscv64-unknown-elf-'+name+'.exe')),*args,str(a.elf)],text=True)
sections={}
for m in re.finditer(r'^\s*\d+\s+(\.\S+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s+([0-9a-f]+)',tool('objdump','-h'),re.M):
    sections[m[1]]=tuple(int(m[i],16) for i in (2,3,4))
for n in ['.init','.text']:
    size,vma,lma=sections[n]
    assert vma==lma and 0x20e00000<=vma<vma+size<=0x21000000,(n,sections[n])
assert sections['.init'][1]==0x20e00000
ram=[]
for n in ['.config_settings','.rodata_in_ram','.data','.bss','.wifi_boot','.heap','.stack']:
    size,vma,lma=sections[n]
    assert 0x08008000<=vma<vma+size<=0x0800c000,(n,sections[n])
    ram.append((vma,vma+size,n))
    if n in ['.config_settings','.rodata_in_ram','.data']:
        assert 0x20e00000<=lma<lma+size<=0x21000000
ram.sort()
assert all(x[1]<=y[0] for x,y in zip(ram,ram[1:])),ram
assert sections['.heap'][0]==1024 and sections['.stack'][:2]==(2048,0x0800b800)
# Startup copy crosses Flash/DLM: GP/TP/SP must remain PC-relative, not relaxed.
dis=tool('objdump','-d')
for reg in ['gp','tp','sp']:
    assert re.search(r'\bauipc\s+'+reg+r',[^\n]+\n[^\n]*\badd[i]?\s+'+reg+','+reg+r',',dis),reg
symbols={m[2]:int(m[1],16) for m in re.finditer(r'^([0-9a-f]+)\s+\w\s+(\S+)$',tool('nm'),re.M)}
assert symbols['_sp']==0x0800c000
assert symbols['_data']==sections['.rodata_in_ram'][1]
assert symbols['_data_lma']==sections['.rodata_in_ram'][2]
assert symbols['_edata']==sections['.data'][1]+sections['.data'][0]
assert 0x20e00000<=symbols['main']<0x21000000
image=a.elf.with_suffix('.bin').read_bytes()
assert 0<len(image)<0x200000
assert b'xip-ui-v1' in image and b'EXEC_PC' in image and b'AE: mode=' in image
print('PASS XIP Flash entry/code, DLM copy/sections, GP/TP/SP, heap/stack, diagnostic strings')
print(f'Binary {len(image)} bytes; DLM link gap {symbols["__StackLimit"]-symbols["__heap_limit"]} bytes (not stack watermark)')
