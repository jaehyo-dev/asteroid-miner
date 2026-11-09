"""v0.7.0 고른 소리를 게임 파일로: 카드 등장 A + 모임 소리. 후보 스크립트의 결과를 그대로 쓴다.
창 소리는 review/v070_fix/listen3/make_listen3.py가 만든다. 기지 귀환 셔터 소리는 창 소리 2번(공기압 슉 + 딸깍)과 같은 재료로 여기서 만든다.
실행: 저장소 맨 위에서 python3 tools/make_fix_sfx.py → assets/sfx/game/card_a_*.wav, shutter_close·open.wav"""
import subprocess
import sys

sys.path[:0] = ["tools", "review/v070_fix/listen", "review/v070_fix/listen3"]
import make_listen as ml  # noqa: E402
import make_listen3 as l3  # noqa: E402
from make_listen import env  # noqa: E402
from make_sfx import SR, save, stereo  # noqa: E402

OUT = "assets/sfx/game/"
COPY = {
    "review/v070_fix/listen/card_A_normal.ogg": "card_a_normal",
    "review/v070_fix/listen/card_A_epic.ogg": "card_a_epic",
    "review/v070_fix/listen/card_A_unique.ogg": "card_a_unique",
    "review/v070_fix/listen/card_A_legend.ogg": "card_a_legend",
}


# 셔터 시간표 (scripts/juice.gd SHUTTER_*와 같게): 닫히는 데 0.18초 → 쿵, 열리는 데 0.24초
SHUT_CLOSE, SHUT_OPEN = 0.18, 0.24
PLATE = "kenney_impact/impactPlate_medium_000.ogg"


def shutter():
    """닫기: 공기압 슉(창 소리보다 낮고 길게) → 0.18초에 무거운 판 쿵 + 걸쇠 딸깍. 열기: 걸쇠 풀림 딸깍 → 공기 빠지는 슉"""
    hiss = env(l3.noise(SHUT_CLOSE, "highpass=f=400,lowpass=f=2400", 51), 0.12, 2.0)
    thud = l3.click(PLATE, 0.45, 0.62, "lowpass=f=2200")  # 음 높이를 내려 무겁게
    close = l3.mix([(0.0, hiss, 0.8), (SHUT_CLOSE, thud, 1.0), (SHUT_CLOSE + 0.01, l3.click(l3.METAL, 0.05, 0.8), 0.3)], 0.62)
    air = env(l3.noise(SHUT_OPEN, "highpass=f=1000,lowpass=f=5000", 52), 0.02, 9.0)
    opn = l3.mix([(0.0, l3.click(l3.METAL, 0.05, 1.2), 0.35), (0.02, air, 1.0)], SHUT_OPEN + 0.04)
    target = l3.loud(l3.decode("review/v070_fix/listen/card_A_normal.ogg"))
    close = l3.level(close, target)  # 쿵은 장면이 바뀌는 큰 소리라 카드 등장과 같은 크기 (창보다 3dB 큼)
    opn = l3.level(opn, target - 4.0)
    peak_at = int(abs(close).argmax()) / SR
    assert SHUT_CLOSE - 0.01 <= peak_at <= SHUT_CLOSE + 0.08, peak_at  # 가장 큰 순간이 셔터가 닫히는 때
    assert len(opn) / SR <= SHUT_OPEN + 0.05 and len(close) / SR <= 0.65
    save(stereo(close), f"{OUT}shutter_close.wav")
    save(stereo(opn), f"{OUT}shutter_open.wav")


def main():
    for src, name in COPY.items():
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, f"{OUT}{name}.wav"], check=True)
    # 모임 소리는 후보 스크립트 안에서만 만들어져 여기서 내보낸다 (유니크 0.16초, 레전드리 0.34초)
    save(ml.swell(0.16), f"{OUT}card_a_swell.wav")
    save(ml.swell(ml.LEGEND_GAP), f"{OUT}card_a_gather.wav")
    shutter()


if __name__ == "__main__":
    main()
