import sys

path = r"C:\Users\21397\Desktop\02_FPGA与SC500项目\EG4D20\uisrc\03_ip\uiudp_stack\uimac_rx.v"
old = b"if({mac_frame_type[15:8],mac_rdata_r4} == ARP_TYPE) begin"
new = b"if(({mac_frame_type[15:8],mac_rdata_r4} == ARP_TYPE) || ({mac_frame_type[15:8],mac_rdata_r4} == IP_TYPE)) begin"

with open(path, "rb") as f:
    data = f.read()

n = data.count(old)
print("matches:", n)
if n == 1:
    data = data.replace(old, new)
    with open(path, "wb") as f:
        f.write(data)
    print("PATCHED")
else:
    print("NOT PATCHED")
