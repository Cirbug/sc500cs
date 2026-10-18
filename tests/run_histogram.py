"""Host algorithm/control tests and RTL stream/APB tests for HEQ1."""
from pathlib import Path
import argparse,subprocess,os
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True)
p.add_argument('--modelsim',type=Path,default=Path('D:/modelsim/win64'))
p.add_argument('--gcc',type=Path,default=Path('D:/quartuesll/quartus/bin64/cygwin/bin/gcc.exe'))
p.add_argument('--eram-model',type=Path,default=Path('D:/TD/sim_release/ph1p/ph1p_logic_eram.v'))
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env['PATH']=str(a.gcc.parent)+os.pathsep+env['PATH']
exe=out/'he_host.exe'
subprocess.run([str(a.gcc),'-std=c99','-O2','-Wall','-Wextra',str(root/'tests/test_histogram_equalization.c'),'-o',str(exe)],env=env,check=True)
r=subprocess.run([str(exe)],env=env,capture_output=True,text=True);(out/'host.log').write_text(r.stdout+r.stderr);print(r.stdout);r.check_returncode()
lib=out/'simlib';subprocess.run([str(a.modelsim/'vlib.exe'),str(lib)],check=True,capture_output=True)
h=root/'user_source/hdl_source';script=out/'run.do'
script.write_text('onerror {quit -code 1 -force}\n'+
 f'vlog -sv -work {{{lib.as_posix()}}} {{{h.as_posix()}/histogram_equalizer.v}} {{{root.as_posix()}/tests/tb_histogram_equalizer.sv}}\n'+
 f'vsim -lib {{{lib.as_posix()}}} tb_histogram_equalizer\n'+
 'onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
log=out/'rtl.log';r=subprocess.run([str(a.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=out,stdout=subprocess.DEVNULL)
s=log.read_text(errors='replace');print('\n'.join(l for l in s.splitlines() if 'PASS' in l or '** Error' in l or '** Fatal' in l))
r.check_returncode();assert s.count('PASS HEQ1')==4 and '** Error' not in s and '** Fatal' not in s
script.write_text('onerror {quit -code 1 -force}\n'+
 f'vlog -work {{{lib.as_posix()}}} {{{a.eram_model.as_posix()}}} {{{(a.eram_model.parent/"ph1p_phy_gsr.v").as_posix()}}}\n'+
 f'vlog -sv -work {{{lib.as_posix()}}} {{{h.as_posix()}/image_effects_9.v}} {{{root.as_posix()}/tests/tb_histogram_pipeline.sv}}\n'+
 f'vsim -lib {{{lib.as_posix()}}} tb_histogram_pipeline PH1P_PHY_GSR\n'+
 'onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
log=out/'pipeline.log';r=subprocess.run([str(a.modelsim/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=out,stdout=subprocess.DEVNULL)
s=log.read_text(errors='replace');print('\n'.join(l for l in s.splitlines() if 'PASS' in l or '** Error' in l or '** Fatal' in l))
r.check_returncode();assert 'PASS HE integration' in s and '** Error' not in s and '** Fatal' not in s
