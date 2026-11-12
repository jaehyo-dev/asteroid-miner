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
       "orbit_pierce", "chain_matrix", "overload", "tractor_beacon",
       "missile", "blackhole", "saw", "mine", "coil", "wave",  # 보조 무기 6종 (v0.8.0)
       "chill", "ram", "trail", "charge", "vein"}  # 짝 스킬 5종 (v0.8.0 5단계)
EVOS = {"evo_missile", "evo_blackhole", "evo_saw", "evo_mine", "evo_coil", "evo_wave"}  # 진화 6개: 카드·판 화면 칸 둘 다
IDS |= EVOS
SUBS = {"missile", "blackhole", "saw", "mine", "coil", "wave"} | EVOS


class TestCardArt(unittest.TestCase):
    def test_아이콘은_36개_48px_void32_10색_이하(self):
        names = {p.stem for p in (OUT / "icons").glob("*.png")}
        self.assertEqual(names, IDS)
        for name in IDS:
            im = Image.open(OUT / f"icons/{name}.png").convert("RGBA")
            self.assertEqual(im.size, (48, 48), name)
            colors = {c[:3] for _, c in im.getcolors(4096) if c[3] > 0}
            self.assertLessEqual(len(colors), 10, name)
            self.assertLessEqual(colors, PAL, name)
            self.assertEqual({c[3] for _, c in im.getcolors(4096)} - {0, 255}, set(), name + " 투명도는 0/255만")

    def test_보조_무기_작은_아이콘은_16px_void32(self):
        self.assertEqual({p.stem for p in (OUT / "icons_small").glob("*.png")}, SUBS)
        for name in SUBS:
            im = Image.open(OUT / f"icons_small/{name}.png").convert("RGBA")
            self.assertEqual(im.size, (16, 16), name)
            self.assertLessEqual({c[:3] for _, c in im.getcolors(4096) if c[3] > 0}, PAL, name)
            self.assertEqual({c[3] for _, c in im.getcolors(4096)} - {0, 255}, set(), name)

    def test_프레임과_버튼은_가운데_한_줄만_남김(self):
        self.assertEqual(Image.open(OUT / "frame.png").size, (141, 169))
        self.assertEqual(Image.open(OUT / "button.png").size, (61, 25))


if __name__ == "__main__":
    unittest.main()
