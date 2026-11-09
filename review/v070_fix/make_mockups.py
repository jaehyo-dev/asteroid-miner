"""v0.7.0 건물 창 시안 (게임에 적용하지 않음). Codex 원본 → void32 픽셀 부품 → 공통 틀 + 건물 5개 + 연구소 A·B → 캡처·GIF.
수치·이름 원본은 data.json (게임 로직 BaseUpgrades·Hangar·Discovery에서 뽑음. 값을 지어내지 않는다).
PC는 논리 640x360의 2배, 폰은 844x390의 1배로 그린다 (카드 프레임과 같은 규칙, 한 화면 안 정수 배율).
실행: python3 review/v070_fix/make_mockups.py → review/v070_fix/ 아래 png, gif"""
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

sys.path.insert(0, "review/v070_step5/frame")
os.chdir(".")
from make_frames import near, nine, pixelize, rgb  # noqa: E402

OUT = "review/v070_fix/"
RAW = "assets/raw/base_panel/"
FONT = "assets/fonts/galmuri/Galmuri11.ttf"
F12, F24 = ImageFont.truetype(FONT, 12), ImageFont.truetype(FONT, 24)
DATA = json.load(open(OUT + "data.json"))
INK, MUTED, DARK, PLATE = "#fef8e5", "#a5b29d", "#14111c", "#2b1925"
TEAL, TEAL2, GOLD, GREY = "#30e1b9", "#99e9e6", "#f6ce50", "#5c5164"
CREDITS = 780  # 시안의 보유 광물: 강화 가능·광물 부족 상태가 다 보이는 값
WARN = []

# 가지별 색 (무기 빨강, 선체 파랑, 채굴 금색): (본색, 밝은 색)
BRANCH = {"weapon": ("#cb3738", "#f25c76"), "hull": ("#4d80cd", "#99e9e6"), "mine": ("#f89419", "#f6ce50")}
BRANCH_NAME = {"weapon": "무기 계통", "hull": "선체 계통", "mine": "채굴 계통"}
# 노드 이름은 이름 후보 표 1번 후보. "lock"은 나중 칸 자리 (수치 없음)
TREE = {
    "weapon": ["damage", {"lock": "보조 무기 해금", "tag": "v0.8.0 제안"}, {"lock": "제안"}, {"lock": "제안"}],
    "hull": ["max_hp", "insurance", {"lock": "제안"}, {"lock": "제안"}],
    "mine": ["speed", "cargo", "magnet", {"lock": "제안"}, {"lock": "제안"}],
}
NODE_NAME = {"damage": "펄스 증폭기", "max_hp": "선체 장갑판", "insurance": "비상 탈출 캡슐", "speed": "추진기 튜닝", "cargo": "화물 베이 확장", "magnet": "견인 빔"}
NODE_ICON = {"damage": 0, "max_hp": 1, "insurance": 2, "speed": 3, "cargo": 4, "magnet": 5}
NODE_DESC = {"damage": "탄에 실리는 펄스를 키워요.", "max_hp": "선체에 장갑을 덧대요.", "insurance": "죽어도 건지는 화물이 늘어요.",
             "speed": "추진기를 다시 맞춰요.", "cargo": "한 판에 싣는 양이 늘어요.", "magnet": "광물을 더 멀리서 끌어와요."}
SAMPLE = DATA["sample"]
# 건물: 제목(유지안), 16칸 아이콘 번호 (base_icons)
BUILD = {"research": ("연구소", 0), "hangar": ("격납고", 1), "storage": ("광물 창고", 3), "museum": ("전시관", 4), "drone": ("드론 공장", 2)}
HAULED = [412, 96, 23, 3]
GRADE_COLOR = [MUTED, TEAL2, "#a884f3", GOLD]
FOUND = {"mineral_0", "mineral_1", "mineral_2", "rock_0", "rock_1", "rock_2", "jelly"}
SHORT = {"mineral_0": "어디서나 나오는 기본 광물.", "mineral_1": "푸른 결이 도는 광물.", "mineral_2": "운석 깊은 곳에서 나오는 광물.", "mineral_3": "아주 드문 광물.",
         "rock_0": "작지만 많이 떠다닌다.", "rock_1": "부수면 작은 조각으로 흩어진다.", "rock_2": "단단하고 광물이 많다. 부수면 화면이 흔들린다.", "golden": "습격 중에만 나타나는 금빛 운석.",
         "jelly": "천천히 끈질기게 쫓아온다.", "bug": "무리 지어 돌진한다.", "guard": "따라다니며 에너지탄을 쏜다. 좋은 광물을 준다.", "barrage": "심연에서 날아오는 포격. 부술 수 없다."}


# ── 부품 ──────────────────────────────────────
def objects(raw: Image.Image, min_area: int = 1500):
    """시트에서 마젠타 아닌 덩어리를 찾아 (위→아래, 왼쪽→오른쪽 줄 단위) 잘라 낼 칸으로 돌려준다"""
    a = np.asarray(raw.convert("RGB")).astype(int)
    mask = ~((a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 110))
    labels, _ = ndimage.label(ndimage.binary_closing(mask, iterations=3))
    boxes = [s for s in ndimage.find_objects(labels) if (s[0].stop - s[0].start) * (s[1].stop - s[1].start) > min_area]
    return [(s[1].start, s[0].start, s[1].stop, s[0].stop) for s in boxes]


def cut(raw, box, width):
    """칸을 잘라 가로 width칸 픽셀 격자로 줄인다 (void32, 투명도 0/255)"""
    pad = 2
    c = raw.crop((box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad)).convert("RGB")
    return pixelize(c, c.width / width)


def grid_boxes(raw, cols, rows):
    """떨어진 조각이 있는 아이콘 시트: 칸마다 마젠타 아닌 부분 전체를 한 덩어리로"""
    a = np.asarray(raw.convert("RGB")).astype(int)
    mask = ~((a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 110))
    h, w = mask.shape
    out = []
    for r in range(rows):
        for q in range(cols):
            x0, y0 = q * w // cols, r * h // rows
            ys, xs = np.nonzero(mask[y0:(r + 1) * h // rows, x0:(q + 1) * w // cols])
            out.append((x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1))
    return out


def by_rows(boxes, row_tol):
    rows = []
    for b in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        if rows and abs((b[1] + b[3]) / 2 - np.mean([(x[1] + x[3]) / 2 for x in rows[-1]])) < row_tol:
            rows[-1].append(b)
        else:
            rows.append([b])
    return [b for r in rows for b in sorted(r, key=lambda x: x[0])]


def load_parts():
    p = {}
    raw = Image.open(RAW + "panel_kit.png")
    b = by_rows(objects(raw), 60)
    assert len(b) == 8, len(b)
    u = 5.66  # 원본 한 칸 크기
    for name, box in zip(("frame", "head", "btn", "btn_down", "btn_off", "close", "tab", "rail"), b):
        p[name] = cut(raw, box, round((box[2] - box[0]) / u))
    raw = Image.open(RAW + "node_kit.png")
    b = by_rows(objects(raw), 90)
    assert len(b) == 6, len(b)
    for name, box, w in zip(("socket_on", "socket_off", "socket_lock", "core", "lock", "pipe"), b, (40, 40, 40, 64, 14, 40)):
        p[name] = cut(raw, box, w)
    raw = Image.open(RAW + "node_icons.png")
    b = grid_boxes(raw, 3, 3)
    p["node_icons"] = [cut(raw, x, 24) for x in b[:6]]
    p["emblem"] = {k: cut(raw, x, 14) for k, x in zip(("weapon", "hull", "mine"), b[6:])}
    raw = Image.open("assets/raw/base_v070c/base_icons.png")
    b = grid_boxes(raw, 3, 3)
    p["build_icons"] = [cut(raw, x, 16) for x in b]
    raw = Image.open(RAW + "hangar_bay.png")
    p["bay"] = cut(raw, objects(raw)[0], 208)
    p["bay_pc"] = cut(raw, objects(raw)[0], 184)
    raw = Image.open(RAW + "tank.png")
    b = sorted(objects(raw), key=lambda x: x[0])
    p["tank"], p["vault"] = cut(raw, b[0], 88), cut(raw, b[1], 150)
    raw = Image.open(RAW + "vitrine.png")
    b = sorted(objects(raw), key=lambda x: x[0])
    p["case_on"], p["case_off"] = cut(raw, b[0], 72), cut(raw, b[1], 72)
    # 구현 때 쓸 부품을 저장
    os.makedirs(OUT + "parts", exist_ok=True)
    for k, v in p.items():
        if isinstance(v, Image.Image):
            v.save(f"{OUT}parts/{k}.png")
    for i, v in enumerate(p["node_icons"]):
        v.save(f"{OUT}parts/node_icon_{i}.png")
    for k, v in p["emblem"].items():
        v.save(f"{OUT}parts/emblem_{k}.png")
    for i, v in enumerate(p["build_icons"]):
        v.save(f"{OUT}parts/build_icon_{i}.png")
    return p


def tint(im, mapping):
    """팔레트 색 바꾸기 {원본 hex: 새 hex}"""
    out = np.array(im)
    src = out.copy()
    for a, b in mapping.items():
        m = (src[..., :3] == np.array(rgb(a))).all(axis=2)
        out[m, :3] = rgb(b)
    return Image.fromarray(out, "RGBA")


def rim(im, branch):
    """소켓의 청록 빛을 가지 색으로"""
    main, light = BRANCH[branch]
    return tint(im, {TEAL: main, TEAL2: light, "#1da775": main, "#125952": main})


def darken(im, f=0.45):
    """잠긴 칸: 어둡게 한 뒤 가장 가까운 void32 색으로 (불투명 유지)"""
    a = np.array(im)
    cache = {}
    for y, x in zip(*np.nonzero(a[..., 3])):
        c = tuple(int(v) for v in a[y, x, :3])
        if c not in cache:
            cache[c] = near(tuple(int(v * f) for v in c))
        a[y, x, :3] = cache[c]
    return Image.fromarray(a, "RGBA")


def silhouette(im):
    a = np.array(im)
    a[a[..., 3] > 0, :3] = (0, 0, 0)
    return Image.fromarray(a, "RGBA")


def outline_only(im, color):
    """그림 윤곽과 굵은 경계만 선으로 (설계도)"""
    a = np.array(im).astype(int)
    lum = a[..., :3].sum(axis=2)
    alpha = a[..., 3] > 0
    edge = np.zeros(alpha.shape, bool)
    edge[1:-1, 1:-1] = alpha[1:-1, 1:-1] & ((np.abs(lum[1:-1, 1:-1] - lum[1:-1, 2:]) > 170) | (np.abs(lum[1:-1, 1:-1] - lum[2:, 1:-1]) > 170) | ~alpha[1:-1, 2:] | ~alpha[2:, 1:-1] | ~alpha[1:-1, :-2] | ~alpha[:-2, 1:-1])
    out = np.zeros((*alpha.shape, 4), np.uint8)
    out[edge] = (*rgb(color), 255)
    return Image.fromarray(out, "RGBA")


def sprite(path):
    return Image.open(path).convert("RGBA")


def discovery_icon(eid):
    """도감 그림: 출격 그림의 첫 칸에서 그림만 잘라 40칸 안으로 (정수로만 줄임)"""
    if eid.startswith("mineral_"):
        return sprite(f"assets/sprites/run/{eid}.png").resize((2 * sprite(f"assets/sprites/run/{eid}.png").width, 2 * sprite(f"assets/sprites/run/{eid}.png").height), Image.NEAREST)
    if eid == "barrage":
        im = sprite("assets/sprites/run/barrage_shot.png").crop((0, 0, 20, 20))
        return im.crop(im.getbbox()).resize((40, 40), Image.NEAREST)
    name, c = {"rock_0": ("rock_0", 64), "rock_1": ("rock_1", 96), "rock_2": ("rock_2", 144), "golden": ("rock_gold", 96), "jelly": ("jelly", 64), "bug": ("bug", 64), "guard": ("guard", 64)}[eid]
    im = sprite(f"assets/sprites/run/{name}.png").crop((0, 0, c, c))
    im = im.crop(im.getbbox())
    d = max(1, (max(im.size) + 39) // 40)
    return im.resize((im.width // d, im.height // d), Image.NEAREST) if d > 1 else im


# ── 화면 기준 ──────────────────────────────────
SCREEN = {
    "pc": dict(size=(640, 360), k=2, win=(6, 6, 628, 348), head=28, big=F12, small=F12, detail=188, head_icon=1, close=1),
    "phone": dict(size=(844, 390), k=1, win=(6, 4, 832, 382), head=44, big=F24, small=F12, detail=236, head_icon=2, close=2),
}
INSET = 15  # 틀 안쪽 시작 (발광 띠 안쪽)


class Ctx:
    def __init__(self, parts, kind):
        self.p, self.kind, self.s = parts, kind, SCREEN[kind]
        self.W, self.H = self.s["size"]


def text(d, x, y, s, font, color, anchor="la", limit=None):
    if limit is not None and font.getlength(s) > limit:
        WARN.append(f"글자 넘침: {s} {font.getlength(s):.0f} > {limit}")
    d.text((x, y), s, font=font, fill=color, anchor=anchor)


def draw(layer):
    d = ImageDraw.Draw(layer)
    d.fontmode = "1"
    return d


def plate(c, name, w, h):
    im = c.p[name]
    return nine(im, w, h, im.width // 2 - 1, im.height // 2 - 1)


def button(c, w, h, label, state="up", cost=None):
    """눌리게 생긴 버튼 하나로 통일. up 켜짐, down 눌림, off 꺼짐"""
    name = {"up": "btn", "down": "btn_down", "off": "btn_off"}[state]
    im = c.p[name]
    out = Image.new("RGBA", (w, h + 2), (0, 0, 0, 0))
    b = nine(im, w, h, 12, im.height // 2 - 1)
    out.alpha_composite(b, (0, 1 if state == "down" else 0))
    d = draw(out)
    f = c.s["big"] if c.kind == "phone" else F12
    color = {"up": DARK, "down": INK, "off": "#3c3544"}[state]
    y = (h - f.size) // 2 - 1 + (1 if state == "down" else 0)
    if cost is None:
        text(d, w // 2, y, label, f, color, "ma", w - 20)
    else:
        total = int(f.getlength(label) + 6 + 14 + f.getlength(cost))
        x = (w - total) // 2
        text(d, x, y, label, f, color)
        x += int(f.getlength(label)) + 6
        ore = sprite("assets/sprites/run/mineral_3.png")
        out.alpha_composite(ore, (x, y + (f.size - ore.height) // 2 + 1))
        text(d, x + 14, y, cost, f, color)
    return out


def window(c, kid):
    """공통 틀: 9칸 금속 틀 + 머리줄(건물 아이콘·이름, 보유 광물, 닫기). 내용은 (틀 그림, 내용 영역)을 받아 꽂는다"""
    x, y, w, h = c.s["win"]
    im = c.p["frame"]
    frame = nine(im, w, h, 26, 26)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.alpha_composite(frame)
    head_h = c.s["head"]
    hx, hy, hw = INSET - 3, INSET - 4, w - 2 * (INSET - 3)
    layer.alpha_composite(plate(c, "head", hw, head_h), (hx, hy))
    d = draw(layer)
    name, icon = BUILD[kid]
    ic = c.p["build_icons"][icon]
    k = c.s["head_icon"]
    ic = ic.resize((ic.width * k, ic.height * k), Image.NEAREST)
    layer.alpha_composite(ic, (hx + 12, hy + (head_h - ic.height) // 2))
    f = c.s["big"]
    ty = hy + (head_h - f.size) // 2 - 1
    text(d, hx + 12 + ic.width + 6, ty, name, f, TEAL2, limit=220)
    cl = c.p["close"]
    cl = cl.resize((cl.width * c.s["close"], cl.height * c.s["close"]), Image.NEAREST)
    cx, cy = hx + hw - cl.width - 8, hy + (head_h - cl.height) // 2
    layer.alpha_composite(cl, (cx, cy))
    m = cl.width // 2
    n = 4 * c.s["close"]
    t = c.s["close"]
    mid = (cx + m, cy + cl.height // 2)
    for i in range(-n, n + 1):
        d.rectangle((mid[0] + i, mid[1] + i, mid[0] + i + t, mid[1] + i + t), fill=INK)
        d.rectangle((mid[0] + i, mid[1] - i, mid[0] + i + t, mid[1] - i + t), fill=INK)
    cr = f"{CREDITS:,}"
    tw = int(f.getlength(cr))
    tx = cx - 12 - tw
    text(d, tx, ty, cr, f, GOLD)
    ore = sprite("assets/sprites/run/mineral_3.png")
    if c.kind == "phone":
        ore = ore.resize((24, 22), Image.NEAREST)
    layer.alpha_composite(ore, (tx - ore.width - 5, hy + (head_h - ore.height) // 2))
    body = (INSET, hy + head_h + 2, w - 2 * INSET, h - INSET - (hy + head_h + 2))
    return layer, body


def compose(c, win_layer, y_off=0, dim=1.0, band=1.0):
    """기지 화면 위에 창. y_off 창이 아래로 밀린 양(화면 논리), dim 어둡기 0~1, band 위쪽 띠 보이는 비율 (창이 열리면 위로 들어간다)"""
    bg = sprite(f"review/v070_base_impl/now_{'pc_1280x720' if c.kind == 'pc' else 'phone_844x390'}.png")
    k = c.s["k"]
    if k > 1:
        bg = bg.resize((c.W, c.H), Image.NEAREST)
    band_h = 28 if c.kind == "pc" else 40
    top = bg.crop((0, 0, c.W, band_h))
    out = bg.copy()
    d = ImageDraw.Draw(out)
    d.rectangle((0, 0, c.W, band_h), fill=(8, 6, 14, 255))
    shift = int((1 - band) * band_h)
    if band > 0:
        out.paste(top.crop((0, shift, c.W, band_h)), (0, 0))
    out.alpha_composite(Image.new("RGBA", out.size, (8, 6, 14, int(190 * dim))))
    if win_layer is not None:
        x, y, _, _ = c.s["win"]
        out.alpha_composite(win_layer, (x, y + int(y_off))) if y + y_off < c.H else None
    return out.resize((c.W * k, c.H * k), Image.NEAREST).convert("RGB")


def clip_paste(canvas, im, x, y):
    x, y = int(x), int(y)
    box = (max(-x, 0), max(-y, 0), im.width, im.height)
    if box[0] < box[2] and box[1] < box[3]:
        canvas.alpha_composite(im.crop(box), (max(x, 0), max(y, 0)))


# ── 연구소 ────────────────────────────────────
def node_state(id_or_lock, branch, levels):
    """chain: 앞 칸을 1단계 이상 찍어야 열림. 예전 저장에서 앞 칸 없이 찍힌 칸은 열린 것으로 친다"""
    if isinstance(id_or_lock, dict):
        return "plan"
    chain = [n for n in TREE[branch] if isinstance(n, str)]
    i = chain.index(id_or_lock)
    lv = levels.get(id_or_lock, 0)
    if i > 0 and levels.get(chain[i - 1], 0) == 0 and lv == 0:
        return "locked"
    if lv >= 5:
        return "max"
    cost = DATA["upgrades"][id_or_lock]["levels"][lv]["cost"]
    if cost <= CREDITS:
        return "can"
    return "poor"


def pips(d, x, y, lv, branch, total=5, size=4, gap=1):
    main, light = BRANCH[branch]
    for i in range(total):
        px = x + i * (size + gap)
        d.rectangle((px, y, px + size - 1, y + size - 1), fill=GREY)
        d.rectangle((px + 1, y + 1, px + size - 2, y + size - 2), fill=light if i < lv else DARK)


def pipe(d, pts, branch, lit, open_):
    """연결관: 찍은 칸까지는 가지 색으로 빛나고, 열린 칸은 켜지기 전 회색, 잠긴 칸은 어둡게"""
    main, light = BRANCH[branch]
    for (a, b) in zip(pts, pts[1:]):
        d.line((a, b), fill=DARK, width=7)
    for (a, b) in zip(pts, pts[1:]):
        d.line((a, b), fill=main if lit else (GREY if open_ else "#3c3544"), width=3)
    if lit:
        for (a, b) in zip(pts, pts[1:]):
            d.line((a, b), fill=light, width=1)


def draw_socket(c, canvas, cx, cy, node, branch, state, levels, selected, pulse):
    """소켓 + 아이콘. 찍은 칸은 가지 색, 살 수 있으면 은은하게 깜빡, 잠기면 어둡게"""
    p = c.p
    lv = levels.get(node, 0) if isinstance(node, str) else 0
    if state == "plan" or state == "locked":
        s = darken(tint(p["socket_lock"], {TEAL: "#5c5164", TEAL2: "#5c5164", "#1da775": "#5c5164", "#125952": "#3c3544"}), 0.55 if state == "plan" else 0.75)
    elif lv > 0:
        s = rim(p["socket_on"], branch)
    elif state == "can":
        s = p["socket_off"].copy()
    else:
        s = p["socket_off"]
    sx, sy = cx - s.width // 2, cy - s.height // 2
    if selected or (state == "can" and pulse > 0):
        strength = 1.0 if selected else pulse
        ring = Image.new("RGBA", (s.width + 8, s.height + 8), (0, 0, 0, 0))
        mask = s.getchannel("A").point(lambda v: 255 if v else 0)
        col = rgb(INK) if selected else rgb(BRANCH[branch][1])
        for i, a in enumerate((90, 44)):
            grown = mask
            for _ in range(i + 1):
                from PIL import ImageFilter
                grown = grown.filter(ImageFilter.MaxFilter(3))
            layer = Image.new("RGBA", ring.size, (0, 0, 0, 0))
            lm = Image.new("L", ring.size, 0)
            lm.paste(grown.point(lambda v: int(a * strength) if v else 0), (4, 4))
            layer.paste((*col, 255), (0, 0), lm)
            ring.alpha_composite(layer)
        clip_paste(canvas, ring, sx - 4, sy - 4)
    clip_paste(canvas, s, sx, sy)
    ic_y = cy + 1
    if isinstance(node, str):
        ic = p["node_icons"][NODE_ICON[node]]
        if state == "locked":
            ic = silhouette(ic)
        elif lv == 0 and state != "can":
            ic = darken(ic, 0.75)
        clip_paste(canvas, ic, cx - ic.width // 2, ic_y - ic.height // 2)


def node_label(c, d, x, y, node, branch, state, levels, anchor="la"):
    """이름 + 단계 칸"""
    f = c.s["small"]
    if isinstance(node, dict):
        text(d, x, y, node["lock"], f, "#917487", anchor)
        if "tag" in node:
            text(d, x, y + 13, node["tag"], f, "#dc7f47", anchor)
        return
    color = {"locked": "#917487", "plan": "#917487", "poor": INK, "can": INK, "max": BRANCH[branch][1]}[state]
    if levels.get(node, 0) > 0 and state != "max":
        color = BRANCH[branch][1]
    text(d, x, y, NODE_NAME[node], f, color, anchor)
    lv = levels.get(node, 0)
    px = x if anchor == "la" else x - 12
    pips(d, px, y + 14, lv, branch)


def detail_panel(c, w, h, sel, levels, press=None):
    """오른쪽 정보: 노드를 누르면 설명, 다음 효과, 가격, 강화 버튼"""
    out = plate(c, "tab", w, h)
    d = draw(out)
    f, big = c.s["small"], c.s["big"]
    x, y = 12, 16
    if sel is None:
        text(d, w // 2, h // 2 - 16, "칸을 눌러", f, TEAL2, "ma")
        text(d, w // 2, h // 2, "효과와 가격을 봐요", f, TEAL2, "ma", w - 20)
        return out
    branch, node = sel
    main, light = BRANCH[branch]
    if isinstance(node, dict):
        out.alpha_composite(c.p["lock"], (x, y - 2))
        text(d, x + 20, y, node["lock"], big, "#dc7f47", limit=w - 34)
        y += big.size + 10
        text(d, x, y, "제안 칸이에요. 수치는 아직", f, INK, limit=w - 24)
        text(d, x, y + 14, "정하지 않았어요.", f, INK)
        if "tag" in node:
            text(d, x, y + 34, "보조 무기가 들어올 자리", f, TEAL2, limit=w - 24)
        return out
    u = DATA["upgrades"][node]
    lv = levels.get(node, 0)
    state = node_state(node, branch, levels)
    ic = c.p["node_icons"][NODE_ICON[node]]
    out.alpha_composite(ic, (x, y - 2))
    tx = x + ic.width + 6
    text(d, tx, y, NODE_NAME[node], f, light, limit=w - tx - 8)
    text(d, tx, y + 14, BRANCH_NAME[branch], f, MUTED)
    y += ic.height + 4
    pips(d, x, y, lv, branch, size=6, gap=2)
    text(d, x + 44, y - 3, f"{lv}/5단계", f, INK)
    y += 12
    text(d, x, y, NODE_DESC[node], f, INK, limit=w - 22)
    y += 16
    text(d, x, y, "다음 효과" if lv < 5 else "지금 효과", f, TEAL2)
    y += 14
    change = u["levels"][lv]["change"]
    if c.kind == "phone":  # 폰은 가장 중요한 값을 크게, 두 줄로 나눔
        cut_at = next((i for i, ch in enumerate(change) if ch.isdigit()), 0)
        text(d, x, y, change[:cut_at].strip(), big, GOLD if lv < 5 else INK, limit=w - 22)
        y += big.size + 1
        text(d, x, y, change[cut_at:], big, GOLD if lv < 5 else INK, limit=w - 22)
        y += big.size + 2
    else:
        text(d, x, y, change, f, GOLD if lv < 5 else INK, limit=w - 22)
        y += 14
    if u["note"]:
        text(d, x, y, u["note"], f, MUTED, limit=w - 22)
    bh = 44 if c.kind == "phone" else 26
    by = h - bh - 12
    if state == "locked":
        chain = [n for n in TREE[branch] if isinstance(n, str)]
        before = chain[chain.index(node) - 1]
        text(d, x, by - 15, f"먼저 찍을 칸: {NODE_NAME[before]}", f, "#dc7f47", limit=w - 22)
        out.alpha_composite(button(c, w - 24, bh, "잠김", "off"), (x, by))
    elif state == "max":
        out.alpha_composite(button(c, w - 24, bh, "최대 단계", "off"), (x, by))
    else:
        cost = f"{u['levels'][lv]['cost']:,}"
        if state == "poor":
            text(d, x, by - 15, "광물이 모자라요", f, "#f25c76")
        out.alpha_composite(button(c, w - 24, bh, "강화", "off" if state == "poor" else ("down" if press else "up"), cost), (x, by))
    return out


def tree_positions_a(cw, ch):
    """A: 코어에서 위로 뻗는 나무. 가지 3개가 세로 열, 코어는 가운데(선체) 열 아래"""
    pitch = 52
    colx = {"weapon": 26, "hull": 26 + (cw - 112) // 2, "mine": cw - 112 + 0}
    core = (colx["hull"], ch - 37)
    pos = {}
    for b, nodes in TREE.items():
        first = core[1] - (56 if b == "hull" else 34)
        for i, n in enumerate(nodes):
            pos[(b, i)] = (colx[b], first - i * pitch)
    return core, pos


def tree_positions_b(cw, ch):
    """B: 방사형. 위로 선체, 왼쪽 아래 무기, 오른쪽 아래 채굴. 넘치는 칸은 끌어서 본다"""
    core = (cw // 2, ch // 2 + 28)
    dirs = {"hull": (0.0, -1.0), "weapon": (-0.87, 0.5), "mine": (0.87, 0.5)}
    pos = {}
    for b, nodes in TREE.items():
        dx, dy = dirs[b]
        for i, n in enumerate(nodes):
            r = 86 + i * 84
            pos[(b, i)] = (core[0] + int(dx * r), core[1] + int(dy * r))
    return core, pos


def research_body(c, body, layout, levels, sel, pulse=0.0, pan=(0, 0), flash=None, press=None, hint=True):
    x0, y0, bw, bh = body
    dw = c.s["detail"]
    cw, ch = bw - dw - 4, bh
    canvas = Image.new("RGBA", (cw, ch), (*rgb("#14111c"), 255))
    d = draw(canvas)
    # 격자: 움직일 수 있는 판임을 보여 준다
    gx, gy = pan[0] % 24, pan[1] % 24
    for yy in range(gy, ch, 24):
        for xx in range(gx, cw, 24):
            d.point((xx, yy), fill="#3c3544")
    core, pos = (tree_positions_a if layout == "A" else tree_positions_b)(cw, ch)
    core = (core[0] + pan[0], core[1] + pan[1])
    pos = {k: (v[0] + pan[0], v[1] + pan[1]) for k, v in pos.items()}
    # 연결관 먼저
    for b, nodes in TREE.items():
        prev = core
        prev_lit = True
        for i, n in enumerate(nodes):
            p = pos[(b, i)]
            st = node_state(n, b, levels)
            lit = isinstance(n, str) and levels.get(n, 0) > 0 and prev_lit
            is_open = st not in ("locked", "plan")
            if layout == "A":
                if prev == core and p[0] != core[0]:
                    pts = [core, (p[0], core[1]), p]
                else:
                    pts = [prev, p]
            else:
                pts = [prev, p]
            pipe(d, pts, b, lit, is_open)
            prev, prev_lit = p, lit
    # 코어
    clip_paste(canvas, c.p["core"], core[0] - c.p["core"].width // 2, core[1] - c.p["core"].height // 2)
    for b, nodes in TREE.items():
        for i, n in enumerate(nodes):
            p = pos[(b, i)]
            st = node_state(n, b, levels)
            selected = sel is not None and sel[0] == b and sel[1] == n
            draw_socket(c, canvas, p[0], p[1], n, b, st, levels, selected, pulse)
            if layout == "A":
                node_label(c, d, p[0] + 26, p[1] - 13, n, b, st, levels)
            elif b == "hull":
                node_label(c, d, p[0] + 26, p[1] - 13, n, b, st, levels)
            else:
                node_label(c, d, p[0], p[1] - 52, n, b, st, levels, "ma")
            if flash is not None and flash[0] == n:
                fl = Image.new("RGBA", (44, 48), (*rgb(BRANCH[b][1]), int(170 * flash[1])))
                clip_paste(canvas, fl, p[0] - 22, p[1] - 24)
    # 가지 머리표: 판과 함께 움직이지 않는다
    for b, nodes in TREE.items():
        if layout == "A":
            hx = pos[(b, 0)][0] - pan[0] - 22
            d.rectangle((hx, 0, hx + 108, 16), fill=DARK)
            canvas.alpha_composite(c.p["emblem"][b], (hx + 1, 1))
            text(d, hx + 18, 2, BRANCH_NAME[b], F12, BRANCH[b][1])
    if layout == "B":
        chips = {"weapon": (2, 2), "hull": (2, 20), "mine": (2, 38)}  # 왼쪽 위는 팔이 지나가지 않는다
        for b, (hx, hy) in chips.items():
            d.rectangle((hx, hy, hx + 106, hy + 16), fill=DARK)
            canvas.alpha_composite(c.p["emblem"][b], (hx + 1, hy + 1))
            text(d, hx + 18, hy + 2, BRANCH_NAME[b], F12, BRANCH[b][1])
    if hint:
        hint_s = "끌어서 이동"
        hx, hy = (6, ch - 18) if layout == "A" else (cw // 2 - 30, ch - 18)
        d.rectangle((hx - 2, hy - 1, hx + F12.getlength(hint_s) + 2, hy + 14), fill=DARK)
        text(d, hx, hy, hint_s, F12, TEAL2)
    panel = detail_panel(c, dw, bh, sel, levels, press)
    return canvas, panel


def research(c, layout, levels=SAMPLE, sel=None, **kw):
    layer, body = window(c, "research")
    canvas, panel = research_body(c, body, layout, levels, sel, **kw)
    layer.alpha_composite(canvas, (body[0], body[1]))
    layer.alpha_composite(panel, (body[0] + body[2] - panel.width, body[1]))
    return layer


# ── 격납고 ────────────────────────────────────
STAT_BRANCH = {"체력": "hull", "사망 보존": "hull", "공격력": "weapon", "공격 속도": "weapon", "이동 속도": "mine", "화물칸": "mine", "자석 범위": "mine"}


def stat_block(c, d, x, y, w, st):
    f = c.s["small"]
    b = STAT_BRANCH[st["name"]]
    main, light = BRANCH[b]
    text(d, x, y, st["name"], f, light)
    text(d, x + w, y, st["value"], f, INK, "ra")
    by = y + 15
    d.rectangle((x, by, x + w, by + 5), fill=DARK)
    d.rectangle((x + 1, by + 1, x + w - 1, by + 4), fill="#3c3544")
    d.rectangle((x + 1, by + 1, x + 1 + int((w - 2) * st["ratio"] / 2) * 2, by + 4), fill=light)


def bay_slot(c, w, h, fighter, selected):
    """전투기 칸: 정비 베이 모양 (아래 위험 띠). 잠긴 칸은 실루엣과 해금 조건 자리"""
    out = plate(c, "tab", w, h)
    if selected:
        out = tint(out, {INK: GOLD, MUTED: "#dc7f47"})
    d = draw(out)
    f = c.s["small"]
    d.rectangle((8, h - 16, w - 9, h - 11), fill=DARK)
    for x in range(8, w - 12, 8):
        d.polygon([(x, h - 11), (x + 3, h - 11), (x + 6, h - 16), (x + 3, h - 16)], fill=GOLD if selected else "#70525e")
    ship = sprite("assets/sprites/station/ship.png")
    sx, sy = (w - ship.width) // 2, 3
    if fighter is None:
        out.alpha_composite(silhouette(ship), (sx, sy))
        text(d, w // 2, 47, "해금 조건", f, "#917487", "ma", w - 8)
        text(d, w // 2, 60, "???", f, "#dc7f47", "ma")
    else:
        out.alpha_composite(ship, (sx, sy))
        text(d, w // 2, 47, fighter["name"], f, GOLD if selected else INK, "ma", w - 8)
        text(d, w // 2, 60, fighter["style"], f, TEAL2, "ma", w - 8)
    return out


def hangar(c):
    layer, body = window(c, "hangar")
    x0, y0, bw, bh = body
    d = draw(layer)
    bay = c.p["bay_pc"] if c.kind == "pc" else c.p["bay"]
    bx, by = x0 + (bw - bay.width) // 2, y0 + 1
    layer.alpha_composite(bay, (bx, by))
    ship = sprite("assets/sprites/station/ship.png")
    ship = ship.resize((96, 96), Image.NEAREST)
    layer.alpha_composite(ship, (bx + (bay.width - 96) // 2, by + (bay.height - 96) // 2))
    # 능력치: 둘레 좌우. 선(이음줄)으로 정비대에 잇는다
    stats = DATA["stats"]
    left, right = stats[:3] + stats[6:], stats[3:6]
    col_w = (bw - bay.width) // 2 - 14
    gap = (bay.height - 8) // 4
    for i, st in enumerate(left):
        y = by + 4 + i * gap
        stat_block(c, d, x0 + 2, y, col_w - 4, st)
    gap_r = (bay.height - 8) // 3
    for i, st in enumerate(right):
        y = by + 4 + i * gap_r
        stat_block(c, d, bx + bay.width + 12, y, col_w - 4, st)
    # 아래: 전투기 정비 베이 + 기본 무기 자리
    sy = by + bay.height + 4
    sh = y0 + bh - sy
    n = 4
    wslot = 112 if c.kind == "pc" else 170
    sw = (bw - wslot - 4 * 4) // n
    fighters = DATA["fighters"]
    for i in range(n):
        s = bay_slot(c, sw, sh, fighters[i] if i < len(fighters) else None, i == 0)
        layer.alpha_composite(s, (x0 + i * (sw + 4), sy))
    w = plate(c, "tab", wslot, sh)
    dw = draw(w)
    w.alpha_composite(c.p["lock"], ((wslot - 14) // 2, 10))
    text(dw, wslot // 2, 32, "기본 무기", c.s["small"], "#dc7f47", "ma", wslot - 8)
    text(dw, wslot // 2, 47, "전방 연사", c.s["small"], INK, "ma", wslot - 8)
    text(dw, wslot // 2, 62, "v0.8.0 제안", c.s["small"], "#917487", "ma", wslot - 8)
    layer.alpha_composite(w, (x0 + bw - wslot, sy))
    return layer


# ── 광물 창고 ─────────────────────────────────
def fill_ratio(n):
    """많을수록 더 차 보이게: 로그 눈금 (1,000개면 가득). 숫자 표시는 지금과 같고 그림만 바뀐다"""
    return min(np.log10(n + 1) / 3.0, 1.0)


def tank(c, grade, count):
    t = c.p["tank"].copy()
    w, h = t.size
    ix0, ix1, iy0, iy1 = int(w * 0.17), int(w * 0.84), int(h * 0.26), int(h * 0.86)
    ore = sprite(f"assets/sprites/run/mineral_{grade}.png")
    ore = ore.resize((ore.width * 2, ore.height * 2), Image.NEAREST)
    fill = fill_ratio(count)
    top = int(iy1 - (iy1 - iy0) * fill)
    rng = random.Random(100 + grade)
    inner = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = iy1 - ore.height
    row = 0
    while y >= top - ore.height // 2 and count > 0:
        x = ix0 - 3 + (row % 2) * ore.width // 2
        while x < ix1 - 2:
            inner.alpha_composite(ore, (x + rng.randint(-1, 1), y + rng.randint(-1, 1)))
            x += ore.width - 2
        y -= ore.height // 2 + 3
        row += 1
    a = np.array(inner)
    a[:iy0, :] = 0
    a[iy1:, :] = 0
    a[:, :ix0] = 0
    a[:, ix1:] = 0
    t.alpha_composite(Image.fromarray(a, "RGBA"))
    # 유리 반사선을 광물 위에 다시
    d = draw(t)
    d.line((ix0 + 2, iy0 + 4, ix0 + 2, iy1 - 6), fill=TEAL2)
    return t


def storage(c):
    layer, body = window(c, "storage")
    x0, y0, bw, bh = body
    d = draw(layer)
    grades = DATA["minerals"]
    lw = 176 if c.kind == "pc" else 250
    v = c.p["vault"]
    vx = x0 + (lw - v.width) // 2
    vy = y0 + (bh - v.height - 90) // 2
    layer.alpha_composite(v, (vx, vy))
    ty = vy + v.height + 18
    text(d, x0 + lw // 2, ty, "보유 광물 총가치", c.s["small"], TEAL2, "ma")
    ore = sprite("assets/sprites/run/mineral_3.png").resize((24, 22), Image.NEAREST)
    val = f"{CREDITS:,}"
    tw = int(F24.getlength(val))
    sx = x0 + (lw - tw - ore.width - 6) // 2
    layer.alpha_composite(ore, (sx, ty + 18))
    text(d, sx + ore.width + 6, ty + 16, val, F24, GOLD)
    text(d, x0 + lw // 2, ty + 48, "지금까지 기지로 가져온 광물", c.s["small"], MUTED, "ma", lw + 16)
    tw = c.p["tank"].width
    room = bw - lw - 10
    pitch = room // 4
    tb = y0 + max((bh - c.p["tank"].height - 34) // 2, 2)
    for i in range(4):
        t = tank(c, i, HAULED[i])
        tx = x0 + lw + 10 + i * pitch + (pitch - tw) // 2
        layer.alpha_composite(t, (tx, tb))
        ly = tb + t.height + 4
        cx = tx + tw // 2
        text(d, cx, ly, f"{grades[i]} 광물", c.s["small"], GRADE_COLOR[i], "ma")
        text(d, cx, ly + 15, f"{HAULED[i]:,}개", c.s["big"] if c.kind == "phone" else F12, INK, "ma")
    return layer


# ── 전시관 ────────────────────────────────────
def museum(c, sel="rock_2"):
    layer, body = window(c, "museum")
    x0, y0, bw, bh = body
    d = draw(layer)
    f = c.s["small"]
    # 탭: 지금은 도감 하나. 진화 도감 자리는 잠금 + 제안
    tab_w, tab_h = 92, 20
    t = plate(c, "tab", tab_w, tab_h)
    dt = draw(t)
    text(dt, tab_w // 2, 4, "도감", F12, TEAL2, "ma")
    layer.alpha_composite(t, (x0, y0))
    t2 = darken(plate(c, "tab", tab_w + 40, tab_h), 0.7)
    dt = draw(t2)
    t2.alpha_composite(c.p["lock"], (6, 3))
    text(dt, 24, 4, "진화 도감 제안", F12, "#917487")
    layer.alpha_composite(t2, (x0 + tab_w + 3, y0))
    # 발견 수 + 진행 막대
    total = len(DATA["discovery"])
    found = len(FOUND)
    px = x0 + tab_w + tab_w + 54
    text(d, px, y0 + 4, f"발견 {found} / {total}", F12, INK)
    bx = px + 76
    bx1 = x0 + bw - 2
    d.rectangle((bx, y0 + 5, bx1, y0 + 14), fill=DARK)
    d.rectangle((bx + 1, y0 + 6, bx1 - 1, y0 + 13), fill="#3c3544")
    d.rectangle((bx + 1, y0 + 6, bx + 1 + (bx1 - bx - 2) * found // total, y0 + 13), fill=TEAL)
    # 진열장 6x2
    cols = 6
    top = y0 + tab_h + 3
    detail_h = 34
    cell_w, cell_h = bw // cols, (bh - tab_h - 3 - detail_h - 2) // 2
    case_on, case_off = tint(c.p["case_on"], {"#6f2626": "#3c3544", "#7a3045": "#3c3544", "#984633": "#5c5164"}), c.p["case_off"]
    for i, e in enumerate(DATA["discovery"]):
        cx = x0 + (i % cols) * cell_w + cell_w // 2
        cy = top + (i // cols) * cell_h
        known = e["id"] in FOUND
        case = case_on if known else case_off
        kx, ky = cx - case.width // 2, cy
        if e["id"] == sel:
            d.rectangle((kx - 2, ky + 4, kx + case.width + 1, ky + case.height + 1), outline=GOLD)
        layer.alpha_composite(case, (kx, ky))
        ic = discovery_icon(e["id"])
        # 받침 위에 올린다 (진열장 안쪽 바닥 = 높이의 약 78%)
        ix, iy = cx - ic.width // 2, ky + int(case.height * 0.79) - ic.height
        if known:
            layer.alpha_composite(ic, (ix, iy))
            text(d, cx, ky + case.height + 1, e["name"], f, INK, "ma", cell_w - 2)
        else:
            layer.alpha_composite(silhouette(ic), (ix, iy))
            text(d, cx, iy + ic.height // 2 - 7, "?", F12, "#917487", "ma")
            text(d, cx, ky + case.height + 1, "?", f, "#917487", "ma")
    # 눌렀을 때 설명
    ep = plate(c, "head", bw, detail_h - 2)
    de = draw(ep)
    entry = next(e for e in DATA["discovery"] if e["id"] == sel)
    text(de, 14, (detail_h - 2 - 12) // 2 - 1, entry["name"], F12, GOLD)
    text(de, 14 + int(F12.getlength(entry["name"])) + 10, (detail_h - 2 - 12) // 2 - 1, SHORT[sel], F12, INK, limit=bw - 110)
    layer.alpha_composite(ep, (x0, y0 + bh - detail_h + 2))
    return layer


# ── 드론 공장 ─────────────────────────────────
def drone(c):
    layer, body = window(c, "drone")
    x0, y0, bw, bh = body
    d = draw(layer)
    blue = "#4d80cd"
    d.rectangle((x0, y0, x0 + bw - 1, y0 + bh - 1), fill="#3a1c57")
    inset = 3
    d.rectangle((x0 + inset, y0 + inset, x0 + bw - inset - 1, y0 + bh - inset - 1), fill=blue)
    for x in range(x0 + inset + 8, x0 + bw - inset, 16):
        for y in range(y0 + inset + 8, y0 + bh - inset, 16):
            d.point((x, y), fill=INK)
    for x in range(x0 + inset, x0 + bw - inset, 64):
        d.line((x, y0 + inset, x, y0 + bh - inset - 1), fill=TEAL2, width=1)
    for y in range(y0 + inset, y0 + bh - inset, 64):
        d.line((x0 + inset, y, x0 + bw - inset - 1, y), fill=TEAL2, width=1)
    art = outline_only(sprite("assets/sprites/station/b_drone.png"), INK)
    art = art.resize((art.width * 2, art.height * 2), Image.NEAREST)
    ax, ay = x0 + (bw - art.width) // 2 - (100 if c.kind == "pc" else 130), y0 + (bh - art.height) // 2
    layer.alpha_composite(art, (ax, ay))
    # 치수선
    d.line((ax, ay - 8, ax + art.width, ay - 8), fill=INK)
    d.line((ax, ay - 12, ax, ay - 4), fill=INK)
    d.line((ax + art.width, ay - 12, ax + art.width, ay - 4), fill=INK)
    d.line((ax + art.width + 8, ay, ax + art.width + 8, ay + art.height), fill=INK)
    d.line((ax + art.width + 4, ay, ax + art.width + 12, ay), fill=INK)
    d.line((ax + art.width + 4, ay + art.height, ax + art.width + 12, ay + art.height), fill=INK)
    # 표지판: 건설 예정
    sw, sh = (150, 44) if c.kind == "pc" else (190, 54)
    sx, sy = ax + art.width + 20, y0 + (bh - sh) // 2
    sg = nine(c.p["btn_off"], sw, sh, 12, c.p["btn_off"].height // 2 - 1)
    a = np.array(sg)
    m = (a[..., :3] == rgb(MUTED)).all(axis=2)
    a[m, :3] = rgb(GOLD)
    sg = Image.fromarray(a, "RGBA")
    ds = draw(sg)
    text(ds, sw // 2, (sh - 24) // 2 - 1, "건설 예정", F24, DARK, "ma")
    layer.alpha_composite(sg, (sx, sy))
    note_w = 188
    nb = plate(c, "tab", note_w, 44)
    dn = draw(nb)
    text(dn, note_w // 2, 8, "드론 공장 설계도", c.s["small"], TEAL2, "ma", note_w - 10)
    text(dn, note_w // 2, 23, "완공되면 채굴 드론 제작", c.s["small"], INK, "ma", note_w - 10)
    layer.alpha_composite(nb, (sx + (sw - note_w) // 2, sy + sh + 6))
    return layer


# ── 전환 GIF ──────────────────────────────────
OPEN_TIME, CLOSE_TIME, DT = 0.18, 0.14, 0.03  # 초. 소리 "턱"이 약 0.2초에 있어 창이 멈출 때 맞음


def ease_out(t):
    return 1 - (1 - t) ** 3


def ease_in(t):
    return t ** 3


def transition(c, win_layer, name):
    """열 때 아래에서 밀려 들어오고 위쪽 띠는 위로 들어간다. 닫을 때 반대로"""
    frames, durs = [], []
    idle = compose(c, None, dim=0, band=1)
    frames.append(idle)
    durs.append(700)
    n = int(OPEN_TIME / DT)
    h = c.H
    for i in range(1, n + 1):
        t = ease_out(i / n)
        frames.append(compose(c, win_layer, y_off=(1 - t) * h, dim=t, band=1 - t))
        durs.append(int(DT * 1000))
    frames.append(compose(c, win_layer, 0, 1, 0))
    durs.append(1300)
    n = int(CLOSE_TIME / DT)
    for i in range(1, n + 1):
        t = ease_in(i / n)
        frames.append(compose(c, win_layer, y_off=t * h, dim=1 - t, band=t))
        durs.append(int(DT * 1000))
    save_gif(frames, durs, name)


def save_gif(frames, durs, name):
    pal = [f.quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    pal[0].save(OUT + name, save_all=True, append_images=pal[1:], duration=durs, loop=0, optimize=True, disposal=1)


def research_gif(c):
    """깜빡임 → 노드 누름 → 강화 → 관·단계 칸 빛남 → 끌어서 이동"""
    frames, durs = [], []
    levels = dict(SAMPLE)
    def snap(sel=None, pulse=0.0, **kw):
        return compose(c, research(c, "A", levels, sel, pulse=pulse, **kw), 0, 1, 0)
    for i in range(10):
        frames.append(snap(None, 0.5 + 0.5 * np.sin(i / 10 * 2 * np.pi)))
        durs.append(100)
    sel = ("mine", "cargo")
    frames.append(snap(sel, 0.5))
    durs.append(800)
    frames.append(snap(sel, 0.5, press=True))
    durs.append(120)
    levels["cargo"] = 1
    global CREDITS
    old = CREDITS
    CREDITS -= 120
    for f in (1.0, 0.6, 0.25):
        frames.append(snap(sel, 0.5, flash=("cargo", f)))
        durs.append(60)
    frames.append(snap(sel, 0.5))
    durs.append(800)
    for py in list(range(0, 64, 8)) + [64] * 4 + list(range(64, -1, -8)):
        frames.append(snap(sel, 0.5, pan=(0, py)))
        durs.append(40)
    CREDITS = old
    save_gif(frames, durs, f"research_press_buy_drag_{c.kind}.gif")


def transition_return():
    """기지 귀환 전환 제안: 충격 셔터가 위아래에서 닫혔다가 기지 쪽에서 열린다 (창과 같은 금속·위험 띠)"""
    a = Image.open("review/v070_final/shot_return_pc_1280x720.png").convert("RGB").resize((640, 360), Image.NEAREST)
    b = Image.open("review/v070_base_impl/now_pc_1280x720.png").convert("RGB").resize((640, 360), Image.NEAREST)
    panel = Image.new("RGBA", (640, 190), (*rgb("#3c3544"), 255))
    d = draw(panel)
    # 끝단: 크림 띠 + 금색 위험 띠
    for y in range(0, 176, 44):
        d.line((0, y, 640, y), fill=DARK)
        for x in range(8 + (y // 44 % 2) * 40, 640, 80):
            d.line((x + 32, y, x + 32, y + 43), fill=DARK)
            d.rectangle((x, y + 4, x + 1, y + 5), fill="#917487")
            d.rectangle((x + 60, y + 4, x + 61, y + 5), fill="#917487")
    d.rectangle((0, 176, 640, 189), fill=DARK)
    for x in range(-14, 640, 14):
        d.polygon([(x, 188), (x + 7, 188), (x + 14, 178), (x + 7, 178)], fill=GOLD)
    d.rectangle((0, 174, 640, 176), fill=INK)
    def frame(top, base):
        im = base.convert("RGBA")
        lo = panel.transpose(Image.FLIP_TOP_BOTTOM)
        clip_paste(im, panel, 0, top - 190)
        clip_paste(im, lo, 0, 360 - top)
        return im.resize((1280, 720), Image.NEAREST).convert("RGB")
    frames, durs = [a.resize((1280, 720), Image.NEAREST)], [500]
    n = 6
    for i in range(1, n + 1):
        frames.append(frame(int(180 * ease_in(i / n)), a))
        durs.append(30)
    shake = [3, -2, 1, 0]
    for s in shake:
        frames.append(frame(180 + s, b))
        durs.append(30)
    frames.append(frame(180, b))
    durs.append(120)
    for i in range(1, n + 3):
        frames.append(frame(int(180 * (1 - ease_out(i / (n + 2)))), b))
        durs.append(30)
    frames.append(b.resize((1280, 720), Image.NEAREST))
    durs.append(700)
    save_gif(frames, durs, "transition_return_proposal_pc.gif")


def state_sheet(parts):
    """노드·버튼 상태 모음 (A·B 공통)"""
    c = Ctx(parts, "pc")
    W, H = 400, 180
    s = Image.new("RGBA", (W, H), (*rgb(DARK), 255))
    d = draw(s)
    items = [
        ("찍음", "damage", "weapon", {"damage": 3}, "poor"),
        ("살 수 있음", "cargo", "mine", {"cargo": 0}, "can"),
        ("광물 부족", "damage", "weapon", {"damage": 0}, "poor"),
        ("잠김", "magnet", "mine", {"cargo": 0}, "locked"),
        ("제안", {"lock": "제안"}, "hull", {}, "plan"),
    ]
    for i, (label, node, b, lv, st) in enumerate(items):
        x = 40 + i * 78
        draw_socket(c, s, x, 40, node, b, st, lv, False, 1.0 if st == "can" else 0.0)
        text(d, x, 68, label, F12, INK, "ma")
    x = 10
    for state, label in (("up", "강화"), ("down", "눌림"), ("off", "꺼짐")):
        s.alpha_composite(button(c, 110, 26, label, state), (x, 100))
        x += 124
    s.alpha_composite(c.p["close"], (10, 140))
    s.alpha_composite(plate(c, "tab", 120, 30), (60, 138))
    s.alpha_composite(plate(c, "head", 180, 28), (200, 139))
    s.resize((W * 2, H * 2), Image.NEAREST).convert("RGB").save(OUT + "states_sheet.png")


def sanity():
    """창이 화면 안에 들어오고, 앞으로 생길 긴 건물 이름도 머리줄에 맞는지"""
    for k, s in SCREEN.items():
        x, y, w, h = s["win"]
        assert x >= 0 and y >= 0 and x + w <= s["size"][0] and y + h <= s["size"][1], k
        assert s["big"].getlength("진화 도감 실험실") < 220 and s["big"].getlength("보조 무기 연구소") < 220, k
    assert fill_ratio(0) == 0 and fill_ratio(3) < fill_ratio(23) < fill_ratio(96) < fill_ratio(412) < 1.0 and fill_ratio(10 ** 6) == 1.0
    # 예전 저장: 앞 칸 없이 찍힌 칸은 잠기지 않는다 (강화를 잃지 않게)
    assert node_state("magnet", "mine", {"magnet": 2}) != "locked"
    assert node_state("magnet", "mine", {"magnet": 0, "cargo": 0}) == "locked"
    assert node_state("cargo", "mine", {"speed": 1, "cargo": 0}) != "locked"


def main():
    sanity()
    parts = load_parts()
    for kind in ("pc", "phone"):
        c = Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        screens = {
            "research_A": research(c, "A", pulse=0.8),
            "research_A_pressed": research(c, "A", sel=("hull", "insurance"), pulse=0.8),
            "research_A_pressed_poor": research(c, "A", sel=("weapon", "damage"), pulse=0.8),
            "research_A_pressed_locked": research(c, "A", sel=("mine", "magnet"), pulse=0.8),
            "research_A_pressed_plan": research(c, "A", sel=("weapon", TREE["weapon"][1]), pulse=0.8),
            "research_B": research(c, "B", pulse=0.8),
            "research_B_pressed": research(c, "B", sel=("hull", "insurance"), pulse=0.8),
            "hangar": hangar(c),
            "storage": storage(c),
            "museum": museum(c),
            "drone": drone(c),
        }
        for name, layer in screens.items():
            compose(c, layer, 0, 1, 0).save(f"{OUT}{name}_{tag}.png")
        for kid in ("research_A", "hangar", "storage", "museum", "drone"):
            if kind == "pc" or kid == "research_A":
                transition(c, screens[kid], f"open_close_{kid}_{kind}.gif")
        research_gif(c)
    state_sheet(parts)
    transition_return()
    for w in sorted(set(WARN)):
        print(w)
    print("시안 저장. 글자 넘침", len(set(WARN)))


if __name__ == "__main__":
    main()
