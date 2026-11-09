"""기지 정거장 그림 굽기: Codex 원본 시트(assets/raw/base_v070*/)를 1배 격자로 정리해 assets/sprites/station/에 저장한다.
실행: python3 tools/bake_base.py
- 건물·꾸밈·착륙장은 void32로, 갑판·통로·땅은 기지 전용 어두운 회색(ART_BIBLE 3번)으로 줄인다 (밝기 순서: 건물 > 갑판 > 통로).
- 배치는 게임(scripts/logic/base_layout.gd)이 칸 데이터로 정한다. 여기서는 부품만 굽는다."""
import os
import re
from collections import Counter

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets/sprites/station")
RUN = os.path.join(ROOT, "assets/sprites/run")
PAL = [tuple(int(c) for c in line.split()[:3]) for line in open(os.path.join(ROOT, "assets/palette/void32.gpl")) if re.match(r"\s*\d", line)]
## 기지 전용 어두운 회색 4색 + void32의 어두운 색 (ART_BIBLE 3번, assets/palette/base_station.gpl)
BASE_DARK = [(20, 18, 26), (30, 26, 38), (36, 32, 44), (48, 43, 58)]
DARK = [(0, 0, 0), *BASE_DARK, (60, 53, 68), (92, 81, 100)]
## 평균 밝기 배율
K_DECK, K_WALK, K_GROUND, K_PAD, K_EMPTY = 0.85, 0.5, 0.6, 0.8, 0.8
## 칸 크기 (그림 픽셀). 폰과 PC가 같은 그림을 쓰고 칸 간격만 다르다
UNIT = 1.1
PLATE_W = round(116 * UNIT)
BUILD_W = round(80 * UNIT)
PAD_W = 140
## 땅: 지도(칸 ±3열)를 다 덮는 큰 소행성 한 장. shortcut: 지도가 이보다 커지면 다시 굽는다
GROUND_SIZE = (1400, 620)
_near = {}


def is_bg(p):
    return p[0] > 170 and p[2] > 170 and p[1] < 110


def near(p):
    if p not in _near:
        _near[p] = min(PAL, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, p)))
    return _near[p]


def to_grid(im, box, w, h):
    """box 영역을 w x h 칸으로 나눠 칸마다 가장 많은 색 (void32). 배경이 60%를 넘는 칸만 비운다"""
    a = np.array(im.crop(box).convert("RGB"))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ys = np.linspace(0, a.shape[0], h + 1).astype(int)
    xs = np.linspace(0, a.shape[1], w + 1).astype(int)
    for j in range(h):
        for i in range(w):
            cell = a[ys[j]:ys[j + 1], xs[i]:xs[i + 1]].reshape(-1, 3)[::2]
            cnt = Counter("bg" if is_bg(tuple(p)) else near(tuple(int(v) for v in p)) for p in cell)
            top = cnt.most_common(1)[0][0]
            if top == "bg" and cnt["bg"] <= sum(cnt.values()) * 0.6:
                top = [k for k, _ in cnt.most_common() if k != "bg"][0]
            if top != "bg":
                out.putpixel((i, j), (*top, 255))
    return out


def content_box(im):
    a = np.array(im.convert("RGB")).astype(int)
    ys, xs = np.nonzero(~((a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 110)))
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def grid_cells(im, cols, rows):
    """시트를 칸으로 나눠 칸마다 그림이 있는 영역"""
    out = []
    for r in range(rows):
        for c in range(cols):
            x0, y0 = im.width * c // cols, im.height * r // rows
            b = content_box(im.crop((x0, y0, im.width * (c + 1) // cols, im.height * (r + 1) // rows)))
            out.append((x0 + b[0], y0 + b[1], x0 + b[2], y0 + b[3]))
    return out


def sprite(sheet, i, w, h=None):
    im, cells = sheet
    box = cells[i]
    return to_grid(im, box, w, h or round((box[3] - box[1]) * w / (box[2] - box[0])))


def dim(img, k, dark=True):
    """k배 어둡게. dark면 어두운 회색으로(색이 빠져 눈에 덜 띔), 아니면 void32로"""
    a = np.array(img).copy()
    for c in {tuple(p) for p in a[a[..., 3] > 0][:, :3].tolist()}:
        v = tuple(round(x * k) for x in c)
        a[(a[..., :3] == c).all(axis=-1), :3] = min(DARK, key=lambda d: sum((p - q) ** 2 for p, q in zip(d, v))) if dark else near(v)
    return Image.fromarray(a, "RGBA")


def load(rel, cols, rows):
    im = Image.open(os.path.join(ROOT, "assets/raw", rel))
    return im, grid_cells(im, cols, rows)


def stripes(colors, vertical=False):
    """가장자리 띠의 반복 칸: 색 줄 몇 개 (기둥 없이). 가로 띠는 위에서 아래로, 세로 띠는 왼쪽에서 오른쪽으로"""
    a = np.array([[(*c, 255)] for c in colors], np.uint8)
    img = Image.fromarray(np.repeat(a, 4, axis=1), "RGBA")
    return img.transpose(Image.Transpose.TRANSPOSE) if vertical else img


def ship():
    """팩 우주선 위쪽 방향 한 칸 + 포 + 엔진 (48x48 칸 그대로: 불꽃과 위치가 맞음)"""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    for name in ("ship_engine", "ship_cannon", "ship"):
        part = Image.open(os.path.join(RUN, name + ".png")).convert("RGBA").crop((0, 0, 48, 48))
        img.paste(part, (0, 0), part)
    return img


def half_pill():
    """이름표 판: 카드 프레임 알약을 절반 크기로 (양끝 장식이 글자를 덜 차지하게)"""
    src = Image.open(os.path.join(RUN, "card/pill.png")).convert("RGBA")
    return src.resize((src.width // 2, src.height // 2), Image.NEAREST)


def build() -> dict[str, Image.Image]:
    square = load("base_v070b/deck_square.png", 3, 2)
    props = load("base_v070b/station_props.png", 4, 2)
    old = load("base_v070/base_buildings.png", 3, 2)
    new = load("base_v070b/base_buildings2.png", 3, 1)
    # 착륙장이 시트 3등분 칸을 넘어서 칸은 직접 나눈다 (왼쪽 갑판, 가운데 관제탑, 오른쪽 연료관)
    pad_im = Image.open(os.path.join(ROOT, "assets/raw/base_v070d/station_pad.png"))
    pad_boxes = []
    for x0, x1 in ((0, 600), (600, 960), (960, pad_im.width)):
        b = content_box(pad_im.crop((x0, 0, x1, pad_im.height)))
        pad_boxes.append((x0 + b[0], b[1], x0 + b[2], b[3]))
    pad = (pad_im, pad_boxes)
    icons = load("base_v070c/base_icons.png", 3, 3)
    plate = sprite(square, 0, PLATE_W)
    out = {
        "deck": dim(plate, K_DECK),
        "deck_lit": plate,
        "deck_empty": dim(sprite(square, 1, PLATE_W), K_EMPTY, dark=False),
        "walk_h": dim(sprite(square, 2, round(44 * UNIT)), K_WALK),
        "walk_v": dim(sprite(square, 3, round(20 * UNIT)), K_WALK),
        "pad": dim(sprite(pad, 0, PAD_W), K_PAD, dark=False),
        "tower": sprite(pad, 1, 34),
        "fuel": sprite(pad, 2, 48),
        "edge_h": stripes([BASE_DARK[3], BASE_DARK[2], BASE_DARK[1], BASE_DARK[0]]),
        "edge_v": stripes([BASE_DARK[0], BASE_DARK[2], BASE_DARK[0]], True),
        "solar": sprite(props, 2, round(36 * UNIT)),
        "mast": sprite(props, 0, round(18 * UNIT)),
        "dish": sprite(props, 1, round(30 * UNIT)),
        "tanks": sprite(props, 7, round(34 * UNIT)),
        "beacon_on": sprite(props, 3, round(14 * UNIT)),
        "beacon_off": sprite(props, 4, round(14 * UNIT)),
        "icon_empty": sprite(icons, 8, 16),
        "ship": ship(),
        "pill_half": half_pill(),
    }
    ground = Image.open(os.path.join(ROOT, "assets/raw/base_v070/base_ground.png"))
    out["ground"] = dim(to_grid(ground, content_box(ground), *GROUND_SIZE), K_GROUND)
    for name, i in {"research": 0, "hangar": 1, "storage": 2, "museum": 3, "drone": 4}.items():
        out["b_" + name] = sprite(old, i, BUILD_W)
    for name, i in {"weapon": 0, "evolve": 1, "planet": 2}.items():
        out["b_" + name] = sprite(new, i, BUILD_W)
    return out


def mean_light(img):
    a = np.array(img)
    return float((a[a[..., 3] > 0][:, :3] * [0.299, 0.587, 0.114]).sum(axis=1).mean())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    parts = build()
    for name, img in parts.items():
        img.save(f"{OUT}/{name}.png")
    with open(os.path.join(ROOT, "assets/palette/base_station.gpl"), "w") as f:
        f.write("GIMP Palette\nName: base_station\n#\n" + "".join(f"{r} {g} {b}\n" for r, g, b in BASE_DARK))
    print(f"정거장 그림 {len(parts)}장 → assets/sprites/station/")
