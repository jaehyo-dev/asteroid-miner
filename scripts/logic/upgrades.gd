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
## 진화 카드 (v0.8.0 5단계): 다섯 등급과 다른 특별한 모양. 뽑기 등급이 아니라 진화 조건이 맞으면 넣는다
const EVOLUTION := 5


## id → Balance의 강화 항목 (수치·효과·레전드리 전부에서 찾는다). 없으면 빈 Dictionary.
static func info(id: String) -> Dictionary:
	for list in [Balance.UPGRADES, Balance.EFFECT_UPGRADES, Balance.LEGENDARY_UPGRADES, Balance.SUB_WEAPONS, Balance.EVOLUTIONS]:
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
			return "탄 피해 +%d%%" % roundi(v * 100.0 / Balance.BULLET_DAMAGE)
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


## 이미 가진 효과 강화 카드의 "지금 → 다음" 문구 (bonus: 지금 누적값). 다음 값은 add_bonus를 그대로 돌려 계산한다.
static func describe_next(id: String, grade: int, bonus: Dictionary, short: bool = false) -> String:
	var next := bonus.duplicate()
	add_bonus(next, id, grade)
	var now_v := float(bonus.get(id, 0.0))
	var next_v := float(next.get(id, 0.0))
	match id:
		"pierce":
			return "관통 %d개 → %d개" % [now_v, next_v]
		"ricochet":
			return "튕김 %d번 → %d번" % [now_v, next_v] if short else "튕김 %d번 → %d번 (피해 70%%)" % [now_v, next_v]
		"explosive":
			var r := "폭발 반경 %d → %d" % [bonus.get("explosive_radius", 0.0), next["explosive_radius"]]
			var a := roundi(float(bonus.get("explosive_share", 0.0)) * 100.0)
			var b := roundi(float(next["explosive_share"]) * 100.0)
			return r if short or a == b else r + ", 피해 %d%% → %d%%" % [a, b]
		"crit":
			return "치명타 %d%% → %d%%" % [roundi(now_v * 100.0), roundi(next_v * 100.0)] if short else "치명타 확률 %d%% → %d%% (2배 피해)" % [roundi(now_v * 100.0), roundi(next_v * 100.0)]
		"shield":
			return "%d초 → %d초마다 막음" % [now_v, next_v] if short else "%d초 → %d초마다 피해 1번을 막음" % [now_v, next_v]
		"drone":
			return "드론 %d기 → %d기" % [now_v, next_v] if short else "드론 %d기 → %d기 (함께 공격)" % [now_v, next_v]
		"mining_laser":
			return "운석 광물 +%d%% → +%d%%" % [roundi(now_v * 100.0), roundi(next_v * 100.0)]
		"chill", "ram", "trail", "charge", "vein":  # 짝 스킬: 느려짐·전하는 %, 나머지는 피해 ×100
			var pct: bool = id in ["chill", "charge"]
			var fmt: String = {"chill": "느려짐 %s → %s", "ram": "부딪힘 피해 %s → %s", "trail": "불꽃 초당 피해 %s → %s", "charge": "쌓일 때 %s → %s", "vein": "충격파 피해 %s → %s"}[id]
			if short:
				fmt = {"chill": "느려짐 %s → %s", "ram": "피해 %s → %s", "trail": "불꽃 %s → %s", "charge": "%s → %s", "vein": "충격파 %s → %s"}[id]
			var unit := "%d%%" if pct else "%d"
			return fmt % [unit % roundi(now_v * 100.0), unit % roundi(next_v * 100.0)]
	return describe(id, grade, short)


## 시간에 따른 등급 확률: RISK_RAMP_TIME까지 직선으로 오르고 그 뒤로는 고정
## epic_bonus: 고급 회로. 합의 이 비율만큼을 노멀에서 에픽으로 옮긴다
static func grade_weights(time: float, epic_bonus := 0.0) -> PackedFloat32Array:
	var k := clampf(time / Balance.RISK_RAMP_TIME, 0.0, 1.0)
	var result := PackedFloat32Array()
	var total := 0.0
	for i in Balance.GRADE_WEIGHTS_START.size():
		result.append(lerpf(Balance.GRADE_WEIGHTS_START[i], Balance.GRADE_WEIGHTS_END[i], k))
		total += result[i]
	var moved := minf(total * epic_bonus, result[NORMAL])
	result[NORMAL] -= moved
	result[EPIC] += moved
	return result


## 등급 하나 뽑기
static func roll_grade(random: RandomNumberGenerator, time: float, epic_bonus := 0.0) -> int:
	return random.rand_weighted(grade_weights(time, epic_bonus))


## 효과 강화의 누적 상한 (이만큼 쌓였으면 더 찍어도 0이라 카드를 뽑지 않는다)
static func cap_of(id: String) -> float:
	match id:
		"pierce":
			return Balance.PIERCE_CAP
		"ricochet":
			return Balance.RICOCHET_CAP
		"crit":
			return Balance.CRIT_CAP
		"drone":
			return Balance.DRONE_CAP
		"mining_laser":
			return Balance.MINING_CAP
		"chill":
			return Balance.CHILL_CAP
		"ram":
			return Balance.RAM_CAP
		"trail":
			return Balance.TRAIL_CAP
		"charge":
			return Balance.CHARGE_CAP
		"vein":
			return Balance.VEIN_CAP
	return INF


## 목록 중 아직 최대 단계가 아니고 상한에 닿지 않은 강화 id (bonus: 지금 누적값).
## 짝 스킬(pair)은 짝 보조 무기(subs: id → 단계)를 가졌을 때만 들어가고 PAIR_SKILL_WEIGHT번 들어간다. pair_free면 없어도 1번
static func available_in(list: Array, levels: Dictionary, bonus: Dictionary = {}, subs: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = []
	for u in list:
		var copies := 1
		if u.has("pair"):
			copies = Balance.PAIR_SKILL_WEIGHT if subs.has(u["pair"]) else (1 if u.get("pair_free", false) else 0)
		if copies == 0:
			continue
		if u.has("blocked_by") and levels.has(u["blocked_by"]):
			continue  # 더 강한 레전드리를 이미 가졌으면 쓸모없는 카드는 뺀다 (궤도 관통 가속기 → 관통탄)
		if float(bonus.get(u["id"], 0.0)) >= cap_of(u["id"]):
			continue
		if int(u["max"]) <= 0 or int(levels.get(u["id"], 0)) < int(u["max"]):
			for i in copies:
				result.append(u["id"])
	return result


## 목록에서 무작위 하나를 빼서 돌려준다 (가중치로 여러 번 들어간 id는 모두 뺀다: 한 화면에 같은 카드 두 장 없게)
static func _take(random: RandomNumberGenerator, pool: PackedStringArray) -> String:
	var i := random.randi_range(0, pool.size() - 1)
	var id := pool[i]
	while pool.has(id):
		pool.remove_at(pool.find(id))
	return id


## 레벨업 카드 뽑기: 서로 다른 강화 count장. 최대 단계는 빼고, 남은 강화가 없으면 있는 만큼만 (수리는 항상 남는다).
## effects_on이 꺼져 있으면 효과·레전드리는 나오지 않고, 레전드리로 뽑힌 칸은 유니크가 된다.
## force_effect: 화면에 효과 카드가 없으면 레전드리가 아닌 한 장을 에픽 효과로 바꾼다 (효과 카드 보정).
## repair_on: 수리를 뽑기에 넣을지 (체력이 넉넉하면 빼고, 고를 카드가 없으면 빈 목록 = 건너뛰기만).
## bonus: 지금 누적값. 상한에 닿은 효과는 빼고, 이미 가진 효과 카드에는 "지금 → 다음" 문구(desc·short)를 붙인다.
static func roll_choices(random: RandomNumberGenerator, levels: Dictionary, count: int, time: float = 0.0, effects_on: bool = Balance.EFFECT_CARDS_ENABLED, force_effect: bool = false, repair_on: bool = true, epic_bonus := 0.0, bonus: Dictionary = {}, skip: Array = [], subs: Dictionary = {}) -> Array:
	var stats := available_in(Balance.UPGRADES, levels)
	if not repair_on and stats.has(REPAIR):
		stats.remove_at(stats.find(REPAIR))
	var effects := available_in(Balance.EFFECT_UPGRADES, levels, bonus, subs) if effects_on else PackedStringArray()
	var legends := available_in(Balance.LEGENDARY_UPGRADES, levels) if effects_on else PackedStringArray()
	for id in skip:  # 장착한 기본 무기에 효과가 없는 카드 (Balance.WEAPONS의 no_cards)
		for pool: PackedStringArray in [stats, effects, legends]:
			while pool.has(id):
				pool.remove_at(pool.find(id))
	var result: Array = []
	var has_legend := false
	for i in count:
		var grade := roll_grade(random, time, epic_bonus)
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
	for c in result:
		if is_effect(c["id"]) and levels.has(c["id"]):
			c["desc"] = describe_next(c["id"], c["grade"], bonus)
			c["short"] = describe_next(c["id"], c["grade"], bonus, true)
	return result


## 카드에 붙은 문구가 있으면 그것, 없으면 기본 문구
static func card_text(card: Dictionary, short: bool = false) -> String:
	return str(card.get("short" if short else "desc", describe(card["id"], card["grade"], short)))


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
		"chill":
			add.call(Balance.CHILL_ADD, Balance.CHILL_CAP)
		"ram":
			add.call(Balance.RAM_ADD, Balance.RAM_CAP)
		"trail":
			add.call(Balance.TRAIL_ADD, Balance.TRAIL_CAP)
		"charge":
			add.call(Balance.CHARGE_ADD, Balance.CHARGE_CAP)
		"vein":
			add.call(Balance.VEIN_ADD, Balance.VEIN_CAP)
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
