"""연구소 강화 소리 후보: 강화 성공 3개(카드 선택 e3와 같은 zer0_sol 권총 녹음의 다른 구간), 만렙 꼬리 3개, 광물 부족 "툭" 1개.
만렙은 게임에서 강화 소리 + 꼬리(칸이 하얗게 번쩍이는 순간)로 겹쳐 낸다.
실행: 저장소 맨 위에서 python3 review/v070_fix/listen5/make_listen5.py → 여기 *.ogg, measure.md, assets/sfx/game/upgrade_*.wav, deny.wav"""
import sys

import numpy as np

sys.path[:0] = ["tools", "review/v070_fix/listen", "review/v070_fix/listen3", "review/v070_fix/listen4"]
from make_listen import E3_PATH, RELOAD, env, eq, gain, rec, stats  # noqa: E402
from make_listen3 import loud  # noqa: E402
from make_listen4 import soft  # noqa: E402
from make_sfx import SR, decode, mix_st, peak, room, save, silence, stereo  # noqa: E402

HERE = "review/v070_fix/listen5/"
GAME = "assets/sfx/game/"
E3_DB, UP_DB, TAIL_DB, DENY_DB, CLICK_DB = -10.0, -5.0, -6.0, -10.0, -8.0  # sfx.gd 재생 크기
UP_MAX = 0.22  # e3(0.39초)보다 짧게
E3_FROM, E3_TO = 1.031, 1.42  # e3가 쓰는 구간: 겹치지 않는다


def cut(t0, t1, p=1.0, fade=0.03):
    """권총 녹음 조각을 e3와 같은 음색 처리로"""
    assert t1 <= E3_FROM or t0 >= E3_FROM + 0.14, ("e3 앞부분(당기는 척)과 겹침", t0, t1)
    return eq(rec(RELOAD, t0, t1, p, fade=fade))


def fit(a, total):
    out = a[:int(total * SR)].copy()
    k = int(0.02 * SR)
    out[-k:] *= np.linspace(1, 0, k)[:, None]
    return out


def up_1():
    """1 탄창 "착-칵": 탄창이 끝까지 들어가 걸리는 두 번 소리"""
    return fit(room(stereo(cut(0.638, 0.80)), 0.08, 0.08, 301), 0.2)


def up_2():
    """2 슬라이드 놓음 "컥": e3의 끝 소리만, 살짝 높여 가볍게 (당기는 척 없이 한 번)"""
    return fit(room(stereo(cut(1.175, 1.34, 1.1)), 0.08, 0.08, 302), 0.18)


def up_3():
    """3 걸쇠 "틱-착": 탄창 멈치 누르는 작은 소리 → 탄창 첫 소리"""
    a = cut(0.09, 0.15, fade=0.01)
    b = cut(0.592, 0.645, fade=0.015)
    return fit(room(mix_st([(0.0, stereo(a * 0.6, -0.15)), (0.06, stereo(b, 0.1))]), 0.08, 0.08, 303), 0.16)


BELL0 = "kenney_impact/impactBell_heavy_000.ogg"
BELL1 = "kenney_impact/impactBell_heavy_001.ogg"


def tail_1():
    """1 묵직한 쇠종: 낮게 내린 종 하나가 길게"""
    a = rec(BELL0, 0.0, 1.3, 1.1, fade=0.4, band="highpass=f=200,lowpass=f=3200")
    return room(stereo(env(a, 0.01, 1.4)), 0.6, 0.25, 311)


def tail_2():
    """2 카드 레전드리 울림과 같은 재료: 두 종이 좌우로"""
    a = rec(BELL0, 0.0, 1.2, 1.6, fade=0.3, band="highpass=f=300,lowpass=f=3800")
    b = rec(BELL1, 0.0, 1.2, 2.4, fade=0.3, band="highpass=f=500,lowpass=f=4500")
    return room(mix_st([(0.0, stereo(env(a, 0.012, 1.1) * 0.6, -0.25)), (0.03, stereo(env(b, 0.02, 1.0) * 0.45, 0.25))]), 0.7, 0.3, 312)


def tail_3():
    """3 금속판 "쿵" + 짧은 쇠 울림: 무거운 판이 맞물리는 느낌"""
    thud = rec("kenney_impact/impactPlate_medium_000.ogg", 0.0, 0.4, 0.7, fade=0.15, band="lowpass=f=2500")
    a = rec(BELL0, 0.0, 0.9, 1.3, fade=0.3, band="highpass=f=250,lowpass=f=3500")
    return room(mix_st([(0.0, stereo(thud * 0.8)), (0.01, stereo(env(a, 0.01, 2.2) * 0.55))]), 0.5, 0.22, 313)


def deny():
    """광물 부족: 버튼 소리 1번을 낮고 둔하게 "툭" """
    a = soft(0.62)
    return stereo(a / max(float(np.abs(a).max()), 1e-9))


def level(a, target, play_db):
    return a * min(gain(target - play_db - loud(a)), gain(-1.0) / float(np.abs(a).max()))


UPS = [("탄창 착-칵", up_1), ("슬라이드 놓음 컥", up_2), ("걸쇠 틱-착", up_3)]
TAILS = [("묵직한 쇠종", tail_1), ("레전드리 두 종", tail_2), ("금속판 쿵 + 울림", tail_3)]


def main():
    e3 = decode(E3_PATH)
    e3_game = loud(e3) + E3_DB
    click = decode(GAME + "click.wav")
    rows = []
    ups = []
    for n, (name, fn) in enumerate(UPS, 1):
        a = level(fn(), e3_game - 2.0, UP_DB)  # e3보다 2dB 작게
        assert len(a) / SR <= UP_MAX + 1e-3, (name, len(a) / SR)
        assert stats(a)["hi"] < 3.0, name
        ups.append(a)
        save(a, f"{GAME}upgrade_{n}.wav")
        save(a, f"{HERE}upgrade_{n}.ogg", quality=6)
        rows.append(f"| 강화 {n} {name} | {len(a) / SR:.2f}초 | {stats(a)['c']:.0f}Hz | {loud(a) + UP_DB:.1f}dB |")
    for n, (name, fn) in enumerate(TAILS, 1):
        a = level(fn(), e3_game + 1.0, TAIL_DB)  # 강화 소리 위에 얹어 e3보다 크게 들림
        save(a, f"{GAME}upgrade_max_{n}.wav")
        save(a, f"{HERE}max_tail_{n}.ogg", quality=6)
        # 들어 보기: 강화 2번 → 만렙(강화 1~3 + 이 꼬리, 꼬리는 번쩍임에 맞춰 0.35초 뒤)
        demo = [ups[0] * gain(UP_DB), stereo(silence(0.4)), ups[0] * gain(UP_DB), stereo(silence(0.4))]
        for u in ups:
            demo += [mix_st([(0.0, u * gain(UP_DB + 2.0)), (0.35, a * gain(TAIL_DB))]), stereo(silence(0.5))]
        save(peak(np.concatenate(demo), -1.0), f"{HERE}max_{n}_demo.ogg", quality=5)
        rows.append(f"| 만렙 꼬리 {n} {name} | {len(a) / SR:.2f}초 | {stats(a)['c']:.0f}Hz | {loud(a) + TAIL_DB:.1f}dB |")
    d = level(deny(), loud(click) + CLICK_DB - 1.0, DENY_DB)  # 버튼 소리보다 조금 작게
    assert stats(d)["c"] < stats(click)["c"], "툭은 버튼 소리보다 낮게"
    save(d, f"{GAME}deny.wav")
    save(d, f"{HERE}deny.ogg", quality=6)
    rows.append(f"| 광물 부족 툭 | {len(d) / SR:.2f}초 | {stats(d)['c']:.0f}Hz | {loud(d) + DENY_DB:.1f}dB |")
    for n, u in enumerate(ups, 1):  # 연타: 강화 6번
        seq = []
        for _ in range(6):
            seq += [u, stereo(silence(0.12))]
        save(np.concatenate(seq), f"{HERE}upgrade_{n}_rapid.ogg", quality=5)
    table = "\n".join(["| 소리 | 길이 | 무게중심 | 게임 크기(가장 큰 50ms) |", "|---|---|---|---|", *rows])
    table += f"\n\n비교: 카드 선택 e3 {len(e3) / SR:.2f}초, {stats(e3)['c']:.0f}Hz, {e3_game:.1f}dB. 버튼 소리 1번 {stats(click)['c']:.0f}Hz, {loud(click) + CLICK_DB:.1f}dB."
    print(table)
    with open(HERE + "measure.md", "w") as f:
        f.write("# 측정값 (make_listen5.py가 만듦, 귀로 듣지 못함)\n\n" + table + "\n")


if __name__ == "__main__":
    main()
