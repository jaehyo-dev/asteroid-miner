"""tools/clean_stars.py 테스트: 1~2픽셀 별만 남고, 십자·큰 덩어리는 지워지고, 색은 회색이 된다."""

import unittest

import numpy as np
from PIL import Image

import clean_stars as cs


def _sheet() -> Image.Image:
    img = Image.new("RGBA", (cs.FRAME_W, 40), (0, 0, 0, 0))
    img.putpixel((5, 5), (251, 185, 84, 255))  # 1픽셀 주황 별
    for p in [(20, 5), (21, 5), (20, 6), (21, 6)]:  # 2x2 별
        img.putpixel(p, (255, 255, 255, 255))
    for p in [(40, 10), (39, 10), (41, 10), (40, 9), (40, 11)]:  # 3x3 십자
        img.putpixel(p, (232, 59, 59, 255))
    img.putpixel((60, 20), (145, 219, 105, 255))  # 대각으로 이어진 3픽셀 (3x3 칸)
    img.putpixel((61, 21), (145, 219, 105, 255))
    img.putpixel((62, 22), (145, 219, 105, 255))
    img.putpixel((0, 30), (255, 255, 255, 255))  # 프레임 양끝에 걸친 2픽셀 별 (감싸서 이어짐)
    img.putpixel((cs.FRAME_W - 1, 30), (255, 255, 255, 255))
    img.putpixel((cs.FRAME_W - 2, 30), (255, 255, 255, 255))  # → 감싸면 3칸 선
    for i in range(5):  # 5x5 고리 모양 (소용돌이 대신)
        for p in [(81 + i, 1), (81 + i, 5), (81, 1 + i), (85, 1 + i)]:
            img.putpixel(p, (240, 79, 120, 255))
    return img


class CleanStarsTest(unittest.TestCase):
    def test_작은_별만_남고_회색이_됨(self):
        out = cs.clean(_sheet())
        a = np.asarray(out)
        self.assertEqual(a[5, 5, 3], 255, "1픽셀 별")
        self.assertEqual(int((a[5:7, 20:22, 3] == 255).sum()), 4, "2x2 별")
        self.assertEqual(int((a[9:12, 39:42, 3] == 255).sum()), 1, "십자는 가운데 1픽셀만")
        self.assertEqual(a[10, 40, 3], 255)
        self.assertEqual(int((a[20:23, 60:63, 3] == 255).sum()), 1, "대각 3픽셀도 가운데만")
        self.assertEqual(int((a[30, [0, cs.FRAME_W - 2, cs.FRAME_W - 1], 3] == 255).sum()), 1, "프레임 경계는 감싸서 봄(3칸 선 → 가운데)")
        self.assertEqual(a[30, cs.FRAME_W - 1, 3], 255)
        self.assertEqual(int(a[0:7, 80:87, 3].sum()), 0, "5x5 소용돌이는 지움")
        r, g, b = a[5, 5, :3]
        self.assertTrue(r == g == b, "무채색")

    def test_투명도는_0_아니면_255(self):
        a = np.asarray(cs.clean(_sheet()))
        self.assertTrue(set(np.unique(a[..., 3])) <= {0, 255})


if __name__ == "__main__":
    unittest.main()
