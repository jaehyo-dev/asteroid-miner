"""v0.7.0 최종 피드백 소리 후보 (게임에 넣지 않음).
창 열기·닫기 4짝(A~D), 카드 등장 4종(A~D) + 등급 울림. 카드 후보는 실제 녹음(CC0)만 쓰고 합성음은 넣지 않는다.
실행: python3 review/v070_fix/listen/make_listen.py → review/v070_fix/listen/*.ogg, measure.md, wave.png"""
import hashlib
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import signal

sys.path.insert(0, "tools")
from make_sfx import SR, decode, ffx, mix_st, peak, room, save, silence, stereo  # noqa: E402

HERE = "review/v070_fix/listen/"
SRC = HERE + "src/"
E3_PATH = "assets/sfx/game/card_pick.wav"
E3_MD5 = "daba8747559c91d23dcf5757d78197dc"  # 사용자가 고른 e3. 절대 바꾸지 않는다
E3_DB = -10.0
# e3 원본에 건 것과 같은 음색 처리: 얇은 금속 녹음의 몸통을 올리고 높은 쪽을 깎아 같은 소리 계열로 맞춘다
E3_EQ = "equalizer=f=450:t=q:w=1.2:g=12,equalizer=f=1200:t=q:w=1:g=5,highshelf=f=6500:g=-11:t=q:w=0.7,lowpass=f=12000"
# 게임 카드 시간표 (scripts/juice.gd): 카드 간격, 앞면이 보이기까지, 레전드리 모임
STAGGER, REVEAL, LEGEND_GAP = 0.28, 0.16, 0.34
RELOAD = "assets/sfx/zer0_sol_reload/reload.wav"


def rec(path: str, t0: float = 0.0, t1: float | None = None, p: float = 1.0, fade: float = 0.02, band: str = "") -> np.ndarray:
    """녹음 조각: 잘라서 앞뒤 튐을 없애고, 테이프처럼 음 높이를 바꾸고, 필터를 건다. -1dB로 맞춤"""
    a = decode(path if path.startswith("assets") else SRC + path)
    a = a[int(t0 * SR):None if t1 is None else int(t1 * SR)].copy()
    if p != 1.0:
        a = ffx(a, f"asetrate={SR * p:.0f},aresample={SR}")
    if band:
        a = ffx(a, band)[:len(a)]
    n, k = int(0.002 * SR), int(fade * SR)
    a[:n] *= np.linspace(0, 1, n)
    a[-k:] *= np.linspace(1, 0, k)
    return peak(a.astype(np.float32), -1.0)


def env(a: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """모양 입히기: attack초 동안 커지고 이후 decay(1초당 줄어드는 비율)로 줄어듦"""
    t = np.arange(len(a)) / SR
    return a * np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-decay * np.maximum(t - attack, 0.0))


def finish(a: np.ndarray, target_rms_db: float | None = None, tail: float = 0.03) -> np.ndarray:
    """80Hz 아래 제거, 9kHz 위 깎기, 끝 정리. 채널별로 처리하고 활성 구간 크기를 맞춘다"""
    chain = "highpass=f=80,highpass=f=80,highshelf=f=8000:g=-9:t=q:w=0.7"
    done = np.stack([ffx(a[:, ch], chain)[:len(a)] for ch in (0, 1)], axis=1)
    k = min(int(SR * tail), len(done))
    done[-k:] *= np.linspace(1, 0, k)[:, None]
    done = done / max(float(np.abs(done).max()), 1e-9) * 10 ** (-1 / 20)
    if target_rms_db is not None:
        # 크기를 맞추되 -1dB를 넘지 않게
        done = done * min(10 ** ((target_rms_db - active_rms(done)) / 20), 10 ** (-1 / 20) / float(np.abs(done).max()))
    return done.astype(np.float32)


def active_rms(a: np.ndarray) -> float:
    """최고점 -30dB 안쪽 구간의 평균 크기 (dB). 짧은 소리끼리 크기를 비교할 때 쓴다"""
    m = a.mean(axis=1) if a.ndim == 2 else a
    idx = np.where(np.abs(m) > np.abs(m).max() * 10 ** (-30 / 20))[0]
    return float(20 * np.log10(np.sqrt((m[idx[0]:idx[-1] + 1] ** 2).mean()) + 1e-9))


# ── 1) 창 열기·닫기: 카드 소리와 재료를 나눠 쓰지 않는다 ───────────────
DOOR_RMS = -24.0  # 파일 크기. 게임 재생 크기는 고른 뒤 sfx.gd에서 맞춘다


def hiss(p: str, t: float, attack: float, decay: float, band: str, seed: float = 1.0) -> np.ndarray:
    """에어 소리: 긴 추진기 잡음 녹음에서 필요한 길이만 잘라 모양을 입힘"""
    return peak(env(rec(p, seed, seed + t, band=band), attack, decay), -1.0)


def door_a():
    """에어록 "치익-턱": 공기 빠지는 소리 뒤 잠금이 풀리는 금속음"""
    air = hiss("kenney_scifi/thrusterFire_004.ogg", 0.24, 0.012, 11.0, "highpass=f=1100,lowpass=f=4800")
    latch = rec("kenney_rpg/chop.ogg", 0.04, 0.2, 0.8, band="lowpass=f=4500")
    body = rec("kenney_impact/impactPlate_light_003.ogg", 0.0, 0.14, 0.9)
    open_ = mix_st([(0.0, stereo(air * 0.45, -0.15)), (0.2, stereo(latch * 0.8, 0.05)), (0.2, stereo(body * 0.55))])
    latch2 = rec("kenney_rpg/chop.ogg", 0.04, 0.16, 0.62, band="lowpass=f=3000")
    body2 = rec("kenney_impact/impactPlate_light_003.ogg", 0.0, 0.12, 0.72)
    air2 = hiss("kenney_scifi/thrusterFire_004.ogg", 0.12, 0.004, 26.0, "highpass=f=700,lowpass=f=2800", 2.0)
    close = mix_st([(0.0, stereo(latch2 * 0.8, -0.05)), (0.0, stereo(body2 * 0.6)), (0.05, stereo(air2 * 0.28, 0.15))])
    return room(open_, 0.09, 0.08, 201), room(close, 0.08, 0.07, 202)


def door_b():
    """금속 패널이 옆으로 밀림: 쇠 긁힘을 낮춰 묵직한 "스르륵" + 끝에 멈춤 "탁" """
    slide = env(rec("kenney_rpg/knifeSlice2.ogg", 0.02, 0.38, 0.58, band="highpass=f=350,lowpass=f=3400"), 0.03, 3.0)
    stop = rec("kenney_impact/impactMetal_light_000.ogg", 0.0, 0.1, 0.62, band="lowpass=f=3200")
    body = rec("kenney_impact/impactPlate_light_003.ogg", 0.0, 0.12, 1.0)
    open_ = mix_st([(0.0, stereo(slide[:int(0.23 * SR)] * 0.55, -0.35)), (0.2, stereo(stop * 0.5, 0.25)), (0.2, stereo(body * 0.5, 0.2))])
    slide2 = env(rec("kenney_rpg/knifeSlice2.ogg", 0.02, 0.26, 0.48, band="highpass=f=300,lowpass=f=2600"), 0.015, 5.0)
    stop2 = rec("kenney_impact/impactMetal_light_000.ogg", 0.0, 0.09, 0.5, band="lowpass=f=2400")
    close = mix_st([(0.0, stereo(slide2[:int(0.15 * SR)] * 0.5, 0.3)), (0.13, stereo(stop2 * 0.5, -0.2)), (0.13, stereo(body[:int(.09 * SR)] * 0.55, -0.15))])
    return room(open_, 0.08, 0.07, 203), room(close, 0.07, 0.06, 204)


def door_c():
    """짧은 유압 해치: 낮은 압력음이 빠지면서 무거운 판이 "쿵" """
    press = hiss("kenney_scifi/thrusterFire_003.ogg", 0.3, 0.05, 7.0, "highpass=f=120,lowpass=f=1500")
    air = hiss("kenney_scifi/thrusterFire_004.ogg", 0.18, 0.03, 12.0, "highpass=f=900,lowpass=f=3400", 3.0)
    thud = rec("kenney_impact/impactPlate_medium_000.ogg", 0.0, 0.2, 0.95, band="lowpass=f=2600")
    open_ = mix_st([(0.0, stereo(press * 0.7)), (0.04, stereo(air * 0.3, 0.2)), (0.2, stereo(thud * 0.75))])
    press2 = hiss("kenney_scifi/thrusterFire_003.ogg", 0.16, 0.02, 14.0, "highpass=f=100,lowpass=f=1000", 2.0)
    thud2 = rec("kenney_impact/impactPlate_medium_000.ogg", 0.0, 0.16, 0.78, band="lowpass=f=1800")
    close = mix_st([(0.0, stereo(press2 * 0.6)), (0.1, stereo(thud2 * 0.8))])
    return room(open_, 0.1, 0.07, 205), room(close, 0.08, 0.06, 206)


def tone(freq: float, dur: float) -> np.ndarray:
    """부드러운 단말기 음: 기본음에 약한 2배음. 시작·끝을 둥글게 해서 찌르지 않게"""
    t = np.arange(int(dur * SR)) / SR
    a = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(4 * np.pi * freq * t)
    return (a * np.minimum(t / 0.006, 1.0) * np.minimum((dur - t) / 0.02, 1.0) * np.exp(-6 * t)).astype(np.float32)


def door_d():
    """단말기 "삑-딸깍": 낮은 두 음 + 실제 버튼 딸깍. 삑은 2kHz 아래에 둔다"""
    click = rec("kenney_rpg/metalClick.ogg", 0.08, 0.2, 0.85, band="lowpass=f=5000")
    body = rec("kenney_impact/impactPlate_light_003.ogg", 0.0, 0.08, 1.15)
    open_ = mix_st([(0.0, stereo(tone(784, 0.07) * 0.3)), (0.06, stereo(tone(1047, 0.1) * 0.3)), (0.15, stereo(click * 0.85)), (0.15, stereo(body * 0.4))])
    click2 = rec("kenney_rpg/metalClick.ogg", 0.08, 0.17, 0.68, band="lowpass=f=3400")
    close = mix_st([(0.0, stereo(click2 * 0.85)), (0.0, stereo(body * 0.4)), (0.045, stereo(tone(587, 0.09) * 0.3))])
    return room(open_, 0.07, 0.06, 207), room(close, 0.06, 0.05, 208)


# ── 2) 카드 등장: 전부 실제 녹음. e3와 같은 EQ로 질감을 맞춘다 ──────────
def eq(a: np.ndarray) -> np.ndarray:
    return peak(ffx(a, E3_EQ)[:len(a)].astype(np.float32), -1.0)


def card_a():
    """금속 위로 미끄러져 나옴: 카드 미끄러짐 + 칼 뽑는 쇳소리 + 끝에 작은 금속 탁. 탁이 앞면이 보이는 순간"""
    slide = eq(rec("kenney_rpg/drawKnife2.ogg", 0.0, 0.17, 1.1, fade=0.03))
    card = rec("kenney_casino/card-slide-4.ogg", 0.03, 0.14, 1.0)
    tap = eq(rec("kenney_impact/impactMetal_light_004.ogg", 0.0, 0.07, 0.92))
    return mix_st([(0.0, stereo(slide * 0.55, -0.15)), (0.0, stereo(card * 0.35)), (0.1, stereo(tap * 0.7, 0.1))]), 0.1


def card_b():
    """탄창 끼우는 "착": e3와 같은 권총 녹음의 탄창 구간이라 질감이 가장 같다"""
    mag = eq(rec(RELOAD, 0.585, 0.81, fade=0.05))
    return stereo(mag), float(np.argmax(np.abs(mag)) / SR)


def card_c():
    """금속판이 펼쳐짐: 얇은 판이 차례로 튀는 틱-틱-착 + 판 몸통"""
    t1 = eq(rec("kenney_impact/impactMetal_light_001.ogg", 0.0, 0.05, 0.78))
    t2 = eq(rec("kenney_impact/impactMetal_light_004.ogg", 0.0, 0.05, 0.9))
    t3 = eq(rec("kenney_impact/impactMetal_light_002.ogg", 0.0, 0.09, 1.0))
    body = rec("kenney_impact/impactPlate_light_001.ogg", 0.0, 0.11, 1.0)
    return mix_st([(0.0, stereo(t1 * 0.35, -0.3)), (0.04, stereo(t2 * 0.5, 0.25)), (0.09, stereo(t3 * 0.85, 0.0)), (0.09, stereo(body * 0.55))]), 0.09


def card_d():
    """딜러가 카드를 돌림: 실제 카드 튕김 + 금속 울림"""
    flick = rec("kenney_casino/card-shove-1.ogg", 0.09, 0.26)
    ring = eq(rec("kenney_impact/impactMetal_light_003.ogg", 0.0, 0.16, 0.85, fade=0.06))
    hit = float(np.argmax(np.abs(flick)) / SR)
    return mix_st([(0.0, stereo(flick * 0.8, -0.1)), (hit, stereo(ring * 0.5, 0.15))]), hit


CARDS = {"A": ("금속 위 미끄러짐", card_a, 203), "B": ("탄창 끼우는 착", card_b, 204), "C": ("금속판 펼침", card_c, 205), "D": ("딜러 + 금속 울림", card_d, 206)}


def ring_layer(level: int) -> np.ndarray:
    """등급 울림 (실제 쇠종 녹음을 올려 은은하게). 1 = 에픽, 2 = 유니크, 3 = 레전드리"""
    a = rec("kenney_impact/impactBell_heavy_000.ogg", 0.0, 1.2, 1.6, fade=0.3, band="highpass=f=300,lowpass=f=3800")
    if level == 1:
        return room(stereo(env(a, 0.012, 1.5) * 0.24), 0.5, 0.25, 211)
    if level == 2:
        return room(stereo(env(a, 0.012, 1.2) * 0.32), 0.6, 0.28, 212)
    b = env(rec("kenney_impact/impactBell_heavy_001.ogg", 0.0, 1.2, 2.4, fade=0.3, band="highpass=f=500,lowpass=f=4500"), 0.02, 0.8)
    return room(mix_st([(0.0, stereo(env(a, 0.012, 0.8) * 0.5, -0.2)), (0.02, stereo(b * 0.4, 0.25))]), 0.8, 0.3, 213)


def swell(dur: float) -> np.ndarray:
    """유니크·레전드리의 모임: 옛 card_swell·card_gather 대신. 쇠 울림 녹음을 거꾸로 틀어 쌓이는 느낌"""
    a = rec("kenney_impact/impactMetal_light_003.ogg", 0.0, 0.3, 0.7, fade=0.04)
    b = rec("kenney_impact/impactBell_heavy_000.ogg", 0.0, 0.8, 2.2, fade=0.2, band="highpass=f=350")
    m = peak(mix_st([(0.0, stereo(a)), (0.0, stereo(b * 0.7))]).mean(axis=1)[::-1].copy(), -1.0)
    m = m[-int(dur * SR):]
    t = np.linspace(0, 1, len(m))
    return stereo((m * t ** 1.5).astype(np.float32) * 0.28)


def make_show(key: str, level: int = 0) -> tuple[np.ndarray, float]:
    """등장 소리 하나. 돌려주는 hit = 소리에서 앞면이 보이는 순간에 맞출 시각. level 0 = 노멀·레어"""
    name, fn, seed = CARDS[key]
    dry, hit = fn()
    parts = [(0.0, room(dry, 0.1, 0.1, seed))]
    if level:
        parts.append((hit, ring_layer(level)))
    return mix_st(parts), hit


# ── 파일 만들기 ──────────────────────────────────────
def trim_st(a: np.ndarray, seconds: float, fade: float = 0.02) -> np.ndarray:
    a = a[:int(seconds * SR)].copy()
    k = int(fade * SR)
    a[-k:] *= np.linspace(1, 0, k)[:, None]
    return a


def gain(db: float) -> float:
    return 10 ** (db / 20)


def stats(a: np.ndarray) -> dict:
    m = a.mean(axis=1) if a.ndim == 2 else a
    f, P = signal.welch(m, SR, nperseg=min(2048, len(m)))
    tot = P.sum() + 1e-15
    band = lambda lo, hi: P[(f >= lo) & (f < hi)].sum() / tot * 100
    idx = np.where(np.abs(m) > np.abs(m).max() * 10 ** (-30 / 20))[0]
    pf, pp = f[np.argmax(P)], P.max() / tot * 100
    return dict(len=len(m) / SR, act=(idx[-1] - idx[0]) / SR, c=(f * P).sum() / tot, body=band(150, 600), mid=band(2000, 5000), hi=band(9000, 1e6), rms=active_rms(a), pf=pf, pp=pp, peak=20 * np.log10(np.abs(a).max() + 1e-9))


def main():
    assert hashlib.md5(open(E3_PATH, "rb").read()).hexdigest() == E3_MD5, "e3가 바뀌었다"
    e3 = decode(E3_PATH, 2) * gain(E3_DB)
    rows_door, rows_card, wave = [], [], []
    labels = {"A": "에어록 치익-턱", "B": "패널 밀림", "C": "유압 해치", "D": "단말기 삑-딸깍"}
    for key, fn in {"A": door_a, "B": door_b, "C": door_c, "D": door_d}.items():
        o, c = fn()
        o, c = finish(trim_st(o, 0.4, 0.05), DOOR_RMS), finish(trim_st(c, 0.3, 0.05), DOOR_RMS - 3.0)
        so, sc = stats(o), stats(c)
        assert so["len"] <= 0.4 and sc["len"] <= 0.3, (key, so, sc)
        assert sc["act"] < so["act"] and sc["c"] < so["c"], (key, so, sc)  # 닫기는 열기보다 짧고 낮게
        assert so["hi"] < 5 and sc["hi"] < 5, (key, so, sc)  # 귀를 찌르지 않게
        save(o, f"{HERE}door_{key}_open.ogg")
        save(c, f"{HERE}door_{key}_close.ogg")
        gap = stereo(silence(0.7))
        demo = np.concatenate([o, gap, c, stereo(silence(1.1)), o, gap, c])
        save(demo, f"{HERE}door_{key}_pair.ogg")
        rows_door.append((key, labels[key], so, sc))
        wave += [(f"창 {key} 열기", o), (f"창 {key} 닫기", c)]
    swell_u = swell(0.16)
    swell_l = swell(LEGEND_GAP)
    for key in CARDS:
        tones = [make_show(key, lv) for lv in (0, 1, 2, 3)]
        shows = {}
        for lv, (a, hit) in zip((0, 1, 2, 3), tones):
            base = trim_st(a, {0: 0.42, 1: 0.8, 2: 0.95, 3: 1.4}[lv], 0.08)
            shows[lv] = (finish(base, tail=0.05) * gain(-13.0 + {0: 0, 1: 1, 2: 1.5, 3: 3}[lv]), hit)
        for lv, name in {0: "normal", 1: "epic", 2: "unique", 3: "legend"}.items():
            save(shows[lv][0], f"{HERE}card_{key}_{name}.ogg")
        # 3장 리듬: 앞면이 보이는 순간(카드 시작 + REVEAL)에 hit가 맞게. 첫 소리가 0보다 앞서지 않게 전체를 민다
        def lay(seq):
            t, parts, last = 0.3, [], 0.0
            for lv in seq:
                snd, hit = shows[lv]
                reveal = t + REVEAL
                if lv == 2:
                    parts.append((t, swell_u))  # 카드가 떨어질 때 시작해 앞면에서 끝남
                if lv == 3:
                    reveal = t + 0.12 + LEGEND_GAP  # 떨어진 뒤 모임
                    parts.append((t + 0.12, swell_l))
                parts.append((reveal - hit, snd))
                last = reveal
                t += STAGGER + (LEGEND_GAP - 0.04 if lv == 3 else 0.0)
            return parts, last
        p, last = lay([0, 0, 1])
        three = mix_st(p)
        save(three, f"{HERE}card_{key}_3cards.ogg")
        save(mix_st([*p, (last + 0.9, e3)]), f"{HERE}card_{key}_3cards_to_e3.ogg")
        p2, last2 = lay([1, 2, 3])
        save(mix_st([*p2, (last2 + 1.1, e3)]), f"{HERE}card_{key}_high_to_e3.ogg")
        s = stats(shows[0][0])
        assert s["act"] < STAGGER, (key, s)  # 다음 카드 전에 끝나야 리듬이 들림
        rows_card.append((key, CARDS[key][0], s, stats(shows[3][0]), shows[0][1], stats(shows[1][0])["act"]))
        wave.append((f"카드 {key} 3장 → e3", mix_st([*p, (last + 0.9, e3)])))
    write_md(rows_door, rows_card, stats(e3))
    draw_wave(wave)


def write_md(rows_door, rows_card, e3):
    out = ["# 측정값 (make_listen.py가 만듦, 귀로 듣지 못함)\n", "## 창 열기·닫기\n",
           "| 후보 | | 소리 길이(-30dB) | 무게중심 | 150~600Hz | 2~5kHz | 9kHz 위 | 가장 센 음 (전체 대비) |", "|---|---|---|---|---|---|---|---|"]
    for key, name, o, c in rows_door:
        for tag, s in (("열기", o), ("닫기", c)):
            out.append(f"| {key} {name} | {tag} | {s['act']:.2f}초 | {s['c']:.0f}Hz | {s['body']:.0f}% | {s['mid']:.0f}% | {s['hi']:.1f}% | {s['pf']:.0f}Hz ({s['pp']:.0f}%) |")
    out += ["", "## 카드 등장 (노멀·레어 기준, 레전드리는 꼬리 길이만)\n",
            "| 후보 | 소리 길이(-30dB) | 무게중심 | 150~600Hz | 2~5kHz | 9kHz 위 | 에픽 길이 | 레전드리 길이 | 앞면 시점 |", "|---|---|---|---|---|---|---|---|---|"]
    for key, name, s, l, hit, ep in rows_card:
        out.append(f"| {key} {name} | {s['act']:.2f}초 | {s['c']:.0f}Hz | {s['body']:.0f}% | {s['mid']:.0f}% | {s['hi']:.1f}% | {ep:.2f}초 | {l['act']:.2f}초 | 시작 뒤 {hit * 1000:.0f}ms |")
    out.append(f"| (비교) e3 | {e3['act']:.2f}초 | {e3['c']:.0f}Hz | {e3['body']:.0f}% | {e3['mid']:.0f}% | {e3['hi']:.1f}% | | | |")
    open(HERE + "measure.md", "w").write("\n".join(out) + "\n")
    print("\n".join(out))


def draw_wave(items):
    """파형 시트: 소리 모양을 눈으로 비교"""
    font = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 12)
    W, H = 900, 44
    im = Image.new("RGB", (W + 160, H * len(items)), "#14111c")
    d = ImageDraw.Draw(im)
    for i, (name, a) in enumerate(items):
        m = a.mean(axis=1)
        y0 = i * H + H // 2
        d.text((4, y0 - 7), name, font=font, fill="#fef8e5")
        scale = W / (4.0 * SR)  # 모두 같은 시간축 (4초)
        for x in range(min(W, int(len(m) * scale))):
            s = m[int(x / scale):int((x + 1) / scale)]
            v = float(np.abs(s).max()) if len(s) else 0.0
            d.line((160 + x, y0 - v * 40, 160 + x, y0 + v * 40), fill="#30e1b9")
    im.save(HERE + "wave.png")


if __name__ == "__main__":
    main()
