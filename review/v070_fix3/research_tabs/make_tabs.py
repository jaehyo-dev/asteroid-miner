"""v0.7.0 연구소 새 배치 시안 (게임에 적용하지 않음). 그림·색·아이콘은 3차 시안 그대로, 배치만 바꾼다.
왼쪽 세로 탭 5개 + 오른쪽 판에 고른 가지 하나. 칸은 모두 격자 위, 갈림길은 가운데 줄기 기준 좌우 대칭.
실행: 저장소 맨 위에서 python3 review/v070_fix3/research_tabs/make_tabs.py"""
import sys

from PIL import Image

sys.path[:0] = ["review/v070_fix3"]
import make_mockups3 as m3  # noqa: E402
from make_mockups3 import BRANCH, DARK, DIM, F12, F24, GOLD, INK, MUTED, SHORT_NAME, TEAL2, TREE, draw, m2, mm, plate, text  # noqa: E402

OUT = "review/v070_fix3/research_tabs/"
TAB_ORDER = ["weapon", "hull", "mine", "elec", "survey"]
COL = ROW = 72  # 격자 한 칸 (배경 점 24칸의 3배라 점과도 맞는다)
FORK_COLS = 1  # 갈림길은 줄기에서 좌우로 이만큼
TAB_W = 58  # 탭 줄 폭. 고른 탭만 왼쪽으로 튀어나오고 판과 이어진다
SOCK_H = 48  # 가장 큰 소켓(잠금) 기준. 모양마다 높이가 짝수라 중심은 같다
SOCK_W = 40
PRICE_H = 14
LABEL_GAP = 10  # 칸과 이름 사이
NAME_H = 14  # 갈림길 칸 아래 이름 높이
JOIN_UP = SOCK_H // 2 + PRICE_H + 4  # 갈림길에서 합쳐지는 가로선은 칸 중심에서 이만큼 위: 자기 가격 바로 위
MARGIN = 6
POP_W = {"pc": 184, "phone": 216}
FORK_POP_W = {"pc": 158, "phone": 264}  # 갈림길 창은 바깥쪽에 뜬다: PC는 줄기 옆 자리가 좁다
FORK_POP_GAP = 36  # 가장 긴 갈림길 이름(빨리 나르기)의 절반보다 넓게
FORK_GUIDE = "둘 다 해금하면 언제든 바꿔 쓸 수 있어요"
STEP_FX = {"shield": ("피해 막기 +{}번", 1), "reroll": ("다시 뽑기 +{}번", 1), "appraise": ("광물 가치 +{}%", 3), "radar": ("희귀 이상 확률 +{}%", 1)}  # 임시 수치
SOON = {"sub", "planet"}
LEVELS = dict(m3.LEVELS, shield=2, reroll=1)  # 표본: 탭마다 찍음·열림·잠김 상태가 보이게
FORKS = {"elec": {"on": "a", "owned": "a"}}  # on 사용 중인 쪽, owned 해금한 쪽들. 저장도 이 둘을 따로 둔다


def is_fork(n):
    return isinstance(n, dict) and n.get("fork")


def nid(n):
    return n if isinstance(n, str) else n["id"]


def label_of(n):
    return m3.label_of(n)


def fork_on(b, forks):
    return forks.get(b, {}).get("on")


def fork_owned(b, forks):
    return forks.get(b, {}).get("owned", "")


def board_size(c):
    _, body = mm.window(c, "research")
    return body[2] - TAB_W, body[3]


def content_h(rows):
    return (rows - 1) * ROW + SOCK_H + PRICE_H


def layout(tree, cw, ch):
    """칸 중심을 격자에서 계산한다. {(줄, 쪽): (x, y)} 쪽은 c 줄기, a 왼쪽, b 오른쪽. 넘치면 맨 아래 칸이 보이게 두고 위로 끌어 본다"""
    cx = cw // 2
    # 연달아 갈림길이면 아래 칸 가격과 위 칸 이름이 겹쳐 한 줄 띄운다
    gap_before = [i > 0 and bool(is_fork(n)) and bool(is_fork(tree[i - 1])) for i, n in enumerate(tree)]
    rows = len(tree) + sum(gap_before)
    h = content_h(rows)
    base = (ch + h) // 2 - SOCK_H // 2 if h + 2 * MARGIN <= ch else ch - MARGIN - SOCK_H // 2
    cells = {}
    grid_row = 0
    for i, n in enumerate(tree):
        grid_row += gap_before[i]
        y = base - grid_row * ROW
        grid_row += 1
        if is_fork(n):
            cells[(i, "a")] = (cx - FORK_COLS * COL, y)
            cells[(i, "b")] = (cx + FORK_COLS * COL, y)
        else:
            cells[(i, "c")] = (cx, y)
    return {"cx": cx, "base": base, "cells": cells, "rows": rows, "max_pan": max(0, h + 2 * MARGIN - ch)}


def links(tree, lay):
    """연결선: 가로·세로로만 꺾인다. (앞칸 번호·쪽, 뒤칸 번호·쪽, 점들).
    갈림길 칸 아래에 이름이 있어서, 줄기는 갈림길 높이까지 올라와 T자로 칸 옆구리에 들어간다. 나갈 때는 칸 위로 나가 합쳐진다"""
    cx, cells = lay["cx"], lay["cells"]
    out = []
    for i in range(1, len(tree)):
        ps = [k for k in cells if k[0] == i - 1]
        qs = [k for k in cells if k[0] == i]
        if len(ps) == 1 and len(qs) == 1:
            out.append((ps[0], qs[0], [cells[ps[0]], cells[qs[0]]]))
            continue
        start = cells[ps[0]]
        if len(ps) == 2:
            jy = start[1] - JOIN_UP
            start = (cx, jy)
            for k in ps:
                out.append((k, None, [cells[k], (cells[k][0], jy), start]))
        for k in qs:
            pts = [start, (cx, cells[k][1]), cells[k]] if len(qs) == 2 else [start, cells[k]]
            out.append((None, k, pts))
    return out


def rects(tree, lay, font=F12):
    """칸·이름·가격 사각형: 겹침 검사와 그리기가 같은 자리를 쓴다"""
    out = []
    for (i, side), (x, y) in lay["cells"].items():
        n = tree[i]
        name = label_of(n) if side == "c" else n[side]["name"]
        w = int(font.getlength(name))
        owner = (i, side)
        out.append((owner, "칸", (x - SOCK_W // 2, y - SOCK_H // 2, x + SOCK_W // 2, y + SOCK_H // 2)))
        out.append((owner, "가격", (x - 30, y - SOCK_H // 2 - PRICE_H, x + 30, y - SOCK_H // 2)))
        lx = x + SOCK_W // 2 + LABEL_GAP
        if side == "c":
            out.append((owner, "이름", (lx, y - 14, lx + w, y + 14)))
        else:  # 갈림길 이름은 칸 아래 가운데
            ny = y + SOCK_H // 2 + 1
            out.append((owner, "이름", (x - w // 2, ny, x - w // 2 + w, ny + NAME_H)))
    return out


def check_lines(paths, rs):
    """연결선이 이름·남의 가격·지나치는 칸과 겹치면 실패. 자기 칸 위 가격은 자기 줄기 위에 얹는 표(기존 배치)라 허용"""
    for pts in paths:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            a = (min(x0, x1) - 3, min(y0, y1) - 3, max(x0, x1) + 4, max(y0, y1) + 4)  # 윤곽 굵기 포함
            for owner, kind, r in rs:
                if not (a[0] < r[2] and r[0] < a[2] and a[1] < r[3] and r[1] < a[3]):
                    continue
                if kind == "가격" and x0 == x1 == (r[0] + r[2]) // 2:
                    continue
                if kind == "칸" and any(r[0] <= px <= r[2] and r[1] <= py <= r[3] for px, py in pts):
                    continue  # 이 선이 들어가거나 나가는 칸
                raise AssertionError(f"연결선 겹침 {owner} {kind} {r} / {pts}")


def check_layout(tree, lay, cw):
    """격자·대칭·직각 검사. 하나라도 어긋나면 AssertionError"""
    cx, base, cells = lay["cx"], lay["base"], lay["cells"]
    assert abs(cx - cw // 2) == 0, f"줄기가 판 가운데가 아님 {cx} {cw}"
    for k, (x, y) in cells.items():
        assert (x - cx) % COL == 0, f"세로줄 어긋남 {k} x={x}"
        assert (base - y) % ROW == 0, f"가로줄 어긋남 {k} y={y}"
    row_y = [next(y for k, (_, y) in cells.items() if k[0] == i) for i in range(len(tree))]
    assert row_y == sorted(set(row_y), reverse=True), f"줄 순서 어긋남 {row_y}"
    for i, n in enumerate(tree):
        if is_fork(n):
            (ax, ay), (bx, by) = cells[(i, "a")], cells[(i, "b")]
            assert ay == by, f"갈림길 높이 다름 {i}"
            assert cx - ax == bx - cx > 0, f"갈림길 대칭 아님 {i}: {ax} {cx} {bx}"
            assert (i, "c") not in cells, f"갈림길에 줄기 칸 {i}"
        else:
            assert cells[(i, "c")][0] == cx, f"줄기가 가운데 세로줄에서 벗어남 {i}"
    for _, _, pts in links(tree, lay):
        for a, b in zip(pts, pts[1:]):
            assert a[0] == b[0] or a[1] == b[1], f"대각선 연결 {a} {b}"
    rs = rects(tree, lay)
    check_lines([pts for _, _, pts in links(tree, lay)], rs)
    for j, (n1, k1, a) in enumerate(rs):
        assert 0 <= a[0] and a[2] <= cw, f"판 밖으로 나감 {n1} {k1} {a} {cw}"
        for n2, k2, r in rs[j + 1:]:
            if n1 == n2:
                continue
            assert not (a[0] < r[2] and r[0] < a[2] and a[1] < r[3] and r[1] < a[3]), f"겹침 {n1} {k1} / {n2} {k2}"


def expect_fail(fn, why):
    try:
        fn()
    except AssertionError:
        return
    raise SystemExit(f"검사가 잡아내지 못함: {why}")


def self_test(cw, ch):
    """검사 자체를 검사: 일부러 어긋난 배치는 반드시 실패해야 한다"""
    tree = TREE["hull"]
    fork_i = next(i for i, n in enumerate(tree) if is_fork(n))

    def broken(key, dx, dy):
        lay = layout(tree, cw, ch)
        x, y = lay["cells"][key]
        lay["cells"][key] = (x + dx, y + dy)
        return lay

    expect_fail(lambda: check_layout(tree, broken((0, "c"), 1, 0), cw), "줄기 1칸 어긋남")
    expect_fail(lambda: check_layout(tree, broken((1, "c"), 0, 1), cw), "가로줄 1칸 어긋남")
    expect_fail(lambda: check_layout(tree, broken((fork_i, "b"), COL, 0), cw), "갈림길 한쪽 치우침")
    expect_fail(lambda: check_layout(tree, broken((fork_i, "a"), 0, ROW), cw), "갈림길 높이 다름")
    expect_fail(lambda: check_lines([[(0, 0), (100, 0)]], [((0, "a"), "이름", (40, -5, 60, 5))]), "선이 이름을 지남")
    expect_fail(lambda: check_lines([[(0, 0), (100, 0)]], [((0, "a"), "가격", (40, -5, 60, 5))]), "가로선이 가격을 지남")
    # 갈림길 두 번, 연달아 갈림길도 대칭이어야 한다
    f = tree[fork_i]
    for multi in (["max_hp", f, "insurance", f, "speed"], ["max_hp", f, f, "speed"]):
        check_layout(multi, layout(multi, cw, ch), cw)


# ── 칸 상태 ───────────────────────────────────
def lv_of(n, levels):
    return levels.get(nid(n), 0)


def max_lv(n):
    return 5 if isinstance(n, str) or nid(n) in STEP_FX else 1


def cost_of(n, lv):
    return mm.DATA["upgrades"][n]["levels"][lv]["cost"] if isinstance(n, str) else int(n["cost"] * 1.6 ** lv)


def fork_open(tree, i, b, levels, forks):
    return i == 0 or passed(tree, i - 1, b, levels, forks)


def passed(tree, i, b, levels, forks):
    n = tree[i]
    return bool(fork_owned(b, forks)) if is_fork(n) else lv_of(n, levels) > 0


def state_of(b, i, levels, forks, tree=None):
    """on 찍음(더 올릴 수 있음), max, can, poor, locked, soon. 옛 저장에서 앞 칸 없이 올린 칸은 잠그지 않는다"""
    tree = tree or TREE[b]
    n = tree[i]
    if nid(n) in SOON:
        return "soon"
    lv = lv_of(n, levels)
    if lv >= max_lv(n):
        return "max"
    if lv == 0 and not fork_open(tree, i, b, levels, forks):
        return "locked"
    if lv > 0:
        return "on"
    return "can" if cost_of(n, lv) <= mm.CREDITS else "poor"


def fork_state(tree, i, side, b, levels, forks):
    """갈림길 한쪽: on 사용 중, idle 해금했지만 꺼짐, can 해금 가능, poor 광물 부족, locked 앞 칸 안 찍음"""
    if fork_on(b, forks) == side:
        return "on"
    if side in fork_owned(b, forks):
        return "idle"
    if not fork_open(tree, i, b, levels, forks):
        return "locked"
    return "can" if tree[i]["cost"] <= mm.CREDITS else "poor"


def icon_of(c, n):
    return c.p["node_icons"][mm.NODE_ICON[n]] if isinstance(n, str) else c.p["ic"][n["icon"]]


def progress(b, levels, forks):
    done = total = 0
    for n in TREE[b]:
        if is_fork(n):
            total += 2  # 양쪽 다 해금할 수 있다
            done += len(fork_owned(b, forks))
        elif nid(n) not in SOON:
            total += max_lv(n)
            done += lv_of(n, levels)
    return done, total


# ── 그리기 ────────────────────────────────────
def pipes(d, paths, b):
    """직각 연결선. 윤곽을 먼저 다 그려야 T자 만나는 곳이 끊기지 않는다. 모서리가 비지 않게 사각형으로 그린다"""
    main, light = BRANCH[b]

    def fill(pts, r, col):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            d.rectangle((min(x0, x1) - r, min(y0, y1) - r, max(x0, x1) + r, max(y0, y1) + r), fill=col)

    for _, pts, _ in paths:
        fill(pts, 3, DARK)
    for on, pts, op in paths:
        if not on:
            fill(pts, 1, m2.DIM if op else "#3c3544")
    for on, pts, _ in paths:
        if on:
            fill(pts, 2, main)
    for on, pts, _ in paths:
        if on:
            fill(pts, 0, light)


def price_tag(c, canvas, d, x, y, s, color, ore=True):
    w = int(F12.getlength(s)) + (14 if ore else 0)
    x0 = x - w // 2
    d.rectangle((x0 - 2, y - SOCK_H // 2 - PRICE_H, x0 + w + 2, y - SOCK_H // 2 - 1), fill=DARK)
    if ore:
        im = mm.sprite("assets/sprites/run/mineral_3.png")
        canvas.alpha_composite(im, (x0, y - SOCK_H // 2 - PRICE_H + (PRICE_H - im.height) // 2)) if y - SOCK_H // 2 - PRICE_H >= 0 else None
        x0 += 14
    text(d, x0, y - SOCK_H // 2 - PRICE_H, s, F12, color)


def idle_sock(c, canvas, x, y, icon, b, selected):
    """해금했지만 꺼진 갈림길 칸: 가지 색 테두리를 어둡게, 빛은 은은하게. 잠긴 칸처럼 보이면 안 된다"""
    s = m2.darken(m2.rim(c.p["socket_on"], b), 0.6)
    sx, sy = x - s.width // 2, y - s.height // 2
    m2.ring(canvas, s, sx, sy, INK if selected else BRANCH[b][1], 1 if selected else 0.25)
    mm.clip_paste(canvas, s, sx, sy)
    ic = m2.darken(c.p["ic"][icon], 0.75)
    mm.clip_paste(canvas, ic, x - ic.width // 2, y + 1 - ic.height // 2)


def board(c, b, levels, forks, sel=None, pan=0, debug=False, pulse=0.8):
    """고른 가지 하나의 나무. sel = (줄, 쪽)"""
    cw, ch = board_size(c)
    tree = TREE[b]
    lay = layout(tree, cw, ch)
    check_layout(tree, lay, cw)
    assert 0 <= pan <= lay["max_pan"], pan
    canvas = Image.new("RGBA", (cw, ch), (*m2.rgb(DARK), 255))
    d = draw(canvas)
    cx, main, light = lay["cx"], *BRANCH[b]
    for yy in range((lay["base"] + pan) % 24, ch, 24):  # 배경 점도 같은 격자 위
        for xx in range(cx % 24, cw, 24):
            d.point((xx, yy), fill="#3c3544")
    at = {k: (x, y + pan) for k, (x, y) in lay["cells"].items()}

    def lit(k):
        n = tree[k[0]]
        return fork_on(b, forks) == k[1] if is_fork(n) else lv_of(n, levels) > 0

    def row_lit(i):
        return any(lit(k) for k in at if k[0] == i)

    drawn = []
    for p, q, pts in links(tree, lay):
        pts = [(x, y + pan) for x, y in pts]
        if p and q:
            on, op = lit(p) and lit(q), state_of(b, q[0], levels, forks) not in ("locked", "soon")
        elif q:  # 가로선에서 뒤 칸으로
            on, op = lit(q) and row_lit(q[0] - 1), fork_open(tree, q[0], b, levels, forks)
        else:  # 갈림길에서 합쳐지는 선. 해금한 쪽만 밝게
            on = lit(p) and row_lit(p[0] + 1)
            op = p[1] in fork_owned(b, forks)
        drawn.append((on, pts, op))
    pipes(d, drawn, b)
    for (i, side), (x, y) in at.items():
        n = tree[i]
        chosen = sel == (i, side)
        if side == "c":
            st = state_of(b, i, levels, forks)
            lv = lv_of(n, levels)
            mode = "on" if lv else ("can" if st in ("can", "poor") else "plan")
            m2.sock(c, canvas, x, y, icon_of(c, n), b, mode, chosen, pulse if st == "can" else 0)
            lx, color = x + SOCK_W // 2 + LABEL_GAP, light if lv else (INK if st in ("can", "poor") else DIM)
            text(d, lx, y - 14, label_of(n), F12, color)
            if st == "soon":
                text(d, lx, y + 1, "곧 추가", F12, MUTED)
            else:
                mm.pips(d, lx, y + 3, lv, b, total=max_lv(n), size=5)
            if lv == 0:
                price_tag(c, canvas, d, x, y, f"{cost_of(n, 0):,}", GOLD if st == "can" else ("#f25c76" if st == "poor" else DIM))
        else:
            opt = n[side]
            st = fork_state(tree, i, side, b, levels, forks)
            if st == "idle":
                idle_sock(c, canvas, x, y, opt["icon"], b, chosen)
            else:
                mode = {"on": "on", "locked": "plan"}.get(st, "can")
                m2.sock(c, canvas, x, y, c.p["ic"][opt["icon"]], b, mode, chosen, pulse if st == "can" else 0)
            color = {"on": light, "idle": MUTED, "can": INK, "poor": INK, "locked": DIM}[st]
            text(d, x, y + SOCK_H // 2 + 1, opt["name"], F12, color, "ma")
            if st == "on":
                price_tag(c, canvas, d, x, y, "사용 중", light, ore=False)
            elif st == "idle":
                price_tag(c, canvas, d, x, y, "바꾸기", MUTED, ore=False)
            else:
                price_tag(c, canvas, d, x, y, f"{n['cost']:,}", {"can": GOLD, "poor": "#f25c76"}.get(st, DIM))
    if debug:
        grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        g = draw(grid)
        for xx in range(cx % COL, cw, COL):
            g.line((xx, 0, xx, ch), fill=(255, 0, 255, 255 if xx == cx else 130))
        for yy in range((lay["base"] + pan) % ROW, ch, ROW):
            g.line((0, yy, cw, yy), fill=(255, 0, 255, 130))
        canvas.alpha_composite(grid)
        d = draw(canvas)
        for x, y in at.values():  # 칸 중심 표시
            d.line((x - 3, y, x + 3, y), fill="#ffffff")
            d.line((x, y - 3, x, y + 3), fill="#ffffff")
        text(d, cw - 6, ch - 16, "격자 확인용 (게임에는 안 보임)", F12, "#ff80ff", "ra")
    if lay["max_pan"]:  # 넘칠 때만: 어느 쪽에 더 있는지
        hint = "▲ 위로 끌어 더 보기" if pan < lay["max_pan"] else "▼ 아래로 끌어 되돌리기"
        w = int(F12.getlength(hint))
        d.rectangle((cw - w - 8, 2, cw - 2, 17), fill=DARK)
        text(d, cw - 5, 3, hint, F12, MUTED, "ra")
    d.rectangle((0, 0, cw - 1, ch - 1), outline=main)
    return canvas


def tabs(c, layer, body, sel_b, levels, forks, locked=()):
    x0, y0, _, bh = body
    d = draw(layer)
    th = bh // len(TAB_ORDER)
    for i, b in enumerate(TAB_ORDER):
        on, lock = b == sel_b, b in locked
        out = 0 if on else 5  # 고른 탭은 왼쪽으로 튀어나오고 판과 맞닿는다
        w = TAB_W - out + (2 if on else 0)
        im = plate(c, "tab", w, th - 2)
        im = im if on else mm.darken(im, 0.65)
        layer.alpha_composite(im, (x0 + out, y0 + i * th))
        tx = x0 + out + w // 2 - (1 if on else 0)
        ty = y0 + i * th + 4
        main, light = BRANCH[b]
        if lock:
            ic = c.p["lock"]
            layer.alpha_composite(ic, (tx - ic.width // 2, ty + 2))
            text(d, tx, ty + 19, SHORT_NAME[b], F12, DIM, "ma")
            continue
        ic = c.p["emblem"][b]
        layer.alpha_composite(ic, (tx - ic.width // 2, ty + 1))
        text(d, tx, ty + 17, SHORT_NAME[b], F12, light if on else mm.MUTED, "ma")
        done, total = progress(b, levels, forks)
        bx0, bx1, by = tx - 19, tx + 19, ty + 34
        d.rectangle((bx0, by, bx1, by + 5), fill=DARK)
        d.rectangle((bx0 + 1, by + 1, bx1 - 1, by + 4), fill="#3c3544")
        if done:
            d.rectangle((bx0 + 1, by + 1, bx0 + 1 + max(1, (bx1 - bx0 - 2) * done // total), by + 4), fill=light if on else main)
        if on:  # 튀어나온 탭 가장자리를 가지 색으로
            d.rectangle((x0 + out, y0 + i * th, x0 + out + w - 1, y0 + i * th + th - 3), outline=main)


def effect_text(n, lv):
    """지금 효과 → 다음 효과"""
    if isinstance(n, str):
        return mm.DATA["upgrades"][n]["levels"][lv]["change"]
    if nid(n) in STEP_FX:
        fmt, k = STEP_FX[nid(n)]
        now = fmt.format(k * lv) if lv else "없음"
        return now if lv >= 5 else f"{now} → {fmt.format(k * (lv + 1)).split(' ')[-1] if lv else fmt.format(k)}"
    return n["effect"] if lv else "없음 → " + n["effect"]


def popup_node(c, b, i, levels, forks, press=False):
    n = TREE[b][i]
    w = POP_W[c.kind]
    bh = 44 if c.kind == "phone" else 26
    light = BRANCH[b][1]
    st, lv = state_of(b, i, levels, forks), lv_of(n, levels)
    lines = m2.wrap(effect_text(n, lv), F12, w - 24)
    h = 14 + 26 + 18 + 15 + len(lines) * 14 + 8 + 15 + bh + 12
    out = plate(c, "tab", w, h)
    d = draw(out)
    x, y = 12, 10
    ic = icon_of(c, n)
    out.alpha_composite(ic, (x, y))
    tx = x + ic.width + 6
    text(d, tx, y - 1, label_of(n), F12, light, limit=w - tx - 8)
    text(d, tx, y + 12, mm.BRANCH_NAME[b], F12, MUTED)
    y += 30
    if st == "soon":
        text(d, x, y, "곧 추가", F12, GOLD)
    else:
        mm.pips(d, x, y + 2, lv, b, total=max_lv(n), size=6, gap=2)
        text(d, x + max_lv(n) * 8 + 6, y, f"{lv}/{max_lv(n)}단계", F12, INK)
    y += 18
    text(d, x, y, "지금 효과" if lv >= max_lv(n) else "지금 → 다음", F12, TEAL2)
    y = m2.para(d, x, y + 15, effect_text(n, lv), F12, GOLD if lv < max_lv(n) else INK, w - 24, 1) + 6
    by = h - bh - 12
    if st == "soon":
        out.alpha_composite(mm.button(c, w - 24, bh, "아직 잠김", "off"), (x, by))
    elif st == "locked":
        text(d, x, by - 15, "먼저 찍을 칸: " + prev_name(b, i), F12, "#dc7f47", limit=w - 22)
        out.alpha_composite(mm.button(c, w - 24, bh, "잠김", "off"), (x, by))
    elif st == "max":
        out.alpha_composite(mm.button(c, w - 24, bh, "최대", "off"), (x, by))
    else:
        cost = cost_of(n, lv)
        if cost > mm.CREDITS:
            text(d, x, by - 15, "광물이 모자라요", F12, "#f25c76")
        out.alpha_composite(mm.button(c, w - 24, bh, "강화", "off" if cost > mm.CREDITS else ("down" if press else "up"), f"{cost:,}"), (x, by))
    return out


def prev_name(b, i):
    p = TREE[b][i - 1]
    return "갈림길" if is_fork(p) else label_of(p)


def fork_card(c, out, x, y, w, opt, cost, b, st, selected):
    """창 안 갈림길 한쪽: 아이콘, 이름, 상태 또는 가격, 효과"""
    d = draw(out)
    light = BRANCH[b][1]
    h = 58
    dim = st == "locked"
    d.rectangle((x, y, x + w, y + h), fill=DARK, outline=INK if selected else (light if st == "on" else "#5c5164"))
    ic = c.p["ic"][opt["icon"]]
    out.alpha_composite(m2.darken(ic, 0.6) if dim else ic, (x + 3, y + 3))
    text(d, x + 31, y + 3, opt["name"], F12, light if st == "on" else (DIM if dim else INK))
    if st in ("on", "idle"):
        text(d, x + w - 4, y + 3, "사용 중" if st == "on" else "해금함", F12, light if st == "on" else MUTED, "ra")
    else:
        s = f"{cost:,}"
        tx = x + w - 4 - int(F12.getlength(s))
        text(d, tx, y + 3, s, F12, {"can": GOLD, "poor": "#f25c76"}.get(st, DIM))
        out.alpha_composite(mm.sprite("assets/sprites/run/mineral_3.png"), (tx - 14, y + 3))
    m2.para(d, x + 31, y + 18, opt["effect"], F12, DIM if dim else GOLD, w - 36, 1)
    return h


def popup_fork(c, b, i, levels, forks, side, press=False):
    """side = 누른 칸. 아래 버튼은 누른 쪽 상태를 따른다"""
    tree = TREE[b]
    n = tree[i]
    w = FORK_POP_W[c.kind]
    bh = 44 if c.kind == "phone" else 26
    guide = m2.wrap(FORK_GUIDE, F12, w - 24)
    h = 10 + 16 + len(guide) * 14 + 6 + 2 * (58 + 4) + 18 + bh + 12
    out = plate(c, "tab", w, h)
    d = draw(out)
    x, y = 12, 10
    light = BRANCH[b][1]
    text(d, x, y, "갈림길", F12, light)
    y = m2.para(d, x, y + 16, FORK_GUIDE, F12, MUTED, w - 24, 0) + 6
    for sd in "ab":
        y += fork_card(c, out, x, y, w - 25, n[sd], n["cost"], b, fork_state(tree, i, sd, b, levels, forks), sd == side) + 4
    st = fork_state(tree, i, side, b, levels, forks)
    by = h - bh - 12
    if st == "on":  # 버튼이 아니라 표시
        d.rectangle((x, by, x + w - 25, by + bh - 1), fill=DARK, outline=light)
        text(d, x + (w - 24) // 2, by + (bh - 16) // 2, "사용 중", F12, light, "ma")
    elif st == "idle":
        out.alpha_composite(mm.button(c, w - 24, bh, "이걸로 바꾸기", "down" if press else "up"), (x, by))
    elif st == "locked":
        text(d, x, by - 15, "먼저: " + prev_name(b, i), F12, "#dc7f47", limit=w - 22)
        out.alpha_composite(mm.button(c, w - 24, bh, "잠김", "off"), (x, by))
    else:
        if st == "poor":
            text(d, x, by - 15, "광물이 모자라요", F12, "#f25c76")
        out.alpha_composite(mm.button(c, w - 24, bh, "해금", "off" if st == "poor" else "up", f"{n['cost']:,}"), (x, by))
    return out


def popup_pos(cell, size, cw, ch, side="c"):
    """칸 옆(오른쪽 먼저, 안 들어가면 왼쪽). 갈림길은 바깥쪽: 반대쪽 칸과 자기 이름을 가리지 않게. 위아래는 판 안으로 밀어 넣는다"""
    x, y = cell
    w, h = size
    gap = SOCK_W // 2 + 8
    if side == "a":
        px = x - FORK_POP_GAP - w
    elif side == "b":
        px = x + FORK_POP_GAP
    else:
        px = x + gap if x + gap + w <= cw - 4 else x - gap - w
    py = min(max(y - h // 2, 4), ch - h - 4)
    return px, py


def check_popups(c):
    """모든 가지·칸·끌기 끝에서 창이 판 안에 있고 누른 칸을 가리지 않는지"""
    cw, ch = board_size(c)
    for b in TAB_ORDER:
        tree = TREE[b]
        lay = layout(tree, cw, ch)
        for pan in (0, lay["max_pan"]):
            for (i, side), (x, y) in lay["cells"].items():
                im = popup_fork(c, b, i, LEVELS, FORKS, side) if side != "c" else popup_node(c, b, i, LEVELS, FORKS)
                px, py = popup_pos((x, y + pan), im.size, cw, ch, side)
                assert 0 <= px and px + im.width <= cw and 0 <= py and py + im.height <= ch, f"창이 판 밖 {b} {i} {side} {c.kind}"
                assert px >= x + SOCK_W // 2 or px + im.width <= x - SOCK_W // 2, f"창이 칸을 가림 {b} {i} {side} {c.kind}"
                if side != "c":  # 자기 이름과 반대쪽 칸도 보여야 한다
                    half = int(F12.getlength(tree[i][side]["name"])) // 2
                    assert px >= x + half or px + im.width <= x - half, f"창이 이름을 가림 {b} {i} {side} {c.kind}"
                    other = lay["cells"][(i, "b" if side == "a" else "a")][0]
                    assert px >= other + SOCK_W // 2 or px + im.width <= other - SOCK_W // 2, f"창이 반대쪽 칸을 가림 {b} {i} {side} {c.kind}"


def shot(c, b, name, levels=LEVELS, forks=FORKS, sel=None, pan=0, debug=False, pop=None, locked=()):
    layer, body = mm.window(c, "research")
    tabs(c, layer, body, b, levels, forks, locked)
    cv = board(c, b, levels, forks, sel, pan, debug)
    if sel is not None and pop is not None:
        cw, ch = cv.size
        x, y = layout(TREE[b], cw, ch)["cells"][sel]
        cv.alpha_composite(pop, popup_pos((x, y + pan), pop.size, cw, ch, sel[1]))
    layer.alpha_composite(cv, (body[0] + TAB_W, body[1]))
    th = body[3] // len(TAB_ORDER)  # 고른 탭과 판 사이 선을 지워 이어 붙인다
    ty = body[1] + TAB_ORDER.index(b) * th
    draw(layer).rectangle((body[0] + TAB_W - 2, ty + 2, body[0] + TAB_W + 1, ty + th - 5), fill=DARK)
    tag = "pc_1280x720" if c.kind == "pc" else "phone_844x390"
    mm.compose(c, layer, 0, 1, 0).save(f"{OUT}{name}_{tag}.png")


def main():
    parts = m2.load_parts2()
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        cw, ch = board_size(c)
        for part in ("socket_on", "socket_off", "socket_lock"):
            assert parts[part].width == SOCK_W and parts[part].height % 2 == 0 and parts[part].height <= SOCK_H, part  # 폭이 같고 높이가 짝수라 그린 중심이 격자 위
        self_test(cw, ch)
        for b in TAB_ORDER:
            check_layout(TREE[b], layout(TREE[b], cw, ch), cw)
        check_popups(c)
        L, F = LEVELS, FORKS
        for b in TAB_ORDER:
            shot(c, b, f"tab_{b}")
            shot(c, b, f"grid_{b}", debug=True)
        max_pan = layout(TREE["mine"], cw, ch)["max_pan"]
        print(kind, "판", cw, ch, "채굴 끌기", max_pan, "4줄 끌기", layout(TREE["hull"], cw, ch)["max_pan"])
        shot(c, "mine", "mine_dragged_top", pan=max_pan)
        shot(c, "mine", "grid_mine_dragged_top", pan=max_pan, debug=True)
        shot(c, "hull", "tab_locked_look", locked=("survey", "elec"))  # 생김새 확인용. 지금 잠긴 가지는 없음
        # 칸 누른 상태
        for name, b, i, pan in (("press_can", "mine", 1, 0), ("press_poor", "weapon", 0, 0), ("press_max", "hull", 0, 0), ("press_locked", "mine", 2, 0), ("press_soon", "weapon", 1, 0), ("press_step", "elec", 0, 0), ("press_top_dragged", "mine", 4, max_pan)):
            shot(c, b, name, sel=(i, "c"), pan=pan, pop=popup_node(c, b, i, L, F))
        # 갈림길 상태: 해금 전 → 하나 해금 → 둘 다 해금 → 바꾸기
        fi = next(i for i, n in enumerate(TREE["hull"]) if is_fork(n))
        one = dict(L, insurance=1)  # 바로 앞 칸(화물 회수 신호기) 1단계: 갈림길이 열린 표본
        F1 = {"hull": {"on": "a", "owned": "a"}}
        F2 = {"hull": {"on": "a", "owned": "ab"}}
        F3 = {"hull": {"on": "b", "owned": "ab"}}

        def fork_shot(name, forks, side=None, press=False):
            sel = (fi, side) if side else None
            pop = popup_fork(c, "hull", fi, one, forks, side, press) if side else None
            shot(c, "hull", name, one, forks, sel=sel, pop=pop)

        fork_shot("fork1_before", {})
        fork_shot("fork1_before_press", {}, "a")
        fork_shot("fork2_one", F1)
        fork_shot("fork2_one_press_on", F1, "a")
        fork_shot("fork2_one_press_other", F1, "b")
        fork_shot("fork3_both", F2)
        fork_shot("fork3_both_press_on", F2, "a")
        fork_shot("fork3_both_press_off", F2, "b")
        fork_shot("fork4_swap_pressing", F2, "b", press=True)
        fork_shot("fork4_swapped", F3)
        fork_shot("fork4_swapped_press_on", F3, "b")
        credits = mm.CREDITS
        mm.CREDITS = 100
        fork_shot("fork_poor", {}, "a")
        mm.CREDITS = credits
        wi = next(i for i, n in enumerate(TREE["weapon"]) if is_fork(n))
        shot(c, "weapon", "fork_locked", sel=(wi, "a"), pop=popup_fork(c, "weapon", wi, L, F, "a"))
    warns = sorted(set(mm.WARN))
    for w in warns:
        print(w)
    assert not warns, "글자 넘침"
    print("시안 저장. 격자·대칭·겹침·창 위치 검사 통과")


if __name__ == "__main__":
    main()
