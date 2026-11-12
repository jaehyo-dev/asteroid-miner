"""v0.8.0 4b단계: capture_web.cjs 프레임(1280x720)을 GIF로 묶고(15장/초, 4초), 보조 무기마다 1·3·5단계 비교 그림을 만든다.
실행: python3 review/v080_step4b/make_gifs.py <프레임 부모 폴더>
→ review/v080_step4b/gif/<무기>_<단계>.gif, review/v080_step4b/sheet_<무기>.png
비교 그림 칸: 우주선 둘레(가운데 560x360)를 자른 것. 검수하며 고른 프레임(picks.json, 장면 → 프레임 번호)을 쓰고,
없으면 밝고 채도 높은 픽셀이 가장 많은 프레임을 고른다."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, "gif"), exist_ok=True)
CROP = (640 - 280, 360 - 180, 640 + 280, 360 + 180)
FONT = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 24)
NAMES = {"missile": "유도 미사일 포드", "blackhole": "블랙홀 발사기", "saw": "궤도 톱날", "mine": "기뢰 살포기", "coil": "방전 코일", "wave": "채굴 펄스"}


def score(im):
    """효과 픽셀 수: 밝고(값 > 150) 채도가 있는(최대-최소 > 60) 픽셀"""
    px = im.crop(CROP).resize((140, 90), Image.NEAREST).getdata()
    return sum(1 for r, g, b in px if max(r, g, b) > 150 and max(r, g, b) - min(r, g, b) > 60)


picks_path = os.path.join(here, "picks.json")
picks = json.load(open(picks_path)) if os.path.exists(picks_path) else {}
best = {}
for name in sorted(os.listdir(src)):
    folder = os.path.join(src, name)
    if not os.path.isdir(folder):
        continue
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    frames = [Image.open(os.path.join(folder, f)).convert("RGB") for f in files]
    pal = frames[len(frames) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in frames]
    path = os.path.join(here, "gif", f"{name}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=66, loop=0, optimize=True)
    print(name, len(out), os.path.getsize(path) // 1024, "KB")
    best[name] = (frames[picks[name]] if name in picks else max(frames, key=score)).crop(CROP)

for wid, title in NAMES.items():
    cells = [best.get(f"{wid}_{s}") for s in (1, 3, 5)]
    if not all(cells):
        continue
    w, h = cells[0].size
    sheet = Image.new("RGB", (w * 3 + 8 * 4, h + 48), (20, 17, 28))
    d = ImageDraw.Draw(sheet)
    for i, (cell, stage) in enumerate(zip(cells, (1, 3, 5))):
        x = 8 + i * (w + 8)
        sheet.paste(cell, (x, 40))
        d.text((x, 8), f"{title} {stage}단계", font=FONT, fill=(254, 248, 229))
    sheet.save(os.path.join(here, f"sheet_{wid}.png"))
    print("sheet", wid)
