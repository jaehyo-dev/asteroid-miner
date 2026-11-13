"""v0.8.0 5f단계: capture_web.cjs 프레임(1280x720 = 출격 화면 2배)을 GIF로 묶고(15장/초, 6초),
공명 파쇄 정지 화면 3장(shots/)과 채굴 펄스 5단계·과충전 방전·공명 파쇄 비교 그림(compare.png)을 만든다.
실행: python3 review/v080_step5f/make_gifs.py <프레임 부모 폴더>
picks.json: GIF·정지 화면·비교 칸에 쓸 프레임 번호 (찍은 프레임을 하나씩 보고 고름)"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
for sub in ("gif", "shots"):
    os.makedirs(os.path.join(here, sub), exist_ok=True)
CROP = (640 - 320, 360 - 200, 640 + 320, 360 + 200)
FONT = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 24)
SCENES = [("wave_5", "채굴 펄스 5단계"), ("coil_evo", "과충전 방전"), ("res", "공명 파쇄")]
picks = json.load(open(os.path.join(here, "picks.json")))


def frames_of(name):
    folder = os.path.join(src, name)
    return [Image.open(os.path.join(folder, f)).convert("RGB") for f in sorted(f for f in os.listdir(folder) if f.endswith(".png"))]


cols = []
for name, title in SCENES:
    frames = frames_of(name)
    pal = frames[len(frames) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in frames]
    path = os.path.join(here, "gif", f"{name}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=66, loop=0, optimize=True)
    print(name, len(out), os.path.getsize(path) // 1024, "KB")
    cols.append((title, [frames[i].crop(CROP) for i in picks["compare"][name]]))
    if name == "res":
        for key, i in picks["shots"].items():
            frames[i].save(os.path.join(here, "shots", f"{key}.png"))

rows = max(len(c) for _, c in cols)
w, h = cols[0][1][0].size
sheet = Image.new("RGB", ((w + 8) * len(cols) + 8, (h + 8) * rows + 40), (20, 17, 28))
d = ImageDraw.Draw(sheet)
for i, (title, cells) in enumerate(cols):
    x = 8 + i * (w + 8)
    d.text((x, 8), title, font=FONT, fill=(246, 206, 80) if i == 2 else (254, 248, 229))
    for r, cell in enumerate(cells):
        sheet.paste(cell, (x, 40 + r * (h + 8)))
sheet.save(os.path.join(here, "compare.png"))
print("compare", sheet.size)
