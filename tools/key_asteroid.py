"""소행성 그림에서 우주 배경(남색·별·떠다니는 작은 돌)을 지워 투명하게 만든다 (마젠타 배경이 아닌 우주 배경용).
사용: python3 tools/key_asteroid.py 원본.png 결과_keyed.png
이 결과를 tools/pixelate.py --no-key --width N 으로 정리한다.
"""

from __future__ import annotations

import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def asteroid_mask(rgb: np.ndarray) -> np.ndarray:
    """붉은 갈색 바위 중 가장 큰 덩어리만 남긴 마스크."""
    r, b = rgb[..., 0].astype(int), rgb[..., 2].astype(int)
    m = ndimage.binary_closing((r > 60) & (r > b + 12), iterations=3)
    lab, n = ndimage.label(m)
    biggest = 1 + int(np.argmax(ndimage.sum(m, lab, range(1, n + 1))))
    return ndimage.binary_fill_holes(lab == biggest)


def main(argv: list[str]) -> int:
    rgb = np.array(Image.open(argv[0]).convert("RGB"))
    mask = asteroid_mask(rgb)
    ys, xs = np.where(mask)
    out = Image.fromarray(np.dstack([rgb, (mask * 255).astype(np.uint8)]))
    out.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).save(argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
