"""출격 화면 그림 시트 만들기 (Foozle Void 팩 + Codex로 만든 운석·광물 → assets/sprites/run/).

- 돌아가는 그림(우주선·적·탄·운석)은 tools/rotsprite.py로 8방향 시트를 만든다 (열 = 프레임, 행 = 방향, 0 = 위쪽).
  적 그림은 팩에서 아래를 보므로 먼저 뒤집어 위쪽을 보게 맞춘다.
- 운석 시트: 열 0 = 멀쩡함, 1·2 = 금 간 단계. 깨지는 애니메이션은 따로 (*_boom.png, 돌리지 않음).
  중간 운석은 팩 Asteroid 01 그대로, 작은·큰 운석은 Codex 그림(assets/sprites/run/rock_*_base.png)에서
  금과 깨지는 프레임을 팩 운석과 같은 색·순서로 만든다 (금 → 용암빛 → 조각이 흩어지며 사라짐).
- 탄에 맞은 순간 보여 줄 흰 실루엣(*_white.png)도 만든다.
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


def whiten(img: Image.Image) -> Image.Image:
    """맞았을 때 잠깐 보여 주는 흰 실루엣 (같은 모양, 불투명한 곳만 흰색)."""
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(img.getchannel("A"))
    return out


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
            for x, y in pts:
                for dx, dy in ((1, 0), (0, 1)):
                    q = (x + dx, y + dy)
                    if q in solid and q not in pts and rng.random() < 0.5:
                        img.putpixel(q, (LAVA[2] if rng.random() < 0.7 else LAVA[3]) + (255,))
        out.append(img)
    return out


def explode_frames(base: Image.Image, cell: int, seed: int, count: int = 8) -> list[Image.Image]:
    """깨지는 애니메이션 count장 (cell 칸 가운데 기준).
    0 멀쩡함 → 1·2 금 → 3~ 조각(보로노이)으로 나뉘어 바깥으로 흩어진다.
    팩 운석처럼 조각마다 바위 머리 뒤로 주황 꼬리가 달리고, 머리는 작아지고 꼬리만 남았다가 사라진다."""
    rng = random.Random(seed)
    cracked = crack_frames(base, seed)
    frames = [center_in(base, cell), center_in(cracked[0], cell), center_in(cracked[1], cell)]
    w, h = base.size
    pieces_n = max(5, min(12, (w * h) // 220))
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
    for f in range(flying):
        t = (f + 1) / flying  # 0 → 1
        img = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        for i, pts in pieces.items():
            if not pts:
                continue
            px = sum(p[0] for p in pts) / len(pts)
            py = sum(p[1] for p in pts) / len(pts)
            d = (px - w / 2.0, py - h / 2.0)
            n = math.hypot(*d) or 1.0
            push = (cell / 2.0 - max(w, h) / 2.0) * t * (0.7 + 0.3 * ((i * 7919) % 10) / 10.0)
            dx, dy = d[0] / n * push, d[1] / n * push
            ux, uy = d[0] / n, d[1] / n
            head = (px + dx, py + dy)

            def put(x: float, y: float, color: tuple) -> None:
                q = (int(round(x)) + off[0], int(round(y)) + off[1])
                if 0 <= q[0] < cell and 0 <= q[1] < cell:
                    img.putpixel(q, color + (255,))

            # 꼬리: 머리에서 가운데 쪽으로 뻗는 주황 줄 (두께 2 → 1, 끝은 노랑). 처음엔 길고 점점 짧아진다
            tail = max(2.0, math.sqrt(len(pts)) * (1.4 - t))
            for s in range(int(tail)):
                k = s / tail
                x, y = head[0] - ux * s, head[1] - uy * s
                color = LAVA[0] if k > 0.7 else (LAVA[1] if k > 0.3 else LAVA[2])
                put(x, y, color)
                if k < 0.5 and t < 0.7:
                    put(x - uy, y + ux, LAVA[2])
            # 머리: 바위 조각이 작아지다 사라진다 (마지막 두 프레임은 꼬리만)
            radius = math.sqrt(len(pts)) * 0.6 * (1.0 - t * 1.4)
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


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    d8 = rotsprite.dir8_sheet
    # 내 우주선: 팩 원본을 60%로 다시 그려 저장 (tools/shrink_ship.py, PLAN 15번). 큰 원본 시트는 게임에 두지 않는다
    for name, strip in ship_strips().items():
        shrink_ship.shrink_sheet(strip, name).save(f"{OUT}/{name}.png")
    d8(vendor("main_ship/Main ship weapons/PNGs/Main ship weapon - Projectile - Auto cannon bullet.png"), 32, 32).save(f"{OUT}/bullet.png")

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
    # 탄에 맞으면 흰색으로 번쩍이는 것들
    for name in ["rock_0", "rock_1", "rock_2", "rock_gold", "jelly", "bug", "guard"]:
        whiten(Image.open(f"{OUT}/{name}.png")).save(f"{OUT}/{name}_white.png")


if __name__ == "__main__":
    build()
    print("assets/sprites/run/ 다시 만듦")
