"""게이트 고리 그림 검사: 8조각, void32, 투명도 0/255, 조각끼리 안 겹침."""
import re
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAL = {tuple(int(c) for c in line.split()[:3]) for line in open(ROOT / "assets/palette/void32.gpl") if re.match(r"\s*\d", line)}


class TestGateArt(unittest.TestCase):
    def setUp(self):
        self.a = np.array(Image.open(ROOT / "assets/sprites/gate/gate_ring.png").convert("RGBA"))

    def test_칸_8개이고_팔레트_색만(self):
        self.assertEqual(self.a.shape[:2], (68, 68 * 8))
        self.assertEqual(set(np.unique(self.a[..., 3]).tolist()) - {0, 255}, set())
        colors = {tuple(c) for c in self.a[self.a[..., 3] > 0][:, :3].tolist()}
        self.assertLessEqual(colors, PAL)

    def test_조각은_자기_방향에_있고_안쪽이_비어_있음(self):
        for i in range(8):
            cell = self.a[:, i * 68:(i + 1) * 68, 3] > 0
            ys, xs = np.nonzero(cell)
            self.assertGreater(len(xs), 100, i)
            angle = np.arctan2(ys.mean() + 0.5 - 34, xs.mean() + 0.5 - 34)
            self.assertLess(abs((angle - i * np.pi / 4 + np.pi) % (2 * np.pi) - np.pi), 0.2, i)
            self.assertGreater(np.hypot(ys - 33.5, xs - 33.5).min(), 18, "소용돌이 자리")


if __name__ == "__main__":
    unittest.main()
