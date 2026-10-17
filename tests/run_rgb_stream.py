"""Validate pixel packing and the actual Full-to-1080p processing chain."""
from pathlib import Path
import argparse, subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--modelsim', default='F:/modelsim/win64')
p.add_argument('--out', type=Path, required=True)
p.add_argument('--tops', nargs='+', default=['tb_camera_pixel_stream'])
a = p.parse_args()
root = Path(__file__).resolve().parent.parent
h = root / 'user_source/hdl_source'
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=True)
lib = out / 'simlib'
tool = Path(a.modelsim)
if not lib.exists():
    subprocess.run([str(tool/'vlib.exe'), str(lib)], check=True, capture_output=True)
sources = [h/'isp/data96_128/data96_128.v', h/'isp/isp_top.v', h/'picture_control.v']
sources += [root/'tests'/f'{top}.sv' for top in a.tops]
for top in a.tops:
    script = out/f'{top}.do'
    log = out/f'{top}.log'
    script.write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
        + 'vlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '
        + ' '.join('{'+s.as_posix()+'}' for s in sources)
        + '\nvsim -lib {'+lib.as_posix()+'} '+top+'\nrun -all\nquit -code 0 -force\n')
    r = subprocess.run([str(tool/'vsim.exe'), '-c', '-do', str(script), '-l', str(log)],
                       cwd=out, capture_output=True, text=True)
    text = log.read_text(errors='replace')
    if r.returncode or 'PASS ' not in text or '** Error' in text or '** Fatal' in text:
        raise RuntimeError(f'{top} failed; see {log}\n{text[-2200:]}')
    print('\n'.join(line for line in text.splitlines() if 'PASS ' in line), flush=True)
