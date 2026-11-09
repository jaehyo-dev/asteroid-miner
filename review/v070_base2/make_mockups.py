"""기지 화면 A' 시안 만들기 (게임에는 쓰지 않음). 실행: python3 review/v070_base2/make_mockups.py
시안 A의 부품(review/v070_base/make_mockups.py)을 그대로 쓰고, 소행성 위에 갑판 모듈로 지은 정거장을 합성한다.
- A1 네모 격자 갑판, A2 육각 모듈 갑판. 지금(건물 5채)과 확장(건물 8채 + 건설 예정 칸, 드래그로 둘러봄).
- PC 640x360(2배로 저장), 폰 844x390(1배). 그림은 Codex 원본을 void32·1배 격자로 정리한다."""
import functools
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "v070_base"))
import make_mockups as mm  # noqa: E402

RAW = os.path.join(mm.ROOT, "assets/raw/base_v070b")
NAMES = {"lab": "연구소", "hangar": "격납고", "drone": "드론 공장", "store": "광물 창고", "gallery": "전시관",
         "weapon": "보조 무기 연구소", "evolve": "진화 도감 실험실", "planet": "행성 관제소", "empty": "건설 예정"}
OLD = {"lab": 0, "hangar": 1, "store": 2, "gallery": 3, "drone": 4}
NEW = {"weapon": 0, "evolve": 1, "planet": 2}
PROP = ["mast", "dish", "solar", "beacon", "beacon_off", "guide", "guide_off", "tanks"]

# 칸 배치: (열, 행) → 건물. 가운데 (0, 0)은 언제나 착륙장. 육각은 홀수 행이 반 칸 어긋난다.
SQUARE_NOW = {(-1, -1): "lab", (0, -1): "hangar", (1, -1): "drone", (-1, 1): "store", (1, 1): "gallery", (-1, 0): "empty", (1, 0): "empty"}
SQUARE_BIG = {**SQUARE_NOW, (-1, 0): "weapon", (1, 0): "planet", (-2, 1): "evolve", (-2, 0): "empty", (2, 0): "empty", (2, 1): "empty", (-2, -1): "empty", (2, -1): "empty", (0, 2): "empty", (-1, 2): "empty"}
HEX_NOW = {(-1, -1): "lab", (0, -1): "hangar", (1, 0): "drone", (-1, 1): "store", (0, 1): "gallery", (-1, 0): "empty", (1, -1): "empty", (-2, 1): "empty"}
HEX_BIG = {**HEX_NOW, (-1, 0): "weapon", (1, -1): "planet", (-2, 1): "evolve", (2, 0): "empty", (-2, 0): "empty", (1, 1): "empty", (-2, -1): "empty", (0, 2): "empty", (-1, 2): "empty"}

PC = {"w": 640, "h": 360, "big": False, "unit": 1.0}
PHONE = {"w": 844, "h": 390, "big": True, "unit": 1.32}


def load(name):
    return Image.open(os.path.join(RAW, name + ".png"))


SHEETS = {"square": (load("deck_square"), 3, 2), "hex": (load("deck_hex"), 3, 2), "props": (load("station_props"), 4, 2), "new": (load("base_buildings2"), 3, 1),
          "old": (Image.open(os.path.join(mm.RAW, "base_buildings.png")), 3, 2), "ground": (Image.open(os.path.join(mm.RAW, "base_ground.png")), 1, 1)}
CELLS = {k: mm.grid_cells(v[0], v[1], v[2]) for k, v in SHEETS.items()}


@functools.lru_cache(maxsize=None)
def sprite(sheet, i, w, h=None):
    """시트 칸 i를 w 폭의 1배 격자 그림으로 (h를 주면 비율을 바꿔 맞춘다)"""
    box = CELLS[sheet][i]
    return mm.to_grid(SHEETS[sheet][0], box, w, h or round((box[3] - box[1]) * w / (box[2] - box[0])))


def building(name, w):
    return sprite("old", OLD[name], w) if name in OLD else sprite("new", NEW[name], w)


def prop(name, w):
    return sprite("props", PROP.index(name), w)


@functools.lru_cache(maxsize=None)
def half_plate(w, h):
    """이름표 판: 카드 프레임 알약을 절반 크기로 줄여 양끝 장식이 글자를 덜 차지하게 (9칸 나누기는 mm.nine과 같음)"""
    src = Image.open(os.path.join(mm.CARD, "pill.png")).convert("RGBA")
    src = src.resize((src.width // 2, src.height // 2), Image.NEAREST)
    mx, my = src.width // 2, src.height // 2
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for sx0, sx1, dx0, dx1 in [(0, mx, 0, mx), (mx, mx + 1, mx, w - mx), (mx + 1, src.width, w - (src.width - mx - 1), w)]:
        for sy0, sy1, dy0, dy1 in [(0, my, 0, my), (my, my + 1, my, h - my), (my + 1, src.height, h - (src.height - my - 1), h)]:
            if dx1 > dx0 and dy1 > dy0:
                out.paste(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def small_tag(bg, cx, y, s, big, fill=mm.INK):
    """이름표: A와 같은 금속 판 (폭이 칸 안에 들어가게 절반 크기)"""
    size = 24 if big else 12
    w, h = mm.tw(s, size) + 36, 32 if big else 19
    mm.paste(bg, half_plate(w, h), (cx - w // 2, y))
    mm.text(bg, (cx, y + h // 2), s, size, fill, "mm")
    return w


class World:
    """정거장 한 벌의 풍경. static은 움직이지 않는 그림, lights는 깜빡이는 자리"""

    def __init__(self, kind, cells, sc):
        self.kind, self.cells, self.sc = kind, cells, sc
        u = sc["unit"]
        self.u = u
        self.plate_w = round((116 if kind == "square" else 122) * u)
        self.sx, self.sy = (round(134 * u), round(92 * u)) if kind == "square" else (round(152 * u), round(84 * u))
        all_cells = dict(cells)
        all_cells[(0, 0)] = "pad"
        self.all = all_cells
        pts = [self.center(c) for c in all_cells]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        mx, my = round((76 if kind == "square" else 44) * u), round(34 * u)  # 돌이 갑판 둘레로 보이게: 좌우 넓게, 위아래 좁게
        self.x0, self.y0 = min(xs) - self.plate_w // 2 - mx, min(ys) - round(60 * u) - my
        self.W = max(xs) + self.plate_w // 2 + mx - self.x0
        self.H = max(ys) + round(60 * u) + my - self.y0
        self.guides, self.beacons, self.windows = [], [], []
        self.static = self._draw()

    def center(self, c):
        col, row = c
        if self.kind == "square":
            return col * self.sx, row * self.sy
        return round((col + (0.5 if row % 2 else 0.0)) * self.sx), row * self.sy

    def at(self, c):
        x, y = self.center(c)
        return x - self.x0, y - self.y0

    def pad_center(self):
        return self.at((0, 0))

    def neighbours(self):
        """이웃한 칸 쌍과 방향"""
        out = []
        dirs = [(1, 0)] + ([(0, 1)] if self.kind == "square" else [])
        for c in self.all:
            for d in dirs:
                n = (c[0] + d[0], c[1] + d[1])
                if n in self.all:
                    out.append((c, n, "h" if d[0] else "v"))
            if self.kind == "hex":
                odd = c[1] % 2
                for dc, tag in [(odd - 1, "\\_left"), (odd, "\\_right")]:
                    n = (c[0] + dc, c[1] + 1)
                    if n in self.all:
                        out.append((c, n, "/" if tag == "\\_left" else "\\"))
        return out

    def _draw(self):
        u, W, H = self.u, self.W, self.H
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        mm.paste(img, sprite("ground", 0, W, H), (0, 0))
        sheet = self.kind
        pw = self.plate_w
        pts = sorted(self.all, key=lambda c: self.center(c)[1])
        # 갑판 아래 돌 위의 시설: 태양광 판, 접시 안테나, 연료 탱크 (갑판 바깥 가장자리)
        self._outside(img)
        plate = sprite(sheet, 0, pw)
        empty = sprite(sheet, 1, pw)
        pad = sprite(sheet, 4, pw)
        ph = plate.height
        for c in pts:
            x, y = self.at(c)
            sp = pad if self.all[c] == "pad" else empty if self.all[c] == "empty" else plate
            mm.paste(img, sp, (x - pw // 2, y - ph // 2))
        self._walkways(img)
        # 안쪽 윗가장자리 난간 (건물 뒤)
        rail = sprite("square", 5, round(58 * u))
        for c in pts:
            if (c[0], c[1] - 1) not in self.all and self.all[c] != "pad":
                x, y = self.at(c)
                mm.paste(img, rail, (x - rail.width // 2, y - ph // 2 - rail.height // 2 + 1))
        bw = round(80 * u)
        for c in pts:
            name = self.all[c]
            x, y = self.at(c)
            if name in OLD or name in NEW:
                sp = building(name, bw)
                bx, by = x - sp.width // 2, y - sp.height + round(24 * u)
                mm.paste(img, sp, (bx, by))
                self.windows.append((bx, by, sp.width, sp.height))
        self._deck_props(img)
        # 유도등 자리 (착륙장 소켓의 여덟 불빛): 게임에서는 차례로 켜진다
        cx, cy = self.pad_center()
        rx, ry = pw * 0.36, ph * 0.35
        self.guides = [(round(cx + rx * math.cos(i * math.tau / 8)), round(cy - round(2 * u) + ry * math.sin(i * math.tau / 8))) for i in range(8)]
        return img

    def _walkways(self, img):
        u = self.u
        sheet = self.kind
        for a, b, d in self.neighbours():
            ax, ay = self.at(a)
            bx, by = self.at(b)
            mx, my = (ax + bx) // 2, (ay + by) // 2
            if self.kind == "square":
                if d == "h":
                    sp = sprite(sheet, 2, round(44 * u))
                else:
                    sp = sprite(sheet, 3, round(20 * u))
            else:
                sp = sprite(sheet, 2, round(48 * u)) if d == "h" else sprite(sheet, 3 if d == "/" else 5, round(44 * u))
            mm.paste(img, sp, (mx - sp.width // 2, my - sp.height // 2))

    def _outside(self, img):
        """갑판 바깥 돌 위의 큰 시설: 위치는 전체 크기 비율. 칸 밖으로 나가게 가장자리에 둔다"""
        u, W, H = self.u, self.W, self.H
        items = [("solar", 0.05, 0.4, 40), ("solar", 0.95, 0.4, 40), ("solar", 0.055, 0.62, 36), ("solar", 0.945, 0.62, 36), ("mast", 0.06, 0.2, 18), ("dish", 0.94, 0.2, 32)]
        for name, fx, fy, w in items:
            sp = prop(name, round(w * u))
            mm.paste(img, sp, (round(W * fx) - sp.width // 2, round(H * fy) - sp.height // 2))
        # 비어 있는 자리의 연료 탱크 (네모는 착륙장 아래, 육각은 오른쪽 아래)
        spot = (0, 1) if self.kind == "square" and (0, 1) not in self.all else (1, 1) if (1, 1) not in self.all else None
        if spot:
            x, y = self.at(spot)
            sp = prop("tanks", round(46 * u))
            mm.paste(img, sp, (x - sp.width // 2, y - sp.height // 2 + round(10 * u)))

    def _deck_props(self, img):
        """바깥쪽 모서리 칸의 경고등 (게임에서는 깜빡인다)"""
        u = self.u
        pw = self.plate_w
        pts = list(self.all)
        corners = [min(pts, key=lambda c: self.center(c)[0] + self.center(c)[1]), max(pts, key=lambda c: self.center(c)[0] - self.center(c)[1]), min(pts, key=lambda c: self.center(c)[0] - self.center(c)[1]), max(pts, key=lambda c: self.center(c)[0] + self.center(c)[1])]
        for i, c in enumerate(corners):
            x, y = self.at(c)
            side = 1 if self.center(c)[0] > 0 else -1
            bx, by = x + side * (pw // 2 - round(4 * u)), y - round(26 * u)
            sp = prop("beacon_off", round(14 * u))
            mm.paste(img, sp, (bx - sp.width // 2, by - sp.height // 2))
            self.beacons.append((bx, by))

    def frame(self, t):
        """t번째 프레임의 풍경: 유도등 차례로, 경고등 깜빡임, 건물 창 불빛, 엔진 불꽃, 운반 드론"""
        u = self.u
        img = self.static.copy()
        lit = prop("guide", round(9 * u))
        dark = prop("guide_off", round(9 * u))
        for i, (x, y) in enumerate(self.guides):
            sp = lit if (t // 3 - i) % 8 in (0, 1, 2) else dark
            mm.paste(img, sp, (x - sp.width // 2, y - sp.height // 2))
        on = prop("beacon", round(14 * u))
        for i, (x, y) in enumerate(self.beacons):
            if (t + i * 7) % 20 < 8:
                mm.paste(img, on, (x - on.width // 2, y - on.height // 2))
        # 건물 창 불빛: 건물마다 자리를 정해 천천히 번갈아 켠다
        px = img.load()
        for j, (bx, by, bw, bh) in enumerate(self.windows):
            rng = random.Random(j + 11)
            spots = [(bx + rng.randrange(bw), by + rng.randrange(bh)) for _ in range(120)]
            spots = [p for p in spots if px[p][3] and px[p][:3] in ((254, 248, 229), (246, 206, 80), (48, 225, 185), (153, 233, 230))][:8]
            if (t // 8 + j) % 3 == 0:
                for p in spots:
                    px[p] = (60, 53, 68, 255)
        cx, cy = self.pad_center()
        fl, ship = mm.flame(t), mm.ship_sprite()
        mm.paste(img, fl, (cx - 24, cy - 30))
        mm.paste(img, ship, (cx - 24, cy - 30))
        k = 0.5 + 0.5 * math.sin(t * math.tau / 40.0)
        ax, ay = self.at((-1, -1))
        dx, dy = round(ax + (cx - ax) * k), round(ay + (cy - ay) * k) - round(20 * u)
        mm.paste(img, mm.drone(t // 2), (dx - 8, dy - 8))
        self._tags(img)
        return img

    def _tags(self, img):
        big = self.sc["big"]
        for c, name in self.all.items():
            if name == "pad":
                continue
            x, y = self.at(c)
            ph = sprite(self.kind, 0, self.plate_w).height
            ty = y + ph // 2 - (36 if big else 22)
            small_tag(img, x, ty, NAMES[name], big, mm.GOLD if name == "empty" else mm.INK)


def screen(world, t=0, cam=(0, 0), hint=False):
    """화면 합성: 별(시차) + 풍경(착륙장이 가운데 + cam만큼 끌림) + 상단 바·출격·버전"""
    sc = world.sc
    w, h, big = sc["w"], sc["h"], sc["big"]
    bg = mm.stars(w, h, 3, t * 0.5 + cam[0] * 0.15)
    pcx, pcy = world.pad_center()
    fy = h // 2 + (6 if big else 6)
    x, y = w // 2 - pcx + cam[0], fy - pcy + cam[1]
    land = world.frame(t)
    bg.paste(land, (x, y), land)
    # 출격은 착륙장 아래: 끌어도 따라간다 (게임에서는 고정 버튼으로도 가능, design.md 참고)
    size = 24 if big else 12
    fw = mm.tw("출격", size) + 76
    fh = 34 if big else 25
    pad_h = sprite(world.kind, 4, world.plate_w).height
    mm.plate(bg, x + pcx - fw // 2, y + pcy + pad_h // 2 - fh + (4 if big else 2), fw, fh, "출격", size, mm.GOLD)
    mm.top_bar(bg, w, big)
    mm.bottom_bar(bg, w, h, big)
    if hint:
        small_tag(bg, w // 2, h - (34 if big else 22), "드래그로 둘러보기", big, mm.TEAL)
    return bg


def save(img, sc, name):
    img = img.convert("RGB")
    if not sc["big"]:
        img = img.resize((1280, 720), Image.NEAREST)
    img.save(f"{HERE}/{name}.png")


def gif(worlds, path, cams=None, n=40):
    """대기 움직임이나 끌어서 둘러보기를 짧은 GIF로 (PC 640x360)"""
    frames = [screen(worlds, t, cams(t) if cams else (0, 0), hint=cams is not None).convert("RGB") for t in range(n)]
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=70, loop=0, optimize=False)


def pan_path(world):
    """끝까지 끌었다 돌아오는 카메라 길 (왼쪽 → 위 → 가운데)"""
    w, h = world.sc["w"], world.sc["h"]
    limit_x = max(world.W // 2 - w // 2, 0)
    limit_y = max(world.H // 2 - h // 2, 0) // 2

    def cam(t):
        k = t / 60.0
        if k < 0.33:
            e = k / 0.33
            return round(limit_x * math.sin(e * math.pi / 2)), 0
        if k < 0.66:
            e = (k - 0.33) / 0.33
            return round(limit_x * math.cos(e * math.pi)), 0
        e = (k - 0.66) / 0.34
        return round(-limit_x * (1 - e)), round(-limit_y * math.sin(e * math.pi))

    return cam


def main():
    variants = {"A1": ("square", SQUARE_NOW, SQUARE_BIG), "A2": ("hex", HEX_NOW, HEX_BIG)}
    sheet = Image.new("RGB", (1280, 720 * 2))
    for row, (key, (kind, now, bigger)) in enumerate(variants.items()):
        for sc, tag in [(PC, "pc_1280x720"), (PHONE, "phone_844x390")]:
            save(screen(World(kind, now, sc)), sc, f"mock_{key}_{tag}")
            wb = World(kind, bigger, sc)
            save(screen(wb, hint=True), sc, f"mock_{key}_big_{tag}")
            if sc is PC:
                save(screen(wb, cam=(pan_path(wb)(20)[0], 0), hint=True), sc, f"mock_{key}_big_dragged_{tag}")
                wb_all = wb.frame(0).convert("RGBA")
                full = mm.stars(wb.W, wb.H, 3)
                full.paste(wb_all, (0, 0), wb_all)
                full.convert("RGB").save(f"{HERE}/mock_{key}_big_whole_map.png")
                gif(wb, f"{HERE}/pan_{key}.gif", pan_path(wb), 60)
        gif(World(kind, now, PC), f"{HERE}/idle_motion_{key}.gif")
        a = Image.open(f"{HERE}/mock_{key}_pc_1280x720.png").resize((640, 360), Image.NEAREST)
        b = Image.open(f"{HERE}/mock_{key}_big_pc_1280x720.png").resize((640, 360), Image.NEAREST)
        sheet.paste(a, (0, row * 360))
        sheet.paste(b, (640, row * 360))
    sheet.crop((0, 0, 1280, 720)).save(f"{HERE}/compare.png")
    print("시안 → review/v070_base2/")


if __name__ == "__main__":
    main()
