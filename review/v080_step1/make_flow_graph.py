"""v0.8.0 1단계: 10분 판 흐름 그래프 (게임에 쓰지 않음).
지금(v0.7.0 balance.gd 값)과 10분 판 안(flow_10min.md의 임시 수치)을 같은 축에 그린다.
실행: 저장소 맨 위에서 python3 review/v080_step1/make_flow_graph.py → review/v080_step1/flow_graph.png"""
from PIL import Image, ImageDraw, ImageFont

OUT = "review/v080_step1/flow_graph.png"
FONT = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 12)
BG, PANEL, GRID, INK, MUTED = (24, 20, 30), (36, 30, 44), (58, 50, 70), (230, 226, 236), (150, 142, 164)
NOW, NEW, BOSS, OVER = (120, 132, 150), (80, 220, 200), (220, 70, 90), (240, 190, 70)
T_END = 660  # 11분까지 그림
MID_BOSS, FINAL_BOSS, OVERTIME = (270, 315), (480, 525), 525  # 보스전 구간(초), 추가 시간 시작


def lerp(a, b, k):
    return a + (b - a) * max(0.0, min(1.0, k))


# ── 지금 (balance.gd v0.7.0) ──────────────────────
def spawn_now(t):  # 초당 운석 수
    iv = lerp(1.15, 0.17, t / 240) if t <= 240 else max(0.17 * 0.5 ** ((t - 240) / 55), 0.03)
    return 1 / iv


def dmg_now(t):
    return min(1 + 0.25 * max((t - 210) // 60, 0), 2.5)


def hp_now(t):
    late = max(t - 270, 0) / 60
    return (1 + t // 75) * (1 + late * late * 0.6)


def risk_now(t):
    return lerp(1.0, 2.0, t / 300)


# ── 10분 판 안 (임시) ─────────────────────────────
def in_boss(t):
    return MID_BOSS[0] <= t < MID_BOSS[1] or FINAL_BOSS[0] <= t < FINAL_BOSS[1]


def spawn_new(t):
    if t <= 480:
        iv = lerp(1.15, 0.17, t / 480)
    elif t < OVERTIME:
        iv = 0.17
    else:
        iv = max(0.17 * 0.5 ** ((t - OVERTIME) / 55), 0.03)
    return (1 / iv) * (0.5 if in_boss(t) else 1.0)  # 보스전 중 일반 적 절반


def dmg_new(t):
    return min(1 + 0.25 * max((t - 300) // 60, 0), 2.5)


def hp_new(t):
    late = max(t - OVERTIME, 0) / 60
    return (1 + t // 150) * (1 + late * late * 0.6)


def risk_new(t):
    if t < OVERTIME:
        return lerp(1.0, 2.0, t / 480)
    return min(2.0 + 0.2 * ((t - OVERTIME) // 30 + 1), 3.0)  # 추가 시간: 30초마다 +0.2, 최대 3배


# 목표 레벨 (분, 레벨)과 지금 봇 측정 참고(일반 진행·best, 죽은 시각의 레벨 중앙값)
LEVEL_TARGET = [(0, 1), (1, 4), (2, 7), (3, 10), (4.5, 14), (6, 17), (7.5, 21), (8, 22), (9, 24), (10, 26), (11, 28)]
LEVEL_NOW = [(0, 1), (3.5, 6), (4.5, 7), (5.5, 18), (6.5, 27.5)]
SUBS = [(0.5, 1), (2, 2), (3.5, 3)]  # 보조 무기 개수가 늘어나는 시각(분)
EVOLVE = 7.25  # 첫 진화 (분)


def panel(d, box, title, ymax, series, yfmt="{:.1f}"):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=PANEL)
    d.text((x0 + 8, y0 + 4), title, font=FONT, fill=INK)
    px0, py0, px1, py1 = x0 + 44, y0 + 24, x1 - 10, y1 - 22
    X = lambda t: px0 + (px1 - px0) * t / T_END
    Y = lambda v: py1 - (py1 - py0) * min(v, ymax) / ymax
    for a, b in (MID_BOSS, FINAL_BOSS):
        d.rectangle((X(a), py0, X(b), py1), fill=(70, 34, 48))
    d.rectangle((X(OVERTIME), py0, X(T_END), py1), outline=None, fill=(56, 48, 34))
    d.rectangle((X(FINAL_BOSS[0]), py0, X(FINAL_BOSS[1]), py1), fill=(70, 34, 48))
    for m in range(0, 12):
        d.line((X(m * 60), py0, X(m * 60), py1), fill=GRID)
        d.text((X(m * 60) - 3, py1 + 4), str(m), font=FONT, fill=MUTED)
    for k in range(5):
        v = ymax * k / 4
        d.line((px0, Y(v), px1, Y(v)), fill=GRID)
        d.text((x0 + 4, Y(v) - 7), yfmt.format(v), font=FONT, fill=MUTED)
    for fn, color in series:
        pts = [(X(t), None if fn(t) is None else Y(fn(t))) for t in range(0, T_END + 1, 2)]
        d.line(pts, fill=color, width=2)
    return X, Y


def main():
    W, H = 1280, 900
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.text((16, 10), "10분 판 흐름: 회색 = 지금(v0.7.0), 청록 = 10분 판 안(임시)   빨강 띠 = 보스전(4:30 중간, 8:00 최종)   노랑 바탕 = 추가 시간(최종 보스 뒤)", font=FONT, fill=INK)
    half = (W - 48) // 2
    boxes = [(16, 32, 16 + half, 312), (32 + half, 32, W - 16, 312), (16, 324, 16 + half, 604), (32 + half, 324, W - 16, 604)]
    panel(d, boxes[0], "운석 등장 (초당 개수, 보스전 중 절반)", 12, [(spawn_now, NOW), (spawn_new, NEW)], "{:.0f}")
    panel(d, boxes[1], "적 피해 배율", 3.0, [(dmg_now, NOW), (dmg_new, NEW)])
    panel(d, boxes[2], "운석 체력 배율 (계단 + 후반 제곱)", 12, [(hp_now, NOW), (hp_new, NEW)], "{:.0f}")
    panel(d, boxes[3], "광물 배율 (위험도)", 3.2, [(risk_now, NOW), (risk_new, NEW)])

    # 레벨·무기 패널
    box = (16, 616, W - 16, H - 12)
    lv = lambda pts: (lambda t: _interp(pts, t / 60))
    X, Y = panel(d, box, "레벨 (청록 = 목표, 회색 = 지금 봇 참고: 일반 진행·좋은 카드, 죽은 시각의 레벨)   ◆ 보조 무기 획득   ★ 첫 진화", 30,
                 [(lambda t: _interp(LEVEL_NOW, t / 60) if t <= 390 else None, NOW), (lv(LEVEL_TARGET), NEW)], "{:.0f}")
    for m, n in SUBS:
        x, y = X(m * 60), Y(_interp(LEVEL_TARGET, m))
        d.polygon([(x, y - 6), (x + 6, y), (x, y + 6), (x - 6, y)], fill=OVER)
        d.text((x + 8, y - 18), f"보조 {n}", font=FONT, fill=OVER)
    x, y = X(EVOLVE * 60), Y(_interp(LEVEL_TARGET, EVOLVE))
    d.regular_polygon((x, y, 8), 5, fill=(255, 120, 200))
    d.text((x - 40, y - 24), "첫 진화", font=FONT, fill=(255, 120, 200))
    im.save(OUT)


def _interp(pts, m):
    if m is None or m > pts[-1][0]:
        return None
    for (a, va), (b, vb) in zip(pts, pts[1:]):
        if a <= m <= b:
            return va + (vb - va) * (m - a) / (b - a)
    return pts[-1][1]


# 선이 없는 구간(None)은 건너뛰도록 panel의 선 그리기를 감싼다
_orig_line = ImageDraw.ImageDraw.line


def _safe_line(self, xy, *a, **k):
    if isinstance(xy, list):
        seg = []
        for p in xy:
            if p[1] is None:
                if len(seg) > 1:
                    _orig_line(self, seg, *a, **k)
                seg = []
            else:
                seg.append(p)
        if len(seg) > 1:
            _orig_line(self, seg, *a, **k)
        return
    _orig_line(self, xy, *a, **k)


ImageDraw.ImageDraw.line = _safe_line

if __name__ == "__main__":
    main()
