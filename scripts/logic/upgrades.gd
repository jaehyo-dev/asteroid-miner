class_name Upgrades
extends RefCounted
## 레벨업 강화 규칙: 등급 확률, 카드 뽑기, 설명 문구, 강화 누적. 수치는 Balance에 있고, 여기서는 계산만 한다.
## 카드 하나는 {"id": 강화 id, "grade": 등급}이다.

## 수리: 단계가 없고, 체력이 낮을 때 뽑기에 들어간다. 다른 강화가 모두 최대면 혼자 나온다
const REPAIR := "repair"

const NORMAL := 0
const RARE := 1
const EPIC := 2
const UNIQUE := 3
const LEGENDARY := 4


## id → Balance의 강화 항목 (수치·효과·레전드리 전부에서 찾는다). 없으면 빈 Dictionary.
static func info(id: String) -> Dictionary:
	for list in [Balance.UPGRADES, Balance.EFFECT_UPGRADES, Balance.LEGENDARY_UPGRADES]:
		for u in list:
			if u["id"] == id:
				return u
	return {}


static func display_name(id: String) -> String:
	return str(info(id).get("name", id))


## 종류 표 (공격·방어·이동·채굴·드론)
static func kind_of(id: String) -> String:
	return str(info(id).get("kind", ""))


## 최대 단계 (0이면 단계 없음)
static func max_stage(id: String) -> int:
	return int(info(id).get("max", 0))


## 수치 강화의 등급별 수치. 레전드리는 수치 강화에 없다.
static func value(id: String, grade: int) -> float:
	var values: Array = info(id).get("values", [])
	return float(values[mini(grade, values.size() - 1)]) if not values.is_empty() else 0.0


## 강화 효과 설명. short면 폰 2줄에 맞춘 짧은 문구
static func describe(id: String, grade: int = NORMAL, short: bool = false) -> String:
	var u := info(id)
	if u.has("desc"):  # 효과·레전드리는 문구가 데이터에 있다
		var key := "short" if short else "desc"
		var text = u[key]
		return text[grade - EPIC] if text is Array else text
	var v := value(id, grade)
	match id:
		"fire_rate":
			return "발사 속도 +%s%%" % _num(v * 100.0)
		"multishot":
			var extra: float = u["bonus_damage"][grade]
			if short:
				return "%d발 더" % int(v) if extra <= 0.0 else "%d발 더, 피해 +%d%%" % [int(v), roundi(extra * 100.0)]
			return "한 번에 %d발 더" % int(v) if extra <= 0.0 else "한 번에 %d발 더, 탄 피해 +%d%%" % [int(v), roundi(extra * 100.0)]
		"damage":
			return "탄 피해 +%s" % _num(v)
		"range":
			return "공격 사거리 +%s%%" % _num(v * 100.0)
		"max_hp":
			return "체력 +%s, 회복" % _num(v) if short else "최대 체력 +%s, 그만큼 회복" % _num(v)
		"repair":
			return "체력 %s 회복" % _num(v)
		"speed":
			if short:
				return "이동 속도 +%s%%" % _num(v * 100.0)
			return "이동 속도 +%s%% (화물이 무거워도 빠르게)" % _num(v * 100.0)
		"magnet":
			return "끄는 범위 +%s%%" % _num(v * 100.0) if short else "광물 끄는 범위 +%s%%" % _num(v * 100.0)
	return ""


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))


## 시간에 따른 등급 확률: RISK_RAMP_TIME까지 직선으로 오르고 그 뒤로는 고정
static func grade_weights(time: float) -> PackedFloat32Array:
	var k := clampf(time / Balance.RISK_RAMP_TIME, 0.0, 1.0)
	var result := PackedFloat32Array()
	for i in Balance.GRADE_WEIGHTS_START.size():
		result.append(lerpf(Balance.GRADE_WEIGHTS_START[i], Balance.GRADE_WEIGHTS_END[i], k))
	return result


## 등급 하나 뽑기
static func roll_grade(random: RandomNumberGenerator, time: float) -> int:
	return random.rand_weighted(grade_weights(time))


## 목록 중 아직 최대 단계가 아닌 강화 id
static func available_in(list: Array, levels: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = []
	for u in list:
		if u.has("blocked_by") and levels.has(u["blocked_by"]):
			continue  # 더 강한 레전드리를 이미 가졌으면 쓸모없는 카드는 뺀다 (궤도 관통 가속기 → 관통탄)
		if int(u["max"]) <= 0 or int(levels.get(u["id"], 0)) < int(u["max"]):
			result.append(u["id"])
	return result


## 목록에서 무작위 하나를 빼서 돌려준다
static func _take(random: RandomNumberGenerator, pool: PackedStringArray) -> String:
	var i := random.randi_range(0, pool.size() - 1)
	var id := pool[i]
	pool.remove_at(i)
	return id


## 레벨업 카드 뽑기: 서로 다른 강화 count장. 최대 단계는 빼고, 남은 강화가 없으면 있는 만큼만 (수리는 항상 남는다).
## effects_on이 꺼져 있으면 효과·레전드리는 나오지 않고, 레전드리로 뽑힌 칸은 유니크가 된다.
## force_effect: 화면에 효과 카드가 없으면 레전드리가 아닌 한 장을 에픽 효과로 바꾼다 (효과 카드 보정).
## repair_on: 수리를 뽑기에 넣을지 (체력이 넉넉할 때 빈칸이 되지 않게). 다른 수치 강화가 다 찼으면 그래도 나온다.
static func roll_choices(random: RandomNumberGenerator, levels: Dictionary, count: int, time: float = 0.0, effects_on: bool = Balance.EFFECT_CARDS_ENABLED, force_effect: bool = false, repair_on: bool = true) -> Array:
	var stats := available_in(Balance.UPGRADES, levels)
	if not repair_on and stats.size() > 1:
		stats.remove_at(stats.find(REPAIR))
	var effects := available_in(Balance.EFFECT_UPGRADES, levels) if effects_on else PackedStringArray()
	var legends := available_in(Balance.LEGENDARY_UPGRADES, levels) if effects_on else PackedStringArray()
	var result: Array = []
	var has_legend := false
	for i in count:
		var grade := roll_grade(random, time)
		if grade == LEGENDARY and (has_legend or legends.is_empty()):
			grade = UNIQUE  # 레전드리는 한 화면에 1장까지
		if grade == LEGENDARY:
			has_legend = true
			result.append({"id": _take(random, legends), "grade": grade})
		elif not effects.is_empty() and grade >= EPIC and (random.randf() < Balance.EFFECT_SHARE or stats.is_empty()):
			result.append({"id": _take(random, effects), "grade": grade})
		elif not stats.is_empty():
			result.append({"id": _take(random, stats), "grade": grade})
		elif not effects.is_empty():
			result.append({"id": _take(random, effects), "grade": maxi(grade, EPIC)})  # 수치 강화가 다 찼으면 효과 카드로
	if force_effect and not effects.is_empty() and not has_effect(result):
		var slots: Array = []
		for i in result.size():
			if result[i]["grade"] != LEGENDARY:
				slots.append(i)
		if not slots.is_empty():
			result[slots[random.randi_range(0, slots.size() - 1)]] = {"id": _take(random, effects), "grade": EPIC}
	return result


static func is_effect(id: String) -> bool:
	for u in Balance.EFFECT_UPGRADES:
		if u["id"] == id:
			return true
	return false


## 화면에 효과 카드가 있는지 (레전드리는 보정에서 효과 카드로 치지 않는다)
static func has_effect(cards: Array) -> bool:
	for c in cards:
		if is_effect(c["id"]):
			return true
	return false


## 고른 강화를 누적값에 더한다. 발사 속도도 더한다 (곱으로 쌓으면 유니크가 겹칠 때 기지 최대 봇이 10분을 넘겨 살아남음).
## 효과 강화는 등급(에픽·유니크)마다 값이 다르고 상한이 있다. 레전드리는 켜짐(1.0)만 기록한다.
static func add_bonus(bonus: Dictionary, id: String, grade: int) -> void:
	var i := clampi(grade - EPIC, 0, 1)
	var add := func(table: Array, cap: float) -> void: bonus[id] = minf(float(bonus.get(id, 0.0)) + table[i], cap)
	match id:
		"multishot":
			bonus[id] = float(bonus.get(id, 0.0)) + value(id, grade)
			bonus["multishot_damage"] = float(bonus.get("multishot_damage", 0.0)) + float(info(id)["bonus_damage"][grade])
		"pierce":
			add.call(Balance.PIERCE_ADD, Balance.PIERCE_CAP)
		"ricochet":
			add.call(Balance.RICOCHET_ADD, Balance.RICOCHET_CAP)
		"crit":
			add.call(Balance.CRIT_ADD, Balance.CRIT_CAP)
		"drone":
			add.call(Balance.DRONE_ADD, Balance.DRONE_CAP)
		"mining_laser":
			add.call(Balance.MINING_ADD, Balance.MINING_CAP)
		"explosive":
			var had: float = bonus.get("explosive_radius", 0.0)
			bonus["explosive_radius"] = Balance.EXPLOSIVE_RADIUS[i] if had <= 0.0 else maxf(had, Balance.EXPLOSIVE_RADIUS[i]) + Balance.EXPLOSIVE_STAGE_RADIUS
			bonus["explosive_share"] = maxf(float(bonus.get("explosive_share", 0.0)), Balance.EXPLOSIVE_SHARE[i])
		"shield":
			var had: float = bonus.get(id, 0.0)
			bonus[id] = Balance.SHIELD_INTERVAL[i] if had <= 0.0 else maxf(minf(had, Balance.SHIELD_INTERVAL[i]) - Balance.SHIELD_STAGE_CUT, Balance.SHIELD_MIN_INTERVAL)
		"orbit_pierce", "chain_matrix", "overload", "tractor_beacon":
			bonus[id] = 1.0
		_:
			bonus[id] = float(bonus.get(id, 0.0)) + value(id, grade)


## 레벨업에 필요한 경험치 (현재 레벨 → 다음 레벨)
static func xp_to_next(level: int) -> int:
	var over := maxi(level - Balance.XP_SOFT_LEVEL, 0)
	return Balance.XP_BASE + (maxi(level, 1) - 1) * Balance.XP_GROWTH + over * over * Balance.XP_SOFT_GROWTH
