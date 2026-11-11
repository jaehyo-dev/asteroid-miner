class_name Hangar
extends RefCounted
## 격납고: 전투기 칸 목록과 지금 우주선 능력치(기지 업그레이드 반영). 전투기는 Balance.FIGHTERS에 있다.


## 격납고 칸 목록: 전투기가 있는 칸은 그 항목, 나머지는 잠긴 칸 {"locked": true}
static func slots() -> Array:
	var result := []
	for i in maxi(Balance.HANGAR_SLOTS, Balance.FIGHTERS.size()):
		result.append(Balance.FIGHTERS[i] if i < Balance.FIGHTERS.size() else {"locked": true})
	return result


## 지금 우주선 능력치 [{name, value(글자), num(비교용 수), ratio(0~1: 기지 업그레이드를 모두 올리고 가장 센 무기를 낀 것 대비)}]
## 출격 규칙(RunSim.apply_base)으로 계산해서 실제 출격과 같다. weapon을 주면 그 무기로 바꿨을 때 값 (격납고 ▲▼ 미리 보기)
static func stats(levels: Dictionary, save: SaveData = null, weapon := "") -> Array:
	var now := RunSim.new(1)
	now.apply_base(levels)
	if not Weapons.has(weapon):
		weapon = Weapons.equipped(save) if save != null else Weapons.DEFAULT
	now.set_weapon(weapon)
	if save != null:
		now.apply_codex(save)
	var maxed := {}
	for u in Balance.BASE_UPGRADES:
		maxed[u["id"]] = u["max"]
	var rows := _rows(now)
	var tops := []  # 줄마다 가장 큰 값 (모든 기지 업그레이드 + 그 줄이 가장 센 무기)
	for id in Weapons.ids():
		var t := _rows(_sim(maxed, id))
		for i in t.size():
			var v: float = 0.0 if is_inf(t[i][1]) else t[i][1]  # 무한은 눈금 기준에서 뺀다
			if i >= tops.size():
				tops.append(v)
			else:
				tops[i] = maxf(tops[i], v)
	var result := []
	for i in rows.size():
		var r: Array = rows[i]
		var value: float = r[1]
		var fmt: String = r[2]
		if is_inf(value):  # 무한(레일건 사거리): 막대 가득, ▲▼ 비교 안 함(num도 INF)
			result.append({"name": r[0], "value": "무한", "num": INF, "ratio": 1.0})
			continue
		result.append({"name": r[0], "value": (fmt % (value if fmt.contains(".") else roundi(value))) + r[3], "num": snappedf(value, 0.01),
			"ratio": clampf(value / maxf(tops[i], 0.001), 0.0, 1.0)})
	return result


static func _sim(levels: Dictionary, weapon: String) -> RunSim:
	var sim := RunSim.new(1)
	sim.apply_base(levels)
	sim.set_weapon(weapon)
	return sim


## 능력치 줄 [이름, 값, 글자 형식, 덧붙임]. 공격력은 한 발 피해 ×100 (산탄은 "×알갱이 수"), 공격 속도·사거리는 장착 무기 기준
static func _rows(sim: RunSim) -> Array:
	var pellets := int(sim.weapon.get("pellets", 1))
	return [
		["체력", sim.max_hp, "%d", ""],
		["공격력", sim.bullet_damage * float(sim.weapon["damage"]) * 100.0, "%d", "×%d" % pellets if pellets > 1 else ""],
		["공격 속도", 1.0 / sim.fire_interval, "%.1f발/초", ""],
		["사거리", INF if sim.weapon.get("hitscan", false) else sim.fire_range, "%d", ""],  # 레일건은 무한
		["이동 속도", sim.move_speed, "%d", ""],
		["화물칸", sim.cargo.capacity, "%d칸", ""],
		["자석 범위", sim.magnet_radius, "%d", ""],
		["사망 보존", sim.keep_ratio() * 100.0, "%d%%", ""],
	]
