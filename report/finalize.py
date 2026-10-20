import os
import shutil
import zipfile

root = r"C:\Users\XIAOXIAO\Desktop\fpga\sc500cs\sc500cs\report"
docx = os.path.join(root, "report_main.docx")
pdf = os.path.join(root, "report_main.pdf")
base = "基于FPGA的多功能实时摄像头系统_设计报告"
targets = [
    os.path.join(root, base + ".docx"),
    os.path.join(r"C:\Users\XIAOXIAO\Desktop\fpga\sc500cs\sc500cs", base + ".docx"),
    os.path.join(r"C:\Users\XIAOXIAO\Desktop", base + ".docx"),
]
for t in targets:
    shutil.copy2(docx, t)
    print("docx ->", t)
pdf_targets = [
    os.path.join(root, base + ".pdf"),
    os.path.join(r"C:\Users\XIAOXIAO\Desktop\fpga\sc500cs\sc500cs", base + ".pdf"),
    os.path.join(r"C:\Users\XIAOXIAO\Desktop", base + ".pdf"),
]
for t in pdf_targets:
    shutil.copy2(pdf, t)
    print("pdf  ->", t)

with zipfile.ZipFile(docx) as z:
    bad = z.testzip()
    media = [n for n in z.namelist() if n.startswith("word/media")]
    print("zip_test", bad, "media", len(media))
