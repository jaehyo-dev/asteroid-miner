class_name RunSim
extends RefCounted
## 출격 한 판의 게임 로직.
## 화면 그리기와 분리되어 있어서, 자동 테스트에서 update()를 직접 불러 확인할 수 있다.
## 화면 쪽(scripts/run.gd)은 매 프레임 update()를 부르고 이 상태를 그리기만 한다.


## 적 한 개 (운석, 황금 운석, 생명체)
class Enemy:
	var pos: Vector2
	var vel: Vector2
	var type: int  ## Balance.ASTEROID_TYPES 인덱스 (0 작음, 1 중간, 2 큼)
	var radius: float
	var damage: float
	var hp: float
	var max_hp: float
	var variant: int  ## 모양 변형 번호 (그리기용)
	var golden := false  ## 황금 운석인지
	var aimed := false  ## 우주선을 정확히 노리는 조준 운석인지
	var flash := 0.0  ## 탄에 맞은 직후 번쩍이는 남은 시간 (그리기용)


## 떠 있는 광물 한 개
class Mineral:
	var pos: Vector2
	var grade: int  ## Balance.MINERAL_GRADES 인덱스 (0 일반 ~ 3 전설)
	var attracted := false  ## 자석에 끌려오는 중인지 (한번 끌리면 끝까지 따라옴)


## 탄 한 개
class Bullet:
	var pos: Vector2
	var prev_pos: Vector2  ## 이번 프레임 이동 전 위치 (지나간 선분으로 명중 판정)
	var vel: Vector2
	var life: float  ## 남은 비행 시간
	var damage: float


var rng := RandomNumberGenerator.new()
## 우주선 위치 (월드 좌표)
var player_pos := Vector2.ZERO
## 우주선 속도 (조준 운석이 앞질러 노릴 때 씀)
var player_vel := Vector2.ZERO
var hp := Balance.SHIP_MAX_HP
var max_hp := Balance.SHIP_MAX_HP
## 남은 무적 시간
var invuln := 0.0
## 우주선이 바라보는 방향 (라디안, 0 = 오른쪽, -PI/2 = 위쪽). 멈추면 마지막 방향을 유지한다.
var facing := -PI / 2.0
var alive := true
## 출격 후 지난 시간
var time := 0.0
## 지금 화면에 보이는 크기 (운석 등장·제거 거리 계산용)
var view_size := Vector2(Balance.BASE_LANDSCAPE)
var enemies: Array[Enemy] = []
var bullets: Array[Bullet] = []
## 이번 프레임에 탄으로 부서진 운석 (효과·보상용)
var destroyed: Array[Enemy] = []
## 이번 프레임에 주운 광물 {pos, grade} (줍기 연출·효과음용)
var picked: Array[Dictionary] = []
## 이번 프레임에 일어난 일 (효과·소리용): "hit", "dead", "shoot", "destroy", "pickup", "levelup", "golden", "aimed"
var events: PackedStringArray = []
## 탄으로 부순 운석 수
var kills := 0
var minerals: Array[Mineral] = []
## 이번 판에 주운 광물 수 (등급별)
var collected := PackedInt32Array([0, 0, 0, 0])
## 이번 판에 주운 광물의 총 가치
var mineral_value := 0

# 능력치 (레벨업 강화로 바뀜, apply_upgrades 참고)
var fire_interval := Balance.FIRE_INTERVAL
var fire_range := Balance.FIRE_RANGE
var bullet_damage := Balance.BULLET_DAMAGE
var bullet_count := Balance.BULLET_COUNT
var magnet_radius := Balance.MAGNET_RADIUS
var move_speed := Balance.SHIP_SPEED

# 경험치와 레벨업
var level := 1
## 현재 레벨에서 모은 경험치 (레벨업하면 필요한 만큼 빠짐)
var xp := 0
## 아직 고르지 않은 레벨업 횟수 (한 번에 여러 레벨이 오를 수 있음)
var pending_levelups := 0
## 지금 보여 주는 강화 선택지. 비어 있지 않으면 고를 때까지 게임이 멈춘다.
var choices: PackedStringArray = []
## 강화 id → 단계
var upgrade_levels: Dictionary = {}

var _spawn_timer := 0.0
## 다음 황금 운석까지 남은 시간
var _golden_timer := Balance.GOLDEN_FIRST_TIME
## 다음 조준 운석까지 남은 시간
var _aimed_timer := Balance.AIMED_FIRST_TIME
## 다음 발사까지 남은 시간 (0 이하면 대상이 생기는 즉시 발사)
var _fire_timer := 0.0


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	_spawn_timer = spawn_interval(0.0)


## 한 프레임 진행. move는 길이 0~1의 이동 방향.
func update(delta: float, move: Vector2) -> void:
	events.clear()
	destroyed.clear()
	picked.clear()
	if not alive or not choices.is_empty():
		return  # 파괴됐거나 강화를 고르는 중이면 멈춘다
	delta = clampf(delta, 0.0, Balance.MAX_FRAME_DELTA)
	time += delta
	invuln = maxf(invuln - delta, 0.0)
	player_vel = move.limit_length(1.0) * move_speed
	player_pos += player_vel * delta
	if move != Vector2.ZERO:
		facing = turn_toward(facing, move.angle(), Balance.SHIP_TURN_SPEED * delta)

	_spawn_timer -= delta
	while _spawn_timer <= 0.0:
		if enemies.size() < Balance.MAX_ENEMIES:
			spawn_asteroid()
		_spawn_timer += spawn_interval(time)
	_aimed_timer -= delta
	while _aimed_timer <= 0.0:
		if enemies.size() + Balance.AIMED_COUNT <= Balance.MAX_ENEMIES:
			spawn_aimed()
		_aimed_timer += aimed_interval(time)
	_golden_timer -= delta
	while _golden_timer <= 0.0:
		if golden_count() < Balance.GOLDEN_MAX and enemies.size() < Balance.MAX_ENEMIES:
			spawn_golden()
		_golden_timer += golden_interval(time)

	_move_asteroids(delta)
	_auto_fire(delta)
	_move_bullets(delta)
	_check_bullet_hits()
	_check_player_hits()
	_update_minerals(delta)


## 우주선이 운석에 맞음. 무적 중이면 무시하고 false를 돌려준다.
func damage_player(amount: float) -> bool:
	if invuln > 0.0 or not alive:
		return false
	hp = maxf(hp - amount, 0.0)
	invuln = Balance.SHIP_INVULN_TIME
	events.append("hit")
	if hp <= 0.0:
		alive = false
		events.append("dead")
	return true


## 운석 하나를 화면 밖 무작위 위치에 만든다. 만든 운석을 돌려준다.
func spawn_asteroid() -> Enemy:
	var a := Enemy.new()
	a.type = pick_weighted(rng, asteroid_weights(time))
	var info: Dictionary = Balance.ASTEROID_TYPES[a.type]
	a.radius = info["radius"]
	a.damage = info["damage"]
	a.max_hp = asteroid_hp(info["hp"], time)
	a.hp = a.max_hp
	a.variant = rng.randi_range(0, 3)
	a.pos = spawn_position(rng, player_pos, view_size, a.radius)
	# 우주선 쪽을 향하되 조금씩 빗나가게 한다.
	var aim := (player_pos - a.pos).angle() + deg_to_rad(rng.randf_range(-Balance.ASTEROID_AIM_SPREAD_DEG, Balance.ASTEROID_AIM_SPREAD_DEG))
	a.vel = Vector2.from_angle(aim) * rng.randf_range(info["speed_min"], info["speed_max"]) * asteroid_speed_mult(time)
	enemies.append(a)
	return a


## 조준 운석 무리를 만든다: 같은 방향에서 한 줄로 AIMED_COUNT개가, 우주선이 갈 곳을 노리고 빠르게 온다.
## 만든 운석 목록을 돌려준다.
func spawn_aimed() -> Array[Enemy]:
	var group: Array[Enemy] = []
	var lead := spawn_asteroid()
	var speed := lead.vel.length() * Balance.AIMED_SPEED_MULT
	var dir := Vector2.from_angle(intercept_angle(lead.pos, player_pos, player_vel, speed))
	for i in Balance.AIMED_COUNT:
		var a := lead if i == 0 else spawn_asteroid()
		a.type = lead.type
		a.radius = lead.radius
		a.damage = lead.damage
		a.max_hp = lead.max_hp
		a.hp = lead.hp
		a.aimed = true
		a.pos = lead.pos - dir * Balance.AIMED_GAP * i  # 줄지어 뒤따라옴
		a.vel = dir * speed
		group.append(a)
	events.append("aimed")
	return group


## 황금 운석 하나를 화면 밖에 만든다. 우주선 근처를 비스듬히 지나가도록 날아간다.
func spawn_golden() -> Enemy:
	var a := Enemy.new()
	a.golden = true
	a.type = Balance.ASTEROID_TYPES.size() - 1  # 그리기·조준에는 큰 운석처럼 취급
	a.radius = Balance.GOLDEN["radius"]
	a.damage = Balance.GOLDEN["damage"]
	a.max_hp = asteroid_hp(Balance.GOLDEN["hp"], time)
	a.hp = a.max_hp
	a.variant = rng.randi_range(0, 3)
	a.pos = spawn_position(rng, player_pos, view_size, a.radius)
	var aim := (player_pos - a.pos).angle() + deg_to_rad(rng.randf_range(-Balance.GOLDEN_AIM_SPREAD_DEG, Balance.GOLDEN_AIM_SPREAD_DEG))
	a.vel = Vector2.from_angle(aim) * rng.randf_range(Balance.GOLDEN["speed_min"], Balance.GOLDEN["speed_max"])
	enemies.append(a)
	events.append("golden")
	return a


## 지금 있는 황금 운석 수
func golden_count() -> int:
	var n := 0
	for a in enemies:
		if a.golden:
			n += 1
	return n


## 운석을 움직이고, 너무 멀어진 운석은 없앤다.
func _move_asteroids(delta: float) -> void:
	var limit := despawn_distance(view_size)
	var kept: Array[Enemy] = []
	for a in enemies:
		a.pos += a.vel * delta
		a.flash = maxf(a.flash - delta, 0.0)
		if a.pos.distance_to(player_pos) <= (limit * Balance.GOLDEN_DESPAWN_FACTOR if a.golden else limit):
			kept.append(a)
	enemies = kept


## 사거리 안에 운석이 있으면 가장 가까운 운석을 향해 발사한다.
func _auto_fire(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var target := nearest_enemy(player_pos, enemies, fire_range)
	if target == null:
		_fire_timer = 0.0  # 대상이 없으면 장전된 상태로 기다린다
		return
	# 움직이는 운석이 탄과 만날 지점을 노린다.
	var base_angle := intercept_angle(player_pos, target.pos, target.vel, Balance.BULLET_SPEED)
	var life := fire_range / Balance.BULLET_SPEED * Balance.BULLET_LIFETIME_FACTOR
	for shot in shot_pattern(base_angle, bullet_count, deg_to_rad(Balance.MULTI_SHOT_SPREAD_DEG), Balance.PARALLEL_SHOT_GAP):
		var b := Bullet.new()
		b.pos = player_pos + shot.offset
		b.prev_pos = b.pos
		b.vel = Vector2.from_angle(shot.angle) * Balance.BULLET_SPEED
		b.life = life
		b.damage = bullet_damage
		bullets.append(b)
	# 프레임 사이에 넘친 시간은 다음 발사에 반영해 프레임 속도와 관계없이 간격을 지킨다.
	_fire_timer = maxf(_fire_timer + fire_interval, 0.0)
	events.append("shoot")


func _move_bullets(delta: float) -> void:
	var kept: Array[Bullet] = []
	for b in bullets:
		b.prev_pos = b.pos
		b.pos += b.vel * delta
		b.life -= delta
		if b.life > 0.0:
			kept.append(b)
	bullets = kept


## 탄이 운석에 맞으면 탄은 사라지고 운석 체력이 준다. 체력이 0이 되면 운석이 부서진다.
func _check_bullet_hits() -> void:
	var kept_bullets: Array[Bullet] = []
	for b in bullets:
		var hit := false
		for a in enemies:
			# 이번 프레임에 지나간 선분으로 판정해, 프레임이 느려도 탄이 운석을 뚫고 지나가지 않게 한다.
			if a.hp > 0.0 and segment_distance(b.prev_pos, b.pos, a.pos) < a.radius + Balance.BULLET_RADIUS:
				a.hp -= b.damage
				a.flash = 0.08
				hit = true
				break
		if not hit:
			kept_bullets.append(b)
	bullets = kept_bullets
	var kept: Array[Enemy] = []
	for a in enemies:
		if a.hp <= 0.0:
			_on_enemy_destroyed(a)
		else:
			kept.append(a)
	enemies = kept


## 탄으로 운석을 부쉈을 때
func _on_enemy_destroyed(a: Enemy) -> void:
	kills += 1
	destroyed.append(a)
	events.append("destroy")
	for drop in drops_of(a):
		for i in int(drop["count"]):
			drop_mineral(a.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, Balance.MINERAL_SCATTER), int(drop["grade"]))


## 경험치를 얻는다. 필요한 만큼 모이면 레벨업하고 강화 선택지를 연다.
func gain_xp(amount: int) -> void:
	xp += maxi(amount, 0)
	while xp >= Upgrades.xp_to_next(level):
		xp -= Upgrades.xp_to_next(level)
		level += 1
		pending_levelups += 1
		events.append("levelup")
	if choices.is_empty() and pending_levelups > 0:
		choices = Upgrades.roll_choices(rng, upgrade_levels, Balance.UPGRADE_CHOICE_COUNT)


## 강화 선택지 중 하나를 고른다. 남은 레벨업이 있으면 다음 선택지를 연다.
func choose(index: int) -> void:
	if index < 0 or index >= choices.size():
		return
	var id := choices[index]
	if id == Upgrades.REPAIR:
		hp = minf(hp + Balance.REPAIR_AMOUNT, max_hp)
	else:
		upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
		if id == "max_hp":
			hp += Balance.UP_MAX_HP_ADD
		apply_upgrades()
	pending_levelups = maxi(pending_levelups - 1, 0)
	choices = []
	if pending_levelups > 0:
		choices = Upgrades.roll_choices(rng, upgrade_levels, Balance.UPGRADE_CHOICE_COUNT)


## 강화 단계에 맞게 능력치를 다시 계산한다 (항상 기본값에서 계산해 오차가 쌓이지 않게).
func apply_upgrades() -> void:
	var lv := func(id: String) -> int: return int(upgrade_levels.get(id, 0))
	fire_interval = Balance.FIRE_INTERVAL * pow(Balance.UP_FIRE_INTERVAL_MULT, lv.call("fire_rate"))
	bullet_count = Balance.BULLET_COUNT + Balance.UP_BULLET_COUNT_ADD * lv.call("multishot")
	bullet_damage = Balance.BULLET_DAMAGE + Balance.UP_DAMAGE_ADD * lv.call("damage")
	magnet_radius = Balance.MAGNET_RADIUS * (1.0 + Balance.UP_MAGNET_ADD * lv.call("magnet"))
	move_speed = Balance.SHIP_SPEED * (1.0 + Balance.UP_SPEED_ADD * lv.call("speed"))
	max_hp = Balance.SHIP_MAX_HP + Balance.UP_MAX_HP_ADD * lv.call("max_hp")
	fire_range = Balance.FIRE_RANGE * (1.0 + Balance.UP_RANGE_ADD * lv.call("range"))
	hp = minf(hp, max_hp)


## 광물 하나를 떨어뜨린다.
func drop_mineral(pos: Vector2, grade: int = 0) -> Mineral:
	var m := Mineral.new()
	m.pos = pos
	m.grade = clampi(grade, 0, Balance.MINERAL_GRADES.size() - 1)
	minerals.append(m)
	while minerals.size() > Balance.MAX_MINERALS:
		minerals.pop_front()
	return m


## 자석 범위 안의 광물은 우주선으로 끌려오고, 가까이 오면 줍는다.
func _update_minerals(delta: float) -> void:
	if not alive:
		return
	var kept: Array[Mineral] = []
	for m in minerals:
		var dist := m.pos.distance_to(player_pos)
		if dist <= magnet_radius:
			m.attracted = true
		if m.attracted:
			m.pos = m.pos.move_toward(player_pos, Balance.MAGNET_SPEED * delta)
			dist = m.pos.distance_to(player_pos)
		if dist <= Balance.PICKUP_RADIUS:
			picked.append({"pos": m.pos, "grade": m.grade})
			collect(m.grade)
		else:
			kept.append(m)
	minerals = kept


## 광물을 줍는다.
func collect(grade: int) -> void:
	collected[grade] += 1
	mineral_value += int(Balance.MINERAL_GRADES[grade]["value"])
	events.append("pickup")
	gain_xp(mineral_xp(grade))


## 우주선과 부딪힌 운석: 무적이 아니면 데미지를 주고 부서진다. 무적 중에는 그냥 지나간다.
func _check_player_hits() -> void:
	var kept: Array[Enemy] = []
	for a in enemies:
		var touching := a.pos.distance_to(player_pos) < a.radius + Balance.SHIP_RADIUS
		if touching and alive and damage_player(a.damage) and not a.golden:
			continue  # 부서진 운석은 목록에서 뺀다 (황금 운석은 부딪혀도 부서지지 않음)
		kept.append(a)
	enemies = kept


# ── 규칙 계산 (자동 테스트 대상) ─────────────────────

## 운석을 탄으로 부쉈을 때 떨어지는 광물 목록 [{grade, count}]
static func drops_of(a: Enemy) -> Array:
	if a.golden:
		return Balance.GOLDEN_DROPS
	var info: Dictionary = Balance.ASTEROID_TYPES[a.type]
	return [{"grade": info["grade"], "count": info["minerals"]}]


## 지금 시간의 조준 운석 등장 간격: 시간이 지날수록 짧아진다.
static func aimed_interval(t: float) -> float:
	var k := clampf(t / Balance.SPAWN_RAMP_TIME, 0.0, 1.0)
	return lerpf(Balance.AIMED_INTERVAL_START, Balance.AIMED_INTERVAL_MIN, k)


## 지금 시간의 황금 운석 등장 간격: 시간이 지날수록 조금씩 짧아진다.
static func golden_interval(t: float) -> float:
	var k := clampf(t / Balance.GOLDEN_RAMP_TIME, 0.0, 1.0)
	return lerpf(Balance.GOLDEN_INTERVAL_START, Balance.GOLDEN_INTERVAL_MIN, k)


## 광물 한 개를 주웠을 때 얻는 경험치: 가치 × 비율 (반올림, 최소 1)
static func mineral_xp(grade: int) -> int:
	return maxi(1, roundi(float(Balance.MINERAL_GRADES[grade]["value"]) * Balance.MINERAL_XP_PER_VALUE))


## 등급별 개수 → 총 가치
static func value_of(counts: PackedInt32Array) -> int:
	var total := 0
	for i in mini(counts.size(), Balance.MINERAL_GRADES.size()):
		total += counts[i] * int(Balance.MINERAL_GRADES[i]["value"])
	return total


## 시간에 따라 늘어나는 운석 체력. 계단식으로 늘어서 처음 구간은 기본 체력(탄 수) 그대로다.
static func asteroid_hp(base_hp: float, t: float) -> float:
	return base_hp * (1.0 + floorf(maxf(t, 0.0) / Balance.ASTEROID_HP_GROWTH_TIME))


## 선분 a-b와 점 p 사이의 가장 짧은 거리
static func segment_distance(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 사거리 안에서 가장 가까운 운석. 없으면 null.
static func nearest_enemy(from: Vector2, list: Array[Enemy], max_range: float) -> Enemy:
	var best: Enemy = null
	var best_dist := max_range
	for a in list:
		var d := from.distance_to(a.pos)
		if d <= best_dist:
			best = a
			best_dist = d
	return best


## 움직이는 대상을 맞히기 위한 발사 각도 (앞질러 쏘기).
## 탄이 대상을 따라잡을 수 없으면 대상의 현재 위치를 노린다.
static func intercept_angle(from: Vector2, target_pos: Vector2, target_vel: Vector2, bullet_speed: float) -> float:
	var to_target := target_pos - from
	# |to_target + target_vel * t| = bullet_speed * t 를 t에 대해 푼다.
	var a := target_vel.length_squared() - bullet_speed * bullet_speed
	var b := 2.0 * to_target.dot(target_vel)
	var c := to_target.length_squared()
	var t := -1.0
	if absf(a) < 0.0001:
		if absf(b) > 0.0001:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if t <= 0.0:
		return to_target.angle()
	return (to_target + target_vel * t).angle()


## 한 번 발사할 때 각 탄의 방향과 출발 위치 (우주선 기준).
## - 1발: 직선 / 2발: 같은 방향으로 gap만큼 떨어져 나란히
## - 홀수(3, 5…): 가운데 1발 + 양옆으로 spread 간격의 부채꼴
## - 짝수(4, 6…): 가운데 2발 나란히 + 양옆으로 spread 간격의 부채꼴
## 결과는 {angle, offset} 목록 (왼쪽 → 오른쪽 순서)
static func shot_pattern(center: float, count: int, spread: float, gap: float) -> Array[Dictionary]:
	count = maxi(count, 1)
	var result: Array[Dictionary] = []
	# 진행 방향에 수직인 방향 (나란히 붙은 두 발을 벌리는 쪽)
	var side := Vector2.from_angle(center + PI / 2.0)
	var fan := (count - 1) / 2 if count % 2 == 1 else (count - 2) / 2  # 한쪽으로 퍼지는 탄 수
	for i in range(fan, 0, -1):
		result.append({"angle": center - i * spread, "offset": Vector2.ZERO})
	if count % 2 == 1:
		result.append({"angle": center, "offset": Vector2.ZERO})
	else:
		result.append({"angle": center, "offset": -side * gap / 2.0})
		result.append({"angle": center, "offset": side * gap / 2.0})
	for i in range(1, fan + 1):
		result.append({"angle": center + i * spread, "offset": Vector2.ZERO})
	return result


## 바라보는 방향을 목표 방향으로 최대 max_step(라디안)만큼 돌린다. 짧은 쪽으로 돈다.
static func turn_toward(from: float, to: float, max_step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= max_step:
		return wrapf(to, -PI, PI)
	return wrapf(from + signf(diff) * max_step, -PI, PI)


## 지금 시간의 운석 등장 간격: 처음 SPAWN_RAMP_TIME 동안 MIN까지 줄고, 그 뒤로는 계속 절반씩 준다.
static func spawn_interval(t: float) -> float:
	if t <= Balance.SPAWN_RAMP_TIME:
		var k := clampf(t / Balance.SPAWN_RAMP_TIME, 0.0, 1.0)
		return lerpf(Balance.SPAWN_INTERVAL_START, Balance.SPAWN_INTERVAL_MIN, k)
	var late := Balance.SPAWN_INTERVAL_MIN * pow(0.5, (t - Balance.SPAWN_RAMP_TIME) / Balance.SPAWN_LATE_HALVING_TIME)
	return maxf(late, Balance.SPAWN_INTERVAL_FLOOR)


## 지금 시간의 운석 속도 배율
static func asteroid_speed_mult(t: float) -> float:
	return 1.0 + maxf(t, 0.0) / Balance.ASTEROID_SPEED_GROWTH_TIME


## 지금 시간의 운석 크기별 등장 비율
static func asteroid_weights(t: float) -> Array[float]:
	var k := clampf(t / Balance.SPAWN_RAMP_TIME, 0.0, 1.0)
	var result: Array[float] = []
	for i in Balance.ASTEROID_WEIGHTS_START.size():
		result.append(lerpf(Balance.ASTEROID_WEIGHTS_START[i], Balance.ASTEROID_WEIGHTS_LATE[i], k))
	return result


## 비율에 따라 무작위 인덱스를 고른다.
static func pick_weighted(random: RandomNumberGenerator, weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	var roll := random.randf() * total
	for i in weights.size():
		roll -= maxf(weights[i], 0.0)
		if roll < 0.0:
			return i
	return weights.size() - 1


## 화면 밖 등장 위치: 화면 대각선 반 길이 + 여유만큼 떨어진 원 위의 무작위 지점
static func spawn_position(random: RandomNumberGenerator, center: Vector2, view: Vector2, radius: float) -> Vector2:
	var distance := view.length() / 2.0 + Balance.SPAWN_MARGIN + radius
	return center + Vector2.from_angle(random.randf() * TAU) * distance


## 이보다 멀어진 운석은 없앤다.
static func despawn_distance(view: Vector2) -> float:
	return view.length() / 2.0 * Balance.DESPAWN_DISTANCE_FACTOR + Balance.SPAWN_MARGIN
