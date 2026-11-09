"""캡처 프레임 몇 장을 한 장에 모아 본다: python3 sheet.py <태그> <장면> <시작> <끝> <간격> <출력>"""
import os, sys
from PIL import Image
D = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/소행성 광부/check")
tag, clip, a, b, step, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
ims = [Image.open(f"{D}/{tag}/{clip}/{i:04d}.png").convert("RGB") for i in range(a, b, step)]
w, h = ims[0].size
s = 0.5 if w > 900 else 0.75
w2, h2 = int(w * s), int(h * s)
cols = 3
sheet = Image.new("RGB", (cols * w2, -(-len(ims) // cols) * h2))
for n, im in enumerate(ims):
    sheet.paste(im.resize((w2, h2), Image.NEAREST), (n % cols * w2, n // cols * h2))
sheet.save(out)
