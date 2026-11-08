"""tools/make_sfx.py 테스트: 합성 소리와 꼬리 자르기, 리듬 층 박자, 포격 후보의 높은 소리."""

import shutil
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

    def test_층의_소리는_끝을_넘으면_처음으로_이어짐(self):
        out = np.zeros(10, np.float32)
        ms.stamp(out, np.ones(4, np.float32), 8)
        self.assertEqual(out.tolist(), [1, 1, 0, 0, 0, 0, 0, 0, 1, 1])

    def test_박_찾기(self):
        layer = ms.pulse_layer(ms.SR * 8, 0.5, 0.125)
        period, offset = ms.beat_grid(layer, 0.5)
        self.assertAlmostEqual(period, 0.5)
        self.assertAlmostEqual(offset, 0.125, delta=0.03)

    def test_레벨업_음표는_마지막이_가장_높지_않고_첫_음과_한_옥타브_안(self):
        for notes, _ in ms.LEVELUP2.values():
            self.assertLess(notes[-1], max(notes))
            self.assertLessEqual(notes[-1], notes[0] * 2)
            self.assertLess(max(notes), 800.0, "C5 근처")

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
    def test_레벨업_후보는_짧고_높은_소리가_없고_끝이_부드러움(self):
        for key in ms.LEVELUP2:
            a = ms.levelup2(key)
            self.assertLessEqual(len(a) / ms.SR, 0.6, key)
            s = np.abs(np.fft.rfft(a)) ** 2
            self.assertLess(s[np.fft.rfftfreq(len(a), 1 / ms.SR) > 4000].sum() / s.sum(), 0.001, key)
            last = int(ms.SR * ms.LEVELUP2_LAST_DUR)
            self.assertLess(np.max(np.abs(a[-last:])), 0.75 * np.max(np.abs(a[:-last])), f"{key} 마지막 음이 더 작음")
            self.assertLess(np.max(np.abs(a[-int(ms.SR * 0.005):])), 0.02, f"{key} 끝이 0으로")
            self.assertLess(np.max(np.abs(a[-int(ms.SR * 0.05):])), 0.5 * np.max(np.abs(a)), f"{key} 갑자기 끊기지 않음")

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
    def test_적_소리_후보는_짧고_날벌레가_가장_짧음(self):
        for fn in (ms.jelly_a, ms.jelly_b, ms.bug_a, ms.bug_b):
            hit, burst = fn()
            self.assertLessEqual(len(hit) / ms.SR, 0.3, fn.__name__)
            self.assertLessEqual(len(burst) / ms.SR, 0.3, fn.__name__)
        self.assertLess(len(ms.bug_b()[1]), len(ms.jelly_a()[1]))

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
    def test_창_소리_후보는_짧고_낮고_마림바보다_작음(self):
        for fn in (ms.card_a, ms.card_b, ms.card_c):
            a = fn()
            self.assertLessEqual(len(a) / ms.SR, 0.35, fn.__name__)
            s = np.abs(np.fft.rfft(a)) ** 2
            self.assertLess(s[np.fft.rfftfreq(len(a), 1 / ms.SR) > 3000].sum() / s.sum(), 0.02, fn.__name__)
            self.assertLess(abs(float(a[-1])), 0.01, f"{fn.__name__} 끝이 부드러움")
            self.assertLess(np.max(np.abs(a)) * 10 ** (ms.CARD_DB / 20), np.max(np.abs(ms.levelup2("a"))) * 10 ** (ms.LEVELUP_DB / 20), fn.__name__)

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
    def test_빠른_층은_반_박마다_소리(self):
        layer = ms.fast_pulse_layer(ms.SR * 4, 1.0, 0.25)
        self.assertEqual(len(layer), ms.SR * 4)
        for half in range(7):
            s = int(ms.SR * (0.25 + half * 0.5))
            self.assertGreater(np.max(np.abs(layer[s:s + 2000])), 0.1, f"{half}번째")
            self.assertLess(np.max(np.abs(layer[s + int(ms.SR * 0.3):s + int(ms.SR * 0.45)])), 0.01, "사이는 조용함")

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
    def test_포격_후보는_높은_소리가_거의_없음(self):
        for fn in (ms.barrage_a, ms.barrage_b, ms.barrage_c):
            for part in fn():
                self.assertLess(high_ratio(part), 0.01, fn.__name__)


class GateSoundTest(unittest.TestCase):
    def test_게이트_소리는_길이가_맞고_끝이_부드러움(self):
        sounds = ms.gate_sounds()
        self.assertEqual(set(sounds), {"gate_assemble", "gate_lock", "gate_hum", "gate_alarm", "gate_collapse", "warp_charge", "warp_done", "takeoff", "warp_launch", "warp_arrive", "landing"})
        self.assertAlmostEqual(len(sounds["warp_charge"]) / ms.SR, 5.0, delta=0.05)
        self.assertLess(len(sounds["landing"]) / ms.SR, 1.1)
        for name, a in sounds.items():
            self.assertLessEqual(abs(a).max(), 1.0, name)
            if name != "gate_hum":
                self.assertLess(abs(a[-1]), 0.05, name)

    def test_웅웅거림은_반복해도_이어짐(self):
        a = ms.gate_hum()
        self.assertLess(abs(float(a[0]) - float(a[-1])), 0.05)


if __name__ == "__main__":
    unittest.main()
