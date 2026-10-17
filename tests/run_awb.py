"""AWB pixel-model, temporal/control and existing picture regressions."""
from pathlib import Path
import argparse,subprocess
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--modelsim',default='D:/modelsim/win64');ap.add_argument('--out',type=Path)
    a=ap.parse_args();root=Path(__file__).resolve().parent.parent
    out=(a.out or root/'build/awb_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    h=root/'user_source/hdl_source';tool=Path(a.modelsim);lib=out/'simlib'
    if not lib.exists():subprocess.run([str(tool/'vlib.exe'),str(lib)],check=True,capture_output=True)
    cases=['tb_awb_robust','tb_awb_fullframe','tb_picture_control','tb_picture_algorithms']
    sources=[h/'awb.v',h/'picture_control.v',h/'isp/isp_top.v']
    sources += [root/'tests'/(top+('.sv' if top.startswith('tb_awb_') else '.v')) for top in cases]
    for top in cases:
        script=out/(top+'.do');log=out/(top+'.log')
        script.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '+' '.join('{'+p.as_posix()+'}' for p in sources)+'\nvsim -voptargs=+acc -lib {'+lib.as_posix()+'} '+top+'\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
        r=subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=out,stdout=subprocess.DEVNULL)
        s=log.read_text(errors='replace')
        if r.returncode or 'PASS' not in s or '** Error' in s or '** Fatal' in s:
            print(s[-6500:]);raise RuntimeError(str(log))
        print('\n'.join(l for l in s.splitlines() if 'PASS' in l),flush=True)
if __name__=='__main__':main()
