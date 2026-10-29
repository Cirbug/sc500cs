import os
import shutil

# Real slave project (D:\2026fpga\EG4D20 is a junction to this folder)
root = r"C:\Users\21397\Desktop\fpga1\sc500cs\EG4D20_cnn_build_20261028"
path = os.path.join(root, r"uisrc\03_ip\uiudp_stack\uimac_rx.v")
backup_dir = os.path.join(root, "backup_before_bcast_20261029")
os.makedirs(backup_dir, exist_ok=True)

old = b"if({mac_frame_type[15:8],mac_rdata_r4} == ARP_TYPE) begin"
new = b"if(({mac_frame_type[15:8],mac_rdata_r4} == ARP_TYPE) || ({mac_frame_type[15:8],mac_rdata_r4} == IP_TYPE)) begin"

with open(path, "rb") as f:
    data = f.read()

n = data.count(old)
print("target file:", path)
print("matches:", n)

if n == 1:
    bak = os.path.join(backup_dir, "uimac_rx.v.orig")
    if not os.path.exists(bak):
        with open(bak, "wb") as f:
            f.write(data)
        print("backup written:", bak)
    else:
        print("backup already exists:", bak)
    with open(path, "wb") as f:
        f.write(data.replace(old, new))
    print("PATCHED")
else:
    print("NOT PATCHED")
