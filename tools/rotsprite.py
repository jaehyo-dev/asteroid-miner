"""RotSprite 방식으로 픽셀 그림을 8방향(45도씩)으로 미리 돌리는 도구.

게임 화면에서 소수 각도로 돌리면 픽셀이 찌그러지므로, 돌린 그림을 미리 만들어 두고 돌리지 않고 그린다.
RotSprite: Scale2x를 3번(8배) 해서 모서리를 매끄럽게 만든 뒤, 돌린 결과를 원래 크기로 nearest 샘플링한다.
새 색을 만들지 않으므로(원래 그림의 색만 씀) 팔레트가 그대로 유지된다.
- 90도 배수는 정확히 돌린다 (픽셀 그대로).
- 45도 방향은 45도 그림 하나를 만들고 그것을 90도씩 돌려 4개 모두 같은 모양이 되게 한다.

시트 형식: 입력은 가로로 늘어놓은 프레임(frame_w x frame_h), 출력은 열 = 프레임, 행 = 방향(0 = 원래 방향, 시계 방향으로 45도씩).
칸 크기는 입력 프레임과 같고 칸 가운데를 기준으로 돈다 (그림이 칸 가운데 근처에 있어야 잘리지 않음).

사용 예:
  python3 tools/rotsprite.py 입력.png 출력.png --frame 48x48
"""

from __future__ import annotations

import argparse
import math
import sys

import numpy as np
from PIL import Image


def _pack(img: Image.Image) -> np.ndarray:
    """RGBA 그림을 픽셀 하나 = uint32 하나인 배열로 (색 비교를 한 번에 하려고)."""
    a = np.asarray(img.convert("RGBA"), dtype=np.uint32)
    return (a[..., 0] << 24) | (a[..., 1] << 16) | (a[..., 2] << 8) | a[..., 3]


def _unpack(p: np.ndarray) -> Image.Image:
    a = np.stack([(p >> 24) & 255, (p >> 16) & 255, (p >> 8) & 255, p & 255], axis=-1).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def scale2x(p: np.ndarray) -> np.ndarray:
    """Scale2x(EPX): 대각선 모서리만 매끄럽게 2배 확대. 새 색은 만들지 않는다."""
    pad = np.pad(p, 1, mode="edge")
    e = pad[1:-1, 1:-1]
    a = pad[:-2, 1:-1]  # 위
    b = pad[1:-1, 2:]  # 오른쪽
    c = pad[1:-1, :-2]  # 왼쪽
    d = pad[2:, 1:-1]  # 아래
    h, w = p.shape
    out = np.empty((h * 2, w * 2), dtype=p.dtype)
    out[0::2, 0::2] = np.where((c == a) & (c != d) & (a != b), a, e)
    out[0::2, 1::2] = np.where((a == b) & (a != c) & (b != d), b, e)
    out[1::2, 0::2] = np.where((d == c) & (d != b) & (c != a), c, e)
    out[1::2, 1::2] = np.where((b == d) & (b != a) & (d != c), d, e)
    return out


def rotsprite(img: Image.Image, degrees: float) -> Image.Image:
    """그림을 시계 방향으로 degrees만큼 돌린다 (크기 그대로, 가운데 기준)."""
    big = scale2x(scale2x(scale2x(_pack(img))))
    h, w = img.height, img.width
    t = math.radians(degrees)
    ys, xs = np.mgrid[0:h, 0:w]
    # 결과 픽셀 가운데를 거꾸로 돌려 8배 그림에서 찾는다 (y가 아래로 커지는 좌표에서 +각도 = 시계 방향)
    dx = xs + 0.5 - w / 2.0
    dy = ys + 0.5 - h / 2.0
    sx = dx * math.cos(-t) - dy * math.sin(-t) + w / 2.0
    sy = dx * math.sin(-t) + dy * math.cos(-t) + h / 2.0
    bx = np.floor(sx * 8).astype(int)
    by = np.floor(sy * 8).astype(int)
    inside = (bx >= 0) & (by >= 0) & (bx < w * 8) & (by < h * 8)
    out = np.zeros((h, w), dtype=np.uint32)
    out[inside] = big[by[inside], bx[inside]]
    return _unpack(out)


def rotate_dir(img: Image.Image, direction: int, diagonal: Image.Image | None = None) -> Image.Image:
    """8방향 번호(0~7, 시계 방향 45도씩)로 돌린 그림. diagonal은 미리 만든(손으로 다듬은) 45도 그림."""
    direction %= 8
    base = img if direction % 2 == 0 else (diagonal if diagonal is not None else rotsprite(img, 45.0))
    # PIL의 ROTATE_270 = 반시계 270도 = 시계 90도
    for _ in range(direction // 2):
        base = base.transpose(Image.Transpose.ROTATE_270)
    return base


def dir8_sheet(sheet: Image.Image, frame_w: int, frame_h: int, turn180: bool = False) -> Image.Image:
    """프레임 시트를 8방향 시트로 (열 = 프레임, 행 = 방향). turn180이면 먼저 뒤집어 위쪽을 보게 한다 (적 그림은 아래를 봄)."""
    if frame_w != frame_h:
        raise ValueError("8방향으로 돌릴 칸은 정사각형이어야 함")
    sheet = sheet.convert("RGBA")
    frames = sheet.width // frame_w
    out = Image.new("RGBA", (frame_w * frames, frame_h * 8), (0, 0, 0, 0))
    for f in range(frames):
        frame = sheet.crop((f * frame_w, 0, (f + 1) * frame_w, frame_h))
        if turn180:
            frame = frame.transpose(Image.Transpose.ROTATE_180)
        diagonal = rotsprite(frame, 45.0)
        for d in range(8):
            out.paste(rotate_dir(frame, d, diagonal), (f * frame_w, d * frame_h))
    return out


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--frame", required=True, help="프레임 크기 예: 48x48")
    p.add_argument("--turn180", action="store_true", help="아래를 보는 그림을 먼저 뒤집음")
    args = p.parse_args(argv)
    fw, fh = (int(v) for v in args.frame.split("x"))
    dir8_sheet(Image.open(args.src), fw, fh, args.turn180).save(args.dst)
    print(f"{args.dst}: 8방향 시트")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
