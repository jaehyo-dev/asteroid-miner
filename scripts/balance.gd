class_name Balance
extends RefCounted
## 게임 수치 모음.
## 조작감, 속도, 난이도 같은 값은 모두 여기 모아 두었다. 이 파일만 고치면 게임 전체에 반영된다.
## (단위: 거리 = 픽셀, 시간 = 초, 속도 = 픽셀/초)

# ── 화면 ─────────────────────────────────────────────
## 가로 화면 기준 해상도 (PC, 휴대폰 가로)
const BASE_LANDSCAPE := Vector2i(640, 360)
## 세로 화면 기준 해상도 (휴대폰 세로). 짧은 쪽이 360px이 되게 해서 글자 크기를 맞춘다.
const BASE_PORTRAIT := Vector2i(360, 640)
## 한 프레임에 처리하는 최대 시간. 탭 전환 등으로 프레임이 길어져도 운석이 순간 이동하지 않게 한다.
const MAX_FRAME_DELTA := 0.1

# ── 우주선 ───────────────────────────────────────────
const SHIP_SPEED := 110.0
const SHIP_RADIUS := 6.0
const SHIP_MAX_HP := 100.0
## 맞은 뒤 무적 시간. 이 시간 동안은 운석과 부딪혀도 데미지가 없다.
const SHIP_INVULN_TIME := 1.0

# ── 휴대폰 가상 조이스틱 ─────────────────────────────
## 손가락을 이만큼 끌면 최고 속도
const JOYSTICK_RADIUS := 28.0
## 이 비율(0~1) 안쪽의 작은 움직임은 무시한다
const JOYSTICK_DEAD_ZONE := 0.15

# ── 운석 ─────────────────────────────────────────────
## 크기별 수치: 반지름, 체력(탄 몇 발), 부딪혔을 때 데미지, 속도 범위, 부서질 때 떨어뜨리는 광물 수, 경험치
const ASTEROID_TYPES := [
	{"name": "작은 운석", "radius": 5.0, "hp": 1.0, "damage": 8.0, "speed_min": 45.0, "speed_max": 75.0, "minerals": 1, "xp": 1},
	{"name": "중간 운석", "radius": 9.0, "hp": 2.0, "damage": 14.0, "speed_min": 32.0, "speed_max": 55.0, "minerals": 1, "xp": 2},
	{"name": "큰 운석", "radius": 14.0, "hp": 3.0, "damage": 22.0, "speed_min": 22.0, "speed_max": 40.0, "minerals": 2, "xp": 4},
]
## 운석 체력은 이 시간(초)마다 기본값만큼 계단식으로 늘어난다 (0~75초 1배, 75초부터 2배, 150초부터 3배 …).
const ASTEROID_HP_GROWTH_TIME := 75.0
## 크기별 등장 비율. 시작할 때 → SPAWN_RAMP_TIME 뒤로 점점 바뀐다 (큰 운석이 늘어남).
const ASTEROID_WEIGHTS_START := [6.0, 3.0, 1.0]
const ASTEROID_WEIGHTS_LATE := [4.0, 4.0, 2.0]
## 운석은 우주선 쪽으로 날아오되, 이 각도(도)만큼 무작위로 빗나간다.
const ASTEROID_AIM_SPREAD_DEG := 25.0
## 운석 등장 간격: 시작 → SPAWN_RAMP_TIME에 걸쳐 최소 간격까지 줄어든다.
const SPAWN_INTERVAL_START := 1.0
const SPAWN_INTERVAL_MIN := 0.15
const SPAWN_RAMP_TIME := 240.0
## 운석은 화면 밖 이만큼 떨어진 곳에서 나타난다.
const SPAWN_MARGIN := 24.0
## 화면 대각선 반 길이의 이 배수보다 멀어진 운석은 없앤다.
const DESPAWN_DISTANCE_FACTOR := 1.6
## 동시에 존재할 수 있는 최대 운석 수 (휴대폰 성능 보호)
const MAX_ASTEROIDS := 250

# ── 자동 공격 ────────────────────────────────────────
## 발사 간격
const FIRE_INTERVAL := 0.55
## 이 거리 안에 있는 가장 가까운 운석을 자동으로 노린다.
const FIRE_RANGE := 170.0
const BULLET_SPEED := 260.0
const BULLET_DAMAGE := 1.0
const BULLET_RADIUS := 1.5
## 한 번에 쏘는 탄 수 (여러 발이면 부채꼴로 퍼짐)
const BULLET_COUNT := 1
const MULTI_SHOT_SPREAD_DEG := 12.0
## 탄은 사거리보다 이 비율만큼 더 날아가고 사라진다.
const BULLET_LIFETIME_FACTOR := 1.15

# ── 광물 ─────────────────────────────────────────────
## 등급별: 이름, 나올 비율, 가치. 탄으로 부순 운석에서만 떨어진다 (몸으로 부딪혀 부순 운석은 없음).
const MINERAL_GRADES := [
	{"name": "일반", "weight": 80.0, "value": 1},
	{"name": "희귀", "weight": 15.0, "value": 5},
	{"name": "영웅", "weight": 4.0, "value": 20},
	{"name": "전설", "weight": 1.0, "value": 100},
]
## 광물이 떨어질 때 운석 자리에서 흩어지는 최대 거리
const MINERAL_SCATTER := 6.0
## 자석 범위: 이 안에 들어온 광물은 우주선으로 끌려온다.
const MAGNET_RADIUS := 40.0
## 끌려오는 속도 (우주선보다 빨라야 따라잡는다)
const MAGNET_SPEED := 220.0
## 이 거리 안이면 줍는다.
const PICKUP_RADIUS := 8.0
## 바닥에 남아 있을 수 있는 최대 광물 수 (넘으면 오래된 것부터 사라짐)
const MAX_MINERALS := 300

# ── 경험치와 레벨업 강화 ─────────────────────────────
## 레벨업에 필요한 경험치 = XP_BASE + (현재 레벨 - 1) × XP_GROWTH  (1→2: 5, 2→3: 9, 3→4: 13 …)
## 경험치는 탄으로 운석을 부수면 얻는다 (크기별 xp는 ASTEROID_TYPES).
const XP_BASE := 5
const XP_GROWTH := 6
## 레벨업 때 보여 주는 강화 수
const UPGRADE_CHOICE_COUNT := 3
## 강화 목록: id, 이름, 최대 단계. 강화는 그 판에서만 유지된다.
const UPGRADES := [
	{"id": "fire_rate", "name": "공격 속도", "max": 5},
	{"id": "multishot", "name": "탄 개수", "max": 4},
	{"id": "damage", "name": "공격력", "max": 5},
	{"id": "magnet", "name": "자석 범위", "max": 5},
	{"id": "speed", "name": "이동 속도", "max": 5},
	{"id": "max_hp", "name": "최대 체력", "max": 5},
	{"id": "range", "name": "사거리", "max": 3},
]
## 강화 한 단계당 효과
const UP_FIRE_INTERVAL_MULT := 0.85  ## 발사 간격 ×0.85 (단계마다 곱함)
const UP_BULLET_COUNT_ADD := 1  ## 한 번에 쏘는 탄 +1
const UP_DAMAGE_ADD := 1.0  ## 탄 피해 +1
const UP_MAGNET_ADD := 0.4  ## 자석 범위 +40% (기본값 기준)
const UP_SPEED_ADD := 0.12  ## 이동 속도 +12% (기본값 기준)
const UP_MAX_HP_ADD := 20.0  ## 최대 체력 +20, 그만큼 회복
const UP_RANGE_ADD := 0.2  ## 사거리 +20% (기본값 기준)
## 모든 강화를 최대로 올리면 대신 나오는 "긴급 수리"의 회복량
const REPAIR_AMOUNT := 30.0
