"""우주선 크기 시안: 팩 우주선(48x48 칸, 보이는 몸 약 26x28)을 작게 다시 그린다.

소수 배율로 줄이면(nearest) 외곽선이 끊기고 색이 뭉개진다. 그래서 줄인 뒤 픽셀을 정리한다:
1) 몸(검은 외곽선을 뺀 색 부분)만 블록 단위로 줄인다: 블록의 절반 이상(외곽선 없는 불꽃은 4분의 1)이 색이면 그 칸을 칠하고,
   색은 블록에서 가장 많은 색.
   (검은 줄이 블록의 대부분이면 몸 안쪽 패널 선으로 보고 검정으로 남김)
2) 원본이 좌우 대칭이면 왼쪽 절반을 오른쪽에 거울로 복사해 대칭을 지킨다 (피해 그림처럼 비대칭이면 그대로).
3) 원본에 검은 외곽선이 있으면 몸 둘레에 1픽셀 검은 외곽선을 다시 두른다 (팩과 같은 두께·색).
4) 혼자 떨어진 1픽셀 색 점(줄이며 생긴 부스러기)을 지운다.
5) FIXES의 손질(시안을 보고 고친 픽셀)을 마지막에 덮어쓴다.
모든 층(몸·엔진·불꽃·자동 포)은 같은 칸 가운데(24, 24)를 기준으로 줄여 겹쳐 그려도 맞는다.
결과는 48x48 칸 그대로(그림만 작아짐)라 게임의 RunSprites.CELL을 바꾸지 않고 시안을 끼워 볼 수 있다.

실행: python3 tools/shrink_ship.py   → review/ship_options/s60/, s50/ 에 8방향 시트 저장
"""

from __future__ import annotations

import os
import sys
from collections import Counter

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import rotsprite  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/sprites/run")
OUT = os.path.join(ROOT, "review/ship_options")
CELL = 48
BLACK = (0, 0, 0, 255)
SHEETS = ["ship", "ship_engine", "ship_flame_idle", "ship_flame_power", "ship_cannon"]
## 시안 이름 → 배율
SIZES = {"s60": 0.6, "s50": 0.5}
## 손질: (시안, 시트, 프레임) → {(x, y): 색, None(지움) 또는 "mirror"(좌우 반대 칸 색을 복사)}. 좌표는 48 칸 안.
## 줄이면서 오른쪽 날개 창(어두운 파랑 점)이 흰 날개에 묻혀 사라져, 왼쪽 창을 거울로 옮긴다 (피해 4단계 모두).
FIXES: dict[tuple[str, str, int], dict[tuple[int, int], object]] = {
    **{("s60", "ship", f): {(29, 26): "mirror"} for f in range(4)},
    **{("s50", "ship", f): {(27, 25): "mirror"} for f in range(4)},
}


def _opaque(p) -> bool:
    return p[3] > 0


def is_symmetric(img: Image.Image) -> bool:
    """모양(불투명한 칸)이 좌우 거울과 같은지 (칸 가운데 기준). 색은 보지 않는다
    (팩 우주선은 조종석 명암·피해 자국만 좌우가 다르고 모양은 대칭)"""
    a = img.getchannel("A").point(lambda v: 255 if v else 0)
    return list(a.getdata()) == list(a.transpose(Image.FLIP_LEFT_RIGHT).getdata())


def _mirror_shape(img: Image.Image) -> None:
    """모양을 좌우 대칭으로: 한쪽만 칠해진 칸은 반대쪽 칸 색으로 채우고,
    한쪽만 검정(선)이면 왼쪽 것을 따른다. 양쪽 다 색이면 각자 색을 둬 명암·피해 자국을 지킨다."""
    p = img.load()
    for y in range(CELL):
        for x in range(CELL // 2):
            r = CELL - 1 - x
            left, right = p[x, y], p[r, y]
            if _opaque(left) and not _opaque(right):
                p[r, y] = left
            elif _opaque(right) and not _opaque(left):
                p[x, y] = right
            elif _opaque(left) and (left == BLACK) != (right == BLACK):
                p[r, y] = left


def shrink_frame(img: Image.Image, scale: float) -> Image.Image:
    """48 칸 한 장을 scale배로 다시 그려 48 칸 가운데에 놓는다."""
    px = img.load()
    has_outline = sum(1 for p in img.getdata() if p == BLACK) > 0
    c = CELL / 2
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    o = out.load()
    for ty in range(CELL):
        for tx in range(CELL):
            # 결과 칸 (tx, ty)가 덮는 원본 블록 (가운데 기준으로 1/scale배)
            x0, x1 = c + (tx - c) / scale, c + (tx + 1 - c) / scale
            y0, y1 = c + (ty - c) / scale, c + (ty + 1 - c) / scale
            colors: Counter = Counter()
            total = 0
            for sy in range(max(int(y0), 0), min(int(-(-y1 // 1)), CELL)):
                for sx in range(max(int(x0), 0), min(int(-(-x1 // 1)), CELL)):
                    total += 1
                    p = px[sx, sy]
                    if _opaque(p):
                        colors[p] += 1
            if not total:
                continue
            body = {k: v for k, v in colors.items() if k != BLACK}
            n_body = sum(body.values())
            n_black = colors.get(BLACK, 0)
            # 외곽선 없는 얇은 층(엔진 불꽃)은 4분의 1만 차도 칠한다 (반을 기준으로 하면 점으로 흩어짐)
            if n_body * (2 if has_outline else 4) >= total:
                o[tx, ty] = max(body.items(), key=lambda kv: kv[1])[0]
            elif has_outline and n_black * 2 >= total and n_body > 0:
                o[tx, ty] = BLACK  # 몸 안쪽 패널 선
    if is_symmetric(img):
        _mirror_shape(out)
    _remove_specks(out)
    if has_outline:
        _outline(out)
    return out


def _remove_specks(img: Image.Image) -> None:
    """사방(8칸)에 색이 하나도 없는 외톨이 점을 지운다."""
    p = img.load()
    lonely = []
    for y in range(CELL):
        for x in range(CELL):
            if _opaque(p[x, y]) and not any(
                0 <= x + dx < CELL and 0 <= y + dy < CELL and _opaque(p[x + dx, y + dy])
                for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy
            ):
                lonely.append((x, y))
    for xy in lonely:
        p[xy] = (0, 0, 0, 0)


def _outline(img: Image.Image) -> None:
    """색이 있는 칸 둘레(상하좌우)의 빈칸에 1픽셀 검은 외곽선"""
    p = img.load()
    ring = [
        (x, y) for y in range(CELL) for x in range(CELL)
        if not _opaque(p[x, y]) and any(
            0 <= x + dx < CELL and 0 <= y + dy < CELL and _opaque(p[x + dx, y + dy]) and p[x + dx, y + dy] != BLACK
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    ]
    for xy in ring:
        p[xy] = BLACK


def shrink_sheet(name: str, option: str, scale: float) -> Image.Image:
    """게임 시트의 위쪽 방향(0행) 프레임들을 줄이고 손질한 뒤 8방향 시트로"""
    sheet = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    frames = []
    for f in range(sheet.width // CELL):
        fr = shrink_frame(sheet.crop((f * CELL, 0, f * CELL + CELL, CELL)), scale)
        for (x, y), col in FIXES.get((option, name, f), {}).items():
            if col == "mirror":
                col = fr.getpixel((CELL - 1 - x, y))
            fr.putpixel((x, y), col if col else (0, 0, 0, 0))
        frames.append(fr)
    strip = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * CELL, 0))
    return rotsprite.dir8_sheet(strip, CELL, CELL)


def build() -> None:
    for option, scale in SIZES.items():
        os.makedirs(os.path.join(OUT, option), exist_ok=True)
        for name in SHEETS:
            shrink_sheet(name, option, scale).save(os.path.join(OUT, option, name + ".png"))


if __name__ == "__main__":
    build()
    print("review/ship_options/ 다시 만듦")
