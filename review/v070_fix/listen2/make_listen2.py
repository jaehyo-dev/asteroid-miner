"""v0.7.0 창 소리 2차 후보 (게임에 넣지 않음). 무거운 기계 건물이 떠오르고 내려앉는 소리.
열기 = 걸쇠 "철컹" → 유압 "위이잉" → 분사 "푸쉬" + "우웅". 닫기 = 분사 잦아듦 → "쿵" → 걸쇠 "철컥".
창 전환에 맞춘다: 열기는 0.18초에 멈추는 순간 "컹", 닫기는 0.14초에 끝나는 순간 "쿵".
금속·분사는 Kenney CC0 녹음(listen2/src/), 유압 서보와 낮은 울림은 numpy 합성.
실행: python3 review/v070_fix/listen2/make_listen2.py → door2_*.ogg, measure.md, wave.png"""
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import signal

sys.path[:0] = ["tools", "review/v070_fix/listen"]
import make_listen as ml  # 1차의 rec, env, finish, stats를 그대로 쓴다
from make_listen import active_rms, env, finish, rec, stats, trim_st
from make_sfx import SR, ffx, mix_st, peak, room, save, silence, stereo

HERE = "review/v070_fix/listen2/"
ml.SRC = HERE + "src/"
OPEN_STOP, CLOSE_STOP = 0.18, 0.14  # 창이 멈추는 때 (design.md 전환)
RMS_OPEN, RMS_CLOSE = -22.0, -25.0
HEAVY, HEAVY2, PLATE = "impactMetal_heavy_000.ogg", "impactMetal_heavy_002.ogg", "impactPlate_heavy_000.ogg"
MID, THRUST, AIR = "impactMetal_medium_001.ogg", "thrusterFire_000.ogg", "thrusterFire_004.ogg"


def servo(dur, f0, f1, curve=0.6, seed=1):
    """유압 서보 "위이잉": 음이 올라가는 톱니에 가까운 배음 + 기어 떨림 + 유압 잡음. 합성"""
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * t ** curve
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 38 * t * dur))  # 기어 떨림
    ph = 2 * np.pi * np.cumsum(f) / SR
    a = sum(w * np.sin(k * ph) for k, w in ((1, 1.0), (2, 0.55), (3, 0.38), (4, 0.2), (6, 0.1)))
    rng = np.random.default_rng(seed)
    a = np.tanh(1.5 * a) + 0.12 * rng.standard_normal(n)
    a = ffx(a.astype(np.float32), "lowpass=f=2600,highpass=f=170")[:n]
    return a * np.minimum(t * dur / 0.015, 1.0) * np.minimum((1 - t) * dur / 0.02, 1.0)


def rumble(dur, f=104, attack=0.02, decay=4.0, drive=2.4):
    """낮은 "우웅": 기본음이 폰 스피커에서 안 들리므로 일그러뜨려 2·3배음(180~400Hz)을 만든다. 합성"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * (f * t + 0.8 * np.sin(2 * np.pi * 7 * t) / 7)
    a = np.tanh(drive * (np.sin(ph) + 0.35 * np.sin(2.01 * ph)))
    return ffx(env(a.astype(np.float32), attack, decay), "highpass=f=95,lowpass=f=1100")[:n]


def thrust(dur, attack, decay, lo=380, hi=4800, seed=0.4, p=1.0):
    """분사 "푸쉬": 추진기 녹음에서 필요한 길이만"""
    body = rec(THRUST, seed, seed + dur, p=p, band=f"highpass=f={lo},lowpass=f={hi}")
    air = rec(AIR, seed, seed + dur, p=p, band=f"highpass=f={lo * 3},lowpass=f={hi}")  # "쉬" 부분
    return peak(env(body + air * 0.55, attack, decay), -1.0)


def at(t, snd):
    """소리가 올라서는 지점(최고점의 절반)이 t초에 오게 놓는다 (앞이 잘리지 않게 0에서 멈춤)"""
    m = np.abs(snd.mean(axis=1) if snd.ndim == 2 else snd)
    return max(t - float(np.argmax(m > m.max() * 0.5)) / SR, 0.0)


def clank(p=0.8, cut=0.22, src=HEAVY, band="lowpass=f=3400"):
    return rec(src, 0.0, cut, p, band=band)


def build_open(latch0, stop, srv, whine_end, puff, boom, length, seed):
    """latch0 = 처음 "철", stop = 0.18초 멈춤의 "컹", srv = 서보 크기, puff/boom = 분사·울림 크기"""
    parts = []
    click = clank(1.05, 0.12, MID)
    parts.append((0.0, stereo(click * latch0, -0.1)))
    s = servo(whine_end - 0.015, 190, 560 if whine_end > 0.25 else 460, seed=seed)
    # 서보가 멈춤 타격을 덮지 않게 그 순간 눌렀다가 천천히 다시 올린다 (빠르게 올리면 그게 또 하나의 타격처럼 들림)
    st = np.arange(len(s)) / SR + 0.015
    dt = st - OPEN_STOP
    s = s * (1 - 0.8 * np.where(dt < 0, np.exp(-(dt / 0.006) ** 2), np.exp(-dt / 0.07)))
    parts.append((0.015, stereo(s * srv, 0.1)))
    hit = clank(0.72, 0.26)
    ring = clank(0.86, 0.16, MID, "highpass=f=500,lowpass=f=4200")  # "컹"의 쇳소리. 폰에서는 이것이 무게를 전한다
    parts.append((at(OPEN_STOP, ring), stereo(ring * stop * 0.7, -0.05)))
    plate = rec(PLATE, 0.0, 0.2, 0.9, band="lowpass=f=2600")
    parts.append((at(OPEN_STOP, hit), stereo(hit * stop)))
    parts.append((at(OPEN_STOP, plate), stereo(plate * stop * 0.65, 0.05)))
    tail = length - OPEN_STOP
    parts.append((OPEN_STOP + 0.012, stereo(thrust(tail - 0.012, 0.05, 5.5) * puff, -0.12)))
    parts.append((OPEN_STOP + 0.008, stereo(rumble(tail - 0.008, attack=0.04, decay=5.0) * boom, 0.0)))
    return room(mix_st(parts), 0.09, 0.07, seed)


def build_close(puff, thud, lock, length, seed):
    """분사가 잦아듦 → 0.14초 "쿵" → 약 0.23초 걸쇠 "철컥". 열기보다 낮게"""
    fade = thrust(0.17, 0.004, 13.0, lo=200, hi=1500, seed=1.1, p=0.8)
    hum = rumble(0.17, f=84, attack=0.003, decay=12.0)
    down = clank(0.55, 0.2, HEAVY2, "lowpass=f=1500")
    plate = rec(PLATE, 0.0, 0.2, 0.68, band="lowpass=f=1400")
    click = clank(0.66, 0.09, MID, "lowpass=f=1500")
    parts = [(0.0, stereo(fade * puff, 0.1)), (0.0, stereo(hum * puff * 0.8)),
             (at(CLOSE_STOP, down), stereo(down * thud)), (at(CLOSE_STOP, plate), stereo(plate * thud * 0.7)),
             (0.235, stereo(click * lock, -0.08))]
    return room(mix_st(parts), 0.07, 0.05, seed)


# 비율만 다른 4개: latch0, stop, srv, whine_end, puff, boom, length / puff, thud, lock, length
CANDIDATES = {
    "A": ("걸쇠 위주", (0.85, 1.0, 0.16, 0.19, 0.2, 0.24, 0.48), (0.28, 0.9, 0.55, 0.36)),
    "B": ("유압 위주", (0.38, 0.62, 0.62, 0.42, 0.2, 0.2, 0.52), (0.42, 0.8, 0.42, 0.38)),
    "C": ("분사 위주", (0.4, 0.75, 0.2, 0.19, 0.95, 0.5, 0.58), (0.72, 0.8, 0.34, 0.4)),
    "D": ("셋을 고르게", (0.6, 0.72, 0.36, 0.26, 0.5, 0.42, 0.54), (0.46, 0.85, 0.45, 0.38)),
}


def transient(a, t, win=0.03):
    """t초 근처에서 소리가 가장 크게 올라서는 시각 (창 멈춤과 맞는지 확인용)"""
    # 서보 음의 주기 때문에 흔들리지 않게 쇳소리 대역만, 10ms 평균 크기가 10ms 전보다 가장 많이 커진 지점
    m = ffx(a.mean(axis=1).astype(np.float32), "highpass=f=700,lowpass=f=5000")[:len(a)]
    k = int(0.01 * SR)
    e = np.sqrt(np.maximum(signal.fftconvolve(m ** 2, np.ones(k) / k, "full")[:len(m)], 0))  # 시각 = 창의 끝
    d = e[k:] - e[:-k]
    lo, hi = int((t - win) * SR), int((t + win) * SR)
    return (lo + int(np.argmax(d[lo:hi]))) / SR


def phone(a):
    """폰 스피커 흉내: 200Hz 아래를 걷어 내도 얼마나 남나 (전체 대비 dB)"""
    m = a.mean(axis=1).astype(np.float32)
    f = ffx(m, "highpass=f=200,highpass=f=200")[:len(m)]
    return 20 * np.log10((f ** 2).mean() ** .5 / (m ** 2).mean() ** .5)


def sub(a):
    m = a.mean(axis=1)
    f, P = signal.welch(m, SR, nperseg=min(2048, len(m)))
    return P[f < 150].sum() / P.sum() * 100


def main():
    rows, wave = [], []
    for key, (name, op, cl) in CANDIDATES.items():
        o = finish(trim_st(build_open(*op, 300 + ord(key)), op[-1], 0.05), RMS_OPEN, 0.05)
        c = finish(trim_st(build_close(*cl, 400 + ord(key)), cl[-1], 0.04), RMS_CLOSE, 0.04)
        gap = stereo(silence(0.7))
        pair = np.concatenate([o, gap, c, stereo(silence(1.1)), o, gap, c])
        save(o, f"{HERE}door2_{key}_open.ogg")
        save(c, f"{HERE}door2_{key}_close.ogg")
        save(pair, f"{HERE}door2_{key}_pair.ogg")
        so, sc = stats(o), stats(c)
        to, tc = transient(o, OPEN_STOP), transient(c, CLOSE_STOP)
        assert 0.45 <= so["len"] <= 0.6 and sc["len"] <= 0.4, (key, so["len"], sc["len"])
        assert sc["c"] < so["c"], (key, sc["c"], so["c"])  # 닫기는 열기보다 낮게
        assert so["hi"] < 1 and sc["hi"] < 1, (key, so["hi"], sc["hi"])  # 9kHz 위 1% 미만
        assert abs(to - OPEN_STOP) < 0.02 and abs(tc - CLOSE_STOP) < 0.02, (key, to, tc)
        assert phone(o) > -6 and phone(c) > -8, (key, phone(o), phone(c))  # 폰에서도 들림
        assert sub(o) < 50 and sub(c) < 60, (key, sub(o), sub(c))  # 150Hz 아래만 있지 않게
        rows.append((key, name, so, sc, to, tc, phone(o), phone(c), sub(o), sub(c)))
        wave += [(f"{key} 열기", o), (f"{key} 닫기", c)]
    for tag in ("open", "close", "pair"):
        shutil.copy(f"review/v070_fix/listen/door_C_{tag}.ogg", f"{HERE}door1_C_{tag}.ogg")
    out = ["# 측정값 (make_listen2.py가 만듦, 귀로 듣지 못함)\n",
           "| 후보 | | 파일 길이 | 소리 길이(-30dB) | 무게중심 | 150Hz 아래 | 150~600Hz | 2~5kHz | 9kHz 위 | 200Hz 걷어 낸 크기 | 멈춤 타격 |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    for key, name, so, sc, to, tc, po, pc, uo, uc in rows:
        for tag, s, t, p, u in (("열기", so, to, po, uo), ("닫기", sc, tc, pc, uc)):
            out.append(f"| {key} {name} | {tag} | {s['len']:.2f}초 | {s['act']:.2f}초 | {s['c']:.0f}Hz | {u:.0f}% | {s['body']:.0f}% | {s['mid']:.0f}% | {s['hi']:.2f}% | {p:.1f}dB | {t:.3f}초 |")
    open(HERE + "measure.md", "w").write("\n".join(out) + "\n")
    print("\n".join(out))
    font = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 12)
    W, H = 900, 56
    im = Image.new("RGB", (W + 90, H * len(wave)), "#14111c")
    d = ImageDraw.Draw(im)
    for i, (name, a) in enumerate(wave):
        m, y0 = a.mean(axis=1), i * H + H // 2
        d.text((4, y0 - 7), name, font=font, fill="#fef8e5")
        sc_ = W / (0.6 * SR)  # 모두 같은 시간축 0.6초
        for x in range(min(W, int(len(m) * sc_))):
            v = float(np.abs(m[int(x / sc_):int((x + 1) / sc_)]).max()) / max(float(np.abs(m).max()), 1e-6)
            d.line((90 + x, y0 - v * 25, 90 + x, y0 + v * 25), fill="#30e1b9")
        tx = 90 + int((OPEN_STOP if "열기" in name else CLOSE_STOP) * W / 0.6)
        d.line((tx, i * H, tx, i * H + H), fill="#ffd34d")
    im.save(HERE + "wave.png")


if __name__ == "__main__":
    main()
