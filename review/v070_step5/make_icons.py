"""Codex 아이콘 원본 → 48px 픽셀 아이콘 (void32 팔레트). 시안용이라 게임 폴더가 아니라 여기에 둔다.
tools/pixelate.py는 외곽선을 잃고 강조색이 바뀌어(가운데 한 픽셀만 읽음), 블록마다 가장 많은 색을 고른다.
실행: python3 review/v070_step5/make_icons.py"""
import re
from collections import Counter
from PIL import Image

RAW = "assets/raw/run/icons"
OUT = "review/v070_step5/icons"
# 이름 → (원본, 가로 구역 시작·끝 비율): 첫 장은 3개가 가로로 있어 구역을 나눈다
SRC = {"cooler": ("icons_sample.png", 0.0, 0.33), "pierce": ("icon_pierce.png", 0.0, 1.0), "drone": ("icons_sample.png", 0.67, 1.0)}
SIZE = 48
PAL = [tuple(int(c) for c in l.split()[:3]) for l in open("assets/palette/void32.gpl") if re.match(r"\s*\d", l)]


def is_bg(p):
    return p[0] > 170 and p[2] > 170 and p[1] < 110


def near(p):
    return min(PAL, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, p)))


for name, (src, x0, x1) in SRC.items():
    im = Image.open(f"{RAW}/{src}").convert("RGB")
    im = im.crop((int(im.width * x0), 0, int(im.width * x1), im.height))
    px = im.load()
    xs = [x for x in range(im.width) for y in range(0, im.height, 4) if not is_bg(px[x, y])]
    ys = [y for y in range(im.height) for x in range(0, im.width, 4) if not is_bg(px[x, y])]
    bx, by, bw, bh = min(xs), min(ys), max(xs) + 1 - min(xs), max(ys) + 1 - min(ys)
    step = max(bw, bh) / SIZE
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox, oy = (SIZE - round(bw / step)) // 2, (SIZE - round(bh / step)) // 2
    for j in range(round(bh / step)):
        for i in range(round(bw / step)):
            cnt = Counter()
            for y in range(int(by + j * step), min(int(by + (j + 1) * step), im.height)):
                for x in range(int(bx + i * step), min(int(bx + (i + 1) * step), im.width)):
                    p = px[x, y]
                    cnt["bg" if is_bg(p) else near(p)] += 1
            top = cnt.most_common(1)[0][0] if cnt else "bg"
            # 배경이 60%를 넘을 때만 비움 (1블록 안에 걸친 얇은 외곽선을 지키려고)
            if top == "bg" and cnt["bg"] <= sum(cnt.values()) * 0.6:
                top = [k for k, _ in cnt.most_common() if k != "bg"][0]
            if top != "bg":
                out.putpixel((ox + i, oy + j), (*top, 255))
    out.save(f"{OUT}/{name}.png")
    print(name, out.size, len(out.getcolors(999)) - 1, "색")
