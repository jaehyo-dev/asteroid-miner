"""tools/bake_base.py 테스트: 정리 결과의 투명도와 밝기 순서, 어두운 회색."""
import unittest

import numpy as np

import bake_base as bb


class BakeBaseTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts = bb.build()

    def test_투명도는_0_아니면_255(self):
        for name, img in self.parts.items():
            alpha = np.array(img.convert("RGBA"))[..., 3]
            self.assertTrue(set(np.unique(alpha)) <= {0, 255}, name)

    def test_밝기_순서_건물_갑판_통로(self):
        builds = [bb.mean_light(self.parts["b_" + n]) for n in ("research", "hangar", "storage", "museum", "drone")]
        self.assertGreater(min(builds), bb.mean_light(self.parts["deck"]))
        self.assertGreater(bb.mean_light(self.parts["deck"]), bb.mean_light(self.parts["walk_h"]))

    def test_땅과_갑판은_기지_팔레트만(self):
        for name in ("deck", "walk_h", "walk_v", "ground", "ground_small", "edge_h", "edge_v"):
            a = np.array(self.parts[name])
            colors = {tuple(p) for p in a[a[..., 3] > 0][:, :3].tolist()}
            self.assertTrue(colors <= set(bb.DARK), name)


if __name__ == "__main__":
    unittest.main()
