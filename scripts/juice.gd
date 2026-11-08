class_name Juice
extends RefCounted
## 손맛(타격감·움직임) 수치 모음 (QUALITY_BAR.md, PLAN_v0.7.0 7번). 상수만 두고 Balance처럼 어디서나 읽는다.
## 화면 연출 값이 대부분이고, 광물 튕김·자석 가속처럼 RunSim이 쓰는 값도 여기 둔다 (손맛 조정을 한곳에서 하려고).

# ── 쏘기와 맞히기 ─────────────────────
## 쏠 때 우주선이 뒤로 밀리는 거리(픽셀)와 돌아오는 시간
const RECOIL_PX := 2.0
const RECOIL_TIME := 0.08
## 자동 포 총구 불꽃 프레임 속도 (쏜 직후 1번부터 끝까지 재생)
const CANNON_FPS := 28.0
## 맞은 적·운석이 흰색으로 번쩍이는 시간 (셰이더로 흰색을 섞음, 처음에 가장 하얗고 사라짐)
const ENEMY_FLASH_TIME := 0.05
## 맞으면 탄이 날아온 쪽으로 밀리는 거리(픽셀). 밀리는 시간은 Balance.HIT_KNOCK_TIME
const HIT_KNOCK_DISTANCE := 2.0

# ── 부수기 ─────────────────────
## 파괴 애니메이션 속도(초당 프레임): 적 함선, 운석 크기별(작음·중간·큼), 황금 운석. 클수록 느리게 = 묵직하게
const ENEMY_BOOM_FPS := 14.0
const ROCK_BOOM_FPS := [16.0, 14.0, 10.0]
const GOLD_BOOM_FPS := 10.0
## 파편 파티클: 기본 수 + 반지름 RADIUS_PER_DEBRIS마다 1개, 지속 시간, 속도(반지름 40마다 1배씩 빨라짐)
const DEBRIS_COUNT := 6
const RADIUS_PER_DEBRIS := 3.0
const DEBRIS_TIME := 0.35
const DEBRIS_SPEED := 60.0
const GOLDEN_DEBRIS_COUNT := 24
## 화면에 한꺼번에 있을 수 있는 파편 파티클 총량 (넘치면 새 파편을 만들지 않음, 폰 성능용)
const PARTICLE_MAX := 160
## 이 반지름 이상이면 파편이 2픽셀 덩어리 (큰 운석·황금 운석)
const DEBRIS_BIG_RADIUS := 16.0
## 히트스톱: 큰 운석·황금 운석을 부순 순간 시뮬레이션을 멈추는 시간 (Engine.time_scale은 안 씀, 입력은 계속)
const HITSTOP_BIG := 0.04
const HITSTOP_GOLD := 0.06
## 히트스톱과 함께 오는 약한 화면 흔들림 (시간, 세기 픽셀)
const BREAK_SHAKE_TIME := 0.15
const BREAK_SHAKE_STRENGTH := 1.0

# ── 광물 ─────────────────────
## 부서질 때 광물이 튀어 나가는 거리(최소~최대)와 감속(클수록 빨리 멈춤): 속도 = 거리 × 감속, 매 초 e^-감속 배로 줄어듦(ease-out)
const MINERAL_POP_MIN := 6.0
const MINERAL_POP_MAX := 18.0
const MINERAL_POP_DAMP := 6.0
## 자석: 범위 끝에서 기본 속도(Balance.MAGNET_SPEED) × FAR, 우주선 바로 옆에서 × NEAR (가까울수록 빨라짐)
const MAGNET_FAR := 1.0
const MAGNET_NEAR := 2.2
## 떠 있는 광물 반짝임: 등급별 초당 반짝임 횟수와 십자 크기(0이면 점 하나). 등급이 높을수록 자주·크게
const SPARKLE_RATE := [0.6, 1.2, 2.0, 3.0]
const SPARKLE_SIZE := [0, 1, 1, 2]
## 등급별 줍기 연출 시간과 퍼지는 고리 반지름 (일반, 희귀, 영웅, 전설)
const PICKUP_FX_TIME := [0.25, 0.35, 0.45, 0.7]
const PICKUP_RING_RADIUS := [6.0, 10.0, 14.0, 24.0]

# ── 우주선 ─────────────────────
## 보이는 방향이 실제 방향을 따라가는 빠르기 (lerp_angle, 초당 비율). 그림은 8방향으로 스냅
const SHIP_TURN_LERP := 18.0
## 최고 속도의 이 비율보다 빠르면 출력 불꽃(Powering), 아니면 대기(Idle)
const ENGINE_POWER_RATIO := 0.5
## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08
## 피격: 중간 화면 흔들림(시간, 세기 픽셀), 화면 붉은 번쩍임·가장자리 테두리 시간
const HIT_SHAKE_TIME := 0.25
const HIT_SHAKE_STRENGTH := 3.0
const HIT_FLASH_TIME := 0.2

# ── 레벨업과 화면 ─────────────────────
## 레벨업 순간 슬로모션: 실제 시간, 시뮬레이션 배율. 그동안 우주선 둘레에 빛이 퍼진다
const LEVELUP_SLOWMO_TIME := 0.3
const LEVELUP_SLOWMO_SCALE := 0.25
const LEVELUP_LIGHT_COLOR := Color("#fff4c8")
const LEVELUP_LIGHT_RADIUS := 56.0
## 레벨업 카드(메뉴)가 아래에서 튀어 오르는 거리(픽셀)와 시간 (넘쳤다 돌아오는 트윈)
const CARD_POP_DISTANCE := 24.0
const CARD_POP_TIME := 0.28
## HUD 숫자 카운트업: 남은 차이의 초당 비율 + 최소 초당 증가량 (목표에 빠르게 붙음)
const COUNT_UP_RATE := 12.0
const COUNT_UP_MIN := 20.0
## 버튼 눌림: 1픽셀 내려가고 밝기가 바뀜 (크기 변화 금지: 정수 배율 규칙)
const BUTTON_PRESS_PX := 1
const BUTTON_PRESS_MODULATE := Color(1.35, 1.35, 1.35)
