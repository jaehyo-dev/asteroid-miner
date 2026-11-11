class_name Weapons
extends RefCounted
## 기본 무기 규칙: 목록, 구매(격납고, 광물), 장착, 격납고 능력치 칸. 화면과 분리해 테스트한다. 수치는 Balance.WEAPONS.

const DEFAULT := "pulse"
## 확인용 숨은 스위치(웹 주소 ?fxtest): 모든 무기 해금 + 판 중 숫자키 1~5로 무기 바꾸기.
## shortcut: v0.8.0 배포 전에 이 스위치와 쓰는 곳(app.gd·run.gd)을 지운다 (review/PLAN_v0.8.0.md 11장)
static var test_mode := false


static func ids() -> Array:
	return Balance.WEAPONS.map(func(w: Dictionary) -> String: return w["id"])


## 무기 표 한 줄. 모르는 id면 펄스 연사포
static func info(id: String) -> Dictionary:
	for w: Dictionary in Balance.WEAPONS:
		if w["id"] == id:
			return w
	return Balance.WEAPONS[0]


static func has(id: String) -> bool:
	return ids().has(id)


## 격납고 구매 가격 (광물). 처음부터 있는 무기는 0
static func cost(id: String) -> int:
	return int(info(id).get("cost", 0))


static func unlocked(save: SaveData, id: String) -> bool:
	return test_mode or cost(id) == 0 or save.weapons_owned.has(id)


## 격납고에서 산다: 광물을 내고 바로 장착한다. 모르는 무기·이미 있음·광물 부족이면 false
static func buy(save: SaveData, id: String) -> bool:
	if not has(id) or unlocked(save, id) or save.credits < cost(id):
		return false
	save.credits -= cost(id)
	save.weapons_owned.append(id)
	save.weapon = id
	return true


## 장착한 무기 (해금이 풀렸거나 모르는 값이면 기본 무기)
static func equipped(save: SaveData) -> String:
	return save.weapon if has(save.weapon) and unlocked(save, save.weapon) else DEFAULT


## 장착. 잠겼거나 모르는 무기면 false
static func equip(save: SaveData, id: String) -> bool:
	if not has(id) or not unlocked(save, id):
		return false
	save.weapon = id
	return true


## 격납고 능력치 4칸 [{name, level(1~5)}]: 공격력(한 번 쏠 때 피해 합), 사거리, 연사, 채굴량. 모든 화면이 이 순서·이름을 쓴다
static func bars(id: String) -> Array:
	var w := info(id)
	var top_power := 0.0
	var top_range := 0.0
	for o: Dictionary in Balance.WEAPONS:
		top_power = maxf(top_power, _power(o))
		top_range = maxf(top_range, float(o["range"]))  # 레일건 range(300)도 눈금 기준으로 그대로 둔다 (다른 무기 막대가 안 바뀌게)
	var rate := 1.0 / float(w["interval"])
	var rate_lv := 1
	for step: float in Balance.WEAPON_RATE_STEPS:
		if rate > step:
			rate_lv += 1
	var lv := func(r: float) -> int: return clampi(roundi(r * 5.0), 1, 5)
	return [
		{"name": "공격력", "level": lv.call(_power(w) / top_power)},
		{"name": "사거리", "level": 5 if w.get("hitscan", false) else lv.call(float(w["range"]) / top_range)},  # 레일건은 사거리 무한
		{"name": "연사", "level": rate_lv},
		{"name": "채굴량", "level": clampi(roundi((float(w["mining"]) - 0.5) * 4.0) + 1, 1, 5)},
	]


static func _power(w: Dictionary) -> float:
	return float(w["damage"]) * int(w.get("pellets", 1))


## 화면에 보여 줄 피해 숫자: 격납고 공격력과 같은 단위(실제 피해 × 100). 채굴 빔(0.22)처럼 작은 피해도 0이 되지 않게 최소 1
static func shown_damage(damage: float) -> int:
	return maxi(roundi(damage * 100.0), 1) if damage > 0.0 else 0
