"""Check the coherent focus-frame mailbox used by red-target autofocus."""
from pathlib import Path
import argparse,subprocess
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path)
    a=ap.parse_args();root=Path(__file__).resolve().parent.parent
    out=(a.out or root/'build/target_focus_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    tool=Path('D:/modelsim/win64');lib=out/'simlib'
    if not lib.exists():subprocess.run([str(tool/'vlib.exe'),str(lib)],check=True,capture_output=True)
    sources=[root/'user_source/hdl_source/focus_result_mailbox.v',root/'tests/tb_focus_result_mailbox.sv']
    script=out/'focus.do';log=out/'focus.log'
    script.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} '+' '.join('{'+p.as_posix()+'}' for p in sources)+'\nvsim -voptargs=+acc -lib {'+lib.as_posix()+'} tb_focus_result_mailbox\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
    subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],check=True,stdout=subprocess.DEVNULL)
    s=log.read_text(errors='replace');assert 'PASS ' in s and '** Error' not in s and '** Fatal' not in s,str(log)
    print('\n'.join(l for l in s.splitlines() if 'PASS ' in l))
if __name__=='__main__':main()
