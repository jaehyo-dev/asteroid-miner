"""기지 화면 시안 만들기 (게임에는 쓰지 않음). 실행: python3 review/v070_base/make_mockups.py
Codex 원본(assets/raw/base_v070/)을 void32·1배 격자로 정리해 PC 640x360(2배로 저장)과 폰 844x390(1배)을 합성한다.
UI는 레벨업 카드의 프레임 S 부품(assets/sprites/run/card/)을 9칸 나누기로 쓴다."""
import math
import os
import random
import re
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
RAW = os.path.join(ROOT, "assets/raw/base_v070")
OUT = os.path.dirname(os.path.abspath(__file__))
CARD = os.path.join(ROOT, "assets/sprites/run/card")
RUN = os.path.join(ROOT, "assets/sprites/run")
FONT = os.path.join(ROOT, "assets/fonts/galmuri/Galmuri11.ttf")
PAL = [tuple(int(c) for c in line.split()[:3]) for line in open(os.path.join(ROOT, "assets/palette/void32.gpl")) if re.match(r"\s*\d", line)]
_near = {}
INK, GOLD, TEAL, DIM = (254, 248, 229), (246, 206, 80), (153, 233, 230), (145, 116, 135)
BACK = (7, 10, 23)


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
    m = ~((a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 110))
    ys, xs = np.nonzero(m)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def grid_cells(im, cols, rows):
    """시트를 칸으로 나눠 칸마다 그림이 있는 영역을 돌려준다"""
    out = []
    for r in range(rows):
        for c in range(cols):
            x0, y0 = im.width * c // cols, im.height * r // rows
            sub = im.crop((x0, y0, im.width * (c + 1) // cols, im.height * (r + 1) // rows))
            b = content_box(sub)
            out.append((x0 + b[0], y0 + b[1], x0 + b[2], y0 + b[3]))
    return out


def fit(im, box, width):
    h = round((box[3] - box[1]) * width / (box[2] - box[0]))
    return to_grid(im, box, width, h)


def nine(art, w, h, mx=None, my=None):
    src = Image.open(os.path.join(CARD, art + ".png")).convert("RGBA")
    mx = src.width // 2 if mx is None else mx
    my = src.height // 2 if my is None else my
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    midw, midh = src.width - 2 * mx, src.height - 2 * my
    xs = [(0, mx, 0, mx), (mx, src.width - mx, mx, w - mx), (src.width - mx, src.width, w - mx, w)]
    ys = [(0, my, 0, my), (my, src.height - my, my, h - my), (src.height - my, src.height, h - my, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.paste(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def text(img, xy, s, size=12, fill=INK, anchor="la"):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill, anchor=anchor)


def tw(s, size):
    return int(ImageFont.truetype(FONT, size).getlength(s))


def paste(bg, sp, xy):
    bg.paste(sp, (int(xy[0]), int(xy[1])), sp)


def plate(bg, x, y, w, h, s=None, size=12, fill=INK):
    paste(bg, nine("button", w, h), (x, y))
    if s:
        text(bg, (x + w // 2, y + h // 2), s, size, fill, "mm")


def tag_w(s, size=12):
    return max(tw(s, size) + 72, 52)  # 양끝 장식이 글자를 가리지 않게


def tag(bg, cx, y, s, size=12, fill=INK):
    w = tag_w(s, size)
    h = 21 if size == 12 else 34
    paste(bg, nine("pill", w, h), (cx - w // 2, y))
    text(bg, (cx, y + h // 2), s, size, fill, "mm")


def stars(w, h, seed=3, shift=0.0):
    bg = Image.new("RGBA", (w, h), (*BACK, 255))
    px = bg.load()
    rng = random.Random(seed)
    for layer, (count, speed, color) in enumerate([(70, 0.15, (60, 53, 70)), (40, 0.4, (92, 81, 100)), (16, 1.0, (165, 178, 157))]):
        for _ in range(count):
            x, y = rng.randrange(w), rng.randrange(h)
            px[int(x + shift * speed) % w, y] = (*color, 255)
    return bg


def ship_sprite():
    """팩 우주선(60%) 위쪽 방향 한 칸 + 몸 + 포 + 엔진"""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    for name in ["ship_engine", "ship_cannon", "ship"]:
        sheet = Image.open(os.path.join(RUN, name + ".png")).convert("RGBA")
        paste(img, sheet.crop((0, 0, 48, 48)), (0, 0))
    return img


def flame(i):
    sheet = Image.open(os.path.join(RUN, "ship_flame_idle.png")).convert("RGBA")
    return sheet.crop(((i % (sheet.width // 48)) * 48, 0, (i % (sheet.width // 48)) * 48 + 48, 48))


def drone(i):
    sheet = Image.open(os.path.join(RUN, "drone.png")).convert("RGBA")
    return sheet.crop(((i % 2) * 16, 2 * 16, (i % 2) * 16 + 16, 3 * 16))


def top_bar(bg, w, big):
    """상단 바: 제목, 보유 광물, 전체 화면을 금속 판 위에"""
    size = 24 if big else 12
    h = 36 if big else 25
    plate(bg, 4, 3, tw("소행성 광부", size) + 84, h, "소행성 광부", size, TEAL)
    label = "보유 광물 2,340"
    bw = tw(label, size) + 100
    plate(bg, w // 2 - bw // 2, 3, bw, h, None)
    ore = Image.open(os.path.join(RUN, "mineral_3.png")).convert("RGBA")
    paste(bg, ore, (w // 2 - bw // 2 + 28, 3 + (h - ore.height) // 2))
    text(bg, (w // 2 + 10, 3 + h // 2), label, size, GOLD, "mm")
    fw = tw("전체 화면", size) + 84
    plate(bg, w - fw - 4, 3, fw, h, "전체 화면", size)


def bottom_bar(bg, w, h, big):
    size = 12
    tag(bg, 70, h - 25, "이전 버전", size, TEAL)
    tag(bg, w - 62, h - 25, "v0.7.0", size, TEAL)


NAMES = ["연구소", "격납고", "광물 창고", "전시관", "드론 공장"]
# 시트 칸 순서: 연구소, 격납고, 창고, 전시관, 공장, 착륙장
def assets():
    sheet = Image.open(os.path.join(RAW, "base_buildings.png"))
    cells = grid_cells(sheet, 3, 2)
    ground_raw = Image.open(os.path.join(RAW, "base_ground.png"))
    station_raw = Image.open(os.path.join(RAW, "base_station.png"))
    return {"sheet": sheet, "cells": cells, "ground_raw": ground_raw, "ground_box": content_box(ground_raw), "station_raw": station_raw, "station_box": content_box(station_raw)}


def build(a, i, width):
    return fit(a["sheet"], a["cells"][i], width)


# ── 시안 A: 지금 배치 유지, 그림·UI만 다듬기 ──
def mock_a(a, w, h, big, t=0, shift=0.0, lit=None):
    bg = stars(w, h, 3, shift)
    gw = int(w * 0.84)
    ground = fit(a["ground_raw"], a["ground_box"], gw)
    gx, gy = (w - gw) // 2, (h - ground.height) // 2 + 8
    paste(bg, ground, (gx, gy))
    bw = 84 if big else 66
    spots = [(0.2, 0.3), (0.5, 0.2), (0.25, 0.72), (0.76, 0.72), (0.8, 0.3)]
    tags = []
    for i, (sx, sy) in enumerate(spots):
        sp = build(a, i, bw)
        x, y = gx + int(gw * sx) - sp.width // 2, gy + int(ground.height * sy) - sp.height // 2
        paste(bg, sp, (x, y))
        tags.append((x + sp.width // 2, y - (24 if not big else 34), NAMES[i]))
    pad = build(a, 5, 76 if big else 62)
    px, py = gx + gw // 2 - pad.width // 2, gy + int(ground.height * 0.52) - pad.height // 2
    paste(bg, pad, (px, py))
    cx, cy = px + pad.width // 2, py + pad.height // 2
    paste(bg, flame(t), (cx - 24, cy - 26))
    paste(bg, ship_sprite(), (cx - 24, cy - 26))
    for tx, ty, s in tags:
        tag(bg, tx, max(ty, 42 if big else 30), s, 24 if big else 12)
    # 왕복 운반 드론
    k = 0.5 + 0.5 * math.sin(t * math.tau / 40.0)
    dx, dy = gx + int(gw * (0.28 + 0.2 * k)), gy + int(ground.height * (0.42 + 0.08 * k))
    paste(bg, drone(t // 2), (dx - 8, dy - 8))
    size = 24 if big else 12
    fw = tw("출격", size) + 76
    plate(bg, cx - fw // 2, py + pad.height + 2, fw, 34 if big else 25, "출격", size, GOLD)
    top_bar(bg, w, big)
    bottom_bar(bg, w, h, big)
    return bg


# ── 시안 B: 화면 구성을 새로: 왼쪽 건물 목록 + 가운데 큰 격납고 무대 + 오른쪽 아래 큰 출격 ──
def mock_b(a, w, h, big, t=0, shift=0.0):
    bg = stars(w, h, 5, shift)
    gw = int(w * 1.3)
    ground = fit(a["ground_raw"], a["ground_box"], gw)
    paste(bg, ground, ((w - gw) // 2 + 40, h - ground.height // 2 + 10))
    col_w = 148 if not big else 250
    y = 34 if not big else 46
    row = 56 if not big else 62
    for i, s in enumerate(NAMES):
        paste(bg, nine("button", col_w, row - 4), (6, y))
        icon = build(a, i, 44)
        paste(bg, icon, (14, y + (row - 4 - icon.height) // 2))
        if big:  # 폰은 24px 두 줄이 판 안에 안 들어가 이름만 둔다
            text(bg, (64, y + (row - 4) // 2), s, 24, INK, "lm")
        else:
            text(bg, (64, y + 10), s, 12, INK)
            text(bg, (64, y + 26), ["강화 3/12", "전투기 1대", "가져온 광물", "도감 41%", "공사 중"][i], 12, TEAL)
        y += row
    # 가운데 무대
    stage_x = col_w + 12 + (w - col_w - 12) // 2
    pad = build(a, 5, 150 if not big else 170)
    px, py = stage_x - pad.width // 2, h // 2 - pad.height // 2 + 10
    paste(bg, pad, (px, py))
    cx, cy = stage_x, py + pad.height // 2
    paste(bg, flame(t), (cx - 24, cy - 28))
    paste(bg, ship_sprite(), (cx - 24, cy - 28))
    k = t % 40 / 40.0
    paste(bg, drone(t // 2), (px + int(pad.width * k), py - 6))
    size = 24 if big else 12
    fw, fh = (190, 44) if big else (130, 32)
    plate(bg, w - fw - 10, h - fh - 28, fw, fh, "출격", 24, GOLD)
    top_bar(bg, w, big)
    bottom_bar(bg, w, h, big)
    return bg


# ── 시안 C: 궤도 정거장 (출격 화면과 같은 위에서 본 시점. ART_BIBLE의 "기지 = 3/4 조감"과 다름) ──
def mock_c(a, w, h, big, t=0, shift=0.0):
    bg = stars(w, h, 7, shift)
    sw = min(int(h * 0.82), 320)
    st = fit(a["station_raw"], a["station_box"], sw)
    sx, sy = w // 2 - st.width // 2, (h - st.height) // 2 + 10
    paste(bg, st, (sx, sy))
    cx, cy = w // 2, sy + st.height // 2
    paste(bg, flame(t), (cx - 24, cy - 24))
    paste(bg, ship_sprite(), (cx - 24, cy - 24))
    r = st.width // 2 + 2
    size = 24 if big else 12
    gap = r + 8
    # 그림의 모듈 자리: 위 연구소, 오른쪽 광물 창고, 오른쪽 아래 격납고, 왼쪽 아래 전시관, 왼쪽 드론 공장
    for s, side, ky in [("연구소", 0.55, -0.82), ("광물 창고", 1, -0.1), ("격납고", 1, 0.42 if big else 0.62), ("전시관", -1, 0.42 if big else 0.62), ("드론 공장", -1, -0.1)]:
        half = tag_w(s, size) // 2
        tx = cx + side * (gap + half) if side != 0.55 else cx + r // 2 + half + 8
        tag(bg, int(tx), int(cy + ky * r), s, size)
    k = t / 40.0 * math.tau
    paste(bg, drone(t // 2), (int(cx + math.cos(k) * r * 0.55) - 8, int(cy + math.sin(k) * r * 0.55) - 8))
    fw, fh = (170, 40) if big else (110, 28)
    plate(bg, w - fw - 10, h - fh - 28, fw, fh, "출격", 24 if big else 12, GOLD)
    top_bar(bg, w, big)
    bottom_bar(bg, w, h, big)
    return bg


def save_all(a):
    for key, fn in {"A": mock_a, "B": mock_b, "C": mock_c}.items():
        fn(a, 640, 360, False).convert("RGB").resize((1280, 720), Image.NEAREST).save(f"{OUT}/mock_{key}_pc_1280x720.png")
        fn(a, 844, 390, True).convert("RGB").save(f"{OUT}/mock_{key}_phone_844x390.png")


def motion(a):
    """대기 움직임 GIF (시안 A, PC): 엔진 불꽃, 별 시차, 건물 불빛 깜빡임, 운반 드론 왕복"""
    rng = random.Random(9)
    base = mock_a(a, 640, 360, False, 0, 0.0)
    arr = np.array(base.convert("RGB"))
    bright = [(48, 225, 185), (153, 233, 230), (246, 206, 80), (248, 148, 25)]
    pts = np.argwhere(np.isin(arr.reshape(-1, 3).dot([65536, 256, 1]), [c[0] * 65536 + c[1] * 256 + c[2] for c in bright]).reshape(arr.shape[:2]))
    # 위쪽 바와 아래쪽 표는 깜빡이지 않게
    pts = [p for p in pts if 32 < p[0] < 330]
    groups = [rng.sample(pts, min(len(pts), 14)) for _ in range(4)]
    frames = []
    for t in range(40):
        f = mock_a(a, 640, 360, False, t, t * 0.5).convert("RGB")
        px = f.load()
        for y, x in groups[t // 10 % 4] if t % 10 < 4 else []:
            px[int(x), int(y)] = (254, 248, 229)
        frames.append(f.resize((640, 360), Image.NEAREST))
    frames[0].save(f"{OUT}/idle_motion_A.gif", save_all=True, append_images=frames[1:], duration=70, loop=0, optimize=False)


def compare_now():
    W = Image.new("RGB", (1280, 720), BACK)
    for i, n in enumerate(["now_pc_1280x720", "mock_A_pc_1280x720", "mock_B_pc_1280x720", "mock_C_pc_1280x720"]):
        im = Image.open(f"{OUT}/{n}.png").convert("RGB").resize((640, 360), Image.NEAREST)
        W.paste(im, (i % 2 * 640, i // 2 * 360))
    W.save(f"{OUT}/compare_all.png")


if __name__ == "__main__":
    a = assets()
    save_all(a)
    motion(a)
    compare_now()
    print("시안 → review/v070_base/")
