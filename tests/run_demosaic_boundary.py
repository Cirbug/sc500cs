"""Run the complete demosaic with the generated wrappers and TD ERAM model."""
from pathlib import Path
import argparse
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--modelsim', default='D:/modelsim/win64')
p.add_argument('--td', default='D:/TD')
p.add_argument('--out', type=Path, required=True)
p.add_argument('--baseline', action='store_true')
p.add_argument('--full', action='store_true')
p.add_argument('--gaps', action='store_true')
p.add_argument('--no-line-gap', action='store_true')
p.add_argument('--reset-partial', action='store_true')
a = p.parse_args()
root = Path(__file__).resolve().parent.parent
d = root/'user_source/hdl_source/isp/demosaic_4x_2_0'
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=True)
tool = Path(a.modelsim)
lib = out/'work'
if not lib.exists():
    subprocess.run([str(tool/'vlib.exe'), str(lib)], check=True, capture_output=True)
sources = [Path(a.td)/'sim_release/ph1p/ph1p_logic_eram.v',
           Path(a.td)/'sim_release/ph1p/ph1p_phy_gsr.v']
sources += list(d.glob('*.v'))
for name in ['demosaic', 'zhenghe']:
    ip = d/('blk_mem_gen_'+name)
    sources += [ip/('blk_mem_gen_'+name+'.v')] + list((ip/'RTL').glob('*.v'))
sources += [root/'tests/tb_demosaic_frame_boundary.sv']
options = '-gW=1920 -gH=1080 -gFRAMES=2' if a.full else ''
if a.gaps:
    options += ' -gGAPS=1'
if a.no_line_gap:
    options += ' -gLINE_GAP=0'
if a.reset_partial:
    options += ' +reset_partial'
if a.baseline:
    options += ' +baseline'
script = out/'run.do'
script.write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
    +'vlog -sv -work {'+lib.as_posix()+'} '+' '.join('{'+s.as_posix()+'}' for s in sources)
    +'\nvsim -lib {'+lib.as_posix()+'} tb_demosaic_frame_boundary PH1P_PHY_GSR '+options
    +'\nrun -all\nquit -code 0 -force\n')
log = out/'run.log'
r = subprocess.run([str(tool/'vsim.exe'), '-c', '-do', str(script), '-l', str(log)],
                   cwd=out, capture_output=True)
text = log.read_text(errors='replace')
if r.returncode or 'PASS' not in text or '** Error' in text or '** Fatal' in text:
    raise RuntimeError(str(log)+'\n'+text[-3500:])
print('\n'.join(line for line in text.splitlines() if 'PASS' in line or 'MISMATCH' in line))
