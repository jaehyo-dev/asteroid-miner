"""세로(휴대폰) 기지 소행성 지면을 만든다: 기존 지면의 바위 질감을 잘라, 시드로 고정한 울퉁불퉁한 비대칭 윤곽(폭:높이 4:5)에 입힌다.
사용: python3 tools/make_ground.py  (결과: assets/sprites/base/ground_portrait.png)"""
import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 262, 326          # 소행성 윗면 크기 (바위 윤곽으로 깎인 뒤 폭:높이 약 4:5)
CLIFF = 7                # 아래쪽 절벽 두께
CANVAS = (W + 20, H + CLIFF + 20)
SEED = 64


def silhouette(rng):
    """극좌표 반지름에 낮은 차수 + 높은 차수 물결을 섞어 좌우 비대칭 바위 윤곽을 만든다"""
    cw, ch = CANVAS
    yy, xx = np.mgrid[0:ch, 0:cw].astype(float)
    cx, cy = cw / 2 - 3, (ch - CLIFF) / 2
    dx, dy = (xx - cx) / (W / 2), (yy - cy) / (H / 2)
    ang = np.arctan2(dy, dx)
    r = np.hypot(dx, dy)
    # 정원 대신 둥근 사각에 가까운 기본형(슈퍼타원) + 물결
    base = (np.abs(dx) ** 2.6 + np.abs(dy) ** 2.6) ** (1 / 2.6)
    wob = np.zeros_like(ang)
    for k, amp in ((2, .03), (3, .045), (4, .03), (5, .025), (7, .02), (11, .012)):
        wob += amp * np.sin(k * ang + rng.uniform(0, 6.28))
    # 한쪽이 푹 들어가고 한쪽이 튀어나오게 (좌우·위아래 비대칭)
    bite = -0.09 * np.exp(-((ang - 2.5) / 0.35) ** 2) + 0.06 * np.exp(-((ang + 0.6) / 0.4) ** 2)
    rim = base / (1 + wob + bite)
    mask = rim < 0.9
    # 가장자리 바위 덩어리: 잔 노이즈로 한 번 더 울퉁불퉁하게
    noise = ndimage.gaussian_filter(rng.standard_normal((ch, cw)), 2.0)
    mask = (rim + noise * 0.3 * np.clip(rim, 0, 1) ** 4 - 0.9) < 0
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        mask = lab == (1 + int(np.argmax(sizes)))
    return ndimage.binary_fill_holes(mask)


def main():
    rng = np.random.default_rng(SEED)
    src = np.array(Image.open("assets/raw/base/ground_portrait_v064.png").convert("RGBA"))
    cw, ch = CANVAS
    tex = src[70:70 + ch, 50:50 + cw].copy()      # 바위 질감 (분화구·돌 포함)
    mask = silhouette(rng)
    out = np.zeros((ch, cw, 4), np.uint8)
    # 아래 절벽: 윤곽을 아래로 CLIFF칸 밀어 그린 부분 중 윗면이 아닌 곳 (어두운 갈색 + 세로 줄무늬)
    cliff = np.zeros_like(mask)
    for d in range(1, CLIFF + 1):
        cliff |= np.roll(mask, d, axis=0)
    cliff &= ~mask
    shade = 0.42 - 0.2 * (rng.random((1, cw)) > 0.6)
    out[cliff] = np.concatenate([(tex[..., :3] * shade[..., None]).astype(np.uint8)[cliff], np.full((cliff.sum(), 1), 255, np.uint8)], 1)
    out[mask] = tex[mask]
    # 윗면 가장자리: 안쪽 2칸 어둡게, 위쪽 모서리는 밝게 (빛이 왼쪽 위)
    edge = mask & ~ndimage.binary_erosion(mask, iterations=2)
    lit = mask & ~np.roll(mask, 1, axis=0) | (mask & ~np.roll(mask, 1, axis=1))
    out[edge, :3] = (out[edge, :3] * 0.7).astype(np.uint8)
    out[lit & edge, :3] = np.clip(out[lit & edge, :3] * 1.35, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(mask | cliff, 255, 0)
    img = Image.fromarray(out)
    # 다른 기지 그림처럼 디더링 없이 색을 줄인다 (자동 테스트: 40색 이하, 반투명 없음)
    q = img.convert("RGB").quantize(36, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    img = Image.merge("RGBA", (*q.split(), img.split()[3]))
    img.save("assets/sprites/base/ground_portrait.png")
    print("size", CANVAS, "mask", mask.sum(), "bbox", Image.fromarray(out).getbbox())


if __name__ == "__main__":
    main()
