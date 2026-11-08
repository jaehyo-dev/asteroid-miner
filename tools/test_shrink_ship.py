"""tools/shrink_ship.py 테스트: 줄인 우주선의 크기·대칭·외곽선·색."""

import unittest

from PIL import Image

import shrink_ship as ss

BODY = (199, 220, 208, 255)


def _ship() -> Image.Image:
    """48 칸 가운데의 좌우 대칭 삼각형 우주선 (몸 색 + 검은 외곽선, 폭 24 높이 24)"""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    for y in range(12, 36):
        half = (y - 12) // 2 + 1
        for x in range(24 - half, 24 + half):
            img.putpixel((x, y), BODY)
    ss._outline(img)
    return img


class ShrinkShipTest(unittest.TestCase):
    def test_배율만큼_작아지고_칸_크기는_그대로(self):
        src = _ship()
        for scale in (0.6, 0.5):
            out = ss.shrink_frame(src, scale)
            self.assertEqual(out.size, (48, 48))
            sw = src.getbbox()[2] - src.getbbox()[0]
            ow = out.getbbox()[2] - out.getbbox()[0]
            self.assertLessEqual(abs(ow - sw * scale), 2, f"{scale}: 폭 {sw} → {ow}")

    def test_대칭_모양은_대칭으로_남음(self):
        out = ss.shrink_frame(_ship(), 0.6)
        self.assertTrue(ss.is_symmetric(out))

    def test_몸_둘레에_검은_외곽선이_있고_색은_원본_색만(self):
        out = ss.shrink_frame(_ship(), 0.5)
        colors = {p for p in out.getdata() if p[3]}
        self.assertLessEqual(colors, {BODY, ss.BLACK})
        px = out.load()
        for y in range(48):
            for x in range(48):
                if px[x, y] == BODY:  # 몸 칸의 상하좌우는 빈칸이 아님 (외곽선이 막음)
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        self.assertTrue(px[x + dx, y + dy][3], (x, y))

    def test_외톨이_점은_지움(self):
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        img.putpixel((5, 5), BODY)
        ss._remove_specks(img)
        self.assertIsNone(img.getbbox())


if __name__ == "__main__":
    unittest.main()
