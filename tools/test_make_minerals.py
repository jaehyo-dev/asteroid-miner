"""tools/make_minerals.py 테스트: 외곽선 1픽셀, 그리고 저장된 광물 4등급이 실제로 외곽선을 두르고 있는지."""

import os
import unittest

import numpy as np
from PIL import Image

import make_minerals as mm


def _edge_colors(img: Image.Image) -> set:
    """투명한 칸과 상하좌우로 닿는 불투명 픽셀들의 색 (그림 밖도 투명으로 봄)."""
    a = np.pad(np.asarray(img.convert("RGBA")), ((1, 1), (1, 1), (0, 0)))
    solid = a[..., 3] > 0
    empty_near = np.zeros_like(solid)
    empty_near[1:] |= ~solid[:-1]
    empty_near[:-1] |= ~solid[1:]
    empty_near[:, 1:] |= ~solid[:, :-1]
    empty_near[:, :-1] |= ~solid[:, 1:]
    return {tuple(c) for c in a[solid & empty_near]}


class MineralOutlineTest(unittest.TestCase):
    def test_외곽선은_사방_1픽셀(self):
        img = Image.new("RGBA", (2, 2), (200, 100, 50, 255))
        out = mm.outline(img)
        self.assertEqual(out.size, (4, 4))
        self.assertEqual(out.getpixel((1, 0)), mm.OUTLINE, "위")
        self.assertEqual(out.getpixel((0, 0))[3], 0, "모서리는 비움 (상하좌우만)")
        self.assertEqual(out.getpixel((1, 1)), (200, 100, 50, 255), "안쪽은 그대로")

    def test_저장된_광물_4등급은_외곽선이_검정이고_9에서_12픽셀(self):
        for g in range(4):
            img = Image.open(os.path.join(mm.ROOT, f"assets/sprites/run/mineral_{g}.png"))
            self.assertEqual(_edge_colors(img), {mm.OUTLINE}, f"광물 {g}")
            self.assertTrue(9 <= max(img.size) <= 12, f"광물 {g}: {img.size}")


if __name__ == "__main__":
    unittest.main()
