"""tools/build_run_sprites.py 테스트: 운석 금·깨짐 프레임 생성, 색 바꾸기, 흰 실루엣."""

import unittest

from PIL import Image

import build_run_sprites as brs


def _rock(size: int = 20) -> Image.Image:
    """동그란 회색 운석 (외곽선 검정)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= c:
                img.putpixel((x, y), (0, 0, 0, 255) if d > c - 1 else (98, 85, 101, 255))
    return img


def _opaque(img: Image.Image) -> int:
    return sum(1 for p in img.getdata() if p[3])


class BuildRunSpritesTest(unittest.TestCase):
    def test_깨짐_프레임은_8장이고_같은_시드면_같음(self):
        a = brs.explode_frames(_rock(), 48, seed=3)
        b = brs.explode_frames(_rock(), 48, seed=3)
        self.assertEqual(len(a), 8)
        self.assertEqual([f.tobytes() for f in a], [f.tobytes() for f in b])
        self.assertTrue(all(f.size == (48, 48) for f in a))

    def test_처음은_멀쩡하고_금이_늘다가_조각이_흩어져_줄어듦(self):
        frames = brs.explode_frames(_rock(), 48, seed=5)
        lava = {c + (255,) for c in brs.LAVA}
        count_lava = [sum(1 for p in f.getdata() if p in lava) for f in frames]
        self.assertEqual(count_lava[0], 0, "멀쩡함")
        self.assertTrue(0 < count_lava[1] < count_lava[2], "금이 늘어남 %s" % count_lava[:3])
        self.assertLess(_opaque(frames[-1]), _opaque(frames[0]) / 3, "마지막은 거의 사라짐")
        # 흩어지면 처음보다 넓은 곳에 퍼진다
        self.assertGreater(frames[4].getchannel("A").getbbox()[2] - frames[4].getchannel("A").getbbox()[0],
                           frames[0].getchannel("A").getbbox()[2] - frames[0].getchannel("A").getbbox()[0])

    def test_새_색은_원래_색과_용암색뿐(self):
        base = _rock()
        allowed = {p for p in base.getdata() if p[3]} | {c + (255,) for c in brs.LAVA}
        for f in brs.explode_frames(base, 48, seed=1):
            self.assertTrue({p for p in f.getdata() if p[3]} <= allowed)

    def test_색_바꾸기는_정한_색만(self):
        img = Image.new("RGBA", (2, 1), (0, 0, 0, 255))
        img.putpixel((1, 0), (98, 85, 101, 255))
        out = brs.recolor(img, brs.GOLD_MAP)
        self.assertEqual(out.getpixel((0, 0)), (0, 0, 0, 255), "외곽선은 그대로")
        self.assertEqual(out.getpixel((1, 0)), brs.GOLD_MAP[(98, 85, 101)] + (255,))

    def test_흰_실루엣은_같은_모양(self):
        rock = _rock()
        white = brs.whiten(rock)
        self.assertEqual(white.getchannel("A").tobytes(), rock.getchannel("A").tobytes())
        self.assertTrue(all(p[:3] == (255, 255, 255) for p in white.getdata() if p[3]))


if __name__ == "__main__":
    unittest.main()
