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
	var variant: int  ## 모양 변형 번호 (그리기용)


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
## 이번 프레임에 일어난 일 (효과·소리용): "hit", "dead"
var events: PackedStringArray = []

var _spawn_timer := 0.0


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	_spawn_timer = spawn_interval(0.0)


## 한 프레임 진행. move는 길이 0~1의 이동 방향.
func update(delta: float, move: Vector2) -> void:
	events.clear()
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
		if a.pos.distance_to(player_pos) <= limit:
			kept.append(a)
	asteroids = kept


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
