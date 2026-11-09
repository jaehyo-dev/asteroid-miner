"""도감 보상 "금빛 도색": 우주선 그림의 선체 색(흰색·회색 단계)만 void32 금색 단계로 바꾼 그림을 굽는다.
창(파랑)·윤곽(검정)·엔진·포는 그대로라 회전 그림 프레임과 픽셀 격자가 원본과 똑같이 맞는다.
실행: 저장소 맨 위에서 python3 tools/make_gold_paint.py → *_gold.png 3장 (출격 화면은 그다음 tools/build_run_atlas.py)"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from build_run_sprites import recolor  # noqa: E402

CREAM, GOLD, ORANGE, AMBER, RUST = (254, 248, 229), (246, 206, 80), (248, 148, 25), (220, 127, 71), (152, 70, 51)
## 출격·기지 우주선(Foozle 팩 색): 밝은 순 흰색 → 회색 4단계
SHIP_MAP = {(255, 255, 255): CREAM, (199, 220, 208): GOLD, (155, 171, 178): ORANGE, (127, 112, 138): AMBER, (105, 79, 98): RUST}
## 격납고 회전 그림(void32로 줄인 색): 크림·흰색 → 회색 단계. 어두운 보라(그림자·틈)는 그대로
SPIN_MAP = {(255, 255, 255): CREAM, (254, 248, 229): CREAM, (199, 220, 208): GOLD, (165, 178, 157): GOLD,
            (155, 171, 178): ORANGE, (145, 116, 135): AMBER, (92, 81, 100): RUST}
FILES = {"assets/sprites/run/ship.png": SHIP_MAP, "assets/sprites/station/ship.png": SHIP_MAP, "assets/sprites/window/spin.png": SPIN_MAP}


def gold_path(path: str) -> str:
    return path[:-4] + "_gold.png"


def main() -> None:
    for path, mapping in FILES.items():
        src = Image.open(path).convert("RGBA")
        out = recolor(src, mapping)
        # 자체 확인: 크기·투명 칸이 같고, 바뀐 색은 표에 있는 것뿐
        assert out.size == src.size
        for a, b in zip(src.getdata(), out.getdata()):
            assert (a[3] == 0) == (b[3] == 0)
            assert a == b or a[:3] in mapping
        out.save(gold_path(path))


if __name__ == "__main__":
    main()
