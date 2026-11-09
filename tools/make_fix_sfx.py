"""v0.7.0 고른 소리를 게임 파일로: 카드 등장 A + 모임 소리. 후보 스크립트의 결과를 그대로 쓴다.
창 소리는 review/v070_fix/listen3/make_listen3.py가 만든다.
실행: 저장소 맨 위에서 python3 tools/make_fix_sfx.py → assets/sfx/game/card_a_*.wav"""
import subprocess
import sys

sys.path[:0] = ["tools", "review/v070_fix/listen"]
import make_listen as ml  # noqa: E402
from make_sfx import save  # noqa: E402

OUT = "assets/sfx/game/"
COPY = {
    "review/v070_fix/listen/card_A_normal.ogg": "card_a_normal",
    "review/v070_fix/listen/card_A_epic.ogg": "card_a_epic",
    "review/v070_fix/listen/card_A_unique.ogg": "card_a_unique",
    "review/v070_fix/listen/card_A_legend.ogg": "card_a_legend",
}


def main():
    for src, name in COPY.items():
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, f"{OUT}{name}.wav"], check=True)
    # 모임 소리는 후보 스크립트 안에서만 만들어져 여기서 내보낸다 (유니크 0.16초, 레전드리 0.34초)
    save(ml.swell(0.16), f"{OUT}card_a_swell.wav")
    save(ml.swell(ml.LEGEND_GAP), f"{OUT}card_a_gather.wav")


if __name__ == "__main__":
    main()
