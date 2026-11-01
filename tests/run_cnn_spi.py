"""Offline result SPI/overlay/CSR checks. Does not program hardware."""
import argparse, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
b=root.parent/'ph1p35second/fpga/uisrc/01_rtl/cnn/cnn_spi_result_slave.v'
h=root/'user_source/hdl_source'
out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
tests={
 'tb_cnn_spi_link':[h/'cnn_spi_result_master.v',b],
 'tb_cnn_overlay':[h/'cnn_digit_overlay.v'],
 'tb_cnn_result_apb':[h/'cnn_result_apb.v',h/'video_integrity.v'],
}
for name,sources in tests.items():
    exe=out/(name+'.vvp')
    cmd=['iverilog','-g2012','-s',name,'-o',str(exe),str(root/'tests'/(name+'.v')),*map(str,sources)]
    comp=subprocess.run(cmd,text=True,capture_output=True)
    (out/(name+'_compile.log')).write_text(comp.stdout+comp.stderr)
    comp.check_returncode()
    sim=subprocess.run(['vvp',str(exe)],text=True,capture_output=True,timeout=120)
    (out/(name+'.log')).write_text(sim.stdout+sim.stderr)
    print(sim.stdout,end='');sim.check_returncode()
    assert '_PASS' in sim.stdout
print('ALL_CNN_SPI_TESTS_PASS')
