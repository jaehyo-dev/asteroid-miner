"""화면 규칙 검사: 선택 표시로 테두리 선을 쓰지 않는다 (2026-11-12 사용자 결정, ART_BIBLE).

UI 스크립트에서 직접 그리는 테두리 선(draw_rect(..., false, ...))과 StyleBox 테두리(set_border_width...)는
아래 허용 목록(선택 표시가 아닌 판·말풍선 틀)만 쓸 수 있다. 버튼·탭·카드의 고른 상태는 바탕을 밝히거나 글자를 밝혀서 보인다.
테마(assets/ui_theme.tres)의 Button focus 스타일은 비어 있어야 한다.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
UI_FILES = sorted((ROOT / "scripts" / "ui").rglob("*.gd")) + [ROOT / "scripts" / "main.gd", ROOT / "scripts" / "run.gd"]
OUTLINE = re.compile(r"draw_rect\([^\n]*,\s*false\b|set_border_width")

# (파일 이름, 줄에 들어 있는 글자): 선택 표시가 아닌 틀
ALLOWED = [
    ("main.gd", "toast_bg.set_border_width_all"),  # 알림 말풍선 틀
    ("menu_panel.gd", "style.set_border_width_all"),  # 메뉴 창 틀 (버튼 아님)
    ("level_card.gd", "_ring.set_border_width_all"),  # 카드 등급 빛 띠 (늘 보이는 등급 표시, 고를 때 생기지 않음)
    ("hud.gd", "draw_rect(box, Color(color, a), false"),  # 위험 보너스 말풍선 틀
    ("research_view.gd", "draw_rect(Rect2(0, 0, cw, ch), WindowArt.BRANCH[v.branch][0], false"),  # 연구 판 틀
]


def outline_lines():
    """허용 목록 밖의 테두리 선 줄: [(파일, 줄 번호, 줄)]"""
    found = []
    for path in UI_FILES:
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("#") or not OUTLINE.search(line):
                continue
            if any(path.name == name and text in line for name, text in ALLOWED):
                continue
            found.append((path.relative_to(ROOT).as_posix(), no, line.strip()))
    return found


class UiRulesTest(unittest.TestCase):
    def test_선택_테두리_선이_없음(self):
        self.assertEqual(outline_lines(), [])

    def test_허용_목록은_실제로_있는_줄만(self):
        for name, text in ALLOWED:
            hits = [p for p in UI_FILES if p.name == name and text in p.read_text(encoding="utf-8")]
            self.assertTrue(hits, f"{name}: 허용 목록 줄이 없어졌으면 목록에서도 지운다 ({text})")

    def test_검사기가_테두리를_잡아냄(self):
        self.assertTrue(OUTLINE.search("\t\tdraw_rect(Rect2(1, 1, w - 2, h - 2), WindowArt.GOLD, false, 1.0)"))
        self.assertTrue(OUTLINE.search("\ts.set_border_width_all(2)"))
        self.assertIsNone(OUTLINE.search("\tdraw_rect(Rect2(2, 2, 4, 4), TAB_FILL)"))

    def test_테마_focus_스타일은_비어_있음(self):
        theme = (ROOT / "assets" / "ui_theme.tres").read_text(encoding="utf-8")
        focus = re.search(r'Button/styles/focus = SubResource\("([^"]+)"\)', theme)
        self.assertIsNotNone(focus, "Button focus 스타일을 테마에서 비운다")
        self.assertIn(f'[sub_resource type="StyleBoxEmpty" id="{focus.group(1)}"]', theme)


if __name__ == "__main__":
    unittest.main()
