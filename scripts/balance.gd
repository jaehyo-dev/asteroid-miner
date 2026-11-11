class_name Balance
extends RefCounted
## 게임 수치 모음.
## 조작감, 속도, 난이도 같은 값은 모두 여기 모아 두었다. 이 파일만 고치면 게임 전체에 반영된다.
## (단위: 거리 = 픽셀, 시간 = 초, 속도 = 픽셀/초)

# ── 화면 ─────────────────────────────────────────────
## 가로 화면 기준 해상도 (PC, 휴대폰 가로)
const BASE_LANDSCAPE := Vector2i(640, 360)
## 출격 화면은 정수 배율로 키우고, 논리 화면을 창 / 배율로 맞춘다. 논리 화면이 이 범위를 벗어나면
## 배율을 낮추고, 그래도 안 되면 예전처럼 640x360 소수 배율로 그린다 (작은 PC 창 등 드문 경우).
const RUN_VIEW_MIN := Vector2i(560, 320)
const RUN_VIEW_MAX_HEIGHT := 480
## 한 프레임에 처리하는 최대 시간. 탭 전환 등으로 프레임이 길어져도 운석이 순간 이동하지 않게 한다.
const MAX_FRAME_DELTA := 0.1

# ── 우주선 ───────────────────────────────────────────
## 충돌 반지름(…_RADIUS, "radius")은 팩 그림(v0.7.0)의 보이는 몸보다 작게 잡는다: 운석·경비선은 보이는 반지름의 약 70%,
## 해파리·날벌레는 약 60%, 내 우주선은 몸통만(약 50~60%: v0.7.0 3c에서 몸 약 20x16으로 작아져 7 → 5.5. 4.5는 밸런스 봇에서 광물·생존이 15% 넘게 늘어남). 같은 화면에 그림이 커진 만큼 운석 등장 간격을 1.15배로 늘려
## 밸런스 봇의 한 판 길이·4분 생존·레벨업 속도를 그 전과 비슷하게 맞췄다 (tests/balance_report.gd).
const SHIP_SPEED := 120.0
const SHIP_RADIUS := 5.5
const SHIP_MAX_HP := 100.0
## 맞은 뒤 무적 시간. 이 시간 동안은 운석과 부딪혀도 데미지가 없다.
const SHIP_INVULN_TIME := 1.0
## 우주선이 이동 방향으로 도는 속도 (라디안/초). 클수록 빨리 돈다 (10이면 반 바퀴에 약 0.3초).
const SHIP_TURN_SPEED := 10.0

# ── 휴대폰 가상 조이스틱 ─────────────────────────────
## 손가락을 이만큼 끌면 최고 속도
const JOYSTICK_RADIUS := 28.0
## 이 비율(0~1) 안쪽의 작은 움직임은 무시한다
const JOYSTICK_DEAD_ZONE := 0.15

# ── 운석 ─────────────────────────────────────────────
## 크기별 수치: 반지름, 체력(탄 몇 발), 부딪혔을 때 데미지, 속도 범위, 부서질 때 떨어뜨리는 광물 등급(MINERAL_GRADES 번호)과 개수
## 광물 등급은 크기마다 고정이다: 작은 운석 → 일반, 중간 → 희귀, 큰 운석 → 영웅
const ASTEROID_TYPES := [
	{"name": "작은 운석", "radius": 8.0, "hp": 1.0, "damage": 8.0, "speed_min": 45.0, "speed_max": 75.0, "grade": 0, "minerals": 1},
	{"name": "중간 운석", "radius": 12.0, "hp": 2.0, "damage": 14.0, "speed_min": 32.0, "speed_max": 55.0, "grade": 1, "minerals": 1},
	{"name": "큰 운석", "radius": 20.0, "hp": 3.0, "damage": 22.0, "speed_min": 22.0, "speed_max": 40.0, "grade": 2, "minerals": 2},
]
## 운석 체력은 이 시간(초)마다 기본값만큼 계단식으로 늘어난다 (0~75초 1배, 75초부터 2배, 150초부터 3배 …).
const ASTEROID_HP_GROWTH_TIME := 75.0
## 크기별 등장 비율. 시작할 때 → SPAWN_RAMP_TIME 뒤로 점점 바뀐다 (큰 운석이 늘어남).
const ASTEROID_WEIGHTS_START := [6.0, 3.0, 1.0]
const ASTEROID_WEIGHTS_LATE := [4.0, 4.0, 2.0]
## 운석은 우주선 쪽으로 날아오되, 이 각도(도)만큼 무작위로 빗나간다.
const ASTEROID_AIM_SPREAD_DEG := 25.0
## 운석 등장 간격: 시작 → SPAWN_RAMP_TIME에 걸쳐 최소 간격까지 줄어든다.
const SPAWN_INTERVAL_START := 1.15
const SPAWN_INTERVAL_MIN := 0.17
const SPAWN_RAMP_TIME := 240.0
## 그 뒤로도 계속 어려워진다: 등장 간격이 이 시간(초)마다 절반이 된다 (SPAWN_INTERVAL_FLOOR까지).
## 강화를 아무리 쌓아도 결국 버틸 수 없게 해서 한 판이 끝나도록 한다.
const SPAWN_LATE_HALVING_TIME := 55.0
const SPAWN_INTERVAL_FLOOR := 0.03
## 운석 속도는 이 시간(초)마다 기본 속도만큼 더 빨라진다 (180초면 2배).
const ASTEROID_SPEED_GROWTH_TIME := 180.0
## 운석은 화면 밖 이만큼 떨어진 곳에서 나타난다.
const SPAWN_MARGIN := 24.0
## 화면 대각선 반 길이의 이 배수보다 멀어진 운석은 없앤다.
const DESPAWN_DISTANCE_FACTOR := 1.6
## 동시에 존재할 수 있는 최대 적 수 (운석·생명체 합계, 휴대폰 성능 보호)
const MAX_ENEMIES := 250

# ── 심연의 포격 (보이지 않는 최종 보스의 에너지포) ─
## 화면 밖 먼 곳의 무언가가 우주선을 노려 에너지탄 BARRAGE_SHOTS발을 연달아 쏜다.
## 자동 공격으로 부술 수 없으므로 반드시 피해야 한다. 그래서 예고를 충분히 보여 준다.
## 흐름: 예고(붉은 조준선, BARRAGE_WARN_TIME) → 충전(조준선이 밝고 굵어짐, BARRAGE_CHARGE_TIME) → 발사(BARRAGE_SHOT_GAP 간격)
## 첫 포격 시각과 포격 간격(시작 → SPAWN_RAMP_TIME에 걸쳐 최소까지 줄어듦)
const BARRAGE_FIRST_TIME := 12.0
const BARRAGE_INTERVAL_START := 12.0
const BARRAGE_INTERVAL_MIN := 6.0
const BARRAGE_WARN_TIME := 1.0
const BARRAGE_CHARGE_TIME := 0.5
const BARRAGE_SHOTS := 3
const BARRAGE_SHOT_GAP := 0.15
const BARRAGE_SHOT_SPEED := 160.0
const BARRAGE_SHOT_DAMAGE := 10.0
## 에너지탄 맞는 범위(반지름). v0.7.0 에너지 구체 그림(몸통 약 14px)에 맞춰 4 → 6 (그림보다 조금 작게)
const BARRAGE_SHOT_RADIUS := 6.0
## 예고가 시작되면 조준선이 쏘는 곳에서부터 이 비율(예고 시간 중)만큼의 시간 동안 쭉 그어진다
const BARRAGE_DRAW_RATIO := 0.4
## 다 쏜 뒤에도 마지막 탄이 우주선 쪽을 지나갈 때까지 화면 가장자리 "!" 표시를 남기는 여유 시간 (초)
const BARRAGE_LINGER_EXTRA := 0.4
## 첫 탄을 쏜 뒤 조준선이 사라지는 시간 (초). 쏘는 순간 탄이 지나갈 길을 잠깐 비춰 주는 느낌
const BARRAGE_LINE_FADE_TIME := 0.5
## 조준: 예고를 시작할 때 우주선이 이 시간(초) 뒤에 있을 곳을 노린다 (움직이면 앞을 막고, 멈춰 있으면 그 자리)
const BARRAGE_LEAD_TIME := 0.6

# ── 쫓아오는 생명체 ─────────────────────────────────
## 종류별: 이름, 반지름, 체력(탄 몇 발, 운석처럼 시간에 따라 계단식 증가), 부딪혔을 때 데미지,
## 최고 속도, 방향을 트는 힘(가속도), 부수면 떨어지는 광물 등급과 개수
## 속도는 시간이 지날수록 빨라지지만 운석보다 천천히 (CREATURE_SPEED_GROWTH_TIME마다 기본 속도만큼).
const CREATURES := {
	"jelly": {"name": "우주 해파리", "radius": 9.0, "hp": 4.0, "damage": 12.0, "speed": 32.0, "accel": 45.0, "grade": 1, "minerals": 1},
	"bug": {"name": "날벌레", "radius": 7.0, "hp": 1.0, "damage": 7.0, "speed": 95.0, "accel": 45.0, "grade": 0, "minerals": 1},
}
## 생명체 속도가 기본 속도만큼 더 빨라지는 시간 (360초면 2배). 날벌레가 우주선보다 너무 빨라지지 않게 운석보다 느리게.
const CREATURE_SPEED_GROWTH_TIME := 360.0
## 우주 해파리: 천천히 끝까지 쫓아온다. 첫 등장 시각과 등장 간격(시작 → SPAWN_RAMP_TIME에 걸쳐 최소)
const JELLY_FIRST_TIME := 40.0
const JELLY_INTERVAL_START := 9.0
const JELLY_INTERVAL_MIN := 3.5
## 날벌레 떼: 무리 지어 빠르게 돌진한다. 첫 등장 시각, 무리 간격, 한 무리 수, 무리가 퍼진 정도(픽셀)
## (첫 등장 시각은 습격 뒤 숨 돌릴 틈(평소 등장이 멈춤)과 겹치지 않게 정한다)
const BUG_FIRST_TIME := 80.0
const BUG_INTERVAL_START := 15.0
const BUG_INTERVAL_MIN := 7.0
const BUG_SWARM_SIZE := 5
const BUG_SWARM_SPREAD := 20.0
## 날벌레는 나온 뒤 이 시간 동안만 우주선 쪽으로 방향을 튼다 (그 뒤엔 그대로 지나감)
const BUG_HOMING_TIME := 3.0

# ── 고대 경비선 (따라다니며 쏘는 적 함선) ─────────
## 심연을 지키던 오래된 무인 함선. 우주선과 일정 거리(GUARD_KEEP_DISTANCE)를 두고 따라다니며 주위를 돌고,
## 선체를 천천히 돌려 우주선을 노린 뒤 충전(뱃머리 빛) → 에너지탄 한 발을 쏜다.
## 단단하고(탄 여러 발) 좋은 광물을 준다. 몸으로 부딪혀도 부서지지 않는다(피해만 입음).
## 체력은 운석처럼 ASTEROID_HP_GROWTH_TIME마다 계단식으로 늘어난다.
const GUARD := {"name": "고대 경비선", "radius": 10.0, "hp": 4.0, "damage": 15.0}
## 부수면 떨어지는 광물: 영웅 3개 + 희귀 2개
const GUARD_DROPS := [{"grade": 2, "count": 3}, {"grade": 1, "count": 2}]
## 첫 등장 시각, 등장 간격(시작 → SPAWN_RAMP_TIME에 걸쳐 최소), 동시에 있을 수 있는 최대 수
## (첫 등장 시각은 습격 뒤 숨 돌릴 틈과 겹치지 않게 정한다)
const GUARD_FIRST_TIME := 100.0
const GUARD_INTERVAL_START := 45.0
const GUARD_INTERVAL_MIN := 30.0
const GUARD_MAX := 1
## 움직임: 최고 속도(우주선 120보다 느려서 달아날 수 있음, GUARD_SPEED_GROWTH_TIME마다 기본 속도만큼 빨라짐),
## 방향을 바꾸는 힘(가속도), 우주선과 유지하려는 거리(픽셀), 주위를 도는 빠르기(최고 속도 대비 비율)
const GUARD_SPEED := 65.0
const GUARD_SPEED_GROWTH_TIME := 600.0
const GUARD_ACCEL := 90.0
const GUARD_KEEP_DISTANCE := 150.0
const GUARD_ORBIT_RATIO := 0.6
## 일반 운석보다 이 배수만큼 더 멀어져야 사라진다 (보통은 따라오므로 거의 사라지지 않음)
const GUARD_DESPAWN_FACTOR := 1.3
## 선체(포) 회전 속도(라디안/초): 천천히 돌아서 우주선이 빨리 옆으로 돌면 따라오지 못한다
const GUARD_TURN_SPEED := 1.5
## 선체가 우주선 쪽 이 각도(도) 안을 바라보면 충전을 시작한다
const GUARD_AIM_TOLERANCE_DEG := 10.0
## 사거리(픽셀). 화면 안(가장자리에서 GUARD_SCREEN_MARGIN 안쪽)에 보일 때만 쏜다.
const GUARD_RANGE := 220.0
const GUARD_SCREEN_MARGIN := 8.0
## 충전 시간(뱃머리가 점점 밝아짐), 쏜 뒤 다음 충전까지 시간
const GUARD_CHARGE_TIME := 1.0
const GUARD_FIRE_INTERVAL := 3.5
## 경비선 에너지탄: 속도, 피해, 맞는 범위(반지름). 심연의 포격처럼 자동 공격으로 부술 수 없다.
const GUARD_SHOT_SPEED := 110.0
const GUARD_SHOT_DAMAGE := 5.0
const GUARD_SHOT_RADIUS := 4.0

# ── 습격 이벤트 (긴장의 리듬) ───────────────────────
## RAID_INTERVAL마다: 경고(RAID_WARNING_TIME) → 습격(RAID_DURATION) → 숨 돌릴 틈(RAID_CALM_TIME, 보통 등장 멈춤)
## 종류는 운석 폭풍과 날벌레 습격(날벌레가 나온 뒤부터)이 번갈아 온다.
const RAID_FIRST_TIME := 60.0  ## 첫 습격이 시작되는 시각 (경고는 그보다 RAID_WARNING_TIME 먼저)
const RAID_INTERVAL := 60.0
const RAID_WARNING_TIME := 3.0
const RAID_DURATION := 10.0
const RAID_CALM_TIME := 5.0
## 습격은 한 방향에서 이 폭(도) 안으로 몰려온다
const RAID_ARC_DEG := 50.0
## 운석 폭풍: 운석 간격(시간이 지날수록 보통 등장처럼 짧아짐, 최소 RAID_STORM_INTERVAL_MIN), 조준 퍼짐 각도(도)
const RAID_STORM_INTERVAL := 0.4
const RAID_STORM_INTERVAL_MIN := 0.15
const RAID_STORM_AIM_SPREAD_DEG := 15.0
## 날벌레 습격: 무리 간격
const RAID_SWARM_INTERVAL := 3.0
## 습격이 시작될 때 습격 방향에서 황금 운석이 함께 온다 (위험을 무릅쓰고 잡으러 갈지 고민되게).
## 습격 황금 운석이 있을 수 있게 습격 때는 최대 수를 GOLDEN_MAX + RAID_GOLDEN_COUNT까지 허용한다.
const RAID_GOLDEN_COUNT := 1
## 새로운 적이 처음 나올 때 / 습격 경고 배너를 보여 주는 시간
const BANNER_TIME := 2.5

# ── 황금 운석 (가끔 나오는 특수 운석) ───────────────
## 큰 운석보다 훨씬 단단하고 느리게 지나간다. 몸으로 부딪혀도 부서지지 않는다(피해만 입음).
## 체력도 일반 운석처럼 ASTEROID_HP_GROWTH_TIME마다 계단식으로 늘어난다.
const GOLDEN := {"name": "황금 운석", "radius": 12.0, "hp": 18.0, "damage": 22.0, "speed_min": 16.0, "speed_max": 26.0}
## 부수면 떨어지는 광물: 등급(MINERAL_GRADES 번호)과 개수 → 전설 1개 + 영웅 4개
const GOLDEN_DROPS := [{"grade": 3, "count": 1}, {"grade": 2, "count": 4}]
## 첫 등장 시각, 등장 간격(시작 → GOLDEN_RAMP_TIME에 걸쳐 최소까지 줄어듦: 시간이 지날수록 조금씩 자주)
const GOLDEN_FIRST_TIME := 35.0
const GOLDEN_INTERVAL_START := 55.0
const GOLDEN_INTERVAL_MIN := 30.0
const GOLDEN_RAMP_TIME := 300.0
## 우주선을 향하지 않고 이 각도(도)까지 빗나가 화면 근처를 지나간다 (쫓아가야 잡을 수 있게).
const GOLDEN_AIM_SPREAD_DEG := 60.0
## 적어도 이 각도(도)만큼은 비껴 간다 (가만히 있는 우주선에 곧장 부딪히지 않게)
const GOLDEN_AIM_MIN_DEG := 20.0
## 동시에 있을 수 있는 최대 수
const GOLDEN_MAX := 2
## 일반 운석보다 이 배수만큼 더 멀어져야 사라진다 (멀어져도 쫓아갈 시간을 줌)
const GOLDEN_DESPAWN_FACTOR := 2.0

# ── 자동 공격 ────────────────────────────────────────
## 발사 간격
const FIRE_INTERVAL := 0.55
## 이 거리 안에 있는 가장 가까운 운석을 자동으로 노린다.
const FIRE_RANGE := 170.0
## 자동 공격은 황금 운석을 이 거리(픽셀)만큼 더 멀리 있는 것으로 치고 고른다 (가까운 위협 먼저)
const TARGET_GOLDEN_PENALTY := 60.0
const BULLET_SPEED := 260.0
const BULLET_DAMAGE := 1.0
const BULLET_RADIUS := 2.0
## 한 번에 쏘는 탄 수
## 발사 형태: 1발 직선 / 2발 나란히 / 홀수(3, 5…) 가운데 1발 + 양옆 부채꼴 / 짝수(4, 6…) 가운데 2발 나란히 + 양옆 부채꼴
const BULLET_COUNT := 1
## 부채꼴로 퍼지는 탄 사이의 각도
const MULTI_SHOT_SPREAD_DEG := 12.0
## 나란히 나가는 두 발 사이의 간격 (픽셀). 60% 우주선 자동 포의 두 총구 간격(약 10)에 맞춤.
## 작은 운석(반지름 8 + 탄 2)도 가운데를 노리면 두 발(±5) 다 맞는다.
const PARALLEL_SHOT_GAP := 10.0
## 탄은 사거리보다 이 비율만큼 더 날아가고 사라진다.
const BULLET_LIFETIME_FACTOR := 1.15

# ── 광물 ─────────────────────────────────────────────
## 등급별: 이름, 가치. 탄으로 부순 운석에서만 떨어진다 (몸으로 부딪혀 부순 운석은 없음).
## 어떤 등급이 떨어지는지는 운석 크기(ASTEROID_TYPES의 grade)와 황금 운석(GOLDEN_DROPS)이 정한다.
## 광물을 주우면 가치 × MINERAL_XP_PER_VALUE 만큼 경험치를 얻는다 (운석을 부숴서는 경험치를 얻지 않음).
const MINERAL_GRADES := [
	{"name": "일반", "value": 1},
	{"name": "희귀", "value": 5},
	{"name": "영웅", "value": 20},
	{"name": "전설", "value": 100},
]
## 광물 가치 1당 경험치. 등급별 경험치 = 가치 × 이 값 (반올림, 최소 1)
const MINERAL_XP_PER_VALUE := 1.0
## (광물이 운석에서 튕겨 나가는 거리·감속은 scripts/juice.gd)
## 자석 범위: 이 안에 들어온 광물은 우주선으로 끌려온다.
const MAGNET_RADIUS := 48.0
## 끌려오는 속도 (우주선보다 빨라야 따라잡는다)
const MAGNET_SPEED := 220.0
## 이 거리 안이면 줍는다.
const PICKUP_RADIUS := 10.0
## 바닥에 남아 있을 수 있는 최대 광물 수 (넘으면 오래된 것부터 사라짐)
const MAX_MINERALS := 300
## 광물 합치기: 같은 등급이 MERGE_RADIUS 안에 MERGE_COUNT[등급]개 이상, 모두 MERGE_REST초 넘게 놓여 있으면 한 단계 위 1개로.
## 가치는 그대로 (일반 5 = 희귀 1, 희귀 4 = 영웅 1, 영웅 5 = 전설 1). 전설은 더 합치지 않는다(0). 자석에 끌려오는 광물은 빠진다.
const MERGE_COUNT := [5, 4, 5, 0]
const MERGE_RADIUS := 24.0
const MERGE_REST := 1.5
## 합치기 검사는 MERGE_CHECK_INTERVAL초마다 한 번, 한 번에 후보로 살펴보는 광물은 MERGE_CHECKS_PER_FRAME개
## (많을 때 돌아가며 나눠 본다. 매 프레임 검사하면 후반 웹에서 스크립트 시간이 약 1ms(15%) 늘어 줄임: review/v070_balance/apply/perf)
const MERGE_CHECK_INTERVAL := 0.2
const MERGE_CHECKS_PER_FRAME := 40

# ── 경험치와 레벨업 강화 ─────────────────────────────
## 레벨업에 필요한 경험치 = XP_BASE + (현재 레벨 - 1) × XP_GROWTH  (1→2: 16, 2→3: 52, 3→4: 88 …)
## 경험치는 광물을 주우면 얻는다 (광물 가치 × MINERAL_XP_PER_VALUE).
const XP_BASE := 16
const XP_GROWTH := 38
## 레벨업 때 보여 주는 강화 수
const UPGRADE_CHOICE_COUNT := 3
## 한 판에 쓸 수 있는 다시 뽑기 횟수 (3장을 한꺼번에 새로 뽑음)
const REROLLS_PER_RUN := 2
## 건너뛰기: 카드를 고르지 않고 넘기면 다음 레벨 필요 경험치의 이 비율만큼 광물 가치를 기지 금고에 바로 더한다 (경험치 없음)
## 위험 없이 금고로 바로 들어가고 레벨이 오를수록 커져서 15% → 5%로 낮춤
const SKIP_REWARD_RATIO := 0.05
## 등급 확률(%): 노멀·레어·에픽·유니크·레전드리. RISK_RAMP_TIME에 걸쳐 시작값 → 끝값으로 오르고 그 뒤로는 고정
const GRADE_WEIGHTS_START := [55.0, 27.0, 12.0, 5.0, 1.0]
const GRADE_WEIGHTS_END := [35.0, 30.0, 20.0, 12.0, 3.0]
## 효과 강화·레전드리 카드가 뽑히는지. 실제 효과는 5단계 3부에서 만든다: 그때까지 잠가 둔다 (보정도 함께 꺼짐)
const EFFECT_CARDS_ENABLED := true
## 효과 카드가 쌓여 멈추지 않는 판을 막는 값 (봇 측정). 이 레벨부터 필요한 경험치가 제곱으로 늘고,
## 이 시각부터 적 체력이 제곱으로 늘어난다 (보통 한 판 길이보다 뒤라 평소 플레이에는 영향이 거의 없음)
const XP_SOFT_LEVEL := 14
const XP_SOFT_GROWTH := 4
const ENEMY_LATE_HP_START := 270.0
const ENEMY_LATE_HP_TIME := 60.0
const ENEMY_LATE_HP_SCALE := 0.6
## 후반 적 피해 (v0.7.0 밸런스 D): ENEMY_DAMAGE_START초부터 1분마다 ENEMY_DAMAGE_STEP씩 오르고 ENEMY_DAMAGE_MAX에서 멈춘다.
## 부딪힘·적 탄 모두 (2:30 ×1, 3:30 ×1.25 … 8:30부터 ×2.5)
const ENEMY_DAMAGE_START := 150.0
const ENEMY_DAMAGE_STEP := 0.25
const ENEMY_DAMAGE_MAX := 2.5
## 에픽·유니크 칸이 효과 강화일 확률 (나머지는 수치 강화)
const EFFECT_SHARE := 0.6
## 효과 카드 없는 레벨업이 이만큼 이어지면 다음 화면에 에픽 효과 1장 확정
const EFFECT_PITY_LEVELUPS := 2
## 수리 카드는 체력이 이 비율 아래일 때만 뽑기에 들어간다 (봇 측정: 항상 넣으면 returner 사망 34→45%, 꽉 찬 체력엔 빈칸이기도 함)
const REPAIR_POOL_HP_RATIO := 0.7
## 수치 강화 8종: 등급별 수치(노멀·레어·에픽·유니크). 최대 단계는 고른 횟수로 센다 (0 = 단계 없음). 강화는 그 판에서만 유지된다.
## fire_rate는 발사 속도 비율, multishot은 탄 수와 탄 피해 비율. 모두 고를 때마다 더해진다.
const UPGRADES := [
	{"id": "fire_rate", "name": "시스템 쿨러 개량", "kind": "공격", "max": 5, "values": [0.10, 0.15, 0.20, 0.30]},
	{"id": "multishot", "name": "다중 포신 장착", "kind": "공격", "max": 4, "values": [1, 1, 1, 2], "bonus_damage": [0.0, 0.10, 0.20, 0.0]},
	{"id": "damage", "name": "고밀도 탄두", "kind": "공격", "max": 5, "values": [0.75, 1.1, 1.5, 2.25]},
	{"id": "range", "name": "장거리 조준 센서", "kind": "공격", "max": 3, "values": [0.15, 0.22, 0.30, 0.45]},
	{"id": "max_hp", "name": "복합 장갑판 보강", "kind": "방어", "max": 5, "values": [15.0, 22.0, 30.0, 45.0]},
	{"id": "repair", "name": "나노 수리봇 투입", "kind": "방어", "max": 0, "values": [20.0, 30.0, 40.0, 60.0]},
	{"id": "speed", "name": "추진기 출력 조정", "kind": "이동", "max": 5, "values": [0.09, 0.13, 0.18, 0.27]},
	{"id": "magnet", "name": "중력 견인 코일", "kind": "채굴", "max": 5, "values": [0.30, 0.45, 0.60, 0.90]},
]
## 효과 강화 7종 (에픽·유니크만). desc·short는 [에픽, 유니크] 문구, short는 폰 2줄용. 실제 수치와 효과는 3부에서 넣는다
const EFFECT_UPGRADES := [
	{"id": "pierce", "name": "텅스텐 관통탄", "kind": "공격", "max": 3, "blocked_by": "orbit_pierce", "desc": ["탄이 대상 1개를 더 뚫고 지나감", "탄이 대상 2개를 더 뚫고 지나감"], "short": ["1개 더 관통", "2개 더 관통"]},
	{"id": "ricochet", "name": "반사 코팅 탄", "kind": "공격", "max": 2, "desc": ["맞은 뒤 1번 튕김 (피해 70%)", "맞은 뒤 2번 튕김 (피해 70%)"], "short": ["1번 튕김 피해 70%", "2번 튕김 피해 70%"]},
	{"id": "explosive", "name": "고폭 탄두", "kind": "공격", "max": 3, "desc": ["부술 때 반경 24 폭발, 탄 피해의 50%", "부술 때 반경 36 폭발, 탄 피해의 75%"], "short": ["부수면 폭발 피해 50%", "부수면 폭발 피해 75%"]},
	{"id": "crit", "name": "표적 분석 AI", "kind": "공격", "max": 3, "desc": ["치명타 확률 15% (2배 피해)", "치명타 확률 25% (2배 피해)"], "short": ["치명타 15%", "치명타 25%"]},
	{"id": "shield", "name": "자동 방어막 발생기", "kind": "방어", "max": 3, "desc": ["20초마다 피해 1번을 막음", "12초마다 피해 1번을 막음"], "short": ["20초마다 1번 막음", "12초마다 1번 막음"]},
	{"id": "drone", "name": "호위 드론 사출", "kind": "드론", "max": 3, "desc": ["드론 +1기가 따라다니며 함께 공격", "드론 +2기가 따라다니며 함께 공격"], "short": ["드론 +1기 함께 공격", "드론 +2기 함께 공격"]},
	{"id": "mining_laser", "name": "정밀 채굴 레이저", "kind": "채굴", "max": 3, "desc": ["운석에서 나오는 광물 +25%", "운석에서 나오는 광물 +50%"], "short": ["운석 광물 +25%", "운석 광물 +50%"]},
]
## 레전드리 4종: 한 판에 1번, 한 화면에 1장까지
const LEGENDARY_UPGRADES := [
	{"id": "orbit_pierce", "name": "궤도 관통 가속기", "kind": "공격", "max": 1, "desc": "모든 탄이 사거리 끝까지 관통", "short": "모든 탄이 끝까지 관통"},
	{"id": "chain_matrix", "name": "연쇄 반사 매트릭스", "kind": "공격", "max": 1, "desc": "튕김 +3번, 반사 탄도 튕길 때 피해 80%", "short": "튕김 +3, 전부 80%"},
	{"id": "overload", "name": "과부하 반응로", "kind": "공격", "max": 1, "desc": "체력이 절반 이하면 발사 속도 ×2", "short": "체력 절반 이하 연사 ×2"},
	{"id": "tractor_beacon", "name": "전역 견인 비콘", "kind": "채굴", "max": 1, "desc": "8초마다 화면 안 모든 광물을 끌어옴", "short": "8초마다 모든 광물 끌어옴"},
]

## 효과 강화 수치. 배열은 [에픽, 유니크]. 최대 단계는 고른 횟수로 세고, 합쳐서 넘지 않는 상한은 여기에 둔다.
const PIERCE_ADD := [1, 2]
const PIERCE_CAP := 4
const RICOCHET_ADD := [1, 2]
const RICOCHET_CAP := 3
## 튕길 때마다 곱해지는 피해, 다음 대상을 찾는 거리
const RICOCHET_DAMAGE := 0.7
const RICOCHET_RANGE := 110.0
## 폭발: 반경, 탄 피해 대비 비율, 단계마다 늘어나는 반경. 폭발로 부서진 적은 다시 터지지 않는다 (연쇄 폭주 방지)
const EXPLOSIVE_RADIUS := [24.0, 36.0]
const EXPLOSIVE_SHARE := [0.5, 0.75]
const EXPLOSIVE_STAGE_RADIUS := 6.0
const CRIT_ADD := [0.15, 0.25]
const CRIT_CAP := 0.5
const CRIT_MULT := 2.0
## 자동 방어막 발생기(카드 "shield"): 막는 간격, 단계마다 줄어드는 시간, 최소 간격, 막은 뒤 무적 시간
const SHIELD_INTERVAL := [20.0, 12.0]
const SHIELD_STAGE_CUT := 3.0
const SHIELD_MIN_INTERVAL := 8.0
const SHIELD_BLOCK_INVULN := 0.5
## 호위 드론: 수, 상한, 탄 피해 비율, 발사 간격, 사거리 비율, 우주선과의 거리, 도는 속도(라디안/초), 따라오는 빠르기
const DRONE_ADD := [1, 2]
const DRONE_CAP := 3
const DRONE_DAMAGE := 0.5
const DRONE_FIRE_INTERVAL := 1.0
const DRONE_RANGE_RATIO := 0.8
const DRONE_ORBIT := 22.0
const DRONE_SPIN := 1.6
const DRONE_FOLLOW := 8.0
const MINING_ADD := [0.25, 0.5]
const MINING_CAP := 1.0
## 레전드리: 연쇄 튕김 수와 튕길 때마다 곱해지는 피해, 과부하가 켜지는 체력 비율과 발사 속도 배율, 견인 비콘 간격
const CHAIN_BOUNCES := 3
const CHAIN_DAMAGE := 0.8
const OVERLOAD_HP_RATIO := 0.5
const OVERLOAD_FIRE_MULT := 2.0
const BEACON_INTERVAL := 8.0
# ── 기본 무기 5종 (v0.8.0, 격납고에서 하나 장착, 판 중 바꾸지 않음) ─────
## 펄스 연사포는 위 FIRE_*·BULLET_* 값 그대로. 수치는 임시 (6단계 밸런스에서 다시 맞춤).
## interval 발사 간격(초), range 사거리, damage 한 발 피해(레벨업·기지 공격력 배율에 곱함), speed 탄 속도,
## mining 운석 광물 배율(1보다 작으면 확률로 덜 나옴), aim: near 가장 가까운 적, far 가장 먼 적, crowd 많이 모인 곳, rock 가까운 운석 먼저.
## pellets·fan_deg 산탄 수와 부채꼴 각도, pierce -1 끝까지 관통, blast 맞으면 터지는 반경(그 안 모두 같은 피해),
## hitscan 탄 없이 쏘는 순간 사거리 끝까지 그은 선(굵기 width 픽셀)에 걸친 대상을 모두 한 번씩 맞힘, beam 계속 닿는 빔(interval마다 피해), enemy_mult 운석이 아닌 적에게 주는 피해 배율. cost: 격납고 구매 가격(광물, 0이면 처음부터 있음, 임시)
## no_cards: 이 무기에는 효과가 없어 레벨업 카드에서 빼는 강화 (관통·튕김은 탄이 날아가 맞을 때만 일어남)
const WEAPONS := [
	{"id": "pulse", "name": "펄스 연사포", "desc": "가장 가까운 적에게 빠르게 연사한다. 무난한 기본기",
		"interval": FIRE_INTERVAL, "range": FIRE_RANGE, "damage": BULLET_DAMAGE, "speed": BULLET_SPEED, "mining": 1.0, "aim": "near"},
	{"id": "shotgun", "name": "산탄포", "desc": "가까운 적 쪽으로 부채꼴 다섯 발. 붙어서 싸울수록 세다", "cost": 600,
		"interval": 0.95, "range": 110.0, "damage": 0.5, "speed": 300.0, "mining": 1.15, "aim": "near", "pellets": 5, "fan_deg": 40.0},
	{"id": "rail", "name": "레일건", "desc": "가까운 적 쪽 일직선을 한 번에 꿰뚫는 빛줄기", "cost": 900,
		"interval": 1.6, "range": 300.0, "damage": 3.0, "speed": 0.0, "mining": 1.0, "aim": "near", "hitscan": true, "width": 5.0, "no_cards": ["pierce", "ricochet", "orbit_pierce", "chain_matrix"]},
	{"id": "plasma", "name": "플라스마 대포", "desc": "적이 모인 곳에 느리게 날아가 크게 터진다", "cost": 1200,
		"interval": 1.7, "range": 170.0, "damage": 2.0, "speed": 140.0, "mining": 0.75, "aim": "crowd", "blast": 34.0, "no_cards": ["pierce", "ricochet", "orbit_pierce", "chain_matrix"]},
	{"id": "beam", "name": "채굴 빔", "desc": "가까운 운석에 계속 닿는 빔. 캐기는 최고, 싸움은 약함", "cost": 1500,
		"interval": 0.1, "range": 95.0, "damage": 0.22, "speed": 0.0, "mining": 1.5, "aim": "rock", "beam": true, "enemy_mult": 0.5, "no_cards": ["pierce", "ricochet", "orbit_pierce", "chain_matrix"]},
]
## 레일건 (2026-11-12 사용자 결정): 사거리 개념이 없다(무한, 빛줄기는 화면 대각선 길이). 레일건 "range"는 드론 사거리와 레벨업 사거리 배율의 기준으로만 쓴다.
## 사거리를 올리는 강화는 레일건에서 빛줄기 굵기(width)를 같은 배율로 올린다. 굵기 상한(픽셀, 판정·그림 같은 값)
const RAIL_WIDTH_MAX := 10.0
## 레일건 선 판정은 보이는 몸 크기로 본다: 충돌 반지름이 보이는 몸의 약 70%(위 "충돌 반지름" 설명)라 1/0.7
const RAIL_BODY_RADIUS_MULT := 1.4
## 격납고 무기 능력치 칸(1~5)의 눈금: 연사(초당 발사 수)가 이 값들을 넘을 때마다 한 칸 (빔은 끝 칸)
const WEAPON_RATE_STEPS := [0.65, 0.9, 1.5, 5.0]

## 화면에 한꺼번에 있을 수 있는 탄 수 (다중 포신·드론·관통이 겹칠 때 폰 성능용)
const MAX_BULLETS := 160

# ── 피격·위험 표시 (조작감) ─────────────────────────
## (맞았을 때 화면 흔들림·붉은 번쩍임 수치는 scripts/juice.gd)
## 적이 탄에 맞으면 탄이 날아온 쪽으로 잠깐 튕기는 모션 시간 (그림만 밀림, 실제 위치는 그대로)
const HIT_KNOCK_TIME := 0.12
## 이 비율 이하이면 체력 낮음 경고 상태
const LOW_HP_RATIO := 0.3
## 처음 체력 낮음이 될 때 화면 테두리가 붉게 맥박치는 시간
const LOW_HP_BORDER_TIME := 2.0
## 체력 낮음 상태에서 또 맞았을 때 테두리가 다시 붉어지는 짧은 시간
const LOW_HP_REHIT_BORDER_TIME := 0.6
## 경고음은 이 시간(초)에 한 번만 울린다
const LOW_HP_SOUND_COOLDOWN := 10.0

# ── 귀환 (워프 게이트, 충전, 위험도, 화물칸, 사망 보존) ─
## 워프 게이트: GATE_FIRST_TIME에 처음 열리고 GATE_INTERVAL마다 다시 열린다. 열린 뒤 GATE_OPEN_TIME이 지나면 닫힌다.
## (습격 경고(57초, 117초 …) 전에 닫히도록 40초, 100초, 160초 …에 열린다)
const GATE_FIRST_TIME := 40.0
const GATE_INTERVAL := 60.0
const GATE_OPEN_TIME := 15.0
## 게이트는 열릴 때 우주선에서 이만큼 떨어진 곳에 생긴다 (좁은 화면에서는 화면 밖)
const GATE_DISTANCE := 200.0
## 열리기 이 시간(초) 전부터 화면 가장자리에 다음 게이트가 열릴 방향과 남은 시간을 보여 준다
const GATE_HINT_TIME := 10.0
## 이 반지름 안에 들어가면 워프 충전을 시작한다
const GATE_RADIUS := 28.0
## 워프 충전 시간: 충전 중에도 움직이고 공격할 수 있지만 게이트를 벗어나면 취소된다
const WARP_CHARGE_TIME := 5.0
## 위험도 배율: 출격 후 RISK_RAMP_TIME에 걸쳐 1.0 → RISK_MAX까지 오른다. 귀환·사망 때 가져가는 광물 가치에 곱한다.
## (적의 수와 체력도 같은 시간에 따라 늘어난다: spawn_interval, asteroid_hp)
const RISK_MAX := 2.0
const RISK_RAMP_TIME := 300.0
## 화물칸 칸수 (광물 1개 = 1칸). 꽉 차면 더 좋은 광물만 가장 싼 광물과 바꿔 싣는다.
const CARGO_CAPACITY := 80
## 화물 무게: 화물칸이 CARGO_HEAVY_START 비율까지는 그대로, 그 뒤 직선으로 느려져 가득 차면 이동 속도 × (1 - CARGO_HEAVY_SLOW).
## 이동 속도 강화(레벨업·기지)로 오른 속도에 곱한다.
const CARGO_HEAVY_START := 0.25
const CARGO_HEAVY_SLOW := 0.3
## 죽으면 화물칸 광물 개수의 이 비율만(내림) 비싼 것부터 남긴다. 비상 보험 단계마다 늘고 최대 DEATH_KEEP_MAX.
const DEATH_KEEP_BASE := 0.5
const DEATH_KEEP_PER_LEVEL := 0.05
const DEATH_KEEP_MAX := 0.75

# ── 기지 (판과 판 사이의 영구 업그레이드, 6단계) ─────
## 판이 끝나면 가져온 광물의 최종 가치(가치 × 위험도 배율)가 기지 보유 광물에 더해지고,
## 그 광물로 모든 판에 적용되는 공용 업그레이드를 산다.
## 비용 = cost × BASE_COST_GROWTH^(현재 단계) (반올림). 한 판 수익(보통 300~1000)으로 2~3판마다 하나씩 살 수 있게 맞췄다.
## (채굴 드론은 v0.8.0에서 추가)
const BASE_UPGRADES := [
	{"id": "damage", "name": "펄스 증폭기", "max": 5, "cost": 200},
	{"id": "max_hp", "name": "격벽 보강", "max": 5, "cost": 150},
	{"id": "speed", "name": "분사 노즐 개조", "max": 5, "cost": 150},
	{"id": "cargo", "name": "화물 베이 확장", "max": 5, "cost": 120},
	{"id": "insurance", "name": "화물 회수 신호기", "max": 5, "cost": 180},
	{"id": "magnet", "name": "자기장 포집기", "max": 5, "cost": 100},
]
const BASE_COST_GROWTH := 1.6

# ── 연구소 나무 ─────────────────────────────────
## 아래부터 위로 가는 순서. 글자는 기존·새 칸 id, Dictionary는 갈림길(a·b를 각각 cost로 해금).
const RESEARCH_BRANCHES := ["weapon", "hull", "mine", "elec", "survey"]
const RESEARCH_TREE := {
	"weapon": ["damage", "sub", {"a": "rapid", "b": "heavy", "cost": 500}, "over"],
	"hull": ["max_hp", "insurance", {"a": "thick", "b": "dodge", "cost": 500}, "repair"],
	"mine": ["magnet", "cargo", "speed", {"a": "wide", "b": "fast", "cost": 500}, "drill"],
	"elec": ["shield", "reroll", {"a": "chip", "b": "bolt", "cost": 500}, "luck"],
	"survey": ["appraise", "radar", {"a": "deep", "b": "wide_scan", "cost": 500}, "planet"],
}
## 새 칸 (임시, 나중에 밸런스 조정). effect: 효과 글. step이 있으면 단계마다 값 %d 또는 %.0f에 넣는다. soon: 기능이 아직 없어 잠김.
const RESEARCH_NODES := [
	{"id": "sub", "name": "보조 무기 해금", "max": 1, "cost": 300, "effect": "보조 무기 칸 1개", "soon": true},
	{"id": "over", "name": "증폭 탄창", "max": 1, "cost": 800, "effect": "6발마다 공격력 1.6배 탄"},
	{"id": "repair", "name": "긴급 수리", "max": 1, "cost": 800, "effect": "판마다 1번 체력 30% 회복"},
	{"id": "drill", "name": "정밀 드릴", "max": 1, "cost": 800, "effect": "10% 확률로 광물 +1개"},
	{"id": "shield", "name": "편향 실드", "max": 5, "cost": 200, "effect": "피해 막기 +%.0f번", "step": 1},
	{"id": "reroll", "name": "재추첨 회로", "max": 5, "cost": 250, "effect": "다시 뽑기 +%.0f번", "step": 1},
	{"id": "luck", "name": "행운 코어", "max": 1, "cost": 800, "effect": "10% 확률로 카드 1장 더"},
	{"id": "appraise", "name": "광물 감정기", "max": 5, "cost": 200, "effect": "광물 가치 +%.0f%%", "step": 3},
	{"id": "radar", "name": "희귀 탐지기", "max": 5, "cost": 250, "effect": "희귀 이상 확률 +%.0f%%", "step": 1},
	{"id": "planet", "name": "항로 개척", "max": 1, "cost": 800, "effect": "행성 좌표 해금", "soon": true},
	{"id": "rapid", "name": "연사형", "max": 1, "cost": 0, "effect": "공격 속도 +15%, 공격력 -5%"},
	{"id": "heavy", "name": "한 방형", "max": 1, "cost": 0, "effect": "공격력 +25%, 공격 속도 -15%"},
	{"id": "thick", "name": "중장갑", "max": 1, "cost": 0, "effect": "체력 +30, 이동 속도 -5%"},
	{"id": "dodge", "name": "회피형", "max": 1, "cost": 0, "effect": "피격 뒤 무적 +0.3초"},
	{"id": "wide", "name": "넓게 끌기", "max": 1, "cost": 0, "effect": "자석 범위 +40%"},
	{"id": "fast", "name": "빨리 나르기", "max": 1, "cost": 0, "effect": "끌려오는 속도 +60%"},
	{"id": "chip", "name": "고급 회로", "max": 1, "cost": 0, "effect": "에픽 이상 확률 +3%"},
	{"id": "bolt", "name": "실드 충전", "max": 1, "cost": 0, "effect": "60초마다 실드 1번 충전"},
	{"id": "deep", "name": "심부 스캔", "max": 1, "cost": 0, "effect": "영웅·전설 확률 +2%"},
	{"id": "wide_scan", "name": "광역 스캔", "max": 1, "cost": 0, "effect": "황금 운석 등장 간격 -20%"},
]
## 새 칸 효과 수치 (임시, 나중에 밸런스 조정)
const RES_RAPID_RATE := 0.15
const RES_RAPID_DAMAGE := -0.05
const RES_HEAVY_DAMAGE := 0.25
const RES_HEAVY_RATE := -0.15
## 증폭 탄창(저장 키 "over"): 6발마다 1.6배 = 평균 피해 +10% (v0.7.0 밸런스 D, 예전 5발마다 2배)
const RES_OVER_EVERY := 6
const RES_OVER_MULT := 1.6
const RES_THICK_HP := 30.0
const RES_THICK_SPEED := -0.05
const RES_DODGE_INVULN := 0.3
const RES_REPAIR_AT := 0.3  ## 체력이 이 비율 밑으로 떨어지면
const RES_REPAIR_HEAL := 0.3  ## 최대 체력의 이만큼 회복
const RES_WIDE_MAGNET := 0.4
const RES_FAST_PULL := 0.6
const RES_DRILL_CHANCE := 0.1
const RES_LUCK_CHANCE := 0.1
const RES_CHIP_EPIC := 0.03  ## 에픽 이상 확률 더하기 (일반 몫에서 옮긴다)
const RES_BOLT_INTERVAL := 60.0
const RES_APPRAISE_STEP := 0.03
const RES_RADAR_STEP := 0.01  ## 일반 광물이 희귀로 오를 확률 (단계마다)
const RES_DEEP_CHANCE := 0.02  ## 희귀·영웅 광물이 한 등급 오를 확률
const RES_SCAN_GOLDEN := 0.2  ## 황금 운석 등장 간격 줄임
## 단계당 효과
const BASE_DAMAGE_MULT_ADD := 0.1  ## 탄 피해 +10% (레벨업 강화까지 합친 값에 곱함)
const BASE_MAX_HP_ADD := 10.0  ## 최대 체력 +10
const BASE_SPEED_ADD := 0.05  ## 이동 속도 +5% (기본값 기준, 레벨업 강화와 더함)
const BASE_CARGO_ADD := 10  ## 화물칸 +10칸
const BASE_MAGNET_ADD := 0.15  ## 자석 범위 +15% (기본값 기준, 레벨업 강화와 더함)
## 화물 회수 신호기는 단계마다 사망 보존 +DEATH_KEEP_PER_LEVEL (위 귀환 항목)

# ── 전시관 도감 보상 ─────────────────────────────
## 발견 수가 at에 닿으면 받을 수 있다 (at 0 = 전부). id는 저장 키라 바꾸지 않는다. kind: credits 광물, speed 이동 속도, keep 사망 보존, paint 금빛 도색
const CODEX_REWARDS := [
	{"id": "at3", "at": 3, "kind": "credits", "value": 150},
	{"id": "at6", "at": 6, "kind": "speed", "value": 0.02},
	{"id": "at9", "at": 9, "kind": "credits", "value": 400},
	{"id": "at12", "at": 12, "kind": "keep", "value": 0.03},
	{"id": "all", "at": 0, "kind": "paint", "value": 1},
]

## 금고 탱크 더미 그림의 개수 눈금 (tools/export_window_art.py의 PILE_COUNTS와 같게)
const TANK_PILE_COUNTS := [1, 3, 6, 12, 30, 80, 200, 500, 1000]

# ── 격납고 (전투기) ─────────────────────────────────
## 고를 수 있는 전투기 목록. 7단계에서 스카우트·홀러·드릴러를 여기에 추가하면 격납고에 나온다.
## (특성 수치는 7단계에서 항목에 함께 넣는다)
const FIGHTERS := [
	{"id": "pioneer", "name": "파이오니어", "style": "균형형", "weapon": "전방 연사"},
]
## 격납고 칸 수: FIGHTERS보다 많은 칸은 자물쇠와 "곧 추가"로 보여 준다
const HANGAR_SLOTS := 4

## 기지 끌어서 둘러보기: 이만큼(그림 픽셀) 넘게 움직여야 끌기로 친다. 폰은 1배라 크게 (손가락 흔들림), PC는 2배라 작게
const BASE_DRAG_THRESHOLD_SMALL := 4.0
const BASE_DRAG_THRESHOLD_LARGE := 8.0
