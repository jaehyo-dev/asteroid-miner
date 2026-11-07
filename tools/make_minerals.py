"""광물 4등급 그림 만들기: Codex 그림(assets/raw/run/minerals.png) → assets/sprites/run/mineral_0~3.png.

1) 마젠타와 아주 가까운 색만 지움 (pixelate.py의 분홍 가장자리 규칙은 보라 보석까지 지워서 쓰지 않음)
2) 가로로 놓인 4개를 나누고, 등급마다 긴 변 8/10/11/12픽셀로 평균(BOX) 축소 (아주 작은 그림은 nearest보다 모양이 잘 남음)
3) 투명도 0/255, 등급별 색 범위(32색 팔레트 void32 안)에서 가장 가까운 색으로
4) 보라 보석은 팔레트에 중간 보라가 없어 면이 사라지므로 깎인 면(오른쪽 아래 어둡게)과 반짝임 2픽셀을 더한다
사용: python3 tools/make_minerals.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image

import pixelate as px

ROOT = os.path.join(os.path.dirname(__file__), "..")
SIZES = [8, 10, 11, 12]
## 등급별로 쓸 팔레트 색 (어두운 외곽선 + 그 등급 색 계열)
RAMPS = [
    ["000000", "2b1925", "3c3544", "5c5164", "917487", "a5b29d", "fef8e5"],  # 일반: 회색 돌
    ["000000", "2b1925", "125952", "4d80cd", "99e9e6", "fef8e5"],  # 희귀: 시안 결정
    ["000000", "2b1925", "3a1c57", "6b3e75", "a884f3", "fef8e5"],  # 영웅: 보라 보석
    ["000000", "2b1925", "984633", "dc7f47", "f89419", "f6ce50", "fef8e5"],  # 전설: 금덩이
]


def key_strict(img: Image.Image, tolerance: int = 80) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(int)
    d = (a[..., 0] - 255) ** 2 + a[..., 1] ** 2 + (a[..., 2] - 255) ** 2
    a[..., 3] = np.where(d < tolerance ** 2, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def facet(img: Image.Image) -> Image.Image:
    """보라 보석: 안쪽 오른쪽 아래 절반을 한 단계 어둡게, 왼쪽 위에 반짝임 2픽셀."""
    img = img.copy()
    w, h = img.size
    light, dark, shine = (168, 132, 243, 255), (107, 62, 117, 255), (254, 248, 229, 255)
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y)) == light and x + y > (w + h) // 2:
                img.putpixel((x, y), dark)
    lit = [(x, y) for y in range(h) for x in range(w) if img.getpixel((x, y)) == light]
    for p in sorted(lit, key=lambda q: q[0] + q[1])[:2]:
        img.putpixel(p, shine)
    return img


def build() -> list[Image.Image]:
    img = px.crop_to_content(key_strict(Image.open(os.path.join(ROOT, "assets/raw/run/minerals.png"))))
    parts = px.split_columns(img)
    assert len(parts) == 4, f"광물 4개가 아니라 {len(parts)}개로 나뉨"
    outs = []
    for grade, part in enumerate(parts):
        k = SIZES[grade] / max(part.width, part.height)
        size = (max(1, round(part.width * k)), max(1, round(part.height * k)))
        ramp = [tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for c in RAMPS[grade]]
        out = px.map_to_palette(px.binarize_alpha(part.resize(size, Image.Resampling.BOX)), ramp)
        if grade == 2:
            out = facet(out)
        out.save(os.path.join(ROOT, f"assets/sprites/run/mineral_{grade}.png"))
        outs.append(out)
    return outs


if __name__ == "__main__":
    for g, o in enumerate(build()):
        print(f"mineral_{g}: {o.width}x{o.height}, {px.count_colors(o)}색")
