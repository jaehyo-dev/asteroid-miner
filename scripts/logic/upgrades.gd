class_name Upgrades
extends RefCounted
## 레벨업 강화 규칙: 고를 수 있는 목록, 설명 문구, 강화 단계별 능력치 계산.
## 수치는 Balance에 있고, 여기서는 계산만 한다.

## 모든 강화를 최대로 올렸을 때 대신 나오는 선택지
const REPAIR := "repair"


## id → Balance.UPGRADES의 항목. 없으면 빈 Dictionary.
static func info(id: String) -> Dictionary:
	for u in Balance.UPGRADES:
		if u["id"] == id:
			return u
	return {}


static func display_name(id: String) -> String:
	if id == REPAIR:
		return "긴급 수리"
	return str(info(id).get("name", id))


## 강화 효과 설명 (Balance 수치로 만든다)
static func describe(id: String) -> String:
	match id:
		"fire_rate":
			return "발사 간격 -%d%%" % roundi((1.0 - Balance.UP_FIRE_INTERVAL_MULT) * 100.0)
		"multishot":
			return "한 번에 %d발 더" % Balance.UP_BULLET_COUNT_ADD
		"damage":
			return "탄 피해 +%s" % _num(Balance.UP_DAMAGE_ADD)
		"magnet":
			return "광물 끄는 범위 +%d%%" % roundi(Balance.UP_MAGNET_ADD * 100.0)
		"speed":
			return "이동 속도 +%d%% (화물이 무거워도 빠르게)" % roundi(Balance.UP_SPEED_ADD * 100.0)
		"max_hp":
			return "최대 체력 +%s, 그만큼 회복" % _num(Balance.UP_MAX_HP_ADD)
		"range":
			return "공격 사거리 +%d%%" % roundi(Balance.UP_RANGE_ADD * 100.0)
		REPAIR:
			return "체력 %s 회복" % _num(Balance.REPAIR_AMOUNT)
	return ""


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)


## 아직 최대 단계가 아닌 강화 id 목록
static func available(levels: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = []
	for u in Balance.UPGRADES:
		if int(levels.get(u["id"], 0)) < int(u["max"]):
			result.append(u["id"])
	return result


## 레벨업 선택지: 고를 수 있는 강화 중 서로 다른 것을 무작위로 count개. 하나도 없으면 긴급 수리.
static func roll_choices(random: RandomNumberGenerator, levels: Dictionary, count: int) -> PackedStringArray:
	var pool := available(levels)
	var result: PackedStringArray = []
	while result.size() < count and not pool.is_empty():
		var i := random.randi_range(0, pool.size() - 1)
		result.append(pool[i])
		pool.remove_at(i)
	if result.is_empty():
		result.append(REPAIR)
	return result


## 레벨업에 필요한 경험치 (현재 레벨 → 다음 레벨)
static func xp_to_next(level: int) -> int:
	return Balance.XP_BASE + (maxi(level, 1) - 1) * Balance.XP_GROWTH
