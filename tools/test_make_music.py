"""tools/make_music.py 테스트: 악보(박, 음역, 모티프), 곡 이음매, 섞기, 게임에 넣은 파일."""

import shutil
import subprocess
import unittest

import numpy as np

import make_music as mm
import make_sfx as ms

HAS_FFMPEG = shutil.which("ffmpeg") is not None


class ScoreTest(unittest.TestCase):
    def test_135_BPM의_128박은_샘플이_딱_떨어짐(self):
        self.assertEqual(mm.BEAT, 60 * ms.SR / 135)
        self.assertEqual(mm.LOOP, 128 * mm.BEAT)

    def test_악보는_모두_곡_안의_박에_맞음(self):
        for ev in (mm.bass_events(False), mm.bass_events(True), mm.arp_events(), mm.pad_events(), mm.stab_events(), mm.motif_events()):
            for beat, _length, _note in ev:
                self.assertLess(beat, 128)
                self.assertEqual(beat * 4, int(beat * 4), "16분음표 격자 위")

    def test_화음은_32마디를_채움(self):
        self.assertEqual(len(mm.CHORDS) * 16, 128)

    def test_멜로디는_중간_음역이고_효과음보다_아래(self):
        notes = [n for _, _, n in mm.MOTIF]
        self.assertGreaterEqual(min(notes), 60, "C4 이상")
        self.assertLess(max(notes), 72, "레벨업 마림바 C5 아래")
        self.assertTrue({n % 12 for n in notes} <= {5, 7, 8, 10, 0, 1, 3}, "F 단조 음계")

    def test_모티프는_같은_간격으로_반복(self):
        ev = mm.motif_events()
        self.assertEqual(len(ev), len(mm.MOTIF) * 128 // mm.MOTIF_BEATS)
        self.assertEqual([(b + mm.MOTIF_BEATS, l, n) for b, l, n in mm.MOTIF], ev[len(mm.MOTIF):2 * len(mm.MOTIF)])
        self.assertIn(mm.MOTIF_BEATS / 4, (4, 8), "4~8마디마다")

    def test_악보를_쌓으면_끝을_넘는_소리가_처음으로_이어짐(self):
        out = mm.render([(128 - mm.GRID / mm.BEAT - 0.25, 1.0, 60)], mm.lead_voice)
        self.assertGreater(np.max(np.abs(out[:mm.BEAT // 2])), 0.1)

    def test_저역_처리와_샘플_줄이기(self):
        a = np.sin(2 * np.pi * 100 * np.arange(mm.LOOP) / mm.LOOP).astype(np.float32)
        half = mm.resample_loop(a, mm.LOOP // 2)
        self.assertEqual(len(half), mm.LOOP // 2)
        self.assertAlmostEqual(ms.rms(half), ms.rms(a), places=2)
        high = np.sin(2 * np.pi * (mm.LOOP // 10) * np.arange(mm.LOOP) / mm.LOOP).astype(np.float32)  # 4410Hz
        self.assertLess(ms.rms(mm.resample_loop(high, mm.LOOP, mm.BASE_CUTOFF)), 0.02)


class MixTest(unittest.TestCase):
    def test_층은_게임_시간에_맞춰_들어오고_기지에선_먹먹한_층만(self):
        n = ms.SR * 20
        song = np.zeros((n, 2), np.float32)
        none = np.zeros(n, np.float32)
        tone = np.ones(n, np.float32)
        stems = lambda i: [tone if j == i else none for j in range(3)]
        for i, enter in enumerate([30.0, 60.0, 120.0]):
            _, fade, db = mm.juice("MUSIC_STEMS")[i]
            self.assertLess(ms.rms(mm.run_mix(song, none, stems(i), enter - 3.0, 0.5)), 0.002, f"{i} 전")
            got = ms.rms(mm.run_mix(song, none, stems(i), enter + fade + 2.0, 0.5))
            self.assertAlmostEqual(got, 10 ** (db / 20), delta=0.02, msg=f"{i} 후")
        out = mm.run_mix(np.ones((n, 2), np.float32), tone * 0.5, [none] * 3, 0.0, 6.0)
        self.assertLess(ms.rms(out[:2048]), ms.rms(out[-2048:]), "출격 순간: 먹먹한 층에서 곡으로")


@unittest.skipUnless(HAS_FFMPEG, "ffmpeg가 없는 환경(CI)은 건너뜀")
class SongTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = ms.decode(mm.SRC_SONG, 2)
        cls.song = mm.fix_song(cls.raw)

    def test_원본의_첫_소리는_1마디_첫_박(self):
        first = int(np.argmax(np.abs(self.raw.mean(axis=1)) > 0.01))
        self.assertAlmostEqual(first, mm.SONG_START, delta=50)

    def test_고친_곡은_128박이고_끊기는_곳이_없음(self):
        y = self.song
        self.assertEqual(len(y), mm.LOOP)
        loop = np.concatenate([y[-ms.SR:], y[:ms.SR * 2]]).mean(axis=1)
        w = ms.SR // 20
        quiet = min(ms.rms(loop[i:i + w]) for i in range(0, len(loop) - w, w))
        self.assertGreater(quiet, 10 ** (-40 / 20), "이음매 근처 50ms마다 소리가 있음")

    def test_이음매에서_튀지_않음(self):
        y = self.song.mean(axis=1)
        typical = np.percentile(np.abs(np.diff(y)), 99.9)
        self.assertLessEqual(abs(y[0] - y[-1]), typical, "처음과 끝의 차이가 평소 곡 안의 변화 수준")

    def test_박이_곡과_맞음(self):
        """곡의 펄스가 터지는 곳을 16분음표로 접어 잰다: 4구간 모두 격자에서 3ms 안"""
        y = self.song.mean(axis=1)
        step = mm.BEAT // 4
        ms1 = ms.SR // 1000
        for part in range(4):
            a = mm.SONG_START + part * 30 * mm.BEAT
            n = 30 * 4  # 30박 분량의 16분음표
            seg = y[a:a + n * step].reshape(n, step)[:, :step // ms1 * ms1].reshape(n, -1, ms1)
            env = 20 * np.log10(np.abs(seg).mean(axis=(0, 2)) + 1e-7)
            attack_ms = (int(np.argmax(np.diff(env))) + 1)
            want_ms = (mm.GRID - mm.SONG_START) / ms1
            self.assertLessEqual(abs(attack_ms - want_ms), 3, f"{part}번 구간 {attack_ms}ms / 격자 {want_ms}ms")

    def test_첫_음이_정확히_격자_위(self):
        out = mm.render([(0.0, 1.0, 60)], mm.lead_voice)
        self.assertEqual(int(np.argmax(np.abs(out) > 0)) // 2, mm.GRID // 2)

    def test_짧게_저장하는_층은_정말_8마디마다_같음(self):
        pulse = mm.rhythm()
        self.assertTrue(np.allclose(pulse[:mm.SHORT], pulse[mm.SHORT:2 * mm.SHORT], atol=1e-3))
        for key in "abc":
            top = mm.candidate(key)["top"]
            self.assertTrue(np.allclose(top[:mm.SHORT], top[mm.SHORT:2 * mm.SHORT], atol=1e-3), key)

    def test_곡과_베이스를_합쳐도_찌그러지지_않음(self):
        for key in "abc":
            self.assertLess(np.max(np.abs(mm.with_bass(self.song, mm.candidate(key)["bass"]))), 1.0, key)

    def test_기지_층은_스스로_이어짐(self):
        muffled = mm.song_parts()[1]
        self.assertEqual(len(muffled), mm.BASE_LEN)
        self.assertLessEqual(abs(muffled[0] - muffled[-1]), np.percentile(np.abs(np.diff(muffled)), 99.9))

    def test_층은_효과음보다_작음(self):
        levelup_db = 20 * np.log10(ms.rms(ms.decode(f"{ms.OUT}/levelup.wav"))) - 9.5
        for key in "abc":
            c = mm.candidate(key)
            bass_db = 20 * np.log10(mm.active_rms(c["bass"])) + mm.juice("MUSIC_BASS_DB")
            self.assertLess(bass_db, levelup_db - 6, f"{key} bass")
            for i, name in {1: "harmony", 2: "top"}.items():
                self.assertLessEqual(np.max(np.abs(c[name])), 10 ** (-1 / 20) + 1e-3, f"{key} {name} 찌그러지지 않음")
                game_db = 20 * np.log10(mm.active_rms(c[name])) + mm.juice("MUSIC_STEMS")[i][2]
                self.assertLess(game_db, levelup_db - 6, f"{key} {name}")

    def test_화음_층은_높은_소리가_적음(self):
        for key in "abc":
            m = mm.candidate(key)["harmony"]
            s = np.abs(np.fft.rfft(m)) ** 2
            self.assertLess(s[np.fft.rfftfreq(len(m), 1 / ms.SR) > 2500].sum() / s.sum(), 0.01, key)


@unittest.skipUnless(HAS_FFMPEG, "ffmpeg가 없는 환경(CI)은 건너뜀")
class BuiltFilesTest(unittest.TestCase):
    def _samples(self, name: str, channels: int) -> np.ndarray:
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", f"{mm.MUSIC}/{name}.ogg", "-f", "s16le", "-"], capture_output=True, check=True).stdout
        return np.frombuffer(raw, np.int16).astype(np.float32).reshape(-1, channels) / 32768.0

    def test_파일_길이가_샘플_단위로_맞음(self):
        self.assertEqual(len(self._samples("urgent_loop", 2)), mm.LOOP)
        self.assertEqual(len(self._samples("urgent_base", 1)), mm.BASE_LEN // 4)
        self.assertEqual(len(self._samples("stem_harmony", 1)), mm.LOOP // 2)
        for name in ("pulse_layer", "stem_top"):
            self.assertEqual(len(self._samples(name, 1)), mm.SHORT // 2, name)

    def test_압축한_파일도_이음매에서_튀지_않음(self):
        for name, ch in {"urgent_loop": 2, "urgent_base": 1, "pulse_layer": 1, "stem_harmony": 1, "stem_top": 1}.items():
            y = self._samples(name, ch).mean(axis=1)
            typical = np.percentile(np.abs(np.diff(y)), 99.9)
            self.assertLessEqual(abs(y[0] - y[-1]), max(typical * 1.5, 0.003), name)


if __name__ == "__main__":
    unittest.main()
