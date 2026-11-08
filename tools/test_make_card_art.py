"""레벨업 카드 그림 검사: tools/make_card_art.py의 결과물이 규칙을 지키는지 본다."""
import re
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/run/card"
PAL = {tuple(int(c) for c in line.split()[:3]) for line in open(ROOT / "assets/palette/void32.gpl") if re.match(r"\s*\d", line)}
IDS = {"fire_rate", "multishot", "damage", "range", "max_hp", "repair", "speed", "magnet",
       "pierce", "ricochet", "explosive", "crit", "shield", "drone", "mining_laser",
       "orbit_pierce", "chain_matrix", "overload", "tractor_beacon"}


class TestCardArt(unittest.TestCase):
    def test_아이콘은_19개_48px_void32_10색_이하(self):
        names = {p.stem for p in (OUT / "icons").glob("*.png")}
        self.assertEqual(names, IDS)
        for name in IDS:
            im = Image.open(OUT / f"icons/{name}.png").convert("RGBA")
            self.assertEqual(im.size, (48, 48), name)
            colors = {c[:3] for _, c in im.getcolors(4096) if c[3] > 0}
            self.assertLessEqual(len(colors), 10, name)
            self.assertLessEqual(colors, PAL, name)
            self.assertEqual({c[3] for _, c in im.getcolors(4096)} - {0, 255}, set(), name + " 투명도는 0/255만")

    def test_프레임과_버튼은_가운데_한_줄만_남김(self):
        self.assertEqual(Image.open(OUT / "frame.png").size, (141, 169))
        self.assertEqual(Image.open(OUT / "button.png").size, (61, 25))


if __name__ == "__main__":
    unittest.main()
