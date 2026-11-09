"""v0.7.0 건물 창 시안 3차 (게임에 적용하지 않음). 2차(review/v070_fix2/make_mockups2.py)를 불러와 바뀌는 곳만 덮어쓴다.
1) 격납고: 눕힌 우주선 + 카메라 30~40도 회전 시트, 무기 아이콘 2배 2) 연구소: 넉넉한 간격, 결정된 이름·순서 3) 전시관: 못 찾은 칸 어둡게, 등급 색은 틀 자체에.
실행: 저장소 맨 위에서 python3 review/v070_fix3/make_mockups3.py [hangar research museum] (이름을 안 주면 전부)"""
import sys

import numpy as np
from PIL import Image

sys.path[:0] = ["review/v070_fix2"]
import make_mockups2 as m2  # noqa: E402
from make_mockups2 import BRANCH, DARK, F12, F24, GOLD, INK, MUTED, ORDER, P, FORK, RANKS, RANK_OF, SAMPLE, SHORT_NAME, TEAL, TEAL2, DIM, cut, darken, draw, mm, plate, rgb, silhouette, text, tint  # noqa: E402

OUT = "review/v070_fix3/"
m2.OUT = OUT


# ── 결정된 이름과 순서 (2026-11-09 사용자) ──────────────
mm.NODE_NAME.update({"damage": "펄스 증폭기", "max_hp": "격벽 보강", "insurance": "화물 회수 신호기", "speed": "분사 노즐 개조", "cargo": "화물 베이 확장", "magnet": "자기장 포집기"})
TREE = dict(m2.TREE)
TREE["mine"] = ["magnet", "cargo", "speed", TREE["mine"][3], TREE["mine"][4]]  # 싼 순서: 자석 → 화물칸 → 이동 속도
for b in TREE:
    for n in TREE[b]:
        if isinstance(n, dict) and "tag" in n:
            n["tag"] = "곧 추가" if n["id"] in ("sub", "planet") else ""
m2.TREE = TREE
m2.PROPOSAL = DIM  # 결정된 칸이라 제안 주황을 쓰지 않는다
mm.TREE = TREE
LEVELS = dict(SAMPLE, magnet=1, cargo=0, speed=0, damage=3, max_hp=5, insurance=1)  # 표본: 자석 1 (순서가 바뀌어 맨 앞 칸을 찍은 상태)


# ── 연구소 간격 ───────────────────────────────────
PITCH = {"pc": 184, "phone": 184}  # 가지 사이: 왼쪽 갈림길 이름 ~ 오른쪽 이름까지(170칸)에 빈 칸 14칸
STEP = {"pc": 68, "phone": 68}  # 칸 사이 (소켓 46칸 + 22칸)
FORK_DX = 92  # 갈림길 두 소켓 사이 (이름 폭 68칸 + 24칸)
FORK_EXTRA = 26  # 갈림길은 소켓 아래 이름이 있어 더 띄운다
FIRST_UP = 46  # 코어 줄에서 첫 칸까지
BAND = 32  # 아래 가지 이름표 띠. 칸이 이 띠 아래로 지나가 글자가 겹치지 않는다


def positions(c, cw, ch):
    """가운데 선체 열 아래 코어. 처음 화면은 코어와 가까운 칸이 보이고 나머지는 끌어서 본다"""
    pitch, step = PITCH[c.kind], STEP[c.kind]
    hull_x = cw // 2 + 6  # 코어가 화면 가운데. PC는 무기·선체가 다 보이고 채굴은 소켓이 걸쳐 더 있다는 걸 알린다
    core = (hull_x, ch - BAND - 32)
    colx = {b: hull_x + (i - 2) * pitch for i, b in enumerate(ORDER)}
    pos = {}
    for b in ORDER:
        y = core[1] - (FIRST_UP + 22 if b == "hull" else FIRST_UP)
        for i, n in enumerate(TREE[b]):
            if isinstance(n, dict) and n.get("fork"):
                y -= FORK_EXTRA
            pos[(b, i)] = (colx[b], y)
            y -= step
    return core, colx, pos


def fork_xy(p):
    return (p[0] - 16, p[1]), (p[0] - 16 + FORK_DX, p[1])


m2.positions = positions
m2.fork_xy = fork_xy


def label_of(n):
    return mm.NODE_NAME[n] if isinstance(n, str) else n["name"]


def layout_rects(cw=420, ch=300, kind="pc"):
    """칸마다 (이름, 사각형)을 낸다. 소켓 46칸, 이름은 오른쪽(갈림길은 아래)에 놓인다"""
    class C:
        pass
    c = C()
    c.kind = kind
    _, _, pos = positions(c, cw, ch)
    rects = []
    for b in ORDER:
        for i, n in enumerate(TREE[b]):
            p = pos[(b, i)]
            if isinstance(n, dict) and n.get("fork"):
                for side, q in zip("ab", fork_xy(p)):
                    w = F12.getlength(n[side]["name"])
                    rects.append((b, n[side]["name"], (q[0] - 23, q[1] - 23, q[0] + 23, q[1] + 23)))
                    rects.append((b, n[side]["name"] + " 글자", (q[0] - w / 2, q[1] + 21, q[0] + w / 2, q[1] + 34)))
            else:
                w = F12.getlength(label_of(n))
                rects.append((b, label_of(n), (p[0] - 23, p[1] - 23, p[0] + 23, p[1] + 23)))
                rects.append((b, label_of(n) + " 글자", (p[0] + 26, p[1] - 13, p[0] + 26 + w, p[1] + 16)))
    return rects


def overlaps():
    """소켓·글자끼리 겹치거나 12칸 안으로 붙은 쌍. 같은 칸의 소켓과 글자는 원래 붙어 있어 뺀다"""
    bad = []
    rects = layout_rects()
    for i, (b1, n1, a) in enumerate(rects):
        for b2, n2, r in rects[i + 1:]:
            if n1.replace(" 글자", "") == n2.replace(" 글자", ""):
                continue
            if b1 != b2:  # 다른 가지는 12칸, 같은 가지는 닿지만 않으면 된다
                g = 12
            else:
                g = 0
            if a[0] < r[2] + g and r[0] < a[2] + g and a[1] < r[3] and r[1] < a[3]:
                bad.append((n1, n2))
    return bad


def research_body(c, body, levels, forks, sel, pulse=0.0, pan=(0, 0), press=None, flash=None, close_t=1.0, hint=True, pick=None):
    """2차 그림을 그대로 쓰고 위쪽 칸 안내만 더한다"""
    canvas, panel = ORIG_BODY(c, body, levels, forks, sel, pulse, pan, press, flash, close_t, False, pick)
    d = draw(canvas)
    cw, ch = canvas.size
    d.rectangle((0, ch - BAND, cw, ch), fill=DARK)
    d.line((0, ch - BAND, cw, ch - BAND), fill="#3c3544")
    _, colx, _ = positions(c, cw, ch)
    for b in ORDER:  # 이름표는 가지 칸 아래에서 좌우로만 판과 함께 움직인다
        x = colx[b] + pan[0]
        if 8 <= x <= cw - 8:
            w = 18 + int(F12.getlength(SHORT_NAME[b]))
            hx = min(max(x - w // 2, 2), cw - w - 2)
            mm.clip_paste(canvas, c.p["emblem"][b], hx, ch - BAND + 2)
            text(d, hx + 18, ch - BAND + 3, SHORT_NAME[b], F12, BRANCH[b][1])
        elif x < 8:  # 화면 밖 가지는 가장자리에 이름으로 (가까운 가지가 위에 그려지게 순서대로 덮는다)
            d.rectangle((0, ch - 15, F12.getlength("◀ " + SHORT_NAME[b]) + 5, ch - 1), fill=DARK)
            text(d, 2, ch - 15, "◀ " + SHORT_NAME[b], F12, BRANCH[b][1])
    for b in reversed(ORDER):
        x = colx[b] + pan[0]
        if x > cw - 8:
            s = SHORT_NAME[b] + " ▶"
            d.rectangle((cw - F12.getlength(s) - 5, ch - 15, cw - 1, ch - 1), fill=DARK)
            text(d, cw - 2, ch - 15, s, F12, BRANCH[b][1], "ra")
    if hint:  # 안내는 띠 안에 있어 칸을 가리지 않는다. 위에 칸이 더 있으면 화살표를 붙인다
        top = min(v[1] for v in positions(c, cw, ch)[2].values()) + pan[1]
        text(d, cw // 2, ch - 15, ("▲ " if top < 24 else "") + "끌어서 둘러보기", F12, MUTED, "ma")
    return canvas, panel


ORIG_BODY = m2.research_body
m2.research_body = research_body


def summary_panel(c, out, w, h, levels):
    """2차 요약에서 "제안" 글자만 뺀다: 새 가지도 이제 실제 칸"""
    d = draw(out)
    f, big = c.s["small"], c.s["big"]
    x, y = 12, 14
    text(d, x, y, "연구 코어", big, TEAL2)
    y = m2.para(d, x, y + big.size + 4, "강화를 찍으면 코어에서 가지로 빛이 번져요.", f, INK, w - 24) + 6
    for b in ("weapon", "hull", "mine", "elec", "survey"):
        out.alpha_composite(c.p["emblem"][b], (x, y))
        text(d, x + 18, y + 1, SHORT_NAME[b], f, BRANCH[b][1])
        done = sum(levels.get(n, 0) for n in TREE[b] if isinstance(n, str))
        total = 5 * sum(isinstance(n, str) for n in TREE[b])
        bx0, bx1 = x + 50, w - 54
        d.rectangle((bx0, y + 4, bx1, y + 10), fill=DARK)
        d.rectangle((bx0 + 1, y + 5, bx1 - 1, y + 9), fill="#3c3544")
        if total:
            d.rectangle((bx0 + 1, y + 5, bx0 + 1 + (bx1 - bx0 - 2) * done // total, y + 9), fill=BRANCH[b][1])
            text(d, w - 12, y + 1, f"{done}/{total}", f, INK, "ra")
        y += 19
    note = m2.wrap("칸을 눌러 효과와 가격을 봐요.", f, w - 24)
    m2.para(d, x, h - len(note) * (f.size + 2) - 16, " ".join(note), f, MUTED, w - 24)


m2.summary_panel = summary_panel


def detail_panel(c, w, h, sel, levels, forks, press=None, pick=None):
    """갈림길은 고르기·바꾸기 모두 무료(2026-11-09 결정). 나머지 칸은 2차 그대로"""
    if sel is None or not (isinstance(sel[1], dict) and sel[1].get("fork")):
        return ORIG_DETAIL(c, w, h, sel, levels, forks, press, pick)
    branch, node = sel
    out = plate(c, "tab", w, h)
    d = draw(out)
    f, big = c.s["small"], c.s["big"]
    x, y = 12, 14
    bh = 44 if c.kind == "phone" else 26
    by = h - bh - 12
    st = "chosen" if branch in forks else m2.fork_state(branch, TREE[branch].index(node), levels, forks)
    text(d, x, y - 1, "갈림길", big, BRANCH[branch][1])
    y += big.size + 2
    text(d, x, y, "둘 중 하나만 고를 수 있어요", f, INK, limit=w - 22)
    y += 18
    for side in "ab":
        state = ("pick" if pick == side else "open") if st != "chosen" else ("on" if forks[branch] == side else "off")
        y += m2.option_card(c, out, x, y, w - 25, node[side], branch, state) + 4
    if st == "chosen":
        text(d, x, by - 15, "언제든 무료로 바꿀 수 있어요", f, MUTED, limit=w - 22)
        out.alpha_composite(mm.button(c, w - 24, bh, "바꾸기 (무료)", "up"), (x, by))
    elif st == "open":
        text(d, x, by - 15, "위 칸을 눌러 고른 뒤 확정" if pick is None else node[pick]["name"] + " 으로 확정", f, MUTED if pick is None else INK, limit=w - 22)
        out.alpha_composite(mm.button(c, w - 24, bh, "고르기 (무료)", "off" if pick is None else "up"), (x, by))
    else:
        text(d, x, by - 15, "앞 칸을 찍으면 열려요", f, MUTED, limit=w - 22)
        out.alpha_composite(mm.button(c, w - 24, bh, "잠김", "off"), (x, by))
    return out


ORIG_DETAIL = m2.detail_panel
m2.detail_panel = detail_panel


def pans(c):
    """둘러볼 지점들: 왼쪽 가지, 오른쪽 가지, 맨 위"""
    p = PITCH[c.kind]
    return {"left": (p, 0), "far_left": (2 * p, 40), "right": (-p, 0), "far_right": (-2 * p, 40), "up": (0, 130)}


def make_research(parts):
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        fk = m2.fork("hull")
        shots = {"research_start": m2.research(c, LEVELS, pulse=0.8)}
        for name, pan in pans(c).items():
            shots[f"research_drag_{name}"] = m2.research(c, LEVELS, pulse=0.8, pan=pan)
        shots["research_fork"] = m2.research(c, LEVELS, sel=("hull", fk), pulse=0.8, pan=(0, 80))
        shots["research_fork_chosen"] = m2.research(c, LEVELS, {"hull": "b"}, sel=("hull", fk), pulse=0.8, pan=(0, 80))
        shots["research_all_chosen_up"] = m2.research(c, dict(m2.DEMO_LEVELS, magnet=2, cargo=1, speed=1), m2.DEMO_FORKS, pulse=0.8, pan=(0, 130))
        for name, layer in shots.items():
            mm.compose(c, layer, 0, 1, 0).save(f"{OUT}{name}_{tag}.png")
        # 끌어서 둘러보는 움직임
        frames, durs = [], []
        pl = pans(c)
        route = [(0, 0), pl["up"], (PITCH[kind], 130), pl["far_left"], pl["left"], (0, 0), pl["right"], pl["far_right"], (0, 0)]
        for a, b in zip(route, route[1:]):
            n = max(abs(b[0] - a[0]), abs(b[1] - a[1])) // 18 + 1
            for t in range(n):
                pan = (a[0] + (b[0] - a[0]) * t // n, a[1] + (b[1] - a[1]) * t // n)
                frames.append(mm.compose(c, m2.research(c, LEVELS, pulse=0.8, pan=pan), 0, 1, 0))
                durs.append(50)
            frames.append(mm.compose(c, m2.research(c, LEVELS, pulse=0.8, pan=b), 0, 1, 0))
            durs.append(500)
        save_gif(frames, durs, f"research_drag_{kind}.gif")


def save_gif(frames, durs, name):
    m2.OUT = OUT
    m2.save_gif(frames, durs, name)


# ── 전시관 ────────────────────────────────────
FRAME_BAND = 8  # 진열장 그림 바깥에서 이만큼이 틀. 안쪽 장면은 건드리지 않는다
# 등급마다 틀 색 (어두운 → 밝은). 색이 틀 전체에 입혀져 칸 하나만 봐도 등급이 보인다
FRAME_RAMP = {
    "common": ("#3c3544", "#5c5164", "#917487", "#a5b29d"),
    "rare": ("#3c3544", "#4d80cd", "#4d80cd", "#99e9e6"),
    "epic": ("#3a1c57", "#6b3e75", "#a884f3", "#a884f3"),
    "legend": ("#984633", "#f89419", "#f6ce50", "#fef8e5"),
    "elite": ("#6f2626", "#984633", "#dc7f47", "#f89419"),
    "boss": ("#6f2626", "#cb3738", "#f25c76", "#f25c76"),
}


def recolor_frame(im, ramp):
    """밝기 순서대로 틀 칸을 등급 색으로 바꾼다. 안쪽 장면과 검은 윤곽은 그대로"""
    a = np.array(im.convert("RGBA"))
    h, w = a.shape[:2]
    band = np.zeros((h, w), bool)
    top = 6  # 위쪽 등 고정쇠 자리만큼 내려서 시작
    band[top:top + FRAME_BAND, :] = band[h - FRAME_BAND:, :] = True
    band[:, :FRAME_BAND] = band[:, w - FRAME_BAND:] = True
    band[:top] = True
    lum = a[..., :3].astype(int).sum(axis=2)
    cuts = (150, 260, 420)  # 어두움, 중간, 밝음, 아주 밝음의 경계 (R+G+B)
    level = np.digitize(lum, cuts)
    keep = (a[..., 3] == 0) | (lum < 40) | ~band
    out = a.copy()
    for i, col in enumerate(ramp):
        out[(level == i) & ~keep, :3] = rgb(col)
    return Image.fromarray(out, "RGBA")


def case_for(c, rank):
    return recolor_frame(ORIG_CASE(c, rank), FRAME_RAMP[rank])


ORIG_CASE = m2.case_for
m2.case_for = case_for


def case_deco(d, kx, ky, w, h, rank):
    """얇은 바깥 줄은 없애고, 색을 못 읽는 사람을 위한 모양 구분만 남긴다: 영웅 이상은 모서리 징, 전설·보스는 뿔"""
    _, main, light, _, deco = RANKS[rank]
    if deco >= 2:
        for x, y in ((kx - 2, ky + 4), (kx + w - 1, ky + 4), (kx - 2, ky + h - 1), (kx + w - 1, ky + h - 1)):
            d.rectangle((x, y, x + 2, y + 2), fill=light)
    if deco >= 3:
        for x, sx in ((kx - 2, -1), (kx + w + 1, 1)):
            d.polygon([(x, ky + 12), (x, ky + 22), (x + 3 * sx, ky + 17)], fill=light)


m2.case_deco = case_deco


def dark_case(parts):
    """못 찾은 칸: 불 꺼진 어두운 진열장. 청록 발광선도 꺼서 찾은 칸보다 눈에 안 띄게"""
    a = np.array(parts["case_off"].convert("RGBA"))
    lum = a[..., :3].astype(int).sum(axis=2)
    a[(lum >= 150) & (a[..., 3] > 0), :3] = rgb("#3c3544")  # 틀·받침·발광선을 모두 한 가지 어두운 색으로
    a[(lum >= 420) & (a[..., 3] > 0), :3] = rgb("#5c5164")  # 가장 밝던 모서리만 한 단계 밝게 남겨 틀 모양을 살린다
    return Image.fromarray(a, "RGBA")


def make_museum(parts):
    p = dict(parts)
    p["case_off"] = dark_case(parts)
    for kind in ("pc", "phone"):
        c = mm.Ctx(p, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        mm.compose(c, m2.museum(c), 0, 1, 0).save(f"{OUT}museum_{tag}.png")
        mm.compose(c, m2.museum(c, m2.ALL_FOUND, sel="mineral_3", claimed=(3, 6, 9)), 0, 1, 0).save(f"{OUT}museum_full_{tag}.png")


# ── 격납고 ────────────────────────────────────
ELEVS = (30, 35, 40)
CHOSEN = 35  # 비교 뒤 시안에 넣는 각도. 받침 그림이 이 각도로 그려졌다
SHEETS = {e: Image.open(f"{OUT}spin3d/spin_e{e}.png").convert("RGBA") for e in ELEVS}
SPIN_W, SPIN_H = 64, 56
PED_RAW = "assets/raw/base_panel3/pedestal_35b.png"


def load_pedestal(parts):
    """35도로 새로 그린 받침. 격자는 2차와 같은 88칸 폭"""
    raw = Image.open(PED_RAW)
    box = mm.objects(raw)
    box = max(box, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
    return m2.despill(cut(raw, box, 88))  # 2차 받침과 같은 칸 폭


def ring_rows(ped):
    """가운데 세로줄에서 윗면 고리의 위·아래 줄을 잰다 (비율 계산과 그림자 자리에 쓴다)"""
    a = np.array(ped.convert("RGBA")).astype(int)
    mid = a[:, ped.width // 2 - 3: ped.width // 2 + 3]
    teal = (mid[..., 1] > 170) & (mid[..., 0] < 120) & (mid[..., 3] > 0)
    rows = np.where(teal.any(axis=1))[0]
    runs = np.split(rows, np.where(np.diff(rows) > 1)[0] + 1)
    return int(runs[0][0]), int(runs[1][0])


def ped_for(parts, elev):
    """각도별 받침: 고리 타원 비율이 sin(각도)가 되게, 칸 격자 그대로 세로 칸만 솎거나 늘린다"""
    ped = parts["pedestal35"]
    top, bot = ring_rows(ped)
    ratio = (bot - top) / (ped.width - 12)
    k = np.sin(np.radians(elev)) / ratio
    return ped.resize((ped.width, round(ped.height * k)), Image.NEAREST)


def spin_frame(elev, i):
    sheet = SHEETS[elev]
    j = (i % 120) * 40 // 120
    return sheet.crop((j % 8 * SPIN_W, j // 8 * SPIN_H, (j % 8 + 1) * SPIN_W, (j // 8 + 1) * SPIN_H))


def ship_shadow(elev, i):
    """받침 면에 떨어지는 그림자: 우주선 윤곽을 같은 각도로 돌려 납작하게. 몸체와 함께 돌아 눕혀진 것이 읽힌다"""
    s = Image.open(f"{OUT}spin3d/ship.png").convert("RGBA").getchannel("A").point(lambda v: 255 if v > 128 else 0)
    r = s.rotate((i % 120) / 120 * 360, Image.NEAREST)  # 시트와 같은 방향
    r = r.resize((r.width, max(1, round(r.height * np.sin(np.radians(elev))))), Image.NEAREST)
    r = r.crop(r.getbbox())
    out = Image.new("RGBA", r.size, (*rgb("#14111c"), 0))
    out.paste((*rgb("#14111c"), 255), (0, 0), r)
    return out


def stage(c, canvas, x, y, w, h, stand, elev, i):
    """받침 위에 우주선을 눕혀 띄운다. 그림자는 받침 면에, 우주선은 바로 위에"""
    d = draw(canvas)
    k = m2.MODEL_K[c.kind]
    cx = x + w // 2
    ped = ped_for(c.p, elev)
    ped = ped.resize((ped.width * 2, ped.height * 2), Image.NEAREST)
    px, py = cx - ped.width // 2, y + h - ped.height - 2
    top, bot = ring_rows(ped)
    pmid = py + (top + bot) // 2  # 윗면 타원 가운데
    for rx, col in ((ped.width // 2 + 14, "#2b1925"), (ped.width // 2 + 26, "#2b1925")):  # 바닥에 퍼지는 고리
        d.ellipse((cx - rx, pmid + 16 - int(rx * np.sin(np.radians(elev))), cx + rx, pmid + 16 + int(rx * np.sin(np.radians(elev)))), outline=col)
    canvas.alpha_composite(ped, (px, py))
    # 빛기둥: 점 줄무늬로 위로 사라진다. 아래쪽은 윗면 타원을 따라 둥글게 끝난다
    rx, ry = (ped.width - 28) / 2, (bot - top) / 2 - 3
    for yy in range(py + bot - 4, y + 6, -3):
        t = max(pmid - yy, 0) / max(pmid - y - 6, 1)
        half = int((ped.width // 2 - 24) * (1 - 0.25 * t))
        if yy > pmid:
            half = min(half, int(rx * np.sqrt(max(1 - ((yy - pmid) / ry) ** 2, 0))))
        step = 2 + int(t * 7)
        off = (i // 2 + yy) % step
        for xx in range(cx - half + off, cx + half, step):
            d.point((xx, yy), fill=("#1da775" if t < 0.5 else "#125952"))
    # 그림자: 받침 면에 붙어 우주선과 함께 돈다
    sh = ship_shadow(elev, i)
    sh = sh.resize((sh.width * k, sh.height * k), Image.NEAREST)
    mm.clip_paste(canvas, sh, cx - sh.width // 2, pmid - sh.height // 2 + 2)
    sp = spin_frame(elev, i)
    sp = sp.resize((sp.width * k, sp.height * k), Image.NEAREST)
    mm.clip_paste(canvas, sp, cx - sp.width // 2, pmid - 34 - sp.height // 2 + m2.bob(i))


def weapon_block(c, out, x, y, w, weapon, font, gap=2):
    """무기 아이콘 2배: 이름은 아이콘 오른쪽 가운데"""
    icon, name, desc, tag = weapon
    d = draw(out)
    ic = c.p["ic"][icon]
    ic = ic.resize((ic.width * 2, ic.height * 2), Image.NEAREST)
    out.alpha_composite(ic, (x, y))
    text(d, x + ic.width + 6, y + (ic.height - font.size) // 2 - 1, name, font, TEAL2, limit=w - ic.width - 6)
    return m2.para(d, x, y + ic.height + 3, desc, font, INK, w, gap)


def desc_panel(c, w, h, fighter):
    """2차와 같고 "제안" 표시만 뺀다"""
    out = plate(c, "tab", w, h)
    d = draw(out)
    f = F24 if c.kind == "phone" else F12
    x, y, tw = 12, 12, w - 24
    text(d, x, y, fighter["name"], f, GOLD)
    text(d, w - 12, y, fighter["style"], f, TEAL2, "ra")
    y = m2.para(d, x, y + f.size + 4, m2.PLAY[fighter["id"]], f, INK, tw) + 6
    d.line((x, y, w - 13, y), fill="#3c3544")
    y += 6
    text(d, x, y, "기본 무기", F12, MUTED)
    y = weapon_block(c, out, x, y + 15, tw, m2.WEAPONS[0], f)
    if y > h - 8:
        mm.WARN.append(f"설명 칸 넘침 {c.kind}: {y} > {h - 8}")
    return out


m2.weapon_block = weapon_block
m2.desc_panel = desc_panel
m2.stage = stage


def make_hangar(parts):
    parts = dict(parts)
    parts["pedestal35"] = load_pedestal(parts)
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        mm.compose(c, m2.hangar(c, "holo", CHOSEN, 0), 0, 1, 0).save(f"{OUT}hangar_{tag}.png")
        mm.compose(c, m2.hangar(c, "holo", CHOSEN, 30), 0, 1, 0).save(f"{OUT}hangar_side_{tag}.png")
        frames = [mm.compose(c, m2.hangar(c, "holo", CHOSEN, i), 0, 1, 0) for i in range(0, 120, 2)]
        save_gif(frames, [100] * len(frames), f"hangar_spin_{kind}.gif")
    # 각도 비교: 무대만 나란히, 초당 20장
    c = mm.Ctx(parts, "pc")
    W, H = 240, 230
    frames = []
    for i in range(120):
        row = Image.new("RGBA", (W * len(ELEVS), H), (*rgb("#2b1925"), 255))
        for n, e in enumerate(ELEVS):
            stage(c, row, n * W, 0, W, H, "holo", e, i)
            text(draw(row), n * W + 8, 4, f"카메라 {e}도", F12, TEAL2)
        frames.append(row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert("RGB"))
    save_gif(frames, [50] * len(frames), "hangar_tilt_compare.gif")
    # 두께 확인: 정면·옆·뒤를 각도별로 멈춰서
    views = [("뒤", 0), ("비스듬", 15), ("옆", 30), ("앞 비스듬", 45), ("앞", 60)]
    sheet = Image.new("RGBA", (len(views) * 140, len(ELEVS) * 126 + 20), (*rgb("#2b1925"), 255))
    for n, (name, i) in enumerate(views):
        text(draw(sheet), n * 140 + 50, 3, name, F12, TEAL2)
        for r, e in enumerate(ELEVS):
            sp = spin_frame(e, i)
            sp = sp.resize((sp.width * 2, sp.height * 2), Image.NEAREST)
            sheet.alpha_composite(sp, (n * 140 + 6, 20 + r * 126))
    for r, e in enumerate(ELEVS):
        text(draw(sheet), 4, 24 + r * 126, f"{e}도", F12, INK)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).convert("RGB").save(f"{OUT}hangar_thickness.png")


SECTIONS = {"hangar": make_hangar, "research": make_research, "museum": make_museum}


def sanity():
    bad = overlaps()
    assert not bad, bad
    assert [n for n in TREE["mine"] if isinstance(n, str)] == ["magnet", "cargo", "speed"]
    assert mm.node_state("cargo", "mine", {"cargo": 2}) != "locked"  # 옛 저장: 앞 칸 없이 올린 칸은 잠그지 않음
    assert mm.node_state("speed", "mine", {"magnet": 1}) == "locked"


def main():
    sanity()
    parts = m2.load_parts2()
    for name in sys.argv[1:] or SECTIONS:
        SECTIONS[name](parts)
    for w in sorted(set(mm.WARN)):
        print(w)
    print("시안 저장. 글자 넘침", len(set(mm.WARN)))


if __name__ == "__main__":
    main()
