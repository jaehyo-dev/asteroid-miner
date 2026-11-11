"""기본 무기 아이콘 (v0.8.0): 격납고 무기 그림 36x17(weapon_<id>.png)과 연구소 칸 아이콘 24x24(icon_w_<id>.png).
펄스 연사포는 기존 그림(export_window_art.py가 만든 weapon_pulse.png) 그대로, 나머지 4개는 같은 팔레트로 직접 그린 것.
(v0.8.0 1단계 격납고 시안 make_hangar_mockups.py의 그림을 게임용으로 옮김. 나중에 Codex 그림으로 바꿀 수 있다)
실행: 저장소 맨 위에서 python3 tools/export_weapon_art.py → assets/sprites/window/icon_w_*.png (weapon_*.png는 덮어쓰지 않음)"""
from PIL import Image, ImageDraw

OUT = "assets/sprites/window/"
INK, PLATE, TEAL, TEAL2, GOLD = "#fef8e5", "#2b1925", "#30e1b9", "#99e9e6", "#f6ce50"
# 연구소 칸 id (Balance.RESEARCH_NODES) ← 무기 id
RESEARCH = {"shotgun": "w_shotgun", "rail": "w_rail", "plasma": "w_plasma", "beam": "w_beam"}


def draw_icon(wid):
    """무기 아이콘 36x17: 왼쪽 몸통은 펄스 연사포와 같은 덩어리, 오른쪽 총구가 무기마다 다르다"""
    im = Image.new("RGBA", (36, 17), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o, body, hi, mid, core, glow = PLATE, "#917487", INK, "#5c5164", TEAL, TEAL2

    def block(x0, y0, x1, y1, fill):
        d.rectangle((x0, y0, x1, y1), fill=o)
        d.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill=fill)

    block(0, 4, 13, 14, body)
    d.line((2, 5, 12, 5), fill=hi)
    d.rectangle((3, 8, 8, 11), fill=mid)
    if wid == "shotgun":  # 짧고 굵은 총구 + 부채꼴로 흩어지는 알갱이
        block(12, 3, 22, 15, "#a5b29d")
        d.line((13, 4, 21, 4), fill=hi)
        for y in (6, 9, 12):
            d.line((14, y, 21, y), fill=mid)
        for (x, y) in ((25, 3), (28, 1), (26, 8), (30, 8), (25, 13), (28, 15)):
            d.rectangle((x, y, x + 1, y + 1), fill=glow)
        d.point((24, 8), fill=core)
    elif wid == "rail":  # 길고 가는 쌍레일, 가운데 청록 줄
        d.rectangle((12, 5, 35, 6), fill=o)
        d.rectangle((12, 11, 35, 12), fill=o)
        d.line((12, 5, 34, 5), fill=hi)
        d.line((12, 12, 34, 12), fill="#a5b29d")
        d.line((13, 8, 33, 8), fill=core)
        d.line((13, 9, 30, 9), fill=glow)
        for x in (17, 23, 29):
            d.rectangle((x, 6, x + 1, 11), fill=mid)
    elif wid == "plasma":  # 넓은 포신 끝 동그란 빛 덩어리 (보라)
        block(12, 5, 22, 13, "#a5b29d")
        d.line((13, 6, 21, 6), fill=hi)
        d.ellipse((22, 1, 35, 16), fill="#3a1c57")
        d.ellipse((24, 3, 33, 14), fill="#6b3e75")
        d.ellipse((26, 5, 31, 12), fill="#a884f3")
        d.rectangle((28, 7, 29, 9), fill=INK)
    elif wid == "beam":  # 작은 방사기 + 끊기지 않는 금빛 빔
        block(12, 6, 18, 12, "#a5b29d")
        d.line((13, 7, 17, 7), fill=hi)
        d.line((19, 8, 35, 8), fill=GOLD)
        d.line((19, 9, 35, 9), fill="#f89419")
        d.line((19, 7, 26, 7), fill="#984633")
        d.line((19, 10, 26, 10), fill="#984633")
    return im


def research_icon(im):
    """연구소 칸 24x24: 무기마다 다른 오른쪽(총구) 24칸을 가운데에 놓는다"""
    out = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    out.alpha_composite(im.crop((12, 0, 36, 17)), (0, 4))
    return out


def main():
    for wid, rid in RESEARCH.items():
        im = draw_icon(wid)
        assert set(im.getchannel("A").getdata()) <= {0, 255}, wid  # 투명도는 0/255만
        # weapon_<id>.png는 2026-11-12부터 사용자가 고른 AI 그림이라 덮어쓰지 않는다 (review/v080_step3/art/cand/)
        research_icon(im).save(f"{OUT}icon_{rid}.png")


if __name__ == "__main__":
    main()
