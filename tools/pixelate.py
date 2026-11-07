"""AI 그림 → 진짜 픽셀 아트 정리 도구.

Codex로 만든 그림(부드러운 가장자리, 들쭉날쭉한 픽셀 크기)을 게임에 넣기 전에 항상 이 도구로 정리한다.
1) 배경 지우기: 단색 마젠타(#FF00FF) 배경을 지운다 (--rembg면 rembg isnet-general-use로 지움)
2) 색 줄이기: 디더링 없이 --colors 색으로 (같은 색 덩어리가 깔끔하게 남게 먼저 줄임)
3) 크기 줄이기: nearest로 --width(또는 --scale) 픽셀 격자에 맞춤. 결과 1픽셀 = 게임 화면에서 정수 배율(기지 화면 3배)
4) 투명도는 0 또는 255만 (반투명 가장자리 없음)
--split이면 가로로 늘어놓은 부품 시트를 빈 세로줄 기준으로 잘라 이름_1.png, 이름_2.png …로 저장한다.
--height가 있으면 배경 그림처럼 그 크기를 위쪽 기준으로 꽉 채운다 (넘치는 아래·양옆은 잘라냄).

사용 예:
  python3 tools/pixelate.py assets/raw/base/hangar.png assets/sprites/base/hangar.png --width 120
  python3 tools/pixelate.py assets/raw/base/piles.png assets/sprites/base/pile.png --scale 0.06 --split
  python3 tools/pixelate.py assets/raw/base/ground_landscape.png assets/sprites/base/ground_landscape.png --width 520 --height 240 --no-key
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageFilter

MAGENTA = (255, 0, 255)
## 배경색과 이만큼(RGB 거리 제곱) 가까우면 배경으로 본다
KEY_TOLERANCE = 110 ** 2
## rembg 실행 파일 (지붕 위 고냥이 작업 때 따로 설치한 가상 환경)
REMBG = os.path.expanduser("~/.local/venvs/rembg/bin/rembg")


def is_background(rgb: tuple, key: tuple = MAGENTA) -> bool:
    """배경색(마젠타)이거나 그 언저리의 분홍빛 가장자리인지."""
    r, g, b = rgb[:3]
    near = (r - key[0]) ** 2 + (g - key[1]) ** 2 + (b - key[2]) ** 2 <= KEY_TOLERANCE
    # 마젠타가 섞인 가장자리: 빨강·파랑이 초록보다 확실히 큼
    fringe = r > 150 and b > 150 and g < min(r, b) - 70
    return near or fringe


def remove_key(img: Image.Image, key: tuple = MAGENTA) -> Image.Image:
    """단색 배경을 투명하게."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if is_background(px[x, y], key):
                px[x, y] = (0, 0, 0, 0)
    return img


def remove_rembg(path: str) -> Image.Image:
    """rembg(isnet-general-use)로 배경을 지운다. 마젠타 빼기가 깔끔하지 않은 그림에만 쓴다."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out.png")
        subprocess.run([REMBG, "i", "-m", "isnet-general-use", path, out], check=True, capture_output=True)
        return Image.open(out).convert("RGBA")


def crop_to_content(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
    return img.crop(box) if box else img


def keep_main_component(img: Image.Image, gap: int = 12) -> Image.Image:
    """가장 큰 덩어리만 남긴다 (gap 픽셀 안쪽으로 붙어 있으면 한 덩어리). 잘라 온 그림 가장자리에 걸린 배관 조각·옆 물건을 지울 때 쓴다."""
    step = 4
    small = img.getchannel("A").point(lambda a: 255 if a >= 128 else 0).resize(
        (max(1, img.width // step), max(1, img.height // step)), Image.Resampling.BOX).point(lambda a: 255 if a else 0)
    k = max(1, gap // step) * 2 + 1
    grown = small.filter(ImageFilter.MaxFilter(k if k % 2 else k + 1))
    w, h = grown.size
    px = grown.load()
    label = [[0] * w for _ in range(h)]
    sizes = {}
    n = 0
    for y0 in range(h):
        for x0 in range(w):
            if px[x0, y0] and not label[y0][x0]:
                n += 1
                stack = [(x0, y0)]
                label[y0][x0] = n
                count = 0
                while stack:
                    x, y = stack.pop()
                    count += 1
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not label[ny][nx]:
                            label[ny][nx] = n
                            stack.append((nx, ny))
                sizes[n] = count
    if not sizes:
        return img
    best = max(sizes, key=sizes.get)
    mask = Image.new("L", (w, h))
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            mp[x, y] = 255 if label[y][x] == best else 0
    mask = mask.resize(img.size, Image.Resampling.NEAREST)
    out = img.copy()
    alpha = ImageChops.multiply(img.getchannel("A"), mask)
    out.putalpha(alpha)
    return out


def split_columns(img: Image.Image, min_gap: int = 8) -> list[Image.Image]:
    """가로로 늘어놓은 부품을 빈 세로줄(min_gap줄 이상) 기준으로 나눈다. 왼쪽부터."""
    alpha = img.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    w, h = img.size
    filled = [alpha.crop((x, 0, x + 1, h)).getbbox() is not None for x in range(w)]
    parts, start, gap = [], None, 0
    for x, f in enumerate(filled + [False] * min_gap):
        if f:
            if start is None:
                start = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                parts.append(crop_to_content(img.crop((start, 0, x - gap + 1, h))))
                start, gap = None, 0
    return parts


def reduce_colors(img: Image.Image, colors: int) -> Image.Image:
    """디더링 없이 색 수를 줄인다. 투명한 곳은 투명하게 둔다."""
    alpha = img.getchannel("A")
    rgb = img.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def binarize_alpha(img: Image.Image) -> Image.Image:
    """반투명 없이 0 또는 255만."""
    img = img.copy()
    img.putalpha(img.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return img


def pixelate(img: Image.Image, width: int | None = None, scale: float | None = None,
             height: int | None = None, colors: int = 24) -> Image.Image:
    """색을 줄이고 nearest로 격자 크기에 맞춘다. height가 있으면 위쪽 기준으로 꽉 채워 자른다."""
    img = reduce_colors(img.convert("RGBA"), colors)
    if height is not None and width is not None:
        # 배경: 목표 비율이 되도록 원본을 위쪽 기준으로 잘라 낸 뒤 줄인다 (가로는 가운데, 세로는 위)
        target = width / height
        w, h = img.size
        if w / h > target:
            new_w = round(h * target)
            img = img.crop(((w - new_w) // 2, 0, (w - new_w) // 2 + new_w, h))
        else:
            img = img.crop((0, 0, w, round(w / target)))
        size = (width, height)
    elif width is not None:
        size = (width, max(1, round(img.height * width / img.width)))
    elif scale is not None:
        size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    else:
        raise ValueError("width 또는 scale이 필요함")
    return binarize_alpha(img.resize(size, Image.Resampling.NEAREST))


def count_colors(img: Image.Image) -> int:
    """불투명한 픽셀의 색 수 (테스트·확인용)."""
    seen = set()
    for r, g, b, a in img.convert("RGBA").getdata():
        if a:
            seen.add((r, g, b))
    return len(seen)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--width", type=int)
    p.add_argument("--height", type=int)
    p.add_argument("--scale", type=float)
    p.add_argument("--colors", type=int, default=24)
    p.add_argument("--no-key", action="store_true", help="배경을 지우지 않음 (배경 그림)")
    p.add_argument("--rembg", action="store_true", help="마젠타 대신 rembg로 배경을 지움")
    p.add_argument("--main-only", action="store_true", help="가장 큰 덩어리만 남김 (잘라 온 그림의 옆 조각 지우기)")
    p.add_argument("--split", action="store_true", help="가로로 늘어놓은 부품을 나눠 이름_번호.png로 저장")
    args = p.parse_args(argv)

    if args.no_key:
        img = Image.open(args.src).convert("RGBA")
    elif args.rembg:
        img = binarize_alpha(remove_rembg(args.src))
        if args.main_only:
            img = binarize_alpha(keep_main_component(img))
        img = crop_to_content(img)
    else:
        img = crop_to_content(remove_key(Image.open(args.src)))
    os.makedirs(os.path.dirname(args.dst) or ".", exist_ok=True)
    if args.split:
        stem, ext = os.path.splitext(args.dst)
        parts = split_columns(img)
        for i, part in enumerate(parts, 1):
            pixelate(part, args.width, args.scale, None, args.colors).save(f"{stem}_{i}{ext}")
        print(f"{args.dst}: 부품 {len(parts)}개")
    else:
        out = pixelate(img, args.width, args.scale, args.height, args.colors)
        out.save(args.dst)
        print(f"{args.dst}: {out.width}x{out.height}, {count_colors(out)}색")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
