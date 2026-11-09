"""게임 효과음 만들기: Kenney 원본(assets/sfx/kenney_*/*.ogg)을 다듬거나 직접 합성해 assets/sfx/game/*.wav로 저장한다.

- wav로 두는 이유: 웹에서 ogg는 재생을 시작할 때마다 디코더를 새로 만들어 비싸다 (v0.7.0 4c 측정, review/v070_step4c/perf.md).
- 다듬기는 ffmpeg 필터(음 높이 = 재생 속도, 높은 음 깎기 lowpass, 고음 살리기 treble, 꼬리 자르기 + 짧게 줄이기)로 한다.
- 합성 소리(종소리 "띠링", 올라가는 "띠리링", 낮은 에너지 소리)는 numpy로 만든다. 같은 입력이면 항상 같은 결과다.
- --listen: 사용자가 들어 보고 고를 후보를 review/v070_step4c/listen/*.ogg로 만든다.
- --listen2: 2차 후보(적 소리, 레벨업)를 만든다. 배경음은 tools/make_music.py가 만든다.
- --listen3: 업그레이드 창 소리 후보를 만든다.
- --listen4: 카드 선택·등장 소리 후보를 review/v070_step5/listen/에 만든다.

다시 만들기: python3 tools/make_sfx.py   (후보: python3 tools/make_sfx.py --listen, --listen2)
"""

from __future__ import annotations

import os
import subprocess
import sys

import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/sfx")
OUT = os.path.join(ROOT, "assets/sfx/game")
LISTEN = os.path.join(ROOT, "review/v070_step4c/listen")
SR = 44100


def decode(path: str, channels: int = 1) -> np.ndarray:
    """소리 파일 → -1~1 배열 (스테레오는 (샘플 수, 2))"""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", str(channels), "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    a = np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0
    return a if channels == 1 else a.reshape(-1, channels)


def load(name: str) -> np.ndarray:
    """assets/sfx/<name>.ogg → -1~1 모노"""
    return decode(f"{SRC}/{name}.ogg")


def ffx(a: np.ndarray, filters: str) -> np.ndarray:
    """ffmpeg 오디오 필터를 건다 (예: "lowpass=f=1200")"""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", "-af", filters,
                          "-ar", str(SR), "-f", "s16le", "-"], input=to16(a), capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0


def to16(a: np.ndarray) -> bytes:
    return (np.clip(a, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes()


def save(a: np.ndarray, path: str, rate: int = SR, quality: int | None = None) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    stereo = a.ndim == 2
    # 스테레오 후보는 길어서 저장소가 커지지 않게 품질을 조금 낮춘다
    q = quality if quality is not None else (3 if stereo else 5)
    args = ["-c:a", "libvorbis", "-q:a", str(q)] if path.endswith(".ogg") else ["-c:a", "pcm_s16le"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(rate), "-ac", "2" if stereo else "1", "-i", "-", *args, path],
                   input=to16(a), check=True)


def pitch(a: np.ndarray, p: float) -> np.ndarray:
    """테이프처럼 음 높이와 빠르기를 함께 바꾼다 (게임의 pitch_scale과 같음)"""
    return a if p == 1.0 else ffx(a, f"asetrate={SR * p:.0f},aresample={SR}")


def trim(a: np.ndarray, seconds: float, fade: float = 0.06) -> np.ndarray:
    """앞 seconds초만 남기고 끝 fade초는 줄어들게 (딸깍 소리 없이 꼬리를 자름)"""
    a = a[: int(SR * seconds)].copy()
    n = min(int(SR * fade), len(a))
    a[len(a) - n:] *= np.linspace(1.0, 0.0, n)
    return a


def peak(a: np.ndarray, db: float = -1.0) -> np.ndarray:
    """최고 음량을 db로 맞춘다 (Kenney 팩과 같은 -1dB)"""
    m = float(np.max(np.abs(a))) or 1.0
    return a * (10 ** (db / 20.0) / m)


def silence(seconds: float) -> np.ndarray:
    return np.zeros(int(SR * seconds), np.float32)


def bell(freq: float, dur: float, bright: float = 0.3, decay: float = 9.0) -> np.ndarray:
    """맑은 종소리 음 하나: 사인 + 배음(bright 비율), 빨리 커지고 지수로 줄어듦"""
    t = np.arange(int(SR * dur)) / SR
    tone = np.sin(2 * np.pi * freq * t) + bright * np.sin(2 * np.pi * freq * 2 * t) + bright * 0.4 * np.sin(2 * np.pi * freq * 3 * t)
    env = np.minimum(t / 0.004, 1.0) * np.exp(-decay * t)
    return (tone * env).astype(np.float32)


def tri(freq: float, dur: float, decay: float = 12.0) -> np.ndarray:
    """부드러운 8비트 삼각파 음"""
    t = np.arange(int(SR * dur)) / SR
    tone = 2.0 * np.abs(2.0 * ((freq * t) % 1.0) - 1.0) - 1.0
    env = np.minimum(t / 0.003, 1.0) * np.exp(-decay * t)
    return (tone * env).astype(np.float32)


def arp(notes: list[float], step: float, voice, dur: float) -> np.ndarray:
    """음표를 step초 간격으로 겹쳐 쌓는다 (올라가는 "띠리링")"""
    out = np.zeros(int(SR * (step * (len(notes) - 1) + dur)), np.float32)
    for i, f in enumerate(notes):
        n = voice(f, dur)
        s = int(SR * step * i)
        out[s:s + len(n)] += n
    return out


def energy_swell(dur: float = 0.7) -> np.ndarray:
    """포격 예고(합성): 낮게 깔리며 올라가는 웅웅거림 (90 → 140Hz, 떨림 7Hz)"""
    t = np.arange(int(SR * dur)) / SR
    f = 90.0 + 50.0 * t / dur
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.35 * np.sin(2 * ph)
    env = np.minimum(t / 0.25, 1.0) * np.minimum((dur - t) / 0.12, 1.0) * (0.75 + 0.25 * np.sin(2 * np.pi * 7 * t))
    return (tone * env).astype(np.float32)


def energy_whomp(dur: float = 0.4) -> np.ndarray:
    """포격 발사(합성): 220 → 55Hz로 떨어지는 둔탁한 "뿌웅" + 낮게 깎은 잡음"""
    t = np.arange(int(SR * dur)) / SR
    f = 55.0 + 165.0 * np.exp(-9.0 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    rng = np.random.default_rng(7)
    noise = ffx(rng.uniform(-1, 1, len(t)).astype(np.float32), "lowpass=f=700,lowpass=f=700")[: len(t)]
    env = np.minimum(t / 0.005, 1.0) * np.exp(-6.0 * t)
    return ((np.sin(ph) + 0.5 * noise * np.exp(-12.0 * t)) * env).astype(np.float32)


def beat_grid(a: np.ndarray, guess: float) -> tuple[float, float]:
    """곡의 (박 길이, 첫 박 위치)를 찾는다: 곡 길이를 나누어떨어지는 박 수로 맞추고(반복해도 어긋나지 않게), 소리가 커지는 순간이 가장 많이 겹치는 위치"""
    length_s = len(a) / SR
    period = length_s / round(length_s / guess)
    hop = 512
    e = np.array([np.sum(a[i:i + hop] ** 2) for i in range(0, len(a) - hop, hop)])
    onset = np.maximum(np.diff(np.log(e + 1e-6)), 0.0)
    times = np.arange(len(onset)) * hop / SR
    bins = 64
    idx = (np.floor((times % period) / period * bins)).astype(int) % bins
    fold = np.bincount(idx, weights=onset, minlength=bins)
    return period, float(np.argmax(fold)) / bins * period


def stamp(out: np.ndarray, hit: np.ndarray, start: int) -> None:
    """소리 하나를 원형으로 더한다: 끝을 넘는 부분은 처음으로 이어져 반복할 때 끊기지 않는다"""
    out[(start + np.arange(len(hit))) % len(out)] += hit


def pulse_layer(samples: int, period: float, offset: float) -> np.ndarray:
    """30초 뒤 들어오는 리듬 층: 곡과 길이가 같고 박에 맞춘 낮은 "둥" (80 → 45Hz)"""
    out = np.zeros(samples, np.float32)
    n = int(SR * 0.28)
    t = np.arange(n) / SR
    ph = 2 * np.pi * np.cumsum(45.0 + 35.0 * np.exp(-25.0 * t)) / SR
    thump = (np.sin(ph) * np.minimum(t / 0.004, 1.0) * np.exp(-11.0 * t)).astype(np.float32)
    beat = 0
    while offset + beat * period < samples / SR:
        # 강박(4박마다 첫 박)은 크게
        stamp(out, thump * (1.0 if beat % 4 == 0 else 0.55), int(round(SR * (offset + beat * period))))
        beat += 1
    return peak(out)


def fast_pulse_layer(samples: int, period: float, offset: float) -> np.ndarray:
    """2분 뒤 더해지는 층: 반 박마다 높은 "칫"(2~6kHz 잡음), 엇박마다 중간 "둥" (110 → 70Hz)"""
    t = np.arange(int(SR * 0.09)) / SR
    tick = ffx(np.random.default_rng(11).uniform(-1, 1, len(t)).astype(np.float32), "highpass=f=2000,lowpass=f=6000")[: len(t)] * np.exp(-55.0 * t)
    t2 = np.arange(int(SR * 0.14)) / SR
    ph = 2 * np.pi * np.cumsum(70.0 + 40.0 * np.exp(-30.0 * t2)) / SR
    mid = (np.sin(ph) * np.minimum(t2 / 0.003, 1.0) * np.exp(-20.0 * t2)).astype(np.float32)
    out = np.zeros(samples, np.float32)
    half = 0
    while offset + half * period / 2 < samples / SR:
        s = int(round(SR * (offset + half * period / 2)))
        off_beat = half % 2 == 1
        stamp(out, tick * (1.0 if off_beat else 0.6), s)
        if off_beat:
            stamp(out, mid * 0.8, s)
        half += 1
    return peak(out)


# ── 후보 (사용자가 들어 보고 고름) ─────────────────────
## 음 이름 → 주파수
C6, E6, G6, C7 = 1046.5, 1318.5, 1568.0, 2093.0
G5, B5, D6 = 784.0, 987.8, 1174.7
GS6, B6, E7 = 1661.2, 1975.5, 2637.0


def barrage_a() -> tuple[np.ndarray, np.ndarray]:
    """Kenney 그대로 낮추고 높은 음 깎기"""
    warn = ffx(pitch(load("kenney_sci-fi/forceField_002"), 0.65), "lowpass=f=900,lowpass=f=900")
    fire = ffx(pitch(load("kenney_sci-fi/laserLarge_000"), 0.55), "lowpass=f=1200,lowpass=f=1200")
    return peak(trim(warn, 1.0, 0.15)), peak(trim(fire, 0.6, 0.1))


def barrage_b() -> tuple[np.ndarray, np.ndarray]:
    """Kenney 엔진 웅웅 + 저주파 폭발"""
    warn = ffx(trim(load("kenney_sci-fi/spaceEngineLow_001"), 0.8, 0.2), "afade=t=in:d=0.2,lowpass=f=700")
    fire = ffx(pitch(load("kenney_sci-fi/lowFrequency_explosion_000"), 1.25), "lowpass=f=1500")
    return peak(warn), peak(trim(fire, 0.5, 0.15))


def barrage_c() -> tuple[np.ndarray, np.ndarray]:
    """직접 합성"""
    return peak(energy_swell()), peak(energy_whomp())


def levelup_a() -> np.ndarray:
    """Kenney 확인음 + 아주 높은 음만 살짝 깎기"""
    return peak(ffx(load("kenney_interface/confirmation_002"), "lowpass=f=6000"), -3.0)


def levelup_b() -> np.ndarray:
    """종소리 아르페지오 도-미-솔-도 (60ms 간격)"""
    return peak(ffx(arp([C6, E6, G6, C7], 0.06, lambda f, d: bell(f, d, 0.25, 8.0), 0.45), "lowpass=f=7000"), -3.0)


def levelup_c() -> np.ndarray:
    """부드러운 8비트 삼각파 솔-시-레-솔 (45ms 간격)"""
    return peak(ffx(arp([G5, B5, D6, G6], 0.045, lambda f, d: tri(f, d, 10.0), 0.32), "lowpass=f=5000"), -3.0)


## 레벨업 2차 후보: 낮고 부드럽게. 마지막 음은 가장 높지 않고 첫 음과 한 옥타브 안, 더 작고 짧게, 끝은 부드럽게 줄어듦
G4, C5, E5 = 392.0, 523.25, 659.25
LEVELUP2_STEP = 0.085
LEVELUP2_LAST_DUR = 0.14
LEVELUP2_LAST_GAIN = 0.5


def tail_fade(a: np.ndarray, seconds: float) -> np.ndarray:
    """끝 seconds초를 코사인 곡선으로 0까지 줄인다 (갑자기 끊기지 않게)"""
    a = a.copy()
    n = min(int(SR * seconds), len(a))
    a[len(a) - n:] *= (0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, n))).astype(np.float32)
    return a


def marimba(freq: float, dur: float) -> np.ndarray:
    """마림바: 사인 + 금방 사라지는 4배 음 (막대를 치는 느낌)"""
    t = np.arange(int(SR * dur)) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-45.0 * t)
    return (tone * np.minimum(t / 0.003, 1.0) * np.exp(-11.0 * t)).astype(np.float32)


def soft_pluck(freq: float, dur: float) -> np.ndarray:
    """부드러운 신스 플럭: 배음이 작고(1/n²) 높은 배음일수록 빨리 사라짐"""
    t = np.arange(int(SR * dur)) / SR
    tone = sum(np.sin(2 * np.pi * freq * n * t) * np.exp(-(9.0 + 7.0 * n) * t) / n ** 2 for n in range(1, 6))
    return (tone * np.minimum(t / 0.006, 1.0)).astype(np.float32)


def round_tri(freq: float, dur: float) -> np.ndarray:
    """둥근 삼각파: 천천히 시작하고 천천히 줄어듦"""
    t = np.arange(int(SR * dur)) / SR
    tone = 2.0 * np.abs(2.0 * ((freq * t) % 1.0) - 1.0) - 1.0
    return (tone * np.minimum(t / 0.012, 1.0) * np.exp(-8.0 * t)).astype(np.float32)


## 후보 → (음표, 음색)
LEVELUP2 = {
    "a": ([C5, E5, G5, C5], marimba),  # 도-미-솔-도: 첫 음으로 돌아옴
    "b": ([C5, E5, G5, E5], soft_pluck),  # 도-미-솔-미: 살짝 내려앉음
    "c": ([G4, C5, E5, C5], round_tri),  # 낮은 솔-도-미-도: 가장 낮고 둥긂
}


def levelup2(key: str) -> np.ndarray:
    notes, voice = LEVELUP2[key]
    out = np.zeros(int(SR * (LEVELUP2_STEP * (len(notes) - 1) + LEVELUP2_LAST_DUR)), np.float32)
    for i, f in enumerate(notes[:-1]):
        # 앞 음은 마지막 음이 시작할 때쯤 사라진다 (잔향이 겹치면 마지막 음이 오히려 가장 커짐)
        n = tail_fade(voice(f, min(0.26, LEVELUP2_STEP * (len(notes) - 1 - i) + 0.015)), 0.06)
        s = int(SR * LEVELUP2_STEP * i)
        out[s:s + len(n)] += n
    last = tail_fade(voice(notes[-1], LEVELUP2_LAST_DUR), LEVELUP2_LAST_DUR * 0.7) * LEVELUP2_LAST_GAIN
    out[len(out) - len(last):] += last
    # 4kHz 위를 깎고 끝을 다시 0으로
    return tail_fade(peak(ffx(out, "lowpass=f=4000,lowpass=f=4000"), -3.0), 0.04)


## 적 소리 합성 재료
def sweep(f0: float, f1: float, dur: float, decay: float, attack: float = 0.002) -> np.ndarray:
    """f0에서 f1로 음이 미끄러지는 사인"""
    t = np.arange(int(SR * dur)) / SR
    ph = 2 * np.pi * np.cumsum(f0 * (f1 / f0) ** (t / dur)) / SR
    return (np.sin(ph) * np.minimum(t / attack, 1.0) * np.exp(-decay * t)).astype(np.float32)


def noise_burst(dur: float, decay: float, filters: str, seed: int) -> np.ndarray:
    t = np.arange(int(SR * dur)) / SR
    n = np.random.default_rng(seed).uniform(-1, 1, len(t)).astype(np.float32)
    return (ffx(n, filters)[: len(t)] * np.exp(-decay * t)).astype(np.float32)


def layered(parts: list[tuple[float, np.ndarray]]) -> np.ndarray:
    """(시작 초, 소리)들을 겹치고 끝을 부드럽게"""
    out = np.zeros(max(int(SR * s) + len(a) for s, a in parts), np.float32)
    for s, a in parts:
        out[int(SR * s):int(SR * s) + len(a)] += a
    return tail_fade(peak(out), 0.015)


def jelly_a() -> tuple[np.ndarray, np.ndarray]:
    """맞음: 둔한 탄력음 "퉁"(190→85Hz) / 파괴: 물방울이 올라가는 "뽁" 두 번"""
    hit = sweep(190, 85, 0.15, 20.0) + 0.25 * sweep(380, 170, 0.15, 35.0)
    return tail_fade(peak(hit), 0.02), layered([(0.0, sweep(260, 950, 0.1, 18.0)), (0.075, 0.45 * sweep(380, 1300, 0.08, 28.0))])


def jelly_b() -> tuple[np.ndarray, np.ndarray]:
    """맞음: Kenney 부드러운 충격 + 낮은 "퉁" / 파괴: 젤리가 터지는 "퍽" + 작은 방울들"""
    soft = ffx(trim(pitch(load("kenney_impact/impactSoft_heavy_000"), 1.5), 0.18, 0.06), "lowpass=f=1200")
    hit = layered([(0.0, soft), (0.0, 0.8 * sweep(150, 90, 0.16, 22.0))])
    burst = layered([(0.0, noise_burst(0.1, 40.0, "lowpass=f=900", 3)), (0.0, sweep(480, 140, 0.14, 22.0)),
                     (0.09, 0.3 * sweep(500, 1100, 0.07, 30.0)), (0.15, 0.2 * sweep(620, 1400, 0.06, 35.0))])
    return hit, burst


def bug_a() -> tuple[np.ndarray, np.ndarray]:
    """맞음: 아주 짧은 "틱"(40ms) / 파괴: 음이 떨어지는 "찍"(0.1초)"""
    hit = layered([(0.0, sweep(2600, 2000, 0.04, 90.0, 0.001)), (0.0, 0.6 * noise_burst(0.03, 150.0, "highpass=f=3000", 5))])
    t = np.arange(int(SR * 0.1)) / SR
    chirp = sweep(3200, 1300, 0.1, 22.0, 0.001) * (0.65 + 0.35 * np.sign(np.sin(2 * np.pi * 70 * t)))
    return hit, tail_fade(peak(chirp.astype(np.float32)), 0.015)


def crackle(dur: float, seed: int) -> np.ndarray:
    """바삭한 지직거림: 짧은 잡음 조각이 불규칙하게 튀고 뒤로 갈수록 작아짐"""
    rng = np.random.default_rng(seed)
    out = np.zeros(int(SR * dur), np.float32)
    pos = 0
    while pos < len(out):
        grain = rng.uniform(-1, 1, int(SR * rng.uniform(0.002, 0.005))).astype(np.float32)
        part = grain[: len(out) - pos]
        out[pos:pos + len(part)] += part * np.exp(-14.0 * pos / SR)
        pos += int(SR * rng.uniform(0.006, 0.016))
    return ffx(out, "highpass=f=1200,lowpass=f=5000")[: len(out)]


def bug_b() -> tuple[np.ndarray, np.ndarray]:
    """맞음: 더 낮고 짧은 "틱"(30ms) / 파괴: 바삭한 "지직"(0.14초)"""
    hit = layered([(0.0, sweep(1800, 1300, 0.03, 110.0, 0.001)), (0.0, 0.5 * noise_burst(0.02, 200.0, "highpass=f=2500", 6))])
    return hit, tail_fade(peak(crackle(0.14, 8)), 0.02)


def enemy_demo(hit: np.ndarray, burst: np.ndarray) -> np.ndarray:
    """맞음 → 파괴를 두 번"""
    return np.concatenate([hit, silence(0.2), burst, silence(0.6), hit, silence(0.2), burst])


def rms(a: np.ndarray) -> float:
    return float(np.sqrt(np.mean(a ** 2)))


def listen2() -> None:
    for key, fn in {"a": jelly_a, "b": jelly_b}.items():
        save(enemy_demo(*fn()), f"{LISTEN}/enemy_jelly_{key}.ogg")
    for key, fn in {"a": bug_a, "b": bug_b}.items():
        save(enemy_demo(*fn()), f"{LISTEN}/enemy_bug_{key}.ogg")
    for key in LEVELUP2:
        save(np.concatenate([levelup2(key), silence(0.6), levelup2(key)]), f"{LISTEN}/levelup2_{key}.ogg")


## 업그레이드 창 소리 후보: 지금 소리(open_002)는 주된 음이 6.9kHz로 높고 마림바보다 크다. 낮고 부드럽게, 0.3초 안에
def card_a() -> np.ndarray:
    """공기가 열리는 "슈욱": 낮게 깎은 잡음이 살짝 커졌다 사라짐 (음이 없어 마림바와 부딪치지 않음)"""
    t = np.arange(int(SR * 0.28)) / SR
    env = np.minimum(t / 0.1, 1.0) ** 2 * np.exp(-9.0 * np.maximum(t - 0.1, 0.0))
    n = noise_burst(0.28, 0.0, "highpass=f=250,lowpass=f=1400,lowpass=f=1400", 21)
    # 잡음은 순간 최고치만 커서 평균이 작다: 부드럽게 눌러 들리는 크기를 키움
    return tail_fade(peak(np.tanh(3.0 * peak(n * env, 0.0)).astype(np.float32)), 0.06)


def card_b() -> np.ndarray:
    """낮은 마림바 "통": 마림바가 끝난 C5의 한 옥타브 아래 C4와 G4를 함께, 레벨업 소리와 이어지는 음"""
    return tail_fade(peak(ffx(marimba(C5 / 2, 0.25) + 0.45 * marimba(G5 / 2, 0.25), "lowpass=f=2500")), 0.08)


def card_c() -> np.ndarray:
    """지금 소리의 성격을 남김: Kenney open_002를 한 옥타브 낮추고 높은 음을 깎은 뒤 0.3초로 자름"""
    return peak(trim(ffx(pitch(load("kenney_interface/open_002"), 0.5), "lowpass=f=1800,lowpass=f=1800"), 0.3, 0.1))


CARD_DB = -14.0  # 게임 음량(scripts/sfx.gd의 card_show와 같게): 최고 크기가 마림바(-12.5dB)보다 작게
LEVELUP_DB = -9.5
LEVELUP_TO_CARD = 0.3  # 레벨업 소리에서 창이 뜰 때까지 (슬로모션 길이)


def listen3() -> None:
    """게임처럼 마림바 → 창 소리를 두 번, 쉬고 창 소리만 두 번 (게임 음량)"""
    g = lambda db: 10 ** (db / 20.0)
    for key, fn in {"a": card_a, "b": card_b, "c": card_c}.items():
        card = fn() * g(CARD_DB)
        up = levelup2("a") * g(LEVELUP_DB)
        scene = np.zeros(max(int(SR * LEVELUP_TO_CARD) + len(card), len(up)), np.float32)
        scene[: len(up)] += up
        scene[int(SR * LEVELUP_TO_CARD):int(SR * LEVELUP_TO_CARD) + len(card)] += card
        save(np.concatenate([scene, silence(0.8), scene, silence(1.0), card, silence(0.6), card]), f"{LISTEN}/card2_{key}.ogg")


## 광물 줍기 후보: 등급 0~3 소리 (게임에서 연속 줍기는 재생 속도로 최대 +12반음 올림)
def pickup_a() -> list[np.ndarray]:
    """지금 Kenney 소리를 +2반음, 고음 +5dB"""
    files = ["kenney_interface/drop_002", "kenney_interface/glass_002", "kenney_interface/pluck_001", "kenney_interface/confirmation_003"]
    return [peak(ffx(pitch(load(f), 2 ** (2 / 12)), "treble=g=5:f=3000")) for f in files]


def pickup_b() -> list[np.ndarray]:
    """일반만 맑은 사인 "띵"(미), 나머지는 지금 Kenney 소리 +3반음"""
    files = ["kenney_interface/glass_002", "kenney_interface/pluck_001", "kenney_interface/confirmation_003"]
    return [peak(bell(E6, 0.16, 0.2, 22.0))] + [peak(pitch(load(f), 2 ** (3 / 12))) for f in files]


def pickup_c() -> list[np.ndarray]:
    """모두 종소리 "띠링": 등급이 높을수록 음이 많고 배음이 밝음"""
    def ding(notes, bright, step=0.05):
        return peak(arp(notes, step, lambda f, d: bell(f, d, bright, 18.0), 0.2))
    return [ding([B5, E6], 0.15), ding([E6, B6], 0.3), ding([E6, GS6, B6], 0.35), ding([E6, GS6, B6, E7], 0.45, 0.045)]


def pickup_demo(sounds: list[np.ndarray]) -> np.ndarray:
    """등급 0~3을 차례로, 이어서 일반을 1반음씩 올리며 6번 (연속 줍기)"""
    parts = []
    for s in sounds:
        parts += [s, silence(0.35)]
    for i in range(6):
        parts += [pitch(sounds[0], 2 ** (i / 12)), silence(0.1)]
    return np.concatenate(parts)


def listen() -> None:
    for key, fn in {"a": barrage_a, "b": barrage_b, "c": barrage_c}.items():
        warn, fire = fn()
        save(np.concatenate([warn * 10 ** (-4 / 20), silence(0.3), fire]), f"{LISTEN}/barrage_{key}.ogg")
    for key, fn in {"a": levelup_a, "b": levelup_b, "c": levelup_c}.items():
        save(np.concatenate([fn(), silence(0.6), fn()]), f"{LISTEN}/levelup_{key}.ogg")
    for key, fn in {"a": pickup_a, "b": pickup_b, "c": pickup_c}.items():
        save(pickup_demo(fn()), f"{LISTEN}/pickup_{key}.ogg")
    # 운석 깨짐: 지금(원본) → 짧게 자른 것, 크기별
    old = [pitch(load("kenney_sci-fi/explosionCrunch_000"), 1.3), load("kenney_sci-fi/explosionCrunch_002"), pitch(load("kenney_sci-fi/lowFrequency_explosion_001"), 0.85)]
    new = [pitch(BREAKS[n](), p) for n, p in (("break_small", 1.3), ("break_mid", 1.0), ("break_big", 0.85))]
    save(np.concatenate([x for s in old for x in (s, silence(0.3))] + [silence(0.6)] + [x for s in new for x in (s, silence(0.3))]), f"{LISTEN}/break_before_after.ogg")


# ── 게임에 넣는 소리 ───────────────────────────────
## 운석 깨짐: 꼬리를 잘라 약 0.3초 안에 (큰 운석은 조금 길게). 게임의 음 높이(작은 1.3배, 큰 0.85배)로 더 짧아지거나 길어짐
BREAKS = {
    "break_small": lambda: trim(load("kenney_sci-fi/explosionCrunch_000"), 0.32, 0.12),
    "break_mid": lambda: trim(load("kenney_sci-fi/explosionCrunch_002"), 0.3, 0.12),
    "break_big": lambda: trim(load("kenney_sci-fi/lowFrequency_explosion_001"), 0.45, 0.15),
}
## 고른 후보 (사용자가 다른 것을 고르면 여기만 바꾸고 다시 실행)
CHOICE = {"barrage": barrage_a, "levelup": lambda: levelup2("a"), "pickup": pickup_c, "jelly": jelly_a, "bug": bug_b}
## 고른 카드 소리 후보 (review/v070_step5/listen/). 사용자가 다른 것을 고르면 여기만 바꾸고 다시 실행
CARD_CHOICE = {"pick": "e2", "show": "d2"}
## 그대로 wav로 바꾸는 Kenney 소리: 게임 이름 → 원본
COPY = {
    "shoot_0": "kenney_sci-fi/laserSmall_000", "shoot_1": "kenney_sci-fi/laserSmall_002",
    "hit_rock_0": "kenney_impact/impactMining_000", "hit_rock_1": "kenney_impact/impactMining_001",
    "player_hit": "kenney_impact/impactMetal_heavy_000",
    "shield_block": "kenney_sci-fi/forceField_000",
    "click": "kenney_interface/click_002",
    "cargo_heavy": "kenney_impact/impactSoft_heavy_000",
}


# ── 게이트·워프 소리 (v0.7.0 6단계: 예전 네모파 합성음을 Kenney 금속·기계음과 낮게 깎은 합성으로 바꿈) ──
def rising(f0: float, f1: float, dur: float, bright: float = 0.35) -> np.ndarray:
    """f0 → f1로 오르며 커지고 떨림이 빨라지는 에너지 충전음 (높은 음은 깎음)"""
    t = np.arange(int(SR * dur)) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + bright * np.sin(2 * ph) + 0.5 * np.sin(0.5 * ph)
    wobble = 0.8 + 0.2 * np.sin(2 * np.pi * np.cumsum(4.0 + 14.0 * t / dur) / SR)
    env = np.minimum(t / 0.05, 1.0) * (0.3 + 0.7 * t / dur) * wobble * np.minimum((dur - t) / 0.03, 1.0)
    return peak(ffx((tone * env).astype(np.float32), "lowpass=f=2600"))


def clank(p: float) -> np.ndarray:
    return trim(pitch(load("kenney_sci-fi/impactMetal_000"), p), 0.14, 0.06)


def gate_hum(dur: float = 2.0) -> np.ndarray:
    """게이트 웅웅거림: 2초에 정수 번 도는 파형만 써서 반복해도 끊기지 않는다"""
    t = np.arange(int(SR * dur)) / SR
    tone = np.sin(2 * np.pi * 70 * t) + 0.5 * np.sin(2 * np.pi * 105 * t) + 0.25 * np.sin(2 * np.pi * 140 * t)
    return peak((tone * (0.8 + 0.2 * np.sin(2 * np.pi * 1.5 * t))).astype(np.float32))


def gate_alarm() -> np.ndarray:
    """닫히기 직전: 둥근 경보 4번 (네모파 대신 세모파, 높은 음 깎음)"""
    return peak(ffx(np.concatenate([x for _ in range(4) for x in (tri(780.0, 0.09, 8.0), silence(0.05))]), "lowpass=f=2400"))


def whoosh(dur: float, seed: int) -> np.ndarray:
    """점프: 잡음이 위로 쓸려 올라가는 "휘익" + 오르는 음"""
    t = np.arange(int(SR * dur)) / SR
    noise = np.random.default_rng(seed).uniform(-1, 1, len(t)).astype(np.float32)
    k = t / dur
    # 낮은 소리를 점점 덜 깎아 쓸려 올라가게: 두 대역을 시간에 따라 섞는다
    low = ffx(noise, "lowpass=f=700")[: len(t)]
    high = ffx(noise, "highpass=f=1800,lowpass=f=6000")[: len(t)]
    env = np.minimum(t / 0.03, 1.0) * np.minimum((dur - t) / 0.12, 1.0)
    return tail_fade(peak(((low * (1 - k) + high * k) * env).astype(np.float32) + 0.5 * sweep(180.0, 1400.0, dur, 2.0, 0.02)), 0.08)


# ── 레벨업 카드 소리 (계획서 33번): 배경음과 같은 F 단조 ──
# 웅장함은 서브 저음이 아니라 150~600Hz 몸통, 짧은 잔향, 좌우 폭, 소리 층(금속 + 화음 + 반짝임)으로 낸다. 80Hz 아래는 빼고 9kHz 위만 부드럽게 깎는다.
F3, AB3, C4, EB4, F4, AB4, C5_, EB5, F5, AB5, C6, EB6, F6, AB6 = 174.61, 207.65, 261.63, 311.13, 349.23, 415.30, 523.25, 622.25, 698.46, 830.61, 1046.5, 1244.51, 1396.91, 1661.22
## 게임 크기(dB), scripts/sfx.gd의 SOUNDS와 같게
CARD_SOUND_DB = {"card_flip": -13.0, "card_rare": -14.0, "card_epic": -12.0, "card_swell": -13.0, "card_unique": -9.0, "card_gather": -13.0, "card_legendary": -8.0}
CARD_PICK_DB = -8.0
SWELL_TIME = 0.16  # 앞면이 보일 때까지 (Juice.CARD_DROP_TIME + 뒤집기 절반): 유니크의 "쉬익"이 이 길이
LEGEND_REVEAL_GAP = 0.34  # 모임이 시작되고 앞면이 보일 때까지 (Juice.CARD_LEGEND_GATHER + 뒤집기 절반)
## d1: 금속이 앞에 서는 단단한 쪽 (화음은 3음 없는 5도), d2: 화음이 앞에 서는 넓은 쪽 (3음을 넣고 잔향이 길다)
CARD_STYLES = {
    "d1": {"pick_chord": [F3, C4, F4, C5_], "metal": 0.85, "chord": 1.0, "room": 1.0, "wet": 0.24, "spread": 0.55, "open": 2600.0},
    "d2": {"pick_chord": [F3, AB3, C4, F4, AB4], "metal": 0.7, "chord": 1.0, "room": 1.25, "wet": 0.32, "spread": 0.85, "open": 3400.0},
}


def stereo(a: np.ndarray, pan: float = 0.0) -> np.ndarray:
    """모노 → 스테레오. pan -1 왼쪽 ~ 1 오른쪽 (일정 파워)"""
    th = (pan + 1.0) * np.pi / 4.0
    return np.stack([a * np.cos(th), a * np.sin(th)], axis=1).astype(np.float32)


def mix_st(parts: list[tuple[float, np.ndarray]]) -> np.ndarray:
    """(시작 초, 스테레오) 겹치기. 크기는 다시 맞추지 않는다"""
    out = np.zeros((max(int(SR * d) + len(a) for d, a in parts), 2), np.float32)
    for d, a in parts:
        out[int(SR * d):int(SR * d) + len(a)] += a
    return out


def room(a: np.ndarray, seconds: float, wet: float, seed: int) -> np.ndarray:
    """짧은 잔향: 좌우가 다른 감쇠 잡음과 합성곱해 넓게 퍼뜨린다. seconds = -60dB까지 걸리는 시간"""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    out = np.zeros((len(a) + n, 2), np.float32)
    out[:len(a)] = a
    for ch in (0, 1):
        ir = rng.standard_normal(n) * np.exp(-6.9 * t / seconds) * np.minimum(t / 0.008, 1.0)
        ir = ffx((ir / np.max(np.abs(ir)) * 0.9).astype(np.float32), "highpass=f=220,lowpass=f=6500")[:n]
        ir = ir / max(float(np.sqrt((ir ** 2).sum())), 1e-9)
        size = len(a) + n
        wetted = np.fft.irfft(np.fft.rfft(a[:, ch], size) * np.fft.rfft(ir, size), size)
        out[:, ch] += (wetted * wet).astype(np.float32)
    return out


def card_finish(a: np.ndarray, tail: float = 0.05) -> np.ndarray:
    """80Hz 아래 제거 + 9kHz 위만 부드럽게 + 끝 정리 + 크기 맞춤 (채널별)"""
    chain = "highpass=f=80,highpass=f=80,highshelf=f=9000:g=-8:t=q:w=0.7"
    done = np.stack([ffx(a[:, ch], chain)[:len(a)] for ch in (0, 1)], axis=1)
    fade = np.ones(len(done), np.float32)
    k = int(SR * tail)
    fade[-k:] = np.linspace(1.0, 0.0, k)
    done = done * fade[:, None]
    return (done * 10 ** (-1.0 / 20.0) / max(float(np.max(np.abs(done))), 1e-9)).astype(np.float32)


def ring(freqs: list[float], dur: float, decay: float) -> np.ndarray:
    """얇은 금속판: 정수배가 아닌 음들이 빨리 사라짐"""
    t = np.arange(int(SR * dur)) / SR
    return (sum(np.sin(2 * np.pi * f * t) / (i + 1) for i, f in enumerate(freqs)) * np.exp(-decay * t)).astype(np.float32)


def brass(freq: float, dur: float, attack: float, decay: float, opened: float, seed: int) -> np.ndarray:
    """금관·신스 패드 한 음: 톱니파 배음을 저역통과 곡선으로 깎고, 시작할 때 필터가 열렸다 닫힌다 (좌우로 살짝 다른 음정)"""
    t = np.arange(int(SR * dur)) / SR
    env = np.minimum(t / attack, 1.0) * np.exp(-decay * t)
    cutoff = 500.0 + (opened - 500.0) * np.minimum(t / max(attack, 0.005), 1.0) * np.exp(-3.0 * t)
    rng = np.random.default_rng(seed)
    out = np.zeros((len(t), 2), np.float32)
    for ch, cents in ((0, -7.0), (1, 7.0)):
        f = freq * 2 ** (cents / 1200.0)
        for n in range(1, int(9000.0 / f) + 1):
            out[:, ch] += (np.sin(2 * np.pi * n * f * t + rng.uniform(0, 6.28)) / n / (1.0 + (n * f / cutoff) ** 4)).astype(np.float32)
    return out * env[:, None] * 0.5


def chord(notes: list[float], dur: float, attack: float, decay: float, opened: float, spread: float, step: float = 0.0, seed: int = 90) -> np.ndarray:
    """화음: 낮은 음은 가운데, 높은 음일수록 좌우로 벌린다. step만큼 살짝 펼쳐 친다"""
    parts = []
    for i, f in enumerate(notes):
        v = brass(f, dur, attack, decay, opened, seed + i)
        side = spread * (i / max(len(notes) - 1, 1)) * (1 if i % 2 else -1)
        parts.append((i * step, np.stack([v[:, 0] * (1.0 - max(side, 0.0)), v[:, 1] * (1.0 + min(side, 0.0))], axis=1)))
    return mix_st(parts)


def sparkle(freq: float, dur: float = 0.14, pan: float = 0.0, over: float = 0.65) -> np.ndarray:
    """반짝임 한 알 (c의 방향): 빠른 시작, 짧은 꼬리, 2.76배 금속 배음"""
    t = np.arange(int(SR * dur)) / SR
    env = np.minimum(t / 0.0015, 1.0) * np.exp(-26.0 * t)
    return stereo(((np.sin(2 * np.pi * freq * t) + over * np.sin(2 * np.pi * freq * 2.76 * t)) * env).astype(np.float32), pan)


def click(seed: int, dur: float, band: str, db: float) -> np.ndarray:
    """아주 짧은 잡음: 맞닿는 순간의 딱 소리"""
    return peak(noise_burst(dur, 4.6 / dur, band, seed), db)


def hiss(dur: float, band: str, seed: int, power: float = 2.0) -> np.ndarray:
    """"쉬익": 끝으로 갈수록 커지는 바람. 좌우 다른 잡음이라 넓다"""
    k = (np.arange(int(SR * dur)) / (SR * dur)) ** power
    return np.stack([peak(noise_burst(dur, 0.0, band, seed + ch), 0.0) * k for ch in (0, 1)], axis=1).astype(np.float32)


def impact(gain: float, seed: int) -> np.ndarray:
    """"쾅": 400→170Hz 몸통 + 금속판 + 또렷한 시작 (서브 저음 없이)"""
    body = sweep(420.0, 170.0, 0.3, 11.0, 0.001)
    plate = ring([980.0, 1510.0, 2240.0, 3180.0, 4260.0, 5470.0], 0.3, 16.0)
    tick = click(seed, 0.02, "highpass=f=900,lowpass=f=6000", -3.0)
    return stereo(layered([(0.0, body), (0.0, plate * 0.8), (0.0, tick * 0.5)]) * gain)


def pick_d(key: str) -> np.ndarray:
    """"철-컥": 걸쇠 "철" → 잠김 "컥" + 짧게 울리는 금속 + 확정 화음, 잔향 꼬리 약 0.4초"""
    st = CARD_STYLES[key]
    lock_at = 0.06
    cheol = stereo(layered([(0.0, click(61, 0.012, "highpass=f=1800,lowpass=f=7000", -4.0)), (0.0, ring([2700.0, 3900.0], 0.04, 140.0) * 0.5)]) * 0.5, -0.25)
    keok = stereo(layered([(0.0, click(62, 0.012, "highpass=f=1000,lowpass=f=6500", -2.0)), (0.0, sweep(380.0, 190.0, 0.09, 30.0, 0.001) * 0.6), (0.0, ring([2150.0, 2890.0, 3870.0], 0.085, 62.0) * 1.1)]), 0.1)
    dry = mix_st([(0.0, cheol), (lock_at, keok), (lock_at, pick_tail(st))])
    return card_finish(room(dry, 0.42 * st["room"], st["wet"] * 1.5, 63), 0.06)


def pick_tail(st: dict) -> np.ndarray:
    """선택 소리 뒤 금속 울림(F5를 바닥으로 정수배가 아닌 음들, 0.25초 안에 사라짐) + 확정 화음"""
    metal = stereo(ring([F5, F5 * 1.52, F5 * 2.24, F5 * 3.17, F5 * 4.6, F5 * 6.1], 0.28, 17.0) * 0.95 * st["metal"], 0.2)
    harmony = chord(st["pick_chord"], 0.32, 0.006, 11.0, st["open"], st["spread"], 0.004) * 0.34 * st["chord"]
    return mix_st([(0.0, metal), (0.004, harmony)])


## 권총 슬라이드: 뒤로 "척"에서 앞으로 "컥"까지 (초). 사용자 요청 0.06~0.1초
RACK_GAP = 0.08
## e3 원본: zer0_sol "Handgun Reload Sound Effect" (CC0). 게임에는 들어가지 않아 review 아래에 둔다
RACK_RECORDING = os.path.join(ROOT, "review/v070_step5/listen/src/reload.wav")
RACK_RECORDING_FROM = 1.098  # 원본에서 슬라이드를 당기는 순간 (앞은 탄창 소리)
RACK_RECORDING_TO = 1.5


def rack_parts() -> list[tuple[float, np.ndarray]]:
    """합성 장전: 당기는 "척" → 레일 쇳소리·스프링 떨림 → 잠기는 "컥" """
    pull = layered([(0.0, click(81, 0.014, "highpass=f=1200,lowpass=f=7500", -3.0)), (0.0, ring([1780.0, 3050.0, 4300.0], 0.05, 95.0) * 0.55), (0.0, sweep(620.0, 330.0, 0.035, 60.0, 0.001) * 0.35)])
    t = np.arange(int(SR * RACK_GAP)) / SR
    scrape = peak(noise_burst(RACK_GAP, 0.0, "highpass=f=2500,lowpass=f=7000", 82), -14.0) * np.minimum(t / 0.006, 1.0) * np.minimum((RACK_GAP - t) / 0.01, 1.0)
    spring = ring([2950.0, 3120.0, 4480.0], RACK_GAP, 38.0) * (1.0 + 0.5 * np.sin(2 * np.pi * 95.0 * t)) * 0.1
    lock = layered([(0.0, click(83, 0.012, "highpass=f=900,lowpass=f=7000", -1.0)), (0.0, sweep(560.0, 240.0, 0.05, 48.0, 0.001) * 0.75), (0.0, ring([1420.0, 2230.0, 3180.0, 4720.0], 0.11, 48.0) * 0.8)])
    return [(0.0, stereo(pull * 0.8, -0.18)), (0.008, stereo((scrape + spring).astype(np.float32), 0.0)), (RACK_GAP, stereo(lock, 0.1))]


def pick_e(key: str) -> np.ndarray:
    """권총 장전 "철컥" 후보. e1 합성 장전만, e2 합성 장전 + d2 화음 꼬리, e3 실제 녹음(CC0) 다듬음"""
    if key == "e1":
        return card_finish(room(mix_st(rack_parts()), 0.12, 0.18, 84), 0.03)
    if key == "e2":
        st = CARD_STYLES["d2"]
        dry = mix_st([*rack_parts(), (RACK_GAP, pick_tail(st) * 0.8)])
        return card_finish(room(dry, 0.42 * st["room"], st["wet"] * 1.5, 63), 0.06)
    a = decode(RACK_RECORDING, 2)[int(RACK_RECORDING_FROM * SR):int(RACK_RECORDING_TO * SR)]
    # 녹음은 얇고 아주 밝아서(무게중심 약 6kHz) 몸통을 올리고 높은 쪽을 깎는다
    eq = "equalizer=f=450:t=q:w=1.2:g=12,equalizer=f=1200:t=q:w=1:g=5,highshelf=f=6500:g=-11:t=q:w=0.7,lowpass=f=12000"
    a = np.stack([ffx(a[:, ch], eq)[:len(a)] for ch in (0, 1)], axis=1)
    a = a / max(float(np.abs(a).max()), 1e-9)
    a[:int(0.003 * SR)] *= np.linspace(0.0, 1.0, int(0.003 * SR))[:, None]  # 잘라 낸 자리의 튐 방지
    return card_finish(a.astype(np.float32), 0.08)


def show_d(key: str) -> dict[str, np.ndarray]:
    """등장 세트: 위 등급일수록 화음 몸통과 잔향이 커진다. 유니크·레전드리는 쉬익 → 쾅 → 넓은 화음"""
    st = CARD_STYLES[key]
    op, sp, r, w = st["open"], st["spread"], st["room"], st["wet"]
    c = st["chord"]
    t = np.arange(int(SR * 0.11)) / SR
    air = peak(noise_burst(0.11, 0.0, "highpass=f=1200,lowpass=f=5600", 71), 0.0) * (np.minimum(t / 0.02, 1.0) * np.exp(-30.0 * np.maximum(t - 0.02, 0.0)))
    flip = room(stereo(layered([(0.0, air), (0.03, ring([1840.0, 2790.0], 0.07, 75.0) * 0.45)])), 0.14, w * 0.6, 72)
    rare = room(mix_st([(0.0, sparkle(F6, 0.14, -0.2)), (0.0, chord([F4, C5_], 0.3, 0.006, 13.0, op, sp) * 0.3 * c)]), 0.32 * r, w, 73)
    epic = room(mix_st([(0.0, sparkle(C6, 0.14, -0.3)), (0.075, sparkle(F6, 0.16, 0.3)), (0.0, chord([F3, C4, F4, AB4], 0.55, 0.008, 6.5, op, sp, 0.008) * 0.42 * c)]), 0.55 * r, w * 1.2, 74)
    swell = room(hiss(SWELL_TIME, "highpass=f=700,lowpass=f=6500", 75), 0.1, w * 0.5, 76)[:int(SR * SWELL_TIME)]
    unique = room(mix_st([
        (0.0, impact(0.7, 77)),
        (0.0, chord([F3, C4, F4, AB4, C5_], 1.0, 0.012, 3.6, op, sp, 0.006) * 0.5 * c),
        (0.0, sparkle(F6, 0.18, -0.45)), (0.05, sparkle(AB6, 0.18, 0.45)),
    ]), 0.8 * r, w * 1.5, 78)
    # 레전드리 모임: 쉬익 + F 단조를 타고 올라가는 반짝임. 끝이 앞면 등장과 맞닿는다
    climb = [(0.0, C5_), (0.1, EB5), (0.18, F5), (0.24, AB5), (0.29, C6)]
    gather = mix_st([(0.0, hiss(LEGEND_REVEAL_GAP, "highpass=f=500,lowpass=f=6000", 79) * 0.6)] + [(d, sparkle(f, 0.05, (-1) ** i * 0.5) * (0.35 + 0.65 * d / 0.29)) for i, (d, f) in enumerate(climb)])[:int(SR * LEGEND_REVEAL_GAP)]
    # 레전드리: 쾅 + F 단조 7화음을 넓게 + 위로 올라가는 반짝임 (Ab 장조의 음이라 밝게 들린다)
    legendary = room(mix_st([
        (0.0, impact(0.85, 80)),
        (0.0, chord([F3, C4, AB4, C5_, EB5, AB5], 1.5, 0.018, 2.4, op * 1.2, sp, 0.012, 100) * 0.55 * c),
        (0.0, sparkle(AB5, 0.2, -0.6)), (0.07, sparkle(C6, 0.2, 0.6)), (0.14, sparkle(EB6, 0.2, -0.35)), (0.21, sparkle(AB6, 0.3, 0.35)),
    ]), 1.1 * r, w * 1.7, 81)
    return {
        "card_flip": card_finish(flip, 0.03),
        "card_rare": card_finish(rare),
        "card_epic": card_finish(epic, 0.08),
        "card_swell": card_finish(swell, 0.005),
        "card_unique": card_finish(unique, 0.12),
        "card_gather": card_finish(gather, 0.005),
        "card_legendary": card_finish(legendary, 0.2),
    }


def show_demo(sounds: dict[str, np.ndarray]) -> np.ndarray:
    """게임 크기로 노멀 → 레어 → 에픽 → 유니크 → 레전드리 순서로 이어 붙인다"""
    g = {name: sounds[name] * 10 ** (db / 20.0) for name, db in CARD_SOUND_DB.items()}
    flip = g["card_flip"]
    scenes = [flip, mix_st([(0.0, flip), (0.0, g["card_rare"])]), mix_st([(0.0, flip), (0.0, g["card_epic"])]),
              mix_st([(0.0, g["card_swell"]), (SWELL_TIME, flip), (SWELL_TIME, g["card_unique"])]),
              mix_st([(0.0, g["card_gather"]), (LEGEND_REVEAL_GAP, flip), (LEGEND_REVEAL_GAP, g["card_legendary"])])]
    gap = stereo(silence(0.75))
    parts: list[np.ndarray] = []
    for scene in scenes:
        parts += [scene, gap]
    return np.concatenate(parts)


def listen5() -> None:
    out = os.path.join(ROOT, "review/v070_step5/listen")
    gap = stereo(silence(0.5))
    for key in CARD_STYLES:
        a = pick_d(key) * 10 ** (CARD_PICK_DB / 20.0)
        save(np.concatenate([a, gap, a, gap, a]), f"{out}/card_pick_{key}.ogg", quality=6)
        save(show_demo(show_d(key)), f"{out}/card_show_{key}.ogg", quality=6)


def listen6() -> None:
    gap = stereo(silence(0.5))
    for key in ("e1", "e2", "e3"):
        a = pick_e(key) * 10 ** (CARD_PICK_DB / 20.0)
        save(np.concatenate([a, gap, a, gap, a]), os.path.join(ROOT, f"review/v070_step5/listen/card_pick_{key}.ogg"), quality=6)


def gate_sounds() -> dict[str, np.ndarray]:
    return {
        "gate_assemble": layered([(0.0, clank(1.4)), (0.15, clank(1.2)), (0.3, clank(1.0))]),
        "gate_lock": layered([(0.0, trim(load("kenney_impact/impactMetal_heavy_000"), 0.2, 0.1)), (0.04, trim(load("kenney_sci-fi/forceField_000"), 0.4, 0.2))]),
        "gate_hum": gate_hum(),
        "gate_alarm": gate_alarm(),
        "gate_collapse": layered([(0.0, trim(load("kenney_sci-fi/explosionCrunch_003"), 0.55, 0.2)), (0.0, sweep(500.0, 70.0, 0.55, 3.0) * 0.5)]),
        "warp_charge": rising(110.0, 520.0, 5.0),
        "warp_done": whoosh(0.7, 21),
        "takeoff": layered([(0.0, trim(pitch(load("kenney_sci-fi/spaceEngineLow_001"), 0.8), 0.9, 0.25)), (0.0, rising(60.0, 130.0, 0.9, 0.2) * 0.6)]),
        "warp_launch": rising(150.0, 900.0, 0.95),
        "warp_arrive": layered([(0.0, trim(load("kenney_sci-fi/lowFrequency_explosion_000"), 0.5, 0.2)), (0.0, trim(load("kenney_sci-fi/forceField_002"), 0.4, 0.2) * 0.6)]),
        "landing": layered([(0.0, rising(300.0, 80.0, 0.7, 0.2) * 0.7), (0.62, trim(load("kenney_impact/impactSoft_heavy_000"), 0.3, 0.1))]),
    }


def game_sounds() -> dict[str, np.ndarray]:
    out = {name: load(src) for name, src in COPY.items()}
    out.update({name: fn() for name, fn in BREAKS.items()})
    out["barrage_warn"], out["barrage_fire"] = CHOICE["barrage"]()
    out["levelup"] = CHOICE["levelup"]()
    out["card_show"] = card_c()  # 사용자 선택 (계획서 22번)
    # 경비선은 지금 금속 소리를 짧게 (파괴음 1.55초 → 게임의 0.9배 음 높이까지 반영해 0.5초)
    out["hit_guard_0"] = trim(load("kenney_sci-fi/impactMetal_000"), 0.3, 0.1)
    out["hit_guard_1"] = trim(load("kenney_sci-fi/impactMetal_002"), 0.3, 0.1)
    out["destroy_guard"] = trim(load("kenney_sci-fi/explosionCrunch_003"), 0.45, 0.15)
    out["hit_jelly"], out["destroy_jelly"] = CHOICE["jelly"]()
    out["hit_bug"], out["destroy_bug"] = CHOICE["bug"]()
    for grade, s in enumerate(CHOICE["pickup"]()):
        out[f"pickup_{grade}"] = s
    out.update(gate_sounds())
    out["card_pick"] = pick_e(CARD_CHOICE["pick"])
    out.update(show_d(CARD_CHOICE["show"]))
    return out


def build() -> None:
    for name, a in game_sounds().items():
        save(a, f"{OUT}/{name}.wav")


if __name__ == "__main__":
    if "--listen" in sys.argv:
        listen()
        print("후보 → review/v070_step4c/listen/")
    elif "--listen6" in sys.argv:
        listen6()
    elif "--listen5" in sys.argv:
        listen5()
        print("카드 소리 후보 → review/v070_step5/listen/")
    elif "--listen3" in sys.argv:
        listen3()
        print("창 소리 후보 → review/v070_step4c/listen/card2_*.ogg")
    elif "--listen2" in sys.argv:
        listen2()
        print("2차 후보 → review/v070_step4c/listen/")
    else:
        build()
        print("게임 효과음 → assets/sfx/game/")
