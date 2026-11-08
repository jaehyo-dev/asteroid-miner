"""등급 확률 곡선과 봇 기반 등급 등장 수 추정 (게임 코드와 무관한 설계 계산).
입력: levelup_times.json (봇 4종 × 시드 100개의 레벨업 시각, levelup_times.gd.txt로 만듦). 시드 고정.
실행: python3 review/v070_step5/make_tables.py → 표 출력 + probability_curve.png"""
import json, random
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm

D = "review/v070_step5/"
GRADES = ["노멀", "레어", "에픽", "유니크", "레전드리"]
START = [55, 27, 12, 5, 1]
END = [35, 30, 20, 12, 3]  # RISK_RAMP_TIME(300초, 광물 보너스와 같은 시간)에 도달, 이후 고정
RAMP = 300.0
MULT = [1.0, 1.5, 2.0, 3.0]
EFFECT_SHARE = 0.6  # 에픽·유니크가 나왔을 때 효과 강화일 확률 (나머지는 수치 강화)
PITY = 2  # 효과 카드 없는 레벨업이 이만큼 이어지면 다음 3장 중 1장은 에픽 효과 확정
ROLLS = 200  # 판마다 카드 뽑기를 되풀이하는 횟수 (봇 판 100개 × 200)


def weights(t):
    p = min(t / RAMP, 1.0)
    return [a + (b - a) * p for a, b in zip(START, END)]


def simulate(runs, pity, rng):
    total = {"cards": 0, "effect": 0, "levelups": 0, "legend_runs": 0, "n": 0, "no_effect_runs": 0}
    grade = [0] * 5
    for run in runs:
        for _ in range(ROLLS):
            total["n"] += 1
            dry, legend, effects = 0, False, 0
            for t in run["levelups"]:
                total["levelups"] += 1
                seen = False
                cards = []
                for _c in range(3):
                    g = rng.choices(range(5), weights(t))[0]
                    # 한 화면에 레전드리는 1장까지
                    if g == 4 and 4 in cards:
                        g = 3
                    cards.append(g)
                eff = [g in (2, 3) and rng.random() < EFFECT_SHARE for g in cards]
                if pity and dry >= pity and not any(eff):
                    cards[0], eff[0] = max(cards[0], 2) if cards[0] != 4 else 2, True
                for g, e in zip(cards, eff):
                    grade[g] += 1
                    total["cards"] += 1
                    total["effect"] += e
                    effects += e
                    legend = legend or g == 4
                    seen = seen or e
                dry = 0 if seen else dry + 1
            total["legend_runs"] += legend
            total["no_effect_runs"] += effects == 0
    n = total["n"]
    return {"grade": [g / n for g in grade], "effect": total["effect"] / n, "legend_run": total["legend_runs"] / n, "no_effect": total["no_effect_runs"] / n}


data = json.load(open(D + "levelup_times.json"))
print("### 시간별 등급 확률 (%)\n\n| 시간 | " + " | ".join(GRADES) + " | 수치 강화 평균 배율 |\n|---|---|---|---|---|---|---|")
for m in [0, 1, 2, 3, 4, 5, 10]:
    w = weights(m * 60)
    mean = sum(x * y for x, y in zip(w[:4], MULT)) / sum(w[:4])
    print(f"| {m}분 | " + " | ".join(f"{x:.1f}" for x in w) + f" | ×{mean:.2f} |")

print("\n### 봇 추정 (봇 4종 × 100판, 판마다 카드 뽑기 200번, 레벨업 1번에 3장, 다시 뽑기 제외)\n")
print("| 봇 | 판 길이(초) | 레벨업 횟수 | 첫·마지막 레벨업(초) | 노멀 | 레어 | 에픽 | 유니크 | 레전드리 | 레전드리 본 판 | 효과 카드 수 | 효과 카드 0장 판 |\n|---|---|---|---|---|---|---|---|---|---|---|---|")
for pity in (0, PITY):
    if pity:
        print(f"| **보정 있음** (효과 카드 없는 레벨업 {PITY}번 뒤 확정) | | | | | | | | | | | |")
    else:
        print("| **보정 없음** | | | | | | | | | | | |")
    for style, runs in data.items():
        rng = random.Random(7)  # 표마다 같은 시드
        r = simulate(runs, pity, rng)
        lv = [len(x["levelups"]) for x in runs]
        first = [x["levelups"][0] for x in runs if x["levelups"]]
        last = [x["levelups"][-1] for x in runs if x["levelups"]]
        tm = sum(x["time"] for x in runs) / len(runs)
        print(f"| {style} | {tm:.0f} | {sum(lv) / len(lv):.1f} | {sum(first) / len(first):.0f} · {sum(last) / len(last):.0f} | " + " | ".join(f"{g:.1f}" if i < 4 else f"{g:.2f}" for i, g in enumerate(r["grade"])) + f" | {r['legend_run'] * 100:.0f}% | {r['effect']:.1f} | {r['no_effect'] * 100:.0f}% |")

# 곡선 그림: 등급마다 선 1개. 색은 게임의 등급 색, 값은 끝에 직접 표시
font = fm.FontProperties(fname="assets/fonts/galmuri/Galmuri11.ttf", size=12)
COLORS = ["#a5b29d", "#99e9e6", "#a884f3", "#f6ce50", "#f25c76"]
SURFACE, INK, MUTED = "#14111c", "#fef8e5", "#917487"
fig, ax = plt.subplots(figsize=(9, 5), dpi=100, facecolor=SURFACE)
ax.set_facecolor(SURFACE)
ts = [i * 6 for i in range(101)]
for i, g in enumerate(GRADES):
    ax.plot([t / 60 for t in ts], [weights(t)[i] for t in ts], color=COLORS[i], linewidth=2, label=g)
    ax.annotate(f"{g} {END[i]}%", (10, END[i]), xytext=(6, -4), textcoords="offset points", color=INK, fontproperties=font, annotation_clip=False)
ax.axvline(RAMP / 60, color=MUTED, linewidth=1, linestyle=":")
ax.text(RAMP / 60 + 0.08, 50, "5분부터 더 오르지 않음", color="#a5b29d", fontproperties=font)
ax.set_xlim(0, 10)
ax.set_ylim(0, 60)
ax.set_xlabel("출격 후 시간 (분)", color="#a5b29d", fontproperties=font)
ax.set_ylabel("카드 1장이 그 등급일 확률 (%)", color="#a5b29d", fontproperties=font)
ax.set_title("등급 확률 곡선 (시작 55/27/12/5/1 → 5분 35/30/20/12/3)", color=INK, fontproperties=font, loc="left")
ax.grid(axis="y", color="#3c3544", linewidth=0.6)
ax.tick_params(colors="#a5b29d", length=0)
for s in ax.spines.values():
    s.set_visible(False)
for lab in ax.get_xticklabels() + ax.get_yticklabels():
    lab.set_fontproperties(font)
leg = ax.legend(prop=font, frameon=False, loc="upper center", ncols=5, labelcolor=INK, bbox_to_anchor=(0.5, -0.13), borderaxespad=0.0, columnspacing=1.0, handlelength=1.2)
fig.subplots_adjust(right=0.86, left=0.08, top=0.92, bottom=0.2)
fig.savefig(D + "probability_curve.png", facecolor=SURFACE)
