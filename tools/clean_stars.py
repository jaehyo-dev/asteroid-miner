"""배경 별 정리: Foozle 별 시트에서 1~2픽셀 별만 남기고 무채색으로 바꾼다.

팩 별 레이어의 색 있는 작은 그림(소용돌이, 십자, 색 점)은 광물·탄으로 착각되므로 지운다 (ART_BIBLE: 배경이 가장 덜 보임).
- 2x2 칸 안에 들어가는 덩어리(8방향으로 이어진 픽셀)는 그대로 남김.
- 3x3 칸 안에 들어가는 덩어리(십자, 짧은 선)는 가운데 1픽셀 별로 줄임. 더 큰 소용돌이 등은 지움.
- 남긴 별은 밝기(휘도)만 남긴 회색으로.
- 시트는 640x360 프레임이 가로로 이어져 있고 프레임 가장자리는 반대편과 이어지므로, 프레임마다 감싸서(wrap) 판단한다.
사용: python3 tools/clean_stars.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = "assets/vendor/foozle/environment/Backgrounds/PNGs/Split up/"
## 원본 → 결과 (assets/sprites/run/)
FILES = {
    "Starry background  - Layer 03 - Stars 2.png": "bg_stars_far.png",
    "Starry background  - Layer 03 - Stars.png": "bg_stars_near.png",
}
FRAME_W = 640


def small_mask(mask: np.ndarray) -> np.ndarray:
    """남길 별 픽셀: 2x2 칸에 들어가는 덩어리는 그대로, 3x3 칸에 들어가는 덩어리는 가운데 픽셀만 (가장자리는 감싸서 봄)."""
    h, w = mask.shape
    m = np.pad(mask.astype(np.int32), 3, mode="wrap")
    # 적분 영상으로 사각형 안 픽셀 수를 빠르게 센다
    s = np.pad(m.cumsum(0).cumsum(1), ((1, 0), (1, 0)))

    def box(y0: int, x0: int, size: int) -> np.ndarray:
        # 원본 좌표 (y, x)마다, (y+y0, x+x0)에서 시작하는 size x size 칸의 합
        ys, xs = np.arange(h)[:, None] + 3 + y0, np.arange(w)[None, :] + 3 + x0
        return s[ys + size, xs + size] - s[ys, xs + size] - s[ys + size, xs] + s[ys, xs]

    keep = np.zeros_like(mask, dtype=bool)
    for dy in (0, -1):
        for dx in (0, -1):
            # 이 픽셀을 품는 2x2 칸의 바깥 테두리(4x4에서 2x2를 뺀 곳)가 비어 있으면 작은 별
            keep |= (box(dy - 1, dx - 1, 4) - box(dy, dx, 2)) == 0
    # 이 픽셀이 가운데인 3x3 칸의 바깥 테두리(5x5에서 3x3을 뺀 곳)가 비어 있으면 십자·짧은 선의 가운데
    keep |= (box(-2, -2, 5) - box(-1, -1, 3)) == 0
    return mask & keep


def clean(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    out = np.zeros_like(a)
    for x0 in range(0, a.shape[1], FRAME_W):
        f = a[:, x0:x0 + FRAME_W]
        keep = small_mask(f[..., 3] > 0)
        lum = f[..., 0] * 0.299 + f[..., 1] * 0.587 + f[..., 2] * 0.114
        o = out[:, x0:x0 + FRAME_W]
        o[..., 0] = o[..., 1] = o[..., 2] = np.where(keep, lum, 0)
        o[..., 3] = np.where(keep, 255, 0)
    return Image.fromarray(np.rint(out).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    for src, dst in FILES.items():
        before = Image.open(os.path.join(ROOT, SRC, src))
        after = clean(before)
        after.save(os.path.join(ROOT, "assets/sprites/run", dst))
        n0 = int((np.asarray(before.convert("RGBA"))[..., 3] > 0).sum())
        n1 = int((np.asarray(after)[..., 3] > 0).sum())
        print(f"{dst}: 픽셀 {n0} → {n1}")
