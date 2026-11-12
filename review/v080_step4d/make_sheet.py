"""v0.8.0 4d단계: capture_web.cjs 결과로 기뢰 후보 비교 그림(mine_sheet.png)과 후보별 GIF를 만든다.
실행: python3 review/v080_step4d/make_sheet.py <프레임 폴더>
gallery.png = ?fxtest Shift+M 비교판 (1280x720 = 게임 2배, 우주선 = 화면 가운데).
비교판 자리(게임 픽셀, 우주선 기준): 후보 n·단계 t = (-100 + 40t, -40 + 40n), 오른쪽 칸 (40, -40/0/40) = 포격 탄·경비선 탄·펄스 연사포 탄"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
FONT = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 24)
SMALL = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 12)
BG = (20, 17, 28)
TEXT = (254, 248, 229)
CELL = 40  # 게임 픽셀
LOOKS = ["후보 1 둥근 몸체 + 가시", "후보 2 육각 판", "후보 3 날개 달린 위성"]
SIDE = ["적 탄 (심연의 포격)", "적 탄 (고대 경비선)", "내 탄 (펄스 연사포)"]

g = Image.open(os.path.join(src, "gallery.png")).convert("RGB")


def cell(gx, gy):
    """게임 좌표 (우주선 기준) 둘레 CELL 칸 → (1배, 4배) 그림"""
    cx, cy = 640 + gx * 2, 360 + gy * 2
    crop = g.crop((cx - CELL, cy - CELL, cx + CELL, cy + CELL))  # 2배 화면이라 게임 CELL px = 화면 2*CELL
    return crop.resize((CELL, CELL), Image.NEAREST), crop.resize((CELL * 4, CELL * 4), Image.NEAREST)


one_w, four_w = CELL, CELL * 4
block = one_w + 8 + four_w  # 1배 + 4배 한 묶음
col_w = block + 24
row_h = 40 + four_w + 16
sheet = Image.new("RGB", (16 + col_w * 4 + 16, 56 + row_h * 3), BG)
d = ImageDraw.Draw(sheet)
d.text((16, 12), "기뢰 몸체 후보 (불빛 켜진 상태) — 칸마다 왼쪽 1배(640x360 기준), 오른쪽 4배", font=FONT, fill=(246, 206, 80))
for look in range(3):
    y = 56 + look * row_h
    d.text((16, y), LOOKS[look], font=FONT, fill=TEXT)
    for i, label in enumerate(["1단계", "3단계", "5단계", SIDE[look]]):
        x = 16 + i * col_w
        gx, gy = (-100 + i * 40, -40 + look * 40) if i < 3 else (40, -40 + look * 40)
        small, big = cell(gx, gy)
        if i == 3:
            d.line((x - 12, y + 4, x - 12, y + row_h - 16), fill=(70, 60, 90), width=2)  # 비교 칸 구분
        d.text((x, y + 30), label, font=SMALL, fill=TEXT)
        sheet.paste(small, (x, y + 48 + (four_w - one_w) // 2))
        sheet.paste(big, (x + one_w + 8, y + 48))
sheet.save(os.path.join(here, "mine_sheet.png"))
print("mine_sheet.png", sheet.size)

os.makedirs(os.path.join(here, "gif"), exist_ok=True)
for name in sorted(os.listdir(src)):
    folder = os.path.join(src, name)
    if not os.path.isdir(folder):
        continue
    frames = [Image.open(os.path.join(folder, f)).convert("RGB") for f in sorted(os.listdir(folder)) if f.endswith(".png")]
    pal = frames[len(frames) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out, durs = [], []
    for i, im in enumerate(frames):
        dur = 60 if i % 3 == 2 else 70  # 70·70·60 → 평균 1/15초, 60장 = 4.0초
        q = im.quantize(palette=pal, dither=Image.Dither.NONE)
        if out and q.tobytes() == out[-1].tobytes():  # 같은 그림은 합치고 시간을 더한다
            durs[-1] += dur
        else:
            out.append(q)
            durs.append(dur)
    path = os.path.join(here, "gif", f"mine_{name}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=durs, loop=0, optimize=True)
    print(path, len(out), sum(durs), "ms", os.path.getsize(path) // 1024, "KB")
