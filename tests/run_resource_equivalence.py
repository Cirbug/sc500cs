"""Compare optimized Sobel/sharpening with the pre-optimization RTL.

Run from any directory. Requires ModelSim and the TD PH1P simulation library.
Example: python tests/run_resource_equivalence.py --modelsim D:/modelsim/win64 --td D:/TD
The reference is pinned to a Git revision, not recomputed from optimized RTL.
"""
from pathlib import Path
import argparse
import re
import subprocess

REFERENCE = 'a8df37a99e9121cdee57aa3bd62c5e6c81d440dd'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim', default='D:/modelsim/win64')
    parser.add_argument('--td', default='D:/TD')
    parser.add_argument('--out', type=Path)
    parser.add_argument('--reference-dir', type=Path,
                        help='Optional directory containing original image_effects_9.v and rgb24_denoise_9.v')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    out = (args.out or root/'build/resource_optimization_sim').resolve()
    out.mkdir(parents=True, exist_ok=True)
    tool = Path(args.modelsim)
    td = Path(args.td)
    sources = []
    for version in ('baseline', 'candidate'):
        for filename, module in [('image_effects_9.v', 'sobel_edge'),
                                 ('rgb24_denoise_9.v', 'rgb24_denoise')]:
            rel = 'user_source/hdl_source/' + filename
            if version == 'candidate':
                source = (root/rel).read_text(encoding='utf-8-sig')
            elif args.reference_dir:
                source = (args.reference_dir/filename).read_text(encoding='utf-8-sig')
            else:
                source = subprocess.check_output(['git', 'show', REFERENCE+':'+rel], cwd=root).decode('utf-8-sig')
            match = re.search(r'\bmodule\s+'+module+r'\b.*?\bendmodule', source, re.S)
            if not match:
                raise RuntimeError('Reference module missing: '+module)
            source = re.sub(r'\b'+module+r'\b', module+'_'+version, match[0], count=1)
            dest = out/(module+'_'+version+'.v')
            dest.write_text(source, encoding='utf-8')
            sources.append(dest)
    ip = root/'user_source/ip_source/blk_mem_gen_awb_delay_signal'
    sources += [ip/'blk_mem_gen_awb_delay_signal.v', ip/'ram_f84573da5ab5.v',
                td/'sim_release/ph1p/ph1p_logic_eram.v', td/'sim_release/ph1p/ph1p_phy_gsr.v',
                root/'tests/tb_resource_equivalence.sv']
    for path in sources:
        if not path.is_file():
            raise FileNotFoundError(path)
    lib = out/'simlib'
    subprocess.run([str(tool/'vlib.exe'), str(lib)], check=True, cwd=out)
    script = out/'run.do'
    script.write_text('onerror {quit -code 1 -force}\n'
        + 'vlog -sv -work {'+lib.as_posix()+'} '
        + ' '.join('{'+p.as_posix()+'}' for p in sources)
        + '\nvsim -voptargs=+acc -lib {'+lib.as_posix()+'} tb_resource_equivalence PH1P_PHY_GSR'
        + '\nonbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n', encoding='utf-8')
    log = out/'simulation.log'
    subprocess.run([str(tool/'vsim.exe'), '-c', '-do', str(script), '-l', str(log)], check=True, cwd=out)
    text = log.read_text(errors='replace')
    if 'PASS equivalence:' not in text or '** Fatal:' in text or '** Error:' in text:
        raise RuntimeError('Simulation did not complete all comparisons; inspect '+str(log))
    print(next(line for line in text.splitlines() if 'PASS equivalence:' in line))

if __name__ == '__main__':
    main()
