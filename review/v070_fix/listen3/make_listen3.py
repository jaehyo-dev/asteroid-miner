"""창 열기·닫기 3차 후보: 화면 패널이 켜지며 밀려 들어오는 가벼운 SF 인터페이스 소리 5짝. 합성 + Kenney CC0 녹음만.
열기 0.25초 안쪽(창이 멈추는 0.18초에 끝 소리), 닫기는 더 짧고 낮게(창이 사라지는 0.14초 안쪽).
실행: 저장소 맨 위에서 python3 review/v070_fix/listen3/make_listen3.py → 여기 *.ogg, 측정 표, 고른 2번은 assets/sfx/game/window_open·close.wav"""
import os
import sys

import numpy as np

sys.path[:0] = ["tools", "review/v070_fix/listen"]
import make_listen as ml  # noqa: E402
from make_listen import env, ffx, gain, rec, stats  # noqa: E402
from make_sfx import SR, decode, mix_st, peak, save, silence, stereo  # noqa: E402

HERE = "review/v070_fix/listen3/"
GAME = "assets/sfx/game/"
OPEN_MAX, CLOSE_MAX = 0.25, 0.16
OPEN_HIT, CLOSE_HIT = 0.18, 0.13  # 창이 멈추는·사라지는 때
GAME_DB = -12.0  # sfx.gd 재생 크기


def tone(freq0, freq1, dur, attack, decay, shape=0.0):
    """freq0에서 freq1로 미끄러지는 사인. shape를 주면 배음을 조금 더해 부드러운 전자음"""
    n = int(dur * SR)
    f = np.geomspace(freq0, freq1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return env((np.sin(ph) + shape * np.sin(2 * ph)).astype(np.float32), attack, decay)


def noise(dur, band, seed):
    rng = np.random.default_rng(seed)
    return ffx(rng.standard_normal(int(dur * SR)).astype(np.float32) * 0.3, band)[:int(dur * SR)]


def click(path, t1, p, band="highpass=f=200"):
    return rec(path, 0.0, t1, p, fade=0.005, band=band)


CLICK = "assets/sfx/kenney_interface/click_002.ogg"
SELECT = "assets/sfx/kenney_interface/select_002.ogg"
METAL = "kenney_rpg/metalClick.ogg"


def mix(parts, total):
    """(시각, 소리, 크기) 묶음을 total초 안에 놓는다"""
    out = np.zeros(int(total * SR), np.float32)
    for t, a, g in parts:
        i = int(t * SR)
        k = min(len(a), len(out) - i)
        out[i:i + k] += a[:k] * g
    out = ffx(out, "lowpass=f=6500,lowpass=f=6500")[:len(out)]  # 찌르는 고음 깎기
    k = int(0.012 * SR)
    out[-k:] *= np.linspace(1, 0, k)
    return peak(out, -1.0)


def holo():
    """1 홀로그램 화면 켜짐: 짧은 상승음 + 끝의 반짝"""
    o = mix([(0.0, tone(620, 1700, OPEN_HIT, 0.03, 4.0), 0.55), (OPEN_HIT - 0.01, tone(2500, 2600, 0.06, 0.002, 60.0), 0.3), (OPEN_HIT, tone(3300, 3400, 0.05, 0.002, 70.0), 0.18)], 0.25)
    c = mix([(0.0, tone(1000, 480, CLOSE_HIT, 0.005, 9.0), 0.6)], 0.15)
    return o, c


def pneu():
    """2 공기압 슉 + 작은 딸깍"""
    o = mix([(0.0, env(noise(OPEN_HIT, "highpass=f=1200,lowpass=f=5500", 31), 0.05, 12.0), 1.0), (OPEN_HIT - 0.005, click(METAL, 0.05, 1.5), 0.32)], 0.24)
    c = mix([(0.0, env(noise(0.11, "highpass=f=500,lowpass=f=2600", 32), 0.008, 22.0), 1.0), (0.1, click(METAL, 0.05, 0.95), 0.3)], 0.15)
    return o, c


def slide():
    """3 금속 패널 미끄러짐 스륵-탁 (가볍게): 좁은 잡음 띠 + 작은 쇠 소리"""
    a = noise(OPEN_HIT, "bandpass=f=3200:width_type=h:w=1600", 41) * (1 + 0.5 * np.sin(2 * np.pi * 90 * np.arange(int(OPEN_HIT * SR)) / SR))
    o = mix([(0.0, env(a.astype(np.float32), 0.04, 6.0), 1.0), (OPEN_HIT - 0.005, click("kenney_impact/impactPlate_light_001.ogg", 0.05, 1.5, "highpass=f=700"), 0.34)], 0.24)
    b = noise(0.1, "bandpass=f=1700:width_type=h:w=900", 42) * (1 + 0.5 * np.sin(2 * np.pi * 70 * np.arange(int(0.1 * SR)) / SR))
    c = mix([(0.0, env(b.astype(np.float32), 0.01, 16.0), 1.0), (0.095, click("kenney_impact/impactPlate_light_001.ogg", 0.04, 1.05, "highpass=f=400"), 0.3)], 0.14)
    return o, c


def beep():
    """4 단말기 삐빅 (부드럽게): 두 음. 닫기는 내려가는 낮은 두 음"""
    o = mix([(0.02, tone(880, 880, 0.09, 0.006, 22.0, 0.15), 0.5), (OPEN_HIT - 0.03, tone(1175, 1175, 0.08, 0.006, 26.0, 0.15), 0.5)], 0.24)
    c = mix([(0.0, tone(784, 784, 0.06, 0.004, 34.0, 0.15), 0.5), (0.065, tone(587, 587, 0.07, 0.004, 34.0, 0.15), 0.5)], 0.14)
    return o, c


def ring():
    """5 아주 짧은 클릭 + 은은한 울림"""
    o = mix([(0.0, click(CLICK, 0.04, 1.0), 0.55), (0.012, tone(660, 660, 0.23, 0.01, 11.0), 0.3), (0.012, tone(990, 990, 0.2, 0.01, 16.0), 0.14)], 0.25)
    c = mix([(0.0, click(CLICK, 0.03, 0.75), 0.55), (0.008, tone(440, 440, 0.12, 0.005, 20.0), 0.32)], 0.14)
    return o, c


def loud(a):
    """가장 큰 50ms 구간의 크기(dB): 길이가 다른 짧은 소리끼리 비교한다 (카드는 꼬리가 길어 전체 평균이 낮게 나온다)"""
    m = a.mean(axis=1) if a.ndim == 2 else a
    k = int(0.05 * SR)
    power = np.convolve(m ** 2, np.ones(k) / k, mode="valid") if len(m) >= k else np.array([(m ** 2).mean()])
    return float(10 * np.log10(power.max() + 1e-12))


def level(a, target):
    """게임에서 -12dB로 틀 때 target이 되게 파일 크기를 맞춘다 (-1dB를 넘지 않게)"""
    return a * min(gain(target - GAME_DB - loud(a)), gain(-1.0) / float(np.abs(a).max()))


CANDS = [("홀로그램 화면 켜짐", holo), ("공기압 슉 + 딸깍", pneu), ("금속 패널 스륵-탁", slide), ("단말기 삐빅", beep), ("클릭 + 은은한 울림", ring)]


def main():
    card = decode("review/v070_fix/listen/card_A_normal.ogg")
    card_loud = loud(card)
    target = card_loud - 3.0  # 창 소리는 카드 등장보다 3dB 작게
    pick = decode("assets/sfx/game/card_pick.wav")
    rows = []
    for n, (name, fn) in enumerate(CANDS, 1):
        o, c = fn()
        o, c = level(o, target), level(c, target - 2.0)  # 닫기는 조금 더 작게
        so, sc = stats(o), stats(c)
        assert len(o) / SR <= OPEN_MAX + 1e-3, (name, len(o) / SR)
        assert len(c) / SR <= CLOSE_MAX + 1e-3 and len(c) < len(o), (name, len(c) / SR)
        assert sc["c"] < so["c"], (name, "닫기가 더 낮아야", sc["c"], so["c"])
        assert so["hi"] < 3.0 and sc["hi"] < 3.0, name  # 찌르는 고음 없음
        game_o = loud(o) + GAME_DB
        assert game_o <= card_loud - 2.9, (name, "카드보다 작게", game_o, card_loud)
        save(stereo(o), f"{HERE}window_{n}_open.ogg", quality=6)
        save(stereo(c), f"{HERE}window_{n}_close.ogg", quality=6)
        gap = silence(0.7)
        save(stereo(np.concatenate([o, gap, c, silence(1.0), o, gap, c])), f"{HERE}window_{n}_pair.ogg", quality=5)
        if n == 2:  # 사용자가 고른 후보만 게임 파일로
            save(stereo(o), f"{GAME}window_open.wav")
            save(stereo(c), f"{GAME}window_close.wav")
        rows.append(f"| {n} {name} | {len(o) / SR:.2f}초 | {len(c) / SR:.2f}초 | {so['c']:.0f}Hz | {sc['c']:.0f}Hz | {game_o:.1f}dB |")
    table = "\n".join(["| 후보 | 열기 길이 | 닫기 길이 | 열기 무게중심 | 닫기 무게중심 | 열기 게임 크기(-12dB 재생, 가장 큰 50ms) |", "|---|---|---|---|---|---|", *rows])
    stc, stp = stats(card), stats(pick)
    table += f"\n\n비교: 카드 등장 A 노멀 {stc['c']:.0f}Hz, {card_loud:.1f}dB (0dB 재생). 카드 선택 e3 {stp['c']:.0f}Hz, {loud(pick) - 10:.1f}dB (-10dB 재생)."
    print(table)
    with open(HERE + "measure.md", "w") as f:
        f.write("# 측정값 (make_listen3.py가 만듦, 귀로 듣지 못함)\n\n" + table + "\n")


if __name__ == "__main__":
    main()
