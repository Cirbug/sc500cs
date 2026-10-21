from pathlib import Path
import json,hashlib,datetime,shutil
ROOT=Path(__file__).resolve().parent
BANK=Path(r'C:\Users\21397\Desktop\bank\camera_net_20261019')
records=[]
for name,board,bit in [('eg_sram_download.txt','EG4D20EG176','eg_image_sink.bit'),
                       ('main_sram_download.txt','PH1P35MDG324','camera_network.bit')]:
    log=(BANK/name).read_text(encoding='utf-8')
    tail=log[log.rfind('RUN-1002 : start command "download -bit'):]
    assert ('camera_net\\output\\'+bit) in tail
    assert 'Chip validation success: '+board in tail and 'GUI-1001 : Downloading succeeded!' in tail
    assert 'ERROR' not in tail
    records.append({'board':board,'bit':bit,'sha256':hashlib.sha256((ROOT/'output'/bit).read_bytes()).hexdigest(),
                    'mode':'PROGRAM_SRAM','download':'SUCCESS','evidence':name})
    shutil.copy2(BANK/name,ROOT/'output'/name)
report={'recorded':datetime.datetime.now().isoformat(timespec='seconds'),'downloads':records,
 'flash_changed':False,'image_recognition_verified_on_hardware':False,
 'display_observation':'AWAITING_USER_HDMI_CONFIRMATION',
 'serial':'COM6 startup capture had no new main-program messages; not proof of MCU boot or network failure.'}
(ROOT/'output/hardware_validation.json').write_text(json.dumps(report,indent=2))
p=ROOT/'output/validation.json';r=json.loads(p.read_text());r['hardware_validation']='BOTH_SRAM_DOWNLOADS_SUCCESS; CAMERA_AND_RECOGNITION_CONFIRMATION_PENDING';p.write_text(json.dumps(r,indent=2))
print(json.dumps(report))
