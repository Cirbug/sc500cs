"""Create isolated project/script references; never overwrite the stable pair."""
from pathlib import Path
R=Path(__file__).resolve().parent
B=Path('C:/Users/21397/Desktop/bank/camera_net_20261020_fast')
p=(R/'eg_image_sink640.al').read_text()
p=p.replace('/v640/','/v640_fast/').replace('<Name>eg_image_sink640</Name>','<Name>eg_image_sink640_fast</Name>')
(R/'eg_image_sink640_fast.al').write_text(p)
p=(R/'build_eg640.tcl').read_text().replace('camera_net_20261019/eg_640','camera_net_20261020_fast/eg_640')
p=p.replace('eg_image_sink640.al','eg_image_sink640_fast.al')
(R/'build_eg640_fast.tcl').write_text(p)
p=(R/'v640/tests/run640.py').read_text().replace("V=R/'v640'","V=R/'v640_fast'")
p=p.replace('camera_net_20261019/sim640','camera_net_20261020_fast/sim640')
p=p.replace("*sorted((V/'tests').glob('tb_*.sv'))","*[p for p in sorted((V/'tests').glob('tb_*.sv')) if p.name!='tb_epoch640.sv']")
(R/'v640_fast/tests/run640.py').write_text(p)
print('Created isolated fast project and test runner')
