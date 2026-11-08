class_name SoundThrottle
extends RefCounted
## 짧은 시간에 같은 종류 소리가 몰릴 때 (예: 후반에 운석이 한꺼번에 깨짐): 창(window초) 안에 이미 난 수만큼 작게 내고,
## max_count개가 넘으면 내지 않는다. 시간은 부르는 쪽이 넘긴다 (테스트에서 고정).

var window: float
var max_count: int
## 앞서 난 소리 하나마다 더할 음량 (음수 데시벨)
var step_db: float
var _times: Array[float] = []


func _init(window_sec: float, max_in_window: int, db_per_sound: float) -> void:
	window = window_sec
	max_count = max_in_window
	step_db = db_per_sound


## 지금(now) 낼 소리의 음량 보정(dB). 내지 말아야 하면 -INF.
func next_db(now: float) -> float:
	_times = _times.filter(func(t: float) -> bool: return now - t < window)
	if _times.size() >= max_count:
		return -INF
	var db := step_db * _times.size()
	_times.append(now)
	return db
