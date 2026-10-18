"""Verify software AE, existing controls, frame metering and sensor updates."""
from pathlib import Path
import argparse
import os
import re
import subprocess


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gcc',type=Path,required=True)
    parser.add_argument('--modelsim',type=Path,required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parent.parent
    out=root/'build/auto_exposure/tests';out.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=str(args.gcc.parent)+os.pathsep+env['PATH']
    for name in ['auto_exposure','mcu_menu','vts_menu','picture_menu','record_menu','touch_focus','wifi_mcu','autofocus']:
        exe=out/(name+'.exe')
        subprocess.run([str(args.gcc),'-std=c99','-O2',str(root/'tests'/('test_'+name+'.c')),'-o',str(exe)],env=env,check=True,capture_output=True)
        result=subprocess.run([str(exe)]+([str(out/"menu_vectors.hex")] if name=="mcu_menu" else []),env=env,capture_output=True,text=True)
        (out/(name+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
        result.check_returncode()
        print(result.stdout.strip() or 'PASS '+name,flush=True)
    h=root/'user_source/hdl_source'
    source=(h/'isp/isp_top.v').read_text(encoding='utf-8-sig')
    match=re.search(r'\bmodule\s+dbg_color_stat\b.*?\bendmodule',source,re.S)
    probe=out/'dbg_color_stat.v';probe.write_text(match[0],encoding='utf-8')
    lib=out/'work'
    sources=[probe,h/'video_integrity.v',h/'mcu_ui_apb_regs.v',h/'key_remove_shakes.v',h/'camera_menu_support.v',h/'uiisp_beta/ae_set.v']
    sources += [h/'uics500_cfg'/n for n in ['uicfgcs500.v','uics500reg.v','uics500regAE.v','uii2c.v','SC500GainTbl.v']]
    tops=['tb_ae_meter','tb_main_vts']
    sources += [root/'tests'/(n+'.sv') for n in tops]
    for index,top in enumerate(tops):
        commands='onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
        if index==0:
            commands+='if {![file exists {'+lib.as_posix()+'}]} {vlib {'+lib.as_posix()+'}}\n'
            commands+='vlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '
            commands+=' '.join('{'+p.as_posix()+'}' for p in sources)+'\n'
        commands+='vsim -voptargs=+acc -lib {'+lib.as_posix()+'} '+top+'\nrun -all\nquit -code 0 -force\n'
        script=out/(top+'.do');script.write_text(commands,encoding='utf-8')
        log=out/(top+'.log')
        result=subprocess.run([str(args.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=root,capture_output=True)
        text=log.read_text(errors='replace')
        if result.returncode or 'PASS' not in text or '** Fatal:' in text or '** Error:' in text:
            raise RuntimeError(top+' failed:\n'+text[-5000:])
        print(next(line for line in text.splitlines() if 'PASS' in line),flush=True)
    for path in ['FDwork/anlu_app/main.c','FDwork/anlu_app2/main.c']:
        text=(root/path).read_text(encoding='utf-8-sig')
        assert 'auto_exposure_init(&ui);' in text and 'auto_exposure_poll(&ui);' in text
        assert 'auto_exposure_poll(record_ui);' in text and 'autofocus_active())auto_exposure_pause()' in text
    print('PASS both firmware targets: startup, main loop, recording service and AF pause',flush=True)


if __name__=='__main__':
    main()
