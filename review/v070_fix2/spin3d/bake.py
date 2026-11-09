"""spin.gd를 Godot Movie Maker로 찍어 시트 2장을 만든다. 저장소 맨 위에서 실행: python3 review/v070_fix2/spin3d/bake.py
spin_a_sheet.png: (a) 실시간 복셀 120프레임 그대로 (시안 합성용). spin_b_sheet.png: (b) 미리 만든 40프레임 + 1픽셀 검은 윤곽 (게임에 넣을 시트 크기 확인용)."""
import glob, os, subprocess, tempfile
import numpy as np
from PIL import Image
from scipy import ndimage

H = "review/v070_fix2/spin3d/"
W, T, N = 64, 56, 120
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["godot", "--path", H, "--resolution", f"{W * 6}x{T * 6}", "--fixed-fps", "20", "--write-movie", tmp + "/f.png", "--quit-after", str(N + 1)], check=True, capture_output=True, timeout=120)
    files = sorted(glob.glob(tmp + "/f*.png"))[1:N + 1]
    assert len(files) == N, len(files)
    frames = []
    for f in files:
        a = np.array(Image.open(f).convert("RGBA"))[3::6, 3::6]  # 6배로 찍은 것을 칸 가운데만 뽑아 되돌림
        c = a[..., :3].astype(int)
        a[(c[..., 0] == 255) & (c[..., 1] == 0) & (c[..., 2] == 255), 3] = 0  # 마젠타 바탕을 투명으로
        frames.append(a)
A = Image.new("RGBA", (W * 12, T * 10), (0, 0, 0, 0))
for i, a in enumerate(frames):
    A.paste(Image.fromarray(a), (i % 12 * W, i // 12 * T))
A.save(H + "spin_a_sheet.png")
B = Image.new("RGBA", (W * 8, T * 5), (0, 0, 0, 0))
for i, a in enumerate(frames[::3]):
    a = a.copy()
    edge = ndimage.binary_dilation(a[..., 3] > 0, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & (a[..., 3] == 0)
    a[edge] = (0, 0, 0, 255)
    B.paste(Image.fromarray(a), (i % 8 * W, i // 8 * T))
B.save(H + "spin_b_sheet.png", optimize=True)
print("a", os.path.getsize(H + "spin_a_sheet.png"), "b", os.path.getsize(H + "spin_b_sheet.png"))
