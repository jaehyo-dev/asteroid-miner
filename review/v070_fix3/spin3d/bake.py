"""spin.gd를 카메라 각도별로 찍어 회전 시트를 만든다. 저장소 맨 위에서 실행: python3 review/v070_fix3/spin3d/bake.py
spin_e각도.png: 미리 만든 40프레임 + 1픽셀 검은 윤곽. 8칸 x 5줄, 칸 하나 64x56."""
import glob, os, subprocess, tempfile
import numpy as np
from PIL import Image
from scipy import ndimage

H = "review/v070_fix3/spin3d/"
W, T, N = 64, 56, 120
NOSE, BODY = "6", "6"
for elev in (30, 35, 40):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["godot", "--path", H, "--resolution", f"{W * 6}x{T * 6}", "--fixed-fps", "20", "--write-movie", tmp + "/f.png", "--quit-after", str(N + 1), "--", str(elev), NOSE, BODY], check=True, capture_output=True, timeout=120)
        files = sorted(glob.glob(tmp + "/f*.png"))[1:N + 1]
        assert len(files) == N, len(files)
        frames = []
        for f in files[::3]:
            a = np.array(Image.open(f).convert("RGBA"))[3::6, 3::6]  # 6배로 찍은 것을 칸 가운데만 뽑아 되돌림
            c = a[..., :3].astype(int)
            a[(c[..., 0] == 255) & (c[..., 1] == 0) & (c[..., 2] == 255), 3] = 0  # 마젠타 바탕을 투명으로
            edge = ndimage.binary_dilation(a[..., 3] > 0, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & (a[..., 3] == 0)
            a[edge] = (0, 0, 0, 255)
            frames.append(a)
    B = Image.new("RGBA", (W * 8, T * 5), (0, 0, 0, 0))
    for i, a in enumerate(frames):
        B.paste(Image.fromarray(a), (i % 8 * W, i // 8 * T))
    B.save(f"{H}spin_e{elev}.png", optimize=True)
    print(elev, os.path.getsize(f"{H}spin_e{elev}.png"))
