"""v0.7.0 건물 창 시안 2차 (게임에 적용하지 않음). 1차(review/v070_fix/make_mockups.py)의 틀·부품을 그대로 가져다 쓰고 바뀐 화면만 그린다.
연구소 5가지·갈림길, 광물 더미, 전시관 등급 테두리·도감 보상, 격납고 회전 모형·설명 칸, 어두운 드론 설계도.
"제안" 표시가 있는 칸과 수치는 전부 시안용 예시이고 게임 로직에는 없다. 기존 강화 6개의 수치·가격은 data.json 그대로다.
실행: python3 review/v070_fix2/make_mockups2.py [research storage museum hangar drone] → review/v070_fix2/ 아래 png, gif (이름을 안 주면 전부)"""
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path[:0] = ["review/v070_fix"]
import make_mockups as mm  # noqa: E402
from make_mockups import BRANCH, CREDITS, DARK, DATA, F12, F24, GOLD, GREY, INK, MUTED, TEAL, TEAL2, WARN, cut, darken, draw, grid_boxes, plate, rgb, rim, silhouette, sprite, text, tint, window  # noqa: E402

OUT = "review/v070_fix2/"
RAW = "assets/raw/base_panel2/"
PROPOSAL = "#dc7f47"  # 제안 표시 색 (1차와 같음)
DIM = "#917487"

# ── 가지와 칸 ─────────────────────────────────
BRANCH.update({"elec": ("#6b3e75", "#a884f3"), "survey": ("#77931e", "#a5cc5f")})  # 빨강·파랑·금색과 안 겹치게 보라, 연두
mm.BRANCH_NAME.update({"elec": "전자 계통", "survey": "탐사 계통"})
SHORT_NAME = {"weapon": "무기", "hull": "선체", "mine": "채굴", "elec": "전자", "survey": "탐사"}
ORDER = ["elec", "weapon", "hull", "mine", "survey"]  # 왼쪽부터. 기존 3가지가 처음 화면에 보이게 새 가지는 바깥에


def P(pid, name, icon, desc, effect, cost, tag="제안"):
    """제안 칸: 수치·가격은 모두 예시"""
    return {"id": pid, "name": name, "icon": icon, "desc": desc, "effect": effect, "cost": cost, "tag": tag}


def FORK(cost, a, b):
    return {"fork": True, "cost": cost, "a": a, "b": b, "id": a["id"] + "_" + b["id"]}


TREE = {
    "weapon": ["damage", P("sub", "보조 무기 해금", "launcher", "보조 무기 칸을 열어요.", "보조 무기 칸 1개", 300, "v0.8.0 제안"),
               FORK(500, P("rapid", "연사형", "gatling", "더 자주, 더 약하게 쏴요.", "공격 속도 +15%, 공격력 -5%", 0), P("heavy", "한 방형", "heavy", "느리지만 묵직하게 쏴요.", "공격력 +25%, 공격 속도 -15%", 0)),
               P("over", "과부하 탄두", "overload", "가끔 아주 센 탄이 나가요.", "5발마다 공격력 2배 탄", 800)],
    "hull": ["max_hp", "insurance",
             FORK(500, P("thick", "중장갑", "thick", "무겁지만 더 버텨요.", "체력 +30, 이동 속도 -5%", 0), P("dodge", "회피형", "dodge", "맞은 뒤 더 오래 안전해요.", "피격 뒤 무적 +0.3초", 0)),
             P("repair", "긴급 수리", "repair", "위험할 때 스스로 고쳐요.", "판마다 1번 체력 30% 회복", 800)],
    "mine": ["speed", "cargo", "magnet",
             FORK(500, P("wide", "넓게 끌기", "wide", "더 멀리서 끌어와요.", "자석 범위 +40%", 0), P("fast", "빨리 나르기", "fast", "끌려오는 광물이 빨라져요.", "끌려오는 속도 +60%", 0)),
             P("drill", "정밀 드릴", "drill", "운석에서 조금 더 캐요.", "10% 확률로 광물 +1개", 800)],
    "elec": [P("shield", "편향 실드", "shield", "판마다 한 번 막아 줘요.", "단계마다 피해 막기 +1번", 200),
             P("reroll", "재추첨 회로", "reroll", "레벨업 카드를 더 뽑아요.", "단계마다 다시 뽑기 +1번", 250),
             FORK(500, P("chip", "고급 회로", "chip", "좋은 카드가 더 자주 나와요.", "에픽 이상 확률 +3%", 0), P("bolt", "실드 충전", "bolt", "막은 뒤 실드가 다시 차요.", "60초마다 실드 1번 충전", 0)),
             P("luck", "행운 코어", "luck", "가끔 카드가 더 나와요.", "10% 확률로 카드 1장 더", 800)],
    "survey": [P("appraise", "광물 감정기", "appraise", "같은 광물을 더 비싸게 팔아요.", "단계마다 광물 가치 +3%", 200),
               P("radar", "희귀 탐지기", "radar", "좋은 광물이 더 자주 나와요.", "단계마다 희귀 이상 확률 +1%", 250),
               FORK(500, P("deep", "심부 스캔", "deep", "더 귀한 광물을 찾아요.", "영웅·전설 확률 +2%", 0), P("wide_scan", "광역 스캔", "wide_scan", "멀리 있는 것도 보여요.", "레이더 범위 +30%", 0)),
               P("planet", "항로 개척", "planet", "새 행성으로 가는 길을 찾아요.", "행성 좌표 해금 (v0.9.0)", 800, "v0.9.0 제안")],
}
mm.TREE = TREE  # 1차의 잠금 규칙(node_state)이 실제 칸 순서를 여기서 읽는다
SWAP_COST = 150  # 갈림길 바꾸기 예시 가격 (제안)
SAMPLE = dict(DATA["sample"])


def despill(im):
    """마젠타 배경과 섞여 자홍이 된 가장자리 칸을 지운다"""
    a = np.array(im)
    for hexc in ("#861a59", "#ff2567", "#6b3e75", "#a884f3"):
        a[(a[..., :3] == rgb(hexc)).all(axis=2), 3] = 0
    return Image.fromarray(a, "RGBA")


def load_parts2():
    p = mm.load_parts()  # 1차 부품 (같은 원본에서 똑같이 다시 만듦)
    mm.OUT = OUT
    ic = {}
    raw = Image.open(RAW + "node_icons_a.png")
    names = ["em_elec", "em_survey", "shield", "reroll", "chip", "bolt", "luck", "appraise", "radar", "deep", "wide_scan", "planet", "launcher", "gatling", "heavy", "overload"]
    for n, b in zip(names, grid_boxes(raw, 4, 4)):
        ic[n] = cut(raw, b, 14 if n.startswith("em_") else 24)
    raw = Image.open(RAW + "node_icons_b.png")
    names = ["thick", "dodge", "repair", "wide", "fast", "drill", "w_pulse", "w_shot", "w_rail", "w_plasma", "w_beam", "crate"]
    for n, b in zip(names, grid_boxes(raw, 4, 3)):
        ic[n] = cut(raw, b, 36 if n.startswith("w_") else 24)  # 무기는 옆으로 길어 넓게
    p["ic"] = ic
    p["crate_s"] = cut(raw, grid_boxes(raw, 4, 3)[11], 14)
    raw = Image.open(RAW + "props.png")
    b = sorted(mm.objects(raw), key=lambda x: x[0])
    assert len(b) == 3, len(b)
    p["pedestal"], p["cradle"], p["cart"] = (despill(cut(raw, x, w)) for x, w in zip(b, (88, 112, 80)))
    p["emblem"] = dict(p["emblem"], elec=ic["em_elec"], survey=ic["em_survey"])
    return p


def wrap(s, font, width):
    """글자 폭에 맞춰 줄 나누기. 띄어쓰기에서 먼저 끊고 안 되면 글자에서 끊는다"""
    lines, cur = [], ""
    for word in s.split(" "):
        trial = (cur + " " + word).strip()
        if font.getlength(trial) <= width:
            cur = trial
            continue
        if cur:
            lines.append(cur)
        cur = ""
        for ch in word:
            if font.getlength(cur + ch) > width:
                lines.append(cur)
                cur = ""
            cur += ch
    return lines + [cur] if cur else lines


def para(d, x, y, s, font, color, width, gap=2):
    for ln in wrap(s, font, width):
        text(d, x, y, ln, font, color)
        y += font.size + gap
    return y


def ring(canvas, im, x, y, color, strength=1.0, reach=2):
    """그림 윤곽을 따라 번지는 빛. 칸이 격자에 맞게 알파 단계만 쓴다"""
    mask = im.getchannel("A").point(lambda v: 255 if v else 0)
    pad = reach + 1
    base = Image.new("L", (im.width + 2 * pad, im.height + 2 * pad), 0)
    base.paste(mask, (pad, pad))
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for i in range(reach, 0, -1):
        grown = base
        for _ in range(i):
            grown = grown.filter(ImageFilter.MaxFilter(3))
        a = int((110 if i == 1 else 50) * strength)
        out.paste((*rgb(color), a), (0, 0), grown)
    mm.clip_paste(canvas, out, x - pad, y - pad)


# ── 연구소 ────────────────────────────────────
def node_lv(n, levels):
    return levels.get(n if isinstance(n, str) else n["id"], 0)


def sock(c, canvas, cx, cy, ic, branch, mode, selected=False, pulse=0.0):
    """제안 칸·갈림길 소켓. mode: on 찍음/고름, can 고를 수 있음, plan 제안(아직 없음), closed 안 고른 쪽"""
    p = c.p
    if mode == "on":
        s = rim(p["socket_on"], branch)
    elif mode == "can":
        s = p["socket_off"]
    else:
        s = darken(tint(p["socket_lock"], {TEAL: "#5c5164", TEAL2: "#5c5164", "#1da775": "#5c5164", "#125952": "#3c3544"}), 0.55 if mode == "closed" else 0.8)
    sx, sy = cx - s.width // 2, cy - s.height // 2
    if selected:
        ring(canvas, s, sx, sy, INK)
    elif mode == "can" and pulse > 0:
        ring(canvas, s, sx, sy, BRANCH[branch][1], pulse)
    elif mode == "on":
        ring(canvas, s, sx, sy, BRANCH[branch][1], 0.8)
    mm.clip_paste(canvas, s, sx, sy)
    if ic is None:
        return
    ico = {"on": ic, "can": ic, "plan": darken(ic, 0.6), "closed": silhouette(ic)}[mode]
    mm.clip_paste(canvas, ico, cx - ico.width // 2, cy + 1 - ico.height // 2)
    if mode == "closed":  # 셔터가 내려와 닫힌 칸: 가로 막대 + 자물쇠
        d = draw(canvas)
        for dy in (-9, -3, 3, 9):
            d.rectangle((cx - 13, cy + dy, cx + 12, cy + dy + 3), fill="#3c3544", outline=DARK)
        lk = p["lock"]
        mm.clip_paste(canvas, lk, cx - lk.width // 2, cy - lk.height // 2)


def positions(c, cw, ch):
    """열 위치와 줄 위치. 가운데(선체) 열 아래에 코어, 처음 화면에 기존 3가지가 들어오고 바깥 2가지는 끌어서 본다"""
    phone = c.kind == "phone"
    pitch, step = (156, 50) if phone else (128, 46)
    hull_x = 212 if phone else 160
    core = (hull_x, ch - 34)
    colx = {b: hull_x + (i - 2) * pitch for i, b in enumerate(ORDER)}
    pos = {}
    for b in ORDER:
        y = core[1] - (60 if b == "hull" else 28)
        for i, n in enumerate(TREE[b]):
            if isinstance(n, dict) and n.get("fork"):
                y -= 18  # 갈림길은 소켓 아래에 이름이 있어 그만큼 띄운다
            pos[(b, i)] = (colx[b], y)
            y -= step
    return core, colx, pos


def fork_xy(p):
    return (p[0] - 8, p[1]), (p[0] + 70, p[1])


def fork_state(b, i, levels, forks):
    if b in forks:
        return "chosen"
    prev = TREE[b][i - 1]
    return "open" if node_lv(prev, levels) > 0 else "plan"


def research_body(c, body, levels, forks, sel, pulse=0.0, pan=(0, 0), press=None, flash=None, close_t=1.0, hint=True, pick=None):
    x0, y0, bw, bh = body
    dw = c.s["detail"]
    cw, ch = bw - dw - 4, bh
    canvas = Image.new("RGBA", (cw, ch), (*rgb(DARK), 255))
    d = draw(canvas)
    for yy in range(pan[1] % 24, ch, 24):
        for xx in range(pan[0] % 24, cw, 24):
            d.point((xx, yy), fill="#3c3544")
    core, colx, pos = positions(c, cw, ch)
    core = (core[0] + pan[0], core[1] + pan[1])
    pos = {k: (v[0] + pan[0], v[1] + pan[1]) for k, v in pos.items()}
    # 관: 먼 가지부터 그려 가까운 가지와 빛나는 관이 위에 오게
    for b in ("elec", "survey", "weapon", "mine", "hull"):
        prev, prev_lit = None, True
        for i, n in enumerate(TREE[b]):
            p = pos[(b, i)]
            if isinstance(n, dict) and n.get("fork"):
                st = fork_state(b, i, levels, forks)
                ya, yb = fork_xy(p)
                # 관은 두 소켓 사이로 올라와 옆에서 들어간다. 소켓 아래의 이름을 지나가지 않게
                gap_x, mid_y = (ya[0] + yb[0]) // 2, p[1] + 38
                chosen_on = st == "chosen" and prev_lit
                mm.pipe(d, [prev, (prev[0], mid_y), (gap_x, mid_y), (gap_x, p[1])], b, chosen_on, st != "plan")
                for side, q in (("a", ya), ("b", yb)):
                    on = st == "chosen" and forks[b] == side
                    mm.pipe(d, [(gap_x, p[1]), q], b, on and prev_lit, st != "plan" and not (st == "chosen" and not on))
                # 다음 칸으로 합쳐짐: 고른 쪽만 이어진다
                nxt = pos[(b, i + 1)]
                up_y = p[1] - 26
                for side, q in (("a", ya), ("b", yb)):
                    on = st == "chosen" and forks[b] == side
                    mm.pipe(d, [q, (q[0], up_y), (nxt[0], up_y), nxt], b, on and node_lv(TREE[b][i + 1], levels) > 0, on)
                prev, prev_lit = nxt, st == "chosen" and prev_lit
                continue
            if i > 0 and isinstance(TREE[b][i - 1], dict) and TREE[b][i - 1].get("fork"):
                prev_lit = prev_lit and node_lv(n, levels) > 0
                prev = p
                continue
            lit = node_lv(n, levels) > 0 and prev_lit
            is_open = isinstance(n, str) and mm.node_state(n, b, levels) != "locked"
            if prev is None:
                pts = [core, (p[0], core[1]), p] if p[0] != core[0] else [core, p]
            else:
                pts = [prev, p]
            mm.pipe(d, pts, b, lit, is_open)
            prev, prev_lit = p, lit
    mm.clip_paste(canvas, c.p["core"], core[0] - c.p["core"].width // 2, core[1] - c.p["core"].height // 2)
    icons = c.p["ic"]
    for b in ORDER:
        for i, n in enumerate(TREE[b]):
            p = pos[(b, i)]
            lx, ly = p[0] + 26, p[1] - 13
            if isinstance(n, str):
                st = mm.node_state(n, b, levels)
                mm.draw_socket(c, canvas, p[0], p[1], n, b, st, levels, sel is not None and sel[1] is n, pulse)
                mm.node_label(c, d, lx, ly, n, b, st, levels)
            elif n.get("fork"):
                st = fork_state(b, i, levels, forks)
                is_sel = sel is not None and sel[1] is n
                for side, q in zip("ab", fork_xy(p)):
                    opt = n[side]
                    if st == "chosen":
                        mode = "on" if forks[b] == side else "closed"
                    else:
                        mode = "can" if st == "open" else "plan"
                    sock(c, canvas, q[0], q[1], icons[opt["icon"]], b, mode, is_sel, pulse)
                    if mode == "closed" and close_t < 1.0:  # 닫히는 중: 셔터가 위에서 내려옴
                        sock(c, canvas, q[0], q[1], icons[opt["icon"]], b, "can")
                        cover = Image.new("RGBA", (44, int(46 * close_t)), (*rgb("#3c3544"), 255))
                        mm.clip_paste(canvas, cover, q[0] - 22, q[1] - 23)
                    color = {"on": BRANCH[b][1], "can": INK, "plan": PROPOSAL, "closed": DIM}[mode]
                    text(d, q[0], q[1] + 21, opt["name"], F12, color, "ma", 68)
                if st != "chosen":
                    gx = (fork_xy(p)[0][0] + fork_xy(p)[1][0]) // 2
                    d.rectangle((gx - 9, p[1] - 8, gx + 8, p[1] + 6), fill=DARK, outline="#3c3544")
                    text(d, gx, p[1] - 7, "택1", F12, TEAL2 if st == "open" else DIM, "ma")  # 관이 만나는 곳에 얹는다
                if flash is not None and flash[0] == n["id"]:
                    q = fork_xy(p)[0 if flash[2] == "a" else 1]
                    mm.clip_paste(canvas, Image.new("RGBA", (44, 48), (*rgb(BRANCH[b][1]), int(170 * flash[1]))), q[0] - 22, q[1] - 24)
            else:
                lv = node_lv(n, levels)
                sock(c, canvas, p[0], p[1], icons[n["icon"]], b, "on" if lv else "plan", sel is not None and sel[1] is n)
                text(d, lx, ly, n["name"], F12, BRANCH[b][1] if lv else DIM, limit=cw)
                text(d, lx, ly + 14, n["tag"], F12, PROPOSAL)
    # 가지 이름표: 위아래로 끌어도 아래 줄에 붙어 있고, 좌우로만 판과 함께 움직인다
    chip_y = ch - 30
    for b in ORDER:
        hx = colx[b] + pan[0] - 16 + (52 if b == "hull" else 0)  # 선체는 코어를 피해 오른쪽으로
        w = 18 + int(F12.getlength(SHORT_NAME[b])) + 3
        d.rectangle((hx, chip_y, hx + w, chip_y + 15), fill=DARK)
        mm.clip_paste(canvas, c.p["emblem"][b], hx + 1, chip_y + 1)
        text(d, hx + 18, chip_y + 1, SHORT_NAME[b], F12, BRANCH[b][1])
    # 화면 밖 가지 알림: 어느 쪽에 무엇이 더 있는지 이름으로
    for b in ORDER:
        x = colx[b] + pan[0]
        if x < 8:
            s = "◀ " + SHORT_NAME[b]
            d.rectangle((0, ch - 14, F12.getlength(s) + 5, ch - 1), fill=DARK)
            text(d, 2, ch - 14, s, F12, BRANCH[b][1])
        if x > cw - 8:
            s = SHORT_NAME[b] + " ▶"
            d.rectangle((cw - F12.getlength(s) - 5, ch - 14, cw - 1, ch - 1), fill=DARK)
            text(d, cw - 2, ch - 14, s, F12, BRANCH[b][1], "ra")
    if hint:
        s = "끌어서 이동"
        d.rectangle((2, 2, 8 + F12.getlength(s), 17), fill=DARK)
        text(d, 5, 3, s, F12, TEAL2)
    return canvas, detail_panel(c, dw, bh, sel, levels, forks, press, pick)


def branch_progress(b, levels):
    real = [n for n in TREE[b] if isinstance(n, str)]
    return sum(levels.get(n, 0) for n in real), len(real) * 5


def summary_panel(c, out, w, h, levels):
    """아무것도 안 눌렀을 때: 코어 설명과 전체 진행"""
    d = draw(out)
    f, big = c.s["small"], c.s["big"]
    x, y = 12, 14
    text(d, x, y, "연구 코어", big, TEAL2)
    y = para(d, x, y + big.size + 4, "강화를 찍으면 코어에서 가지로 빛이 번져요.", f, INK, w - 24)
    y += 6
    rows = 0
    for b in ("weapon", "hull", "mine", "elec", "survey"):
        out.alpha_composite(c.p["emblem"][b], (x, y))
        text(d, x + 18, y + 1, SHORT_NAME[b], f, BRANCH[b][1])
        done, total = branch_progress(b, levels)
        bx0, bx1 = x + 50, w - 54
        d.rectangle((bx0, y + 4, bx1, y + 10), fill=DARK)
        d.rectangle((bx0 + 1, y + 5, bx1 - 1, y + 9), fill="#3c3544")
        if total:
            d.rectangle((bx0 + 1, y + 5, bx0 + 1 + (bx1 - bx0 - 2) * done // total, y + 9), fill=BRANCH[b][1])
            text(d, w - 12, y + 1, f"{done}/{total}", f, INK, "ra")
        else:
            text(d, w - 12, y + 1, "제안", f, PROPOSAL, "ra")
        y += 19
    done = sum(branch_progress(b, levels)[0] for b in ORDER)
    total = sum(branch_progress(b, levels)[1] for b in ORDER)
    y += 6
    text(d, x, y, "찍은 단계", f, TEAL2)
    text(d, w - 12, y - (big.size - f.size) // 2, f"{done} / {total}", big, GOLD, "ra")
    note = wrap("칸을 눌러 효과와 가격을 봐요. 주황 글씨는 제안이에요.", f, w - 24)
    para(d, x, h - len(note) * (f.size + 2) - 16, " ".join(note), f, MUTED, w - 24)


def option_card(c, out, x, y, w, opt, branch, state):
    """갈림길 한쪽: 아이콘, 이름, 예시 효과. state: on 고름, off 안 고름, open 고를 수 있음"""
    d = draw(out)
    f = c.s["small"]
    h = 58
    d.rectangle((x, y, x + w, y + h), fill=DARK, outline=BRANCH[branch][1] if state == "on" else (INK if state == "pick" else ("#3c3544" if state == "off" else "#5c5164")))
    ic = c.p["ic"][opt["icon"]]
    out.alpha_composite(silhouette(ic) if state == "off" else ic, (x + 3, y + 3))
    text(d, x + 31, y + 3, opt["name"], f, BRANCH[branch][1] if state == "on" else (DIM if state == "off" else INK))
    if state in ("on", "off"):
        text(d, x + w - 4, y + 3, "고름" if state == "on" else "닫힘", f, BRANCH[branch][1] if state == "on" else DIM, "ra")
    para(d, x + 31, y + 18, opt["effect"], f, GOLD if state != "off" else DIM, w - 36, 1)
    return h


def detail_panel(c, w, h, sel, levels, forks, press=None, pick=None):
    out = plate(c, "tab", w, h)
    d = draw(out)
    f, big = c.s["small"], c.s["big"]
    x, y = 12, 14
    bh = 44 if c.kind == "phone" else 26
    by = h - bh - 12
    if sel is None:
        summary_panel(c, out, w, h, levels)
        return out
    branch, node = sel
    light = BRANCH[branch][1]
    if isinstance(node, str):
        u = DATA["upgrades"][node]
        lv = levels.get(node, 0)
        state = mm.node_state(node, branch, levels)
        ic = c.p["node_icons"][mm.NODE_ICON[node]]
        out.alpha_composite(ic, (x, y))
        tx = x + ic.width + 6
        text(d, tx, y - 1, mm.NODE_NAME[node], f, light, limit=w - tx - 8)
        text(d, tx, y + 13, mm.BRANCH_NAME[branch], f, MUTED)
        y += 30
        mm.pips(d, x, y + 2, lv, branch, size=6, gap=2)
        text(d, x + 44, y, f"{lv}/5단계", f, INK)
        y += 18
        y = para(d, x, y, mm.NODE_DESC[node], f, INK, w - 24)
        y += 6
        text(d, x, y, "다음 효과" if lv < 5 else "지금 효과", f, TEAL2)
        y += 15
        change = u["levels"][lv]["change"]
        if c.kind == "phone":
            cut_at = next((i for i, ch in enumerate(change) if ch.isdigit()), 0)
            text(d, x, y, change[:cut_at].strip(), big, GOLD if lv < 5 else INK, limit=w - 22)
            y += big.size + 1
            text(d, x, y, change[cut_at:], big, GOLD if lv < 5 else INK, limit=w - 22)
            y += big.size + 2
        else:
            text(d, x, y, change, f, GOLD if lv < 5 else INK, limit=w - 22)
            y += 15
        if u["note"]:
            text(d, x, y, u["note"], f, MUTED, limit=w - 22)
        if state == "locked":
            chain = [n for n in TREE[branch] if isinstance(n, str)]
            text(d, x, by - 15, f"먼저 찍을 칸: {mm.NODE_NAME[chain[chain.index(node) - 1]]}", f, PROPOSAL, limit=w - 22)
            out.alpha_composite(mm.button(c, w - 24, bh, "잠김", "off"), (x, by))
        elif state == "max":
            out.alpha_composite(mm.button(c, w - 24, bh, "최대", "off"), (x, by))
        else:
            cost = f"{u['levels'][lv]['cost']:,}"
            if state == "poor":
                text(d, x, by - 15, "광물이 모자라요", f, "#f25c76")
            out.alpha_composite(mm.button(c, w - 24, bh, "강화", "off" if state == "poor" else ("down" if press else "up"), cost), (x, by))
        return out
    if node.get("fork"):
        st = "chosen" if branch in forks else ("open" if fork_state(branch, TREE[branch].index(node), levels, forks) == "open" else "plan")
        text(d, x, y - 1, "갈림길", big, light)
        text(d, w - 12, y - 1, "제안", f, PROPOSAL, "ra")
        y += big.size + 2
        text(d, x, y, "둘 중 하나만 고를 수 있어요", f, INK, limit=w - 22)
        y += 18
        for side in "ab":
            state = ("pick" if pick == side else "open") if st != "chosen" else ("on" if forks[branch] == side else "off")
            y += option_card(c, out, x, y, w - 25, node[side], branch, state) + 4
        cost = f"{node['cost']:,}"
        if st == "chosen":
            text(d, x, by - 15, "광물을 내고 바꿀 수 있어요", f, MUTED, limit=w - 22)
            out.alpha_composite(mm.button(c, w - 24, bh, "바꾸기", "up", f"{SWAP_COST:,}"), (x, by))
        elif st == "open":
            text(d, x, by - 15, "위 칸을 눌러 고른 뒤 확정" if pick is None else node[pick]["name"] + " 으로 확정", f, MUTED if pick is None else INK, limit=w - 22)
            label_state = "off" if pick is None else ("down" if press else "up")
            out.alpha_composite(mm.button(c, w - 24, bh, "고르기", label_state, cost), (x, by))
        else:
            text(d, x, by - 15, "앞 칸을 찍으면 열려요", f, PROPOSAL, limit=w - 22)
            out.alpha_composite(mm.button(c, w - 24, bh, "잠김", "off"), (x, by))
        return out
    # 제안 칸
    ic = c.p["ic"][node["icon"]]
    out.alpha_composite(ic, (x, y))
    tx = x + ic.width + 6
    text(d, tx, y - 1, node["name"], f, light, limit=w - tx - 8)
    text(d, tx, y + 13, mm.BRANCH_NAME[branch], f, MUTED)
    y += 30
    text(d, x, y, node["tag"], f, PROPOSAL)
    y = para(d, x, y + 18, node["desc"], f, INK, w - 24) + 6
    text(d, x, y, "예시 효과", f, TEAL2)
    y = para(d, x, y + 15, node["effect"], f, GOLD, w - 24) + 6
    text(d, x, y, f"예시 가격 {node['cost']:,}", f, MUTED)
    out.alpha_composite(mm.button(c, w - 24, bh, "아직 없는 칸", "off"), (x, by))
    return out


def research(c, levels=SAMPLE, forks=None, sel=None, **kw):
    layer, body = window(c, "research")
    canvas, panel = research_body(c, body, levels, forks or {}, sel, **kw)
    layer.alpha_composite(canvas, (body[0], body[1]))
    layer.alpha_composite(panel, (body[0] + body[2] - panel.width, body[1]))
    return layer


def pan_for(c, side):
    """바깥 가지가 보이도록 끈 양. PC는 3열, 폰은 3열 반이 한 화면에 들어온다"""
    pitch = 156 if c.kind == "phone" else 128
    return (pitch, 0) if side == "left" else (-pitch, 0)


DEMO_LEVELS = dict(SAMPLE, sub=1, damage=3, magnet=2, cargo=1, shield=2, reroll=1, appraise=1, radar=1, over=0)
DEMO_FORKS = {"weapon": "a", "hull": "b", "mine": "a", "elec": "a", "survey": "b"}


def fork(b):
    return next(n for n in TREE[b] if isinstance(n, dict) and n.get("fork"))


def prop(b, pid):
    return next(n for n in TREE[b] if isinstance(n, dict) and n.get("id") == pid)


def save_gif(frames, durs, name):
    """모든 프레임에 같은 색표를 써서 바뀐 곳만 저장되게 한다"""
    sample = Image.new("RGB", (frames[0].width, frames[0].height * 2))
    sample.paste(frames[0], (0, 0))
    sample.paste(frames[len(frames) // 2], (0, frames[0].height))
    pal = sample.quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE)
    q = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
    q[0].save(OUT + name, save_all=True, append_images=q[1:], duration=durs, loop=0, optimize=False, disposal=1)


def research_gif(c):
    """깜빡임 → 왼쪽으로 끌기 → 오른쪽으로 끌기 → 갈림길 누름 → 고름, 안 고른 쪽 셔터 닫힘 → 바꾸기"""
    frames, durs = [], []
    def snap(levels=SAMPLE, forks=None, sel=None, pulse=0.8, **kw):
        return mm.compose(c, research(c, levels, forks, sel, pulse=pulse, **kw), 0, 1, 0)
    for i in range(8):
        frames.append(snap(pulse=0.5 + 0.5 * np.sin(i / 8 * 2 * np.pi)))
        durs.append(100)
    pl, pr = pan_for(c, "left")[0], pan_for(c, "right")[0]
    for t in list(range(0, pl + 1, 16)) + [pl] * 6 + list(range(pl, pr - 1, -16)) + [pr] * 6 + list(range(pr, 1, 16)) + [0] * 2:
        frames.append(snap(pan=(t, 0)))
        durs.append(40)
    fk = fork("hull")
    sel = ("hull", fk)
    frames.append(snap(sel=sel))
    durs.append(800)
    frames.append(snap(sel=sel, pick="a"))
    durs.append(800)
    frames.append(snap(sel=sel, pick="a", press=True))
    durs.append(120)
    for t in (0.25, 0.5, 0.75):
        frames.append(snap(forks={"hull": "a"}, sel=sel, close_t=t, flash=(fk["id"], 1 - t, "a")))
        durs.append(60)
    frames.append(snap(forks={"hull": "a"}, sel=sel))
    durs.append(1400)
    save_gif(frames, durs, f"research_drag_fork_{c.kind}.gif")


def make_research(parts):
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        shots = {
            "research_start": research(c, pulse=0.8),
            "research_drag_left": research(c, pulse=0.8, pan=pan_for(c, "left")),
            "research_drag_right": research(c, pulse=0.8, pan=pan_for(c, "right")),
            "research_node": research(c, sel=("hull", "insurance"), pulse=0.8),
            "research_node_max": research(c, sel=("hull", "max_hp"), pulse=0.8),
            "research_node_poor": research(c, sel=("weapon", "damage"), pulse=0.8),
            "research_node_locked": research(c, sel=("mine", "magnet"), pulse=0.8),
            "research_proposal": research(c, sel=("weapon", prop("weapon", "over")), pulse=0.8),
            "research_proposal_new": research(c, sel=("elec", prop("elec", "reroll")), pulse=0.8, pan=pan_for(c, "left")),
            "research_fork_open": research(c, sel=("hull", fork("hull")), pulse=0.8),
            "research_fork_pick": research(c, sel=("hull", fork("hull")), pulse=0.8, pick="a"),
            "research_fork_chosen": research(c, forks={"hull": "a"}, sel=("hull", fork("hull")), pulse=0.8),
            "research_all_chosen": research(c, DEMO_LEVELS, DEMO_FORKS, pulse=0.8),
            "research_all_chosen_left": research(c, DEMO_LEVELS, DEMO_FORKS, pulse=0.8, pan=pan_for(c, "left")),
            "research_all_chosen_right": research(c, DEMO_LEVELS, DEMO_FORKS, pulse=0.8, pan=pan_for(c, "right")),
        }
        for name, layer in shots.items():
            mm.compose(c, layer, 0, 1, 0).save(f"{OUT}{name}_{tag}.png")
        research_gif(c)
        mm.transition(c, shots["research_start"], f"open_close_research_{kind}.gif")


# ── 광물 창고 ─────────────────────────────────
def ore_palette(grade):
    """광물 그림의 색을 어두운 순서로: 외곽선, 어두운 면, 가운데 면, 밝은 면"""
    a = np.array(sprite(f"assets/sprites/run/mineral_{grade}.png"))
    cols = {tuple(int(v) for v in p[:3]) for p in a[a[..., 3] > 0]}
    cols = sorted(cols, key=sum)
    # 맨 밝은 색은 한 줌만 쓰게 빼 둔다. 다 쓰면 소금 뿌린 것처럼 지저분하다
    return cols[0], cols[len(cols) // 4], cols[len(cols) // 2], cols[max(len(cols) * 3 // 4, len(cols) // 2)]


def shard(rng, r, pal):
    """제각각인 광물 조각: 불규칙한 다각형 + 밝은 면, 어두운 면 (크기·각도·모양을 매번 다르게)"""
    size = 2 * r + 3
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = rng.randint(5, 7)
    start = rng.uniform(0, 6.28)
    pts = []
    for i in range(n):
        ang = start + i / n * 6.28 + rng.uniform(-0.25, 0.25)
        rad = r * rng.uniform(0.65, 1.0)
        pts.append((r + 1 + round(np.cos(ang) * rad), r + 1 + round(np.sin(ang) * rad * rng.uniform(0.75, 1.0))))
    d.polygon(pts, fill=(*pal[2], 255), outline=(*pal[0], 255))
    mid = (r + 1 + rng.randint(-1, 1), r + 1 + rng.randint(-1, 1))
    top = sorted(pts, key=lambda p: p[0] + p[1])
    d.polygon([top[-1], top[-2], mid], fill=(*pal[1], 255))
    if r >= 4 and rng.random() < 0.7:  # 밝은 면은 큰 돌에만
        d.polygon([top[0], top[1], mid], fill=(*pal[3], 255))
    d.polygon(pts, outline=(*pal[0], 255))
    return im


def real_ore(rng, grade):
    """게임의 광물 그림을 뒤집고 돌려 섞는다 (새 색을 만들지 않게 90도 단위로만)"""
    im = sprite(f"assets/sprites/run/mineral_{grade}.png")
    im = im.crop(im.getbbox())
    if rng.random() < 0.5:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    k = rng.randint(0, 3)
    return im.rotate(90 * k, expand=True) if k else im


def pile_height(count, max_h):
    return 0 if count <= 0 else max(int(max_h * mm.fill_ratio(count)), 6)


def pile(w, max_h, grade, count, phase=None):
    """쌓인 더미: 바닥은 빽빽하고 위는 한쪽으로 무너진 모양. 개수(로그 눈금)만큼 높아진다. phase를 주면 몇 개가 반짝인다"""
    rng = random.Random(500 + grade)
    pal = ore_palette(grade)
    h = pile_height(count, max_h)
    im = Image.new("RGBA", (w, max_h), (0, 0, 0, 0))
    if count <= 0:
        return im
    apex = w * 0.36  # 꼭대기를 왼쪽으로 치우쳐 오른쪽으로 흘러내리게
    def top(x):
        side = (x - apex) / (apex if x < apex else w - apex)
        return h * max(0.12, 1 - abs(side) ** (2.2 if x < apex else 1.25) * 0.78)
    if count < 12:  # 몇 개뿐이면 정말 그 개수만 놓는다
        spots = [(rng.uniform(5, w - 6), 0, rng.randint(5, 6)) for _ in range(count)]
    else:
        spots = []
        # 바닥 칸부터 채운다: 먼저 뒤쪽(위) 돌을 그려 앞쪽이 덮게
        for y in range(h, 0, -5):
            for x in range(1, w, 6):
                if y <= top(x) + rng.uniform(-4, 1):
                    low = y < h * 0.45
                    spots.append((x + rng.uniform(-3, 3), y + rng.uniform(-3, 2), rng.choice((5, 5, 6, 7) if low else (4, 5, 5, 6))))
        # 더미 앞으로 굴러 나온 돌
        spots += [(w * rng.uniform(0.72, 0.98), rng.uniform(1, 4), rng.randint(3, 5)) for _ in range(3)]
    backing = [(0, max_h)] + [(x, max_h - top(x) + 2) for x in range(0, w, 2)] + [(w, max_h)]
    if count >= 12:
        ImageDraw.Draw(im).polygon(backing, fill=(*pal[0], 255))
    spots.sort(key=lambda s: -s[1])
    picked = []
    for x, y, r in spots:
        st = real_ore(rng, grade) if rng.random() < 0.45 and r >= 4 else shard(rng, r, pal)
        px, py = int(x - st.width / 2), int(max_h - y - st.height)
        mm.clip_paste(im, st, px, py)
        if r >= 3:
            picked.append((px + st.width // 2 - 1, py + st.height // 2 - 1, rng.random()))
    if phase is not None and picked:
        d = ImageDraw.Draw(im)
        for x, y, off in rng.sample(picked, min(6 if count >= 12 else 2, len(picked))):
            t = (phase + off) % 1.0
            if t < 0.3:  # 잠깐 켜지는 십자 반짝임
                arm = 1 if t < 0.1 or t > 0.2 else 2
                d.line((x - arm, y, x + arm, y), fill=(*rgb(INK), 255))
                d.line((x, y - arm, x, y + arm), fill=(*rgb(INK), 255))
    return im


def tank2(c, grade, count, phase=None):
    t = c.p["tank"].copy()
    w, h = t.size
    ix0, ix1, iy0, iy1 = int(w * 0.17), int(w * 0.84), int(h * 0.26), int(h * 0.86)
    p = pile(ix1 - ix0, iy1 - iy0, grade, count, phase)
    t.alpha_composite(p, (ix0, iy0))
    draw(t).line((ix0 + 2, iy0 + 4, ix0 + 2, iy1 - 6), fill=TEAL2)  # 유리 반사선을 다시 위에
    return t


def cart2(c, grade, count, phase=None):
    """B안: 수레 위 광석 더미. 앞쪽 벽이 더미 아래를 가린다"""
    cart = c.p["cart"]
    rim_y = int(cart.height * 0.36)
    max_h = 56
    out = Image.new("RGBA", (cart.width, cart.height + max_h - rim_y), (0, 0, 0, 0))
    out.alpha_composite(cart, (0, max_h - rim_y))
    p = pile(cart.width - 16, max_h, grade, count, phase)
    out.alpha_composite(p, (8, 4))
    front = cart.crop((0, rim_y, cart.width, cart.height))
    out.alpha_composite(front, (0, max_h))
    return out


def storage(c, mode="tank", counts=None, phase=None):
    layer, body = window(c, "storage")
    x0, y0, bw, bh = body
    d = draw(layer)
    counts = counts or mm.HAULED
    lw = 176 if c.kind == "pc" else 250
    v = c.p["vault"]
    vx, vy = x0 + (lw - v.width) // 2, y0 + (bh - v.height - 90) // 2
    layer.alpha_composite(v, (vx, vy))
    ty = vy + v.height + 18
    text(d, x0 + lw // 2, ty, "보유 광물 총가치", c.s["small"], TEAL2, "ma")
    ore = sprite("assets/sprites/run/mineral_3.png").resize((24, 22), Image.NEAREST)
    val = f"{CREDITS:,}"
    sx = x0 + (lw - int(F24.getlength(val)) - ore.width - 6) // 2
    layer.alpha_composite(ore, (sx, ty + 18))
    text(d, sx + ore.width + 6, ty + 16, val, F24, GOLD)
    text(d, x0 + lw // 2, ty + 48, "지금까지 기지로 가져온 광물", c.s["small"], MUTED, "ma", lw + 16)
    pitch = (bw - lw - 10) // 4
    for i in range(4):
        t = tank2(c, i, counts[i], phase) if mode == "tank" else cart2(c, i, counts[i], phase)
        tb = y0 + (bh - t.height - 34) // 2
        tx = x0 + lw + 10 + i * pitch + (pitch - t.width) // 2
        layer.alpha_composite(t, (tx, tb))
        ly, cx = tb + t.height + 4, tx + t.width // 2
        text(d, cx, ly, f"{DATA['minerals'][i]} 광물", c.s["small"], mm.GRADE_COLOR[i], "ma")
        text(d, cx, ly + 15, f"{counts[i]:,}개", c.s["big"] if c.kind == "phone" else F12, INK, "ma")
    return layer


def make_storage(parts):
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        for mode in ("tank", "cart"):
            mm.compose(c, storage(c, mode, phase=0.12), 0, 1, 0).save(f"{OUT}storage_{mode}_{tag}.png")
            mm.compose(c, storage(c, mode, [0, 8, 60, 1000], phase=0.12), 0, 1, 0).save(f"{OUT}storage_{mode}_counts_{tag}.png")
    c = mm.Ctx(parts, "pc")
    for mode in ("tank", "cart"):
        frames, durs = [], []
        for n in (1, 3, 8, 20, 50, 120, 300, 1000):  # 개수가 늘면 더미가 높아짐
            frames.append(mm.compose(c, storage(c, mode, [n, n, n, n], phase=0.5), 0, 1, 0))
            durs.append(350)
        for i in range(16):
            frames.append(mm.compose(c, storage(c, mode, phase=i / 16), 0, 1, 0))
            durs.append(90)
        save_gif(frames, durs, f"storage_{mode}_grow_sparkle_pc.gif")


# ── 전시관 ────────────────────────────────────
# 등급: (이름, 본색, 밝은 색, 어두운 색, 장식). 장식은 색 말고 모양으로도 구분되게 등급이 오를수록 늘어난다
RANKS = {
    "common": ("일반", "#5c5164", "#a5b29d", "#3c3544", 0), "rare": ("희귀", "#4d80cd", "#99e9e6", "#3c3544", 1),
    "epic": ("영웅", "#6b3e75", "#a884f3", "#3a1c57", 2), "legend": ("전설", "#f89419", "#f6ce50", "#984633", 3),
    "elite": ("정예", "#dc7f47", "#f89419", "#984633", 1), "boss": ("보스", "#cb3738", "#f25c76", "#6f2626", 3),
}
RANK_OF = {"mineral_0": "common", "mineral_1": "rare", "mineral_2": "epic", "mineral_3": "legend", "rock_0": "common", "rock_1": "common", "jelly": "common", "bug": "common",
           "rock_2": "elite", "golden": "elite", "guard": "elite", "barrage": "boss"}
REWARDS = {3: "광물 150", 6: "이동 속도 +2%", 9: "광물 400", 12: "사망 보존 +3%"}
SPECIAL = "금빛 도색"
ALL_FOUND = {e["id"] for e in DATA["discovery"]}


def case_for(c, rank):
    name, main, light, dark, deco = RANKS[rank]
    base = tint(c.p["case_on"], {"#6f2626": "#3c3544", "#7a3045": "#3c3544", "#984633": "#5c5164"})
    im = tint(base, {TEAL: main if rank != "common" else "#917487", TEAL2: light, "#1da775": main, "#125952": dark})
    if deco >= 3:  # 전설·보스: 모서리 금속도 등급 색으로
        im = tint(im, {INK: light, "#a5b29d": main})
    return im


def case_deco(d, kx, ky, w, h, rank):
    """등급 장식: 희귀·정예는 바깥 줄, 영웅은 모서리 징, 전설·보스는 뿔"""
    _, main, light, _, deco = RANKS[rank]
    if deco >= 1:
        d.rectangle((kx - 1, ky + 5, kx + w, ky + h), outline=main)
    if deco >= 2:
        for x, y in ((kx - 2, ky + 4), (kx + w - 1, ky + 4), (kx - 2, ky + h - 1), (kx + w - 1, ky + h - 1)):
            d.rectangle((x, y, x + 2, y + 2), fill=light)
    if deco >= 3:
        for x, sx in ((kx - 2, -1), (kx + w + 1, 1)):
            d.polygon([(x, ky + 12), (x, ky + 22), (x + 3 * sx, ky + 17)], fill=light)


def reward_bar(c, layer, d, bx, y, bx1, found, claimed, pulse, sel):
    """진행 막대 + 보상 지점 4곳. 받은 것은 체크, 받을 수 있으면 반짝, 아직이면 어둡게"""
    d.rectangle((bx, y + 3, bx1, y + 11), fill=DARK)
    d.rectangle((bx + 1, y + 4, bx1 - 1, y + 10), fill="#3c3544")
    total = len(DATA["discovery"])
    span = bx1 - bx - 2
    d.rectangle((bx + 1, y + 4, bx + 1 + span * found // total, y + 10), fill=TEAL)
    crate = c.p["crate_s"]
    for n in REWARDS:
        x = bx + 1 + span * n // total - crate.width // 2 - (crate.width // 2 if n == total else 0)
        cy = y + 7 - crate.height // 2
        if n in claimed:
            layer.alpha_composite(darken(crate, 0.6), (x, cy))
            d.line((x + 3, cy + 8, x + 6, cy + 11), fill=TEAL2, width=2)
            d.line((x + 6, cy + 11, x + 12, cy + 3), fill=TEAL2, width=2)
        elif found >= n:
            ring(layer, crate, x, cy, GOLD, 0.35 + 0.65 * pulse)
            layer.alpha_composite(crate, (x, cy))
        else:
            layer.alpha_composite(darken(crate, 0.5), (x, cy))
        if sel == n:
            d.rectangle((x - 2, cy - 2, x + crate.width + 1, cy + crate.height + 1), outline=INK)


def museum(c, found=None, sel="rock_2", claimed=(3,), reward=None, pulse=0.8, glow=0.5):
    layer, body = window(c, "museum")
    x0, y0, bw, bh = body
    d = draw(layer)
    f = c.s["small"]
    found = mm.FOUND if found is None else found
    tab_w, tab_h = 92, 20
    t = plate(c, "tab", tab_w, tab_h)
    text(draw(t), tab_w // 2, 4, "도감", F12, TEAL2, "ma")
    layer.alpha_composite(t, (x0, y0))
    t2 = darken(plate(c, "tab", tab_w + 40, tab_h), 0.7)
    t2.alpha_composite(c.p["lock"], (6, 3))
    text(draw(t2), 24, 4, "진화 도감 제안", F12, DIM)
    layer.alpha_composite(t2, (x0 + tab_w + 3, y0))
    total = len(DATA["discovery"])
    px = x0 + 2 * tab_w + 54
    text(d, px, y0 + 4, f"발견 {len(found)} / {total}", F12, INK)
    cols, top, detail_h = 6, y0 + tab_h + 5, 40 if c.kind == "phone" else 34
    cell_w, cell_h = bw // cols, (bh - tab_h - 5 - detail_h - 2) // 2
    for i, e in enumerate(DATA["discovery"]):
        cx, cy = x0 + (i % cols) * cell_w + cell_w // 2, top + (i // cols) * cell_h
        known = e["id"] in found
        rank = RANK_OF[e["id"]]
        case = case_for(c, rank) if known else c.p["case_off"]
        kx, ky = cx - case.width // 2, cy
        if known and RANKS[rank][4] >= 3 and glow > 0:
            ring(layer, case, kx, ky, RANKS[rank][2], glow, 3)  # 전설·보스의 은은한 빛
        if known:
            case_deco(d, kx, ky, case.width, case.height, rank)
        if e["id"] == sel and reward is None:
            d.rectangle((kx - 3, ky + 3, kx + case.width + 2, ky + case.height + 2), outline=INK)
        layer.alpha_composite(case, (kx, ky))
        ic = mm.discovery_icon(e["id"])
        ix, iy = cx - ic.width // 2, ky + int(case.height * 0.79) - ic.height
        if known:
            layer.alpha_composite(ic, (ix, iy))
            text(d, cx, ky + case.height + 1, e["name"], f, RANKS[rank][2] if rank != "common" else INK, "ma", cell_w - 2)
        else:
            layer.alpha_composite(silhouette(ic), (ix, iy))
            text(d, cx, iy + ic.height // 2 - 7, "?", F12, DIM, "ma")
            text(d, cx, ky + case.height + 1, "?", f, DIM, "ma")
    reward_bar(c, layer, d, px + 76, y0 + 2, x0 + bw - 8, len(found), claimed, pulse, reward)
    ep = plate(c, "head", bw, detail_h - 2)
    de = draw(ep)
    ty = (detail_h - 2 - 12) // 2 - 1
    if reward is None:
        entry = next(e for e in DATA["discovery"] if e["id"] == sel)
        rank = RANKS[RANK_OF[sel]]
        text(de, 14, ty, entry["name"], F12, GOLD)
        nx = 14 + int(F12.getlength(entry["name"])) + 8
        text(de, nx, ty, rank[0], F12, rank[2])
        text(de, nx + int(F12.getlength(rank[0])) + 8, ty, mm.SHORT[sel], F12, INK, limit=bw - nx - 40)
    else:
        text(de, 14, ty, f"{reward}개 발견 보상", F12, GOLD)
        s = REWARDS[reward] + (f", 완성 보상 {SPECIAL}" if reward == total else "")
        nx = 14 + int(F12.getlength(f"{reward}개 발견 보상")) + 8
        text(de, nx, ty, s, F12, INK)
        text(de, nx + int(F12.getlength(s)) + 8, ty, "제안", F12, PROPOSAL)
        if reward in claimed:
            label, state = "받음", "off"
        elif len(found) >= reward:
            label, state = "받기", "up"
        else:
            label, state = f"{reward - len(found)}개 더", "off"
        bw2, bh2 = (116, 30) if c.kind == "phone" else (72, 22)
        ep.alpha_composite(mm.button(c, bw2, bh2, label, state), (bw - bw2 - 18, 3))
    layer.alpha_composite(ep, (x0, y0 + bh - detail_h + 2))
    return layer


def make_museum(parts):
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        shots = {
            "museum": museum(c),
            "museum_reward_ready": museum(c, reward=6),
            "museum_reward_claimed": museum(c, reward=3),
            "museum_reward_future": museum(c, reward=9),
            "museum_full": museum(c, ALL_FOUND, sel="mineral_3", claimed=(3, 6, 9)),
            "museum_full_reward": museum(c, ALL_FOUND, claimed=(3, 6, 9), reward=12),
            "museum_full_claimed": museum(c, ALL_FOUND, sel="barrage", claimed=(3, 6, 9, 12)),
        }
        for name, layer in shots.items():
            mm.compose(c, layer, 0, 1, 0).save(f"{OUT}{name}_{tag}.png")
    c = mm.Ctx(parts, "pc")
    frames, durs = [], []
    for i in range(14):
        k = 0.5 + 0.5 * np.sin(i / 14 * 2 * np.pi)
        frames.append(mm.compose(c, museum(c, ALL_FOUND, sel="mineral_3", claimed=(3, 6, 9), pulse=k, glow=0.2 + 0.6 * k), 0, 1, 0))
        durs.append(110)
    save_gif(frames, durs, "museum_glow_reward_pc.gif")


# ── 격납고 ────────────────────────────────────
PLAY = {"pioneer": "무엇이든 무난하게 해내는 전투기."}
WEAPONS = [
    ("w_pulse", "펄스 연사포", "가까운 거리에서 빠른 연사로 앞을 쓸어 버립니다.", "기본"),
    ("w_shot", "산탄포", "넓게 퍼지는 탄으로 몰려오는 적을 한 번에 밀어냅니다.", "v0.8.0 제안"),
    ("w_rail", "레일건", "느리지만 일직선에 있는 것을 전부 꿰뚫습니다.", "v0.8.0 제안"),
    ("w_plasma", "플라스마 대포", "크고 느린 탄이 터지며 주변까지 태웁니다.", "v0.8.0 제안"),
    ("w_beam", "채굴 빔", "짧은 빔을 계속 쏘아 운석을 빠르게 깎습니다.", "v0.8.0 제안"),
]
SPIN = {"a": (Image.open(OUT + "spin3d/spin_a_sheet.png").convert("RGBA"), 12, 120), "b": (Image.open(OUT + "spin3d/spin_b_sheet.png").convert("RGBA"), 8, 40)}
SPIN_W, SPIN_H = 64, 56
MODEL_K = {"pc": 3, "phone": 3}  # 모형의 정수 배율. 1차는 2배였다


def spin_frame(method, i):
    """i = 0~119 (0.05초 간격). (b)는 40장뿐이라 3칸마다 바뀐다"""
    sheet, cols, n = SPIN[method]
    j = (i % 120) * n // 120
    return sheet.crop((j % cols * SPIN_W, j // cols * SPIN_H, (j % cols + 1) * SPIN_W, (j // cols + 1) * SPIN_H))


def bob(i):
    """위아래로 살짝 떠 있음: 2.4초 주기, 정수 칸만 움직인다"""
    return int(round(3 * np.sin(i / 48 * 2 * np.pi)))


def stage(c, canvas, x, y, w, h, stand, method, i):
    """배경에 네모 판 없이 받침만 놓는다. 바닥 고리는 희미한 색 몇 칸으로 어둠에 녹인다"""
    d = draw(canvas)
    k = MODEL_K[c.kind]
    cx, cy = x + w // 2, y + h // 2 - 8
    if stand == "holo":
        ped = c.p["pedestal"]
        ped = ped.resize((ped.width * 2, ped.height * 2), Image.NEAREST)
        px, py = cx - ped.width // 2, y + h - ped.height - 2
        pmid = py + int(ped.height * 0.38)
        for rx, col in ((ped.width // 2 + 14, "#2b1925"), (ped.width // 2 + 26, "#2b1925")):  # 바닥에 퍼지는 고리
            d.ellipse((cx - rx, pmid + 10 - rx // 3, cx + rx, pmid + 10 + rx // 3), outline=col)
        canvas.alpha_composite(ped, (px, py))
        # 받침 위 그림자: 떠오르면 작아진다
        sh = 44 - bob(i) * 2
        d.ellipse((cx - sh, pmid - sh // 4, cx + sh, pmid + sh // 4), fill="#14111c")
        # 빛기둥: 점 줄무늬로 위로 사라진다. 반투명 대신 칸을 듬성듬성 찍어 팔레트를 지킨다
        for yy in range(pmid - 8, y + 6, -3):
            t = (pmid - yy) / max(pmid - y - 6, 1)
            half = int((ped.width // 2 - 12) * (1 - 0.25 * t))
            step = 2 + int(t * 7)
            off = (i // 2 + yy) % step
            for xx in range(cx - half + off, cx + half, step):
                d.point((xx, yy), fill=("#1da775" if t < 0.5 else "#125952"))
        d.ellipse((cx - ped.width // 2 + 12, pmid - 16, cx + ped.width // 2 - 12, pmid + 16), outline=TEAL)
        cy = pmid - 58
    else:
        cr = c.p["cradle"]
        cr = cr.resize((cr.width * 2, cr.height * 2), Image.NEAREST)
        px, py = cx - cr.width // 2, y + h - cr.height - 2
        base_y = py + int(cr.height * 0.86)
        for rx, col in ((cr.width // 2 + 10, "#2b1925"),):
            d.ellipse((cx - rx, base_y - rx // 4, cx + rx, base_y + rx // 4), outline=col)
        canvas.alpha_composite(cr, (px, py))
        sh = 40 - bob(i) * 2
        d.ellipse((cx - sh, base_y - 8 - sh // 5, cx + sh, base_y - 8 + sh // 5), fill="#14111c")
        cy = py + int(cr.height * 0.42)
    sp = spin_frame(method, i)
    sp = sp.resize((sp.width * k, sp.height * k), Image.NEAREST)
    mm.clip_paste(canvas, sp, cx - sp.width // 2, cy - sp.height // 2 + bob(i))


def stat_rows(c, d, x, y, w, h):
    stats = DATA["stats"]
    font = F24 if c.kind == "phone" else F12
    gap = h // len(stats)
    for i, st in enumerate(stats):
        ry = y + i * gap
        light = BRANCH[mm.STAT_BRANCH[st["name"]]][1]
        text(d, x, ry, st["name"], font, light)
        text(d, x + w, ry, st["value"], font, INK, "ra")
        by = ry + font.size + 2
        d.rectangle((x, by, x + w, by + 4), fill=DARK)
        d.rectangle((x + 1, by + 1, x + w - 1, by + 3), fill="#3c3544")
        d.rectangle((x + 1, by + 1, x + 1 + int((w - 2) * st["ratio"] / 2) * 2, by + 3), fill=light)


def weapon_block(c, out, x, y, w, weapon, font, gap=2):
    icon, name, desc, tag = weapon
    d = draw(out)
    out.alpha_composite(c.p["ic"][icon], (x, y))
    text(d, x + 42, y + (24 - font.size) // 2 - 1, name, font, TEAL2, limit=w - 42)
    return para(d, x, y + 28, desc, font, INK, w, gap)


def desc_panel(c, w, h, fighter):
    out = plate(c, "tab", w, h)
    d = draw(out)
    f = F24 if c.kind == "phone" else F12
    x, y, tw = 12, 12, w - 24
    text(d, x, y, fighter["name"], f, GOLD)
    text(d, w - 12, y, fighter["style"], f, TEAL2, "ra")
    y = para(d, x, y + f.size + 4, PLAY[fighter["id"]], f, INK, tw) + 6
    d.line((x, y, w - 13, y), fill="#3c3544")
    y += 6
    text(d, x, y, "기본 무기", F12, MUTED)
    text(d, w - 12, y, "설명 글은 제안", F12, PROPOSAL, "ra")
    y = weapon_block(c, out, x, y + 15, tw, WEAPONS[0], f)
    assert y <= h - 8, (c.kind, y, h)
    return out


def slot2(c, w, h, fighter, selected):
    out = plate(c, "tab", w, h)
    if selected:
        out = tint(out, {INK: GOLD, MUTED: PROPOSAL})
    d = draw(out)
    f = F24 if c.kind == "phone" else F12
    ship = sprite("assets/sprites/station/ship.png")
    sb = ship.crop(ship.getbbox())
    sx, sy = 12, (h - sb.height) // 2 - 1
    tx = 12 + sb.width + 8
    rows = [("해금 조건", DIM), ("???", PROPOSAL)] if fighter is None else [(fighter["name"], GOLD if selected else INK), (fighter["style"], TEAL2)]
    out.alpha_composite(silhouette(sb) if fighter is None else sb, (sx, sy))
    ty = (h - 2 * f.size - 2) // 2 - 1
    for i, (s, col) in enumerate(rows):
        text(d, tx, ty + i * (f.size + 2), s, f, col, limit=w - tx - 8)
    return out


def hangar(c, stand="holo", method="b", i=0):
    layer, body = window(c, "hangar")
    x0, y0, bw, bh = body
    d = draw(layer)
    phone = c.kind == "phone"
    slot_h = 64 if phone else 44
    sw_stats, sw_desc = (216, 300) if phone else (146, 170)
    area_h = bh - slot_h - 4
    stat_rows(c, d, x0 + 4, y0 + 4, sw_stats - 8, area_h - 4)
    stage(c, layer, x0 + sw_stats, y0, bw - sw_stats - sw_desc, area_h, stand, method, i)
    layer.alpha_composite(desc_panel(c, sw_desc, area_h, DATA["fighters"][0]), (x0 + bw - sw_desc, y0))
    n = 4
    w = (bw - 3 * 4) // n
    for k in range(n):
        s = slot2(c, w, slot_h, DATA["fighters"][k] if k < len(DATA["fighters"]) else None, k == 0)
        layer.alpha_composite(s, (x0 + k * (w + 4), y0 + bh - slot_h))
    return layer


def weapons_sheet(c):
    """v0.8.0 무기도 같은 형식으로 (제안)"""
    layer, body = window(c, "hangar")
    x0, y0, bw, bh = body
    f = F24 if c.kind == "phone" else F12
    cols, rows = 2, 3
    w, h = (bw - 4) // cols, (bh - 8) // rows
    for i, wp in enumerate(WEAPONS):
        out = plate(c, "tab", w, h)
        y_end = weapon_block(c, out, 12, 10, w - 24, wp, f)
        text(draw(out), w - 12, 10, wp[3], F12, MUTED if wp[3] == "기본" else PROPOSAL, "ra")
        assert y_end <= h, (wp, y_end, h)
        layer.alpha_composite(out, (x0 + i % cols * (w + 4), y0 + i // cols * (h + 4)))
    return layer


def make_hangar(parts):
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        for stand in ("holo", "cradle"):
            mm.compose(c, hangar(c, stand, "b", 8), 0, 1, 0).save(f"{OUT}hangar_{stand}_{tag}.png")
        mm.compose(c, weapons_sheet(c), 0, 1, 0).save(f"{OUT}hangar_weapons_{tag}.png")
    def spin_gif(kind, stand, method, name):
        c = mm.Ctx(parts, kind)
        frames = [mm.compose(c, hangar(c, stand, method, i), 0, 1, 0) for i in range(0, 120, 2)]
        save_gif(frames, [100] * len(frames), name)
    spin_gif("pc", "holo", "a", "hangar_holo_spin_a_pc.gif")
    spin_gif("pc", "holo", "b", "hangar_holo_spin_b_pc.gif")
    spin_gif("pc", "cradle", "b", "hangar_cradle_spin_b_pc.gif")
    spin_gif("phone", "holo", "a", "hangar_holo_spin_a_phone.gif")
    spin_gif("phone", "cradle", "b", "hangar_cradle_spin_b_phone.gif")
    # 무대만 나란히: (a) (b) 차이를 20프레임으로 비교
    c = mm.Ctx(parts, "pc")
    frames = []
    for i in range(0, 120):
        row = Image.new("RGBA", (2 * 264, 234), (*rgb(DARK), 255))
        stage(c, row, 0, 0, 264, 234, "holo", "a", i)
        stage(c, row, 264, 0, 264, 234, "holo", "b", i)
        d = draw(row)
        text(d, 6, 4, "(a) 실시간 복셀", F12, TEAL2)
        text(d, 270, 4, "(b) 미리 만든 40장", F12, TEAL2)
        frames.append(row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert("RGB"))
    save_gif(frames, [50] * len(frames), "hangar_spin_compare.gif")


# ── 드론 공장 ─────────────────────────────────
def drone(c, fill=DARK):
    """파란 설계도를 어둡게. void32에 진짜 남색이 없어 어두운 바탕(fill) + 파란 선만 남긴다. 글자와 표지판이 가장 밝다"""
    layer, body = window(c, "drone")
    x0, y0, bw, bh = body
    d = draw(layer)
    line, dot = "#4d80cd", "#3c3544"
    d.rectangle((x0, y0, x0 + bw - 1, y0 + bh - 1), fill="#3a1c57" if fill == DARK else "#2b1925")
    inset = 2
    d.rectangle((x0 + inset, y0 + inset, x0 + bw - inset - 1, y0 + bh - inset - 1), fill=fill)
    for x in range(x0 + inset + 8, x0 + bw - inset, 16):
        for y in range(y0 + inset + 8, y0 + bh - inset, 16):
            d.point((x, y), fill=dot)
    grid = "#3c3544" if fill == DARK else "#6b3e75"
    for x in range(x0 + inset, x0 + bw - inset, 64):
        d.line((x, y0 + inset, x, y0 + bh - inset - 1), fill=grid)
    for y in range(y0 + inset, y0 + bh - inset, 64):
        d.line((x0 + inset, y, x0 + bw - inset - 1, y), fill=grid)
    art = mm.outline_only(sprite("assets/sprites/station/b_drone.png"), line)
    art = art.resize((art.width * 2, art.height * 2), Image.NEAREST)
    ax, ay = x0 + (bw - art.width) // 2 - (100 if c.kind == "pc" else 130), y0 + (bh - art.height) // 2
    layer.alpha_composite(art, (ax, ay))
    for box in ((ax, ay - 8, ax + art.width, ay - 8), (ax, ay - 12, ax, ay - 4), (ax + art.width, ay - 12, ax + art.width, ay - 4),
                (ax + art.width + 8, ay, ax + art.width + 8, ay + art.height), (ax + art.width + 4, ay, ax + art.width + 12, ay), (ax + art.width + 4, ay + art.height, ax + art.width + 12, ay + art.height)):
        d.line(box, fill=line)
    sw, sh = (150, 44) if c.kind == "pc" else (190, 54)
    sx, sy = ax + art.width + 40, y0 + (bh - sh) // 2  # 안내판이 치수선을 덮지 않게
    sg = mm.nine(c.p["btn_off"], sw, sh, 12, c.p["btn_off"].height // 2 - 1)
    a = np.array(sg)
    a[(a[..., :3] == rgb(MUTED)).all(axis=2), :3] = rgb(GOLD)
    sg = Image.fromarray(a, "RGBA")
    text(draw(sg), sw // 2, (sh - 24) // 2 - 1, "건설 예정", F24, DARK, "ma")
    layer.alpha_composite(sg, (sx, sy))
    nb = plate(c, "tab", 188, 44)
    dn = draw(nb)
    text(dn, 94, 8, "드론 공장 설계도", c.s["small"], TEAL2, "ma", 178)
    text(dn, 94, 23, "완공되면 채굴 드론 제작", c.s["small"], INK, "ma", 178)
    layer.alpha_composite(nb, (sx + (sw - 188) // 2, sy + sh + 6))
    return layer


def make_drone(parts):
    for kind in ("pc", "phone"):
        c = mm.Ctx(parts, kind)
        tag = "pc_1280x720" if kind == "pc" else "phone_844x390"
        mm.compose(c, drone(c), 0, 1, 0).save(f"{OUT}drone_{tag}.png")
        mm.compose(c, drone(c, "#3a1c57"), 0, 1, 0).save(f"{OUT}drone_violet_{tag}.png")


def sanity():
    # 기존 강화 6개는 그대로: 칸, 5단계, 가격이 data.json과 같아야 한다
    real = [n for b in TREE.values() for n in b if isinstance(n, str)]
    assert sorted(real) == sorted(DATA["upgrades"]) and len(real) == 6, real
    assert all(len(DATA["upgrades"][n]["levels"]) == 6 for n in real)  # 1~5단계 + 최대 표시
    assert mm.node_state("max_hp", "hull", {"max_hp": 5}) == "max"
    assert mm.node_state("magnet", "mine", {"magnet": 2}) != "locked"  # 예전 저장 보호
    assert fork_state("hull", 2, {"insurance": 1}, {}) == "open" and fork_state("hull", 2, {"insurance": 0}, {}) == "plan"
    assert fork_state("hull", 2, {"insurance": 1}, {"hull": "a"}) == "chosen"
    # 더미: 개수가 늘수록 높아지고, 빈 칸은 비어 있다
    assert pile_height(0, 80) == 0 and pile_height(3, 80) < pile_height(23, 80) < pile_height(96, 80) < pile_height(412, 80) < pile_height(1000, 80) == 80
    assert {RANK_OF[e["id"]] for e in DATA["discovery"]} <= set(RANKS) and len(RANK_OF) == len(DATA["discovery"])
    assert sorted(REWARDS) == [3, 6, 9, 12]


SECTIONS = {"research": make_research, "storage": make_storage, "museum": make_museum, "hangar": make_hangar, "drone": make_drone}


def main():
    sanity()
    parts = load_parts2()
    for name in (sys.argv[1:] or SECTIONS):
        SECTIONS[name](parts)
    for w in sorted(set(WARN)):
        print(w)
    print("시안 저장. 글자 넘침", len(set(WARN)))


if __name__ == "__main__":
    main()
