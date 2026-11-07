"""tools/rotsprite.py 테스트: 90도는 정확히, 45도는 새 색 없이 모양 유지, 8방향 시트 배치."""

import unittest

from PIL import Image

import rotsprite as rs


def _arrow() -> Image.Image:
    """위쪽을 가리키는 16x16 화살표 (두 색)."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(3, 13):
        img.putpixel((8, y), (255, 255, 255, 255))
        img.putpixel((7, y), (90, 90, 200, 255))
    for i in range(3):
        img.putpixel((8 - i - 1, 4 + i), (90, 90, 200, 255))
        img.putpixel((8 + i + 1, 4 + i), (90, 90, 200, 255))
    return img


def _opaque(img: Image.Image) -> int:
    return sum(1 for p in img.getdata() if p[3])


class RotSpriteTest(unittest.TestCase):
    def test_scale2x는_가로세로_2배이고_새_색이_없음(self):
        packed = rs._pack(_arrow())
        big = rs.scale2x(packed)
        self.assertEqual(big.shape, (32, 32))
        self.assertTrue(set(big.flatten()) <= set(packed.flatten()))

    def test_0도는_그대로_90도는_정확히_돎(self):
        img = _arrow()
        self.assertEqual(rs.rotate_dir(img, 0).tobytes(), img.tobytes())
        self.assertEqual(rs.rotate_dir(img, 2).tobytes(), img.transpose(Image.Transpose.ROTATE_270).tobytes())
        self.assertEqual(rs.rotate_dir(img, 8).tobytes(), img.tobytes(), "8 = 한 바퀴")

    def test_45도는_새_색이_없고_픽셀_수가_비슷함(self):
        img = _arrow()
        rot = rs.rotsprite(img, 45.0)
        colors = {p for p in img.getdata() if p[3]}
        self.assertTrue({p for p in rot.getdata() if p[3]} <= colors, "원래 그림의 색만 씀")
        self.assertAlmostEqual(_opaque(rot), _opaque(img), delta=_opaque(img) * 0.3)

    def test_45도_방향_4개는_같은_그림을_90도씩_돌린_것(self):
        img = _arrow()
        d1 = rs.rotate_dir(img, 1)
        self.assertEqual(rs.rotate_dir(img, 3).tobytes(), d1.transpose(Image.Transpose.ROTATE_270).tobytes())

    def test_시계_방향으로_돎(self):
        # 위를 가리키는 화살표를 90도(방향 2) 돌리면 끝이 오른쪽으로 간다
        rot = rs.rotate_dir(_arrow(), 2)
        tip_x = [x for y in range(16) for x in range(16) if rot.getpixel((x, y)) == (90, 90, 200, 255) and abs(y - 8) >= 2]
        self.assertTrue(tip_x and min(tip_x) > 8, "화살촉 날개가 오른쪽에 있음")

    def test_8방향_시트는_열이_프레임_행이_방향(self):
        sheet = Image.new("RGBA", (32, 16))
        sheet.paste(_arrow(), (0, 0))
        sheet.paste(_arrow(), (16, 0))
        out = rs.dir8_sheet(sheet, 16, 16)
        self.assertEqual(out.size, (32, 128))
        self.assertEqual(out.crop((16, 0, 32, 16)).tobytes(), _arrow().tobytes())

    def test_turn180이면_아래를_보던_그림이_위를_봄(self):
        down = _arrow().transpose(Image.Transpose.ROTATE_180)
        out = rs.dir8_sheet(down, 16, 16, turn180=True)
        self.assertEqual(out.crop((0, 0, 16, 16)).tobytes(), _arrow().tobytes())

    def test_정사각형이_아니면_거부(self):
        with self.assertRaises(ValueError):
            rs.dir8_sheet(Image.new("RGBA", (24, 16)), 24, 16)


if __name__ == "__main__":
    unittest.main()
