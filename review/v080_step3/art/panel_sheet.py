"""in_panel/<무기>_<번호>.png(격납고 PC 1280x720 캡처)에서 오른쪽 설명 칸 윗부분만 잘라 무기별 한 줄로 모은다 → panel_sheet.png
실행(저장소 맨 위): python3 review/v080_step3/art/panel_sheet.py"""
from PIL import Image

BOX = (900, 95, 1238, 345)  # 설명 칸: 이름·그림·4칸 막대
D = "review/v080_step3/art/"
w, h = BOX[2] - BOX[0], BOX[3] - BOX[1]
sheet = Image.new("RGB", (w * 3 + 20, h * 4 + 30), (0x14, 0x11, 0x1c))
for r, wid in enumerate(["shotgun", "rail", "plasma", "beam"]):
    for c in range(3):
        im = Image.open(f"{D}in_panel/{wid}_{c + 1}.png").convert("RGB").crop(BOX)
        sheet.paste(im, (c * (w + 10), r * (h + 10)))
sheet.save(D + "panel_sheet.png")
print("ok")
