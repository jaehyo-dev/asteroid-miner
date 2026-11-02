class_name RunSim
extends RefCounted
## 출격 한 판의 게임 로직.
## 화면 그리기와 분리되어 있어서, 자동 테스트에서 update()를 직접 불러 확인할 수 있다.
## 화면 쪽(scripts/run.gd)은 매 프레임 update()를 부르고 이 상태를 그리기만 한다.


## 운석 한 개
class Asteroid:
	var pos: Vector2
	var vel: Vector2
	var type: int  ## Balance.ASTEROID_TYPES 인덱스 (0 작음, 1 중간, 2 큼)
	var radius: float
	var damage: float
	var hp: float
	var max_hp: float
	var variant: int  ## 모양 변형 번호 (그리기용)
	var flash := 0.0  ## 탄에 맞은 직후 번쩍이는 남은 시간 (그리기용)


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
var hp := Balance.SHIP_MAX_HP
var max_hp := Balance.SHIP_MAX_HP
## 남은 무적 시간
var invuln := 0.0
var alive := true
## 출격 후 지난 시간
var time := 0.0
## 지금 화면에 보이는 크기 (운석 등장·제거 거리 계산용)
var view_size := Vector2(Balance.BASE_LANDSCAPE)
var asteroids: Array[Asteroid] = []
var bullets: Array[Bullet] = []
## 이번 프레임에 탄으로 부서진 운석 (효과·보상용)
var destroyed: Array[Asteroid] = []
## 이번 프레임에 일어난 일 (효과·소리용): "hit", "dead", "shoot", "destroy"
var events: PackedStringArray = []
## 탄으로 부순 운석 수
var kills := 0

# 자동 공격 능력치 (나중에 강화로 바뀜)
var fire_interval := Balance.FIRE_INTERVAL
var fire_range := Balance.FIRE_RANGE
var bullet_damage := Balance.BULLET_DAMAGE
var bullet_count := Balance.BULLET_COUNT

var _spawn_timer := 0.0
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
	if not alive:
		return
	delta = clampf(delta, 0.0, Balance.MAX_FRAME_DELTA)
	time += delta
	invuln = maxf(invuln - delta, 0.0)
	player_pos += move.limit_length(1.0) * Balance.SHIP_SPEED * delta

	_spawn_timer -= delta
	while _spawn_timer <= 0.0:
		if asteroids.size() < Balance.MAX_ASTEROIDS:
			spawn_asteroid()
		_spawn_timer += spawn_interval(time)

	_move_asteroids(delta)
	_auto_fire(delta)
	_move_bullets(delta)
	_check_bullet_hits()
	_check_player_hits()


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
func spawn_asteroid() -> Asteroid:
	var a := Asteroid.new()
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
	a.vel = Vector2.from_angle(aim) * rng.randf_range(info["speed_min"], info["speed_max"])
	asteroids.append(a)
	return a


## 운석을 움직이고, 너무 멀어진 운석은 없앤다.
func _move_asteroids(delta: float) -> void:
	var limit := despawn_distance(view_size)
	var kept: Array[Asteroid] = []
	for a in asteroids:
		a.pos += a.vel * delta
		a.flash = maxf(a.flash - delta, 0.0)
		if a.pos.distance_to(player_pos) <= limit:
			kept.append(a)
	asteroids = kept


## 사거리 안에 운석이 있으면 가장 가까운 운석을 향해 발사한다.
func _auto_fire(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var target := nearest_asteroid(player_pos, asteroids, fire_range)
	if target == null:
		_fire_timer = 0.0  # 대상이 없으면 장전된 상태로 기다린다
		return
	# 움직이는 운석이 탄과 만날 지점을 노린다.
	var base_angle := intercept_angle(player_pos, target.pos, target.vel, Balance.BULLET_SPEED)
	var life := fire_range / Balance.BULLET_SPEED * Balance.BULLET_LIFETIME_FACTOR
	for angle in spread_angles(base_angle, bullet_count, deg_to_rad(Balance.MULTI_SHOT_SPREAD_DEG)):
		var b := Bullet.new()
		b.pos = player_pos
		b.prev_pos = player_pos
		b.vel = Vector2.from_angle(angle) * Balance.BULLET_SPEED
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
		for a in asteroids:
			# 이번 프레임에 지나간 선분으로 판정해, 프레임이 느려도 탄이 운석을 뚫고 지나가지 않게 한다.
			if a.hp > 0.0 and segment_distance(b.prev_pos, b.pos, a.pos) < a.radius + Balance.BULLET_RADIUS:
				a.hp -= b.damage
				a.flash = 0.08
				hit = true
				break
		if not hit:
			kept_bullets.append(b)
	bullets = kept_bullets
	var kept: Array[Asteroid] = []
	for a in asteroids:
		if a.hp <= 0.0:
			_on_asteroid_destroyed(a)
		else:
			kept.append(a)
	asteroids = kept


## 탄으로 운석을 부쉈을 때
func _on_asteroid_destroyed(a: Asteroid) -> void:
	kills += 1
	destroyed.append(a)
	events.append("destroy")


## 우주선과 부딪힌 운석: 무적이 아니면 데미지를 주고 부서진다. 무적 중에는 그냥 지나간다.
func _check_player_hits() -> void:
	var kept: Array[Asteroid] = []
	for a in asteroids:
		var touching := a.pos.distance_to(player_pos) < a.radius + Balance.SHIP_RADIUS
		if touching and alive and damage_player(a.damage):
			continue  # 부서진 운석은 목록에서 뺀다
		kept.append(a)
	asteroids = kept


# ── 규칙 계산 (자동 테스트 대상) ─────────────────────

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
static func nearest_asteroid(from: Vector2, list: Array[Asteroid], max_range: float) -> Asteroid:
	var best: Asteroid = null
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


## 여러 발을 쏠 때 각 탄의 각도: 가운데를 기준으로 spread 간격의 부채꼴
static func spread_angles(center: float, count: int, spread: float) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for i in maxi(count, 1):
		result.append(center + (i - (maxi(count, 1) - 1) / 2.0) * spread)
	return result


## 지금 시간의 운석 등장 간격
static func spawn_interval(t: float) -> float:
	var k := clampf(t / Balance.SPAWN_RAMP_TIME, 0.0, 1.0)
	return lerpf(Balance.SPAWN_INTERVAL_START, Balance.SPAWN_INTERVAL_MIN, k)


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
