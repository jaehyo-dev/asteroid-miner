"""편향 실드 연출 시안: 우주선 윤곽을 따라가는 금색 테두리 (GAME_SPEC 11번). 둥근 막 없음.
충전 3단계, 완충(광택이 윤곽을 따라 흐름) 4프레임, 막는 순간(번쩍 → 조각으로 흩어짐) 4프레임 + 실제 게임 크기.
실행: python3 review/v070_step5/make_shield.py → shield_frames.png"""
import math, random
from PIL import Image, ImageDraw, ImageFont

D = "review/v070_step5/"
CELL, CROP, ZOOM = 48, 36, 5  # 칸 48 → 가운데 36만, 5배(정수)로 보여 줌
GOLD, BRIGHT, DEEP = (246, 206, 80), (254, 248, 229), (248, 148, 25)
BG = (10, 8, 20, 255)
F = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 24)
F12 = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 12)


def ship():
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for n in ("ship_engine", "ship", "ship_cannon"):  # 게임과 같은 위쪽 방향 첫 프레임
        im.alpha_composite(Image.open(f"assets/sprites/run/{n}.png").convert("RGBA").crop((0, 0, CELL, CELL)))
    o = (CELL - CROP) // 2
    return im.crop((o, o, o + CROP, o + CROP))


SHIP = ship()
SOLID = {(x, y) for y in range(CROP) for x in range(CROP) if SHIP.getpixel((x, y))[3] > 0}
N8 = [(a, b) for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b]


def ring(src):
    """src를 둘러싼 한 겹 (8방향)"""
    return {(x + a, y + b) for x, y in src for a, b in N8} - src


OUTLINE = ring(SOLID)
GLOW1 = ring(SOLID | OUTLINE)
GLOW2 = ring(SOLID | OUTLINE | GLOW1)
cx = sum(p[0] for p in SOLID) / len(SOLID)
cy = sum(p[1] for p in SOLID) / len(SOLID)
# 윤곽을 따라 도는 순서: 가운데에서 본 각도
ORDER = sorted(OUTLINE, key=lambda p: math.atan2(p[1] - cy, p[0] - cx))


def base():
    im = Image.new("RGBA", (CROP, CROP), BG)
    im.alpha_composite(SHIP)
    return im


def plot(im, cells, color, alpha):
    for x, y in cells:
        if 0 <= x < CROP and 0 <= y < CROP:
            im.alpha_composite(Image.new("RGBA", (1, 1), (*color, alpha)), (x, y))


def charge(ratio):
    """충전 비율만큼 윤곽이 진해진다"""
    im = base()
    plot(im, GLOW2, GOLD, int(14 * ratio))
    plot(im, GLOW1, GOLD, int(40 * ratio))
    plot(im, OUTLINE, GOLD, int(235 * ratio))
    return im


def gloss(pos):
    """완충: 빛줄기가 윤곽을 따라 흐른다 (pos 0~1)"""
    im = charge(1.0)
    n = len(ORDER)
    head = int(pos * n)
    for i in range(10):
        p = ORDER[(head - i) % n]
        plot(im, [p], BRIGHT, 255 - i * 22)
        if i < 3:
            plot(im, [(p[0] + a, p[1] + b) for a, b in N8 if (p[0] + a, p[1] + b) not in SOLID], BRIGHT, 70)
    return im


def flash():
    """막는 순간: 윤곽이 희게 번쩍, 빛 띠가 넓어지고 우주선도 살짝 밝아짐"""
    im = base()
    plot(im, SOLID, BRIGHT, 110)
    plot(im, GLOW2, GOLD, 90)
    plot(im, GLOW1, GOLD, 170)
    plot(im, OUTLINE, BRIGHT, 255)
    return im


# 조각: 윤곽을 3칸씩 끊어 가운데에서 바깥으로 흩어짐 (시드 고정)
rng = random.Random(5)
SHARDS = [(ORDER[i:i + 3], rng.uniform(0.7, 1.3)) for i in range(0, len(ORDER), 3)]


def shards(t, fade):
    im = base()
    for cells, speed in SHARDS:
        mx = sum(p[0] for p in cells) / len(cells) - cx
        my = sum(p[1] for p in cells) / len(cells) - cy
        d = math.hypot(mx, my) or 1.0
        dx, dy = round(mx / d * t * speed), round(my / d * t * speed)
        color = GOLD if speed > 1.0 else DEEP
        # 멀리 갈수록 조각이 짧아짐
        plot(im, [(x + dx, y + dy) for x, y in cells[: 3 if fade > 0.6 else 2 if fade > 0.3 else 1]], color, int(255 * fade))
    return im


ROWS = [
    ("충전 중: 투명 → 점점 진해짐", [("1/3", charge(0.33)), ("2/3", charge(0.66)), ("거의 참", charge(0.92))]),
    ("완충: 광택이 윤곽을 따라 흐름", [("0초", gloss(0.0)), ("0.1초", gloss(0.3)), ("0.2초", gloss(0.6)), ("0.3초", gloss(0.85))]),
    ("막는 순간: 번쩍 → 조각으로 흩어짐", [("번쩍", flash()), ("조각 1", shards(3, 1.0)), ("조각 2", shards(7, 0.6)), ("조각 3", shards(12, 0.25))]),
]
FRAME = CROP * ZOOM
GAP, LABEL, TITLE = 16, 46, 40
W = GAP + 4 * (FRAME + GAP) + 190
H = GAP + len(ROWS) * (TITLE + FRAME + LABEL) + GAP
sheet = Image.new("RGBA", (W, H), (20, 17, 28, 255))
d = ImageDraw.Draw(sheet)
d.fontmode = "1"
y = GAP
for title, frames in ROWS:
    d.text((GAP, y + 4), title, font=F, fill=(254, 248, 229))
    y += TITLE
    for i, (label, im) in enumerate(frames):
        x = GAP + i * (FRAME + GAP)
        sheet.alpha_composite(im.resize((FRAME, FRAME), Image.NEAREST), (x, y))
        d.text((x + 2, y + FRAME + 8), label, font=F, fill=(165, 178, 157))
    # 오른쪽: 실제 게임 크기 (PC 2배, 폰 1배)
    mx = GAP + 4 * (FRAME + GAP) + 10
    key = frames[-1][1] if title.startswith("충전") else frames[1][1]
    sheet.alpha_composite(key.resize((CROP * 2, CROP * 2), Image.NEAREST), (mx, y))
    sheet.alpha_composite(key, (mx + CROP * 2 + 12, y + CROP // 2))
    d.text((mx, y + CROP * 2 + 6), "PC 2배", font=F12, fill=(165, 178, 157))
    d.text((mx + CROP * 2 + 12, y + CROP * 2 + 6), "폰 1배", font=F12, fill=(165, 178, 157))
    y += FRAME + LABEL
sheet.convert("RGB").save(D + "shield_frames.png")
print("저장", sheet.size)
