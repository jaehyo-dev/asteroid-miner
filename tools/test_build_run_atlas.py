"""tools/build_run_atlas.py 테스트: 원판·고리 픽셀, 패킹 겹침, 저장된 아틀라스가 시트와 같은지."""

import re
import unittest

from PIL import Image

import build_run_atlas as bra


class BuildRunAtlasTest(unittest.TestCase):
    def test_원판은_대칭이고_가운데가_칠해짐(self):
        d = bra.disc(5)
        self.assertEqual(d.size, (10, 10))
        self.assertEqual(d.getpixel((5, 5))[3], 255)
        self.assertEqual(d.getpixel((0, 0))[3], 0)
        self.assertEqual(d.tobytes(), d.transpose(Image.FLIP_LEFT_RIGHT).tobytes())

    def test_고리는_가운데가_빔(self):
        r = bra.ring(6)
        self.assertEqual(r.size, (14, 14))
        self.assertEqual(r.getpixel((7, 7))[3], 0)
        self.assertEqual(r.getpixel((1, 7))[3], 255)

    def test_패킹은_겹치지_않고_안_들어가면_오류(self):
        items = [(str(i), Image.new("RGBA", (300, 200 + i))) for i in range(30)]
        places = bra.pack(items)
        rects = [(*places[n], img.width, img.height) for n, img in items]
        for i, a in enumerate(rects):
            for b in rects[i + 1:]:
                self.assertFalse(a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3])
        with self.assertRaises(ValueError):
            bra.pack([("큼", Image.new("RGBA", (3000, 10)))])

    def test_저장된_아틀라스와_표가_시트와_같음(self):
        with open(bra.TABLE, encoding="utf-8") as f:
            table = {m[0]: tuple(int(x) for x in m[1:]) for m in re.findall(r'"(\w+)": \[(\d+), (\d+), (\d+), (\d+), (\d+)\]', f.read())}
        atlases = [Image.open(f"{bra.OUT}/atlas_{i}.png").convert("RGBA") for i in (0, 1)]
        for a in atlases:
            self.assertLessEqual(max(a.size), bra.SIZE, "WebGL2 보장 크기")
        for name, sheet in [s for g in bra.groups() for s in g]:
            i, x, y, w, h = table[name]
            self.assertEqual(atlases[i].crop((x, y, x + w, y + h)).tobytes(), sheet.tobytes(), name)
        self.assertTrue(all(table[n][0] == 1 for n in table if n.startswith("rock_")), "운석은 아틀라스 1")


if __name__ == "__main__":
    unittest.main()
