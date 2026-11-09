"""shoot_holo.gd 프레임 → GIF(그 화면의 정수 배율로 줄임 없음, 창 안쪽 전체)와 40각도 확인표. 실행: python3 make_gif.py pc 2"""
import os
import sys

from PIL import Image

D = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/소행성 광부/holo/")
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
tag, scale = sys.argv[1], int(sys.argv[2])  # 창의 정수 배율로 줄여 논리 화소 그대로 저장
frames = []
for f in sorted(os.listdir(D + tag)):
    im = Image.open(D + tag + "/" + f).convert("RGB")
    frames.append(im.resize((im.width // scale, im.height // scale), Image.NEAREST))
pal = frames[0].quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE)
out = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
out[0].save(f"{OUT}hangar_holo_{tag}.gif", save_all=True, append_images=out[1:], duration=75, loop=0, disposal=1)
print(tag, frames[0].size, os.path.getsize(f"{OUT}hangar_holo_{tag}.gif") // 1024, "KB")
frames[0].resize((frames[0].width * scale, frames[0].height * scale), Image.NEAREST).save(f"{OUT}hangar_holo_{tag}.png")
