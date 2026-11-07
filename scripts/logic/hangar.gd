class_name Hangar
extends RefCounted
## 격납고: 전투기 칸 목록과 지금 우주선 능력치(기지 업그레이드 반영). 전투기는 Balance.FIGHTERS에 있다.


## 격납고 칸 목록: 전투기가 있는 칸은 그 항목, 나머지는 잠긴 칸 {"locked": true}
static func slots() -> Array:
	var result := []
	for i in maxi(Balance.HANGAR_SLOTS, Balance.FIGHTERS.size()):
		result.append(Balance.FIGHTERS[i] if i < Balance.FIGHTERS.size() else {"locked": true})
	return result


## 지금 우주선 능력치 [{name, value(글자), ratio(0~1: 기지 업그레이드를 모두 올렸을 때 대비)}]
## 출격 규칙(RunSim.apply_base)으로 계산해서 실제 출격과 같다.
static func stats(levels: Dictionary) -> Array:
	var now := RunSim.new(1)
	now.apply_base(levels)
	var top := RunSim.new(1)
	var maxed := {}
	for u in Balance.BASE_UPGRADES:
		maxed[u["id"]] = u["max"]
	top.apply_base(maxed)
	var rows := [
		["체력", now.max_hp, top.max_hp, "%d"],
		["공격력", now.bullet_damage * 100.0, top.bullet_damage * 100.0, "%d%%"],
		["공격 속도", 1.0 / now.fire_interval, 1.0 / top.fire_interval, "%.1f발/초"],
		["이동 속도", now.move_speed, top.move_speed, "%d"],
		["화물칸", now.cargo.capacity, top.cargo.capacity, "%d칸"],
		["자석 범위", now.magnet_radius, top.magnet_radius, "%d"],
		["사망 보존", Cargo.keep_ratio(now.insurance_level) * 100.0, Cargo.keep_ratio(top.insurance_level) * 100.0, "%d%%"],
	]
	var result := []
	for r in rows:
		var value: float = r[1]
		var fmt: String = r[3]
		result.append({"name": r[0], "value": fmt % (value if fmt.contains(".") else roundi(value)), "ratio": clampf(value / maxf(r[2], 0.001), 0.0, 1.0)})
	return result
