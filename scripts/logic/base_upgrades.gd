class_name BaseUpgrades
extends RefCounted
## 기지 공용 업그레이드 규칙: 비용, 구매, 설명 문구. 수치는 Balance.BASE_UPGRADES에 있다.
## 업그레이드 단계는 SaveData.upgrades(id → 단계)에 저장된다.


## id → Balance.BASE_UPGRADES의 항목. 없으면 빈 Dictionary.
static func info(id: String) -> Dictionary:
	for u in Balance.BASE_UPGRADES:
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
			return "이동 속도 +%d%%" % roundi(Balance.BASE_SPEED_ADD * 100.0)
		"cargo":
			return "화물칸 +%d칸" % Balance.BASE_CARGO_ADD
		"insurance":
			return "사망 보존 +%d%%" % roundi(Balance.DEATH_KEEP_PER_LEVEL * 100.0)
		"magnet":
			return "자석 범위 +%d%%" % roundi(Balance.BASE_MAGNET_ADD * 100.0)
	return ""
