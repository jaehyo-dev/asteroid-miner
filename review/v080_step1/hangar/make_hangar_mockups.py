"""v0.8.0 1단계 격납고 "기본 무기 고르기" 시안 3개 (게임에 적용하지 않음).
실제 격납고 창 캡처(base_*.png, capture_hangar.gd로 찍음)를 논리 픽셀(1/2)로 줄여 바뀌는 곳만 덮어 그리고 다시 2배로 키운다.
글자는 Galmuri11 12px(게임과 같은 격자), 판·버튼·자물쇠·플라스크는 assets/sprites/window/ 그림 그대로.
무기 아이콘은 펄스 연사포만 실제 그림이고 나머지 4개는 시안용으로 코드로 그렸다 (나중에 Codex로 다시 그림).
실행: 저장소 맨 위에서 python3 review/v080_step1/hangar/make_hangar_mockups.py → 같은 폴더에 6장
바탕 다시 찍기: godot --path . --resolution 1280x720 -s $PWD/review/v080_step1/hangar/capture_hangar.gd -- $PWD/review/v080_step1/hangar/base_pc.png [noship]
(폰은 844x390, base_phone.png)"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont

DIR = "review/v080_step1/hangar/"
ART = "assets/sprites/window/"
FONT = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 12)
ASC = FONT.getmetrics()[0]

INK, MUTED, DIM, DARK, PLATE = "#fef8e5", "#a5b29d", "#917487", "#14111c", "#2b1925"  # DIM: 잠긴 이름도 읽히게 한 단계 밝게
TEAL, TEAL2, GOLD, RED, GREY = "#30e1b9", "#99e9e6", "#f6ce50", "#f25c76", "#3c3544"
BAR = {"사거리": TEAL2, "연사": RED, "채굴량": GOLD, "공격력": "#dc7f47"}

# 무기 표 (해금 가격은 임시). 공격력은 시안 C 왼쪽 막대용 임시 값
WEAPONS = [
    {"id": "pulse", "name": "펄스 연사포", "desc": "가장 가까운 적에게 빠르게 연사", "bars": (3, 4, 3), "atk": 3, "cost": 0, "state": "on"},
    {"id": "shot", "name": "산탄포", "desc": "가까운 적 쪽으로 부채꼴 다섯 발", "bars": (1, 2, 4), "atk": 4, "cost": 600, "state": "open"},
    {"id": "rail", "name": "레일건", "desc": "가장 먼 적까지 일렬로 꿰뚫음", "bars": (5, 1, 3), "atk": 5, "cost": 900, "state": "open"},
    {"id": "plasma", "name": "플라스마 대포", "desc": "적이 모인 곳에 느리고 큰 폭발", "bars": (3, 1, 2), "atk": 4, "cost": 1200, "state": "lock"},
    {"id": "beam", "name": "채굴 빔", "desc": "가까운 운석에 계속 닿는 빔, 채굴 특화", "bars": (1, 5, 5), "atk": 1, "cost": 1500, "state": "lock"},
]
BY_ID = {w["id"]: w for w in WEAPONS}

# 창 안 배치 (hangar_view.gd·base_window.gd와 같은 논리 좌표)
LAYOUT = {
    "pc": {"size": (640, 360), "body": (21, 47, 598, 292), "slot_h": 44, "stats_w": 146, "desc_w": 170},
    "phone": {"size": (422, 195), "body": (9, 28, 404, 159), "slot_h": 32, "stats_w": 118, "desc_w": 132},
}
PROBLEMS = []  # 넘침·겹침 (끝에서 assert)


def sprite(name):
    return Image.open(ART + name + ".png").convert("RGBA")


def nine(im, w, h, mx=None, my=None):
    """9칸 판 (WindowArt.plate와 같음: 여백을 안 주면 거의 절반, 가운데만 늘어남)"""
    mx = im.width // 2 - 1 if mx is None else mx
    my = im.height // 2 - 1 if my is None else my
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs = [(0, mx, 0, mx), (mx, im.width - mx, mx, w - mx), (im.width - mx, im.width, w - mx, w)]
    ys = [(0, my, 0, my), (my, im.height - my, my, h - my), (im.height - my, im.height, h - my, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                out.paste(im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def shade(im, f):
    """판을 어둡게 (게임의 modulate와 같음)"""
    a = np.array(im).astype(float)
    a[..., :3] *= f
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def silhouette(im, color=DIM):
    a = np.array(im)
    a[a[..., 3] > 0, :3] = Image.new("RGB", (1, 1), color).getpixel((0, 0))
    return Image.fromarray(a, "RGBA")


def width(s):
    return int(np.ceil(FONT.getlength(s)))


class Canvas:
    """논리 픽셀 그림판. 글자를 쓸 때마다 넘침(limit)·겹침을 기록한다"""

    def __init__(self, base, kind):
        a = np.array(Image.open(base).convert("RGBA"))[::2, ::2]  # 창은 2배 격자라 한 칸씩 건너뛰면 논리 픽셀
        self.im = Image.fromarray(a, "RGBA")
        self.kind = kind
        self.L = LAYOUT[kind]
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"
        self.boxes = []

    def text(self, x, y, s, color, align=-1, limit=None):
        """WindowArt.text와 같은 기준: y는 글자 위, align -1 왼쪽 0 가운데 1 오른쪽"""
        w = width(s)
        x0 = x - (0 if align < 0 else (w // 2 if align == 0 else w))
        if limit is not None and w > limit:
            PROBLEMS.append(f"{self.kind} 글자 넘침: {s} {w} > {limit}")
        box = (x0, y, x0 + w, y + 12)
        for b, t in self.boxes:
            if box[0] < b[2] and b[0] < box[2] and box[1] < b[3] and b[1] < box[3]:
                PROBLEMS.append(f"{self.kind} 글자 겹침: {s} / {t}")
        if x0 < 0 or box[2] > self.L["size"][0] or box[3] > self.L["size"][1]:
            PROBLEMS.append(f"{self.kind} 화면 밖 글자: {s}")
        self.boxes.append((box, s))
        self.d.text((x0, y + ASC), s, font=FONT, fill=color, anchor="ls")

    def paste(self, im, x, y):
        self.im.alpha_composite(im, (int(x), int(y)))

    def clear(self, x, y, w, h):
        self.d.rectangle((x, y, x + w - 1, y + h - 1), fill=PLATE)
        self.boxes = [(b, t) for b, t in self.boxes if not (b[0] >= x and b[2] <= x + w and b[1] >= y and b[3] <= y + h)]

    def save(self, name):
        out = self.im.resize((self.im.width * 2, self.im.height * 2), Image.NEAREST).convert("RGB")
        out.save(DIR + name)


# ── 부품 ───────────────────────────────────
TAB, BTN, BTN_OFF, LOCK, FLASK = sprite("tab"), sprite("btn"), sprite("btn_off"), sprite("lock"), sprite("build_research")


def ore_icon():
    """머리줄의 광물 아이콘을 캡처에서 오려 낸다 (실제 게임과 같은 그림)"""
    a = np.array(Image.open(DIR + "base_pc.png").convert("RGBA"))[::2, ::2][22:38, 536:552].copy()
    bg = a[0, 0, :3].copy()
    a[(a[..., :3] == bg).all(axis=2), 3] = 0
    im = Image.fromarray(a, "RGBA")
    return im.crop(im.getbbox())


ORE = ore_icon()


def mini_lock():
    """작은 자물쇠 7x8 (좁은 칸용)"""
    im = Image.new("RGBA", (7, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 0, 5, 3), outline="#917487")
    d.rectangle((0, 3, 6, 7), fill="#917487", outline=DARK)
    d.point((3, 5), fill=DARK)
    return im


MINI_LOCK = mini_lock()


def draw_icon(wid):
    """무기 아이콘 36x17. 펄스 연사포는 실제 그림, 나머지는 같은 팔레트로 그린 시안용"""
    if wid == "pulse":
        return sprite("weapon_pulse")
    im = Image.new("RGBA", (36, 17), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o, body, hi, mid, core, glow = PLATE, "#917487", INK, "#5c5164", TEAL, TEAL2

    def block(x0, y0, x1, y1, fill):
        d.rectangle((x0, y0, x1, y1), fill=o)
        d.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill=fill)

    block(0, 4, 13, 14, body)  # 몸통 (펄스와 같은 뒤쪽 덩어리)
    d.line((2, 5, 12, 5), fill=hi)
    d.rectangle((3, 8, 8, 11), fill=mid)
    if wid == "shot":  # 짧고 굵은 총구 + 부채꼴 세 갈래
        block(12, 3, 22, 15, "#a5b29d")
        d.line((13, 4, 21, 4), fill=hi)
        for y in (6, 9, 12):
            d.line((14, y, 21, y), fill=mid)
        for (x, y) in ((25, 3), (28, 1), (26, 8), (30, 8), (25, 13), (28, 15)):
            d.rectangle((x, y, x + 1, y + 1), fill=glow)
        d.point((24, 8), fill=core)
    elif wid == "rail":  # 길고 가는 쌍레일, 가운데 청록 줄
        d.rectangle((12, 5, 35, 6), fill=o)
        d.rectangle((12, 11, 35, 12), fill=o)
        d.line((12, 5, 34, 5), fill=hi)
        d.line((12, 12, 34, 12), fill="#a5b29d")
        d.line((13, 8, 33, 8), fill=core)
        d.line((13, 9, 30, 9), fill=glow)
        for x in (17, 23, 29):
            d.rectangle((x, 6, x + 1, 11), fill=mid)
    elif wid == "plasma":  # 넓은 포신 끝 동그란 빛 덩어리 (보라)
        block(12, 5, 22, 13, "#a5b29d")
        d.line((13, 6, 21, 6), fill=hi)
        d.ellipse((22, 1, 35, 16), fill="#3a1c57")
        d.ellipse((24, 3, 33, 14), fill="#6b3e75")
        d.ellipse((26, 5, 31, 12), fill="#a884f3")
        d.rectangle((28, 7, 29, 9), fill=INK)
    elif wid == "beam":  # 작은 방사기 + 끊기지 않는 금빛 빔
        block(12, 6, 18, 12, "#a5b29d")
        d.line((13, 7, 17, 7), fill=hi)
        d.line((19, 8, 35, 8), fill=GOLD)
        d.line((19, 9, 35, 9), fill="#f89419")
        d.line((19, 7, 26, 7), fill="#984633")
        d.line((19, 10, 26, 10), fill="#984633")
    return im


ICONS = {w["id"]: draw_icon(w["id"]) for w in WEAPONS}


def icon_for(w):
    """잠긴 무기는 어두운 윤곽 + 자물쇠"""
    ic = ICONS[w["id"]]
    if w["state"] != "lock":
        return ic
    out = silhouette(ic, "#3a1c57")
    out.alpha_composite(MINI_LOCK, (14, 5))
    return out


def plate(c, x, y, w, h, bright=True, border=None):
    p = nine(TAB, w, h)
    c.paste(p if bright else shade(p, 0.7), x, y)
    if border:
        c.d.rectangle((x + 1, y + 1, x + w - 2, y + h - 2), outline=border)


def button(c, x, y, w, h, label, off=False, cost=None):
    """WinButton과 같은 판 (여백 12칸) + 가운데 글자"""
    c.paste(nine(BTN_OFF if off else BTN, w, h - 1, 12), x, y)
    color = GREY if off else DARK
    ty = y + (h - 12) // 2  # WinButton보다 2칸 아래: 판 윗 테두리에 글자 머리가 걸리지 않게
    if cost is None:
        c.text(x + w // 2, ty, label, color, 0, limit=w - 8)
    else:
        total = width(label) + 4 + ORE.width + 2 + width(f"{cost:,}")
        tx = x + (w - total) // 2
        c.text(tx, ty, label, color)
        tx += width(label) + 4
        c.paste(ORE, tx, ty + 2)
        c.text(tx + ORE.width + 2, ty, f"{cost:,}", color)


def pips(c, x, y, lv, color, sz=5, gap=1):
    """5칸 눈금 (WindowArt.pips와 같은 모양)"""
    for i in range(5):
        r = (x + i * (sz + gap), y, x + i * (sz + gap) + sz - 1, y + sz - 1)
        c.d.rectangle(r, fill=DARK)
        c.d.rectangle((r[0] + 1, r[1] + 1, r[2] - 1, r[3] - 1), fill=color if i < lv else GREY)


def bar_rows(c, x, y, w, weapon, gap=13):
    """막대 3개를 세로로: 이름 왼쪽, 눈금 오른쪽"""
    for name, lv in zip(("사거리", "연사", "채굴량"), weapon["bars"]):
        c.text(x, y, name, BAR[name])
        pips(c, x + w - 29, y + 4, lv, BAR[name])
        y += gap
    return y


def bar_cols(c, x, y, w, weapon):
    """막대 3개를 가로로: 이름 위, 눈금 아래 (좁은 패널용, 높이 19)"""
    names = ("사거리", "연사", "채굴량")
    gap = (w - sum(max(width(n), 29) for n in names)) // 2  # 이름 폭에 맞춰 남는 칸을 고르게
    if gap < 4:
        PROBLEMS.append(f"{c.kind} 막대 칸 좁음 {gap}")
    for name, lv in zip(names, weapon["bars"]):
        c.text(x, y, name, BAR[name])
        pips(c, x, y + 14, lv, BAR[name])
        x += max(width(name), 29) + gap
    return y + 20


def wrap(s, w):
    lines, cur = [], ""
    for word in s.split(" "):
        t = (cur + " " + word).strip()
        if width(t) <= w:
            cur = t
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def para(c, x, y, s, color, w, gap=14):
    for ln in wrap(s, w):
        c.text(x, y, ln, color, limit=w)
        y += gap
    return y


def lock_line(c, x, y, w, weapon):
    """잠김 안내: 연구소에서 해금 · 가격 (플라스크는 아래 버튼에)"""
    s = "연구소에서 해금 ·"
    c.text(x, y, s, MUTED, limit=w)
    tx = x + width(s) + 3
    c.paste(ORE, tx, y + 2)
    c.text(tx + ORE.width + 2, y, f"{weapon['cost']:,}", GOLD)
    if tx + ORE.width + 2 + width(f"{weapon['cost']:,}") > x + w:
        PROBLEMS.append(f"{c.kind} 잠김 줄 넘침: {weapon['name']}")


# ── 아래 줄 무기 카드 (B·C 공통) ─────────────────
def card_row(c, sel, y=None, h=None, x=None, w=None):
    L = c.L
    bx, by, bw, bh = L["body"]
    x = bx if x is None else x
    w = bw if w is None else w
    h = L["slot_h"] if h is None else h
    y = by + bh - h if y is None else y
    cw = (w - 4 * 4) // 5
    c.clear(x, y, w, h)
    for i, wp in enumerate(WEAPONS):
        cx = x + i * (cw + 4)
        weapon_card(c, cx, y, cw, h, wp, wp["id"] == sel)


def weapon_card(c, x, y, w, h, wp, selected):
    st = wp["state"]
    plate(c, x, y, w, h, st != "lock", GOLD if st == "on" else (TEAL2 if selected else None))
    if selected and st == "on":  # 고른 것이 장착 중이면 금색 안에 청록 한 줄 더
        c.d.rectangle((x + 2, y + 2, x + w - 3, y + h - 3), outline=TEAL2)
    ic = icon_for(wp)
    if c.kind == "phone" and h < 30:  # 폰 B: 칸이 낮아 아이콘 + 상태만 (이름은 오른쪽 패널)
        c.paste(ic, x + 4, y + (h - 17) // 2)
        rx = x + w - 4
        ty = y + (h - 12) // 2 - 1
        if st == "on":
            c.text(rx, ty, "사용", GOLD, 1)
        elif st == "open":
            c.text(rx, ty, "해금", TEAL2, 1)
        else:
            c.text(rx, ty, f"{wp['cost']:,}", GOLD, 1)  # 광물 아이콘까지 넣으면 무기 그림과 겹쳐 금색 숫자만
        return
    if c.kind == "phone":  # 폰 C: 아이콘 위, 상태 아래 (이름은 77칸에 안 들어가 오른쪽 패널에)
        c.paste(ic, x + (w - 36) // 2, y + 1)
        if st == "lock":
            s = f"{wp['cost']:,}"
            tw = ORE.width + 2 + width(s)
            c.paste(ORE, x + (w - tw) // 2, y + 19)
            c.text(x + (w - tw) // 2 + ORE.width + 2, y + 17, s, MUTED)
        else:
            c.text(x + w // 2, y + 17, "장착 중" if st == "on" else "해금", GOLD if st == "on" else TEAL2, 0)
        return
    # PC: 1줄 아이콘 + 오른쪽 상태, 2줄 이름 (+ 잠김이면 가격)
    c.paste(ic, x + 6, y + 6)
    rx = x + w - 6
    if st == "on":
        c.text(rx, y + 7, "장착 중", GOLD, 1)
    elif st == "open":
        button(c, rx - 40, y + 3, 40, 22, "장착")
    else:  # 잠김: 플라스크(연구소) + 가격, 이름 옆 ▶ 로 연구소로 이어짐
        s = f"{wp['cost']:,}"
        c.text(rx, y + 7, s, MUTED, 1)
        c.paste(ORE, rx - width(s) - ORE.width - 1, y + 9)
        c.paste(FLASK, rx - width(s) - ORE.width - 20, y + 3)
        c.text(rx, y + 28, "▶", TEAL2, 1)
    name_col = DIM if st == "lock" else (GOLD if st == "on" else INK)
    c.text(x + 6, y + 28, wp["name"], name_col, limit=w - 12 - (14 if st == "lock" else 0))


def detail(c, x, y, w, h, wp, icon2=True):
    """오른쪽 설명 패널: 고른 무기 자세히 (B·C)"""
    plate(c, x, y, w, h)
    tx, tw = x + 10, w - 20
    ty = y + 8
    phone = c.kind == "phone"
    c.text(tx, ty, "기본 무기", MUTED)
    tag = {"on": ("장착 중", GOLD), "open": ("해금됨", TEAL2), "lock": ("잠김", DIM)}[wp["state"]]
    c.text(x + w - 10, ty, *tag, 1)
    ty += 15
    if icon2 and not phone:
        ic = icon_for(wp)
        c.paste(ic.resize((72, 34), Image.NEAREST), tx, ty)
        ty += 38
    c.text(tx, ty, wp["name"], GOLD if wp["state"] != "lock" else INK, limit=tw)
    ty += 15
    ty = para(c, tx, ty, wp["desc"], INK, tw) + 3
    if phone:
        ty = bar_cols(c, tx, ty, tw, wp)
    else:
        c.d.line((tx, ty, tx + tw - 1, ty), fill=GREY)
        ty = bar_rows(c, tx, ty + 4, tw, wp)
    bh = 22
    by = y + h - bh - (6 if phone else 8)
    if wp["state"] == "lock":
        if not phone:
            lock_line(c, tx, by - 18, tw, wp)
            button(c, tx, by, tw, bh, "연구소로 ▶")
            c.paste(FLASK, tx + 4, by)
        else:
            button(c, tx, by, tw, bh, "연구소로 ▶", cost=None)
            c.paste(FLASK, tx + 2, by - 1)
    elif wp["state"] == "open":
        button(c, tx, by, tw, bh, "장착")
    else:
        button(c, tx, by, tw, bh, "장착 중", off=True)
    if ty > by - (20 if (wp["state"] == "lock" and not phone) else 2):
        PROBLEMS.append(f"{c.kind} 설명 패널 넘침: {wp['name']} {ty} > {by}")


# ── 시안 A: 설명 패널 안 목록 ────────────────────
def mock_a(kind):
    c = Canvas(DIR + f"base_{kind}.png", kind)
    L = c.L
    bx, by, bw, bh = L["body"]
    area_h = bh - L["slot_h"] - 4
    sel = BY_ID["shot"]
    if kind == "pc":
        x, w = bx + bw - L["desc_w"], L["desc_w"]
        c.clear(x, by, w, area_h)
        plate(c, x, by, w, area_h)
        tx, tw = x + 8, w - 16
        ty = by + 7
        c.text(tx, ty, "◀ 기본 무기 고르기", GOLD, limit=tw)
        ty += 16
        for wp in WEAPONS:
            st = wp["state"]
            on = wp is sel
            rh = 21 if st != "lock" else 34
            if on:
                rh = 21 + 2 + 28 + 20 + 25
            if on or st == "on":
                c.d.rectangle((tx - 3, ty - 1, tx + tw + 2, ty + rh - 2), fill="#1f1420", outline=GOLD if st == "on" else TEAL2)
            c.paste(icon_for(wp), tx, ty + 1)
            col = DIM if st == "lock" else (GOLD if st == "on" else INK)
            c.text(tx + 40, ty + 3, wp["name"], col, limit=tw - 40 - 30)
            if st == "on":
                c.text(tx + tw, ty + 3, "장착 중", GOLD, 1)
            elif st == "open" and not on:
                c.text(tx + tw, ty + 3, "해금", TEAL2, 1)
            if st == "lock":  # 1줄 오른쪽 플라스크 ▶ (연구소로), 2줄 해금 안내
                c.paste(FLASK, tx + tw - 30, ty)
                c.text(tx + tw, ty + 3, "▶", TEAL2, 1)
                note = "연구소에서 해금 ·"
                c.text(tx, ty + 20, note, MUTED)
                px = tx + width(note) + 3
                c.paste(ORE, px, ty + 22)
                c.text(px + ORE.width + 2, ty + 20, f"{wp['cost']:,}", GOLD)
                if px + ORE.width + 2 + width(f"{wp['cost']:,}") > tx + tw:
                    PROBLEMS.append(f"A 잠김 줄 넘침 {wp['name']}")
            if on:  # 고른 무기: 설명 + 막대(가로) + 장착 버튼
                yy = para(c, tx, ty + 21, wp["desc"], INK, tw)
                yy = bar_cols(c, tx, yy + 1, tw, wp)
                button(c, tx, yy + 1, tw, 22, "장착")
                if yy + 23 > ty + rh:
                    PROBLEMS.append(f"A 펼친 칸 넘침 {yy + 20} > {ty + rh}")
            ty += rh + 1
        if ty > by + area_h - 4:
            PROBLEMS.append(f"A 목록 넘침 {ty} > {by + area_h - 4}")
    else:  # 폰: 패널 132칸에 5줄 + 막대가 안 들어가 가운데까지 넓혀 두 칸(목록 | 자세히)
        x = bx + L["stats_w"]
        w = bx + bw - x
        c.clear(x, by, w, area_h)
        plate(c, x, by, w, area_h)
        lw = 146
        tx = x + 6
        ty = by + 4
        c.text(tx, ty, "◀ 기본 무기", GOLD)
        ty += 15
        for wp in WEAPONS:
            st = wp["state"]
            if wp is sel or st == "on":
                c.d.rectangle((tx - 2, ty - 1, x + lw - 2, ty + 18), fill="#1f1420", outline=GOLD if st == "on" else TEAL2)
            c.paste(icon_for(wp), tx, ty + 1)
            c.text(tx + 39, ty + 2, wp["name"], DIM if st == "lock" else (GOLD if st == "on" else INK), limit=lw - 47)
            ty += 20
        c.d.line((x + lw + 2, by + 6, x + lw + 2, by + area_h - 8), fill=GREY)
        dx, dw = x + lw + 8, w - lw - 16
        dy = by + 4
        c.text(dx, dy, sel["name"], GOLD)
        c.text(dx + dw, dy, "해금됨", TEAL2, 1)
        dy = para(c, dx, dy + 15, sel["desc"], INK, dw)
        dy = bar_cols(c, dx, dy + 1, dw, sel)
        button(c, dx, by + area_h - 28, dw, 22, "장착")
        if dy > by + area_h - 28:
            PROBLEMS.append(f"A 폰 자세히 넘침 {dy}")
    return c


# ── 시안 B: 아래 줄 탭 ─────────────────────────
def tabs(c, x, y, h, active="기본 무기"):
    for name in ("전투기", "기본 무기"):
        w = width(name) + 16
        on = name == active
        p = nine(TAB, w, h)
        c.paste(p if on else shade(p, 0.6), x, y)
        if on:
            c.d.rectangle((x + 1, y + 1, x + w - 2, y + h - 2), outline=GOLD)
        c.text(x + w // 2, y + (h - 12) // 2 + 1, name, GOLD if on else MUTED, 0)
        x += w + 2


def mock_b(kind):
    c = Canvas(DIR + f"base_{kind}.png", kind)
    L = c.L
    bx, by, bw, bh = L["body"]
    area_h = bh - L["slot_h"] - 4
    sel = BY_ID["plasma"]
    if kind == "pc":
        c.clear(bx, by + area_h - 18, 160, 22)  # 마지막 능력치 막대 아래 빈 줄
        tabs(c, bx, by + area_h - 18, 21)
        card_row(c, "plasma")
    else:  # 폰: 탭 16칸을 넣으려고 카드 줄을 22칸으로 낮춤 (이름은 오른쪽 패널에)
        c.clear(bx, by + bh - 39, bw, 39)
        tabs(c, bx, by + bh - 39, 16)
        card_row(c, "plasma", y=by + bh - 22, h=22)
    x = bx + bw - L["desc_w"]
    c.clear(x, by, L["desc_w"], area_h)
    detail(c, x, by, L["desc_w"], area_h, sel)
    return c


# ── 시안 C: 무기 전용 화면 ──────────────────────
def mock_c(kind):
    c = Canvas(DIR + f"base_{kind}_noship.png", kind)
    L = c.L
    bx, by, bw, bh = L["body"]
    area_h = bh - L["slot_h"] - 4
    sel = BY_ID["rail"]
    phone = kind == "phone"
    # 왼쪽: 돌아가기 + 무기 능력치 4줄 (지금 능력치 막대와 같은 모양, 5칸 눈금)
    sw = L["stats_w"]
    c.clear(bx, by, sw - 4, area_h)
    button(c, bx + 2, by + 2, 76 if phone else 84, 22, "◀ 전투기")
    rows = list(zip(("사거리", "연사", "채굴량", "공격력"), (*sel["bars"], sel["atk"])))
    top = by + (26 if phone else 34)
    gap = (by + area_h - top) // 4
    x, w = bx + 4, sw - 12
    for i, (name, lv) in enumerate(rows):
        ry = top + i * gap
        c.text(x, ry, name, BAR[name])
        c.text(x + w, ry, f"{lv} / 5", INK, 1)
        seg = (w - 4 * 2) // 5  # 5칸 막대: 지금 능력치 막대(3칸 높이)를 5조각으로
        for k in range(5):
            sx = x + k * (seg + 2)
            c.d.rectangle((sx, ry + 13, sx + seg - 1, ry + 16), fill=DARK)
            c.d.rectangle((sx + 1, ry + 14, sx + seg - 2, ry + 15), fill=BAR[name] if k < lv else GREY)
    # 가운데: 받침 위에 무기 (우주선과 같은 배율: PC 3배, 폰 2배)
    k = 2 if phone else 3
    ic = ICONS[sel["id"]].resize((36 * k, 17 * k), Image.NEAREST)
    stage_x = bx + sw
    stage_w = bw - sw - L["desc_w"]
    cx = stage_x + stage_w // 2
    ped_h = sprite("pedestal").height * (1 if phone else 2)  # hangar_view._draw_stage와 같은 계산
    mid = by + area_h - 2 - ped_h + (8 + 17) * (1 if phone else 2)
    lift = 40 if phone else 62
    sh = ImageDraw.Draw(c.im)
    shw = 16 * (1 if phone else 2)
    sh.ellipse((cx - shw, mid - shw // 4, cx + shw, mid + shw // 4), fill="#0e2b2c")
    c.paste(ic, cx - ic.width // 2, mid - lift - ic.height // 2)
    c.text(cx, by + 4, sel["name"], GOLD, 0)
    # 아래: 무기 카드 5개, 오른쪽: 설명 + 장착
    card_row(c, "rail")
    x = bx + bw - L["desc_w"]
    c.clear(x, by, L["desc_w"], area_h)
    plate(c, x, by, L["desc_w"], area_h)
    tx, tw = x + 10, L["desc_w"] - 20
    ty = by + 8
    c.text(tx, ty, sel["name"], GOLD)
    c.text(x + L["desc_w"] - 10, ty, "해금됨", TEAL2, 1)
    ty = para(c, tx, ty + 15, sel["desc"], INK, tw) + 2
    if not phone:
        c.d.line((tx, ty, tx + tw - 1, ty), fill=GREY)
        c.text(tx, ty + 4, "지금 장착", MUTED)
        c.paste(ICONS["pulse"], tx, ty + 20)
        c.text(tx + 40, ty + 22, "펄스 연사포", TEAL2, limit=tw - 40)
    else:
        c.text(tx, ty, "지금: 펄스 연사포", MUTED, limit=tw)
    bh2 = 22
    button(c, tx, by + area_h - bh2 - (6 if phone else 8), tw, bh2, "장착")
    return c


def main():
    for kind, tag in (("pc", "pc_1280x720"), ("phone", "phone_844x390")):
        for name, fn in (("a_panel_list", mock_a), ("b_bottom_tabs", mock_b), ("c_weapon_screen", mock_c)):
            fn(kind).save(f"{name}_{tag}.png")
    for p in PROBLEMS:
        print("문제:", p)
    assert not PROBLEMS, len(PROBLEMS)
    print("6장 완료")


if __name__ == "__main__":
    main()
