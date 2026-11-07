"""tools/key_asteroid.py 테스트: 우주(남색·별·떠다니는 작은 돌)는 지우고 큰 바위 덩어리만 남기는지. numpy·scipy가 없으면 건너뜀."""

import unittest

try:
    import numpy as np
    import key_asteroid as ka
except ImportError:
    np = None


@unittest.skipIf(np is None, "numpy/scipy 없음 (개발 PC 전용 도구)")
class AsteroidMaskTest(unittest.TestCase):
    def test_큰_바위만_남고_우주와_작은_돌은_빠짐(self):
        img = np.zeros((60, 60, 3), dtype=np.uint8)
        img[:] = (10, 15, 40)  # 남색 우주
        img[10:50, 10:50] = (150, 100, 100)  # 큰 소행성
        img[2:4, 2:4] = (150, 100, 100)  # 떠다니는 작은 돌
        img[55, 55] = (255, 255, 255)  # 별
        m = ka.asteroid_mask(img)
        self.assertTrue(m[30, 30])
        self.assertFalse(m[2, 2])
        self.assertFalse(m[55, 55])
        self.assertFalse(m[0, 0])


if __name__ == "__main__":
    unittest.main()
