class_name PickupCombo
extends RefCounted
## 광물 줍기 소리 규칙 (수치는 Juice.PICKUP_*):
## - PICKUP_GROUP_TIME초 안에 주운 광물은 소리 한 번으로 묶고, 그 묶음의 가장 높은 등급 소리를 낸다.
##   묶음 안에서 더 높은 등급이 들어오면 그건 따로 낸다 (희귀 이상이 일반에 묻히지 않게).
## - 최근 1초 재생 수가 PICKUP_RATE_REF보다 많으면 한 번의 음량을 낮춰 전체 크기를 비슷하게 한다 (전설은 PICKUP_LEGEND_FLOOR_DB까지만).
## - 묶음마다 1반음씩 PICKUP_COMBO_MAX_SEMITONES까지 오르고, PICKUP_COMBO_WINDOW초 끊기면 처음 음으로.
## (동시에 나는 줍기 소리 수 PICKUP_MAX_VOICES는 부르는 쪽이 지킨다)

const LEGEND := 3

var steps := 0
var _last := -INF
var _group_at := -INF
var _group_grade := -1
var _plays: Array[float] = []


## now(게임 시간)에 grades(이번 프레임에 주운 등급들)를 주웠을 때 낼 소리 {grade, db, semi}. 내지 않으면 빈 Dictionary.
func pick(now: float, grades: Array) -> Dictionary:
	var top := -1
	for g in grades:
		top = maxi(top, int(g))
	if top < 0:
		return {}
	var in_group := now - _group_at < Juice.PICKUP_GROUP_TIME
	if in_group and top <= _group_grade:
		return {}
	if not in_group:
		steps = mini(steps + 1, Juice.PICKUP_COMBO_MAX_SEMITONES) if now - _last <= Juice.PICKUP_COMBO_WINDOW else 0
		_group_at = now
	_last = now
	_group_grade = top
	_plays = _plays.filter(func(t: float) -> bool: return now - t < 1.0)
	_plays.append(now)
	var db := rate_db(_plays.size())
	if top >= LEGEND:
		db = maxf(db, Juice.PICKUP_LEGEND_FLOOR_DB)
	return {"grade": top, "db": db, "semi": steps}


## 1초에 count번 날 때 한 번의 음량 보정 (기준 횟수 이하면 0)
static func rate_db(count: int) -> float:
	return -10.0 * log(maxf(count / Juice.PICKUP_RATE_REF, 1.0)) / log(10.0)


## 반음 수 → 재생 속도 배율 (12반음 = 2배 = 한 옥타브)
static func pitch_of(semitones: int) -> float:
	return pow(2.0, semitones / 12.0)
