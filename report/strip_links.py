import os
import re
import shutil
import zipfile

root = r"C:\Users\XIAOXIAO\Desktop\fpga\sc500cs\sc500cs\report"
src = os.path.join(root, "report_main.docx")
tmp = os.path.join(root, "report_main_nolink.docx")

with zipfile.ZipFile(src, "r") as zin:
    items = {name: zin.read(name) for name in zin.namelist()}

doc = items["word/document.xml"].decode("utf-8")
doc = re.sub(r'\s+r:link="[^"]*"', "", doc)
items["word/document.xml"] = doc.encode("utf-8")

rels_name = "word/_rels/document.xml.rels"
if rels_name in items:
    rels = items[rels_name].decode("utf-8")
    # Drop external picture links only; keep any hyperlink relationships.
    rels = re.sub(
        r'<Relationship[^>]*TargetMode="External"[^>]*/>',
        "",
        rels,
    )
    items[rels_name] = rels.encode("utf-8")

with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for name, data in items.items():
        zout.writestr(name, data)

shutil.move(tmp, src)
print("stripped external picture links")
