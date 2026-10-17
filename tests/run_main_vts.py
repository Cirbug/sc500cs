"""Run menu, APB/sensor, dual frame counter and OSD regressions."""
from pathlib import Path
import argparse,subprocess,os
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--modelsim',default='D:/modelsim/win64')
    ap.add_argument('--gcc',default='D:/quartuesll/quartus/bin64/cygwin/bin/gcc.exe')
    ap.add_argument('--out',type=Path)
    ap.add_argument('--tops',nargs='*')
    args=ap.parse_args();root=Path(__file__).resolve().parent.parent;h=root/'user_source/hdl_source';tests=root/'tests'
    out=(args.out or root/'build/main_vts_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    (root/'build').mkdir(exist_ok=True)
    tool=Path(args.modelsim);lib=out/'simlib'
    if not args.tops:
        env=os.environ.copy();env['PATH']=str(Path(args.gcc).parent)+os.pathsep+env['PATH']
        for name in ['test_vts_menu','test_picture_menu','test_record_menu']:
            exe=out/(name+'.exe')
            subprocess.run([args.gcc,'-std=c99','-O2',str(tests/(name+'.c')),'-o',str(exe)],env=env,check=True,capture_output=True)
            r=subprocess.run([str(exe)],env=env,check=True,capture_output=True,text=True)
            result=r.stdout+r.stderr or ('PASS '+name+' assertions\n')
            (out/(name+'.log')).write_text(result)
            print(result.strip(),flush=True)
    tops=args.tops or ['tb_main_vts','tb_main_meter','tb_camera30','tb_camera30_osd','tb_hdmi_stats_osd','tb_menu_chinese']
    sources=[h/'ui_osd.v',h/'mcu_ui_apb_regs.v',h/'uiisp_beta/ae_set.v',h/'key_remove_shakes.v']
    sources += [h/'uics500_cfg'/n for n in ['uicfgcs500.v','uics500reg.v','uics500regAE.v','uii2c.v','SC500GainTbl.v']]
    sources += [tests/(n+('.sv' if n in ['tb_main_vts','tb_main_meter'] else '.v')) for n in tops]
    if not lib.exists():subprocess.run([str(tool/'vlib.exe'),str(lib)],check=True,capture_output=True)
    for top in tops:
        script=out/(top+'.do');log=out/(top+'.log')
        script.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '+' '.join('{'+p.as_posix()+'}' for p in sources)+'\nvsim -voptargs=+acc -lib {'+lib.as_posix()+'} '+top+'\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
        subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=root,check=True,stdout=subprocess.DEVNULL)
        s=log.read_text(errors='replace');assert ('PASS ' in s or 'PASS:' in s) and '** Error' not in s and '** Fatal' not in s,str(log)
        print('\n'.join(l for l in s.splitlines() if 'PASS' in l),flush=True)
if __name__=='__main__':main()
