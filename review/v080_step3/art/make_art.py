"""v0.8.0 3단계 무기 그림 후보: Codex 시트(assets/raw/weapons_v080/<무기>.png, 3개씩 가로) → 36x17 후보 12장 + 비교 시트.
tools/pixelate.py 함수로 정리한다(마젠타 빼기, 디더링 없이 색 줄이기, nearest, 투명도 0/255, 기존 무기 그림 팔레트로 맞춤).
실행(저장소 맨 위): python3 review/v080_step3/art/make_art.py → review/v080_step3/art/cand/<무기>_<번호>.png, sheet.png"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "tools")
import pixelate as px  # noqa: E402

W, H = 36, 17
OUT = "review/v080_step3/art/"
WEAPONS = ["shotgun", "rail", "plasma", "beam"]
NAMES = {"pulse": "펄스 연사포", "shotgun": "산탄포", "rail": "레일건", "plasma": "플라스마 대포", "beam": "채굴 빔"}
# 팔레트: 지금 무기 그림 5장의 색 + 금·주황 (펄스 연사포와 같은 팔레트로 맞춘다)
PAL = set()
for n in ["pulse", "shotgun", "rail", "plasma", "beam"]:
    PAL |= {c[:3] for c in Image.open(f"assets/sprites/window/weapon_{n}.png").convert("RGBA").getdata() if c[3]}
PAL |= {(0xf6, 0xce, 0x50), (0xf8, 0x94, 0x19), (0xdc, 0x7f, 0x47)}
PAL = sorted(PAL)
OUTLINE = (0x2b, 0x19, 0x25)


def mode_down(img: Image.Image, k: float) -> Image.Image:
    """칸마다 가장 많은 색(투명 포함)으로 줄인다: nearest는 선이 끊기고, BOX는 섞인 색 점이 생겨서."""
    w, h = max(1, round(img.width * k)), max(1, round(img.height * k))
    src = img.load()
    out = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            count = {}
            for sy in range(int(y / k), max(int(y / k) + 1, int((y + 1) / k))):
                for sx in range(int(x / k), max(int(x / k) + 1, int((x + 1) / k))):
                    c = src[min(sx, img.width - 1), min(sy, img.height - 1)]
                    c = c if c[3] else (0, 0, 0, 0)
                    count[c] = count.get(c, 0) + 1
            out.putpixel((x, y), max(count, key=count.get))
    return out


def fit(img: Image.Image) -> Image.Image:
    """그림을 36x17 안에 꽉 차게 줄이고(비율 유지, nearest) 팔레트로 맞춘 뒤 가운데 아래쪽 정렬로 놓는다."""
    img = px.crop_to_content(img)
    k = min((W - 1) / img.width, (H - 1) / img.height)
    small = mode_down(px.binarize_alpha(px.map_to_palette(px.reduce_colors(img, 32), PAL)), k)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(small, ((W - small.width) // 2, (H - small.height) // 2), small)
    return canvas


def main() -> None:
    os.makedirs(OUT + "cand", exist_ok=True)
    cands = {}
    for wid in WEAPONS:
        sheet = px.remove_key(Image.open(f"assets/raw/weapons_v080/{wid}.png").convert("RGBA"))
        parts = px.split_columns(sheet, min_gap=20)
        parts = sorted(parts, key=lambda p: -p.width * p.height)[:3] if len(parts) > 3 else parts
        assert len(parts) == 3, f"{wid}: {len(parts)}개로 잘림"
        cands[wid] = []
        for i, part in enumerate(parts, 1):
            im = fit(part)
            im.save(f"{OUT}cand/{wid}_{i}.png")
            cands[wid].append(im)
    # 비교 시트: 줄마다 [펄스 연사포 | 후보 1 | 후보 2 | 후보 3] (6배, 어두운 판 위)
    z, cell_w, cell_h, left = 6, W * 6 + 40, H * 6 + 44, 150
    font = ImageFont.truetype("assets/fonts/galmuri/Galmuri11.ttf", 24)
    sheet = Image.new("RGB", (left + cell_w * 4, cell_h * 4 + 50), (0x14, 0x11, 0x1c))
    d = ImageDraw.Draw(sheet)
    for c, title in enumerate(["펄스 연사포(기준)", "후보 1", "후보 2", "후보 3"]):
        d.text((left + c * cell_w + 20, 12), title, font=font, fill=(0xfe, 0xf8, 0xe5))
    pulse = Image.open("assets/sprites/window/weapon_pulse.png").convert("RGBA")
    for r, wid in enumerate(WEAPONS):
        y = 50 + r * cell_h
        d.text((16, y + cell_h // 2 - 14), NAMES[wid], font=font, fill=(0xf6, 0xce, 0x50))
        for c, im in enumerate([pulse] + cands[wid]):
            x = left + c * cell_w + 20
            d.rectangle([x - 6, y + 6, x + W * z + 6, y + H * z + 18], fill=(0x2b, 0x19, 0x25))
            big = im.resize((W * z, H * z), Image.NEAREST)
            sheet.paste(big, (x, y + 12), big)
    sheet.save(OUT + "sheet.png")
    print("ok", OUT + "sheet.png")


if __name__ == "__main__":
    main()
