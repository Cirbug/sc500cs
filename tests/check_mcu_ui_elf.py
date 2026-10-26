"""Check TCM capacity and protected GP/TP/SP initialization after relaxation."""
import argparse,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('elf',type=Path)
p.add_argument('--tools',type=Path,default=Path('F:/AnlogicFpga/FD_2026.1/toolchain/gcc/riscv/ph1p35/bin'))
a=p.parse_args()
def tool(name,*args):
    return subprocess.check_output([str(a.tools/('riscv64-unknown-elf-'+name+'.exe')),*args,str(a.elf)],text=True)
sections=[]
for m in re.finditer(r'^\s*\d+\s+(\.\S+)\s+([0-9a-f]+)\s+([0-9a-f]+)',tool('objdump','-h'),re.M):
    name,size,start=m[1],int(m[2],16),int(m[3],16)
    if size and 0x08000000<=start<0x0800c000:sections.append((start,start+size,name))
sections.sort()
assert sections and all(b<=0x0800c000 for _,b,_ in sections),'TCM overflow'
for before,after in zip(sections,sections[1:]):assert before[1]<=after[0],(before,after)
byname={name:(start,end) for start,end,name in sections}
assert byname['.stack']==(0x0800b800,0x0800c000)
assert byname['.heap'][1]-byname['.heap'][0]>=256   # __HEAP_SIZE=256: see FDwork/anlu_app/Makefile
dis=tool('objdump','-d')
for reg in ['gp','tp','sp']:
    assert re.search(r'\bauipc\s+'+reg+r',[^\n]+\n[^\n]*\badd[i]?\s+'+reg+','+reg+r',',dis),reg+' initialization relaxed'
assert re.search(r'\bauipc\s+sp,[^\n]+\n[^\n]*800c000 <_sp>',dis),'SP must resolve to TCM top'
used=sum(b-a for a,b,_ in sections)
print(f'PASS ELF: GP/TP/SP PC-relative initialization, 2 KiB stack, 256 B heap, TCM sections {used}/49152 bytes')
print(f'Heap-to-stack reserve: {0x0800b800-byname[".heap"][1]} bytes')
