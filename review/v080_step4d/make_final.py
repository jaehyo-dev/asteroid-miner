"""v0.8.0 4d단계 확정 기뢰 자료: 4c 촬영 도구 프레임으로 1·3·5단계 4배 확대 그림 + 5단계 GIF를 만든다.
촬영: CHROME=<headless shell> NODE_PATH=… FRAMES=<폴더> node review/v080_step4c/capture_web.cjs mine_1 mine_3 mine_5
실행: python3 review/v080_step4d/make_final.py <프레임 폴더>
프레임은 1280x720 = 게임 2배. PICKS = 장면 → [프레임, 화면 x, 화면 y] (빨간 점이 켜진 기뢰 가운데, 우주선과 떨어진 것)"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
FONT = ImageFont.truetype(os.path.join(here, "../../assets/fonts/galmuri/Galmuri11.ttf"), 24)
BG = (20, 17, 28)
TEXT = (254, 248, 229)
PICKS = {"mine_1": ["040", 522, 250], "mine_3": ["040", 546, 244], "mine_5": ["049", 762, 322]}
HALF = 20  # 게임 픽셀 (확대 칸 = 40x40 게임 픽셀)

cells = []
for scene, (frame, x, y) in PICKS.items():
    im = Image.open(os.path.join(src, scene, frame + ".png")).convert("RGB")
    crop = im.crop((x - HALF * 2, y - HALF * 2, x + HALF * 2, y + HALF * 2))  # 화면은 2배라 게임 HALF = 화면 2*HALF
    cells.append(crop.resize((HALF * 8, HALF * 8), Image.NEAREST))  # 게임 4배
w = HALF * 8
sheet = Image.new("RGB", (16 + (w + 24) * 3, 56 + 32 + w + 16), BG)
d = ImageDraw.Draw(sheet)
d.text((16, 12), "확정 기뢰 · 게임 4배 · 빨간 점 켜짐", font=FONT, fill=(246, 206, 80))
for i, (label, c) in enumerate(zip(["1단계", "3단계", "5단계"], cells)):
    x = 16 + i * (w + 24)
    d.text((x, 56), label, font=FONT, fill=TEXT)
    sheet.paste(c, (x, 88))
sheet.save(os.path.join(here, "mine_final_4x.png"))
print("mine_final_4x.png", sheet.size)

folder = os.path.join(src, "mine_5")
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
path = os.path.join(here, "gif", "mine_final_5.gif")
out[0].save(path, save_all=True, append_images=out[1:], duration=durs, loop=0, optimize=True)
print(path, len(out), sum(durs), "ms", os.path.getsize(path) // 1024, "KB")
