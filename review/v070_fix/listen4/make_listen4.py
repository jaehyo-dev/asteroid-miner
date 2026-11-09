"""UI 버튼 소리 후보 4개 (+강화용 밝은 소리): 창 소리 2번 "공기압 슉 + 딸깍"과 어울리는 부드럽고 짧은 "톡". 합성 + Kenney CC0 녹음만.
실행: 저장소 맨 위에서 python3 review/v070_fix/listen4/make_listen4.py → 여기 *.ogg, measure.md, assets/sfx/game/click_N(_up).wav"""
import sys

import numpy as np

sys.path[:0] = ["tools", "review/v070_fix/listen", "review/v070_fix/listen3"]
from make_listen import env, ffx, gain, stats  # noqa: E402
from make_listen3 import METAL, click, loud, noise, tone  # noqa: E402
from make_sfx import SR, decode, peak, save, silence, stereo  # noqa: E402

HERE = "review/v070_fix/listen4/"
GAME = "assets/sfx/game/"
MAX_LEN = 0.08
CLICK_DB, UP_DB = -8.0, -11.0  # sfx.gd 재생 크기
BELOW_WINDOW = 2.0  # 창 소리(가장 큰 50ms)보다 이만큼 작게. 소리가 짧아 전체 에너지는 훨씬 작다
UP_LOUDER = 1.0  # 강화는 살짝 크게


def mix(parts, total):
    """(시각, 소리, 크기) 묶음. 부드럽게 고음을 깎고 끝을 닫는다"""
    out = np.zeros(int(total * SR), np.float32)
    for t, a, g in parts:
        i = int(t * SR)
        k = min(len(a), len(out) - i)
        out[i:i + k] += a[:k] * g
    out = ffx(out, "lowpass=f=4500,lowpass=f=4500")[:len(out)]
    k = int(0.008 * SR)
    out[-k:] *= np.linspace(1, 0, k)
    return peak(out, -1.0)


def soft(p):
    """1 부드러운 톡: 아래로 살짝 떨어지는 둥근 사인, 나무 건반 느낌"""
    return mix([(0.0, tone(640 * p, 430 * p, 0.065, 0.0015, 55.0, 0.12), 1.0)], 0.07)


def air(p):
    """2 작은 공기 톡: 창 소리의 슉을 아주 짧게 + 아래를 받치는 작은 사인"""
    band = f"highpass=f={int(1100 * p)},lowpass=f={int(3600 * p)}"
    return mix([(0.0, env(noise(0.05, band, 51), 0.003, 70.0), 1.0), (0.0, tone(360 * p, 300 * p, 0.04, 0.002, 80.0), 0.4)], 0.06)


def low(p):
    """3 낮은 딸깍: 창 소리의 딸깍과 같은 재료를 낮춰 둥글게 + 몸통 사인"""
    return mix([(0.0, click(METAL, 0.05, 0.72 * p, "lowpass=f=2400"), 0.55), (0.0, tone(250 * p, 190 * p, 0.05, 0.001, 70.0), 0.8)], 0.06)


def holo(p):
    """4 짧은 홀로그램 톡: 살짝 올라가는 짧은 음 + 작은 반짝"""
    return mix([(0.0, tone(820 * p, 1180 * p, 0.05, 0.002, 60.0), 1.0), (0.012, tone(2350 * p, 2400 * p, 0.03, 0.001, 110.0), 0.14)], 0.065)


def level(a, target, play_db):
    """게임에서 play_db로 틀 때 target이 되게 파일 크기를 맞춘다"""
    return a * min(gain(target - play_db - loud(a)), gain(-1.0) / float(np.abs(a).max()))


CANDS = [("부드러운 톡", soft), ("작은 공기 톡", air), ("낮은 딸깍", low), ("짧은 홀로그램 톡", holo)]


def main():
    window = decode(GAME + "window_open.wav")
    window_game = loud(window) - 12.0  # sfx.gd 재생 크기
    target = window_game - BELOW_WINDOW
    now = decode(GAME + "click.wav")
    rows = []
    for n, (name, fn) in enumerate(CANDS, 1):
        c = level(fn(1.0), target, CLICK_DB)
        u = level(fn(1.22), target + UP_LOUDER, UP_DB)  # 강화: 같은 소리를 살짝 높고 밝게
        for a, what in ((c, "기본"), (u, "강화")):
            assert len(a) / SR <= MAX_LEN + 1e-3, (name, what, len(a) / SR)
            assert stats(a)["hi"] < 3.0, (name, what)
        sc, su = stats(c), stats(u)
        assert su["c"] > sc["c"], (name, "강화가 더 밝아야")
        game = loud(c) + CLICK_DB
        assert game < window_game, (name, "창 소리보다 작게", game, window_game)
        save(stereo(c), f"{GAME}click_{n}.wav")
        save(stereo(u), f"{GAME}click_{n}_up.wav")
        save(stereo(c), f"{HERE}click_{n}.ogg", quality=6)
        save(stereo(u), f"{HERE}click_{n}_up.ogg", quality=6)
        # 들어 보기용: 천천히 3번, 연타 6번(음높이 흔들림 ±5%), 강화 1번
        gap, fast = silence(0.45), silence(0.09)
        rng = np.random.default_rng(n)
        taps = []
        for _ in range(6):
            p = 1.0 + rng.uniform(-0.05, 0.05)
            taps += [np.interp(np.arange(0, len(c), p), np.arange(len(c)), c).astype(np.float32), fast]
        save(stereo(np.concatenate([c, gap, c, gap, c, gap, *taps, gap, u])), f"{HERE}click_{n}_demo.ogg", quality=5)
        rows.append(f"| {n} {name} | {len(c) / SR:.3f}초 | {sc['c']:.0f}Hz | {su['c']:.0f}Hz | {game:.1f}dB |")
    table = "\n".join(["| 후보 | 길이 | 무게중심 | 강화 무게중심 | 게임 크기(가장 큰 50ms) |", "|---|---|---|---|---|", *rows])
    table += f"\n\n비교: 지금 click {len(now) / SR:.3f}초, {stats(now)['c']:.0f}Hz, {loud(now) + CLICK_DB:.1f}dB. 창 열기 2번 {stats(window)['c']:.0f}Hz, {window_game:.1f}dB."
    print(table)
    with open(HERE + "measure.md", "w") as f:
        f.write("# 측정값 (make_listen4.py가 만듦, 귀로 듣지 못함)\n\n" + table + "\n")


if __name__ == "__main__":
    main()
