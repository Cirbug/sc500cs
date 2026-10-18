"""Compare Gamma pixels and controls against the pre-optimization Git revision.

Example: python tests/run_gamma_equivalence.py --modelsim F:/win64
"""
from pathlib import Path
import argparse
import re
import shutil
import subprocess

REFERENCE = 'ab4917f0be7a1bea3b95460a697c38f1de80b130'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    out = root / 'build/resource_optimization/gamma_sim'
    out.mkdir(parents=True, exist_ok=True)
    tool = args.modelsim / 'vsim.exe' if args.modelsim else shutil.which('vsim')
    if not tool:
        raise RuntimeError('ModelSim not found; specify --modelsim with its executable directory')
    rel = 'user_source/hdl_source/isp/isp_top.v'
    original = subprocess.check_output(['git', 'show', REFERENCE + ':' + rel], cwd=root).decode('utf-8-sig')
    current = (root / rel).read_text(encoding='utf-8-sig')
    sources = []
    for name, source in [('baseline', original), ('candidate', current)]:
        module = re.search(r'\bmodule\s+rgb96_gamma\b.*?\bendmodule', source, re.S)
        if module is None:
            raise RuntimeError('Gamma module missing from ' + name)
        text = module[0]
        if name == 'baseline':
            text = text.replace('module rgb96_gamma', 'module rgb96_gamma_baseline', 1)
        path = out / (name + '.v')
        path.write_text(text, encoding='utf-8')
        sources.append(path)
    sources.append(root / 'tests/tb_gamma_equivalence.sv')
    lib = out / 'work'
    script = out / 'run.do'
    script.write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
                      + 'if {![file exists {' + lib.as_posix() + '}]} {vlib {' + lib.as_posix() + '}}\n'
                      + 'vlog -sv -work {' + lib.as_posix() + '} '
                      + ' '.join('{' + p.as_posix() + '}' for p in sources)
                      + '\nvsim -voptargs=+acc -lib {' + lib.as_posix() + '} tb_gamma_equivalence\n'
                      + 'run -all\nquit -code 0 -force\n', encoding='utf-8')
    log = out / 'simulation.log'
    subprocess.run([str(tool), '-c', '-do', str(script), '-l', str(log)], check=True, cwd=out)
    text = log.read_text(errors='replace')
    if 'PASS gamma equivalence:' not in text or '** Fatal:' in text or '** Error:' in text:
        raise RuntimeError('Gamma equivalence failed; inspect ' + str(log))
    print(next(line for line in text.splitlines() if 'PASS gamma equivalence:' in line))


if __name__ == '__main__':
    main()
