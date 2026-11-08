"""출격 화면 그림 아틀라스 만들기 (assets/sprites/run/*.png 시트 → assets/sprites/run_atlas/atlas_*.png + scripts/run_atlas.gd).

왜: 시트마다 텍스처가 달라 그림을 그릴 때마다 그리기 호출이 끊겼다 (4b 측정 약 1,190번).
같은 텍스처의 사각형은 한 번에 묶여 그려지므로, 모든 그림과 원판·고리·흰 픽셀을 아틀라스에 넣고 사각형으로만 그린다.
WebGL2가 보장하는 최대 텍스처 크기가 2048이라, 운석 묶음(atlas_1)과 나머지(atlas_0) 두 장으로 나눈다.
월드는 운석을 먼저 몰아 그리고 나머지를 그려서 묶음이 두 번 정도만 끊긴다.

다시 만들기: python3 tools/build_run_atlas.py   (tools/build_run_sprites.py로 시트를 바꾼 뒤에도 실행)
"""

from __future__ import annotations

import glob
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/sprites/run")
OUT = os.path.join(ROOT, "assets/sprites/run_atlas")
TABLE = os.path.join(ROOT, "scripts/run_atlas.gd")
SIZE = 2048
## 그림 사이 빈 칸 (nearest로 그려도 옆 그림이 번지지 않게)
PAD = 2
## 원판·고리 반지름 범위 (이보다 큰 원판은 가장 큰 것을 늘여 그림)
MAX_RADIUS = 24
## 흰 사각형 (점·선·파편을 같은 텍스처로 그리려고 씀). 가운데만 잘라 써서 가장자리를 집지 않게 4x4
WHITE = 4


def disc(r: int) -> Image.Image:
    """draw_circle(정수 중심, r)과 같은 픽셀: 픽셀 가운데가 중심에서 r 안이면 칠함. 크기 2r x 2r."""
    img = Image.new("RGBA", (2 * r, 2 * r), (0, 0, 0, 0))
    for y in range(2 * r):
        for x in range(2 * r):
            if (x + 0.5 - r) ** 2 + (y + 0.5 - r) ** 2 <= r * r:
                img.putpixel((x, y), (255, 255, 255, 255))
    return img


def ring(r: int) -> Image.Image:
    """굵기 1 고리 (draw_arc 반지름 r, 굵기 1과 비슷): 거리가 r ± 0.5 안인 픽셀. 크기 2(r+1), 중심은 (r+1, r+1)."""
    n = 2 * (r + 1)
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            d = ((x + 0.5 - r - 1) ** 2 + (y + 0.5 - r - 1) ** 2) ** 0.5
            if abs(d - r) <= 0.5:
                img.putpixel((x, y), (255, 255, 255, 255))
    return img


def pack(items: list[tuple[str, Image.Image]]) -> dict[str, tuple[int, int]]:
    """스카이라인 패킹 (높은 것부터 가장 낮은 자리에). 안 들어가면 ValueError."""
    sky = [0] * SIZE
    out = {}
    for name, img in sorted(items, key=lambda it: (-it[1].height, -it[1].width, it[0])):
        w, h = img.width + PAD, img.height + PAD
        best = None
        for x in range(0, SIZE - img.width + 1, 2):
            y = max(sky[x:min(SIZE, x + w)])
            if y + img.height <= SIZE and (best is None or y < best[1]):
                best = (x, y)
        if best is None:
            raise ValueError(f"아틀라스에 안 들어감: {name}")
        out[name] = best
        for i in range(best[0], min(SIZE, best[0] + w)):
            sky[i] = best[1] + h
    return out


def groups() -> list[list[tuple[str, Image.Image]]]:
    """[나머지 + 원판·고리·흰색, 운석 묶음]"""
    sheets = []
    for f in sorted(glob.glob(f"{SRC}/*.png")):
        name = os.path.basename(f)[:-4]
        if name.startswith("bg_") or name.endswith("_base"):
            continue  # 배경 별은 따로 그리고, *_base는 시트를 만드는 원본
        sheets.append((name, Image.open(f).convert("RGBA")))
    main = [s for s in sheets if not s[0].startswith("rock_")]
    main.append(("white", Image.new("RGBA", (WHITE, WHITE), (255, 255, 255, 255))))
    for r in range(1, MAX_RADIUS + 1):
        main.append((f"disc_{r}", disc(r)))
        main.append((f"ring_{r}", ring(r)))
    return [main, [s for s in sheets if s[0].startswith("rock_")]]


def build() -> dict[str, tuple[int, int, int, int, int]]:
    """아틀라스를 저장하고 표 {이름: (장 번호, x, y, 너비, 높이)}를 돌려준다."""
    os.makedirs(OUT, exist_ok=True)
    table = {}
    for index, items in enumerate(groups()):
        places = pack(items)
        atlas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for name, img in items:
            atlas.paste(img, places[name])
            table[name] = (index, *places[name], img.width, img.height)
        # 쓰지 않는 아래쪽은 잘라 낸다 (높이는 4의 배수)
        bottom = max(y + h for i, x, y, w, h in table.values() if i == index)
        atlas.crop((0, 0, SIZE, (bottom + 3) // 4 * 4)).save(f"{OUT}/atlas_{index}.png", optimize=True)
    lines = [
        "class_name RunAtlas",
        "extends RefCounted",
        "## tools/build_run_atlas.py가 만든 표 (직접 고치지 말 것): 이름 → [아틀라스 번호, x, y, 너비, 높이]",
        "",
        "const ENTRIES := {",
    ]
    lines += [f'\t"{n}": [{i}, {x}, {y}, {w}, {h}],' for n, (i, x, y, w, h) in sorted(table.items())]
    lines += ["}", f"const MAX_RADIUS := {MAX_RADIUS}", ""]
    with open(TABLE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return table


if __name__ == "__main__":
    t = build()
    print(f"아틀라스 {len(t)}칸 → assets/sprites/run_atlas/, scripts/run_atlas.gd")
