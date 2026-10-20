import os
root = r"C:\Users\XIAOXIAO\Desktop\fpga\sc500cs\sc500cs\report"
src = open(os.path.join(root, "report.html"), encoding="utf-8").read()
base = "file:///C:/Users/XIAOXIAO/Desktop/fpga/sc500cs/sc500cs/report/assets/"
src = src.replace('src="assets/', 'src="' + base)
out = os.path.join(root, "report_for_word.html")
open(out, "w", encoding="utf-8", newline="\n").write(src)
print("written", out, len(src))
