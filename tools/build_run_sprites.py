"""출격 화면 그림 시트 만들기 (Foozle Void 팩 + Codex로 만든 운석·광물 → assets/sprites/run/).

- 돌아가는 그림(우주선·적·탄·운석)은 tools/rotsprite.py로 8방향 시트를 만든다 (열 = 프레임, 행 = 방향, 0 = 위쪽).
  적 그림은 팩에서 아래를 보므로 먼저 뒤집어 위쪽을 보게 맞춘다.
- 운석 시트: 열 0 = 멀쩡함, 1·2 = 금 간 단계. 깨지는 애니메이션은 따로 (*_boom.png, 돌리지 않음).
  중간 운석은 팩 Asteroid 01 그대로, 작은·큰 운석은 Codex 그림(assets/sprites/run/rock_*_base.png)에서
  금과 깨지는 프레임을 팩 운석과 같은 색·순서로 만든다 (금 → 용암빛 → 조각이 흩어지며 사라짐).
- 탄에 맞은 순간 흰 번쩍임은 게임의 셰이더(scripts/flash_white.gdshader)가 그려서 따로 그림을 만들지 않는다.
- 황금 운석은 팩 운석의 바위 색만 팔레트의 금색으로 바꾼다. 고대 경비선 탄은 내 탄(주황)과 구분되게 빨간색으로 바꾼다.

다시 만들기: python3 tools/build_run_sprites.py   (같은 입력이면 항상 같은 결과: 무작위는 시드 고정)
"""

from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import rotsprite  # noqa: E402
import shrink_ship  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
VENDOR = os.path.join(ROOT, "assets/vendor/foozle")
OUT = os.path.join(ROOT, "assets/sprites/run")

SHIP = "main_ship/Main Ship"
NAUT = "fleet3_nautolan/Nautolan"
NAIR = "fleet2_nairan/Nairan"
KLAED = "fleet1_klaed/Kla'ed"
ROCK = "environment/Asteroids/PNGs"

## 팩 운석의 금·용암 색 (Explode 시트에서 씀): 노랑, 주황, 진한 주황, 빨강
LAVA = [(249, 194, 43), (247, 150, 23), (251, 107, 29), (232, 59, 59)]
## 황금 운석: 팩 운석 바위 색(어두운 순) → 팔레트(void32) 금색 계열
GOLD_MAP = {(46, 34, 47): (152, 70, 51), (62, 53, 70): (248, 148, 25), (98, 85, 101): (246, 206, 80), (150, 108, 108): (254, 248, 229)}
## 고대 경비선 탄: 팩 주황 → 팔레트 빨강 (내 탄은 주황이라 색으로 구분)
RED_MAP = {(247, 150, 23): (203, 55, 56), (249, 194, 43): (242, 92, 118)}


def vendor(path: str) -> Image.Image:
    return Image.open(os.path.join(VENDOR, path)).convert("RGBA")


def recolor(img: Image.Image, mapping: dict) -> Image.Image:
    """mapping에 있는 색만 바꾼다 (나머지·투명은 그대로)."""
    img = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in mapping:
                px[x, y] = mapping[(r, g, b)] + (a,)
    return img


def center_in(img: Image.Image, cell: int) -> Image.Image:
    """그림을 cell x cell 칸 가운데에 놓는다 (정수 위치, 크기는 그대로)."""
    out = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    out.paste(img, ((cell - img.width) // 2, (cell - img.height) // 2), img)
    return out


def orb_frames(strip: Image.Image, count: int, cell: int) -> list[Image.Image]:
    """가로로 늘어놓은 맥동 프레임을 같은 폭으로 나누고, 구체 몸통(3픽셀 이상 찬 줄) 가운데를 칸 가운데에 맞춘다.
    (튀는 불꽃은 프레임마다 위치가 달라 전체 bbox로 맞추면 구체가 흔들려 보임)"""
    w = strip.width // count
    out = []
    for i in range(count):
        f = strip.crop((i * w, 0, i * w + w, strip.height))
        a = f.getchannel("A").point(lambda v: 1 if v else 0)
        cols = [x for x in range(f.width) if sum(a.getpixel((x, y)) for y in range(f.height)) >= 3]
        rows = [y for y in range(f.height) if sum(a.getpixel((x, y)) for x in range(f.width)) >= 3]
        cx, cy = (cols[0] + cols[-1] + 1) // 2, (rows[0] + rows[-1] + 1) // 2
        c = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        c.paste(f, (cell // 2 - cx, cell // 2 - cy), f)
        out.append(c)
    return out


def row(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def crack_frames(base: Image.Image, seed: int) -> list[Image.Image]:
    """금 간 단계 2장: 1단계는 노란 금 2줄, 2단계는 금이 늘고 주황·빨강으로 달아오름 (팩 운석 Explode 1·2번처럼)."""
    rng = random.Random(seed)
    w, h = base.size
    solid = {(x, y) for y in range(h) for x in range(w) if base.getpixel((x, y))[3]}
    cx, cy = w / 2.0, h / 2.0
    size = max(w, h)

    def walk(n_lines: int) -> list[tuple[int, int]]:
        pts = []
        for _ in range(n_lines):
            a = rng.random() * math.tau
            x, y = cx, cy
            for _ in range(int(size * 0.45)):
                a += rng.uniform(-0.5, 0.5)
                x += math.cos(a)
                y += math.sin(a)
                p = (int(x), int(y))
                if p in solid:
                    pts.append(p)
        return pts

    first = walk(2)
    second = first + walk(2 + size // 20)
    out = []
    for level, pts in ((1, first), (2, second)):
        img = base.copy()
        for x, y in pts:
            img.putpixel((x, y), LAVA[0] + (255,) if level == 1 else LAVA[1] + (255,))
        if level == 2:
            # 금 둘레가 달아오른다 (금 바로 옆 바위 픽셀을 진한 주황, 가끔 빨강으로)
            # 팩 Explode 2번처럼 굵게: 금 둘레 8칸 대부분이 진한 주황·빨강으로 (용암 칸)
            for x, y in pts:
                for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, -1)):
                    q = (x + dx, y + dy)
                    if q in solid and q not in pts and rng.random() < 0.7:
                        img.putpixel(q, (LAVA[2] if rng.random() < 0.6 else LAVA[3]) + (255,))
        out.append(img)
    return out


def explode_frames(base: Image.Image, cell: int, seed: int, count: int = 8) -> list[Image.Image]:
    """깨지는 애니메이션 count장 (cell 칸 가운데 기준). 팩 운석 Explode처럼 굵게:
    0 멀쩡함 → 1·2 금(2는 굵은 용암 금) → 3~ 운석 그림을 굵은 바위 덩어리(보로노이)로 잘라 바깥으로 흩는다.
    덩어리마다 뒤로 넓은 원뿔 불꽃(머리 쪽 진한 주황 → 끝 노랑)이 달리고, 덩어리가 작아져 사라지면 머리 자리는 빨강.
    덩어리 수·크기·불꽃은 운석 크기에 비례해서 큰 운석이 가장 묵직하게 깨진다."""
    rng = random.Random(seed)
    cracked = crack_frames(base, seed)
    frames = [center_in(base, cell), center_in(cracked[0], cell), center_in(cracked[1], cell)]
    w, h = base.size
    pieces_n = max(5, min(16, (w * h) // 220))
    seeds = [(rng.uniform(0, w), rng.uniform(0, h)) for _ in range(pieces_n)]
    pieces: dict[int, list[tuple[int, int, tuple]]] = {i: [] for i in range(pieces_n)}
    src = cracked[1]
    for y in range(h):
        for x in range(w):
            c = src.getpixel((x, y))
            if c[3]:
                i = min(range(pieces_n), key=lambda k: (seeds[k][0] - x) ** 2 + (seeds[k][1] - y) ** 2)
                pieces[i].append((x, y, c))
    flying = count - 3
    off = ((cell - w) // 2, (cell - h) // 2)
    # 프레임별(0 → 끝) 덩어리 크기, 불꽃 폭, 불꽃 길이 비율
    head_k = [1.0, 0.7, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0][:flying]
    width_k = [1.0, 0.85, 0.55, 0.3, 0.15, 0.1, 0.1, 0.1][:flying]
    length_k = [1.0, 1.25, 1.1, 0.75, 0.4, 0.3, 0.3, 0.3][:flying]
    for f in range(flying):
        t = (f + 1) / flying  # 0 → 1
        ease = 1.0 - (1.0 - t) ** 2  # 처음에 빨리 튀어 나가고 느려진다
        img = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))

        def put(x: float, y: float, color: tuple) -> None:
            q = (int(round(x)) + off[0], int(round(y)) + off[1])
            if 0 <= q[0] < cell and 0 <= q[1] < cell:
                img.putpixel(q, color + (255,))

        heads = []
        for i, pts in pieces.items():
            if not pts:
                continue
            px = sum(p[0] for p in pts) / len(pts)
            py = sum(p[1] for p in pts) / len(pts)
            d = (px - w / 2.0, py - h / 2.0)
            n = math.hypot(*d) or 1.0
            ux, uy = d[0] / n, d[1] / n
            push = (cell / 2.0 - max(w, h) / 2.0) * ease * (0.75 + 0.25 * ((i * 7919) % 10) / 10.0)
            dx, dy = ux * push, uy * push
            hx, hy = px + dx, py + dy
            size = math.sqrt(len(pts))
            # 원뿔 불꽃: 머리에서 가운데 쪽으로 뻗고, 머리 쪽이 넓고 끝으로 갈수록 좁아진다
            length = max(2.0, size * 1.4 * length_k[f])
            width = max(1.0, size * 0.6 * width_k[f])
            steps = int(length * 2)
            for s_i in range(steps):
                s_ = s_i / 2.0
                k = s_ / length
                half = width * (1.0 - k) / 2.0
                color = LAVA[2] if k < 0.25 else (LAVA[1] if k < 0.7 else LAVA[0])
                if head_k[f] == 0.0 and s_ < 1.5:
                    color = LAVA[3]  # 덩어리가 사라진 자리는 빨갛게 달아오른 끝
                cx_, cy_ = hx - ux * s_, hy - uy * s_
                o = -half
                while o <= half:
                    put(cx_ - uy * o, cy_ + ux * o, color)
                    o += 0.5
            heads.append((pts, px, py, dx, dy, size * 0.75 * head_k[f]))
        # 바위 덩어리는 불꽃 위에 (운석 그림 그대로, 가운데에서 멀수록 깎여 작아짐)
        for pts, px, py, dx, dy, radius in heads:
            for x, y, c in pts:
                if math.hypot(x - px, y - py) <= radius:
                    put(x + dx, y + dy, c[:3])
        frames.append(img)
    return frames


def rock_sheets(name: str, base: Image.Image, cell: int, seed: int) -> None:
    """운석 한 크기: 8방향 시트(멀쩡·금1·금2)와 깨지는 시트."""
    boom = explode_frames(base, cell, seed)
    rotsprite.dir8_sheet(row(boom[:3]), cell, cell).save(f"{OUT}/{name}.png")
    row(boom).save(f"{OUT}/{name}_boom.png")


def ship_strips() -> dict[str, Image.Image]:
    """내 우주선 팩 원본의 위쪽 방향 프레임 줄: 피해 4단계(멀쩡 → 아주 망가짐), 엔진 몸체, 엔진 불꽃(대기·출력), 자동 포(7프레임)"""
    states = ["Full health", "Slight damage", "Damaged", "Very damaged"]
    fx = f"{SHIP}/Main Ship - Engine Effects/PNGs/Main Ship - Engines - Base Engine"
    return {
        "ship": row([vendor(f"{SHIP}/Main Ship - Bases/PNGs/Main Ship - Base - {s}.png") for s in states]),
        "ship_engine": vendor(f"{SHIP}/Main Ship - Engines/PNGs/Main Ship - Engines - Base Engine.png"),
        "ship_flame_idle": vendor(f"{fx} - Idle.png"),
        "ship_flame_power": vendor(f"{fx} - Powering.png"),
        "ship_cannon": vendor(f"{SHIP}/Main Ship - Weapons/PNGs/Main Ship - Weapons - Auto Cannon.png"),
    }


## 내 탄 60% (팩 10x17 → 6x10, PLAN 16번). 블록 축소(shrink_ship)는 이 크기에서 검은 고리·꼬리가 사라져서
## 팩 탄의 구조(흰 테 → 검은 고리 → 노랑·주황 속 → 꼬리 점 두 줄)와 색을 그대로 써서 손으로 다시 찍었다.
## 글자 = 팩 색: 0 흰, 1 검정, 2 연노랑, 4 주황, 5 노랑, 7 진한 갈색, 8 진주황. 꼬리 점은 두 프레임이 번갈아 깜빡인다.
BULLET_COLORS = {"0": (255, 255, 255), "1": (0, 0, 0), "2": (251, 185, 84), "4": (247, 150, 23),
                 "5": (249, 194, 43), "7": (158, 69, 57), "8": (251, 107, 29)}
BULLET_FRAMES = [
    ["..00..", ".0110.", "012210", "412214", "418814", "517715", ".5115.", "......", "5....5", "5....5"],
    ["..00..", ".0110.", "012210", "412214", "418814", "517715", ".5115.", "5....5", "......", "5....5"],
]


def bullet_sheet() -> Image.Image:
    """BULLET_FRAMES를 32 칸 가운데에 찍은 8방향 시트 (칸 크기는 예전 그대로 32라 RunSprites.CELL은 그대로)"""
    frames = []
    for rows in BULLET_FRAMES:
        img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
        for y, line in enumerate(rows):
            for x, ch in enumerate(line):
                if ch != ".":
                    img.putpixel((x, y), BULLET_COLORS[ch] + (255,))
        frames.append(center_in(img, 32))
    return rotsprite.dir8_sheet(row(frames), 32, 32)


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    d8 = rotsprite.dir8_sheet
    # 내 우주선: 팩 원본을 60%로 다시 그려 저장 (tools/shrink_ship.py, PLAN 15번). 큰 원본 시트는 게임에 두지 않는다
    for name, strip in ship_strips().items():
        shrink_ship.shrink_sheet(strip, name).save(f"{OUT}/{name}.png")
    bullet_sheet().save(f"{OUT}/bullet.png")  # 팩 Auto cannon bullet을 60%로 다시 찍음

    # 적 3종 (팩은 아래를 봄 → 뒤집음): 몸, 엔진, 파괴
    enemies = {
        "jelly": (f"{NAUT}/Designs - Base/PNGs/Nautolan Ship - Fighter - Base.png",
                  f"{NAUT}/Engine Effects/PNGs/Nautolan Ship - Fighter - Engine Effect.png",
                  f"{NAUT}/Destruction/PNGs/Nautolan Ship - Fighter.png"),
        "bug": (f"{NAIR}/Designs - Base/PNGs/Nairan - Scout - Base.png",
                f"{NAIR}/Engine Effects/PNGs/Nairan - Scout - Engine.png",
                f"{NAIR}/Destruction/PNGs/Nairan - Scout -  Destruction.png"),
        "guard": (f"{KLAED}/Base/PNGs/Kla'ed - Support ship - Base.png",
                  f"{KLAED}/Engine/PNGs/Kla'ed - Support ship - Engine.png",
                  f"{KLAED}/Destruction/PNGs/Kla'ed - Support ship - Destruction.png"),
    }
    for name, (body, engine, boom) in enemies.items():
        d8(vendor(body), 64, 64, turn180=True).save(f"{OUT}/{name}.png")
        d8(vendor(engine), 64, 64, turn180=True).save(f"{OUT}/{name}_engine.png")
        d8(vendor(boom), 64, 64, turn180=True).save(f"{OUT}/{name}_boom.png")
    # 적 탄: 경비선 = Kla'ed 큰 탄(빨간색으로), 심연의 포격 = Codex 에너지 구체(맥동 4프레임, 둥글어서 돌리지 않음: 행 1개)
    # (탄은 팩에서 머리가 위쪽이라 뒤집지 않음. Kla'ed 큰 탄은 8x16 프레임 4장 → 16x16 칸 가운데에 놓음)
    big = recolor(vendor(f"{KLAED}/Projectiles/PNGs/Kla'ed - Big Bullet.png"), RED_MAP)
    d8(row([center_in(big.crop((f * 8, 0, f * 8 + 8, 16)), 16) for f in range(4)]), 16, 16).save(f"{OUT}/guard_shot.png")
    row(orb_frames(Image.open(f"{OUT}/barrage_orb_base.png").convert("RGBA"), 4, 20)).save(f"{OUT}/barrage_shot.png")

    # 운석 3크기 + 황금 운석. 중간은 팩 그림 그대로 (Explode 8프레임)
    explode = vendor(f"{ROCK}/Asteroid 01 - Explode.png")
    d8(explode.crop((0, 0, 96 * 3, 96)), 96, 96).save(f"{OUT}/rock_1.png")
    explode.save(f"{OUT}/rock_1_boom.png")
    gold = recolor(explode, GOLD_MAP)
    d8(gold.crop((0, 0, 96 * 3, 96)), 96, 96).save(f"{OUT}/rock_gold.png")
    gold.save(f"{OUT}/rock_gold_boom.png")
    rock_sheets("rock_0", Image.open(f"{OUT}/rock_small_base.png").convert("RGBA"), 64, 11)
    rock_sheets("rock_2", Image.open(f"{OUT}/rock_large_base.png").convert("RGBA"), 144, 23)


if __name__ == "__main__":
    build()
    print("assets/sprites/run/ 다시 만듦")
