"""MCU -> APB display-table -> shared font pixel equivalence regression."""
from pathlib import Path
import argparse, subprocess, os

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--modelsim',type=Path,default=Path('D:/modelsim/win64'))
    ap.add_argument('--gcc',type=Path,default=Path('D:/quartuesll/quartus/bin64/cygwin/bin/gcc.exe'))
    a=ap.parse_args();root=Path(__file__).resolve().parents[1]
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    exe=out/'test_mcu_menu.exe';vectors=out/'menu_vectors.hex'
    env=os.environ.copy();env['PATH']=str(a.gcc.parent)+os.pathsep+env['PATH']
    subprocess.run([str(a.gcc),'-std=c99','-O2','-Wall','-Wextra','-Werror',
                    str(root/'tests/test_mcu_menu.c'),'-o',str(exe)],env=env,check=True)
    subprocess.run([str(exe),str(vectors)],env=env,check=True)
    lib=out/'simlib'
    if not lib.exists():subprocess.run([str(a.modelsim/'vlib.exe'),str(lib)],check=True,capture_output=True)
    h=root/'user_source/hdl_source'
    script=out/'test.do'
    script.write_text('onerror {quit -code 1 -force}\n'+
        f'vlog -sv -work {{{lib.as_posix()}}} {{+incdir+{h.as_posix()}}} '+
        f'{{{h.as_posix()}/ui_osd.v}} {{{root.as_posix()}/tests/tb_mcu_menu.sv}}\n'+
        f'vsim -voptargs=+acc -lib {{{lib.as_posix()}}} tb_mcu_menu {{+TABLE={vectors.as_posix()}}}\n'+
        'onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
    log=out/'test.log'
    subprocess.run([str(a.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],
                   cwd=root,check=True,stdout=subprocess.DEVNULL)
    s=log.read_text(errors='replace')
    assert 'PASS MCU menu pixel equivalence' in s and '** Error' not in s and '** Fatal' not in s,s[-3000:]
    print('\n'.join(l for l in s.splitlines() if 'PASS' in l))
    script.write_text('onerror {quit -code 1 -force}\n'+
        f'vlog -sv -work {{{lib.as_posix()}}} {{{root.as_posix()}/tests/tb_mcu_menu_bus.sv}}\n'+
        f'vsim -lib {{{lib.as_posix()}}} tb_mcu_menu_bus\n'+
        'onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
    log=out/'bus.log'
    subprocess.run([str(a.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],
                   cwd=root,check=True,stdout=subprocess.DEVNULL)
    s=log.read_text(errors='replace')
    assert 'PASS MCU menu bus' in s and '** Error' not in s and '** Fatal' not in s
    print('\n'.join(l for l in s.splitlines() if 'PASS' in l))
if __name__=='__main__':main()
