"""Guard the live video / SD snapshot allocation and MCU compatibility."""
from pathlib import Path
import re
root=Path(__file__).resolve().parent.parent
h=root/'user_source/hdl_source'
params=(h/'video_params.vh').read_text(encoding='utf-8')
def number(name):
    return int(re.search(r'`define\s+'+name+r'\s+(\d+)',params)[1])
w,ht=number('PIPE_WIDTH'),number('PIPE_HEIGHT')
stride=number('DDR_FRAME_STRIDE_ADDR');snapshot=number('DDR_SNAPSHOT_BASE_ADDR')
frame_units=w*ht*3//2
assert frame_units<=stride
assert 2*stride+frame_units<=snapshot
snapshot_units=(number('DISPLAY_WIDTH')//3)*(number('DISPLAY_HEIGHT')//3)*2
assert snapshot+snapshot_units<=2**25
rec=(h/'sd_recorder.v').read_text(encoding='utf-8')
assert 'BASE=`DDR_SNAPSHOT_BASE_ADDR' in rec
assert "rdata=32'h00010003" in rec  # existing MCU requires this ABI revision
assert (h/'design_top_wrapper.v').read_text(encoding='utf-8').count('sd_recorder #')==0
print(f'PASS DDR layout: three live banks end at byte {(2*stride+frame_units)*2}; '
      f'SD bytes {snapshot*2}..{(snapshot+snapshot_units)*2-1}; unchanged REC1 ABI')
