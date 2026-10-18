"""UI host inputs and actual RTL pixels; no FPGA implementation or programming."""
import argparse
import subprocess
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--modelsim', type=Path, default=Path('F:/modelsim/win64'))
    a = ap.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    vectors = out/'panel_vectors.hex'
    for name in ['test_panel_ui', 'test_picture_menu', 'test_record_menu', 'test_vts_menu', 'test_touch_focus']:
        for compat in ([1,0] if name == 'test_panel_ui' else [1]):
            exe = out/(name+f'_compat{compat}.exe')
            subprocess.run(['gcc', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror',
                            f'-DMENU_LEGACY_COMPAT={compat}',
                            str(root/'tests'/(name+'.c')), '-o', str(exe)], check=True)
            subprocess.run([str(exe)] + ([str(vectors)] if name == 'test_panel_ui' else []), check=True)
    h = root/'user_source/hdl_source'
    lib = out/'simlib'
    if not lib.exists():
        subprocess.run([str(a.modelsim/'vlib.exe'), str(lib)], check=True, capture_output=True)
    for bench, extra in [('tb_panel_ui', f'{{+TABLE={vectors.as_posix()}}} {{+FONT={(root/"assets/menu_font/rows.hex").as_posix()}}}'),
                         ('tb_rtc_osd', ''), ('tb_brand_layout', '')]:
        suffix = '.v' if bench == 'tb_rtc_osd' else '.sv'
        sources = ['ui_osd.v'] if bench != 'tb_brand_layout' else [
            'hdmi_mixer_image9.v', 'anlogic_logo_rom.v', 'logo2_rom.v', 'red_tracking_osd.v']
        script = out/(bench+'.do')
        log = out/(bench+'.log')
        script.write_text('onerror {quit -code 1 -force}\n' +
            f'vlog -sv -work {{{lib.as_posix()}}} {{+incdir+{h.as_posix()}}} '+
            ' '.join(f'{{{(h/source).as_posix()}}}' for source in sources)+
            f' {{{(root/"tests"/(bench+suffix)).as_posix()}}}\n'+
            f'vsim -voptargs=+acc -lib {{{lib.as_posix()}}} {bench} {extra}\n'+
            'onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
        subprocess.run([str(a.modelsim/'vsim.exe'), '-c', '-do', str(script), '-l', str(log)],
                       cwd=root, check=True, stdout=subprocess.DEVNULL)
        text = log.read_text(errors='replace')
        assert 'PASS' in text and '** Error' not in text and '** Fatal' not in text, text[-3000:]
        print('\n'.join(line for line in text.splitlines() if 'PASS' in line))


if __name__ == '__main__':
    main()
