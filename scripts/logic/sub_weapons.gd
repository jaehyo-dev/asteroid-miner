class_name SubWeapons
extends RefCounted
## 보조 무기 6종 (v0.8.0): 기본 무기와 따로 자동으로 동작한다. 레벨업 카드로 얻고 같은 카드로 1단계씩 오른다(1~5단계).
## 수치는 Balance.SUB_WEAPONS·SUB_*. 화면과 분리되어 있어 RunSim.update()만으로 테스트할 수 있다.
## 피해는 RunSim.sub_hit()으로 주고, 부서진 적은 RunSim이 기본 무기 탄과 같은 자리에서 처리한다(광물·경험치 그대로).
## 그리기용 상태(missiles, holes, mines, waves, zaps)는 SubWeaponFx가 읽기만 한다.

## 가진 보조 무기: id → 단계 (얻은 순서대로, 판 화면 칸 순서)
var stages: Dictionary = {}
## 날아가는 유도 미사일 {pos, vel, target, life, damage, blast}
var missiles: Array[Dictionary] = []
## 블랙홀 {pos, from, t(던진 뒤 지난 시간), time(유지 시간), radius, dps}
var holes: Array[Dictionary] = []
## 놓인 기뢰 {pos, t}
var mines: Array[Dictionary] = []
## 퍼지는 파동 {pos, r, radius, damage, hits}
var waves: Array[Dictionary] = []
## 톱날 각도 (그리기·판정 같은 값)
var saw_angle := 0.0
var _timers: Dictionary = {}
## 진화한 보조 무기 id → true (v0.8.0 5단계, Balance.EVOLUTIONS). 진화해도 stages의 5단계 수치를 그대로 쓴다
var evolved: Dictionary = {}
## 연쇄 폭격: 이어 터질 폭발 {pos, left(남은 횟수), t(터질 때까지), damage, blast, hit(이미 터진 자리 근처 적)}
var chains: Array[Dictionary] = []
## 과충전 방전: 쌓인 전하 (번개가 맞힌 수)
var coil_charge := 0


static func ids() -> PackedStringArray:
	var result: PackedStringArray = []
	for w in Balance.SUB_WEAPONS:
		result.append(w["id"])
	return result


static func info(id: String) -> Dictionary:
	for w in Balance.SUB_WEAPONS:
		if w["id"] == id:
			return w
	return {}


static func is_sub(id: String) -> bool:
	return not info(id).is_empty()


## 그 단계(1~5)의 수치
static func stat(id: String, key: String, stage: int) -> float:
	var list: Array = info(id)["stats"][key]
	return float(list[clampi(stage, 1, list.size()) - 1])


## 진화 정보 (진화 id로)
static func evo_info(evo_id: String) -> Dictionary:
	for e in Balance.EVOLUTIONS:
		if e["id"] == evo_id:
			return e
	return {}


## 진화 정보 (보조 무기 id로)
static func evo_of(sub_id: String) -> Dictionary:
	for e in Balance.EVOLUTIONS:
		if e["sub"] == sub_id:
			return e
	return {}


## 짝 스킬 id → 짝 보조 무기 이름 ("진화 재료: …" 카드 문구). 짝 스킬이 아니면 ""
static func pair_of(skill_id: String) -> String:
	for e in Balance.EVOLUTIONS:
		if e["skill"] == skill_id:
			return String(info(e["sub"])["name"])
	return ""


## 진화 조건이 맞은 첫 진화 id: 보조 무기 5단계 + 짝 스킬 1단계 이상 + 아직 진화 안 함. 없으면 "" (얻은 순서대로 하나씩)
static func ready_evolution(owned: Dictionary, done: Dictionary, levels: Dictionary) -> String:
	for id: String in owned:
		var e := evo_of(id)
		if not done.has(id) and int(owned[id]) >= int(info(id)["max"]) and int(levels.get(e["skill"], 0)) >= 1:
			return e["id"]
	return ""


## 진화 카드를 화면에 1장 넣는다: 수치 강화 → 보조 무기 → 효과 카드 순으로 바꿀 칸을 찾고(레전드리는 두고), 없으면 한 장 더
static func put_evolution(cards: Array, evo_id: String) -> Array:
	var e := evo_info(evo_id)
	var card := {"id": evo_id, "grade": Upgrades.EVOLUTION, "evo": true, "tag": "진화",
		"recipe": "%s + %s" % [info(e["sub"])["name"], Upgrades.display_name(e["skill"])], "desc": e["desc"], "short": e["short"]}
	var result := cards.duplicate()
	for want in ["stat", "sub", "effect"]:
		for i in result.size():
			var c: Dictionary = result[i]
			var kind := "sub" if c.get("sub", false) else ("effect" if Upgrades.is_effect(c["id"]) else ("legend" if int(c["grade"]) == Upgrades.LEGENDARY else "stat"))
			if kind == want:
				result[i] = card
				return result
	result.append(card)
	return result


func is_evolved(id: String) -> bool:
	return evolved.has(id)


func evolve(id: String) -> void:
	if stages.has(id):
		evolved[id] = true


## 카드에 뽑을 수 있는 보조 무기: 칸이 남았으면 아직 없는 것 + 5단계 아닌 가진 것, 칸이 다 찼으면 5단계 아닌 가진 것만
static func pool(owned: Dictionary, slots: int) -> PackedStringArray:
	var result: PackedStringArray = []
	for id in ids():
		var stage := int(owned.get(id, 0))
		if stage >= int(info(id)["max"]):
			continue
		if stage > 0 or owned.size() < slots:
			result.append(id)
	return result


## 카드 문구. 처음 얻는 카드는 한 줄 설명, 가진 것은 바뀌는 수치만 "지금 → 다음" (short는 폰용 첫 줄만)
static func card_text(id: String, stage: int, short := false) -> String:
	var w := info(id)
	if stage <= 0:
		return String(w["short" if short else "desc"])
	var parts: PackedStringArray = []
	var labels: Dictionary = w["labels"]
	for key: String in labels:
		var now := stat(id, key, stage)
		var next := stat(id, key, stage + 1)
		if not is_equal_approx(now, next):
			parts.append((String(labels[key]) % _num(now, key)) + " → " + _num(next, key))
			if short:
				break
	return ", ".join(parts)


## 피해는 격납고 공격력처럼 ×100, 나머지는 소수 한 자리까지
static func _num(v: float, key: String) -> String:
	if key in ["damage", "dps"]:
		return str(roundi(v * 100.0))
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 2)


## 한 단계 올린다 (없으면 1단계로 얻음). 칸·최대 단계 검사는 카드 뽑기에서 한다
func level_up(id: String) -> void:
	stages[id] = mini(int(stages.get(id, 0)) + 1, int(info(id)["max"]))
	if not _timers.has(id):
		_timers[id] = 0.0  # 얻자마자 한 번 쏜다


func stage_of(id: String) -> int:
	return int(stages.get(id, 0))


## 한 프레임 진행
func update(sim: RunSim, delta: float) -> void:
	for id: String in stages:
		var s := int(stages[id])
		if id == "saw":
			_update_saw(sim, delta, s)
			continue
		_timers[id] = float(_timers[id]) - delta
		if _timers[id] <= 0.0:
			if _fire(sim, id, s):
				_timers[id] = float(_timers[id]) + stat(id, "interval", s)
			else:
				_timers[id] = 0.0  # 대상이 없으면 준비된 채 기다린다
	_update_missiles(sim, delta)
	_update_chains(sim, delta)
	_update_holes(sim, delta)
	_update_mines(sim, delta)
	_update_mine_links(sim, delta)
	_update_waves(sim, delta)


## 정해진 때마다 한 번 쏘기. 쐈으면 true
func _fire(sim: RunSim, id: String, s: int) -> bool:
	match id:
		"missile":
			var target := RunSim.pick_target(sim.player_pos, _alive(sim), Balance.SUB_MISSILE_RANGE)
			if target == null:
				return false
			var n := int(stat(id, "count", s))
			for i in n:
				var spread := (float(i) - (n - 1) / 2.0) * 0.6  # 여러 발이면 부채꼴로 나가 휘어 들어간다
				var dir := (target.pos - sim.player_pos).angle() + spread
				missiles.append({"pos": sim.player_pos, "vel": Vector2.from_angle(dir) * Balance.SUB_MISSILE_SPEED, "target": target,
					"life": Balance.SUB_MISSILE_LIFE, "damage": stat(id, "damage", s), "blast": stat(id, "blast", s)})
			sim.events.append("sub_missile")
			return true
		"blackhole":
			var target := RunSim.weapon_target(sim.player_pos, _alive(sim), Balance.SUB_HOLE_RANGE, "crowd", stat(id, "radius", s))
			if target == null:
				return false
			holes.append({"pos": target.pos, "from": sim.player_pos, "t": 0.0, "time": stat(id, "time", s), "radius": stat(id, "radius", s), "dps": stat(id, "dps", s)})
			sim.events.append("sub_blackhole")
			return true
		"mine":
			for m in mines:
				if m["pos"].distance_to(sim.player_pos) < Balance.SUB_MINE_GAP:
					return false  # 멈춰 있으면 같은 자리에 쌓지 않는다 (움직이면 바로 놓음)
			mines.append({"pos": sim.player_pos, "t": 0.0})
			while mines.size() > int(stat(id, "max", s)):
				mines.pop_front()  # 오래된 것부터 사라짐
			return true
		"coil":
			return _zap(sim, s)
		"wave":
			waves.append({"pos": sim.player_pos, "r": 0.0, "radius": stat(id, "radius", s), "damage": stat(id, "damage", s), "hits": []})
			sim.events.append("sub_wave")
			return true
	return false


## 유도 미사일: 대상 쪽으로 방향을 틀며 날아가 맞으면 반경 안 모두에게 피해. 대상이 사라지면 가까운 적을 다시 노린다
func _update_missiles(sim: RunSim, delta: float) -> void:
	var kept: Array[Dictionary] = []
	for m in missiles:
		var target: RunSim.Enemy = m["target"]
		if target == null or target.hp <= 0.0 or not sim.enemies.has(target):
			target = RunSim.pick_target(m["pos"], _alive(sim), Balance.SUB_MISSILE_RANGE)
			m["target"] = target
		var vel: Vector2 = m["vel"]
		if target != null:
			var angle := RunSim.turn_toward(vel.angle(), (target.pos - m["pos"]).angle(), Balance.SUB_MISSILE_TURN * delta)
			vel = Vector2.from_angle(angle) * Balance.SUB_MISSILE_SPEED
		var from: Vector2 = m["pos"]
		m["pos"] = from + vel * delta
		m["vel"] = vel
		m["life"] -= delta
		var hit := false
		for e in sim.enemies:
			if e.hp > 0.0 and RunSim.segment_distance(from, m["pos"], e.pos) < e.radius + Balance.SUB_MISSILE_RADIUS:
				hit = true
				break
		if hit or m["life"] <= 0.0:
			_burst(sim, m["pos"], m["blast"], m["damage"], "missile")
			if is_evolved("missile") and hit:
				chains.append({"pos": m["pos"], "left": Balance.EVO_CHAIN_COUNT, "t": Balance.EVO_CHAIN_DELAY, "damage": m["damage"], "blast": m["blast"]})
		else:
			kept.append(m)
	missiles = kept


## 블랙홀: 날아가서 자리 잡은 뒤 반경 안 적과 광물을 가운데로 끌고, 적에게 초당 피해
func _update_holes(sim: RunSim, delta: float) -> void:
	var kept: Array[Dictionary] = []
	for h in holes:
		h["t"] += delta
		if h["t"] >= Balance.SUB_HOLE_FLIGHT + float(h["time"]):
			if is_evolved("blackhole"):
				_collapse(sim, h)
			continue
		kept.append(h)
		if h["t"] < Balance.SUB_HOLE_FLIGHT:
			continue
		var c: Vector2 = h["pos"]
		var r: float = h["radius"]
		var step := Balance.SUB_HOLE_PULL * delta
		for e in sim.enemies:
			var d := e.pos.distance_to(c)
			if e.hp > 0.0 and d < r + e.radius:
				e.pos = e.pos.move_toward(c, step * (Balance.SUB_HOLE_STURDY_PULL if e.sturdy() else 1.0))
				e.hp -= float(h["dps"]) * sim.bullet_damage * delta  # 계속 닿는 피해는 번쩍임·치명타 없이 (빔처럼 화면을 덮지 않게)
				if is_evolved("blackhole"):  # 정지장: 안에 든 적은 얼어 스스로 못 움직이고 끌려가기만 한다
					e.chill = maxf(e.chill, 0.2)
					e.chill_slow = 1.0
		for m in sim.minerals:
			if not m.attracted and m.pos.distance_to(c) < r:
				m.pos = m.pos.move_toward(c, step)
				m.rest = 0.0
	holes = kept


## 정지장 붕괴탄: 블랙홀이 끝나는 순간 반경 × EVO_COLLAPSE_REACH 안 모두에게 큰 피해 (얼었던 적이 한꺼번에 무너진다)
func _collapse(sim: RunSim, h: Dictionary) -> void:
	var reach := float(h["radius"]) * Balance.EVO_COLLAPSE_REACH
	sim.fx.append({"type": "sub_collapse", "pos": h["pos"], "radius": reach})
	sim.events.append("explode")
	for e in sim.enemies:
		if e.hp > 0.0 and e.pos.distance_to(h["pos"]) < reach + e.radius:
			e.chill = 0.0
			sim.sub_hit(e, Balance.EVO_COLLAPSE_DAMAGE, h["pos"])


## 연쇄 폭격: 미사일 폭발 뒤 EVO_CHAIN_DELAY마다 가장 가까운 다른 적 자리에서 다시 터진다 (피해는 매번 EVO_CHAIN_DAMAGE배)
func _update_chains(sim: RunSim, delta: float) -> void:
	if chains.is_empty():
		return
	var kept: Array[Dictionary] = []
	for c in chains:
		c["t"] -= delta
		if c["t"] > 0.0:
			kept.append(c)
			continue
		var next: RunSim.Enemy = null
		var best := Balance.EVO_CHAIN_JUMP
		for e in sim.enemies:
			var d := e.pos.distance_to(c["pos"])
			if e.hp > 0.0 and d < best and d > float(c["blast"]) * 0.5:
				next = e
				best = d
		if next == null:
			continue
		var damage := float(c["damage"]) * Balance.EVO_CHAIN_DAMAGE
		sim.fx.append({"type": "chain_link", "from": c["pos"], "to": next.pos})
		_burst(sim, next.pos, c["blast"], damage, "chain")
		if int(c["left"]) > 1:
			kept.append({"pos": next.pos, "left": int(c["left"]) - 1, "t": Balance.EVO_CHAIN_DELAY, "damage": damage, "blast": c["blast"]})
	chains = kept


## 연소 기뢰선: 켜진 기뢰를 놓인 순서대로 이웃끼리(EVO_MINE_LINK 안) 잇고, 선에 닿은 적에게 초당 피해 (그리기와 같은 선)
func mine_links() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not is_evolved("mine"):
		return out
	for i in range(1, mines.size()):
		var a: Dictionary = mines[i - 1]
		var b: Dictionary = mines[i]
		if a["t"] >= Balance.SUB_MINE_ARM and b["t"] >= Balance.SUB_MINE_ARM and (a["pos"] as Vector2).distance_to(b["pos"]) <= Balance.EVO_MINE_LINK:
			out.append(PackedVector2Array([a["pos"], b["pos"]]))
	return out


func _update_mine_links(sim: RunSim, delta: float) -> void:
	var links := mine_links()
	if links.is_empty():
		return
	var hurt := Balance.EVO_MINE_LINE_DPS * sim.bullet_damage * delta
	for e in sim.enemies:
		if e.hp <= 0.0:
			continue
		for l in links:
			if RunSim.segment_distance(l[0], l[1], e.pos) < e.radius + Balance.EVO_MINE_LINE_WIDTH:
				e.hp -= hurt
				break


## 기뢰: 잠깐 뒤 켜지고, 적이 닿으면 터진다. 오래되면 사라진다
func _update_mines(sim: RunSim, delta: float) -> void:
	if mines.is_empty():
		return
	var s := stage_of("mine")
	var kept: Array[Dictionary] = []
	for m in mines:
		m["t"] += delta
		if m["t"] >= Balance.SUB_MINE_LIFE:
			continue
		var boom := false
		if m["t"] >= Balance.SUB_MINE_ARM:
			for e in sim.enemies:
				if e.hp > 0.0 and e.pos.distance_to(m["pos"]) < e.radius + Balance.SUB_MINE_TRIGGER:
					boom = true
					break
		if boom:
			_burst(sim, m["pos"], stat("mine", "blast", s), stat("mine", "damage", s), "mine")
		else:
			kept.append(m)
	mines = kept


## 채굴 펄스: 파동이 퍼지며 처음 닿은 적에게 한 번씩 피해 (운석이 아닌 적은 약하게)
func _update_waves(sim: RunSim, delta: float) -> void:
	var kept: Array[Dictionary] = []
	for w in waves:
		w["r"] = minf(float(w["r"]) + Balance.SUB_WAVE_SPEED * delta, w["radius"])
		var hits: Array = w["hits"]
		for e in sim.enemies:
			if e.hp > 0.0 and not hits.has(e) and e.pos.distance_to(w["pos"]) - e.radius <= w["r"]:
				hits.append(e)
				var mult := 1.0 if e.kind == RunSim.ROCK else Balance.SUB_WAVE_CREATURE_MULT
				var shatter := is_evolved("wave") and e.kind == RunSim.ROCK and not e.golden and e.type <= 1
				if is_evolved("wave") and not shatter:
					mult *= Balance.EVO_WAVE_BIG_MULT
				sim.sub_hit(e, float(w["damage"]) * mult, w["pos"])
				if shatter:  # 공명 파쇄: 작은·중간 운석은 한 번에 부서지고 광물을 더 떨어뜨린다
					e.hp = minf(e.hp, 0.0)
					e.bonus_drop = Balance.EVO_WAVE_DROP
				sim.fx.append({"type": "sub_hit", "kind": "shatter" if shatter else "wave", "pos": e.pos, "target": e})  # 그리기용 (금 가는 운석)
		if w["r"] < w["radius"]:
			kept.append(w)
	waves = kept


## 궤도 톱날: 우주선 둘레를 돌며 닿은 적을 SUB_SAW_HIT_GAP마다 간다
## 회전 충각이면 움직이는 빠르기에 따라 더 빨리 돌고 더 세게 간다 (톱날도 크다)
func _update_saw(sim: RunSim, delta: float, s: int) -> void:
	var speed := speed_ratio(sim) if is_evolved("saw") else 0.0
	saw_angle = wrapf(saw_angle + Balance.SUB_SAW_SPIN * (1.0 + Balance.EVO_SAW_SPEED_SPIN * speed) * delta, 0.0, TAU)
	var reach := saw_radius()
	var damage := stat("saw", "damage", s) * (1.0 + Balance.EVO_SAW_SPEED_DAMAGE * speed)
	for p in saw_points(sim.player_pos, s):
		for e in sim.enemies:
			if e.hp > 0.0 and sim.time - e.saw_hit_at >= Balance.SUB_SAW_HIT_GAP and e.pos.distance_to(p) < e.radius + reach:
				e.saw_hit_at = sim.time
				sim.sub_hit(e, damage, p, true)
				sim.fx.append({"type": "sub_hit", "kind": "saw", "pos": p.lerp(e.pos, 0.5), "target": e})  # 그리기용 (불꽃·부스러기)


## 톱날 위치들 (그리기와 판정이 같은 값)
func saw_points(center: Vector2, s: int = -1) -> Array[Vector2]:
	if s < 0:
		s = stage_of("saw")
	var result: Array[Vector2] = []
	var n := int(stat("saw", "count", s))
	var orbit := stat("saw", "orbit", s) + (Balance.EVO_SAW_ORBIT_ADD if is_evolved("saw") else 0.0)
	for i in n:
		result.append(center + Vector2.from_angle(saw_angle + TAU * i / n) * orbit)
	return result


## 톱날 판정 반지름 (회전 충각이면 크다)
func saw_radius() -> float:
	return Balance.EVO_SAW_RADIUS if is_evolved("saw") else Balance.SUB_SAW_RADIUS


## 지금 이동 빠르기 / 강화된 이동 속도 (0~1)
static func speed_ratio(sim: RunSim) -> float:
	return clampf(sim.player_vel.length() / maxf(sim.move_speed, 1.0), 0.0, 1.0)


## 방전 코일: 가장 가까운 적에서 시작해 가까운 적으로 튀며 chains곳에 피해. 그리기용 꺾은선은 sim.fx에 남긴다
func _zap(sim: RunSim, s: int) -> bool:
	var first := RunSim.pick_target(sim.player_pos, _alive(sim), Balance.SUB_COIL_RANGE)
	if first == null:
		return false
	var points: Array[Vector2] = [sim.player_pos]
	var hit: Array[RunSim.Enemy] = []
	var current := first
	while current != null and hit.size() < int(stat("coil", "chains", s)):
		hit.append(current)
		points.append(current.pos)
		var next: RunSim.Enemy = null
		var best := Balance.SUB_COIL_JUMP
		for e in sim.enemies:
			var d := e.pos.distance_to(current.pos)
			if e.hp > 0.0 and d < best and not hit.has(e):
				next = e
				best = d
		current = next
	for e in hit:
		sim.sub_hit(e, stat("coil", "damage", s), points[0], e == first)
	sim.fx.append({"type": "zap", "points": points})
	sim.events.append("sub_coil")
	if is_evolved("coil"):
		coil_charge += hit.size()
		if coil_charge >= Balance.EVO_COIL_CHARGE:
			coil_charge -= Balance.EVO_COIL_CHARGE
			_discharge(sim)
	return true


## 과충전 방전: 우주선 둘레 EVO_COIL_RADIUS 안 모든 적에게 큰 피해. 그리기용으로 맞은 자리를 가까운 순 12곳까지 남긴다
func _discharge(sim: RunSim) -> void:
	var targets: Array[RunSim.Enemy] = []
	for e in sim.enemies:
		if e.hp > 0.0 and e.pos.distance_to(sim.player_pos) < Balance.EVO_COIL_RADIUS + e.radius:
			targets.append(e)
	targets.sort_custom(func(a: RunSim.Enemy, b: RunSim.Enemy) -> bool: return a.pos.distance_squared_to(sim.player_pos) < b.pos.distance_squared_to(sim.player_pos))
	var points: Array[Vector2] = []
	for e in targets:
		if points.size() < 12:
			points.append(e.pos)
		sim.sub_hit(e, Balance.EVO_COIL_DAMAGE, sim.player_pos)
	sim.fx.append({"type": "discharge", "pos": sim.player_pos, "radius": Balance.EVO_COIL_RADIUS, "points": points})
	sim.events.append("sub_discharge")


## 이번 프레임에 아직 살아 있는 적 (같은 프레임에 먼저 부서진 적은 _check_bullet_hits 전까지 목록에 남아 있다)
static func _alive(sim: RunSim) -> Array[RunSim.Enemy]:
	return sim.enemies.filter(func(e: RunSim.Enemy) -> bool: return e.hp > 0.0)


## 폭발 (미사일·기뢰): 반경 안 모두에게 피해. 그리기용 sim.fx
func _burst(sim: RunSim, at: Vector2, radius: float, damage: float, kind: String) -> void:
	sim.fx.append({"type": "sub_burst", "pos": at, "radius": radius, "kind": kind})
	sim.events.append("explode")
	for e in sim.enemies:
		if e.hp > 0.0 and e.pos.distance_to(at) < radius + e.radius:
			sim.sub_hit(e, damage, at)


## 레벨업 카드에 보조 무기 카드를 섞는다: 수치 강화 칸마다 SUB_CARD_SHARE 확률로 바꾸고, 빈 칸(고를 카드가 모자람)은 채운다.
## force면 최소 1장 (첫 레벨업, 흐름표). 뽑을 보조 무기가 없으면 그대로 (난수도 쓰지 않음)
static func mix_cards(random: RandomNumberGenerator, cards: Array, owned: Dictionary, slots: int, count: int, force: bool) -> Array:
	var left := pool(owned, slots)
	if left.is_empty():
		return cards
	var result := cards.duplicate()
	var made := 0
	for i in count:
		if left.is_empty():
			break
		var empty := i >= result.size()
		if empty or (_replaceable(result[i]) and random.randf() < Balance.SUB_CARD_SHARE):
			var card := _card(random, left, owned, slots)
			if empty:
				result.append(card)
			else:
				result[i] = card
			made += 1
	if force and made == 0:
		var spots: Array = []
		for i in result.size():
			if _replaceable(result[i]):
				spots.append(i)
		var card := _card(random, left, owned, slots)
		if spots.is_empty():
			result.append(card)
		else:
			result[spots[random.randi_range(0, spots.size() - 1)]] = card
	return result


## 보조 무기 카드로 바꿔도 되는 칸: 레전드리(한 화면 1장)와 효과 카드(효과 카드 보정이 넣은 카드일 수 있음)는 두고, 수치 강화만 바꾼다
static func _replaceable(card: Dictionary) -> bool:
	return int(card["grade"]) != Upgrades.LEGENDARY and not Upgrades.is_effect(card["id"])


static func _card(random: RandomNumberGenerator, left: PackedStringArray, owned: Dictionary, slots: int) -> Dictionary:
	var i := random.randi_range(0, left.size() - 1)
	var id := left[i]
	left.remove_at(i)
	var stage := int(owned.get(id, 0))
	return {"id": id, "grade": Balance.SUB_CARD_GRADE, "sub": true, "tag": "보조 무기 %d/%d" % [owned.size(), slots],
		"desc": card_text(id, stage), "short": card_text(id, stage, true)}
