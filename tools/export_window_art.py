"""건물 창 그림을 시안 원본(assets/raw/base_panel*)에서 게임 부품으로 뽑는다. 색 바꾸기·빛 번짐·더미는 여기서 미리 구워 게임은 그리기만 한다.
실행: 저장소 맨 위에서 python3 tools/export_window_art.py → assets/sprites/window/"""
import os
import sys

import numpy as np
from PIL import Image

sys.path[:0] = ["review/v070_fix3/research_pipes"]
import make_pipes as mp  # noqa: E402

m2, mm, m3 = mp.m2, mp.mm, mp.mt.m3
OUT = "assets/sprites/window/"
BRANCHES = ["weapon", "hull", "mine", "elec", "survey"]
# 칸 id → 아이콘 이름 (기존 6칸은 node_icons 번호)
NODE_ICONS = {"sub": "launcher", "over": "overload", "repair": "repair", "drill": "drill", "shield": "shield", "reroll": "reroll", "luck": "luck", "appraise": "appraise", "radar": "radar", "planet": "planet",
              "rapid": "gatling", "heavy": "heavy", "thick": "thick", "dodge": "dodge", "wide": "wide", "fast": "fast", "chip": "chip", "bolt": "bolt", "deep": "deep", "wide_scan": "wide_scan"}
PILE_COUNTS = [1, 3, 6, 12, 30, 80, 200, 500, 1000]  # Balance.TANK_PILE_COUNTS와 같게


def save(im, name):
    im.save(f"{OUT}{name}.png")


def glow(im, reach=2):
    """윤곽을 따라 번지는 빛 (흰색, 알파 단계만). 게임에서 색을 곱한다. 원본보다 reach+1칸 넓다"""
    mask = im.getchannel("A").point(lambda v: 255 if v else 0)
    pad = reach + 1
    base = Image.new("L", (im.width + 2 * pad, im.height + 2 * pad), 0)
    base.paste(mask, (pad, pad))
    out = Image.new("RGBA", base.size, (255, 255, 255, 0))
    from PIL import ImageFilter
    for i in range(reach, 0, -1):
        grown = base
        for _ in range(i):
            grown = grown.filter(ImageFilter.MaxFilter(3))
        out.paste((255, 255, 255, 110 if i == 1 else 50), (0, 0), grown)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    p = m2.load_parts2()
    p["pedestal35"] = m3.load_pedestal(p)
    for name in ("frame", "head", "btn", "btn_down", "btn_off", "close", "tab", "lock", "socket_off", "tank", "vault", "crate_s"):
        save(p[name], name)
    for b in BRANCHES:
        on = m2.rim(p["socket_on"], b)
        save(on, f"socket_on_{b}")
        save(m2.darken(on, 0.6), f"socket_idle_{b}")
        save(p["emblem"][b], f"emblem_{b}")
    plan = m2.darken(m2.tint(p["socket_lock"], {mm.TEAL: "#5c5164", mm.TEAL2: "#5c5164", "#1da775": "#5c5164", "#125952": "#3c3544"}), 0.8)
    save(plan, "socket_plan")
    save(glow(p["socket_on"]), "glow_on")
    save(glow(p["socket_off"]), "glow_off")
    save(glow(plan), "glow_plan")
    for nid, i in mm.NODE_ICON.items():
        save(p["node_icons"][i], f"icon_{nid}")
    for nid, ic in NODE_ICONS.items():
        save(p["ic"][ic], f"icon_{nid}")
    save(p["ic"]["w_pulse"], "weapon_pulse")
    for kid, (_, i) in mm.BUILD.items():
        save(p["build_icons"][i], f"build_{kid}")
    # 전시관: 등급 틀 + 징·뿔을 함께 구움 (사방 3칸 여백)
    c = mm.Ctx(p, "pc")
    for rank in m2.RANKS:
        case = m2.case_for(c, rank)
        out = Image.new("RGBA", (case.width + 6, case.height + 6), (0, 0, 0, 0))
        m2.case_deco(mm.draw(out), 3, 3, case.width, case.height, rank)
        out.alpha_composite(case, (3, 3))
        save(out, f"case_{rank}")
    save(m3.dark_case(p), "case_off")
    # 격납고: 받침, 회전 시트(눕힌 우주선 35도), 함께 도는 그림자
    ped = p["pedestal35"].convert("RGBA")
    px = ped.load()
    for yy in range(ped.height):
        for xx in range(ped.width):
            if px[xx, yy] == (*bytes.fromhex("30e1b9"), 255):
                px[xx, yy] = (*bytes.fromhex("1da775"), 255)  # 윗면 고리를 빛기둥과 같은 톤으로 은은하게
    save(ped, "pedestal")
    Image.open("review/v070_fix3/spin3d/spin_e35.png").convert("RGBA").save(f"{OUT}spin.png")
    shadows = Image.new("RGBA", (64 * 8, 56 * 5), (0, 0, 0, 0))
    for j in range(40):
        s = m3.ship_shadow(35, j * 3)
        shadows.alpha_composite(s, (j % 8 * 64 + (64 - s.width) // 2, j // 8 * 56 + (56 - s.height) // 2))
    shadows.save(f"{OUT}spin_shadow.png")
    # 금고: 등급·개수별 더미
    tw, th = p["tank"].size
    ix0, ix1, iy0, iy1 = int(tw * 0.17), int(tw * 0.84), int(th * 0.26), int(th * 0.86)
    print("탱크", tw, th, "안쪽", ix0, iy0, ix1 - ix0, iy1 - iy0)
    for g in range(4):
        sheet = Image.new("RGBA", ((ix1 - ix0) * len(PILE_COUNTS), iy1 - iy0), (0, 0, 0, 0))
        for k, n in enumerate(PILE_COUNTS):
            sheet.alpha_composite(m2.pile(ix1 - ix0, iy1 - iy0, g, n), (k * (ix1 - ix0), 0))
        save(sheet, f"pile_{g}")
    # 드론 공장: 파란 설계도 선
    save(mm.outline_only(mm.sprite("assets/sprites/station/b_drone.png"), "#4d80cd"), "blueprint")
    save(mp.ATLAS, "pipes")
    # 드론 공장 표지판: 꺼진 버튼의 회색 면을 금색으로
    a = np.array(p["btn_off"])
    a[(a[..., :3] == m2.rgb(mm.MUTED)).all(axis=2), :3] = m2.rgb(mm.GOLD)
    save(Image.fromarray(a, "RGBA"), "sign")
    for name in ("frame", "head", "btn", "tab", "close", "vault", "pedestal", "case_off", "socket_off", "socket_plan", "socket_on_hull", "blueprint"):
        print(name, Image.open(f"{OUT}{name}.png").size)


if __name__ == "__main__":
    main()
