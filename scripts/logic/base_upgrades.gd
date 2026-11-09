class_name BaseUpgrades
extends RefCounted
## 기지 공용 업그레이드 규칙: 비용, 구매, 설명 문구. 수치는 Balance.BASE_UPGRADES에 있다.
## 업그레이드 단계는 SaveData.upgrades(id → 단계)에 저장된다.


## id → Balance.BASE_UPGRADES의 항목. 없으면 빈 Dictionary.
static func info(id: String) -> Dictionary:
	for list in [Balance.BASE_UPGRADES, Balance.RESEARCH_NODES]:
		for u in list:
			if u["id"] == id:
				return u
	return {}


static func max_level(id: String) -> int:
	return int(info(id).get("max", 0))


## level 단계에서 다음 단계로 올리는 비용
static func cost(id: String, level: int) -> int:
	return roundi(float(info(id)["cost"]) * pow(Balance.BASE_COST_GROWTH, level))


## 지금 살 수 있는지 (최대 단계가 아니고 광물이 충분함)
static func can_buy(save: SaveData, id: String) -> bool:
	var lv := save.level_of(id)
	return lv < max_level(id) and save.credits >= cost(id, lv)


## 한 단계 산다. 성공하면 true (광물이 빠지고 단계가 오른다).
static func buy(save: SaveData, id: String) -> bool:
	if not can_buy(save, id):
		return false
	var lv := save.level_of(id)
	save.credits -= cost(id, lv)
	save.upgrades[id] = lv + 1
	return true


## 한 단계당 효과 설명 (Balance 수치로 만든다)
static func describe(id: String) -> String:
	match id:
		"damage":
			return "탄 피해 +%d%%" % roundi(Balance.BASE_DAMAGE_MULT_ADD * 100.0)
		"max_hp":
			return "최대 체력 +%d" % roundi(Balance.BASE_MAX_HP_ADD)
		"speed":
			return "이동 속도 +%d%% (화물이 무거워도 빠르게)" % roundi(Balance.BASE_SPEED_ADD * 100.0)
		"cargo":
			return "화물칸 +%d칸" % Balance.BASE_CARGO_ADD
		"insurance":
			return "사망 보존 +%d%%" % roundi(Balance.DEATH_KEEP_PER_LEVEL * 100.0)
		"magnet":
			return "자석 범위 +%d%%" % roundi(Balance.BASE_MAGNET_ADD * 100.0)
	return ""


## 연구소 카드에 덧붙이는 짧은 도움말 (없으면 빈 문자열)
static func note(id: String) -> String:
	return "무거운 화물에도 효과" if id == "speed" else ""


## 기지 업그레이드 level 단계일 때의 능력치 값 (출격 규칙 RunSim.apply_base로 계산해서 실제와 같다)
static func stat_value(id: String, level: int) -> float:
	var sim := RunSim.new(1)
	sim.apply_base({id: level})
	match id:
		"damage":
			return sim.bullet_damage / Balance.BULLET_DAMAGE * 100.0
		"max_hp":
			return sim.max_hp
		"speed":
			return sim.move_speed
		"cargo":
			return sim.cargo.capacity
		"insurance":
			return Cargo.keep_ratio(sim.insurance_level) * 100.0
		"magnet":
			return sim.magnet_radius
	return 0.0


## 능력치 이름과 단위: "체력 120", "사망 보존 55%"
static func stat_text(id: String, level: int) -> String:
	var v := roundi(stat_value(id, level))
	match id:
		"damage":
			return "탄 피해 %d%%" % v
		"max_hp":
			return "체력 %d" % v
		"speed":
			return "속도 %d" % v
		"cargo":
			return "화물칸 %d칸" % v
		"insurance":
			return "사망 보존 %d%%" % v
		"magnet":
			return "자석 %d" % v
	return ""


## 연구소 카드의 바뀌는 값: "체력 120 → 130" (최대면 지금 값만)
static func change_text(id: String, level: int) -> String:
	var now := stat_text(id, level)
	if level >= max_level(id):
		return now
	var next := stat_text(id, level + 1)
	return "%s → %s" % [now, next.substr(next.rfind(" ") + 1)]


## 단계 칸: 3/5 → "■■■□□"
static func pips(id: String, level: int) -> String:
	return "■".repeat(level) + "□".repeat(maxi(max_level(id) - level, 0))
