"""tools/make_sfx.py 테스트: 합성 소리와 꼬리 자르기, 리듬 층 박자, 포격 후보의 높은 소리."""

import unittest

import numpy as np

import make_sfx as ms


def high_ratio(a: np.ndarray) -> float:
    s = np.abs(np.fft.rfft(a)) ** 2
    f = np.fft.rfftfreq(len(a), 1 / ms.SR)
    return float(s[f > 3000].sum() / s.sum())


class MakeSfxTest(unittest.TestCase):
    def test_꼬리를_자르면_길이가_맞고_끝이_0(self):
        a = np.ones(ms.SR, np.float32)
        t = ms.trim(a, 0.3, 0.1)
        self.assertEqual(len(t), int(ms.SR * 0.3))
        self.assertAlmostEqual(float(t[-1]), 0.0)

    def test_최고_음량을_맞춤(self):
        p = ms.peak(np.array([0.1, -0.2], np.float32), -6.0)
        self.assertAlmostEqual(float(np.max(np.abs(p))), 10 ** (-6 / 20), places=4)

    def test_아르페지오는_음이_뒤로_쌓임(self):
        a = ms.arp([1000.0, 2000.0], 0.1, lambda f, d: ms.bell(f, d), 0.2)
        self.assertEqual(len(a), int(ms.SR * 0.3))
        self.assertGreater(np.max(np.abs(a[int(ms.SR * 0.1):])), 0.1)

    def test_리듬_층은_길이가_같고_박마다_소리(self):
        samples = ms.SR * 4
        layer = ms.pulse_layer(samples, 1.0, 0.25)
        self.assertEqual(len(layer), samples)
        for beat in range(4):
            s = int(ms.SR * (0.25 + beat))
            self.assertGreater(np.max(np.abs(layer[s:s + 4000])), 0.2, f"{beat}번 박")
            self.assertLess(np.max(np.abs(layer[s + int(ms.SR * 0.5):s + int(ms.SR * 0.7)])), 0.01, "박 사이는 조용함")

    def test_박_찾기(self):
        layer = ms.pulse_layer(ms.SR * 8, 0.5, 0.125)
        period, offset = ms.beat_grid(layer, 8.0, 0.5)
        self.assertAlmostEqual(period, 0.5)
        self.assertAlmostEqual(offset, 0.125, delta=0.03)

    def test_포격_후보는_높은_소리가_거의_없음(self):
        for fn in (ms.barrage_a, ms.barrage_b, ms.barrage_c):
            for part in fn():
                self.assertLess(high_ratio(part), 0.01, fn.__name__)


if __name__ == "__main__":
    unittest.main()
