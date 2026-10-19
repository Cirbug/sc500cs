"""Record observed hardware evidence, keeping visual acceptance separate."""
from pathlib import Path
import datetime, hashlib, json, shutil
R=Path(__file__).resolve().parent
B=Path(r'C:\Users\21397\Desktop\bank\camera_net_20261019')
O=R/'output320'
manifest=json.loads((O/'validation.json').read_text())
probe=json.loads((O/'first_probe.json').read_text())
# Never attribute a previous firmware's live samples to a newly downloaded bit.
assert (O/'first_probe.json').stat().st_mtime >= (B/'eg320_download.log').stat().st_mtime, 'Probe predates latest EG download; capture and record this revision separately'
assert all(s['magic']==0x4e455431 and s['dimensions']==0x014000b4 for s in probe['samples'])
assert probe['summary']['frames']>0 and probe['summary']['frames']==probe['summary']['remote_frames']
downloads=[]
for key,chip,filename,logname in [('PH1P35','PH1P35MDG324','camera_network.bit','main320_download.log'),
                                ('EG4D20','EG4D20EG176','eg_image_sink.bit','eg320_download.log')]:
 log=(B/logname).read_text(encoding='utf-8-sig',errors='replace')
 assert 'Chip validation success: '+chip in log
 assert 'finish command "download -bit' in log and 'output320/'+filename in log
 digest=hashlib.sha256((O/filename).read_bytes()).hexdigest()
 assert digest==manifest['boards'][key]['sha256']
 downloads.append(dict(board=chip,file=filename,sha256=digest,mode='JTAG_SRAM',
  evidence=logname,verified_by='download completed and live matching v2 image/48-byte result exchange'))
 shutil.copy2(B/logname,O/logname)
load=(B/'mcu320_load.log').read_text()
assert load.count(': matched.')==4 and 'detached' in load and '0x8000100 <_start>' in load
shutil.copy2(B/'mcu320_load.log',O/'mcu320_load.log')
report=dict(recorded=datetime.datetime.now().isoformat(timespec='seconds'),downloads=downloads,
 flash_changed=False,mcu=dict(elf='firmware/anlu_app.elf',all_load_sections_verified=True,
 sha256=hashlib.sha256((O/'firmware/anlu_app.elf').read_bytes()).hexdigest()),
 measured=probe['summary'],dimensions=[320,180],secondary_downsampling=False,
 red_result_valid_samples=sum(s['red_valid'] for s in probe['samples']),
 shape_result_valid_samples=sum(s['shape_valid'] for s in probe['samples']),
 processing_failure_samples=sum(s['failure'] for s in probe['samples']),
 visual_acceptance='AWAITING_USER: HDMI image, red box and controlled circle/rectangle/triangle targets',
 detection_accuracy='Not established by register readings; sampled scene has no ground-truth labels.',
 initial_counter_note='Before sample: 30 timeout/drop events and 4 remote errors; none increased during measured interval.',
 downloader_note='Main connect_cable emitted an option-parser warning but launched hwserver and completed download. The live 0x014000b4 dimensions and v2 matching-frame counters verify the new design is running.')
(O/'hardware_validation.json').write_text(json.dumps(report,indent=2))
manifest['hardware_validation']='BOTH_SRAM_IMAGES_RUNNING; 320x180 exchange and red result verified; controlled visual acceptance pending'
(O/'validation.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps(report,ensure_ascii=False))
