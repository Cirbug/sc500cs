"""MCU tracking safety regressions and a reproducible synthetic plant comparison."""
from pathlib import Path
import argparse, csv, io, json, os, subprocess, sys

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--gcc',default='D:/quartuesll/quartus/bin64/cygwin/bin/gcc.exe')
    ap.add_argument('--out',type=Path)
    a=ap.parse_args();root=Path(__file__).resolve().parent.parent
    out=(a.out or root/'build/red_tracking_fast_sim').resolve();out.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=str(Path(a.gcc).parent)+os.pathsep+env['PATH']
    r=subprocess.run([sys.executable,str(root/'tests/run_autofocus.py'),'--gcc',a.gcc,'--out',str(out/'host')],
                     capture_output=True,text=True,encoding='utf-8',errors='replace')
    (out/'host_regressions.log').write_text(r.stdout+r.stderr,encoding='utf-8');r.check_returncode()
    print('PASS AF, tracking arbitration, touch, menu and controller safety regressions',flush=True)
    exe=out/'response.exe'
    r=subprocess.run([a.gcc,'-std=c99','-O2','-Wall','-Wextra',str(root/'tests/test_red_track_response.c'),'-lm','-o',str(exe)],
                     env=env,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (out/'response_compile.log').write_text(r.stdout+r.stderr,encoding='utf-8');r.check_returncode()
    r=subprocess.run([str(exe)],cwd=out,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (out/'response_results.csv').write_text(r.stdout,encoding='utf-8')
    (out/'response_stderr.log').write_text(r.stderr,encoding='utf-8');r.check_returncode()
    rows=list(csv.DictReader(io.StringIO(r.stdout)))
    assert len(rows)==594
    pairs=list(zip(rows[::2],rows[1::2]))
    for old,new in pairs:
        assert old['controller']=='baseline' and new['controller']=='fast'
        if new['moving']=='1':
            assert float(new['rms_px'])<float(old['rms_px']), (old,new)
    sample=[r for r in rows if r['fps']=='30' and r['delay_ms']=='120' and r['gain_px_per_us']=='4'
            and r['sx']=='1' and r['sy']=='1' and r['noise']=='1']
    summary={'model_only':True,'board_validated':False,'cases':len(rows),
             'static_scenarios_per_controller':288,'moving_scenarios_per_controller':9,
             'fps':[15,30,50],'delay_ms':[40,120,240],'gain_px_per_us':[1,2,4,8],
             'static_settle_window_px':[64,52],'static_settle_hold_ms':500,
             'representative_scenarios':sample}
    (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print('PASS 288 static and 9 moving scenarios per controller; all moving RMS comparisons improve',flush=True)
    for r in sample: print(r,flush=True)

if __name__=='__main__':main()
