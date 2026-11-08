"""레벨업 카드 프레임 시안 (게임에 적용하지 않음). Codex 원본 → void32 픽셀 부품 → 등급별 조립 → 출격 화면 위 시안.
- 프레임·장식·꼬리표·버튼은 PC·폰 모두 논리 1배. 카드 크기가 달라도 9칸 나누기로 맞춘다 (모서리는 그대로, 변·가운데만 반복).
- 받침과 아이콘은 2배, 글자는 Galmuri11 12px·24px. 등급은 팔레트 색 바꾸기와 장식 추가로 만들어 그림 수를 늘리지 않는다.
실행: python3 review/v070_step5/frame/make_frames.py → review/v070_step5/frame/*.png"""
import os
import re
from collections import Counter
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = "review/v070_step5/"
OUT = ROOT + "frame/"
RAW = "assets/raw/run/frame/"
FONT = "assets/fonts/galmuri/Galmuri11.ttf"
F12, F24 = ImageFont.truetype(FONT, 12), ImageFont.truetype(FONT, 24)
PAL = [tuple(int(c) for c in l.split()[:3]) for l in open("assets/palette/void32.gpl") if re.match(r"\s*\d", l)]
ICONS = {n: Image.open(f"{ROOT}icons/{n}.png").convert("RGBA") for n in ("cooler", "pierce", "drone")}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


STEP = {"M": {"frame": 1024 / 192, "parts": 1774 / 273}, "S": {"frame": 1024 / 192, "parts": 1536 / 288}}
TEAL = rgb("#30e1b9")
TEAL2 = rgb("#99e9e6")
INK, MUTED, DARK = "#fef8e5", "#a5b29d", "#14111c"
RAINBOW = ["#f25c76", "#f89419", "#f6ce50", "#a5cc5f", "#30e1b9", "#99e9e6", "#a884f3"]
GRADES = ["노멀", "레어", "에픽", "유니크", "레전드리"]
NAME_COLOR = {"노멀": INK, "레어": "#99e9e6", "에픽": "#a884f3", "유니크": "#f6ce50"}
GLOW_ALPHA = {"노멀": (), "레어": (80, 34), "에픽": (110, 60, 24), "유니크": (130, 80, 44, 18), "레전드리": (150, 100, 60, 30, 14)}
# 등급별 금속 바꾸기 (원본 색 → 등급 색). 노멀은 발광 띠도 금속처럼 꺼짐
GOLD = {"#a5b29d": "#f6ce50", "#917487": "#dc7f47", "#5c5164": "#984633", "#fef8e5": "#fef8e5", "#3c3544": "#6f2626", "#a5cc5f": "#f6ce50", "#70525e": "#984633", "#577e66": "#dc7f47"}
ACCENT = {"노멀": ("#5c5164", "#917487"), "레어": ("#30e1b9", "#99e9e6"), "에픽": ("#a884f3", "#fef8e5"), "유니크": ("#f6ce50", "#fef8e5")}
EPIC_TINT = {"#917487": "#6b3e75", "#70525e": "#6b3e75"}


def near(p):
    return min(PAL, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, p)))


def is_bg(p):
    return p[0] > 170 and p[2] > 170 and p[1] < 110


def pixelize(im, step):
    """원본을 step 크기 블록으로 나눠 블록마다 가장 많은 색 → void32. 외곽선을 지키려고 배경은 60% 넘을 때만 비움."""
    w, h = max(1, round(im.width / step)), max(1, round(im.height / step))
    px = im.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for j in range(h):
        for i in range(w):
            cnt = Counter()
            for y in range(int(j * step), min(int((j + 1) * step), im.height), 2):
                for x in range(int(i * step), min(int((i + 1) * step), im.width), 2):
                    p = px[x, y]
                    cnt["bg" if is_bg(p) else near(p)] += 1
            if not cnt:
                continue
            top = cnt.most_common(1)[0][0]
            if top == "bg" and cnt["bg"] <= sum(cnt.values()) * 0.6:
                top = [k for k, _ in cnt.most_common() if k != "bg"][0]
            if top != "bg":
                out.putpixel((i, j), (*top, 255))
    return out


def load_parts(key):
    """부품 시트: 윗줄 받침·작은 날개 2·큰 날개 2·모서리, 아랫줄 받침대·꼬리표·버튼"""
    k = key.lower()
    frame_raw = Image.open(f"{RAW}frame_{k}.png").convert("RGB")
    frame = pixelize(frame_raw, STEP[key]["frame"])
    raw = Image.open(f"{RAW}parts_{k}.png").convert("RGB")
    a = np.asarray(raw).astype(int)
    mask = ~((a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 110))
    labels, n = ndimage.label(ndimage.binary_closing(mask, iterations=3))
    boxes = [s for s in ndimage.find_objects(labels) if (s[0].stop - s[0].start) * (s[1].stop - s[1].start) > 1500]
    mid = np.mean([(s[0].start + s[0].stop) / 2 for s in boxes])
    top = sorted([s for s in boxes if (s[0].start + s[0].stop) / 2 < mid], key=lambda s: s[1].start)
    bottom = sorted([s for s in boxes if (s[0].start + s[0].stop) / 2 >= mid], key=lambda s: s[1].start)
    assert len(top) == 6 and len(bottom) == 3, (len(top), len(bottom))
    step = STEP[key]["parts"]
    crop = lambda s, st=step, pad=3: pixelize(raw.crop((s[1].start - pad, s[0].start - pad, s[1].stop + pad, s[0].stop + pad)), st)
    ped_raw = raw.crop((bottom[0][1].start - 3, bottom[0][0].start - 3, bottom[0][1].stop + 3, bottom[0][0].stop + 3))
    parts = {
        "pad_b": {"M": 27, "S": 23}[key],  # 프레임 아래 띠 두께 (단계 점이 띠에 걸리지 않게)
        "frame": frame, "crest": crop(top[0]), "wing_s": (crop(top[1]), crop(top[2])), "wing_b": (crop(top[3]), crop(top[4])),
        "corner": crop(top[5]), "pill": crop(bottom[1]), "button": crop(bottom[2]),
        # 받침은 화면별 폭에 맞춰 원본에서 다시 줄인다 (늘리거나 소수로 키우지 않음)
        "ped_pc": pixelize(ped_raw, ped_raw.width / 64), "ped_phone": pixelize(ped_raw, ped_raw.width / 72),
    }
    return parts


def recolor(im, grade, phase=0, metal=True):
    """팔레트 색 바꾸기. 청록 = 발광 부분, 나머지 = 금속. 레전드리는 대각선 무지개가 phase만큼 흐른다."""
    out = im.copy()
    px = out.load()
    gold = {rgb(a): rgb(b) for a, b in GOLD.items()}
    tint = {rgb(a): rgb(b) for a, b in EPIC_TINT.items()}
    teal_like = {TEAL, TEAL2, rgb("#125952"), rgb("#1da775"), rgb("#4d80cd")}
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            c = (r, g, b)
            if c in teal_like:
                if grade == "레전드리":
                    c = rgb(RAINBOW[((x + y + phase) // 10) % len(RAINBOW)])
                else:
                    main, light = ACCENT[grade]
                    c = rgb(light if c == TEAL2 else main)
            elif metal and grade == "레전드리" and c == rgb("#a5b29d"):
                c = rgb(RAINBOW[((x + y + phase) // 14) % len(RAINBOW)])  # 두꺼운 금속 띠가 무지개로 흐른다
            elif metal and grade in ("유니크", "레전드리"):
                c = gold.get(c, c)
            elif metal and grade == "에픽":
                c = tint.get(c, c)
            px[x, y] = (*c, a)
    return out


def nine(im, W, H, cx, cy):
    """9칸 나누기: 모서리(cx, cy)는 그대로, 변·가운데는 원본 가운데 한 줄을 반복한다."""
    w, h = im.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mx, my = w // 2, h // 2
    for (sx0, sx1, dx0, dx1) in ((0, cx, 0, cx), (mx, mx + 1, cx, W - cx), (w - cx, w, W - cx, W)):
        for (sy0, sy1, dy0, dy1) in ((0, cy, 0, cy), (my, my + 1, cy, H - cy), (h - cy, h, H - cy, H)):
            if dx1 > dx0 and dy1 > dy0:
                out.paste(im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def clear_traces(frame, y0):
    """발광 띠로 둘러싸인 안쪽 판을 찾아 y0 아래를 판 색으로 덮는다 (글자 뒤에 회로 홈이 지나가지 않게, 위쪽 홈은 남김)"""
    a = np.array(frame)
    teal = (a[..., :3] == TEAL).all(axis=2) | (a[..., :3] == TEAL2).all(axis=2)
    labels, _ = ndimage.label(~teal)  # 4방향 연결이라 대각선 띠 사이로 새지 않는다
    inner = labels == labels[frame.height // 2, frame.width // 2]
    assert inner.mean() < 0.9, "발광 띠가 끊겨 바깥까지 이어짐"
    inner[:y0] = False
    a[inner] = (*rgb("#2b1925"), 255)
    return Image.fromarray(a, "RGBA")


def wrap(text, font, width):
    lines, cur = [], ""
    for word in text.split(" "):
        t = (cur + " " + word).strip()
        if font.getlength(t) <= width:
            cur = t
            continue
        if cur:
            lines.append(cur)
        cur = word
        while font.getlength(cur) > width:
            n = len(cur)
            while font.getlength(cur[:n]) > width:
                n -= 1
            lines.append(cur[:n])
            cur = cur[n:]
    lines.append(cur)
    return lines


def text(d, x, y, s, font, color, anchor="la"):
    d.text((x, y), s, font=font, fill=color, anchor=anchor)


def rainbow_text(d, x, y, s, font, phase=0):
    """레전드리 이름: 글자마다 무지개 (가운데 정렬)"""
    x -= int(font.getlength(s)) // 2
    n = 0
    for ch in s:
        d.text((x, y), ch, font=font, fill=RAINBOW[(n + phase) % len(RAINBOW)])
        x += int(font.getlength(ch))
        n += ch != " "


def with_glow(card, grade, u, phase=0, boost=0):
    """카드 윤곽을 따라 계단 빛 띠. 카드에 여백을 붙여 돌려준다 (u = 띠 한 칸의 픽셀 수)."""
    steps = [a for a in GLOW_ALPHA[grade] for _ in range(u)]
    extra = boost * u
    m = len(steps) + extra + 2
    out = Image.new("RGBA", (card.width + 2 * m, card.height + 2 * m), (0, 0, 0, 0))
    base = Image.new("L", out.size, 0)
    base.paste(card.getchannel("A").point(lambda v: 255 if v else 0), (m, m))
    prev = base
    for i, a in enumerate(steps + [24] * extra):
        grown = prev.filter(ImageFilter.MaxFilter(3))
        ring = np.asarray(grown).astype(int) - np.asarray(prev).astype(int) > 0
        layer = np.zeros((*ring.shape, 4), np.uint8)
        if grade == "레전드리":
            ys, xs = np.nonzero(ring)
            for x, y in zip(xs, ys):
                layer[y, x] = (*rgb(RAINBOW[((x + y + phase) // 10) % len(RAINBOW)]), a)
        else:
            layer[ring] = (*rgb(ACCENT[grade][0]), a)
        out.alpha_composite(Image.fromarray(layer, "RGBA"))
        prev = grown
    out.alpha_composite(card, (m, m))
    return out, m


SCREEN = {
    "PC": dict(size=(640, 360), k=2, W=196, gap=10, ped="ped_pc", pad=19, name=F24, desc=F12, tag=F12, tag_h=23, btn=(200, 30), btn_font=F12, glow=1, ped_top=24, dot=5, btn_gap=4),
    "PHONE": dict(size=(844, 390), k=1, W=262, gap=12, ped="ped_phone", pad=19, name=F24, desc=F24, tag=F24, tag_h=36, btn=(300, 40), btn_font=F24, glow=2, ped_top=24, dot=6, btn_gap=5),
}


def compose_card(parts, key, c, s, phase=0, back=False):  # s는 prep()이 만든 값
    """카드 한 장(받침·글자 포함) RGBA. back이면 뒷면(내용 없음)."""
    name, kind, desc, step, maxi, grade, icon = c
    W, H = s["W"], s["H"]
    # 장식이 위로 튀어나오는 만큼 위쪽 여백
    TOP = 8
    card = Image.new("RGBA", (W, H + TOP), (0, 0, 0, 0))
    ped_h = parts[s["ped"]].height * 2
    # 글자 구역의 회로 홈은 지우고 색을 입힌다 (청록 띠로 안쪽을 찾으므로 색 바꾸기 전에)
    frame = recolor(clear_traces(nine(parts["frame"], W, H, 70, 84), s["ped_top"] + ped_h), grade, phase)
    # 입체감: 안쪽 판 위쪽은 살짝 밝게, 아래쪽은 어둡게 (계단 띠, 빛 효과)
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    p = s["pad"]
    for i, a in enumerate((26, 16, 8)):
        sd.rectangle((p, p + i * 3, W - p - 1, p + i * 3 + 2), fill=(254, 248, 229, a))
    for i, a in enumerate((70, 44, 22)):
        sd.rectangle((p, H - s["pad_b"] - (i + 1) * 4, W - p - 1, H - s["pad_b"] - i * 4 - 1), fill=(8, 6, 14, a))
    fa = np.asarray(frame)
    inner_mask = (fa[..., 0] < 70) & (fa[..., 1] < 45) & (fa[..., 2] < 60)  # 어두운 판에만
    sa = np.array(shade)
    sa[..., 3] = sa[..., 3] * inner_mask
    frame.alpha_composite(Image.fromarray(sa, "RGBA"))
    card.alpha_composite(frame, (0, TOP))
    d = ImageDraw.Draw(card)
    d.fontmode = "1"
    cx = W // 2
    # 등급 장식: 에픽 작은 날개, 유니크·레전드리 큰 날개 + 모서리 쇠
    crest = recolor(parts["crest"], grade, phase)
    # 노멀은 장식 없이 받침의 보석만 꺼진 색
    if grade == "에픽":
        wing = parts["wing_s"]
    elif grade in ("유니크", "레전드리"):
        wing = parts["wing_b"]
    else:
        wing = None
    if grade in ("유니크", "레전드리"):
        cn = recolor(parts["corner"], grade, phase)
        card.alpha_composite(cn, (2, TOP + 2))
        card.alpha_composite(cn.transpose(Image.FLIP_LEFT_RIGHT), (W - cn.width - 2, TOP + 2))
        if grade == "레전드리":  # 아래 모서리까지
            flip = cn.transpose(Image.FLIP_TOP_BOTTOM)
            card.alpha_composite(flip, (2, TOP + H - cn.height - 2))
            card.alpha_composite(flip.transpose(Image.FLIP_LEFT_RIGHT), (W - cn.width - 2, TOP + H - cn.height - 2))
    if wing:
        wl, wr = recolor(wing[0], grade, phase), recolor(wing[1], grade, phase)
        card.alpha_composite(wl, (cx - crest.width // 2 - wl.width + 3, 2))
        card.alpha_composite(wr, (cx + crest.width // 2 - 3, 2))
    card.alpha_composite(crest, (cx - crest.width // 2, 0))
    if back:
        return card, TOP
    # 받침 + 아이콘 (둘 다 2배)
    ped = recolor(parts[s["ped"]], grade, phase).resize((parts[s["ped"]].width * 2, parts[s["ped"]].height * 2), Image.NEAREST)
    py = TOP + s["ped_top"]
    card.alpha_composite(ped, (cx - ped.width // 2, py))
    ic = ICONS[icon].resize((96, 96), Image.NEAREST)
    card.alpha_composite(ic, (cx - 48, py + (ped.height - 96) // 2))
    y = py + ped.height - s["tag_h"] // 2
    # 알약 꼬리표: 받침 아래쪽에 걸침 (양끝 고정, 가운데 반복)
    tw = int(s["tag"].getlength(kind)) + 30
    pill = nine(recolor(parts["pill"], grade, phase), tw, s["tag_h"], parts["pill"].width // 2 - 1, parts["pill"].height // 2 - 1)
    card.alpha_composite(pill, (cx - tw // 2, y))
    text(d, cx, y + (s["tag_h"] - s["tag"].size) // 2 - 1, kind, s["tag"], INK, "ma")
    y += s["tag_h"] + 3
    # 이름: 등급 색, 이름 칸 높이는 고정해서 카드끼리 글줄이 맞게
    inner = W - 2 * p - 4
    for line in wrap(name, s["name"], inner):
        if grade == "레전드리":
            rainbow_text(d, cx, y, line, s["name"], phase // 10)
        else:
            text(d, cx, y, line, s["name"], NAME_COLOR[grade], "ma")
        y += s["name"].size + 1
    y = max(y, py + ped.height - s["tag_h"] // 2 + s["tag_h"] + 3 + s["name_h"]) + 2
    for line in wrap(desc, s["desc"], inner):
        text(d, cx, y, line, s["desc"], INK, "ma")
        y += s["desc"].size + 1
    # 단계 점: 프레임 바닥 위쪽 가운데
    size, gap = s["dot"], 2
    total = maxi * size + (maxi - 1) * gap
    dx = cx - total // 2
    dy = TOP + H - s["pad_b"] - size - 3
    col = rgb(RAINBOW[2]) if grade == "레전드리" else rgb(NAME_COLOR[grade])
    for i in range(maxi):
        d.rectangle((dx + i * (size + gap), dy, dx + i * (size + gap) + size - 1, dy + size - 1), fill=(*rgb("#5c5164"), 255))
        d.rectangle((dx + i * (size + gap) + 1, dy + 1, dx + i * (size + gap) + size - 2, dy + size - 2), fill=(*(col if i < step else rgb(DARK)), 255))
    return card, TOP


def button(parts, s, left):
    """다시 뽑기 버튼 하나: 남은 횟수 표시, 0회면 어둡게 꺼진 모양"""
    W, H = s["btn"]
    art = parts["button"]
    plate = nine(recolor(art, "레어" if left else "노멀", metal=False), W, H, 30, art.height // 2 - 1)
    if not left:  # 비활성: 회색으로 빼고 어둡게
        a = np.array(plate)
        gray = (a[..., :3].mean(axis=2) * 0.55).astype(np.uint8)
        a[..., 0], a[..., 1], a[..., 2] = gray, gray, gray
        plate = Image.fromarray(a, "RGBA")
    d = ImageDraw.Draw(plate)
    d.fontmode = "1"
    f = s["btn_font"]
    color = INK if left else "#5c5164"
    label = "다시 뽑기"
    count = f"{left}회"
    gap = f.size // 2
    total = int(f.getlength(label) + gap + f.getlength(count))
    x = (W - total) // 2
    y = (H - f.size) // 2 - 1
    text(d, x, y, label, f, color)
    text(d, x + int(f.getlength(label)) + gap, y, count, f, "#f6ce50" if left else "#5c5164")
    return plate


def prep(kind, cards, parts):
    """화면 값 + 이름 칸 + 카드 높이: 설명 아래 빈 공간이 없게 가장 긴 내용에 맞춘다"""
    s = dict(SCREEN[kind])
    inner = s["W"] - 2 * s["pad"] - 4
    s["name_h"] = max(len(wrap(c[0], s["name"], inner)) for c in cards) * (s["name"].size + 1)
    desc_h = max(len(wrap(c[2], s["desc"], inner)) for c in cards) * (s["desc"].size + 1)
    ped_h = parts[s["ped"]].height * 2
    s["pad_b"] = parts["pad_b"]
    s["H"] = s["ped_top"] + ped_h + s["tag_h"] // 2 + 3 + s["name_h"] + 2 + desc_h + 4 + s["dot"] + 3 + s["pad_b"]
    return s


COOLER = ("시스템 쿨러 개량", "공격", "발사 속도 +15%", 2, 5, "레어", "cooler")
PIERCE = ("텅스텐 관통탄", "공격", "탄이 대상 1개를 더 뚫고 지나감", 1, 3, "에픽", "pierce")
DRONE = ("호위 드론 사출", "드론", "드론 2기가 따라다니며 함께 공격", 1, 3, "유니크", "drone")
NORMAL = ("시스템 쿨러 개량", "공격", "발사 속도 +10%", 1, 5, "노멀", "cooler")
LEGEND = ("궤도 관통 가속기", "공격", "모든 탄이 사거리 끝까지 관통", 1, 1, "레전드리", "pierce")
THREE = [COOLER, PIERCE, DRONE]
FIVE = [NORMAL, COOLER, PIERCE, DRONE, LEGEND]
REVEAL = [COOLER, PIERCE, LEGEND]


def backdrop(kind, alpha=170):
    bg = Image.open(f"{ROOT}bg_{'pc' if kind == 'PC' else 'phone'}.png").convert("RGBA")
    bg.alpha_composite(Image.new("RGBA", bg.size, (8, 6, 14, alpha)))
    return bg


def screen(parts, key, kind):
    s = prep(kind, THREE, parts)
    W, H = s["size"]
    k = s["k"]
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    total = 3 * s["W"] + 2 * s["gap"]
    x0 = (W - total) // 2
    btn = button(parts, s, 2)
    y0 = (H - s["H"] - s["btn_gap"] - btn.height) // 2
    for i, c in enumerate(THREE):
        card, top = compose_card(parts, key, c, s)
        g, m = with_glow(card, c[5], s["glow"])
        layer.alpha_composite(g, (max(x0 + i * (s["W"] + s["gap"]) - m, 0), max(y0 - top - m, 0)))
    layer.alpha_composite(btn, ((W - btn.width) // 2, y0 + s["H"] + s["btn_gap"]))
    out = backdrop(kind)
    out.alpha_composite(layer.resize((W * k, H * k), Image.NEAREST))
    return out.convert("RGB")


def grades_sheet(parts, key):
    s = prep("PC", FIVE, parts)
    gap = 18
    W, H = 5 * s["W"] + 6 * gap, s["H"] + 96
    sheet = Image.new("RGBA", (W, H), (*rgb(DARK), 255))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for i, c in enumerate(FIVE):
        x = gap + i * (s["W"] + gap)
        text(d, x + s["W"] // 2, 2, c[5], F12, NAME_COLOR.get(c[5], RAINBOW[2]), "ma")
        card, top = compose_card(parts, key, c, s)
        g, m = with_glow(card, c[5], 1)
        sheet.alpha_composite(g, (x - m, 22 - m - top + 8))
    y = s["H"] + 34
    for j, left in enumerate((2, 0)):  # 버튼 상태 비교
        b = button(parts, s, left)
        x = W // 2 - b.width - 8 + j * (b.width + 16)
        sheet.alpha_composite(b, (x, y))
        text(d, x + b.width // 2, y + b.height + 2, "남은 횟수 있음" if left else "0회: 비활성", F12, MUTED, "ma")
    return sheet.resize((W * 2, H * 2), Image.NEAREST).convert("RGB")


def flip_width(card, ratio):
    """뒤집기 프레임: 세로줄을 nearest로 골라 폭만 줄임 (픽셀 격자 유지)"""
    w = max(2, int(card.width * ratio))
    return card.resize((w, card.height), Image.NEAREST)


def flash(card_img, grade, strength, u, phase):
    """번쩍: 카드가 희게 + 등급별로 넓은 빛 고리"""
    out = card_img.copy()
    a = np.array(out)
    mix = strength  # 흰색 섞는 비율
    for ch in range(3):
        a[..., ch] = (a[..., ch] * (1 - mix) + 254 * mix).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


FLASH = {"노멀": (0.25, 0), "레어": (0.4, 3), "에픽": (0.55, 6), "유니크": (0.7, 10), "레전드리": (0.85, 16)}


def reveal_frame(parts, key, t, s):
    """t(초)에서의 화면 한 장 (640x360 논리). 카드는 0.28초 간격으로 위에서 내려오다 뒤집히며 앞면으로."""
    W, H = s["size"]
    dim = min(t / 0.12, 1.0)
    out = Image.open(f"{ROOT}bg_pc.png").convert("RGBA").resize((W, H), Image.NEAREST)
    out.alpha_composite(Image.new("RGBA", (W, H), (8, 6, 14, int(170 * dim))))
    x0 = (W - (3 * s["W"] + 2 * s["gap"])) // 2
    btn = button(parts, s, 2)
    y0 = (H - s["H"] - s["btn_gap"] - btn.height) // 2
    phase = int(t * 40)
    for i, c in enumerate(REVEAL):
        ct = t - 0.15 - i * 0.28
        if ct < 0:
            continue
        x = x0 + i * (s["W"] + s["gap"])
        if ct < 0.12:  # 뒷면으로 내려옴 (ease-out)
            r = ct / 0.12
            back, top = compose_card(parts, key, c, s, phase, back=True)
            out.alpha_composite(back, (x, max(0, y0 - top - int(60 * (1 - r) ** 2))))
        elif ct < 0.2:  # 뒤집힘: 폭이 줄었다가 앞면으로 늘어남
            r = (ct - 0.12) / 0.08
            face, top = compose_card(parts, key, c, s, phase, back=r < 0.5)
            ratio = abs(1 - 2 * r)
            f = flip_width(face, max(ratio, 0.04))
            out.alpha_composite(f, (x + (face.width - f.width) // 2, y0 - top))
        else:
            face, top = compose_card(parts, key, c, s, phase)
            strength, boost = FLASH[c[5]]
            r = min((ct - 0.2) / 0.25, 1.0)  # 번쩍은 0.25초 동안 사라짐
            f = flash(face, c[5], strength * (1 - r), 1, phase) if r < 1 else face
            g, m = with_glow(f, c[5], 1, phase, int(boost * (1 - r)))
            ox, oy = x - m, y0 - top - m
            out.alpha_composite(g.crop((max(-ox, 0), max(-oy, 0), g.width, g.height)), (max(ox, 0), max(oy, 0)))
    if t > 1.1:
        out.alpha_composite(btn, ((W - btn.width) // 2, y0 + s["H"] + s["btn_gap"]))
    return out


def reveal_sheet(parts, key):
    s = prep("PC", REVEAL, parts)
    times = [0.1, 0.2, 0.31, 0.4, 0.7, 0.98, 1.05, 1.5]
    W, H = s["size"]
    cols, label = 4, 18
    sheet = Image.new("RGBA", (cols * W + (cols + 1) * 8, 2 * (H + label) + 3 * 8), (*rgb(DARK), 255))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for n, t in enumerate(times):
        x = 8 + (n % cols) * (W + 8)
        y = 8 + (n // cols) * (H + label + 8)
        text(d, x, y, f"{t:.2f}초", F12, MUTED)
        sheet.alpha_composite(reveal_frame(parts, key, t, s), (x, y + label))
    return sheet.convert("RGB")


def glow_compare(parts, key):
    """앞면으로 뒤집힌 직후의 등급별 빛 비교: 등급이 높을수록 번쩍임과 빛 고리가 강하다"""
    s = prep("PC", FIVE, parts)
    gap = 26
    W, H = 5 * s["W"] + 6 * gap, s["H"] + 60
    sheet = Image.new("RGBA", (W, H), (*rgb(DARK), 255))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for i, c in enumerate(FIVE):
        x = gap + i * (s["W"] + gap)
        text(d, x + s["W"] // 2, 2, c[5], F12, NAME_COLOR.get(c[5], RAINBOW[2]), "ma")
        face, top = compose_card(parts, key, c, s, 8)
        strength, boost = FLASH[c[5]]
        g, m = with_glow(flash(face, c[5], strength * 0.6, 1, 8), c[5], 1, 8, boost)
        ox, oy = x - m, 30 - m
        sheet.alpha_composite(g.crop((max(-ox, 0), max(-oy, 0), g.width, g.height)), (max(ox, 0), max(oy, 0)))
    return sheet.convert("RGB")


if __name__ == "__main__":
    for key in ("M", "S"):
        parts = load_parts(key)
        # 구현 때 쓸 부품 (청록 = 등급 색으로 바꾸는 자리)
        os.makedirs(f"{OUT}parts_{key}", exist_ok=True)
        named = {k: v for k, v in parts.items() if isinstance(v, Image.Image)}
        named.update({"wing_s_l": parts["wing_s"][0], "wing_s_r": parts["wing_s"][1], "wing_b_l": parts["wing_b"][0], "wing_b_r": parts["wing_b"][1]})
        for name, im in named.items():
            im.save(f"{OUT}parts_{key}/{name}.png")
        screen(parts, key, "PC").save(f"{OUT}frame_{key}_pc_1280x720.png")
        screen(parts, key, "PHONE").save(f"{OUT}frame_{key}_phone_844x390.png")
        grades_sheet(parts, key).save(f"{OUT}frame_{key}_grades.png")
        reveal_sheet(parts, key).save(f"{OUT}frame_{key}_reveal.png")
        glow_compare(parts, key).save(f"{OUT}frame_{key}_reveal_glow.png")
    print("시안 저장")
