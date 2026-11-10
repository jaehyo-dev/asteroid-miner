"""tools/build_run_sprites.py 테스트: 운석 금·깨짐 프레임 생성, 색 바꾸기."""

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

if __name__ == "__main__":
    unittest.main()


class OrbFramesTest(unittest.TestCase):
    def test_구체_몸통이_칸_가운데에_오고_튀는_불꽃은_무시(self):
        strip = Image.new("RGBA", (40, 10), (0, 0, 0, 0))
        for i, (ox, oy) in enumerate([(1, 1), (4, 3)]):  # 프레임마다 구체 위치가 다름
            for y in range(oy, oy + 5):
                for x in range(i * 20 + ox, i * 20 + ox + 5):
                    strip.putpixel((x, y), (255, 37, 103, 255))
            strip.putpixel((i * 20 + 18, 0), (254, 248, 229, 255))  # 혼자 튄 불꽃 1픽셀
        frames = brs.orb_frames(strip, 2, 16)
        for f in frames:
            self.assertEqual(f.size, (16, 16))
            body = f.crop((0, 0, 16, 16))
            xs = [x for x in range(16) if body.getpixel((x, 8))[3]]
            self.assertEqual((xs[0] + xs[-1] + 1) // 2, 8)


    def test_드론_탄은_3x5(self):
        sheet = brs.drone_bullet_sheet()
        self.assertEqual(sheet.size, (16 * len(brs.DRONE_BULLET_FRAMES), 16 * 8))
        for f in range(len(brs.DRONE_BULLET_FRAMES)):
            x0, y0, x1, y1 = sheet.crop((f * 16, 0, f * 16 + 16, 16)).getbbox()
            self.assertEqual((x1 - x0, y1 - y0), (3, 5))

    def test_내_탄은_6x10이고_좌우_대칭으로_칸_가운데(self):
        sheet = brs.bullet_sheet()
        self.assertEqual(sheet.size, (32 * len(brs.BULLET_FRAMES), 32 * 8))
        for f in range(len(brs.BULLET_FRAMES)):
            up = sheet.crop((f * 32, 0, f * 32 + 32, 32))  # 0행 = 위쪽
            x0, y0, x1, y1 = up.getbbox()
            self.assertEqual((x1 - x0, y1 - y0), (6, 10))
            self.assertEqual((x0 + x1) / 2, 16)
            self.assertEqual(up.getchannel("A").tobytes(), up.transpose(Image.FLIP_LEFT_RIGHT).getchannel("A").tobytes())
