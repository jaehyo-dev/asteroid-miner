"""배경음 만들기: Urgent 이음매 고치기 + 그 위에 얹는 음 층(베이스, 화음/아르페지오, 빠른 리듬 + 멜로디).

- 박: 135 BPM = 정확히 19600샘플(44.1kHz). 곡은 128박 = 2,508,800샘플로 맞춰 모든 층이 같은 길이로 반복된다.
- 원본 Urgent는 머리 0.9초가 비어 있고 꼬리가 소리 중간에 끊겨, 반복할 때 약 1초 곡이 사라졌다. 같은 박 위치의 소리로 채운다.
- 음은 F 단조(4마디마다 화음 변화, F 저음 위). 멜로디는 C4~Ab4: 레벨업 마림바(C5~)와 광물 줍기 종소리(B5~) 아래에 둔다.
- 웹은 곡을 통째로 48kHz 스테레오로 풀어 재생(Sample 방식, 57초 곡 하나에 약 42MB)하고 버스 필터가 동작하지 않는다.
  그래서 기지의 먹먹한 소리도 미리 만든 층을 쓰고, 메모리가 늘지 않게 베이스는 곡에 섞고(곡은 출격 때만 들림),
  8마디마다 똑같은 리듬·멜로디 층은 8마디만, 기지 층은 16마디만 저장한다.
- 음을 놓을 때와 샘플레이트를 낮출 때 모두 원형으로 처리해 반복 이음매가 생기지 않는다. 같은 입력이면 항상 같은 결과다.

게임에 넣기: python3 tools/make_music.py   후보 듣기: python3 tools/make_music.py --listen
"""

from __future__ import annotations

import ast
import os
import re
import sys

import numpy as np

import make_sfx as ms

SR = ms.SR
BEAT = 19600  # 135 BPM의 한 박(샘플)
BAR = BEAT * 4
LOOP = BEAT * 128  # 2,508,800샘플 = 56.889초
SHORT = BEAT * 32  # 짧게 저장하는 층: 8마디 (44.1kHz에서 샘플이 딱 떨어짐. 48kHz 웹에서도 어긋남은 반복마다 0.1ms 미만)
BASE_LEN = BEAT * 64  # 기지 층: 16마디
SONG_START = 39902  # 원본에서 소리가 시작하는 곳 (0.9048초). 앞은 비어 있음
GRID = SONG_START + 1540  # 곡의 16분음표 펄스가 터지는 곳: 모든 음을 여기에 맞춘다 (측정: 어느 구간이든 ±3ms). 펄스에 강박 차이가 없어 이곳을 1마디 첫 박으로 삼음
MUSIC = os.path.join(ms.ROOT, "assets/music")
SRC_SONG = f"{MUSIC}/srg774_dark_scifi/urgent.ogg"
BASE_CUTOFF = 450.0  # 기지의 먹먹한 층: 이 위를 깎음

## 곡의 F 페달 위에서 4마디마다 바뀌는 화음 (분석 결과는 review/v070_step4c/listen.md). (이름, 베이스 MIDI, 화음 MIDI)
CHORDS = [
    ("Fm", 41, [53, 56, 60, 65]),
    ("Db", 37, [49, 53, 56, 61]),
    ("C", 36, [48, 52, 55, 60]),
    ("Gm7b5", 43, [55, 58, 61, 65]),
    ("Eb7", 39, [51, 55, 58, 61]),
    ("Db", 37, [49, 53, 56, 61]),
    ("C", 36, [48, 52, 55, 60]),
    ("Fm", 41, [53, 56, 60, 65]),
]
## 멜로디 모티프: 8마디마다 반복 (박, 길이, MIDI). 내려오다 Db→C 반음으로 한숨 쉬는 것이 기억에 남는 부분
MOTIF = [
    (0.0, 0.75, 68), (0.75, 0.75, 67), (1.5, 0.5, 65), (2.0, 1.0, 60), (4.0, 0.5, 61), (4.5, 1.5, 60),
    (16.0, 0.75, 68), (16.75, 0.75, 67), (17.5, 0.5, 65), (18.0, 1.0, 63), (20.0, 0.5, 61), (20.5, 1.5, 60),
]
MOTIF_BEATS = 32


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def render(events: list, voice) -> np.ndarray:
    """(박, 길이, MIDI 또는 (MIDI, 세기))를 원형으로 쌓는다: 곡 끝을 넘는 소리는 처음으로 이어진다"""
    out = np.zeros(LOOP, np.float32)
    cache = {}
    for beat, length, note in events:
        midi, gain = note if isinstance(note, tuple) else (note, 1.0)
        key = (midi, length)
        if key not in cache:
            cache[key] = voice(hz(midi), length * BEAT / SR)
        ms.stamp(out, cache[key] * gain, GRID + int(round(beat * BEAT)))
    return out


def echo(a: np.ndarray, beats: float, gain: float, count: int = 2) -> np.ndarray:
    """박에 맞춘 메아리 (우주 공간 느낌). np.roll이라 이음매가 없다"""
    out = a.copy()
    for i in range(1, count + 1):
        out += np.roll(a, int(round(i * beats * BEAT))) * gain ** i
    return out


def saw(freq: float, t: np.ndarray, harmonics: int, tilt: float = 1.0, detune: float = 0.0) -> np.ndarray:
    """배음을 직접 더한 어두운 톱니파 (tilt가 클수록 높은 배음이 작음)"""
    f = freq * 2 ** (detune / 1200)
    return sum(np.sin(2 * np.pi * f * k * t) / k ** tilt for k in range(1, harmonics + 1))


def bass_voice(freq: float, dur: float) -> np.ndarray:
    """베이스: 폰 스피커에서도 들리게 배음을 남긴 어두운 톱니파"""
    t = np.arange(int(SR * (dur + 0.05))) / SR
    env = np.minimum(t / 0.006, 1.0) * np.exp(-1.6 * t) * np.minimum((dur + 0.05 - t) / 0.05, 1.0)
    return (saw(freq, t, 7, 1.3) * env).astype(np.float32)


def pluck_voice(freq: float, dur: float) -> np.ndarray:
    """어두운 신스 플럭: 두 음을 살짝 어긋나게 겹치고 높은 배음이 먼저 사라짐"""
    t = np.arange(int(SR * max(dur + 0.12, 0.2))) / SR
    tone = sum((np.sin(2 * np.pi * freq * k * t) + np.sin(2 * np.pi * freq * 1.004 * k * t)) * np.exp(-(9.0 + 5.0 * k) * t) / k for k in range(1, 7))
    return ms.tail_fade((tone * np.minimum(t / 0.003, 1.0)).astype(np.float32), 0.04)


def long_pluck_voice(freq: float, dur: float) -> np.ndarray:
    """멜로디용 플럭: 아르페지오와 같은 음색, 더 길게 울림"""
    t = np.arange(int(SR * (dur + 0.25))) / SR
    tone = sum((np.sin(2 * np.pi * freq * k * t) + np.sin(2 * np.pi * freq * 1.004 * k * t)) * np.exp(-(2.5 + 3.0 * k) * t) / k for k in range(1, 7))
    return ms.tail_fade((tone * np.minimum(t / 0.004, 1.0)).astype(np.float32), 0.06)


def pad_voice(freq: float, dur: float) -> np.ndarray:
    """어두운 패드: 천천히 커지고 줄어들며 어긋난 세 음이 서로 맥놀이함"""
    t = np.arange(int(SR * (dur + 0.6))) / SR
    tone = saw(freq, t, 6, 1.5, -7) + saw(freq, t, 6, 1.5, 0) + saw(freq, t, 6, 1.5, 7)
    env = np.minimum(t / 0.7, 1.0) * np.minimum((dur + 0.6 - t) / 0.8, 1.0) * (0.85 + 0.15 * np.sin(2 * np.pi * 0.28 * t))
    return (tone * env).astype(np.float32)


def stab_voice(freq: float, dur: float) -> np.ndarray:
    """짧은 화음 찌르기"""
    t = np.arange(int(SR * 0.2)) / SR
    return ms.tail_fade((saw(freq, t, 5, 1.4) * np.minimum(t / 0.004, 1.0) * np.exp(-16.0 * t)).astype(np.float32), 0.03)


def bell_voice(freq: float, dur: float) -> np.ndarray:
    """부드러운 금속성 음: 사인 + 금방 사라지는 어긋난 배음"""
    t = np.arange(int(SR * (dur + 0.35))) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-6.0 * t)
    return (tone * np.minimum(t / 0.012, 1.0) * np.exp(-2.2 * t) * np.minimum((dur + 0.35 - t) / 0.2, 1.0)).astype(np.float32)


def lead_voice(freq: float, dur: float) -> np.ndarray:
    """리드: 홀수 배음의 네모파에 가까운 소리, 조금 뒤부터 떨림"""
    t = np.arange(int(SR * (dur + 0.04))) / SR
    vib = 0.006 * np.minimum(t / 0.35, 1.0) * np.sin(2 * np.pi * 5.5 * t)
    ph = 2 * np.pi * np.cumsum(freq * (1.0 + vib)) / SR
    tone = sum(np.sin(k * ph) / k for k in (1, 3, 5, 7))
    env = np.minimum(t / 0.008, 1.0) * (0.75 + 0.25 * np.exp(-5.0 * t)) * np.minimum((dur + 0.04 - t) / 0.04, 1.0)
    return (tone * env).astype(np.float32)


## 악보
def bass_events(active: bool) -> list:
    """베이스 선율: 근음 - 5도 - 7도를 오가고, 화음이 바뀌기 직전에 다음 근음의 반음 위에서 내려앉음"""
    out = []
    for c, (_, root, _tones) in enumerate(CHORDS):
        next_root = CHORDS[(c + 1) % len(CHORDS)][1]
        for bar in range(4):
            b = (c * 4 + bar) * 4.0
            last = next_root + 1 if bar == 3 else root + 10
            if active:
                out += [(b, 0.75, root), (b + 0.75, 0.75, root), (b + 1.5, 0.5, root + 12), (b + 2, 0.5, root + 7),
                        (b + 2.5, 0.5, root + 10), (b + 3, 0.5, root + 7), (b + 3.5, 0.5, last)]
            else:
                out += [(b, 1.5, root), (b + 1.5, 0.5, root), (b + 2, 1.0, root + 7 if bar % 2 == 0 else root + 12), (b + 3, 1.0, last)]
    return out


def arp_events() -> list:
    """16분음표 아르페지오: 화음을 오르내리고 박마다 강세"""
    order = [0, 1, 2, 3, 2, 1]
    out = []
    for c, (_, _root, tones) in enumerate(CHORDS):
        for i in range(4 * 4 * 4):
            out.append((c * 16 + i * 0.25, 0.25, (tones[order[i % 6]], 1.0 if i % 4 == 0 else 0.62)))
    return out


def pad_events() -> list:
    return [(c * 16.0, 16.0, note) for c, (_, _root, tones) in enumerate(CHORDS) for note in tones[:3]]


def stab_events() -> list:
    """엇박 찌르기: 2박 뒤 절반과 4박째"""
    out = []
    for c, (_, _root, tones) in enumerate(CHORDS):
        for bar in range(4):
            for beat in (1.5, 3.0):
                out += [((c * 4 + bar) * 4.0 + beat, 0.5, (n, 1.0 if beat == 1.5 else 0.7)) for n in tones[:3]]
    return out


def motif_events() -> list:
    return [(rep * MOTIF_BEATS + b, length, note) for rep in range(128 // MOTIF_BEATS) for b, length, note in MOTIF]


def active_rms(a: np.ndarray) -> float:
    """소리가 나는 구간의 평균 크기: 쉬는 구간이 많은 멜로디도 들리는 크기로 비교한다 (50ms 단위, 최고 구간보다 30dB 이상 작으면 쉬는 것으로 봄)"""
    w = SR // 20
    blocks = np.sqrt(np.mean(a[: len(a) // w * w].reshape(-1, w) ** 2, axis=1))
    return float(np.sqrt(np.mean(blocks[blocks > blocks.max() * 10 ** (-30 / 20)] ** 2)))


def fit_rms(a: np.ndarray, db: float) -> np.ndarray:
    """소리 나는 구간의 크기를 db로 맞추되, 최고 크기는 -1dB를 넘지 않게 (넘으면 파일에서 찌그러진다)"""
    out = a * (10 ** (db / 20.0) / active_rms(a))
    return ms.peak(out, -1.0) if np.max(np.abs(out)) > 10 ** (-1 / 20) else out


## 층 파일은 소리 나는 구간의 크기를 맞춰 두고, 실제 크기는 juice.gd의 MUSIC_STEMS·MUSIC_BASS_DB가 정한다
STEM_RMS_DB = -18.0


def candidate(key: str) -> dict[str, np.ndarray]:
    """후보의 층: bass(곡에 섞어 출격 직후부터), harmony(1분), top(2분: 빠른 리듬 + 멜로디). 후보마다 주인공이 다르다"""
    ticks = ms.fast_pulse_layer(LOOP, BEAT / SR, (GRID % BEAT) / SR)
    if key == "a":  # 어두운 신스 아르페지오 중심
        bass = render(bass_events(False), bass_voice)
        harmony = echo(render(arp_events(), pluck_voice), 0.75, 0.3)
        melody = echo(render(motif_events(), long_pluck_voice), 0.75, 0.3)
        melody_db, ticks_db = -19.0, -28.0
    elif key == "b":  # 패드 화음 + 베이스 중심
        bass = render(bass_events(True), bass_voice)
        harmony = render(pad_events(), pad_voice)
        melody = echo(render(motif_events(), bell_voice), 1.5, 0.25, 1)
        melody_db, ticks_db = -20.0, -28.0
    else:  # 짧은 리드 멜로디 중심
        bass = render(bass_events(False), bass_voice)
        harmony = render(stab_events(), stab_voice)
        melody = echo(render(motif_events(), lead_voice), 0.75, 0.2, 1)
        melody_db, ticks_db = -16.0, -28.0
    top = fit_rms(melody, melody_db) + fit_rms(ticks, ticks_db)
    return {"bass": fit_rms(bass, STEM_RMS_DB), "harmony": fit_rms(harmony, STEM_RMS_DB), "top": fit_rms(top, STEM_RMS_DB)}


def rhythm() -> np.ndarray:
    return ms.pulse_layer(LOOP, BEAT / SR, (GRID % BEAT) / SR)


## 곡 이음매
def pick_fill_bars(x: np.ndarray) -> int:
    """머리를 채울 소리를 몇 마디 뒤에서 가져올지: 곡 끝에서 이어질 때와 첫 소리로 넘어갈 때 모두 가장 비슷한 곳"""
    w = BEAT // 2
    mono = x.mean(axis=1)
    best, best_score = 1, -2.0
    for bars in range(1, 31):
        shift = bars * BAR
        into = np.corrcoef(mono[SONG_START:SONG_START + w], mono[SONG_START + shift:SONG_START + shift + w])[0, 1]
        out_of = np.corrcoef(mono[LOOP - w:LOOP], mono[shift - w:shift])[0, 1]
        if min(into, out_of) > best_score:
            best, best_score = bars, min(into, out_of)
    return best


def fix_song(x: np.ndarray) -> np.ndarray:
    """원본(머리 0.9초 무음)을 정확히 128박의 끊김 없는 반복으로: 빈 머리를 같은 박 위치의 소리로 채운다"""
    x = x[:LOOP].copy()
    fade = int(SR * 0.03)
    shift = pick_fill_bars(x) * BAR
    src = x[shift - fade:shift + SONG_START + fade]  # 앞뒤로 fade만큼 여유
    up = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    y = x.copy()
    y[:SONG_START] = src[fade:fade + SONG_START]
    y[SONG_START:SONG_START + fade] = src[fade + SONG_START:] * (1 - up) + x[SONG_START:SONG_START + fade] * up
    y[LOOP - fade:] = x[LOOP - fade:] * (1 - up) + src[:fade] * up
    return y


def resample_loop(a: np.ndarray, n: int, cutoff: float | None = None) -> np.ndarray:
    """반복을 전제로 주파수 영역에서 샘플 수를 줄인다 (곡 끝과 처음이 이어짐). cutoff: 2차 저역 필터(먹먹함)"""
    s = np.fft.rfft(a)
    if cutoff:
        # Q 0.5 2차 저역 필터의 크기, 위상은 그대로
        s = s / (1.0 + (np.fft.rfftfreq(len(a), 1 / SR) / cutoff) ** 2)
    return (np.fft.irfft(s[: n // 2 + 1], n) * (n / len(a))).astype(np.float32)


## 게임에서 섞는 대로 후보 만들기 (scripts/music.gd, scripts/logic/music_mix.gd와 같은 계산, 수치는 juice.gd)
def juice(name: str):
    with open(os.path.join(ms.ROOT, "scripts/juice.gd"), encoding="utf-8") as f:
        return ast.literal_eval(re.search(rf"^const {name} := (.+)$", f.read(), re.M).group(1))


def stem_db(i: int, time: float) -> float:
    start, fade, db = juice("MUSIC_STEMS")[i]
    return 20.0 * np.log10(max(float(np.clip((time - start) / fade, 0.0, 1.0)), 0.001)) + db


def with_bass(song: np.ndarray, bass: np.ndarray) -> np.ndarray:
    """곡 + 베이스 (게임에서 곡을 RUN_DB로 낼 때 베이스가 MUSIC_BASS_DB가 되게)"""
    return song + bass[:, None] * 10 ** ((juice("MUSIC_BASS_DB") - juice("MUSIC_RUN_DB")) / 20.0)


def loop_tail(a: np.ndarray, n: int) -> np.ndarray:
    """곡의 앞 n샘플을 그 자체로 반복되게: 끝부분을 곡 맨 끝(앞부분 바로 전 소리)과 겹쳐 잇는다"""
    fade = int(SR * 0.05)
    up = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    y = a[:n].copy()
    y[n - fade:] = a[n - fade:n] * (1 - up) + a[len(a) - fade:] * up
    return y


def run_mix(song: np.ndarray, muffled: np.ndarray, stems: list[np.ndarray], start: float, dur: float) -> np.ndarray:
    """게임 시간 start초부터 dur초. start가 0이면 기지 상태에서 출격하는 순간부터. 음량은 게임처럼 부드럽게 따라감"""
    block = 1024
    k = 1.0 - np.exp(-juice("MUSIC_SMOOTH") * block / SR)
    run_db, base_db, silent = juice("MUSIC_RUN_DB"), juice("MUSIC_BASE_DB"), juice("MUSIC_SILENT_DB")
    tables = [juice("MUSIC_STEMS")[i] for i in range(len(stems))]

    def targets(t: float) -> np.ndarray:
        layers = [20.0 * np.log10(max(float(np.clip((t - s) / f, 0.0, 1.0)), 0.001)) + d for s, f, d in tables]
        return np.array([run_db, silent] + layers)

    state = targets(start)
    if start == 0:
        state[:2] = [silent, base_db]
    pos = int(SR * start)
    out = []
    for i in range(0, int(SR * dur), block):
        state = state + (targets(start + i / SR) - state) * k
        idx = pos + i + np.arange(block)
        g = 10 ** (state / 20.0)
        # 층마다 길이가 달라도 각자 반복한다 (게임과 같음)
        mono = muffled[idx % len(muffled)] * g[1] + sum(s[idx % len(s)] * g[2 + j] for j, s in enumerate(stems))
        out.append(song[idx % len(song)] * g[0] + mono[:, None])
    return np.concatenate(out).astype(np.float32)


def song_parts() -> tuple[np.ndarray, np.ndarray]:
    """(고친 곡, 기지의 먹먹한 층)"""
    song = fix_song(ms.decode(SRC_SONG, 2))
    return song, loop_tail(resample_loop(song.mean(axis=1), LOOP, BASE_CUTOFF), BASE_LEN)


def listen() -> None:
    song, muffled = song_parts()
    pulse = rhythm()[:SHORT]
    for key in "abc":
        c = candidate(key)
        main = with_bass(song, c["bass"])
        stems = [pulse, c["harmony"], c["top"][:SHORT]]
        ms.save(run_mix(main, muffled, stems, 0.0, 45.0), f"{ms.LISTEN}/bgm3_{key}_start.ogg")
        ms.save(run_mix(main, muffled, stems, 110.0, 40.0), f"{ms.LISTEN}/bgm3_{key}_2min.ogg")
        print(key, {n: (round(20 * np.log10(np.max(np.abs(a))), 1), round(20 * np.log10(active_rms(a)), 1)) for n, a in c.items()}, "층 (최고, 소리 나는 구간 평균) dB")


## 고른 후보 (사용자가 다른 것을 고르면 여기만 바꾸고 다시 실행)
CHOICE = "a"


def build() -> None:
    song, muffled = song_parts()
    c = candidate(CHOICE)
    ms.save(with_bass(song, c["bass"]), f"{MUSIC}/urgent_loop.ogg", quality=6)
    ms.save(resample_loop(muffled, BASE_LEN // 4), f"{MUSIC}/urgent_base.ogg", rate=SR // 4)
    for name, a in {"pulse_layer": rhythm()[:SHORT], "stem_harmony": c["harmony"], "stem_top": c["top"][:SHORT]}.items():
        ms.save(resample_loop(a, len(a) // 2), f"{MUSIC}/{name}.ogg", rate=SR // 2)


if __name__ == "__main__":
    if "--listen" in sys.argv:
        listen()
        print("후보 → review/v070_step4c/listen/bgm3_*.ogg")
    else:
        build()
        print("배경음 → assets/music/")
