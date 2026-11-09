"""카드 소리 후보 c1·c2·c3 (계획서 32번, 게임에 넣지 않음). 실행: python3 review/v070_step5/listen/make_cards_c.py
목표: 가볍고 산뜻하지만 귀를 찌르지 않는 중간 밝기. 1이 가장 부드럽고 3이 가장 밝다.
공통: 200Hz 아래와 "웅" 층 없음, 2~5kHz 또렷함 유지, 7~8kHz 위만 부드럽게 깎음, 높은 음을 길게 끌지 않음.
고른 뒤에는 이 함수들을 tools/make_sfx.py로 옮기고 CARD_CHOICE를 바꾼다."""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
import make_sfx as ms  # noqa: E402

SR = ms.SR
# F 단조의 음. 레전드리 음계와 반짝임에 쓴다
F5, AB5, C6, EB6, F6, AB6, C7 = 698.46, 830.61, 1046.5, 1244.51, 1396.91, 1661.22, 2093.0

# 밝기 단계별 값: 금속판 음 비율, 7~8kHz 위를 얼마나 깎을지, 반짝임의 위 배음 크기와 음 높이(옥타브 배)
LEVELS = {
    "c1": {"shelf": "highshelf=f=6000:g=-9:t=q:w=0.7,lowpass=f=7500", "plate": 0.75, "air": "highpass=f=900,lowpass=f=4200", "over": 0.25, "oct": 1.0},
    "c2": {"shelf": "highshelf=f=7000:g=-7:t=q:w=0.7,lowpass=f=8500", "plate": 1.0, "air": "highpass=f=1200,lowpass=f=5200", "over": 0.45, "oct": 1.0},
    "c3": {"shelf": "highshelf=f=8000:g=-6:t=q:w=0.7,lowpass=f=9500", "plate": 1.3, "air": "highpass=f=1500,lowpass=f=6200", "over": 0.65, "oct": 2.0},
}
# 게임 크기(dB): 뒤집힘·선택은 지금 값(scripts/sfx.gd) 그대로, 반짝임은 짧고 가벼워 들리게 맞춘 값 (고른 뒤 sfx.gd에 옮긴다)
PICK_DB = -7.0
SHOW_DB = {"card_flip": -12.0, "card_rare": -14.0, "card_epic": -13.0, "card_unique": -12.0, "card_gather": -15.0, "card_legendary": -11.0}


def finish(a: np.ndarray, lv: dict, tail: float = 0.03) -> np.ndarray:
    """공통 마무리: 200Hz 아래 제거 + 7~8kHz 위 깎기 + 꼬리 정리 + 크기 맞춤"""
    return ms.tail_fade(ms.peak(ms.ffx(a, f"highpass=f=220,highpass=f=220,{lv['shelf']}")), tail)


def click(seed: int, dur: float, band: str, db: float) -> np.ndarray:
    """아주 짧은 잡음: 맞닿는 순간의 "딱"(dur 안에 약 -40dB까지 줄어듦)"""
    return ms.peak(ms.noise_burst(dur, 4.6 / dur, band, seed), db)


def tick(freqs: list[float], dur: float, decay: float) -> np.ndarray:
    """얇은 금속 부품의 튕김: 시작 1ms 안에 최고 크기"""
    return ms.ring(freqs, dur, decay).astype(np.float32)


def pick(key: str) -> np.ndarray:
    """"착칵": 작은 잠금쇠가 "착"(가볍게 닿음) 뒤 "칵"(맞물림). 0.15초 안팎"""
    lv = LEVELS[key]
    k = lv["plate"]
    cha = ms.layered([(0.0, click(61, 0.012, "highpass=f=1800,lowpass=f=6500", -4.0)), (0.0, tick([2700.0 * k ** 0.3, 3900.0 * k ** 0.3], 0.04, 140.0) * 0.5)])
    kak = ms.layered([(0.0, click(62, 0.01, "highpass=f=1400,lowpass=f=6000", -2.0)), (0.0, tick([2150.0 * k ** 0.3, 2890.0 * k ** 0.3, 3870.0 * k ** 0.3], 0.085, 62.0) * 0.8)])
    return finish(ms.layered([(0.0, cha * 0.6), (0.055, kak)]), lv, 0.02)


def sparkle(freq: float, lv: dict, dur: float = 0.11) -> np.ndarray:
    """반짝임 한 알: 빠른 시작, 짧은 꼬리. 밝기 단계는 위 배음과 옥타브로 다르다"""
    f = freq * lv["oct"]
    t = np.arange(int(SR * dur)) / SR
    env = np.minimum(t / 0.0015, 1.0) * np.exp(-34.0 * t)
    return ((np.sin(2 * np.pi * f * t) + lv["over"] * np.sin(2 * np.pi * f * 2.76 * t)) * env).astype(np.float32)


def show_set(key: str) -> dict[str, np.ndarray]:
    """등장 세트. 노멀은 스윽만, 위 등급은 반짝임의 수와 밝기로 구분한다 (낮은 울림 없음)"""
    lv = LEVELS[key]
    k = lv["plate"]
    # 스윽: 공기 + 얇은 판. 바람이 금방 올라와 금방 사라져 가볍다
    t = np.arange(int(SR * 0.11)) / SR
    air = ms.peak(ms.noise_burst(0.11, 0.0, lv["air"], 71), 0.0) * (np.minimum(t / 0.02, 1.0) * np.exp(-30.0 * np.maximum(t - 0.02, 0.0)))
    flip = finish(ms.layered([(0.0, air), (0.03, tick([1840.0 * k ** 0.3, 2790.0 * k ** 0.3], 0.07, 75.0) * 0.45 * k)]), lv)
    # 레전드리 모임: 0.3초 동안 F 단조 음을 타고 올라가는 반짝임이 점점 빨라지고 커진다
    gather_notes = [(0.0, C6 / 2), (0.1, EB6 / 2), (0.18, F6 / 2), (0.24, AB6 / 2), (0.28, C7 / 2)]
    gather = ms.layered([(d, sparkle(f, lv, 0.07) * (0.35 + 0.65 * d / 0.28)) for d, f in gather_notes])
    gather = np.pad(gather, (0, max(0, int(SR * 0.3) - len(gather))))[: int(SR * 0.34)]
    return {
        "card_flip": flip,
        "card_rare": finish(sparkle(F6, lv), lv, 0.02),
        "card_epic": finish(ms.layered([(0.0, sparkle(C6, lv)), (0.075, sparkle(F6, lv))]), lv, 0.02),
        # 유니크: 밝은 화음을 살짝 펼쳐서 (F Ab C). 짧게
        "card_unique": finish(ms.layered([(0.0, sparkle(F5, lv, 0.18)), (0.018, sparkle(AB5, lv, 0.18)), (0.036, sparkle(C6, lv, 0.18))]), lv, 0.04),
        "card_gather": finish(gather, lv, 0.02),
        # 레전드리: 밝게 올라가는 음계 4음 Ab C Eb Ab (F 단조와 같은 음들로 된 Ab 장조). 끝 음만 살짝 길게
        "card_legendary": finish(ms.layered([(0.0, sparkle(AB5, lv, 0.12)), (0.07, sparkle(C6, lv, 0.12)), (0.14, sparkle(EB6, lv, 0.12)), (0.21, sparkle(AB6, lv, 0.22))]), lv, 0.05),
    }


def demo(s: dict[str, np.ndarray]) -> np.ndarray:
    """게임 크기로 노멀 → 레어 → 에픽 → 유니크 → 레전드리 (ms.show_demo와 같은 순서, 크기만 후보 값)"""
    saved = ms.CARD_SOUND_DB
    ms.CARD_SOUND_DB = SHOW_DB
    try:
        return ms.show_demo(s)
    finally:
        ms.CARD_SOUND_DB = saved


def band_share(a: np.ndarray, lo: float, hi: float) -> float:
    spec = np.abs(np.fft.rfft(a)) ** 2
    f = np.fft.rfftfreq(len(a), 1 / SR)
    return float(spec[(f >= lo) & (f < hi)].sum() / max(spec.sum(), 1e-12))


def centroid(a: np.ndarray) -> float:
    """밝기 숫자: 소리 에너지의 무게중심 (Hz)"""
    spec = np.abs(np.fft.rfft(a)) ** 2
    return float((spec * np.fft.rfftfreq(len(a), 1 / SR)).sum() / max(spec.sum(), 1e-12))


def report(name: str, a: np.ndarray) -> tuple[float, float, float]:
    low, mid, high = band_share(a, 0, 200), band_share(a, 2000, 5000), band_share(a, 8000, SR / 2)
    print(f"{name:18s} 길이 {len(a) / SR:5.2f}초  200Hz 아래 {low * 100:5.2f}%  2~5kHz {mid * 100:5.1f}%  8kHz 위 {high * 100:5.2f}%")
    return low, mid, high


def main() -> None:
    gap = ms.silence(0.6)
    bright: list[tuple[float, float]] = []
    for key in LEVELS:
        p = pick(key)
        low, mid, high = report(f"card_pick_{key}", p)
        # 자체 확인: 요청한 조건을 숫자로 지키는지
        assert low < 0.002 and mid > 0.3 and high < 0.02, key
        assert 0.12 <= len(p) / SR <= 0.18, len(p) / SR
        assert np.argmax(np.abs(p) > 0.25) < 0.003 * SR, "시작이 또렷해야 함"  # -12dB까지 3ms 안에
        g = p * 10 ** (PICK_DB / 20.0)
        ms.save(np.concatenate([g, gap, g, gap, g]), f"{HERE}/card_pick_{key}.ogg")
        s = show_set(key)
        for name, a in s.items():
            low, mid, high = report(f"  {name}", a)
            assert low < 0.005 and high < 0.02 and len(a) / SR < 0.5, name
        d = demo(s)
        ms.save(d, f"{HERE}/card_show_{key}.ogg")
        bright.append((centroid(p), centroid(d)))
        print(f"{key} 밝기(무게중심): 선택 {bright[-1][0]:.0f}Hz, 등장 {bright[-1][1]:.0f}Hz")
    assert all(bright[i][j] < bright[i + 1][j] for i in (0, 1) for j in (0, 1)), "1 < 2 < 3 순서로 밝아야 함"


if __name__ == "__main__":
    main()
