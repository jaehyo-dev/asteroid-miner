"""v0.8.0 4단계: capture_web.cjs(Playwright headless)가 찍은 프레임(1280x720, 출격 화면 2배)을 그대로 GIF로 묶는다 (15장/초).
실행: python3 review/v080_step4/make_gifs.py <프레임 부모 폴더> → review/v080_step4/gif/<장면>.gif"""
import os
import sys

from PIL import Image

src = sys.argv[1]
dst = "review/v080_step4/gif"
os.makedirs(dst, exist_ok=True)
for name in sorted(os.listdir(src)):
    if not os.path.isdir(os.path.join(src, name)):
        continue
    files = sorted(f for f in os.listdir(os.path.join(src, name)) if f.endswith(".png"))
    if not files:
        continue
    frames = [Image.open(os.path.join(src, name, f)).convert("RGB") for f in files]
    # 팔레트는 첫 장 기준 하나로 맞춰 깜빡임과 크기를 줄인다 (픽셀 아트라 색이 적음)
    pal = frames[len(frames) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in frames]
    out[0].save(os.path.join(dst, f"{name}.gif"), save_all=True, append_images=out[1:], duration=66, loop=0, optimize=True)
    print(name, len(out), os.path.getsize(os.path.join(dst, f"{name}.gif")) // 1024, "KB")
