"""레벨업 카드 그림 정리: Codex 원본 → assets/sprites/run/card/ (게임에서 쓰는 그림).
- 아이콘 19개: 시트를 칸으로 나눠 48x48, 블록마다 가장 많은 색 → void32, 아이콘당 최대 10색.
  (tools/pixelate.py는 외곽선을 잃고 강조색이 바뀌어 쓰지 않는다. make_minerals.py도 같은 이유로 따로 있음)
- 프레임·버튼: S 부품을 9칸 나누기용으로 줄인다 (가운데 줄을 1픽셀만 남겨, 늘려도 픽셀이 찌그러지지 않게).
- review/v070_step5/icons_all.png: 19개를 받침 안에 넣어 본 시트.
실행: python3 tools/make_card_art.py"""
import os
import re
import shutil
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

RAW = "assets/raw/run/icons"
PARTS = "review/v070_step5/frame/parts_S"
OUT = "assets/sprites/run/card"
SIZE = 48
MAX_COLORS = 10
CORNER_X, CORNER_Y = 70, 84  # 프레임 9칸의 모서리 크기 (scripts/ui/level_card.gd와 같게)
BTN_X, BTN_Y = 30, 12
PLATE = (0x2b, 0x19, 0x25)
TEAL = [(0x30, 0xe1, 0xb9), (0x99, 0xe9, 0xe6)]
PAL = [tuple(int(c) for c in line.split()[:3]) for line in open("assets/palette/void32.gpl") if re.match(r"\s*\d", line)]

# 강화 id → (원본, 왼쪽 비율, 오른쪽 비율). 이 표가 아이콘 19개의 전부다.
ICONS = {
    "fire_rate": ("icons_sample.png", 0.0, 0.33), "multishot": ("icons_a.png", 0.0, 1 / 3), "damage": ("icons_a.png", 1 / 3, 2 / 3),
    "range": ("icons_a.png", 2 / 3, 1.0), "max_hp": ("icons_b.png", 0.0, 1 / 3), "repair": ("icons_b.png", 1 / 3, 2 / 3),
    "speed": ("icons_b.png", 2 / 3, 1.0), "magnet": ("icons_c.png", 0.0, 1 / 3),
    "pierce": ("icons_d.png", 0.0, 1 / 3), "ricochet": ("icons_h.png", 0.0, 1.0), "explosive": ("icons_d.png", 2 / 3, 1.0),
    "crit": ("icons_e.png", 0.0, 0.5), "shield": ("icons_g.png", 0.5, 1.0), "drone": ("icons_sample.png", 0.67, 1.0),
    "mining_laser": ("icons_c.png", 1 / 3, 2 / 3),
    "orbit_pierce": ("icons_e.png", 0.5, 1.0), "chain_matrix": ("icons_f.png", 0.0, 1 / 3), "overload": ("icons_f.png", 1 / 3, 2 / 3),
    "tractor_beacon": ("icons_f.png", 2 / 3, 1.0),
}


def is_bg(p):
    return p[0] > 170 and p[2] > 170 and p[1] < 110


def near(p, colors=PAL):
    return min(colors, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, p)))


def make_icon(src, x0, x1):
    im = Image.open(f"{RAW}/{src}").convert("RGB")
    im = im.crop((int(im.width * x0), 0, int(im.width * x1), im.height))
    px = im.load()
    xs = [x for x in range(im.width) for y in range(0, im.height, 4) if not is_bg(px[x, y])]
    ys = [y for y in range(im.height) for x in range(0, im.width, 4) if not is_bg(px[x, y])]
    bx, by, bw, bh = min(xs), min(ys), max(xs) + 1 - min(xs), max(ys) + 1 - min(ys)
    step = max(bw, bh) / SIZE
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox, oy = (SIZE - round(bw / step)) // 2, (SIZE - round(bh / step)) // 2
    for j in range(round(bh / step)):
        for i in range(round(bw / step)):
            cnt = Counter()
            for y in range(int(by + j * step), min(int(by + (j + 1) * step), im.height)):
                for x in range(int(bx + i * step), min(int(bx + (i + 1) * step), im.width)):
                    p = px[x, y]
                    cnt["bg" if is_bg(p) else near(p)] += 1
            top = cnt.most_common(1)[0][0] if cnt else "bg"
            # 배경이 60%를 넘을 때만 비움 (1블록 안에 걸친 얇은 외곽선을 지키려고)
            if top == "bg" and cnt["bg"] <= sum(cnt.values()) * 0.6:
                top = [k for k, _ in cnt.most_common() if k != "bg"][0]
            if top != "bg":
                out.putpixel((ox + i, oy + j), (*top, 255))
    return limit_colors(out)


def limit_colors(im, limit=MAX_COLORS):
    """적게 쓰인 색을 남는 색 중 가장 가까운 색으로 합친다 (아이콘당 8~10색 규칙)"""
    a = np.array(im)
    opaque = a[..., 3] > 0
    counts = Counter(map(tuple, a[opaque][:, :3].tolist()))
    keep = [c for c, _ in counts.most_common(limit)]
    for c in counts:
        if c not in keep:
            a[opaque & (a[..., :3] == c).all(axis=2), :3] = near(c, keep)
    return Image.fromarray(a, "RGBA")


def shrink_nine(im, cx, cy):
    """9칸 원본에서 모서리와 가운데 한 줄만 남긴다: 폭 2cx+1, 높이 2cy+1"""
    w, h = im.size
    mx, my = w // 2, h // 2
    out = Image.new("RGBA", (2 * cx + 1, 2 * cy + 1), (0, 0, 0, 0))
    for sx0, sx1, dx in ((0, cx, 0), (mx, mx + 1, cx), (w - cx, w, cx + 1)):
        for sy0, sy1, dy in ((0, cy, 0), (my, my + 1, cy), (h - cy, h, cy + 1)):
            out.paste(im.crop((sx0, sy0, sx1, sy1)), (dx, dy))
    return out


def clear_traces(frame, y0):
    """발광 띠 안쪽 판에서 y0 아래를 판 색으로 덮는다 (글자 뒤에 회로 홈이 지나가지 않게, 위쪽 홈은 남김)"""
    a = np.array(frame)
    teal = np.zeros(a.shape[:2], bool)
    for c in TEAL:
        teal |= (a[..., :3] == c).all(axis=2)
    labels, _ = ndimage.label(~teal)  # 4방향 연결이라 대각선 띠 사이로 새지 않는다
    inner = labels == labels[frame.height // 2, frame.width // 2]
    assert inner.mean() < 0.9, "발광 띠가 끊겨 바깥까지 이어짐"
    inner[:y0] = False
    a[inner] = (*PLATE, 255)
    return Image.fromarray(a, "RGBA")


def icons_sheet(path):
    """19개 전부를 받침 안에 넣은 모습 (받침은 게임과 같은 2배, 금지 표시처럼 보이는지 보는 용도)"""
    font = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 12)
    ped = Image.open(f"{OUT}/ped_pc.png").convert("RGBA")
    ped = ped.resize((ped.width * 2, ped.height * 2), Image.NEAREST)
    cols, cell_w, cell_h = 5, 150, 160
    rows = (len(ICONS) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0x14, 0x11, 0x1c, 255))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for n, name in enumerate(ICONS):
        x, y = (n % cols) * cell_w + (cell_w - ped.width) // 2, (n // cols) * cell_h + 6
        sheet.alpha_composite(ped, (x, y))
        icon = Image.open(f"{OUT}/icons/{name}.png").resize((96, 96), Image.NEAREST)
        sheet.alpha_composite(icon, (x + (ped.width - 96) // 2, y + (ped.height - 96) // 2))
        d.text((x + ped.width // 2, y + ped.height + 2), name, font=font, fill="#fef8e5", anchor="ma")
    sheet.convert("RGB").save(path)


def main():
    os.makedirs(f"{OUT}/icons", exist_ok=True)
    for name, (src, x0, x1) in ICONS.items():
        icon = make_icon(src, x0, x1)
        icon.save(f"{OUT}/icons/{name}.png")
        print(name, len(icon.getcolors(999)) - 1, "색")
    for part in ("crest", "corner", "pill", "ped_pc", "ped_phone", "wing_s_l", "wing_s_r", "wing_b_l", "wing_b_r"):
        shutil.copy(f"{PARTS}/{part}.png", f"{OUT}/{part}.png")
    frame = shrink_nine(Image.open(f"{PARTS}/frame.png").convert("RGBA"), CORNER_X, CORNER_Y)
    clear_traces(frame, CORNER_Y).save(f"{OUT}/frame.png")
    shrink_nine(Image.open(f"{PARTS}/button.png").convert("RGBA"), BTN_X, BTN_Y).save(f"{OUT}/button.png")
    icons_sheet("review/v070_step5/icons_all.png")


if __name__ == "__main__":
    main()
