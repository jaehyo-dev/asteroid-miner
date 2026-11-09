"""기지 화면 A1 다듬은 시안 (게임에는 쓰지 않음). 실행: python3 review/v070_base3/make_mockups.py
A' 시안(review/v070_base2/make_mockups.py)의 부품과 합성을 그대로 쓰고, 계획서 32번의 복잡함 줄이는 규칙 5가지만 더한다."""
import functools
import importlib.util
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("b2", os.path.join(HERE, "..", "v070_base2", "make_mockups.py"))
b2 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(b2)
mm = b2.mm

ICON_ORDER = ["lab", "hangar", "drone", "store", "gallery", "weapon", "evolve", "planet", "empty"]
_icons = Image.open(os.path.join(mm.ROOT, "assets/raw/base_v070c/base_icons.png"))
b2.SHEETS["icons"] = (_icons, 3, 3)
b2.CELLS["icons"] = mm.grid_cells(_icons, 3, 3)

# 규칙 1: 밝기 배율 (건물은 그대로 1.0). 땅은 갑판이 떠 보이게 가장 어둡게
K_DECK, K_WALK, K_RAIL, K_GROUND, K_PAD, K_EMPTY = 0.85, 0.5, 0.6, 0.6, 0.8, 0.8
# void32에는 어두운 회색이 (60,53,68) 아래로 없어서 그대로 줄이면 땅이 적갈색 얼룩이 된다. 시안의 어두운 회색 단계 (design.md 질문)
DARK = [(0, 0, 0), (20, 18, 26), (30, 26, 38), (36, 32, 44), (48, 43, 58), (60, 53, 68), (92, 81, 100)]

# 규칙 3: 칸 간격을 넓혀 한 화면에 착륙장 + 둘레 6칸. 다음 열은 화면 끝에 조금만 보여 끌 수 있음을 알린다
PC = {"w": 640, "h": 360, "big": False, "unit": 1.1, "px": 172, "py": 104}
PHONE = {"w": 844, "h": 390, "big": True, "unit": 1.2, "px": 232, "py": 108}

# 착륙장 위아래 칸은 비워 착륙장 이름표와 출격 버튼 자리로 쓴다. 규칙 4: 건설 예정은 다음 1~2칸만
NOW = {(-1, -1): "lab", (1, -1): "hangar", (-1, 0): "drone", (1, 0): "gallery", (-1, 1): "store", (1, 1): "empty", (2, 0): "empty"}
# 10채. 8종뿐이라 왼쪽 끝 2채는 연구소·창고를 임시로 다시 썼다
BUSY = {(-1, -1): "lab", (1, -1): "hangar", (-1, 0): "drone", (1, 0): "gallery", (-1, 1): "store", (1, 1): "weapon",
        (2, -1): "planet", (2, 0): "evolve", (-2, -1): "lab", (-2, 0): "store", (2, 1): "empty", (-2, 1): "empty"}
# A' 그대로 + 같은 10채 (빈 칸도 A' 규칙대로 전부)
BEFORE = {**b2.SQUARE_BIG, (-2, -1): "lab", (2, 0): "store"}
PRESSED = (-1, 1)  # c: 맨 아래 왼쪽 "광물 창고"를 누름 (폰에서 "이전 버전"과 가장 가까운 자리)


@functools.lru_cache(maxsize=None)
def dim(sheet, i, w, h, k, dark=True):
    """시트 그림을 k배 어둡게. dark면 어두운 회색 단계로(색이 빠져 눈에 덜 띔), 아니면 void32로 맞춘다"""
    a = np.array(b2.sprite(sheet, i, w, h)).copy()
    for c in {tuple(p) for p in a[a[..., 3] > 0][:, :3].tolist()}:
        mask = (a[..., :3] == c).all(axis=-1)
        v = tuple(round(x * k) for x in c)
        a[mask, :3] = min(DARK, key=lambda d: sum((p - q) ** 2 for p, q in zip(d, v))) if dark else mm.near(v)
    return Image.fromarray(a, "RGBA")


class Station(b2.World):
    """A1 정거장에 규칙 1·3·4·5를 넣은 풍경. 이름표(규칙 2)는 화면 좌표라 label_layer에서 그린다"""

    def __init__(self, cells, sc, pressed=None):
        self.pressed = pressed
        super().__init__("square", cells, sc)

    def center(self, c):
        return c[0] * self.sc["px"], c[1] * self.sc["py"]

    def _draw(self):
        u, W, H, pw = self.u, self.W, self.H, self.plate_w
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        mm.paste(img, dim("ground", 0, W, H, K_GROUND), (0, 0))
        self._outside(img)
        order = sorted(self.all, key=lambda c: self.center(c)[1])
        ph = b2.sprite("square", 0, pw).height
        for c in order:
            x, y = self.at(c)
            name = self.all[c]
            # 누른 칸만 갑판을 원래 밝기로
            i, k = (4, K_PAD) if name == "pad" else (1, K_EMPTY) if name == "empty" else (0, 1.0 if c == self.pressed else K_DECK)
            mm.paste(img, dim("square", i, pw, None, k, dark=i == 0 and k < 1), (x - pw // 2, y - ph // 2))
        self._walkways(img)
        for c in order:  # 난간은 지도 윗가장자리에만
            if (c[0], c[1] - 1) not in self.all and self.all[c] != "pad":
                x, y = self.at(c)
                rail = dim("square", 5, round(58 * u), None, K_RAIL)
                mm.paste(img, rail, (x - rail.width // 2, y - ph // 2 - rail.height // 2 + 1))
        for c in order:
            name = self.all[c]
            x, y = self.at(c)
            if name in b2.OLD or name in b2.NEW:
                sp = b2.building(name, round(80 * u))
                bx, by = x - sp.width // 2, y - sp.height + round(24 * u)
                mm.paste(img, sp, (bx, by))
                self.windows.append((bx, by, sp.width, sp.height))
        self._deck_props(img)
        cx, cy = self.pad_center()
        rx, ry = pw * 0.36, ph * 0.35
        self.guides = [(round(cx + rx * math.cos(i * math.tau / 8)), round(cy - round(2 * u) + ry * math.sin(i * math.tau / 8))) for i in range(8)]
        return img

    def _walkways(self, img):
        """통로: 칸 사이를 이어 갑판보다 어둡게. 가로 통로는 넓어진 간격에 맞춰 늘린다"""
        u, pw = self.u, self.plate_w
        for a, b, d in self.neighbours():
            ax, ay = self.at(a)
            bx, by = self.at(b)
            if d == "h":
                natural = b2.sprite("square", 2, round(44 * u))
                sp = dim("square", 2, self.sc["px"] - pw + round(26 * u), natural.height, K_WALK)
            else:
                sp = dim("square", 3, round(20 * u), None, K_WALK)
            mm.paste(img, sp, ((ax + bx) // 2 - sp.width // 2, (ay + by) // 2 - sp.height // 2))

    def _outside(self, img):
        """규칙 5: 꾸밈은 지도 가장자리(칸 바깥 돌 위)에만"""
        u, W, H = self.u, self.W, self.H
        for name, fx, fy, w in [("solar", 0.05, 0.42, 36), ("solar", 0.95, 0.42, 36), ("mast", 0.06, 0.2, 18), ("dish", 0.94, 0.2, 30), ("tanks", 0.06, 0.8, 34), ("tanks", 0.94, 0.8, 34)]:
            sp = b2.prop(name, round(w * u))
            mm.paste(img, sp, (round(W * fx) - sp.width // 2, round(H * fy) - sp.height // 2))

    def frame(self, t):
        """A'의 대기 움직임에서 운반 드론만 뺀다 (불빛, 유도등, 대기 엔진)"""
        real, mm.drone = mm.drone, lambda i: Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        try:
            return super().frame(t)
        finally:
            mm.drone = real

    def _tags(self, img):
        pass


def edge_ui(sc):
    """화면 가장자리 UI 사각형 (상단 바, 이전 버전, 버전). 이름표·표식은 여기를 피한다"""
    w, h, big = sc["w"], sc["h"], sc["big"]
    size = 24 if big else 12
    bar = 36 if big else 25
    tw = mm.tag_w
    return [(4, 3, mm.tw("소행성 광부", size) + 84, bar), (w // 2 - (mm.tw("보유 광물 2,340", size) + 100) // 2, 3, mm.tw("보유 광물 2,340", size) + 100, bar),
            (w - mm.tw("전체 화면", size) - 88, 3, mm.tw("전체 화면", size) + 84, bar),
            (70 - tw("이전 버전") // 2, h - 25, tw("이전 버전"), 21), (w - 62 - tw("v0.7.0") // 2, h - 25, tw("v0.7.0"), 21)]


def hits(r, others, gap=2):
    return any(r[0] < o[0] + o[2] + gap and o[0] < r[0] + r[2] + gap and r[1] < o[1] + o[3] + gap and o[1] < r[1] + r[3] + gap for o in others)


def clear_of_ui(x, y, w, h, sc):
    """아래쪽 UI와 겹치면 위로, 위쪽 UI와 겹치면 아래로 비켜선 자리 (폰 "이전 버전" 요청)"""
    ui = edge_ui(sc)
    while hits((x, y, w, h), ui):
        y += -1 if y > sc["h"] // 2 else 1
    return x, y


def label_layer(bg, world, pressed, ox, oy):
    """규칙 2: 평소 표식만, 누른 칸은 이름. 착륙장은 항상 이름. 돌려준 사각형으로 겹침을 확인한다"""
    sc = world.sc
    big = sc["big"]
    size = 24 if big else 12
    plate_h = b2.sprite("square", 0, world.plate_w).height
    pad_h = b2.sprite("square", 4, world.plate_w).height
    placed = []
    cx, cy = world.pad_center()
    th = 32 if big else 19

    def name_tag(s, sx, sy, fill):
        w = mm.tw(s, size) + 36
        x, y = clear_of_ui(sx - w // 2, sy, w, th, sc)
        mm.paste(bg, b2.half_plate(w, th), (x, y))
        mm.text(bg, (x + w // 2, y + th // 2), s, size, fill, "mm")
        placed.append((x, y, w, th))

    name_tag("착륙장", ox + cx, oy + cy - pad_h // 2 - (th - (6 if big else 4)), mm.TEAL)
    icon_w = 22 if big else 16
    for c, name in world.all.items():
        if name == "pad":
            continue
        x, y = world.at(c)
        sx = ox + x
        if c == pressed:
            name_tag(b2.NAMES[name], sx, oy + y + plate_h // 2 - th - (4 if big else 3), mm.GOLD if name == "empty" else mm.INK)
            continue
        icon = b2.sprite("icons", ICON_ORDER.index(name), icon_w)
        # 건물은 갑판 왼쪽 아래 모서리(위아래 건물·통로와 겹치지 않음), 빈 건설 칸은 가운데
        ix = sx - icon.width // 2 if name == "empty" else sx - world.plate_w // 2 + (5 if big else 4)
        iy = oy + y - icon.height // 2 if name == "empty" else oy + y + plate_h // 2 - icon.height - (7 if big else 5)
        if ix < 0 or ix + icon.width > sc["w"]:
            continue  # 화면 끝에 조금만 보이는 칸은 표식을 그리지 않는다
        ix, iy = clear_of_ui(ix, iy, icon.width, icon.height, sc)
        mm.paste(bg, icon, (ix, iy))
        placed.append((ix, iy, icon.width, icon.height))
    # 자체 확인: 표식·이름표가 가장자리 UI를 가리지 않는다
    assert not any(hits(r, edge_ui(sc), 0) for r in placed), placed
    return placed


def screen(world, t=0, pressed=None):
    bg = b2.screen(world, t)  # 별, 풍경, 출격, 상단 바, 이전 버전·버전은 A'와 같다
    pcx, pcy = world.pad_center()
    label_layer(bg, world, pressed, world.sc["w"] // 2 - pcx, world.sc["h"] // 2 + 6 - pcy)
    return bg


def save(img, sc, name):
    img = img.convert("RGB")
    if not sc["big"]:
        img = img.resize((1280, 720), Image.NEAREST)
    img.save(f"{HERE}/{name}.png")
    return img


def busyness(img):
    """눈이 쉴 틈의 숫자: 옆 픽셀과 색이 다른 픽셀 비율 (작을수록 차분함)"""
    a = np.array(img.convert("RGB")).astype(int)
    return float(((np.abs(np.diff(a, axis=1)).sum(axis=2) > 40)).mean())


def brightness_check():
    """규칙 1 자체 확인: 건물 > 갑판 > 통로 평균 밝기"""
    def mean(sp):
        a = np.array(sp)
        return float((a[a[..., 3] > 0][:, :3] * [0.299, 0.587, 0.114]).sum(axis=1).mean())

    u = PC["unit"]
    bld = np.mean([mean(b2.building(n, round(80 * u))) for n in list(b2.OLD) + list(b2.NEW)])
    deck = mean(dim("square", 0, round(116 * u), None, K_DECK))  # 건물이 올라가지 않은 판 전체
    walk = mean(dim("square", 2, 70, 30, K_WALK))
    ground = mean(dim("ground", 0, 400, 200, K_GROUND))
    print(f"밝기 평균: 건물 {bld:.0f} > 갑판 {deck:.0f} > 통로 {walk:.0f}, 땅 {ground:.0f}")
    assert bld > deck > walk


def main():
    brightness_check()
    for sc, tag in [(PC, "pc_1280x720"), (PHONE, "phone_844x390")]:
        save(screen(Station(NOW, sc)), sc, f"mock_a_now_{tag}")
        save(screen(Station(BUSY, sc)), sc, f"mock_b_busy_{tag}")
        save(screen(Station(BUSY, sc, PRESSED), pressed=PRESSED), sc, f"mock_c_pressed_{tag}")

    # 나란히 비교: 왼쪽 A' 그대로, 오른쪽 규칙 적용
    rows = []
    for sc_old, sc_new, tag in [(b2.PC, PC, "PC"), (b2.PHONE, PHONE, "폰")]:
        old = b2.screen(b2.World("square", BEFORE, sc_old))
        new = screen(Station(BUSY, sc_new))
        print(f"{tag} 옆 픽셀과 다른 비율: A' {busyness(old) * 100:.1f}% → 규칙 {busyness(new) * 100:.1f}%")
        rows.append((old, new, not sc_old["big"]))
    w, gap, head = 1280, 24, 44
    sheet = Image.new("RGB", (w * 2 + gap, head + 720 + gap + 390 + 8), (24, 24, 32))
    mm.text(sheet, (w // 2, 8), "A' 그대로 (규칙 없음)", 24, mm.INK, "ma")
    mm.text(sheet, (w + gap + w // 2, 8), "규칙 5가지 적용", 24, mm.GOLD, "ma")
    for (old, new, is_pc), y in zip(rows, (head, head + 720 + gap)):
        for img, x in ((old, 0), (new, w + gap)):
            img = img.convert("RGB")
            if is_pc:
                sheet.paste(img.resize((1280, 720), Image.NEAREST), (x, y))
            else:
                sheet.paste(img, (x + (w - img.width) // 2, y))
    sheet.save(f"{HERE}/before_after_busy.png")

    # 대기 움직임 (PC 640x360, 40프레임)
    for cells, tag in [(NOW, "a"), (BUSY, "b")]:  # b 첫 화면에는 지도 끝 경고등이 안 보여 a도 만든다
        world = Station(cells, PC)
        frames = [screen(world, t).convert("RGB") for t in range(40)]
        frames[0].save(f"{HERE}/idle_motion_{tag}_pc.gif", save_all=True, append_images=frames[1:], duration=90, loop=0, optimize=False)
    print("시안 → review/v070_base3/")


if __name__ == "__main__":
    main()
