"""게임 효과음 만들기: Kenney 원본(assets/sfx/kenney_*/*.ogg)을 다듬거나 직접 합성해 assets/sfx/game/*.wav로 저장한다.

- wav로 두는 이유: 웹에서 ogg는 재생을 시작할 때마다 디코더를 새로 만들어 비싸다 (v0.7.0 4c 측정, review/v070_step4c/perf.md).
- 다듬기는 ffmpeg 필터(음 높이 = 재생 속도, 높은 음 깎기 lowpass, 고음 살리기 treble, 꼬리 자르기 + 짧게 줄이기)로 한다.
- 합성 소리(종소리 "띠링", 올라가는 "띠리링", 낮은 에너지 소리)는 numpy로 만든다. 같은 입력이면 항상 같은 결과다.
- --listen: 사용자가 들어 보고 고를 후보를 review/v070_step4c/listen/*.ogg로 만든다.
- --listen2: 2차 후보(적 소리, 레벨업)를 만든다. 배경음은 tools/make_music.py가 만든다.

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
## 그대로 wav로 바꾸는 Kenney 소리: 게임 이름 → 원본
COPY = {
    "shoot_0": "kenney_sci-fi/laserSmall_000", "shoot_1": "kenney_sci-fi/laserSmall_002",
    "hit_rock_0": "kenney_impact/impactMining_000", "hit_rock_1": "kenney_impact/impactMining_001",
    "player_hit": "kenney_impact/impactMetal_heavy_000",
    "shield_block": "kenney_sci-fi/forceField_000", "card_show": "kenney_interface/open_002",
    "card_pick": "kenney_interface/select_002", "click": "kenney_interface/click_002",
    "cargo_heavy": "kenney_impact/impactSoft_heavy_000",
}


def game_sounds() -> dict[str, np.ndarray]:
    out = {name: load(src) for name, src in COPY.items()}
    out.update({name: fn() for name, fn in BREAKS.items()})
    out["barrage_warn"], out["barrage_fire"] = CHOICE["barrage"]()
    out["levelup"] = CHOICE["levelup"]()
    # 경비선은 지금 금속 소리를 짧게 (파괴음 1.55초 → 게임의 0.9배 음 높이까지 반영해 0.5초)
    out["hit_guard_0"] = trim(load("kenney_sci-fi/impactMetal_000"), 0.3, 0.1)
    out["hit_guard_1"] = trim(load("kenney_sci-fi/impactMetal_002"), 0.3, 0.1)
    out["destroy_guard"] = trim(load("kenney_sci-fi/explosionCrunch_003"), 0.45, 0.15)
    out["hit_jelly"], out["destroy_jelly"] = CHOICE["jelly"]()
    out["hit_bug"], out["destroy_bug"] = CHOICE["bug"]()
    for grade, s in enumerate(CHOICE["pickup"]()):
        out[f"pickup_{grade}"] = s
    return out


def build() -> None:
    for name, a in game_sounds().items():
        save(a, f"{OUT}/{name}.wav")


if __name__ == "__main__":
    if "--listen" in sys.argv:
        listen()
        print("후보 → review/v070_step4c/listen/")
    elif "--listen2" in sys.argv:
        listen2()
        print("2차 후보 → review/v070_step4c/listen/")
    else:
        build()
        print("게임 효과음 → assets/sfx/game/")
