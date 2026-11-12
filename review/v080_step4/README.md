# v0.8.0 4단계: 보조 무기 6종 확인 자료 (2026-11-12 맥, 브랜치 v0.8.0-weapons)

모든 그림은 웹 빌드를 Playwright headless(Chromium)로 열어 찍었다 (맥에서 Godot 창을 띄우지 않음, CLAUDE.md 규칙). 콘솔 오류 0.

## GIF (`gif/`, 1280x720 = 출격 화면 2배, 5초, 15장/초)

`?fxtest` 촬영 모드(Shift+0)로 우주선 가까이에 운석 6개 + 해파리 2마리를 늘 채우고, 기본 무기는 펄스 연사포.

| 보조 무기 | 1단계 | 5단계 | 볼 점 |
|---|---|---|---|
| 유도 미사일 포드 | [missile_1](gif/missile_1.gif) | [missile_5](gif/missile_5.gif) | 미사일이 휘어 들어가 터짐, 5단계 3발 |
| 블랙홀 발사기 | [blackhole_1](gif/blackhole_1.gif) | [blackhole_5](gif/blackhole_5.gif) | 보라 원 안으로 적·광물이 끌려감 |
| 궤도 톱날 | [saw_1](gif/saw_1.gif) | [saw_5](gif/saw_5.gif) | 1개 → 4개, 사각형으로 움직이며 |
| 기뢰 살포기 | [mine_1](gif/mine_1.gif) | [mine_5](gif/mine_5.gif) | 지나간 자리에 기뢰(빨간 불빛 깜빡임), 닿으면 폭발 |
| 방전 코일 | [coil_1](gif/coil_1.gif) | [coil_5](gif/coil_5.gif) | 번개 2곳 → 5곳 |
| 채굴 펄스 | [wave_1](gif/wave_1.gif) | [wave_5](gif/wave_5.gif) | 금빛 파동 고리, 운석이 금 감 |

- 레일건 [rail_fast](gif/rail_fast.gif): 빠르게 사각형으로 돌며 쏨. 빛줄기가 보이는 시간 0.7초 → 0.25초(굵은 선 약 0.08초 → 점선으로 흩어짐). 프레임마다 레일 색 픽셀을 세어 보면 한 발에 굵은 선 1장 + 점선 1~2장만 남는다.

## 캡처 (`ui/`, PC 1280x720 · 폰 844x390)

| 장면 | PC | 폰 |
|---|---|---|
| 첫 레벨업 (보조 무기 카드 꼭 1장, "보조 무기 0/3") | [cards_new_pc](ui/cards_new_pc.png) | [cards_new_phone](ui/cards_new_phone.png) |
| 칸이 찬 판 (3/3, 가진 보조 무기 강화 카드만, "지금 → 다음") | [cards_full_pc](ui/cards_full_pc.png) | [cards_full_phone](ui/cards_full_phone.png) |
| 판 화면 보조 무기 칸 (레벨 글자 옆, 아이콘 + 단계 점) | [hud_pc](ui/hud_pc.png) | [hud_phone](ui/hud_phone.png) |
| 연구소 "보조 무기 해금" 칸 (800, 3칸 → 4칸) | [research_pc](ui/research_pc.png) | [research_phone](ui/research_phone.png) |

## 봇 측정 ([bot_table.md](bot_table.md))

collector 봇(귀환 안 함), 펄스 연사포, 시드 1~30, 최대 10분, 기지 업그레이드 없음. "보조 무기 우선" = 그 보조 무기 카드가 나오면 항상 고르고, 없으면 보조 무기가 아닌 카드 중 무작위.

| 보조 무기 우선 | 얻은 판 | 평균 최종 단계 | 평균 생존(초) | 처치 수 | 주운 광물(개) |
|---|---|---|---|---|---|
| 보조 무기 안 고름 (기준) | - | - | 222.0 | 233 | 273.8 |
| 유도 미사일 포드 | 67% | 1.7 | 230.6 | 291 | 327.5 |
| 블랙홀 발사기 | 63% | 1.0 | 210.1 | **209 (-23%)** | **231.3 (-26%)** |
| 궤도 톱날 | 63% | 1.2 | 222.6 | **227 (-15%)** | 279.3 |
| 기뢰 살포기 | 60% | 0.9 | 225.1 | 242 | 269.7 |
| 방전 코일 | 70% | 1.3 | 240.5 | **344 (+41%)** | **406.7 (+46%)** |
| 채굴 펄스 | 73% | 1.3 | 222.1 | 251 | 284.5 |

(굵게 = 그 보조 무기를 뺀 나머지 5개 평균보다 15% 넘게 벗어남)

읽는 법과 주의
- 지금 곡선(5분 판)에서는 봇이 3분 40초 안팎에 쓰러져 보조 무기가 평균 1~1.7단계까지밖에 안 오른다. 30판 중 그 보조 무기를 얻은 판도 60~73%. 그래서 이 표는 "1~2단계 보조 무기를 가진 판"의 비교에 가깝다. 5단계 세기는 6단계(10분 곡선) 뒤에 다시 잰다.
- 같은 수치로 두 번 잰 결과(코드 리뷰 반영 전·후)에서 기뢰 살포기가 +30% → 0%, 방전 코일이 +17% → +41%로 크게 흔들렸다(카드 뽑기 난수가 바뀌어 판 흐름이 달라짐). 30판으로는 ±20% 안팎은 잡음일 수 있다. 두 번 모두 같은 쪽으로 벗어난 것은 **블랙홀 발사기(약함, -23%)**와 **방전 코일(강함)**뿐.

수치 제안 (바꾸지 않음, 6단계에서 다시 잰 뒤 정함)
1. 블랙홀 발사기: 끌어모은 뒤 끝에 터지는 피해가 없어 처치가 적다. 사라질 때 반경 안에 한 번 터지는 피해(예: 초당 피해 × 1.5)를 넣거나, 간격 6초 → 5초.
2. 방전 코일: 1단계 번개 2곳 → 그대로 두고 피해 170 → 140 정도로 낮추거나, 간격 1.5초 → 1.8초.
3. 판 안에서 보조 무기가 잘 안 자람: 보조 무기 카드 확률 35%에 "가진 보조 무기 강화"가 섞이면 원하는 것이 덜 나온다. 6단계에서 가진 보조 무기 강화 카드 가중치를 올릴지 같이 본다.

## 다시 만들기

```bash
# 웹 빌드 (build/는 커밋 안 함)
v=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot); bash tools/export_web.sh "$PWD" "$PWD/build/web" "$v"
python3 -m http.server 8765 --directory build/web &
# Playwright headless (CHROME=설치된 chrome-headless-shell 경로, NODE_PATH=playwright가 있는 node_modules)
FRAMES=/tmp/frames node review/v080_step4/capture_web.cjs missile_1 missile_5 … rail_fast cards_new_pc cards_new_phone …
python3 review/v080_step4/make_gifs.py /tmp/frames
# 봇
godot --headless --path . -s $PWD/review/v080_step4/bot_subs.gd -- review/v080_step4/bot_table.md
```
