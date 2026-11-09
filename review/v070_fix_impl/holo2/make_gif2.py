"""빛기둥 2차: 진하기 3단계(옅게·보통·진하게) 비교 GIF와 정지 캡처.
프레임: godot --path . --resolution 1280x720 -s res://review/v070_fix_impl/holo/shoot_holo.gd -- pc 0  (pc·phone × 0·1·2)
실행: python3 review/v070_fix_impl/holo2/make_gif2.py"""
import os

from PIL import Image

D = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/소행성 광부/holo/")
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
NAMES = ["옅게", "보통", "진하게"]
SCALE = 2  # 창 배율: 캡처를 논리 화소로 줄인다
CROP = {"pc": (150, 30, 474, 300), "phone": (118, 18, 292, 168)}  # 논리 화소에서 받침 무대만


def frames(tag, style):
    d = f"{D}{tag}_s{style}/"
    out = []
    for f in sorted(os.listdir(d)):
        im = Image.open(d + f).convert("RGB")
        out.append(im.resize((im.width // SCALE, im.height // SCALE), Image.NEAREST))
    return out


def gif(ims, path):
    pal = ims[0].quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE)
    q = [f.quantize(palette=pal, dither=Image.NONE) for f in ims]
    q[0].save(path, save_all=True, append_images=q[1:], duration=75, loop=0, disposal=1)


for tag in ("pc", "phone"):
    sets = [frames(tag, s) for s in range(3)]
    for s, fr in enumerate(sets):
        fr[0].resize((fr[0].width * SCALE, fr[0].height * SCALE), Image.NEAREST).save(f"{OUT}still_{tag}_{s + 1}_{NAMES[s]}.png")
        gif(fr, f"{OUT}holo_{tag}_{s + 1}_{NAMES[s]}.gif")
    # 나란히 비교 (무대만, 2배): 왼쪽부터 옅게 → 보통 → 진하게
    box = CROP[tag]
    w, h = box[2] - box[0], box[3] - box[1]
    side = []
    for i in range(len(sets[0])):
        o = Image.new("RGB", (w * 3 + 8, h), (20, 17, 28))
        for s in range(3):
            o.paste(sets[s][i].crop(box), (s * (w + 4), 0))
        side.append(o.resize((o.width * 2, o.height * 2), Image.NEAREST))
    gif(side, f"{OUT}compare_{tag}.gif")
    side[0].save(f"{OUT}compare_{tag}.png")
    print(tag, "ok")
