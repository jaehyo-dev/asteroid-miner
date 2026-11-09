"""캡처를 한 장으로: python3 sheet.py 태그 출력 이름..."""
import os, sys
from PIL import Image
D = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/소행성 광부/shots/")
tag, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
ims = [Image.open(f"{D}{n}_{tag}.png").convert("RGB") for n in names]
w, h = ims[0].size
cols = 2
rows = (len(ims) + 1) // 2
sheet = Image.new("RGB", (w * cols, h * rows))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
sheet.save(out)
