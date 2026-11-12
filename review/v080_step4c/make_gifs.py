"""v0.8.0 4c단계: capture_web.cjs 프레임(1280x720 = 출격 화면 2배)으로 GIF(15장/초, 4초), 1·3·5단계 그림,
고치기 전(4b sheet)·후 비교 그림, 5단계 4배 확대 정지 화면을 만든다.
실행: python3 review/v080_step4c/make_gifs.py <프레임 부모 폴더>
picks.json: 장면 → 비교 그림에 쓸 프레임 번호, zoom.json: 장면 → [프레임 번호, 화면 x, 화면 y] (확대 가운데, 1280x720 기준)"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
before_dir = os.path.join(here, "../v080_step4b")
os.makedirs(os.path.join(here, "gif"), exist_ok=True)
CROP = (640 - 280, 360 - 180, 640 + 280, 360 + 180)  # 4b 비교 그림과 같은 자리
FONT = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 24)
NAMES = {"blackhole": "블랙홀 발사기", "wave": "채굴 펄스", "mine": "기뢰 살포기"}
BG = (20, 17, 28)


def load(path, default):
    return json.load(open(path)) if os.path.exists(path) else default


picks = load(os.path.join(here, "picks.json"), {})
zoom = load(os.path.join(here, "zoom.json"), {})
frames = {}
for name in sorted(os.listdir(src)):
    folder = os.path.join(src, name)
    if not os.path.isdir(folder):
        continue
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    frames[name] = [Image.open(os.path.join(folder, f)).convert("RGB") for f in files]
    pal = frames[name][len(files) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    # 부하로 받은 프레임이 모자라 같은 그림이 이어지면 한 장으로 합치고 시간을 더한다 (Pillow가 그냥 합치면 GIF가 짧아짐)
    out, durs = [], []
    for i, im in enumerate(frames[name]):
        d = 60 if i % 3 == 2 else 70  # GIF는 10ms 단위라 70·70·60으로 평균 1/15초 (60장 = 4.0초)
        q = im.quantize(palette=pal, dither=Image.Dither.NONE)
        if out and q.tobytes() == out[-1].tobytes():
            durs[-1] += d
        else:
            out.append(q)
            durs.append(d)
    path = os.path.join(here, "gif", f"{name}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=durs, loop=0, optimize=True)
    print(name, len(out), os.path.getsize(path) // 1024, "KB")

for wid, title in NAMES.items():
    cells = [frames[f"{wid}_{s}"][picks.get(f"{wid}_{s}", 30)].crop(CROP) for s in (1, 3, 5) if f"{wid}_{s}" in frames]
    if len(cells) < 3:
        continue
    w, h = cells[0].size
    sheet = Image.new("RGB", (w * 3 + 8 * 4, h + 48), BG)
    d = ImageDraw.Draw(sheet)
    for i, (cell, stage) in enumerate(zip(cells, (1, 3, 5))):
        x = 8 + i * (w + 8)
        sheet.paste(cell, (x, 40))
        d.text((x, 8), f"{title} {stage}단계 (후)", font=FONT, fill=(254, 248, 229))
    sheet.save(os.path.join(here, f"sheet_{wid}.png"))
    # 고치기 전(4b) 위, 후 아래
    old = Image.open(os.path.join(before_dir, f"sheet_{wid}.png")).convert("RGB")
    both = Image.new("RGB", (max(old.width, sheet.width), old.height + sheet.height + 48), BG)
    d = ImageDraw.Draw(both)
    d.text((8, 8), "위: 고치기 전 (v080_step4b)   아래: 고친 뒤", font=FONT, fill=(246, 206, 80))
    both.paste(old, (0, 40))
    both.paste(sheet, (0, 48 + old.height))
    both.save(os.path.join(here, f"compare_{wid}.png"))
    print("compare", wid)

for scene, (idx, cx, cy) in zoom.items():
    if scene not in frames:
        continue
    # 1280x720은 이미 2배라 280x200(게임 픽셀 140x100)을 다시 2배 → 게임 픽셀 4배 560x400 (nearest)
    im = frames[scene][idx].crop((cx - 140, cy - 100, cx + 140, cy + 100)).resize((560, 400), Image.NEAREST)
    im.save(os.path.join(here, f"zoom4x_{scene}.png"))
    print("zoom", scene)
