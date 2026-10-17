"""Check synchronous logo ROM, mixer latency/priority, and sprite restoration.

Requires ModelSim. --reference-dir may contain the original
hdmi_mixer_image9.v and anlogic_logo_rom.v when Git history is unavailable.
"""
from pathlib import Path
import argparse
import re
import subprocess

REFERENCE = 'a8df37a99e9121cdee57aa3bd62c5e6c81d440dd'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--modelsim',default='D:/modelsim/win64')
    ap.add_argument('--reference-dir',type=Path)
    ap.add_argument('--out',type=Path)
    args=ap.parse_args()
    root=Path(__file__).resolve().parent.parent
    out=(args.out or root/'build/osd_eram_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    hdl=root/'user_source/hdl_source';tool=Path(args.modelsim);lib=out/'simlib'
    def original(name):
        if args.reference_dir:
            return (args.reference_dir/name).read_text(encoding='utf-8-sig')
        return subprocess.check_output(['git','show',REFERENCE+':user_source/hdl_source/'+name],cwd=root).decode('utf-8-sig')
    s=original('hdmi_mixer_image9.v')
    assert 'SPRITE_ENABLE' not in s
    # Only expose the original compile-time enable as a parameter. All original
    # addressing, timing, pixel colors and layer priority remain the reference.
    s=s.replace('parameter integer DEBUG_MODE = 0,',"parameter integer DEBUG_MODE = 0,\nparameter SPRITE_ENABLE = 1'b1,")
    assert "localparam LOG2_EN    = 1'b1;" in s
    s=s.replace("localparam LOG2_EN    = 1'b1;",'localparam LOG2_EN = SPRITE_ENABLE;')
    for mod in re.findall(r'\bmodule\s+(\w+)',s)+['anlogic_logo_rom']:
        s=re.sub(r'\b'+mod+r'\b',mod+'_ref',s)
    (out/'mixer_ref.v').write_text(s,encoding='utf8')
    (out/'logo_ref.v').write_text(original('anlogic_logo_rom.v').replace('module anlogic_logo_rom','module anlogic_logo_rom_ref'),encoding='utf8')
    sources=[out/'mixer_ref.v',out/'logo_ref.v',hdl/'hdmi_mixer_image9.v',hdl/'anlogic_logo_rom.v',hdl/'logo2_rom.v',hdl/'red_tracking_osd.v',root/'tests/tb_osd_eram_equivalence.sv']
    subprocess.run([str(tool/'vlib.exe'),str(lib)],cwd=out,check=True)
    compile_do=out/'compile.do'
    compile_do.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} {+incdir+'+hdl.as_posix()+'} '+' '.join('{'+p.as_posix()+'}' for p in sources)+'\nquit -code 0 -force\n')
    subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(compile_do),'-l',str(out/'compile.log')],cwd=out,check=True)
    passed=[]
    for debug in range(4):
        run=out/f'debug{debug}.do';log=out/f'debug{debug}.log'
        run.write_text('onerror {quit -code 1 -force}\nvsim -voptargs=+acc -gDEBUG_TEST='+str(debug)+' -lib {'+lib.as_posix()+'} tb_osd\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
        subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(run),'-l',str(log)],cwd=out,check=True)
        text=log.read_text(errors='replace')
        assert 'PASS OSD:' in text and '** Error' not in text and '** Fatal' not in text, str(log)
        passed.append(next(line for line in text.splitlines() if 'PASS OSD:' in line))
    (out/'summary.txt').write_text('\n'.join(passed)+'\n')
    print('\n'.join(passed))

if __name__=='__main__':
    main()
