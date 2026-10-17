"""MCU -> APB display-table -> shared font pixel equivalence regression."""
from pathlib import Path
import argparse, subprocess

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--modelsim',type=Path,default=Path('F:/modelsim/win64'))
    a=ap.parse_args();root=Path(__file__).resolve().parents[1]
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    exe=out/'test_mcu_menu.exe';vectors=out/'menu_vectors.hex'
    subprocess.run(['gcc','-std=c11','-O2','-Wall','-Wextra','-Werror',
                    str(root/'tests/test_mcu_menu.c'),'-o',str(exe)],check=True)
    subprocess.run([str(exe),str(vectors)],check=True)
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
    bus=out/'bus.vvp'
    subprocess.run(['iverilog','-g2012','-I',str(h),'-s','tb_mcu_menu_bus','-o',str(bus),
                    str(root/'tests/tb_mcu_menu_bus.sv'),str(h/'mcu_menu_table.v')],check=True)
    r=subprocess.run(['vvp',str(bus)],capture_output=True,text=True,check=True)
    (out/'bus.log').write_text(r.stdout+r.stderr)
    assert 'PASS MCU menu bus' in r.stdout
    print(r.stdout.strip())
if __name__=='__main__':main()
