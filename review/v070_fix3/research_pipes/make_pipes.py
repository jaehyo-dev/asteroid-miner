"""v0.7.0 연구소 배관 시안 (게임에 적용하지 않음). make_tabs.py의 칸·탭·규칙을 그대로 쓰고 바뀌는 곳만 새로 그린다.
1) 단색 선 → 금속 관(부품 아틀라스) 2) 찍은 길에 빛 흐름 3) 강화 순간 빛 달리기 + 칸 번쩍
4) 폰은 판·탭·창을 2배로(논리 칸은 PC와 같음) 5) 1단계 칸은 단계 점 없음 6) 끌기 안내는 글자 대신 오른쪽 가장자리 막대 7) 창이 다른 칸을 피해 자리를 고름
실행: 저장소 맨 위에서 python3 review/v070_fix3/research_pipes/make_pipes.py"""
import sys

from PIL import Image

sys.path[:0] = ["review/v070_fix3/research_tabs"]
import make_tabs as mt  # noqa: E402
from make_tabs import BRANCH, DARK, DIM, F12, GOLD, INK, MUTED, SHORT_NAME, TAB_ORDER, TEAL2, TREE, draw, m2, mm, plate, text  # noqa: E402

OUT = "review/v070_fix3/research_pipes/"
ZOOM = {"pc": 1, "phone": 2}  # 판·탭·창 그림 배율. PC는 화면 전체가 2배라 실제 크기가 같아진다
TAB_W = {"pc": 58, "phone": 49}  # 폰은 탭 높이 31칸이라 아이콘과 이름을 옆으로 놓는다
POP_W = {"pc": 156, "phone": 142}
BAR_W = 6  # 끌기 막대 자리
JOIN_UP = 42  # 합쳐지는 가로관 중심(make_tabs와 같음)

# 관 금속 색 (테두리, 밝은 면, 그림자, 빈 관 속 / 판 면, 판 밝은 면, 판 어두운 면, 리벳). 모두 void32
TIER = {
    "lit": ("#000000", "#a5b29d", "#5c5164", "#2b1925", "#5c5164", "#917487", "#3c3544", "#a5b29d"),
    "open": ("#000000", "#5c5164", "#3c3544", "#2b1925", "#3c3544", "#5c5164", "#2b1925", "#917487"),
    "locked": ("#000000", "#3c3544", "#2b1925", "#000000", "#2b1925", "#3c3544", "#000000", "#5c5164"),
}
RANK = {"locked": 0, "open": 1, "lit": 2}
DEEP = {"weapon": "#6f2626", "hull": "#3a1c57", "mine": "#984633", "elec": "#3a1c57", "survey": "#355148"}  # 관 속 그늘

FLOW_SPACING = 50  # 빛 덩어리 간격
FLOW_FRAMES = 50  # 한 칸씩 움직여 2초에 한 바퀴 (초당 25장, 25칸/초)
COMET_SPEED = 18  # 강화 빛은 한 장에 18칸 (450칸/초)
COMET_TAIL = 28
DIRS = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}


# ── 부품 아틀라스 ─────────────────────────────────
def plate_part(tier, conns):
    """모서리 이음쇠(2방향)·T자(3방향). 12×12 판에 리벳, 관 속이 지나는 곳은 구멍(뒤의 관 속이 보인다)"""
    o, _, _, _, face, hi, lo, rivet = TIER[tier]
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = draw(im)
    d.rectangle((0, 0, 11, 11), fill=o)
    d.rectangle((1, 1, 10, 10), fill=face)
    d.line((1, 1, 10, 1), fill=hi)
    d.line((1, 1, 1, 10), fill=hi)
    d.line((2, 10, 10, 10), fill=lo)
    d.line((10, 2, 10, 10), fill=lo)
    for (x, y), arms in (((2, 2), "NW"), ((9, 2), "NE"), ((2, 9), "SW"), ((9, 9), "SE")):
        if not set(arms) & conns or len(set(arms) & conns) == 1:  # 관이 지나지 않는 쪽 모서리에만
            d.point((x, y), fill=rivet)
    for a, box in (("N", (4, 0, 7, 7)), ("S", (4, 4, 7, 11)), ("W", (0, 4, 7, 7)), ("E", (4, 4, 11, 7))):
        if a in conns:
            hole = Image.new("RGBA", (box[2] - box[0] + 1, box[3] - box[1] + 1), (0, 0, 0, 0))
            im.paste(hole, box[:2])
    # 구멍 끝을 관 벽과 잇는다: 판 테두리와 만나는 곳 양옆을 관 색으로 둔다
    return im


def collar_part(tier, axis):
    """이음새: 관보다 1칸씩 넓은 띠 + 양끝 리벳. 세로관용 10×4 (가로관용은 4×10)"""
    o, _, _, _, face, hi, lo, rivet = TIER[tier]
    im = Image.new("RGBA", (10, 4), o)
    d = draw(im)
    d.line((1, 1, 8, 1), fill=hi)
    d.line((1, 2, 8, 2), fill=lo)
    d.point((1, 1), fill=rivet)
    d.point((8, 1), fill=rivet)
    if axis == "h":  # 빛 방향이 위·왼쪽이라 돌리지 않고 다시 그린다
        im = Image.new("RGBA", (4, 10), o)
        d = draw(im)
        d.line((1, 1, 1, 8), fill=hi)
        d.line((2, 1, 2, 8), fill=lo)
        d.point((1, 1), fill=rivet)
        d.point((1, 8), fill=rivet)
    _ = face
    return im


def flange_part(tier, side):
    """칸 테두리와 만나는 끝 소켓. 칸 위·아래용 14×4, 옆용 4×14. 가운데는 관 속 구멍"""
    o, _, _, _, face, hi, lo, rivet = TIER[tier]
    wide = side in "NS"
    im = Image.new("RGBA", (14, 4) if wide else (4, 14), o)
    d = draw(im)
    if wide:
        d.rectangle((1, 1, 12, 2), fill=face)
        d.line((1, 1, 12, 1), fill=hi)
        d.line((1, 2, 12, 2), fill=lo)
        d.point((2, 1), fill=rivet)
        d.point((11, 1), fill=rivet)
        im.paste(Image.new("RGBA", (4, 4), (0, 0, 0, 0)), (5, 0))
    else:
        d.rectangle((1, 1, 2, 12), fill=face)
        d.line((1, 1, 1, 12), fill=hi)
        d.line((2, 1, 2, 12), fill=lo)
        d.point((1, 2), fill=rivet)
        d.point((1, 11), fill=rivet)
        im.paste(Image.new("RGBA", (4, 4), (0, 0, 0, 0)), (0, 5))
    return im


def rail_part(tier, axis):
    """곧은 관 8칸 타일: 테두리, 밝은 면, (관 속은 비움), 그림자, 테두리"""
    o, hi, sh = TIER[tier][:3]
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = draw(im)
    for i, col in ((0, o), (1, hi), (6, sh), (7, o)):
        d.line((i, 0, i, 7) if axis == "v" else (0, i, 7, i), fill=col)
    return im


CORNERS = ("SE", "SW")  # 지금 나무에 쓰는 모서리(아래에서 올라와 안쪽으로). 아틀라스에는 네 방향 다 넣는다
PLATE_SHAPES = ["NE", "NW", "SE", "SW", "NEW", "SEW", "NSE", "NSW"]


def build_atlas():
    """열: 곧은 관 2, 이음새 2, 모서리 4, T자 4, 소켓 4 / 줄: 찍은 길, 빈 길, 잠긴 길. 한 칸 16×16"""
    cols = [("rail", "v"), ("rail", "h"), ("collar", "v"), ("collar", "h")] + [("plate", s) for s in PLATE_SHAPES] + [("flange", s) for s in "NESW"]
    atlas = Image.new("RGBA", (16 * len(cols), 16 * 3), (0, 0, 0, 0))
    parts = {}
    maker = {"rail": rail_part, "collar": collar_part, "flange": flange_part}
    for row, tier in enumerate(("lit", "open", "locked")):
        for col, (kind, arg) in enumerate(cols):
            im = plate_part(tier, set(arg)) if kind == "plate" else maker[kind](tier, arg)
            atlas.alpha_composite(im, (col * 16, row * 16))
            box = (col * 16, row * 16, col * 16 + im.width, row * 16 + im.height)
            parts[(tier, kind, frozenset(arg) if kind == "plate" else arg)] = box
    return atlas, parts


ATLAS, BOX = build_atlas()


def part(tier, kind, arg):
    return ATLAS.crop(BOX[(tier, kind, frozenset(arg) if kind == "plate" else arg)])


def check_palette():
    """아틀라스 색은 모두 void32"""
    allowed = set()
    for line in open("assets/palette/void32.gpl"):
        bits = line.split()
        if len(bits) >= 4 and bits[0].isdigit():
            allowed.add(tuple(int(v) for v in bits[:3]))
    used = {px[:3] for px in ATLAS.getdata() if px[3]}
    assert used <= allowed, f"팔레트 밖 색 {used - allowed}"
    assert all(px[3] in (0, 255) for px in ATLAS.getdata()), "반투명 있음"


# ── 관 경로 ───────────────────────────────────
def norm(a, b):
    return (a, b) if a <= b else (b, a)


def path_states(tree, lay, b, levels, forks):
    """links의 선마다 (앞, 뒤, 점들, 단계). make_tabs.board의 판단을 그대로 쓴다"""
    def lit(k):
        n = tree[k[0]]
        return mt.fork_on(b, forks) == k[1] if mt.is_fork(n) else mt.lv_of(n, levels) > 0

    def row_lit(i):
        return any(lit(k) for k in lay["cells"] if k[0] == i)

    out = []
    for p, q, pts in mt.links(tree, lay):
        if p and q:
            on, op = lit(p) and lit(q), mt.state_of(b, q[0], levels, forks) not in ("locked", "soon")
        elif q:
            on, op = lit(q) and row_lit(q[0] - 1), mt.fork_open(tree, q[0], b, levels, forks)
        else:
            on, op = lit(p) and row_lit(p[0] + 1), p[1] in mt.fork_owned(b, forks)
        out.append((p, q, pts, "lit" if on else ("open" if op else "locked")))
    return out


def walk(points):
    """꺾인 선을 1칸씩 걷는다. 아래에서 위로 흐르는 순서"""
    out = []
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0))
        dx, dy = (x1 > x0) - (x1 < x0), (y1 > y0) - (y1 < y0)
        for i in range(n):
            out.append((x0 + dx * i, y0 + dy * i, "v" if dx == 0 else "h"))
    if points:
        out.append((*points[-1], out[-1][2] if out else "v"))
    return out


def route(paths, upto=None):
    """찍은 길을 이어 흐름 한 줄로. 옛 저장처럼 끊긴 곳이 있으면 거기서 새 줄"""
    runs = [[]]
    for _, _, pts, tier in paths:
        if tier != "lit":
            continue
        if runs[-1] and runs[-1][-1] != pts[0]:
            runs.append([])
        runs[-1].extend(pts if not runs[-1] else pts[1:])
    return [r for r in runs if r]


def paint_cross(d, x, y, axis, cols):
    """관 속 4칸 단면 한 줄"""
    for i, col in enumerate(cols):
        if col is not None:
            d.point((x - 2 + i, y) if axis == "v" else (x, y - 2 + i), fill=col)


def draw_pipes(canvas, tree, lay, b, paths, phase, pan, comet=None, unlit=None):
    """그리는 순서: 벽 → 관 속 → 흐름 → 이음쇠. unlit = 찍은 색을 칠하지 않을 칸(바꾸기·강화 때 차오르는 길)"""
    main, light = BRANCH[b]
    fill_cols = (light, main, main, DEEP[b])
    tiers = {}
    conns = {}
    for _, _, pts, tier in paths:
        for a, c in zip(pts, pts[1:]):
            key = norm(a, c)
            if key not in tiers or RANK[tier] > RANK[tiers[key]]:
                tiers[key] = tier
            for u, v in ((a, c), (c, a)):
                d_ = next(n for n, (dx, dy) in DIRS.items() if dx == (v[0] > u[0]) - (v[0] < u[0]) and dy == (v[1] > u[1]) - (v[1] < u[1]))
                conns.setdefault(u, {})[d_] = max(conns.get(u, {}).get(d_, "locked"), tier, key=RANK.get)
    off = lambda p: (p[0], p[1] + pan)
    d = draw(canvas)
    # 벽
    for (a, c), tier in sorted(tiers.items(), key=lambda kv: RANK[kv[1]]):
        o, hi, sh = TIER[tier][:3]
        (x0, y0), (x1, y1) = off(a), off(c)
        if x0 == x1:
            for i, col in ((-4, o), (-3, hi), (2, sh), (3, o)):
                d.line((x0 + i, y0 - 4, x0 + i, y1 + 3), fill=col)
        else:
            for i, col in ((-4, o), (-3, hi), (2, sh), (3, o)):
                d.line((x0 - 4, y0 + i, x1 + 3, y0 + i), fill=col)
    # 빈 관 속
    for (a, c), tier in sorted(tiers.items(), key=lambda kv: RANK[kv[1]]):
        (x0, y0), (x1, y1) = off(a), off(c)
        col = TIER["open" if tier == "lit" else tier][3]
        d.rectangle((x0 - 2, y0 - 2, x1 + 1, y1 + 1), fill=col)
    # 찍은 길 관 속 + 흐름
    for run in route(paths):
        for x, y, axis in walk(run):
            if unlit and (x, y) in unlit:
                continue
            paint_cross(d, x, y + pan, axis, fill_cols)
    if phase is not None:
        for run in route(paths):
            cells = walk(run)
            for head in range(phase % FLOW_SPACING, len(cells), FLOW_SPACING):
                for back in range(9):  # 빛 덩어리: 앞 3칸 밝고 뒤로 흐려진다
                    j = head - back
                    if not 0 <= j < len(cells):
                        continue
                    x, y, axis = cells[j]
                    if unlit and (x, y) in unlit:
                        continue
                    if back < 2:
                        paint_cross(d, x, y + pan, axis, (light, INK, INK, light))
                    elif back < 5:
                        paint_cross(d, x, y + pan, axis, (light, light, light, main))
                    else:
                        paint_cross(d, x, y + pan, axis, (light, light, main, main))
    if comet:
        cells, s = comet
        for j in range(max(0, s - COMET_TAIL), min(s, len(cells) - 1) + 1):
            x, y, axis = cells[j]
            back = s - j
            paint_cross(d, x, y + pan, axis, (INK, INK, INK, INK) if back < 8 else (INK, light, light, INK) if back < 18 else (light, light, light, main))
    # 이음새
    for (a, c), tier in tiers.items():
        (x0, y0), (x1, y1) = off(a), off(c)
        vert = x0 == x1
        lo, hi_ = (y0, y1) if vert else (x0, x1)
        lo += trim(a, c, lay, conns, vert)
        hi_ -= trim(c, a, lay, conns, vert)
        if hi_ - lo < 10:
            continue
        mid = (lo + hi_) // 2
        for k in (-2, -1, 0, 1, 2):
            at = mid + k * 24
            if at - 2 < lo or at + 2 > hi_:
                continue
            im = part(tier, "collar", "v" if vert else "h")
            mm.clip_paste(canvas, im, x0 - 5, at - 2) if vert else mm.clip_paste(canvas, im, at - 2, y0 - 5)
    # 모서리·T자·칸 소켓
    for p, arms in conns.items():
        x, y = off(p)
        names = set(arms)
        tier = max(arms.values(), key=RANK.get)
        straight = names in ({"N", "S"}, {"E", "W"})
        if p in lay["cells"].values():
            continue
        if len(names) >= 2 and not straight:
            mm.clip_paste(canvas, part(tier, "plate", "".join(sorted(names))), x - 6, y - 6)
    for key, p in lay["cells"].items():
        x, y = off(p)
        for side, tier in conns.get(p, {}).items():
            if side == "N":
                mm.clip_paste(canvas, part(tier, "flange", "N"), x - 7, y - 26)
            elif side == "S":
                mm.clip_paste(canvas, part(tier, "flange", "S"), x - 7, y + 22)
            elif side == "W":
                mm.clip_paste(canvas, part(tier, "flange", "W"), x - 24, y - 7)
            else:
                mm.clip_paste(canvas, part(tier, "flange", "E"), x + 20, y - 7)


def trim(a, c, lay, conns, vert):
    """이음새를 끝 부품에서 띄울 거리"""
    if a in lay["cells"].values():
        return 28 if vert else 24
    return 8


# ── 판 ─────────────────────────────────────────
def scroll_bar(d, cw, ch, pan, max_pan, main):
    """끌기 안내: 글자 대신 오른쪽 가장자리 막대. 어느 칸 글자도 덮지 않는다"""
    x0 = cw - BAR_W
    d.rectangle((x0, 2, cw - 3, ch - 3), fill="#2b1925")
    track = ch - 14
    thumb = max(12, track * ch // (ch + max_pan))
    # pan 0 = 맨 아래가 보임 → 막대는 아래쪽
    top = 7 + (track - thumb) * (max_pan - pan) // max_pan
    d.rectangle((x0, top, cw - 3, top + thumb), fill=main)
    if pan < max_pan:
        d.line((x0 + 1, 2, cw - 5, 2), fill=INK)
        d.point((x0 + 1, 3), fill=INK)
        d.point((cw - 5, 3), fill=INK)
    if pan > 0:
        d.line((x0 + 1, ch - 3, cw - 5, ch - 3), fill=INK)
        d.point((x0 + 1, ch - 4), fill=INK)
        d.point((cw - 5, ch - 4), fill=INK)


def board(c, b, levels, forks, cw, ch, sel=None, pan=0, phase=None, comet=None, unlit=None, flash=None):
    """make_tabs.board와 같은 나무. 관·흐름·번쩍임·끌기 막대·1단계 점 없음만 다르다"""
    tree = TREE[b]
    lay = mt.layout(tree, cw, ch)
    mt.check_layout(tree, lay, cw)
    assert 0 <= pan <= lay["max_pan"], pan
    canvas = Image.new("RGBA", (cw, ch), (*m2.rgb(DARK), 255))
    d = draw(canvas)
    cx, (main, light) = lay["cx"], BRANCH[b]
    for yy in range((lay["base"] + pan) % 24, ch, 24):
        for xx in range(cx % 24, cw, 24):
            d.point((xx, yy), fill="#3c3544")
    paths = path_states(tree, lay, b, levels, forks)
    draw_pipes(canvas, tree, lay, b, paths, phase, pan, comet, unlit)
    d = draw(canvas)
    at = {k: (x, y + pan) for k, (x, y) in lay["cells"].items()}
    for (i, side), (x, y) in at.items():
        n = tree[i]
        chosen = sel == (i, side)
        if side == "c":
            st = mt.state_of(b, i, levels, forks)
            lv = mt.lv_of(n, levels)
            mode = "on" if lv else ("can" if st in ("can", "poor") else "plan")
            m2.sock(c, canvas, x, y, mt.icon_of(c, n), b, mode, chosen, 0.8 if st == "can" else 0)
            lx, color = x + mt.SOCK_W // 2 + mt.LABEL_GAP, light if lv else (INK if st in ("can", "poor") else DIM)
            one = mt.max_lv(n) == 1 and st != "soon"
            text(d, lx, y - 7 if one else y - 14, mt.label_of(n), F12, color)
            if st == "soon":
                text(d, lx, y + 1, "곧 추가", F12, MUTED)
            elif not one:  # 1단계 칸은 점 하나가 얼룩처럼 보여 뺀다
                mm.pips(d, lx, y + 3, lv, b, total=mt.max_lv(n), size=5)
            if lv == 0:
                mt.price_tag(c, canvas, d, x, y, f"{mt.cost_of(n, 0):,}", GOLD if st == "can" else ("#f25c76" if st == "poor" else DIM))
        else:
            opt = n[side]
            st = mt.fork_state(tree, i, side, b, levels, forks)
            if st == "idle":
                mt.idle_sock(c, canvas, x, y, opt["icon"], b, chosen)
            else:
                mode = {"on": "on", "locked": "plan"}.get(st, "can")
                m2.sock(c, canvas, x, y, c.p["ic"][opt["icon"]], b, mode, chosen, 0.8 if st == "can" else 0)
            color = {"on": light, "idle": MUTED, "can": INK, "poor": INK, "locked": DIM}[st]
            text(d, x, y + mt.SOCK_H // 2 + 1, opt["name"], F12, color, "ma")
            if st == "on":
                mt.price_tag(c, canvas, d, x, y, "사용 중", light, ore=False)
            elif st == "idle":
                mt.price_tag(c, canvas, d, x, y, "바꾸기", MUTED, ore=False)
            else:
                mt.price_tag(c, canvas, d, x, y, f"{n['cost']:,}", {"can": GOLD, "poor": "#f25c76"}.get(st, DIM))
    if flash:
        key, power = flash
        x, y = at[key]
        s = c.p["socket_on"]
        sx, sy = x - s.width // 2, y - s.height // 2
        m2.ring(canvas, s, sx, sy, light, 1, reach=2 + power)
        if power >= 2:  # 첫 두 장은 칸 전체가 흰색
            white = Image.new("RGBA", s.size, (*m2.rgb(INK), 255))
            white.putalpha(s.getchannel("A").point(lambda v: 255 if v else 0))
            mm.clip_paste(canvas, white, sx, sy)
    if lay["max_pan"]:
        scroll_bar(draw(canvas), cw, ch, pan, lay["max_pan"], main)
    draw(canvas).rectangle((0, 0, cw - 1, ch - 1), outline=main)
    return canvas


# ── 탭 (폰은 옆으로 놓는다) ─────────────────────────
def tabs_phone(c, th, sel_b, levels, forks):
    """폰 탭 줄을 논리 칸으로 그린다: 아이콘 + 이름 + 진행 막대"""
    w = TAB_W["phone"]
    layer = Image.new("RGBA", (w, th * len(TAB_ORDER)), (0, 0, 0, 0))
    d = draw(layer)
    for i, b in enumerate(TAB_ORDER):
        on = b == sel_b
        out = 0 if on else 3
        tw = w - out + (1 if on else 0)
        im = plate(c, "tab", tw, th - 1)
        layer.alpha_composite(im if on else mm.darken(im, 0.65), (out, i * th))
        main, light = BRANCH[b]
        layer.alpha_composite(c.p["emblem"][b], (out + 2, i * th + 4))
        text(d, out + 17, i * th + 5, SHORT_NAME[b], F12, light if on else MUTED)
        done, total = mt.progress(b, levels, forks)
        bx0, bx1, by = out + 4, w - 5, i * th + 20
        d.rectangle((bx0, by, bx1, by + 4), fill=DARK)
        d.rectangle((bx0 + 1, by + 1, bx1 - 1, by + 3), fill="#3c3544")
        if done:
            d.rectangle((bx0 + 1, by + 1, bx0 + 1 + max(1, (bx1 - bx0 - 2) * done // total), by + 3), fill=light if on else main)
        if on:
            d.rectangle((out, i * th, w - 1, i * th + th - 2), outline=main)
    return layer


# ── 설명 창 ────────────────────────────────────
def popup_node(c, b, i, levels, forks, press=False):
    """이름·단계·지금→다음·버튼. 판 안에 들어오게 줄을 아끼고, 1단계 칸은 점을 뺀다"""
    n = TREE[b][i]
    w = POP_W[c.kind]
    light = BRANCH[b][1]
    st, lv = mt.state_of(b, i, levels, forks), mt.lv_of(n, levels)
    effect = mt.effect_text(n, lv)
    lines = m2.wrap(effect, F12, w - 24)
    cost = mt.cost_of(n, lv) if lv < mt.max_lv(n) and st not in ("soon",) else 0
    need_msg = st == "locked" or (st not in ("soon", "max") and cost > mm.CREDITS)
    bh = 24
    h = 8 + 26 + 15 + 14 + len(lines) * 14 + 4 + (14 if need_msg else 0) + bh + 8
    out = plate(c, "tab", w, h)
    d = draw(out)
    x, y = 12, 7
    ic = mt.icon_of(c, n)
    out.alpha_composite(ic, (x, y))
    tx = x + ic.width + 5
    text(d, tx, y - 1, mt.label_of(n), F12, light, limit=w - tx - 6)
    text(d, tx, y + 12, mm.BRANCH_NAME[b], F12, MUTED)
    y += 27
    if st == "soon":
        text(d, x, y, "곧 추가", F12, GOLD)
    elif mt.max_lv(n) == 1:
        text(d, x, y, "한 번만 강화" if lv == 0 else "강화 완료", F12, INK)
    else:
        mm.pips(d, x, y + 2, lv, b, total=mt.max_lv(n), size=6, gap=2)
        text(d, x + mt.max_lv(n) * 8 + 4, y, f"{lv}/{mt.max_lv(n)}단계", F12, INK)
    y += 15
    text(d, x, y, "지금 효과" if lv >= mt.max_lv(n) else "지금 → 다음", F12, TEAL2)
    m2.para(d, x, y + 14, effect, F12, GOLD if lv < mt.max_lv(n) else INK, w - 24, 0)
    by = h - bh - 9
    if st == "soon":
        out.alpha_composite(mm.button(PC, w - 24, bh, "아직 잠김", "off"), (x, by))
    elif st == "locked":
        text(d, x, by - 14, "먼저: " + mt.prev_name(b, i), F12, "#dc7f47", limit=w - 22)
        out.alpha_composite(mm.button(PC, w - 24, bh, "잠김", "off"), (x, by))
    elif st == "max":
        out.alpha_composite(mm.button(PC, w - 24, bh, "최대", "off"), (x, by))
    else:
        if cost > mm.CREDITS:
            text(d, x, by - 14, "광물이 모자라요", F12, "#f25c76")
        out.alpha_composite(mm.button(PC, w - 24, bh, "강화", "off" if cost > mm.CREDITS else ("down" if press else "up"), f"{cost:,}"), (x, by))
    return out


def popup_fork_phone(c, b, i, levels, forks, side, press=False):
    """폰 2배에서는 양쪽 카드가 안 들어가서 누른 쪽 하나만. 다른 쪽은 창을 닫고 그 칸을 누른다"""
    tree = TREE[b]
    n = tree[i]
    w = 160
    bh = 24
    guide = m2.wrap(mt.FORK_GUIDE, F12, w - 24)
    h = 7 + 14 + len(guide) * 14 + 2 + 58 + 3 + bh + 9
    out = plate(c, "tab", w, h)
    d = draw(out)
    x, y = 12, 7
    text(d, x, y, "갈림길", F12, BRANCH[b][1])
    y = m2.para(d, x, y + 14, mt.FORK_GUIDE, F12, MUTED, w - 24, 0) + 2
    st = mt.fork_state(tree, i, side, b, levels, forks)
    mt.fork_card(c, out, x, y, w - 25, n[side], n["cost"], b, st, True)
    by = h - bh - 9
    if st == "on":
        d.rectangle((x, by, x + w - 25, by + bh - 1), fill=DARK, outline=BRANCH[b][1])
        text(d, x + (w - 24) // 2, by + (bh - 16) // 2, "사용 중", F12, BRANCH[b][1], "ma")
    elif st == "idle":
        out.alpha_composite(mm.button(PC, w - 24, bh, "이걸로 바꾸기", "down" if press else "up"), (x, by))
    elif st == "locked":
        out.alpha_composite(mm.button(PC, w - 24, bh, "잠김", "off"), (x, by))
    else:
        out.alpha_composite(mm.button(PC, w - 24, bh, "해금", "off" if st == "poor" else "up", f"{n['cost']:,}"), (x, by))
    return out


def popup_size_rects(tree, lay, pan, skip):
    """창이 피해야 할 것: 누른 칸 말고 다른 칸의 소켓·이름·가격"""
    return [r for owner, kind, r in [(o, k, (x0, y0 + pan, x1, y1 + pan)) for o, k, (x0, y0, x1, y1) in mt.rects(tree, lay)] if owner != skip]


def overlap(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def popup_pos(key, size, tree, lay, cw, ch, pan):
    """칸 옆에서 다른 칸을 안 가리는 가장 가까운 자리. 양쪽 다 가리면 덜 가리는 쪽(같으면 오른쪽). 눌린 칸은 절대 안 가린다
    돌려주는 값: (x, y, 가린 개수)"""
    x, y = lay["cells"][key]
    y += pan
    w, h = size
    max_x = cw - BAR_W - 4 - w if lay["max_pan"] else cw - 4 - w
    half = int(F12.getlength(tree[key[0]][key[1]]["name"])) // 2 if key[1] != "c" else 0
    gap = max(mt.SOCK_W // 2, half) + 6
    avoid = popup_size_rects(tree, lay, pan, key)
    avoid = [r for r in avoid if r[3] > 0 and r[1] < ch]
    best = None
    right = range(x + gap, max_x + 1, 4)
    left = range(x - gap - w, 3, -4)
    for order, xs in ((0, right), (1, left)):
        for dist, px in enumerate(xs):
            for py in range(4, max(4, ch - h - 4) + 1, 4):
                box = (px, py, px + w, py + h)
                score = (sum(overlap(box, r) for r in avoid), dist + abs(py + h // 2 - y) // 8, order)
                if best is None or score < best[0]:
                    best = (score, px, py)
    assert best, f"창 자리 없음 {key} {w} {cw}"
    return best[1], best[2], best[0][0]


def check_popups(c, cw, ch):
    """모든 칸에서: 창이 판 안, 눌린 칸을 안 가림. 가리는 칸 수를 센다"""
    worst = {}
    for b in TAB_ORDER:
        tree = TREE[b]
        lay = mt.layout(tree, cw, ch)
        for pan in sorted({0, lay["max_pan"] // 2, lay["max_pan"]}):
            for key, (x, y) in lay["cells"].items():
                vis_y = y + pan
                if not 0 <= vis_y < ch:
                    continue
                if key[1] == "c":
                    im = popup_node(c, b, key[0], mt.LEVELS, mt.FORKS)
                elif c.kind == "phone":
                    im = popup_fork_phone(c, b, key[0], mt.LEVELS, mt.FORKS, key[1])
                else:
                    im = mt.popup_fork(c, b, key[0], mt.LEVELS, mt.FORKS, key[1])
                assert im.height <= ch - 8, f"창이 판보다 큼 {c.kind} {b} {key} {im.size}"
                px, py, hits = popup_pos(key, im.size, tree, lay, cw, ch, pan)
                assert 0 <= px and px + im.width <= cw and 0 <= py and py + im.height <= ch, f"창이 판 밖 {b} {key}"
                assert px >= x + mt.SOCK_W // 2 or px + im.width <= x - mt.SOCK_W // 2, f"창이 칸을 가림 {b} {key}"
                worst[(b, key, pan)] = hits
    return worst


# ── 합성 ────────────────────────────────────────
def frame(c, b, levels, forks, sel=None, pan=0, phase=None, pop=None, comet=None, unlit=None, flash=None):
    """창 하나 완성. 폰은 탭·판·창을 2배로 키워 꽂는다"""
    z = ZOOM[c.kind]
    layer, body = mm.window(c, "research")
    tw = TAB_W[c.kind]
    cw, ch = (body[2] // z - tw), body[3] // z
    cv = board(c, b, levels, forks, cw, ch, sel, pan, phase, comet, unlit, flash)
    if pop is not None:
        lay = mt.layout(TREE[b], cw, ch)
        px, py, _ = popup_pos(sel, pop.size, TREE[b], lay, cw, ch, pan)
        cv.alpha_composite(pop, (px, py))
    if z == 1:
        mt.TAB_W = tw
        mt.tabs(c, layer, body, b, levels, forks)
        layer.alpha_composite(cv, (body[0] + tw, body[1]))
        th = body[3] // len(TAB_ORDER)
        ty = body[1] + TAB_ORDER.index(b) * th
        draw(layer).rectangle((body[0] + tw - 2, ty + 2, body[0] + tw + 1, ty + th - 5), fill=DARK)
    else:
        th = ch // len(TAB_ORDER)
        tabs = tabs_phone(c, th, b, levels, forks)
        layer.alpha_composite(tabs.resize((tabs.width * z, tabs.height * z), Image.NEAREST), (body[0], body[1]))
        layer.alpha_composite(cv.resize((cv.width * z, cv.height * z), Image.NEAREST), (body[0] + tw * z, body[1]))
    return mm.compose(c, layer, 0, 1, 0)


def tag(c):
    return "pc_1280x720" if c.kind == "pc" else "phone_844x390"


def save_gif(frames, name, ms=40):
    """프레임 전체 색을 모아 팔레트 하나로. 디더링 없음"""
    sheet = Image.new("RGB", (frames[0].width, frames[0].height * min(len(frames), 6)))
    step = max(1, len(frames) // 6)
    for i, f in enumerate(frames[::step][:6]):
        sheet.paste(f, (0, i * frames[0].height))
    pal = sheet.quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE)
    out = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
    out[0].save(OUT + name, save_all=True, append_images=out[1:], duration=ms, loop=0, optimize=False, disposal=1)


# ── 장면 ────────────────────────────────────────
L = dict(mt.LEVELS, shield=2, reroll=1, insurance=2, repair=0)


def fork_index(b):
    return next(i for i, n in enumerate(TREE[b]) if mt.is_fork(n))


def main():
    check_palette()
    ATLAS.save(OUT + "pipes_atlas.png")
    ATLAS.resize((ATLAS.width * 4, ATLAS.height * 4), Image.NEAREST).save(OUT + "pipes_atlas_x4.png")
    global PC
    parts = m2.load_parts2()
    PC = mm.Ctx(parts, "pc")  # 폰 창은 PC와 같은 논리 칸으로 그려 2배로 키운다
    real_credits = mm.CREDITS
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        z = ZOOM[kind]
        _, body = mm.window(c, "research")
        cw, ch = body[2] // z - TAB_W[kind], body[3] // z
        for b in TAB_ORDER:
            mt.check_layout(TREE[b], mt.layout(TREE[b], cw, ch), cw)
            names = [r for _, k, r in mt.rects(TREE[b], mt.layout(TREE[b], cw, ch)) if k == "이름"]
            assert all(r[2] <= cw - BAR_W - 1 for r in names), f"이름이 끌기 막대에 닿음 {b}"
        hits = check_popups(c, cw, ch)
        bad = {k: v for k, v in hits.items() if v}
        print(kind, "판", cw, ch, "창 위치", len(hits), "곳, 다른 칸을 가린 곳", len(bad))
        if kind == "pc":
            assert not bad, f"PC에서 창이 다른 칸을 가림 {bad}"
        fi = fork_index("hull")
        lay = mt.layout(TREE["hull"], cw, ch)
        top = lay["max_pan"]
        F2 = {"hull": {"on": "a", "owned": "ab"}, "elec": {"on": "a", "owned": "a"}}
        F3 = {"hull": {"on": "b", "owned": "ab"}, "elec": {"on": "a", "owned": "a"}}
        mid = top // 2

        # 정지 캡처: 찍은 길 / 빈 길 / 잠긴 길 / 갈림길이 다 보이게
        for name, b, levels, forks, pan in (
            ("still_hull_fork", "hull", L, F2, top if z > 1 else 0),
            ("still_hull_start", "hull", dict(L, max_hp=1, insurance=0), {}, 0),
            ("still_weapon", "weapon", L, F2, 0),
            ("still_mine_dragged", "mine", L, F2, mt.layout(TREE["mine"], cw, ch)["max_pan"]),
            ("still_elec", "elec", L, F2, mid if mt.layout(TREE["elec"], cw, ch)["max_pan"] else 0),
        ):
            pan = min(pan, mt.layout(TREE[b], cw, ch)["max_pan"])
            frame(c, b, levels, forks, pan=pan, phase=12).save(f"{OUT}{name}_{tag(c)}.png")

        # 설명 창: 다른 칸을 피하는지
        ins = TREE["hull"].index("insurance")
        frame(c, "hull", L, F2, sel=(ins, "c"), pan=mid if z > 1 else 0, phase=12, pop=popup_node(c, "hull", ins, L, F2)).save(f"{OUT}still_popup_{tag(c)}.png")
        frk = popup_fork_phone(c, "hull", fi, L, F2, "b") if z > 1 else mt.popup_fork(c, "hull", fi, L, F2, "b")
        frame(c, "hull", L, F2, sel=(fi, "b"), pan=top if z > 1 else 0, phase=12, pop=frk).save(f"{OUT}still_popup_fork_{tag(c)}.png")

        # 흐름 GIF: 2초 반복, 끊김 없음
        pan = mid if z > 1 else 0
        save_gif([frame(c, "hull", L, F2, pan=pan, phase=p) for p in range(FLOW_FRAMES)], f"flow_{kind}.gif")

        # 바꾸기 GIF: 왼쪽 흐름이 빠지고 오른쪽이 차오른다
        pan = top if z > 1 else 0
        paths_a = path_states(TREE["hull"], lay, "hull", L, F2)
        paths_b = path_states(TREE["hull"], lay, "hull", L, F3)
        cells_a = set((x, y) for r in route(paths_a) for x, y, _ in walk(r))
        cells_b = set((x, y) for r in route(paths_b) for x, y, _ in walk(r))
        only_a = [p for r in route(paths_a) for p in walk(r) if (p[0], p[1]) not in cells_b]
        only_b = [p for r in route(paths_b) for p in walk(r) if (p[0], p[1]) not in cells_a]
        pop = lambda fs, press=False: (popup_fork_phone(c, "hull", fi, L, fs, "b", press) if z > 1 else mt.popup_fork(c, "hull", fi, L, fs, "b", press))
        frames, p = [], 0
        for _ in range(12):
            frames.append(frame(c, "hull", L, F2, sel=(fi, "b"), pan=pan, phase=p, pop=pop(F2)))
            p += 1
        for _ in range(4):
            frames.append(frame(c, "hull", L, F2, sel=(fi, "b"), pan=pan, phase=p, pop=pop(F2, True)))
            p += 1
        for _ in range(8):  # 창을 닫고 흐름이 옮겨 가는 것이 보이게
            frames.append(frame(c, "hull", L, F2, pan=pan, phase=p))
            p += 1
        n = len(only_a)
        for k in range(0, n, 8):  # 먼 쪽부터 빠진다
            gone = {(x, y) for x, y, _ in only_a[n - k - 8:]} if k + 8 < n else {(x, y) for x, y, _ in only_a}
            frames.append(frame(c, "hull", L, F2, pan=pan, phase=p, unlit=gone))
            p += 1
        n = len(only_b)
        for k in range(0, n, 8):  # 가까운 쪽부터 찬다
            empty = {(x, y) for x, y, _ in only_b[k + 8:]}
            frames.append(frame(c, "hull", L, F3, pan=pan, phase=p, unlit=empty))
            p += 1
        for _ in range(40):
            frames.append(frame(c, "hull", L, F3, pan=pan, phase=p))
            p += 1
        save_gif(frames, f"flow_swap_{kind}.gif")

        # 강화 GIF: 맨 위 칸(긴급 수리)을 찍는다. 빛이 갈림길을 지나 달려가 칸이 번쩍
        mm.CREDITS = 3000
        # 폰은 창이 커서 갈림길을 가리므로 빛이 다 보이는 줄기 칸(화물 회수 신호기 2→3)으로
        target = next(i for i, n in enumerate(TREE["hull"]) if i > fi) if z == 1 else ins
        lv0 = mt.lv_of(TREE["hull"][target], L)
        before, after = L, dict(L, **{mt.nid(TREE["hull"][target]): lv0 + 1})
        pan = 0
        key = (target, "c")
        popb = lambda levels, press=False: popup_node(c, "hull", target, levels, F2, press)
        paths = path_states(TREE["hull"], lay, "hull", after, F2)
        cells = walk(route(paths)[0])
        goal = lay["cells"][key]
        cells = cells[:next(j for j, q in enumerate(cells) if (q[0], q[1]) == goal) + 1]
        old = {(x, y) for r in route(path_states(TREE["hull"], lay, "hull", before, F2)) for x, y, _ in walk(r)}
        frames, p = [], 0
        for _ in range(16):
            frames.append(frame(c, "hull", before, F2, sel=key, pan=pan, phase=p, pop=popb(before)))
            p += 1
        for _ in range(4):
            frames.append(frame(c, "hull", before, F2, sel=key, pan=pan, phase=p, pop=popb(before, True)))
            p += 1
        mm.CREDITS = 3000 - mt.cost_of(TREE["hull"][target], lv0)
        s = 0
        while s < len(cells) + 8:
            # 머리가 지나간 새 길만 찬다
            ahead = {(x, y) for x, y, _ in cells[min(s, len(cells)):] if (x, y) not in old}
            frames.append(frame(c, "hull", after, F2, sel=key, pan=pan, phase=p, pop=popb(after), comet=(cells, s), unlit=ahead))
            p += 1
            s += COMET_SPEED
        for power in (3, 3, 2, 1, 1, 0):
            frames.append(frame(c, "hull", after, F2, sel=key, pan=pan, phase=p, pop=popb(after), flash=(key, power)))
            p += 1
        for _ in range(40):
            frames.append(frame(c, "hull", after, F2, sel=key, pan=pan, phase=p, pop=popb(after)))
            p += 1
        save_gif(frames, f"upgrade_{kind}.gif")
        mm.CREDITS = real_credits
    assert not sorted(set(mm.WARN)), sorted(set(mm.WARN))
    print("시안 저장. 아틀라스 팔레트·격자·대칭·겹침·창 위치 검사 통과")


if __name__ == "__main__":
    main()
