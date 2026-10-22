"""Check the eight fixed gamma presets against the real-power reference.

Example: python tests/run_gamma_presets.py --modelsim D:/modelsim/win64
"""
from pathlib import Path
import argparse
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim', type=Path)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    out = (args.out or root / 'build/gamma_presets').resolve()
    out.mkdir(parents=True, exist_ok=True)
    tool = args.modelsim / 'vsim.exe' if args.modelsim else shutil.which('vsim')
    if not tool:
        raise RuntimeError('ModelSim not found; specify --modelsim with its executable directory')
    source = (root / 'user_source/hdl_source/isp/isp_top.v').read_text(encoding='utf-8-sig')
    module = re.search(r'\bmodule\s+rgb96_gamma\b.*?\bendmodule', source, re.S)
    if module is None:
        raise RuntimeError('Gamma module missing')
    dut = out / 'gamma_dut.v'
    dut.write_text(module[0], encoding='utf-8')
    tb = root / 'tests/tb_gamma_presets.sv'
    lib = out / 'work'
    script = out / 'run.do'
    script.write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
                      + 'if {![file exists {' + lib.as_posix() + '}]} {vlib {' + lib.as_posix() + '}}\n'
                      + 'vlog -sv -work {' + lib.as_posix() + '} {'
                      + dut.as_posix() + '} {' + tb.as_posix() + '}\n'
                      + 'vsim -voptargs=+acc -lib {' + lib.as_posix() + '} tb_gamma_presets\n'
                      + 'run -all\nquit -code 0 -force\n', encoding='utf-8')
    log = out / 'simulation.log'
    subprocess.run([str(tool), '-c', '-do', str(script), '-l', str(log)], check=True, cwd=out)
    text = log.read_text(errors='replace')
    if 'PASS gamma presets:' not in text or '** Fatal:' in text or '** Error:' in text:
        raise RuntimeError('Gamma presets failed; inspect ' + str(log))
    print(next(line.strip('# ') for line in text.splitlines() if 'PASS gamma presets:' in line))


if __name__ == '__main__':
    main()
