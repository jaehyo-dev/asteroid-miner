class_name PickupCombo
extends RefCounted
## 광물 연속 줍기 음 높이: 앞 줍기에서 Juice.PICKUP_COMBO_WINDOW 안에 또 주우면 1반음씩 올라간다 (최대 PICKUP_COMBO_MAX_SEMITONES).

var steps := 0
var _last := -INF


## now(게임 시간)에 주웠을 때 올릴 반음 수를 돌려준다. 첫 줍기·끊긴 뒤는 0.
func pick(now: float) -> int:
	steps = mini(steps + 1, Juice.PICKUP_COMBO_MAX_SEMITONES) if now - _last <= Juice.PICKUP_COMBO_WINDOW else 0
	_last = now
	return steps


## 반음 수 → 재생 속도 배율 (12반음 = 2배 = 한 옥타브)
static func pitch_of(semitones: int) -> float:
	return pow(2.0, semitones / 12.0)
