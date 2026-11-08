"""tools/make_sfx.py 테스트: 합성 소리와 꼬리 자르기, 리듬 층 박자, 포격 후보의 높은 소리."""

import importlib.util
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
    def test_빠른_층은_반_박마다_소리(self):
        layer = ms.fast_pulse_layer(ms.SR * 4, 1.0, 0.25)
        self.assertEqual(len(layer), ms.SR * 4)
        for half in range(7):
            s = int(ms.SR * (0.25 + half * 0.5))
            self.assertGreater(np.max(np.abs(layer[s:s + 2000])), 0.1, f"{half}번째")
            self.assertLess(np.max(np.abs(layer[s + int(ms.SR * 0.3):s + int(ms.SR * 0.45)])), 0.01, "사이는 조용함")

    @unittest.skipUnless(importlib.util.find_spec("scipy"), "scipy가 없는 환경(CI)은 건너뜀")
    def test_섞기는_게임_시간에_맞춰_층이_들어오고_필터가_높은_소리를_깎음(self):
        n = ms.SR * 200
        zero_song = np.zeros((n, 2), np.float32)
        tone = np.ones(n, np.float32)
        # 낮은 값(직류)은 필터를 통과하므로 층 음량을 바로 잴 수 있다
        before = ms.rms(ms.run_mix(zero_song, tone, np.zeros(n, np.float32), 10.0, 1.0))
        after = ms.rms(ms.run_mix(zero_song, tone, np.zeros(n, np.float32), 45.0, 1.0))
        self.assertLess(before, 0.002, "30초 전에는 안 들림")
        self.assertGreater(after, 0.15, "40초 뒤에는 들림")
        self.assertLess(ms.rms(ms.run_mix(zero_song, np.zeros(n, np.float32), tone, 100.0, 1.0)), 0.002, "2분 전 두 번째 층")
        self.assertGreater(ms.rms(ms.run_mix(zero_song, np.zeros(n, np.float32), tone, 135.0, 1.0)), 0.1, "2분 뒤 두 번째 층")
        # 시작할 때 기지 상태(450Hz)에서 약 4kHz로 곧 열림: 10kHz 사인이 처음보다 2초 뒤에 커짐
        t = np.arange(n) / ms.SR
        high = np.stack([np.sin(2 * np.pi * 10000 * t)] * 2, axis=1).astype(np.float32)
        out = ms.run_mix(high, np.zeros(n, np.float32), np.zeros(n, np.float32), 0.0, 4.0)
        self.assertLess(ms.rms(out[:ms.SR // 10]), ms.rms(out[3 * ms.SR:]))

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
    def test_포격_후보는_높은_소리가_거의_없음(self):
        for fn in (ms.barrage_a, ms.barrage_b, ms.barrage_c):
            for part in fn():
                self.assertLess(high_ratio(part), 0.01, fn.__name__)


if __name__ == "__main__":
    unittest.main()
