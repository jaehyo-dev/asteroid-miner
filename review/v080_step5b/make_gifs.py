"""v0.8.0 5b단계: capture_web.cjs 프레임(1280x720 = 출격 화면 2배)을 GIF로 묶고(15장/초, 6초),
다시 만든 진화 4개마다 5단계와 진화를 나란히 놓은 비교 그림(compare_<무기>.png)을 만든다.
실행: python3 review/v080_step5b/make_gifs.py <프레임 부모 폴더>
비교 칸은 우주선 둘레(가운데 640x400)를 자른 것: picks.json(장면 → 프레임 번호들)이 있으면 그 프레임들, 없으면 효과 픽셀이 가장 많은 프레임 하나."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, "gif"), exist_ok=True)
CROP = (640 - 320, 360 - 200, 640 + 320, 360 + 200)
## 비교 칸을 위로 옮겨 자를 양 (블랙홀은 적이 모인 위쪽으로 던져져 가운데를 자르면 빠진다)
LIFT = {"blackhole": 100}
FONT = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 24)
NAMES = {"saw": ("궤도 톱날", "회전 충각"), "mine": ("기뢰 살포기", "연소 기뢰선"), "wave": ("채굴 펄스", "공명 파쇄"), "blackhole": ("블랙홀 발사기", "정지장 붕괴탄")}


def score(im):
    """효과 픽셀 수: 밝고(값 > 150) 채도가 있는(최대-최소 > 60) 픽셀"""
    px = im.crop(CROP).resize((160, 100), Image.NEAREST).getdata()
    return sum(1 for r, g, b in px if max(r, g, b) > 150 and max(r, g, b) - min(r, g, b) > 60)


picks_path = os.path.join(here, "picks.json")
picks = json.load(open(picks_path)) if os.path.exists(picks_path) else {}
best = {}
for name in sorted(os.listdir(src)):
    folder = os.path.join(src, name)
    if not os.path.isdir(folder) or name.split("_")[0] not in NAMES:
        continue
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    frames = [Image.open(os.path.join(folder, f)).convert("RGB") for f in files]
    pal = frames[len(frames) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in frames]
    path = os.path.join(here, "gif", f"{name}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=66, loop=0, optimize=True)
    print(name, len(out), os.path.getsize(path) // 1024, "KB")
    chosen = picks.get(name) or [max(range(len(frames)), key=lambda i: score(frames[i]))]
    up = LIFT.get(name.split("_")[0], 0)
    best[name] = [frames[i].crop((CROP[0], CROP[1] - up, CROP[2], CROP[3] - up)) for i in chosen]

for wid, (sub, evo) in NAMES.items():
    left, right = best.get(f"{wid}_5"), best.get(f"{wid}_evo")
    if not left or not right:
        continue
    rows = max(len(left), len(right))
    w, h = left[0].size
    sheet = Image.new("RGB", (w * 2 + 8 * 3, (h + 8) * rows + 40), (20, 17, 28))
    d = ImageDraw.Draw(sheet)
    for i, (cells, title) in enumerate(((left, f"{sub} 5단계"), (right, f"진화: {evo}"))):
        x = 8 + i * (w + 8)
        d.text((x, 8), title, font=FONT, fill=(254, 248, 229) if i == 0 else (255, 37, 103))
        for r, cell in enumerate(cells):
            sheet.paste(cell, (x, 40 + r * (h + 8)))
    sheet.save(os.path.join(here, f"compare_{wid}.png"))
    print("compare", wid)
