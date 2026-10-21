"""Publish the matched 320x180 pair only after timing and regression pass."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, zipfile, argparse
ap=argparse.ArgumentParser();ap.add_argument("--perf40",action="store_true");options=ap.parse_args()

ROOT = Path(__file__).resolve().parent
BANK = Path(r'C:\Users\21397\Desktop\bank\camera_net_20261019')
OUT = ROOT / ('output320_perf40' if options.perf40 else 'output320')
EG_FOLDER='eg_320_perf40' if options.perf40 else 'eg_320'
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

sim = json.loads((BANK/'sim320/result.json').read_text())
required = {'rectangle','circle','triangle','blue_circle','blank','diamond',
            'small_red','right_red','dim_red','noisy_circle','bridge','capture',
            'receiver','recovery','pair','warm_skin','shadow_red','muted_red','pale_red','red_speck','red_guard'}
assert sim['status'] == 'PASS' and required <= set(sim['checks'])
assert sim['analysis_pixels'] == 57600 and sim['udp_fcs_and_every_pixel'] == 'PASS'
assert sim.get('analysis_clock_hz',25000000)==(40000000 if options.perf40 else 25000000)
boards = {}
for board, folder, bit, marker in [
    ('PH1P35','fpga_320','camera_network.bit','CAMERA_NET_BUILD_COMPLETE'),
    ('EG4D20',EG_FOLDER,'eg_image_sink.bit','EG_IMAGE_SINK_BUILD_COMPLETE')]:
    build = BANK/folder
    timing = (build/'final_timing.rpt').read_text()
    sw,st = map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns',timing).groups())
    hw,ht = map(float,re.search(r'HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing).groups())
    assert sw >= 0 and hw >= 0 and st == 0 and ht == 0, (board,sw,st,hw,ht)
    logname = 'camera_net_'+('main320' if board == 'PH1P35' else ('eg320_perf40' if options.perf40 else 'eg320'))+'_build.log'
    assert marker in (BANK.parent/logname).read_text(encoding='utf-8-sig',errors='replace')
    p = build/bit
    assert p.stat().st_mtime >= (build/'final_timing.rpt').stat().st_mtime
    boards[board] = dict(file=bit,sha256=sha(p),setup_wns_ns=sw,hold_wns_ns=hw,
                         sta_coverage=re.search(r'STA coverage\s*:\s*(\S+)',timing)[1])

baseline = json.loads((ROOT/'baseline.json').read_text())
assert baseline['main_sha256'] == sha(ROOT.parents[1]/'user_source/hdl_source/design_top_wrapper.v')
pins = re.findall(r'LOCATION\s*=\s*(\w+)',(ROOT/'pin_net.adc').read_text(encoding='utf-8-sig'))
assert len(pins) == len(set(pins))
OUT.mkdir(exist_ok=True)
for board, folder in [('PH1P35','fpga_320'),('EG4D20',EG_FOLDER)]:
    shutil.copy2(BANK/folder/boards[board]['file'],OUT/boards[board]['file'])
    for name in ['final.area','final_timing.rpt']:
        shutil.copy2(BANK/folder/name,OUT/(board+'_'+name))
shutil.copy2(BANK/'sim320/result.json',OUT/'simulation.json')
for name in sim['checks']:
    shutil.copy2(BANK/'sim320'/(name+'.log'),OUT/(name+'.log'))
functional = list((ROOT/'rtl').glob('*.v')) + list((ROOT/'vendor').glob('*.v'))
functional += [ROOT/n for n in ['shape_features320.v','design_top_wrapper_net.v',
    'anlogic_logo_rom_trim.v','eg_image_sink.v','pin_net.adc','timing_net.sdc','timing_eg.sdc',
    'prepare.py','build_main320.tcl','build_eg320.tcl']]
if options.perf40:functional += [ROOT/n for n in ['eg_image_sink_perf40.v','timing_eg_perf40.sdc','build_eg320_perf40.tcl','eg_image_sink_perf40.al']]
(OUT/'source_sha256.json').write_text(json.dumps({str(p.relative_to(ROOT)):sha(p) for p in functional},indent=2))
report = dict(status='BUILD_AND_SIMULATION_PASS',generated=datetime.datetime.now().isoformat(timespec='seconds'),
    image=dict(width=320,height=180,format='RGB332',analysis_pixels=57600,secondary_downsampling=False,analysis_clock_hz=sim.get('analysis_clock_hz',25000000)),
    protocol=dict(format_version=2,chunks=240,pixels_per_chunk=240,ack_bytes=48,result_bytes=24),
    boards=boards,simulation=sim,main_source_unchanged=True,
    hardware_validation='PENDING; see hardware_validation.json when present')
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
with zipfile.ZipFile(OUT/'source_snapshot.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for p in ROOT.rglob('*'):
        if p.is_file() and not any(part.startswith('output') or part == '__pycache__' or part.endswith('_Runs') for part in p.relative_to(ROOT).parts):
            archive.write(p,'camera_net/'+p.relative_to(ROOT).as_posix())
    for folder in ['user_source','td_project/al_ip']:
        for p in (ROOT.parents[1]/folder).rglob('*'):
            if p.is_file():archive.write(p,'baseline/'+p.relative_to(ROOT.parents[1]).as_posix())
    for name in ['camera_to_dsi_display.al','camera_to_dsi_display.sdc']:
        archive.write(ROOT.parents[1]/'td_project'/name,'baseline/td_project/'+name)
firmware=OUT/'firmware';firmware.mkdir(exist_ok=True)
for name in ['build/anlu_app.elf','camera_net_ram.cfg','ph1p35_mcu_ir8.cfg','anlu_app_camera_net.launch']:
    shutil.copy2(ROOT.parents[1]/'FDwork/anlu_app'/name,firmware/Path(name).name)
print(json.dumps(report,ensure_ascii=False))
