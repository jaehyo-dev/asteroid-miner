"""진화 카드 소리 (v0.8.0 5단계, 2026-11-13 사용자가 후보 2번씩 고름): 등장·고를 때 소리를 만든다.

재료는 이미 게임에 있는 CC0 소리(assets/sfx/game/)와 numpy 합성음이다.
사용: python3 tools/make_evo_sfx.py  →  assets/sfx/game/evo_show_2.wav, evo_pick_2.wav (파일 이름은 후보 번호 그대로)
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
    pick = load("card_pick")
    # 등장 2 "두 개가 합쳐지는 쿵": 낮게 깐 모으기 → 금속판 쿵 + 레전드리 울림을 낮게
    save("evo_show_2", mix([(pitch(gather, 0.8), 0.0, 0.8), (pitch(plate, 0.85), 0.28, 1.0), (pitch(legend, 0.9), 0.3, 0.6)]))
    # 고를 때 2 "단단한 결합": 카드 고르기 + 금속판 쿵
    save("evo_pick_2", mix([(pick, 0.0, 0.8), (plate, 0.04, 0.9)]), "card_pick")


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    main()
