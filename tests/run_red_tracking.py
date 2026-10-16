"""Offline red detection, coherent APB mailbox and MCU tracking regressions."""
from pathlib import Path
import argparse, os, subprocess

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--modelsim',default='D:/modelsim/win64')
    ap.add_argument('--gcc',default='D:/quartuesll/quartus/bin64/cygwin/bin/gcc.exe')
    ap.add_argument('--out',type=Path)
    a=ap.parse_args();root=Path(__file__).resolve().parent.parent
    out=(a.out or root/'build/red_tracking_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=str(Path(a.gcc).parent)+os.pathsep+env['PATH']
    for test in ['red_track_control','touch_focus','picture_menu','record_menu','vts_menu']:
        exe=out/(test+'.exe')
        subprocess.run([a.gcc,'-std=c99','-O2','-Wall','-Wextra',str(root/'tests'/('test_'+test+'.c')),'-o',str(exe)],env=env,check=True)
        r=subprocess.run([str(exe)],env=env,check=True,capture_output=True,text=True)
        (out/(test+'.log')).write_text(r.stdout+r.stderr);print(r.stdout.strip() or ('PASS '+test),flush=True)
    logsrc=root/'FDwork/anlu/ph1p35_fpsoc_cpu0/lib/log'
    for shared in [False,True]:
        name='printf_shared' if shared else 'printf_original';exe=out/(name+'.exe')
        flags=['-DAL_CAMERA_SHARED_PRINTF'] if shared else []
        subprocess.run([a.gcc,'-std=c99','-O2','-DAL_SIMP_NO_FLOAT',*flags,
            '-I'+str(root/'tests/printf_host'),'-I'+str(logsrc/'inc'),str(root/'tests/test_compact_printf.c'),
            str(logsrc/'src/al_printf.c'),str(logsrc/'src/al_simp_printf.c'),'-o',str(exe)],env=env,check=True,capture_output=True)
        r=subprocess.run([str(exe)],env=env,check=True,capture_output=True,text=True)
        (out/(name+'.log')).write_text(r.stdout+r.stderr);print(name+': '+r.stdout.strip(),flush=True)
    h=root/'user_source/hdl_source';lib=out/'simlib';tool=Path(a.modelsim)
    if not lib.exists():subprocess.run([str(tool/'vlib.exe'),str(lib)],check=True,capture_output=True)
    sources=[h/n for n in ['red_target_tracker.v','red_track_mailbox.v','mcu_ui_apb_regs.v','key_remove_shakes.v','red_tracking_osd.v']]
    cases=[(top,'') for top in ['tb_red_track_mailbox','tb_red_target_tracker','tb_red_tracker_1080p','tb_red_tracking_osd']]
    cases.append(('tb_red_target_tracker','-gREPORT_AREA_PERCENT=0'))
    for top,parameter in cases:
        name=top+('_no_percent' if parameter else '')
        script=out/(name+'.do');log=out/(name+'.log')
        script.write_text('onerror {quit -code 1 -force}\nvlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '+' '.join('{'+p.as_posix()+'}' for p in sources+[root/'tests'/(top+'.sv')])+'\nvsim -voptargs=+acc '+parameter+' -lib {'+lib.as_posix()+'} '+top+'\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
        subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=root,check=True,stdout=subprocess.DEVNULL)
        s=log.read_text(errors='replace');assert 'PASS ' in s and '** Error' not in s and '** Fatal' not in s,str(log)
        print('\n'.join(l for l in s.splitlines() if 'PASS ' in l),flush=True)
if __name__=='__main__':main()
