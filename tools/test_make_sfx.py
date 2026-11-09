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

    @staticmethod
    def _share(a, lo, hi):
        spec = np.abs(np.fft.rfft(a.mean(axis=1))) ** 2
        f = np.fft.rfftfreq(len(a), 1 / ms.SR)
        return spec[(f >= lo) & (f < hi)].sum() / spec.sum()

    @staticmethod
    def _centroid(a):
        spec = np.abs(np.fft.rfft(a.mean(axis=1))) ** 2
        return (spec * np.fft.rfftfreq(len(a), 1 / ms.SR)).sum() / spec.sum()

    @staticmethod
    def _tail(a):
        """가장 큰 곳 뒤 -30dB까지 걸리는 시간"""
        e = np.abs(a).max(axis=1)
        return (np.where(e > e.max() * 10 ** (-30 / 20))[0][-1] - e.argmax()) / ms.SR

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg 없음")
    def test_카드_선택은_몸통과_또렷함과_꼬리가_있음(self):
        for key in ms.CARD_STYLES:
            a = ms.pick_d(key)
            self.assertLess(self._share(a, 0, 80), 0.005, "80Hz 아래 없음")
            self.assertLess(self._share(a, 9000, ms.SR / 2), 0.01, "9kHz 위 부드럽게")
            self.assertGreater(self._share(a, 150, 600), 0.15, "중간 저음 몸통")
            self.assertGreater(self._share(a, 2000, 5000), 0.1, "금속 또렷함")
            self.assertGreater(self._centroid(a), 900, "a·b(373~487Hz)처럼 둔탁하지 않게")
            self.assertTrue(0.25 <= self._tail(a) <= 0.55, "잔향 꼬리 약 0.4초")
            self.assertTrue(np.array_equal(a, ms.pick_d(key)), "같은 결과")

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg 없음")
    def test_권총_장전은_두_번_이어지고_또렷함(self):
        for key in ("e1", "e2", "e3"):
            a = ms.pick_e(key)
            self.assertLess(self._share(a, 0, 80), 0.005, f"{key} 80Hz 아래 없음")
            self.assertLess(self._share(a, 9000, ms.SR / 2), 0.01, f"{key} 9kHz 위 부드럽게")
            self.assertGreater(self._share(a, 2000, 5000), 0.1, f"{key} 금속 또렷함")
            self.assertGreater(self._centroid(a), 900, f"{key} 둔탁하지 않게")
            e = np.abs(a).max(axis=1)
            head = e[:int(0.03 * ms.SR)].max()
            self.assertGreater(head, e.max() * 0.3, f"{key} 앞의 척이 들림")
            # 척 뒤 조용해졌다가 0.06~0.1초에 컥이 다시 올라옴
            start, end = int(0.06 * ms.SR), int(0.1 * ms.SR)
            lock = start + int(np.argmax(e[start:end] > e.max() * 0.3))
            self.assertGreater(e[start:end].max(), e.max() * 0.3, f"{key} 컥 위치")
            self.assertLess(e[int(0.045 * ms.SR):lock - 44].max(initial=0.0), e[lock:lock + 441].max(), f"{key} 사이가 더 작음")
            self.assertTrue(np.array_equal(a, ms.pick_e(key)), "같은 결과")

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg 없음")
    def test_실제_녹음_장전은_당기는_순간부터_시작(self):
        src = np.abs(ms.decode(ms.RACK_RECORDING, 2)).max(axis=1)
        start = int(ms.RACK_RECORDING_FROM * ms.SR)
        self.assertLess(src[start - int(0.1 * ms.SR):start].max(), 10 ** (-50 / 20), "자른 자리 앞은 조용함 (탄창 소리가 안 섞임)")
        self.assertGreater(src[start:start + int(0.005 * ms.SR)].max(), 10 ** (-30 / 20), "자르자마자 소리가 시작됨")
        out = np.abs(ms.pick_e("e3")).max(axis=1)
        self.assertLess(np.argmax(out > 0.01) / ms.SR, 0.003, "앞에 빈 부분이 없음")
        self.assertLess(len(out) / ms.SR, 0.55, "카드 선택답게 짧음")

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg 없음")
    def test_카드_등장은_등급이_오를수록_몸통과_잔향이_커짐(self):
        for key in ms.CARD_STYLES:
            s = ms.show_d(key)
            self.assertEqual(set(s), set(ms.CARD_SOUND_DB))
            for name, a in s.items():
                self.assertLess(self._share(a, 0, 80), 0.005, name)
                self.assertLess(self._share(a, 9000, ms.SR / 2), 0.03, name)
            order = ["card_rare", "card_epic", "card_unique", "card_legendary"]
            tails = [self._tail(s[n]) for n in order]
            self.assertEqual(tails, sorted(tails), "잔향이 커짐")
            for n in ("card_unique", "card_legendary"):
                self.assertGreater(self._share(s[n], 150, 600), 0.2, n + " 몸통")
                sd = (s[n][:, 0] - s[n][:, 1]) / 2
                self.assertGreater(float(np.sqrt((sd ** 2).mean() / (s[n].mean(axis=1) ** 2).mean())), 0.5, n + " 좌우로 넓게")
            self.assertAlmostEqual(len(s["card_swell"]) / ms.SR, ms.SWELL_TIME, places=2)
            self.assertAlmostEqual(len(s["card_gather"]) / ms.SR, ms.LEGEND_REVEAL_GAP, places=2)

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
    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg가 없는 환경(CI)은 건너뜀")
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
