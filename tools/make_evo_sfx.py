"""진화 카드 소리 후보 (v0.8.0 5단계): 등장 2·3번, 고를 때 2·3번을 만든다. 1번은 기존 레전드리 카드 소리 그대로.

재료는 이미 게임에 있는 CC0 소리(assets/sfx/game/)와 numpy 합성음이다.
사용: python3 tools/make_evo_sfx.py  →  assets/sfx/game/evo_show_2·3.wav, evo_pick_2·3.wav
"""
import os
import wave

import numpy as np

DIR = "assets/sfx/game"
RATE = 44100


def load(name):
    """wav → 스테레오 float 배열 (-1~1)"""
    with wave.open(f"{DIR}/{name}.wav") as w:
        data = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768.0
        if w.getnchannels() == 1:
            data = np.repeat(data, 2)
        return data.reshape(-1, 2)


def pitch(x, k):
    """음 높이를 k배 (재생 속도를 바꿔서, 길이는 1/k)"""
    idx = np.arange(0, len(x) - 1, k)
    i = idx.astype(int)
    f = (idx - i)[:, None]
    return x[i] * (1 - f) + x[i + 1] * f


def tone(freqs, length, decay=6.0, vol=0.25):
    """종소리 같은 사인파 화음 (빠르게 줄어듦)"""
    t = np.arange(int(RATE * length)) / RATE
    s = sum(np.sin(2 * np.pi * f * t) * (0.6 ** i) for i, f in enumerate(freqs))
    s = s * np.exp(-decay * t) * vol
    return np.stack([s, s], 1).astype(np.float32)


def mix(parts):
    """[(소리, 시작 초, 크기)] 를 겹친다"""
    end = max(int(at * RATE) + len(x) for x, at, _ in parts)
    out = np.zeros((end, 2), np.float32)
    for x, at, vol in parts:
        s = int(at * RATE)
        out[s:s + len(x)] += x * vol
    return out


def save(name, x, peak_like="card_a_legend"):
    """기준 소리와 최대 크기를 맞춰 저장 (다른 카드 소리와 크기가 비슷하게)"""
    ref = np.abs(load(peak_like)).max()
    x = x / max(np.abs(x).max(), 1e-6) * ref
    fade = min(len(x), int(RATE * 0.05))
    x[-fade:] *= np.linspace(1, 0, fade)[:, None]  # 끝 딸깍 없게
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(f"{DIR}/{name}.wav", "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(name, round(len(x) / RATE, 2), "초")


def main():
    legend = load("card_a_legend")
    gather = load("card_a_gather")
    plate = load("upgrade_max_3")
    levelup = load("levelup")
    pick = load("card_pick")
    chime = load("pickup_3")
    # 등장 2 "두 개가 합쳐지는 쿵": 낮게 깐 모으기 → 금속판 쿵 + 레전드리 울림을 낮게
    save("evo_show_2", mix([(pitch(gather, 0.8), 0.0, 0.8), (pitch(plate, 0.85), 0.28, 1.0), (pitch(legend, 0.9), 0.3, 0.6)]))
    # 등장 3 "빛나는 화음": 레벨업 마림바를 높게 → 종 화음(도·미·솔·도)이 길게 울림
    save("evo_show_3", mix([(pitch(levelup, 1.26), 0.0, 0.7), (tone([523.3, 659.3, 784.0, 1046.5], 1.4, 3.0), 0.22, 1.0), (legend, 0.22, 0.5)]))
    # 고를 때 2 "단단한 결합": 카드 고르기 + 금속판 쿵
    save("evo_pick_2", mix([(pick, 0.0, 0.8), (plate, 0.04, 0.9)]), "card_pick")
    # 고를 때 3 "반짝 상승": 카드 고르기 + 높은 광물 종 두 번
    save("evo_pick_3", mix([(pick, 0.0, 0.8), (chime, 0.05, 0.8), (pitch(chime, 1.5), 0.16, 0.7)]), "card_pick")


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    main()
