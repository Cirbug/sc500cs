"""Exercise production AF with a timed lens/error model and touch regressions."""
from pathlib import Path
import argparse, os, subprocess

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--gcc',default='D:/quartuesll/quartus/bin64/cygwin/bin/gcc.exe')
    ap.add_argument('--out',type=Path)
    args=ap.parse_args()
    root=Path(__file__).resolve().parent.parent
    out=(args.out or root/'build/autofocus_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=str(Path(args.gcc).parent)+os.pathsep+env['PATH']
    for name in ['autofocus','focus_tracking','touch_focus','red_track_control','picture_menu','record_menu','vts_menu']:
        exe=out/(name+'.exe')
        subprocess.run([args.gcc,'-std=c99','-O2','-Wall','-Wextra',str(root/'tests'/('test_'+name+'.c')),'-o',str(exe)],env=env,check=True)
        r=subprocess.run([str(exe)],env=env,capture_output=True,text=True)
        (out/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
        print(r.stdout+r.stderr,flush=True)
        r.check_returncode()
    s=(root/'FDwork/anlu_app/main.c').read_text(encoding='utf-8-sig')
    service=s[s.index('static void recorder_service(void)'):s.index('AL_S32 main(void)')]
    assert 'autofocus_task();' in service
    assert '#include "../shared/autofocus_control.h"' in s
    assert '#include "../shared/tracking_service.h"' in s
    assert 'tracking_service(record_ui);' in service
    assert 'tracking_service(&ui);' in s
    assert 'af_wait_ms++' not in s
    print('PASS AF production inclusion and cooperative recorder service integration',flush=True)

if __name__=='__main__':main()
