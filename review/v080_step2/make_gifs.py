"""v0.8.0 2단계: capture_weapon_gif.gd가 찍은 프레임(1280x720)을 반으로 줄여(출격 화면 2배 → 1배, nearest) GIF로 묶는다.
실행: python3 review/v080_step2/make_gifs.py <프레임 폴더들의 부모> → review/v080_step2/gif/<이름>.gif"""
import os
import sys

from PIL import Image

src = sys.argv[1]
dst = "review/v080_step2/gif"
os.makedirs(dst, exist_ok=True)
for name in sorted(os.listdir(src)):
    files = sorted(f for f in os.listdir(os.path.join(src, name)) if f.endswith(".png"))
    if not files:
        continue
    frames = []
    for f in files:
        im = Image.open(os.path.join(src, name, f)).convert("RGB")
        im = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
        frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    frames[0].save(os.path.join(dst, f"{name}.gif"), save_all=True, append_images=frames[1:], duration=66, loop=0, optimize=True)
    print(name, len(frames), os.path.getsize(os.path.join(dst, f"{name}.gif")) // 1024, "KB")
