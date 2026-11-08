"""워프 게이트 고리 그림 정리: Codex 원본 assets/raw/run/gate_ring.png → assets/sprites/gate/gate_ring.png.
- 마젠타 배경을 빼고 블록마다 가장 많은 색으로 68x68 격자에 맞춘 뒤 void32 색으로 바꾼다 (make_card_art.py와 같은 방식).
- 원본은 조각 8개가 45도마다 놓인 고리다. 가운데에서 본 각도로 번호를 매겨(0 = 오른쪽, 시계 방향 45도씩) 68칸 8개를 가로로 저장한다.
실행: python3 tools/make_gate_art.py"""
import math
import os
import re
from collections import Counter

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
RAW = os.path.join(ROOT, "assets/raw/run/gate_ring.png")
OUT = os.path.join(ROOT, "assets/sprites/gate/gate_ring.png")
SIZE = 68
SEGMENTS = 8
PAL = [tuple(int(c) for c in line.split()[:3]) for line in open(os.path.join(ROOT, "assets/palette/void32.gpl")) if re.match(r"\s*\d", line)]


def is_bg(p) -> bool:
    return p[0] > 170 and p[2] > 170 and p[1] < 110


def near(p):
    return min(PAL, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, p)))


def to_grid(im: Image.Image) -> Image.Image:
    """그림이 있는 정사각 영역을 SIZE 칸으로 나눠 칸마다 가장 많은 색을 고른다."""
    px = im.load()
    xs = [x for x in range(0, im.width, 2) for y in range(0, im.height, 2) if not is_bg(px[x, y])]
    ys = [y for y in range(0, im.height, 2) for x in range(0, im.width, 2) if not is_bg(px[x, y])]
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    step = side / SIZE
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for j in range(SIZE):
        for i in range(SIZE):
            cnt = Counter()
            for y in range(int(cy - side / 2 + j * step), min(int(cy - side / 2 + (j + 1) * step), im.height)):
                for x in range(int(cx - side / 2 + i * step), min(int(cx - side / 2 + (i + 1) * step), im.width)):
                    if 0 <= x and 0 <= y:
                        cnt["bg" if is_bg(px[x, y]) else near(px[x, y])] += 1
            if not cnt:
                continue
            top = cnt.most_common(1)[0][0]
            if top == "bg" and cnt["bg"] <= sum(cnt.values()) * 0.6:  # 얇은 외곽선을 지키려고
                top = [k for k, _ in cnt.most_common() if k != "bg"][0]
            if top != "bg":
                out.putpixel((i, j), (*top, 255))
    return out


def split(grid: Image.Image) -> Image.Image:
    """픽셀마다 가운데에서 본 각도로 조각을 정한다 (격자에 맞추면 조각 사이 틈이 대각선으로 붙어 덩어리로는 못 나눈다)."""
    a = np.array(grid)
    sheet = np.zeros((SIZE, SIZE * SEGMENTS, 4), np.uint8)
    ys, xs = np.nonzero(a[..., 3] > 0)
    for y, x in zip(ys, xs):
        angle = math.atan2(y + 0.5 - SIZE / 2, x + 0.5 - SIZE / 2)
        index = round(angle / (math.tau / SEGMENTS)) % SEGMENTS
        sheet[y, index * SIZE + x] = a[y, x]
    return Image.fromarray(sheet)


if __name__ == "__main__":
    split(to_grid(Image.open(RAW).convert("RGB"))).save(OUT)
    print("assets/sprites/gate/gate_ring.png 다시 만듦")
