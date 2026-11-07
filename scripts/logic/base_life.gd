class_name BaseLife
extends RefCounted
## 살아 있는 기지: 진행 상황에 따라 바뀌는 모습 (연구소 안테나·불빛, 창고 앞 광물 더미)과 가끔 지나가는 운석.

## 광물 더미 단계를 나누는 보유 광물 (이 값 이상이면 한 단계 더 큼)
const PILE_STEPS := [1, 200, 800, 2500, 6000]
## 연구소 불빛은 연구 단계 합계마다 하나씩 (최대 연구 30단계 → 불빛 10개)
const LIGHTS_PER_RESEARCH := 3
## 안테나는 연구 단계 합계마다 하나씩 (최대 4개)
const ANTENNA_PER_RESEARCH := 6
const ANTENNA_MAX := 4
## 운석이 지나가는 간격(초) 범위
const METEOR_GAP := Vector2(5.0, 11.0)


## 기지 업그레이드 단계 합계
static func research_total(levels: Dictionary) -> int:
	var n := 0
	for u in Balance.BASE_UPGRADES:
		n += clampi(int(levels.get(u["id"], 0)), 0, int(u["max"]))
	return n


static func research_lights(levels: Dictionary) -> int:
	return research_total(levels) / LIGHTS_PER_RESEARCH


## 안테나 수: 처음 1개, 연구할수록 늘어남
static func antennas(levels: Dictionary) -> int:
	return mini(1 + research_total(levels) / ANTENNA_PER_RESEARCH, ANTENNA_MAX)


## 광물 더미 크기 0(없음) ~ PILE_STEPS.size()
static func pile_level(credits: int) -> int:
	var level := 0
	for step in PILE_STEPS:
		if credits >= step:
			level += 1
	return level


## 다음 운석까지 기다릴 시간
static func next_meteor_gap(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(METEOR_GAP.x, METEOR_GAP.y)
