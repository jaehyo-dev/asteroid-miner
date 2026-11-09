"""측정 결과(JSON) → 표 (점검용). 사용: python3 summarize.py <out 폴더>
상태마다 봇 4종 × 시드 50판 평균. 피격·처치는 1분당으로 바꿔 생존 시간 차이를 뺀다."""
import json
import os
import sys

STYLES = ["collector", "flee", "wander", "returner"]


def load(folder):
    rows = {}
    for name in sorted(os.listdir(folder)):
        with open(os.path.join(folder, name)) as f:
            text = f.read().strip()
        if text:
            rows[name[:-5]] = json.loads(text)
    return rows


def stats(runs):
    n = len(runs)
    t = sum(r["t"] for r in runs) / n
    minutes = sum(r["t"] for r in runs) / 60.0
    return {
        "t": t,
        "dead": 100.0 * sum(not r["alive"] and not r["ret"] for r in runs) / n,
        "ten": 100.0 * sum(r["alive"] and r["t"] >= 599 for r in runs) / n,
        "hits_m": sum(r["hits"] for r in runs) / minutes,
        "lost_m": sum(r["lost"] for r in runs) / minutes,
        "blocks": sum(r["blocks"] for r in runs) / n,
        "kills_m": sum(r["kills"] for r in runs) / minutes,
        "value": sum(r["value"] for r in runs) / n,
        "home": sum(r["home"] for r in runs) / n,
        "lv": sum(r["lv"] for r in runs) / n,
    }


def main():
    rows = load(sys.argv[1])
    print("| 상태 | 봇 | 생존(초) | 사망% | 10분 생존% | 피격/분 | 체력 손실/분 | 실드 막음/판 | 처치/분 | 광물 가치/판 | 가져간 가치/판 | 레벨 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for key, data in rows.items():
        for style in STYLES + ["전체"]:
            runs = sum(data["runs"].values(), []) if style == "전체" else data["runs"][style]
            s = stats(runs)
            print(f"| {key} | {style} | {s['t']:.0f} | {s['dead']:.0f} | {s['ten']:.0f} | {s['hits_m']:.2f} | {s['lost_m']:.1f} | {s['blocks']:.1f} | {s['kills_m']:.0f} | {s['value']:.0f} | {s['home']:.0f} | {s['lv']:.1f} |")


if __name__ == "__main__":
    main()
