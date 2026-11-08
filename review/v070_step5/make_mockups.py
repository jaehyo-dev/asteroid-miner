"""레벨업 카드 시안 생성기 (게임에 적용하지 않음). 진짜 출격 화면 캡처 위에 카드를 그린다.
- 카드 층은 논리 픽셀로 그린 뒤 화면 배율(PC 2배, 폰 1배) 정수로만 키운다. 글자는 Galmuri11 12px과 그 2배(24px)를 앤티에일리어싱 없이.
- 빛은 층마다 일정한 알파를 가진 계단 띠라서 픽셀 격자를 벗어나지 않는다.
실행: python3 review/v070_step5/make_mockups.py <bg_pc.png> <bg_phone.png> → review/v070_step5/*.png"""
import sys
from PIL import Image, ImageDraw, ImageFont

D = "review/v070_step5/"
FONT = "assets/fonts/galmuri/Galmuri11.ttf"
F12, F24 = ImageFont.truetype(FONT, 12), ImageFont.truetype(FONT, 24)
ICONS = {n: Image.open(f"{D}icons/{n}.png").convert("RGBA") for n in ("cooler", "pierce", "drone")}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


GRADE = {"노멀": "#a5b29d", "레어": "#99e9e6", "에픽": "#a884f3", "유니크": "#f6ce50"}
RAINBOW = ["#ff2567", "#fb6b1d", "#f6ce50", "#a5cc5f", "#30e1b9", "#4d80cd", "#a884f3"]
INK, MUTED, DARK, PANEL, PANEL2, LINE = "#fef8e5", "#a5b29d", "#14111c", "#2b1925", "#3c3544", "#5c5164"

# 예시 카드 (이름, 종류, 효과, 단계, 최대, 등급, 아이콘)
COOLER = ("시스템 쿨러 개량", "공격", "발사 속도 +15%", 2, 5, "레어", "cooler")
PIERCE = ("텅스텐 관통탄", "공격", "탄이 대상 1개를 더 뚫고 지나감", 1, 3, "에픽", "pierce")
DRONE = ("호위 드론 사출", "드론", "드론 2기가 따라다니며 함께 공격", 1, 3, "유니크", "drone")
THREE = [COOLER, PIERCE, DRONE]
FIVE = [("시스템 쿨러 개량", "공격", "발사 속도 +10%", 1, 5, "노멀", "cooler"), COOLER, PIERCE, DRONE,
        ("궤도 관통 가속기", "공격", "모든 탄이 사거리 끝까지 관통", 1, 1, "레전드리", "pierce")]


def wrap(text, font, width):
    """글자 폭에 맞춰 줄 나누기 (빈칸 기준, 한 낱말이 넘치면 글자 단위)"""
    lines, cur = [], ""
    for word in text.split(" "):
        t = (cur + " " + word).strip()
        if font.getlength(t) <= width:
            cur = t
            continue
        if cur:
            lines.append(cur)
        cur = word
        while font.getlength(cur) > width:
            n = len(cur)
            while font.getlength(cur[:n]) > width:
                n -= 1
            lines.append(cur[:n])
            cur = cur[n:]
    lines.append(cur)
    return lines


class Layer:
    """논리 픽셀 그림판"""

    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"  # 앤티에일리어싱 없음

    def text(self, x, y, s, font, color, anchor="la"):
        self.d.text((x, y), s, font=font, fill=color, anchor=anchor)

    def rect(self, x, y, w, h, color):
        c = rgb(color) if isinstance(color, str) else color
        if w > 0 and h > 0:
            self.im.alpha_composite(Image.new("RGBA", (w, h), c if len(c) == 4 else (*c, 255)), (x, y))


def border_cells(w, h, cut, t):
    """모서리를 cut만큼 계단으로 깎은 사각형의 테두리 좌표(둘레 순서가 아닌 집합) (두께 t)"""
    def inside(x, y, m):
        if not (m <= x < w - m and m <= y < h - m):
            return False
        c = max(cut - m, 0)
        dx = min(x - m, w - 1 - m - x)
        dy = min(y - m, h - 1 - m - y)
        return dx + dy >= c
    return inside


GLOW = {"노멀": 1, "레어": 2, "에픽": 3, "유니크": 4, "레전드리": 5}  # 등급이 높을수록 빛 띠가 많다
GLOW_ALPHA = (130, 85, 55, 32, 16)


def glow_for(grade, s):
    return tuple(a for a in GLOW_ALPHA[:GLOW[grade]] for _ in range(s["u"]))


def fill_shape(layer, x0, y0, w, h, cut, border, t, fill, glow=None, glow_steps=()):
    """깎인 사각형: 바깥 빛 띠 → 테두리 → 안쪽 채우기. border가 함수면 둘레 위치별 색(무지개)."""
    inside = border_cells(w, h, cut, t)
    px = layer.im.load()
    fill_c = rgb(fill) if isinstance(fill, str) else fill
    if len(fill_c) == 3:
        fill_c = (*fill_c, 255)
    # 빛: 카드 바깥쪽 계단 띠 (색은 등급 색, 알파만 줄어듦)
    for i, a in enumerate(glow_steps):
        m = i + 1
        for y in range(-m, h + m):
            for x in range(-m, w + m):
                dx = min(x + m, w - 1 + m - x)
                dy = min(y + m, h - 1 + m - y)
                on_edge = min(dx, dy) == 0 or dx + dy == max(cut, 0)
                if on_edge and dx + dy >= max(cut, 0) and not inside(x, y, 0):
                    px_x, px_y = x0 + x, y0 + y
                    if 0 <= px_x < layer.im.width and 0 <= px_y < layer.im.height:
                        c = border(x, y) if callable(border) else rgb(border)
                        layer.im.alpha_composite(Image.new("RGBA", (1, 1), (*c, a)), (px_x, px_y))
    for y in range(h):
        for x in range(w):
            if not inside(x, y, 0):
                continue
            if inside(x, y, t):
                px[x0 + x, y0 + y] = fill_c
                if glow_steps and not inside(x, y, t + t):  # 패널 칸 앞까지만  # 안쪽으로도 빛이 번짐
                    c = border(x, y) if callable(border) else rgb(border)
                    layer.im.alpha_composite(Image.new("RGBA", (1, 1), (*c, 60)), (x0 + x, y0 + y))
            else:
                c = border(x, y) if callable(border) else rgb(border)
                px[x0 + x, y0 + y] = (*c, 255)


def grade_border(grade, w, h):
    if grade != "레전드리":
        return GRADE[grade]
    band = max((w + h) // 14, 1)  # 대각선 무지개 띠
    return lambda x, y: rgb(RAINBOW[((x + y) // band) % len(RAINBOW)])


def grade_ink(grade):
    return GRADE.get(grade, RAINBOW[2])


def dots(l, x, y, step, maxi, color, size, gap, center_w=None):
    total = maxi * size + (maxi - 1) * gap
    if center_w is not None:
        x += (center_w - total) // 2
    for i in range(maxi):
        if i < step:
            l.rect(x + i * (size + gap), y, size, size, color)
        else:
            l.rect(x + i * (size + gap), y, size, size, LINE)
            l.rect(x + i * (size + gap) + 1, y + 1, size - 2, size - 2, DARK)


def chip(l, x, y, s, font, color, u):
    w = int(font.getlength(s)) + 8 * u
    h = font.size + 4 * u
    l.rect(x, y, w, h, DARK)
    l.rect(x, y, u, h, color)
    l.text(x + 4 * u + u, y + 2 * u, s, font, INK)
    return w


# ── 시안 A: 격납고 패널 (깎은 모서리, 아이콘 칸 가운데, 글자 가운데 정렬, 배경 고르게 어둡게) ──
def card_a(l, x, y, w, h, c, s):
    name, kind, desc, step, maxi, grade, icon = c
    u = s["u"]
    fill_shape(l, x, y, w, h, 6 * u, grade_border(grade, w, h), 2 * u, PANEL, glow_steps=glow_for(grade, s))
    bay_h = h // 2 - 4 * u
    l.rect(x + 4 * u, y + 4 * u, w - 8 * u, bay_h, DARK)
    for i in range(0, w - 8 * u, 8 * u):  # 칸 위아래 작은 눈금
        l.rect(x + 4 * u + i, y + 4 * u, u, 2 * u, PANEL2)
        l.rect(x + 4 * u + i, y + 4 * u + bay_h - 2 * u, u, 2 * u, PANEL2)
    ic = ICONS[icon].resize((48 * s["icon"], 48 * s["icon"]), Image.NEAREST)
    l.im.alpha_composite(ic, (x + (w - ic.width) // 2, y + 4 * u + (bay_h - ic.height) // 2))
    ty = y + 4 * u + bay_h + 3 * u
    for line in wrap(name, s["name"], w - 10 * u):
        l.text(x + w // 2, ty, line, s["name"], INK, "ma")
        ty += s["name"].size + 2
    ty = y + 4 * u + bay_h + 3 * u + s["name_h"] + u
    cw = int(s["desc"].getlength(kind)) + 9 * u
    chip(l, x + (w - cw) // 2, ty, kind, s["desc"], grade_ink(grade), u)
    ty += s["desc"].size + 4 * u + 3 * u
    for line in wrap(desc, s["desc"], w - 12 * u):
        l.text(x + w // 2, ty, line, s["desc"], MUTED, "ma")
        ty += s["desc"].size + 2
    dots(l, x, y + h - 9 * u, step, maxi, grade_ink(grade), 5 * u, 2 * u, w)


# ── 시안 B: 장갑 판 (곧은 판 + 굵은 모서리 쇠, 볼트, 아이콘 크게 위쪽 가득, 왼쪽 정렬, 배경 비네트) ──
def card_b(l, x, y, w, h, c, s):
    name, kind, desc, step, maxi, grade, icon = c
    u = s["u"]
    b = grade_border(grade, w, h)
    fill_shape(l, x, y, w, h, 0, b, u, PANEL2, glow_steps=glow_for(grade, s))
    l.rect(x + u, y + u, w - 2 * u, h // 2, PANEL)
    # 모서리 쇠: 등급 색 ㄱ자 굵은 쇠
    m = 12 * u
    t = 3 * u
    for cx, cy, sx, sy in ((x, y, 1, 1), (x + w, y, -1, 1), (x, y + h, 1, -1), (x + w, y + h, -1, -1)):
        hx = cx if sx > 0 else cx - m
        hy = cy if sy > 0 else cy - t
        vx = cx if sx > 0 else cx - t
        vy = cy if sy > 0 else cy - m
        for rx, ry, rw, rh in ((hx, hy, m, t), (vx, vy, t, m)):
            for yy in range(ry, ry + rh):
                for xx in range(rx, rx + rw):
                    col = b(xx - x, yy - y) if callable(b) else rgb(b)
                    l.im.putpixel((xx, yy), (*col, 255))
    ic = ICONS[icon].resize((48 * s["icon"], 48 * s["icon"]), Image.NEAREST)
    l.im.alpha_composite(ic, (x + (w - ic.width) // 2, y + 6 * u + max((h // 2 - 8 * u - ic.height) // 2, 0)))
    ty = y + h // 2 + 5 * u
    top = ty
    for line in wrap(name, s["name"], w - 11 * u):
        l.text(x + 6 * u, ty, line, s["name"], grade_ink(grade))
        ty += s["name"].size + 2
    ty = top + s["name_h"]
    l.rect(x + 6 * u, ty + u, w - 12 * u, u, LINE)
    ty += 4 * u
    for line in wrap(desc, s["desc"], w - 12 * u):
        l.text(x + 6 * u, ty, line, s["desc"], INK)
        ty += s["desc"].size + 2
    dots(l, x + 6 * u, y + h - 9 * u, step, maxi, grade_ink(grade), 5 * u, 2 * u)
    l.text(x + w - 6 * u, y + h - 6 * u - F12.size, f"[{kind}]", F12, grade_ink(grade), "ra")


# ── 시안 C: 스캔 창 (얇은 선 + 모서리 눈금, 비치는 판, 이름이 맨 위, 단계가 옆줄, 위아래 띠 배경) ──
def card_c(l, x, y, w, h, c, s):
    name, kind, desc, step, maxi, grade, icon = c
    u = s["u"]
    fill_shape(l, x, y, w, h, 2 * u, grade_border(grade, w, h), u, (20, 17, 28, 240), glow_steps=glow_for(grade, s))
    ty = y + 4 * u
    for line in wrap(name, s["name"], w - 10 * u):
        l.text(x + 5 * u, ty, line, s["name"], INK)
        ty += s["name"].size + 2
    ty = y + 4 * u + s["name_h"]
    l.text(x + 5 * u, ty + u, f"[ {kind} ]", s["desc"], grade_ink(grade))
    ty += s["desc"].size + 4 * u
    ic = ICONS[icon].resize((48 * s["icon"], 48 * s["icon"]), Image.NEAREST)
    bay = ic.height + 8 * u
    bx, bw = x + 4 * u, w - 8 * u - 8 * u
    l.rect(bx, ty, bw, bay, (*rgb(PANEL), 200))
    for yy in range(ty, ty + bay, 2 * u):  # 스캔 줄
        l.rect(bx, yy, bw, u, (*rgb(grade_ink(grade)), 26))
    l.im.alpha_composite(ic, (bx + (bw - ic.width) // 2, ty + 4 * u))
    # 단계: 오른쪽 세로 눈금 (아래부터 찬다)
    size = 6 * u
    for i in range(maxi):
        yy = ty + bay - (i + 1) * (size + 2 * u) + 2 * u
        col = grade_ink(grade) if i < step else LINE
        l.rect(x + w - 10 * u, yy, 6 * u, size, col)
        if i >= step:
            l.rect(x + w - 10 * u + u, yy + u, 4 * u, size - 2 * u, DARK)
    ty += bay + 3 * u
    for line in wrap(desc, s["desc"], w - 10 * u):
        l.text(x + 5 * u, ty, line, s["desc"], MUTED)
        ty += s["desc"].size + 2


def reroll(l, x, y, w, s, style):
    u = s["u"]
    h = s["btn"]
    l.rect(x, y, w, h, LINE if style != "C" else (43, 25, 37, 225))
    l.rect(x + u, y + u, w - 2 * u, h - 2 * u, PANEL if style != "C" else (20, 17, 28, 225))
    label = "다시 뽑기"
    f = s["btn_font"]
    l.text(x + w // 2 - int(f.getlength("2회")) // 2 - 3 * u, y + (h - f.size) // 2, label, f, INK, "ma")
    l.text(x + w - 6 * u, y + (h - f.size) // 2, "2회", f, RAINBOW[2], "ra")


# 화면별 값: 카드 폭·높이·간격, 위쪽 여백, 글자, 아이콘 배율, 카드 층 격자 u
PC = {"size": (640, 360), "k": 2, "gap": 10, "btn": 22, "btn_gap": 4, "btn_font": F12}
PHONE = {"size": (844, 390), "k": 1, "gap": 12, "btn": 34, "btn_gap": 6, "btn_font": F24}
STYLES = {
    # A: 폰 설명 12px(CSS 12px), 이름 24px
    "A": {"fn": card_a, "PC": dict(w=196, h=262, u=1, name=F24, desc=F12, icon=2),
          "PHONE": dict(w=262, h=336, u=2, name=F24, desc=F12, icon=3)},
    # B: 폰 설명도 24px(색으로 구분), 이름 24px
    "B": {"fn": card_b, "PC": dict(w=196, h=296, u=1, name=F24, desc=F12, icon=3),
          "PHONE": dict(w=262, h=336, u=2, name=F24, desc=F24, icon=3)},
    # C: 이름이 맨 위, 설명 폰 24px, 아이콘 작게
    "C": {"fn": card_c, "PC": dict(w=196, h=232, u=1, name=F24, desc=F12, icon=2),
          "PHONE": dict(w=262, h=292, u=2, name=F24, desc=F24, icon=2)},
}


def backdrop(bg, style, k):
    """배경 처리: 실제 화면 픽셀(배율 적용 뒤)에서 어둡게"""
    w, h = bg.size
    out = bg.convert("RGBA")
    if style == "A":  # 고르게 어둡게
        out.alpha_composite(Image.new("RGBA", (w, h), (8, 6, 14, 165)))
    elif style == "B":  # 비네트 반대: 가운데 어둡고 가장자리로 갈수록 화면이 보임, 계단 띠
        cx, cy = w / 2, h / 2
        px = Image.new("L", (w // k, h // k))
        a = px.load()
        for y in range(h // k):
            for x in range(w // k):
                d = max(abs(x * k - cx) / cx, abs(y * k - cy) / cy)
                a[x, y] = 200 if d < 0.8 else 150 if d < 0.9 else 105
        m = Image.new("RGBA", (w, h), (8, 6, 14, 255))
        m.putalpha(px.resize((w, h), Image.NEAREST))
        out.alpha_composite(m)
    else:  # 위아래 검은 띠, 가운데는 살짝만 어둡게 (전투 상황이 가장 잘 보임)
        out.alpha_composite(Image.new("RGBA", (w, h), (8, 6, 14, 90)))
        band = 14 * k
        ImageDraw.Draw(out).rectangle((0, 0, w, band - 1), fill=(8, 6, 14, 255))
        ImageDraw.Draw(out).rectangle((0, h - band, w, h), fill=(8, 6, 14, 255))
    return out


def name_block(cards, s):
    """카드끼리 글줄이 맞게, 가장 긴 이름에 맞춘 이름 칸 높이"""
    return max(len(wrap(c[0], s["name"], s["w"] - 11 * s["u"])) for c in cards) * (s["name"].size + 2)


def screen(style, kind, bg):
    sc = PC if kind == "PC" else PHONE
    st = STYLES[style]
    s = {**st[kind], **sc}
    W, H = sc["size"]
    l = Layer(W, H)
    total = 3 * s["w"] + 2 * s["gap"]
    x0 = (W - total) // 2
    y = (H - s["h"] - s["btn_gap"] - s["btn"]) // 2
    s["name_h"] = name_block(THREE, s)
    for i, c in enumerate(THREE):
        x = x0 + i * (s["w"] + s["gap"])
        st["fn"](l, x, y, s["w"], s["h"], c, s)
        reroll(l, x, y + s["h"] + s["btn_gap"], s["w"], s, style)
    k = sc["k"]
    out = backdrop(bg, style, k)
    out.alpha_composite(l.im.resize((W * k, H * k), Image.NEAREST))
    return out.convert("RGB")


def grades_sheet(style):
    """다섯 등급 비교 (PC와 같은 2배 픽셀). 다섯 장이 다 들어가도록 넓은 판에."""
    s = {**STYLES[style]["PC"], **PC}
    s["name_h"] = name_block(FIVE, s)
    W, H = 5 * s["w"] + 6 * 12, s["h"] + 44
    l = Layer(W, H)
    l.rect(0, 0, W, H, DARK)
    for i, c in enumerate(FIVE):
        x = 12 + i * (s["w"] + 12)
        l.text(x + s["w"] // 2, 8, c[5], F12, grade_ink(c[5]), "ma")
        STYLES[style]["fn"](l, x, 28, s["w"], s["h"], c, s)
    return l.im.resize((W * 2, H * 2), Image.NEAREST).convert("RGB")


if __name__ == "__main__":
    bg = {"PC": Image.open(sys.argv[1]), "PHONE": Image.open(sys.argv[2])}
    for style in STYLES:
        screen(style, "PC", bg["PC"]).save(f"{D}mock_{style}_pc_1280x720.png")
        screen(style, "PHONE", bg["PHONE"]).save(f"{D}mock_{style}_phone_844x390.png")
        grades_sheet(style).save(f"{D}mock_{style}_grades.png")
    print("시안 저장")
