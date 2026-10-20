"""Check frame-coherent target coordinates and actual legacy/MCU OSD pixels."""
import argparse
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modelsim/win64"))
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    lib = out / "simlib"
    if not lib.exists():
        subprocess.run([str(args.modelsim / "vlib.exe"), str(lib)],
                       check=True, capture_output=True)
    hdl = root / "user_source/hdl_source"
    cases = {
        "tb_red_track_display": ["red_track_display.v"],
        "tb_red_track_label": ["ui_osd.v", "red_tracking_osd.v"],
        "tb_red_tracking_osd": ["red_tracking_osd.v"],
    }
    for bench, modules in cases.items():
        sources = [hdl / name for name in modules] + [root / "tests" / (bench + ".sv")]
        script = out / (bench + ".do")
        log = out / (bench + ".log")
        script.write_text(
            "onerror {quit -code 1 -force}\n"
            f"vlog -sv -work {{{lib.as_posix()}}} {{+incdir+{hdl.as_posix()}}} "
            + " ".join("{" + p.as_posix() + "}" for p in sources)
            + f"\nvsim -voptargs=+acc -lib {{{lib.as_posix()}}} {bench}"
            + f" {{+OUT_DIR={out.as_posix()}}}\n"
            "onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n",
            encoding="ascii",
        )
        subprocess.run([str(args.modelsim / "vsim.exe"), "-c", "-do", str(script), "-l", str(log)],
                       cwd=root, check=True, stdout=subprocess.DEVNULL)
        text = log.read_text(errors="replace")
        assert "PASS " in text and "** Error" not in text and "** Fatal" not in text, text[-4000:]
        print("\n".join(line for line in text.splitlines() if "PASS " in line), flush=True)


if __name__ == "__main__":
    main()
