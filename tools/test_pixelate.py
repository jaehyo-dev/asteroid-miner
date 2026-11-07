"""tools/pixelate.py 테스트: 배경 지우기, 색 수, 격자 크기, 투명도, 부품 나누기."""

import unittest

from PIL import Image

import pixelate as px


def _sprite() -> Image.Image:
    """마젠타 배경 위에 4x4 크기 블록으로 그린 두 색 사각형 (가장자리에 분홍빛 섞임)."""
    img = Image.new("RGB", (64, 48), px.MAGENTA)
    for y in range(8, 40):
        for x in range(8, 56):
            img.putpixel((x, y), (40, 120, 200) if (x // 4 + y // 4) % 2 else (230, 230, 240))
    for y in range(8, 40):
        img.putpixel((7, y), (200, 90, 210))  # 가장자리 분홍 섞임
    return img


class PixelateTest(unittest.TestCase):
    def test_배경과_분홍_가장자리를_지움(self):
        img = px.remove_key(_sprite())
        self.assertEqual(img.getpixel((0, 0))[3], 0)
        self.assertEqual(img.getpixel((7, 20))[3], 0, "분홍 가장자리")
        self.assertEqual(img.getpixel((20, 20))[3], 255)
        self.assertEqual(px.crop_to_content(img).size, (48, 32))

    def test_격자_크기에_맞추고_투명도는_0_아니면_255(self):
        img = px.crop_to_content(px.remove_key(_sprite()))
        out = px.pixelate(img, width=12, colors=8)
        self.assertEqual(out.size, (12, 8))
        self.assertTrue(set(out.getchannel("A").getdata()) <= {0, 255})

    def test_nearest로_줄이면_블록_색이_그대로(self):
        img = px.crop_to_content(px.remove_key(_sprite()))
        out = px.pixelate(img, width=12, colors=8)
        colors = {out.getpixel((x, y))[:3] for x in range(12) for y in range(8)}
        self.assertEqual(len(colors), 2, "섞인 중간색이 생기지 않음")

    def test_색_수를_줄임(self):
        img = Image.new("RGBA", (32, 32))
        for y in range(32):
            for x in range(32):
                img.putpixel((x, y), (x * 8, y * 8, 128, 255))
        self.assertLessEqual(px.count_colors(px.pixelate(img, width=32, colors=6)), 6)

    def test_배경_그림은_위쪽_기준으로_꽉_채움(self):
        img = Image.new("RGBA", (160, 90), (0, 0, 0, 255))
        for x in range(160):
            for y in range(4):
                img.putpixel((x, y), (255, 255, 255, 255))  # 위쪽 4줄 (하늘, 결과 1칸 ≈ 원본 3줄)
        out = px.pixelate(img, width=52, height=24, colors=4)
        self.assertEqual(out.size, (52, 24))
        self.assertEqual(out.getpixel((10, 0))[:3], (255, 255, 255), "위쪽은 남김")

    def test_부품_시트를_왼쪽부터_나눔(self):
        img = Image.new("RGBA", (100, 20), (0, 0, 0, 0))
        for x0, w in [(5, 10), (40, 20), (80, 15)]:
            for x in range(x0, x0 + w):
                for y in range(5, 15):
                    img.putpixel((x, y), (200, 200, 200, 255))
        parts = px.split_columns(img)
        self.assertEqual([p.width for p in parts], [10, 20, 15])

    def test_같은_배율이면_부품끼리_크기_비율이_유지됨(self):
        small = Image.new("RGBA", (20, 20), (9, 9, 9, 255))
        big = Image.new("RGBA", (60, 40), (9, 9, 9, 255))
        self.assertEqual(px.pixelate(small, scale=0.25).size, (5, 5))
        self.assertEqual(px.pixelate(big, scale=0.25).size, (15, 10))


if __name__ == "__main__":
    unittest.main()
