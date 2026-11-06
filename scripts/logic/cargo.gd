class_name Cargo
extends RefCounted
## 화물칸: 광물 1개 = 1칸, 등급별 개수로 기억한다.
## 꽉 차면 더 좋은 광물을 주웠을 때만 가장 싼 광물을 버리고 바꿔 싣는다.

var capacity := Balance.CARGO_CAPACITY
## 등급별 개수 (Balance.MINERAL_GRADES 순서)
var counts := PackedInt32Array([0, 0, 0, 0])


func size() -> int:
	return total(counts)


## 등급별 개수 → 전체 개수
static func total(from: PackedInt32Array) -> int:
	var n := 0
	for c in from:
		n += c
	return n


func is_full() -> bool:
	return size() >= capacity


func value() -> int:
	return RunSim.value_of(counts)


## 광물 하나를 싣는다. 늘어난 가치를 돌려준다 (빈칸이면 그 광물 가치, 교체면 가치 차이, 못 실으면 0).
func add(grade: int) -> int:
	var v := grade_value(grade)
	if size() < capacity:
		counts[grade] += 1
		return v
	var low := lowest_grade()
	if low < 0 or grade <= low:
		return 0  # 같거나 낮은 등급: 화물칸은 그대로 (경험치는 RunSim이 따로 준다)
	counts[low] -= 1
	counts[grade] += 1
	return v - grade_value(low)


## 실려 있는 가장 낮은 등급 (비어 있으면 -1)
func lowest_grade() -> int:
	for i in counts.size():
		if counts[i] > 0:
			return i
	return -1


static func grade_value(grade: int) -> int:
	return int(Balance.MINERAL_GRADES[grade]["value"])


## 죽었을 때 남기는 비율: 기본 50%, 비상 보험 단계마다 +5%, 최대 75%
static func keep_ratio(insurance_level: int) -> float:
	return minf(Balance.DEATH_KEEP_BASE + Balance.DEATH_KEEP_PER_LEVEL * maxi(insurance_level, 0), Balance.DEATH_KEEP_MAX)


## 죽었을 때 남는 광물: 전체 개수 × ratio(내림)만큼 비싼 등급부터 남긴다.
static func preserved(from: PackedInt32Array, ratio: float) -> PackedInt32Array:
	var left := floori(total(from) * ratio + 0.000001)  # 0.55 × 20 = 10.999… 같은 부동소수 오차로 1개 덜 남지 않게
	var result := PackedInt32Array()
	result.resize(from.size())
	for i in range(from.size() - 1, -1, -1):
		var n := mini(from[i], left)
		result[i] = n
		left -= n
	return result
