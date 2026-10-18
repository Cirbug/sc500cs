"""Run merged measurement and display regressions. Invoke from any directory.
Example: python tests/run_latency_merged.py --modelsim F:/win64
"""
from pathlib import Path
import argparse
import subprocess

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim',type=Path,required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parent.parent
    out=root/'build/merge_latency/simulation'
    out.mkdir(parents=True,exist_ok=True)
    lib=out/'work'
    names=['tb_capture_display_latency','tb_latency_range','tb_hdmi_stats_osd','tb_ui_osd']
    sources=[root/'user_source/hdl_source/capture_display_latency.v',root/'user_source/hdl_source/ui_osd.v']
    sources += [root/('tests/'+top+'.v') for top in names]
    for index,top in enumerate(names):
        script=out/(top+'.do')
        commands='onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
        if index==0:
            commands+='if {![file exists {'+lib.as_posix()+'}]} {vlib {'+lib.as_posix()+'}}\n'
            commands+='vlog -sv -work {'+lib.as_posix()+'} +incdir+'+(root/'user_source/hdl_source').as_posix()+' '
            commands+=' '.join('{'+p.as_posix()+'}' for p in sources)+'\n'
        commands+='vsim -voptargs=+acc -lib {'+lib.as_posix()+'} '+top+'\nrun -all\nquit -code 0 -force\n'
        script.write_text(commands,encoding='utf-8')
        log=out/(top+'.log')
        result=subprocess.run([str(args.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        text=log.read_text(errors='replace') if log.exists() else result.stdout.decode(errors='replace')
        if result.returncode or 'PASS' not in text or '** Fatal:' in text or '** Error:' in text:
            raise RuntimeError(top+' failed:\n'+text[-4000:])
        print(next(line for line in text.splitlines() if 'PASS' in line))

if __name__=='__main__':
    main()
