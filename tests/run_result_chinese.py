"""Pixel-level Chinese effect/shape labels and existing menu regression."""
from pathlib import Path
import argparse, subprocess

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--modelsim',default='D:/modelsim/win64')
    ap.add_argument('--out',type=Path,required=True)
    args=ap.parse_args();root=Path(__file__).resolve().parent.parent
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    tool=Path(args.modelsim);lib=out/'simlib';h=root/'user_source/hdl_source'
    if not lib.exists(): subprocess.run([str(tool/'vlib.exe'),str(lib)],check=True,capture_output=True)
    sources=[h/n for n in ['ui_osd.v','hdmi_mixer_image9.v','anlogic_logo_rom.v','logo2_rom.v','red_tracking_osd.v']]
    sources += [root/'tests/tb_result_chinese.sv',root/'tests/tb_menu_chinese.v']
    for top in ['tb_result_chinese','tb_menu_chinese']:
        script=out/(top+'.do');log=out/(top+'.log')
        script.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '+
            ' '.join('{'+p.as_posix()+'}' for p in sources)+'\nvsim -voptargs=+acc -lib {'+lib.as_posix()+'} '+top+
            ' {+OUT_DIR='+out.as_posix()+'}\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
        subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=root,check=True,stdout=subprocess.DEVNULL)
        s=log.read_text(errors='replace')
        assert 'PASS ' in s and '** Error' not in s and '** Fatal' not in s,str(log)
        print('\n'.join(l for l in s.splitlines() if 'PASS ' in l),flush=True)
if __name__=='__main__':main()
