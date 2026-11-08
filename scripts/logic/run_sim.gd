class_name RunSim
extends RefCounted
## 출격 한 판의 게임 로직.
## 화면 그리기와 분리되어 있어서, 자동 테스트에서 update()를 직접 불러 확인할 수 있다.
## 화면 쪽(scripts/run.gd)은 매 프레임 update()를 부르고 이 상태를 그리기만 한다.


## 적 종류: 운석, 고대 경비선 (생명체는 Balance.CREATURES의 키)
const ROCK := "rock"
const GUARD := "guard"


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
	var kind := ROCK  ## 종류: ROCK(운석), GUARD(고대 경비선) 또는 Balance.CREATURES의 키 ("jelly", "bug")
	var age := 0.0  ## 나온 뒤 지난 시간
	var flash := 0.0  ## 탄에 맞은 직후 번쩍이는 남은 시간 (그리기용)
	var hit_dir := Vector2.ZERO  ## 마지막으로 맞은 탄이 날아온 방향 (맞으면 그쪽으로 튕기는 모션)
	var hit_time := 0.0  ## 튕김 모션 남은 시간 (그리기용)
	# 고대 경비선 전용
	var aim := 0.0  ## 선체(포)가 바라보는 방향 (라디안)
	var charge := -1.0  ## 충전한 시간 (충전 중이 아니면 -1)
	var reload := 0.0  ## 다음 충전까지 남은 시간

	## 부딪혀도 부서지지 않는 단단한 적인지 (황금 운석, 고대 경비선)
	func sturdy() -> bool:
		return golden or kind == GUARD


## 떠 있는 광물 한 개
class Mineral:
	var pos: Vector2
	var grade: int  ## Balance.MINERAL_GRADES 인덱스 (0 일반 ~ 3 전설)
	var vel := Vector2.ZERO  ## 운석에서 튕겨 나가는 속도 (점점 줄어 멈춤)
	var attracted := false  ## 자석에 끌려오는 중인지 (한번 끌리면 끝까지 따라옴)


## 에너지탄 한 개: 심연의 포격 또는 고대 경비선이 쏜다 (자동 공격으로 부술 수 없음)
class Shot:
	var pos: Vector2
	var prev_pos: Vector2  ## 이번 프레임 이동 전 위치 (지나간 선분으로 충돌 판정)
	var vel: Vector2
	var life: float  ## 남은 비행 시간
	var damage := Balance.BARRAGE_SHOT_DAMAGE
	var radius := Balance.BARRAGE_SHOT_RADIUS
	var guard := false  ## 고대 경비선이 쏜 탄인지 (그리기용)


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
## 우주선 속도 (포격·날벌레가 앞질러 노릴 때 씀)
var player_vel := Vector2.ZERO
var hp := Balance.SHIP_MAX_HP
var max_hp := Balance.SHIP_MAX_HP
## 남은 무적 시간
var invuln := 0.0
## 레벨업 직후 슬로모션 동안 강화 고르기 전이어도 진행할지 (화면 쪽 scripts/run.gd가 정함)
var run_during_levelup := false
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
## 이번 프레임에 우주선과 부딪혀 부서진 적 (광물 없음, 폭발 그림용)
var crashed: Array[Enemy] = []
## 이번 프레임에 주운 광물 {pos, grade, gain(화물칸에서 늘어난 가치)} (줍기 연출·효과음용)
var picked: Array[Dictionary] = []
## 이번 프레임에 일어난 일 (효과·소리용): "hit", "dead", "shoot", "destroy", "pickup", "levelup", "golden",
## "barrage_warning"·"barrage_charge"·"barrage_fire"(심연의 포격), "new_barrage"(첫 포격),
## "new_jelly"·"new_bug"·"new_guard"(처음 등장), "guard_charge"·"guard_fire"(고대 경비선),
## "raid_warning", "raid_start", "raid_end", "raid_golden"(습격과 함께 온 황금 운석),
## "gate_open"·"gate_close"(워프 게이트), "warp_charge"·"warp_cancel"·"warp_done"(워프 충전),
## "cargo_heavy"(화물이 무거워 처음 느려짐), "hit_rock"·"hit_enemy"(탄이 운석·적에 맞음, 맞은 수만큼)
var events: PackedStringArray = []
## 탄으로 부순 적 수 (운석·황금 운석·생명체)
var kills := 0
var minerals: Array[Mineral] = []
## 이번 판에 주운 광물 수 (등급별, 화물칸에 못 실은 것 포함)
var collected := PackedInt32Array([0, 0, 0, 0])
## 이번 판에 주운 광물의 총 가치 (화물칸에 못 실은 것 포함)
var mineral_value := 0
## 화물칸 (귀환하면 이 광물을 가져간다)
var cargo := Cargo.new()
## 워프 게이트와 충전
var gate := WarpGate.new()
## 워프 충전을 마쳐 귀환했는지 (귀환하면 판이 끝난다)
var returned := false
## 비상 보험 단계 (기지 업그레이드에서 정함). 죽었을 때 남기는 비율을 올린다.
var insurance_level := 0
## 기지 공용 업그레이드 id → 단계 (apply_base로 정함, 판 동안 바뀌지 않음)
var base_levels: Dictionary = {}

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
## 다음 심연의 포격까지 남은 시간
var _barrage_timer := Balance.BARRAGE_FIRST_TIME
## 진행 중인 포격 (예고·충전·발사)과 날아가는 에너지탄
var barrages: Array[Barrage] = []
var shots: Array[Shot] = []
## 다음 발사까지 남은 시간 (0 이하면 대상이 생기는 즉시 발사)
var _fire_timer := 0.0
## 생명체 등장 타이머
var _jelly_timer := Balance.JELLY_FIRST_TIME
var _bug_timer := Balance.BUG_FIRST_TIME
## 다음 고대 경비선까지 남은 시간
var _guard_timer := Balance.GUARD_FIRST_TIME
## 습격 중 다음 등장까지 남은 시간
var _raid_spawn_timer := 0.0
## 습격 이벤트 흐름
var raid := RaidDirector.new()
## 이미 한 번 나온 생명체 종류 (처음 나올 때 경고용)
var introduced := {}


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
	crashed.clear()
	picked.clear()
	if is_over() or (not choices.is_empty() and not run_during_levelup):
		return  # 판이 끝났거나 강화를 고르는 중이면 멈춘다 (레벨업 슬로모션 동안만 계속)
	delta = clampf(delta, 0.0, Balance.MAX_FRAME_DELTA)
	time += delta
	invuln = maxf(invuln - delta, 0.0)
	player_vel = move.limit_length(1.0) * current_speed()
	if move != Vector2.ZERO and cargo.fill_ratio() > Balance.CARGO_HEAVY_START and not introduced.has("heavy"):
		introduced["heavy"] = true
		events.append("cargo_heavy")  # 처음 느려질 때 한 번 안내
	player_pos += player_vel * delta
	if move != Vector2.ZERO:
		facing = turn_toward(facing, move.angle(), Balance.SHIP_TURN_SPEED * delta)
	events.append_array(gate.update(delta, rng, player_pos))
	if gate.done:
		returned = true
		return  # 귀환 완료: 이 순간의 화물칸을 그대로 가져간다

	for e in raid.update(delta, rng, time >= Balance.BUG_FIRST_TIME):
		events.append(e)
		if e == "raid_start":
			_raid_spawn_timer = 0.0
			# 습격 방향에서 황금 운석이 함께 온다 (평소 최대 수 GOLDEN_MAX에 RAID_GOLDEN_COUNT만큼 더 허용)
			var spawned := false
			for i in Balance.RAID_GOLDEN_COUNT:
				if golden_count() < Balance.GOLDEN_MAX + Balance.RAID_GOLDEN_COUNT:
					spawn_golden(raid.direction + deg_to_rad(rng.randf_range(-Balance.RAID_ARC_DEG, Balance.RAID_ARC_DEG) / 2.0))
					spawned = true
			if spawned:
				events.append("raid_golden")
	# 습격이 끝난 뒤 숨 돌릴 틈에는 평소 등장을 멈춘다 (황금 운석은 그대로)
	_spawn_regular(delta, raid.state == RaidDirector.State.CALM)
	if raid.state == RaidDirector.State.ACTIVE:
		_spawn_raid(delta)
	_golden_timer -= delta
	while _golden_timer <= 0.0:
		if golden_count() < Balance.GOLDEN_MAX and enemies.size() < Balance.MAX_ENEMIES:
			spawn_golden()
		_golden_timer += golden_interval(time)

	_update_barrages(delta)
	_move_enemies(delta)
	_auto_fire(delta)
	_move_bullets(delta)
	_check_bullet_hits()
	_check_player_hits()
	_update_minerals(delta)


## 평소 등장: 운석, 심연의 포격, 우주 해파리, 날벌레 떼.
## hold(숨 돌릴 틈)이면 시간은 그대로 흐르되 나오지 않고 "준비됨"에서 기다렸다가, 틈이 끝나면 한 번씩 나온다.
## (타이머를 멈추면 이후 등장 시각이 모두 밀리므로 멈추지 않는다)
func _spawn_regular(delta: float, hold: bool) -> void:
	_spawn_timer = _tick(_spawn_timer, delta, hold)
	while _spawn_timer <= 0.0:
		if enemies.size() < Balance.MAX_ENEMIES:
			spawn_asteroid()
		_spawn_timer += spawn_interval(time)
	_barrage_timer = _tick(_barrage_timer, delta, hold)
	while _barrage_timer <= 0.0:
		start_barrage()
		_barrage_timer += barrage_interval(time)
	_jelly_timer = _tick(_jelly_timer, delta, hold)
	while _jelly_timer <= 0.0:
		if enemies.size() < Balance.MAX_ENEMIES:
			spawn_creature("jelly")
		_jelly_timer += creature_interval(Balance.JELLY_INTERVAL_START, Balance.JELLY_INTERVAL_MIN, time)
	_bug_timer = _tick(_bug_timer, delta, hold)
	while _bug_timer <= 0.0:
		if enemies.size() + Balance.BUG_SWARM_SIZE <= Balance.MAX_ENEMIES:
			spawn_swarm()
		_bug_timer += creature_interval(Balance.BUG_INTERVAL_START, Balance.BUG_INTERVAL_MIN, time)
	_guard_timer = _tick(_guard_timer, delta, hold)
	while _guard_timer <= 0.0:
		if guard_count() < Balance.GUARD_MAX and enemies.size() < Balance.MAX_ENEMIES:
			spawn_guard()
		_guard_timer += creature_interval(Balance.GUARD_INTERVAL_START, Balance.GUARD_INTERVAL_MIN, time)


## 등장 타이머 한 프레임: hold면 0 바로 위에서 멈춰 기다린다.
static func _tick(timer: float, delta: float, hold: bool) -> float:
	timer -= delta
	return maxf(timer, 0.0001) if hold else timer


## 습격 중 등장: 습격 방향(raid.direction)의 좁은 폭에서 몰려온다.
func _spawn_raid(delta: float) -> void:
	_raid_spawn_timer -= delta
	while _raid_spawn_timer <= 0.0:
		var angle := raid.direction + deg_to_rad(rng.randf_range(-Balance.RAID_ARC_DEG, Balance.RAID_ARC_DEG) / 2.0)
		if raid.kind == RaidDirector.SWARM:
			if enemies.size() + Balance.BUG_SWARM_SIZE <= Balance.MAX_ENEMIES:
				spawn_swarm(angle)
			_raid_spawn_timer += Balance.RAID_SWARM_INTERVAL
		else:
			if enemies.size() < Balance.MAX_ENEMIES:
				var a := spawn_asteroid(angle)
				# 폭풍 운석은 우주선 쪽으로 더 곧게 온다
				var aim := (player_pos - a.pos).angle() + deg_to_rad(rng.randf_range(-Balance.RAID_STORM_AIM_SPREAD_DEG, Balance.RAID_STORM_AIM_SPREAD_DEG))
				a.vel = Vector2.from_angle(aim) * a.vel.length()
			_raid_spawn_timer += raid_storm_interval(time)


## 생명체 하나를 화면 밖에 만든다 (angle을 주면 그 방향에서). 처음 나온 종류면 "new_종류" 이벤트.
func spawn_creature(creature: String, angle: float = INF) -> Enemy:
	var info: Dictionary = Balance.CREATURES[creature]
	var e := Enemy.new()
	e.kind = creature
	e.radius = info["radius"]
	e.damage = info["damage"]
	e.max_hp = asteroid_hp(info["hp"], time)
	e.hp = e.max_hp
	e.variant = rng.randi_range(0, 3)
	e.pos = spawn_position(rng, player_pos, view_size, e.radius, angle)
	e.vel = (player_pos - e.pos).normalized() * creature_speed(creature, time)
	enemies.append(e)
	if not introduced.has(creature):
		introduced[creature] = true
		events.append("new_" + creature)
	return e


## 날벌레 떼: 같은 곳에서 BUG_SWARM_SIZE마리가 조금씩 퍼져 우주선이 갈 곳으로 돌진한다.
func spawn_swarm(angle: float = INF) -> Array[Enemy]:
	var group: Array[Enemy] = []
	var lead := spawn_creature("bug", angle)
	var speed := creature_speed("bug", time)
	var dir := Vector2.from_angle(intercept_angle(lead.pos, player_pos, player_vel, speed))
	for i in Balance.BUG_SWARM_SIZE:
		var e := lead if i == 0 else spawn_creature("bug")
		e.pos = lead.pos + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Balance.BUG_SWARM_SPREAD
		e.vel = dir * speed
		group.append(e)
	return group


## 고대 경비선 하나를 화면 밖에 만든다. 우주선을 따라다니며 쏜다. 처음이면 "new_guard".
func spawn_guard(angle: float = INF) -> Enemy:
	var e := Enemy.new()
	e.kind = GUARD
	e.radius = Balance.GUARD["radius"]
	e.damage = Balance.GUARD["damage"]
	e.max_hp = asteroid_hp(Balance.GUARD["hp"], time)
	e.hp = e.max_hp
	e.variant = rng.randi_range(0, 3)  # 짝수면 시계 방향, 홀수면 반대로 돈다
	e.pos = spawn_position(rng, player_pos, view_size, e.radius, angle)
	e.aim = (player_pos - e.pos).angle()
	e.vel = Vector2.from_angle(e.aim) * guard_speed(time)
	e.reload = Balance.GUARD_FIRE_INTERVAL / 2.0
	enemies.append(e)
	if not introduced.has(GUARD):
		introduced[GUARD] = true
		events.append("new_guard")
	return e


## 지금 있는 고대 경비선 수
func guard_count() -> int:
	var n := 0
	for e in enemies:
		if e.kind == GUARD:
			n += 1
	return n


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


## 운석 하나를 화면 밖에 만든다 (angle을 주면 그 방향, 아니면 무작위). 만든 운석을 돌려준다.
func spawn_asteroid(angle: float = INF) -> Enemy:
	var a := Enemy.new()
	a.type = pick_weighted(rng, asteroid_weights(time))
	var info: Dictionary = Balance.ASTEROID_TYPES[a.type]
	a.radius = info["radius"]
	a.damage = info["damage"]
	a.max_hp = asteroid_hp(info["hp"], time)
	a.hp = a.max_hp
	a.variant = rng.randi_range(0, 3)
	a.pos = spawn_position(rng, player_pos, view_size, a.radius, angle)
	# 우주선 쪽을 향하되 조금씩 빗나가게 한다.
	var aim := (player_pos - a.pos).angle() + deg_to_rad(rng.randf_range(-Balance.ASTEROID_AIM_SPREAD_DEG, Balance.ASTEROID_AIM_SPREAD_DEG))
	a.vel = Vector2.from_angle(aim) * rng.randf_range(info["speed_min"], info["speed_max"]) * asteroid_speed_mult(time)
	enemies.append(a)
	return a


## 심연의 포격을 시작한다: 화면 밖 먼 곳에서 우주선이 갈 곳을 노리는 조준선이 먼저 보인다.
func start_barrage() -> Barrage:
	var from := spawn_position(rng, player_pos, view_size, 0.0)
	var b := Barrage.new(from, Barrage.aim_direction(from, player_pos, player_vel, Balance.BARRAGE_LEAD_TIME))
	barrages.append(b)
	events.append("barrage_warning")
	if not introduced.has("barrage"):
		introduced["barrage"] = true
		events.append("new_barrage")
	return b


## 포격 진행: 충전·발사, 에너지탄 이동, 우주선과 충돌 (무적이면 지나감, 맞으면 탄은 사라짐)
func _update_barrages(delta: float) -> void:
	var kept: Array[Barrage] = []
	var fired := false
	for b in barrages:
		var was_firing := b.phase != Barrage.Phase.DONE
		var r := b.step(delta)
		if r["charge"]:
			events.append("barrage_charge")
		for i in int(r["fired"]):
			var s := Shot.new()
			s.pos = b.origin
			s.prev_pos = b.origin
			s.vel = b.dir * Balance.BARRAGE_SHOT_SPEED
			# 우주선 쪽을 지나 화면 반대편 밖까지 날아갈 만큼
			s.life = (b.origin.distance_to(player_pos) + despawn_distance(view_size)) / Balance.BARRAGE_SHOT_SPEED
			shots.append(s)
			fired = true
		if was_firing and b.phase == Barrage.Phase.DONE:
			# 마지막 탄이 우주선 쪽을 지나갈 때까지 포격을 남긴다 (조준선은 사라져도 가장자리 "!" 표시는 유지)
			b.linger = b.origin.distance_to(player_pos) / Balance.BARRAGE_SHOT_SPEED + Balance.BARRAGE_LINGER_EXTRA
		elif b.phase == Barrage.Phase.DONE:
			b.linger -= delta
		if not b.finished():
			kept.append(b)
	barrages = kept
	if fired:
		events.append("barrage_fire")
	var kept_shots: Array[Shot] = []
	for s in shots:
		s.prev_pos = s.pos
		s.pos += s.vel * delta
		s.life -= delta
		if s.life <= 0.0:
			continue
		var touching := segment_distance(s.prev_pos, s.pos, player_pos) < s.radius + Balance.SHIP_RADIUS
		if touching and alive and damage_player(s.damage):
			continue  # 맞은 탄은 사라진다
		kept_shots.append(s)
	shots = kept_shots


## 우주선이 지금 위험한 조준선 위에 있으면, 그 선에서 벗어나는 방향 (아니면 ZERO). 밸런스 봇용.
## lookahead: 날아가는 탄은 이 시간(초) 안에 닿을 것만 피한다.
func barrage_escape(pos: Vector2, margin: float, lookahead: float = 1.0) -> Vector2:
	for b in barrages:
		if b.phase == Barrage.Phase.DONE:
			continue  # 다 쏜 뒤에는 위험을 날아가는 탄(아래)에서 본다
		var d := Barrage.distance_from_line(b.origin, b.dir, pos)
		if d < margin:
			var side := Vector2(-b.dir.y, b.dir.x)
			return side if (pos - b.origin).dot(side) >= 0.0 else -side
	for s in shots:
		var along := (pos - s.pos).dot(s.vel.normalized())
		if along > s.vel.length() * lookahead:
			continue  # 아직 멀리 있는 탄은 나중에 피한다 (사람도 가까이 올 때 비켜섬)
		var d := Barrage.distance_from_line(s.pos, s.vel.normalized(), pos)
		if d < margin:
			var side := Vector2(-s.vel.y, s.vel.x).normalized()
			return side if (pos - s.pos).dot(side) >= 0.0 else -side
	return Vector2.ZERO


## 황금 운석 하나를 화면 밖에 만든다 (angle을 주면 그 방향, 아니면 무작위). 우주선 근처를 비스듬히 지나가도록 날아간다.
func spawn_golden(angle: float = INF) -> Enemy:
	var a := Enemy.new()
	a.golden = true
	a.type = Balance.ASTEROID_TYPES.size() - 1  # 그리기·조준에는 큰 운석처럼 취급
	a.radius = Balance.GOLDEN["radius"]
	a.damage = Balance.GOLDEN["damage"]
	a.max_hp = asteroid_hp(Balance.GOLDEN["hp"], time)
	a.hp = a.max_hp
	a.variant = rng.randi_range(0, 3)
	a.pos = spawn_position(rng, player_pos, view_size, a.radius, angle)
	# 우주선을 곧장 향하지 않고 GOLDEN_AIM_MIN_DEG ~ GOLDEN_AIM_SPREAD_DEG만큼 비껴 지나간다 (왼쪽·오른쪽 무작위)
	var off := rng.randf_range(Balance.GOLDEN_AIM_MIN_DEG, Balance.GOLDEN_AIM_SPREAD_DEG) * (1.0 if rng.randf() < 0.5 else -1.0)
	var aim := (player_pos - a.pos).angle() + deg_to_rad(off)
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


## 적을 움직이고, 너무 멀어진 적은 없앤다. 생명체는 우주선 쪽으로 방향을 튼다.
func _move_enemies(delta: float) -> void:
	var limit := despawn_distance(view_size)
	var kept: Array[Enemy] = []
	var guard_fired := false
	for a in enemies:
		a.age += delta
		if a.kind == GUARD:
			a.vel = Guard.steer(a.pos, a.vel, player_pos, guard_speed(time), 1.0 if a.variant % 2 == 0 else -1.0, delta)
			var was_charging := a.charge >= 0.0
			var can_fire := alive and Guard.can_fire_at(a.pos, player_pos, view_size, Balance.GUARD_SCREEN_MARGIN)
			if Guard.update(a, delta, player_pos, can_fire):
				_fire_guard(a)
				guard_fired = true
			elif not was_charging and a.charge >= 0.0:
				events.append("guard_charge")
		elif a.kind != ROCK and (a.kind != "bug" or a.age < Balance.BUG_HOMING_TIME):
			a.vel = steer(a.pos, a.vel, player_pos, creature_speed(a.kind, time), float(Balance.CREATURES[a.kind]["accel"]), delta)
		a.pos += a.vel * delta
		a.flash = maxf(a.flash - delta, 0.0)
		a.hit_time = maxf(a.hit_time - delta, 0.0)
		var keep_limit := limit
		if a.golden:
			keep_limit = limit * Balance.GOLDEN_DESPAWN_FACTOR
		elif a.kind == GUARD:
			keep_limit = limit * Balance.GUARD_DESPAWN_FACTOR
		if a.pos.distance_to(player_pos) <= keep_limit:
			kept.append(a)
	enemies = kept
	if guard_fired:
		events.append("guard_fire")


## 고대 경비선이 선체가 바라보는 방향으로 에너지탄 한 발을 쏜다 (뱃머리에서 나감).
func _fire_guard(t: Enemy) -> void:
	var dir := Vector2.from_angle(t.aim)
	var s := Shot.new()
	s.pos = t.pos + dir * t.radius
	s.prev_pos = s.pos
	s.vel = dir * Balance.GUARD_SHOT_SPEED
	s.damage = Balance.GUARD_SHOT_DAMAGE
	s.radius = Balance.GUARD_SHOT_RADIUS
	s.guard = true
	s.life = despawn_distance(view_size) / Balance.GUARD_SHOT_SPEED
	shots.append(s)


## 사거리 안에 운석이 있으면 가장 가까운 운석을 향해 발사한다.
func _auto_fire(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var target := pick_target(player_pos, enemies, fire_range)
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
				a.flash = Juice.ENEMY_FLASH_TIME
				a.hit_dir = b.vel.normalized()
				a.hit_time = Balance.HIT_KNOCK_TIME
				events.append("hit_rock" if a.kind == ROCK else "hit_enemy")
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
			var m := drop_mineral(a.pos, int(drop["grade"]))
			# 운석 자리에서 사방으로 튕겨 나가 감속하며 멈춘다 (멈출 때까지 가는 거리 = 속도 / 감속)
			m.vel = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(Juice.MINERAL_POP_MIN, Juice.MINERAL_POP_MAX) * Juice.MINERAL_POP_DAMP


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


## 지금 이동 속도 = 강화로 오른 속도(move_speed) × 화물 무게 배율
func current_speed() -> float:
	return move_speed * Cargo.speed_mult(cargo.fill_ratio())


## 출격 전에 기지 공용 업그레이드를 적용한다: 능력치를 다시 계산하고 체력을 가득 채운다.
func apply_base(levels: Dictionary) -> void:
	base_levels = levels.duplicate()
	var blv := func(id: String) -> int: return int(base_levels.get(id, 0))
	insurance_level = blv.call("insurance")
	cargo.capacity = Balance.CARGO_CAPACITY + Balance.BASE_CARGO_ADD * blv.call("cargo")
	apply_upgrades()
	hp = max_hp


## 강화 단계(레벨업 + 기지)에 맞게 능력치를 다시 계산한다 (항상 기본값에서 계산해 오차가 쌓이지 않게).
func apply_upgrades() -> void:
	var lv := func(id: String) -> int: return int(upgrade_levels.get(id, 0))
	var blv := func(id: String) -> int: return int(base_levels.get(id, 0))
	fire_interval = Balance.FIRE_INTERVAL * pow(Balance.UP_FIRE_INTERVAL_MULT, lv.call("fire_rate"))
	bullet_count = Balance.BULLET_COUNT + Balance.UP_BULLET_COUNT_ADD * lv.call("multishot")
	bullet_damage = (Balance.BULLET_DAMAGE + Balance.UP_DAMAGE_ADD * lv.call("damage")) * (1.0 + Balance.BASE_DAMAGE_MULT_ADD * blv.call("damage"))
	magnet_radius = Balance.MAGNET_RADIUS * (1.0 + Balance.UP_MAGNET_ADD * lv.call("magnet") + Balance.BASE_MAGNET_ADD * blv.call("magnet"))
	move_speed = Balance.SHIP_SPEED * (1.0 + Balance.UP_SPEED_ADD * lv.call("speed") + Balance.BASE_SPEED_ADD * blv.call("speed"))
	max_hp = Balance.SHIP_MAX_HP + Balance.UP_MAX_HP_ADD * lv.call("max_hp") + Balance.BASE_MAX_HP_ADD * blv.call("max_hp")
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
		if not m.attracted and m.vel != Vector2.ZERO:
			m.pos += m.vel * delta
			m.vel *= exp(-Juice.MINERAL_POP_DAMP * delta)
			if m.vel.length() < 1.0:
				m.vel = Vector2.ZERO
		var dist := m.pos.distance_to(player_pos)
		if dist <= magnet_radius:
			m.attracted = true
		if m.attracted:
			m.vel = Vector2.ZERO
			m.pos = m.pos.move_toward(player_pos, magnet_speed(dist, magnet_radius) * delta)
			dist = m.pos.distance_to(player_pos)
		if dist <= Balance.PICKUP_RADIUS:
			picked.append({"pos": m.pos, "grade": m.grade, "gain": collect(m.grade)})
		else:
			kept.append(m)
	minerals = kept


## 광물을 줍는다. 경험치는 화물칸이 꽉 찼어도 항상 받는다. 화물칸에서 늘어난 가치를 돌려준다.
func collect(grade: int) -> int:
	collected[grade] += 1
	mineral_value += int(Balance.MINERAL_GRADES[grade]["value"])
	events.append("pickup")
	var gain := cargo.add(grade)
	gain_xp(mineral_xp(grade))
	return gain


## 판이 끝났는지 (파괴 또는 귀환)
func is_over() -> bool:
	return not alive or returned


## 가져가는 광물 (등급별 개수): 귀환·진행 중이면 화물칸 전부, 파괴되면 보존 비율만큼 비싼 것부터
func brought_home() -> PackedInt32Array:
	if alive:
		return cargo.counts.duplicate()
	return Cargo.preserved(cargo.counts, Cargo.keep_ratio(insurance_level))


## 가져가는 광물의 최종 가치 = 가치 × 지금 위험도 배율 (반올림)
func final_value() -> int:
	return roundi(value_of(brought_home()) * risk_mult(time))


## 우주선과 부딪힌 운석: 무적이 아니면 데미지를 주고 부서진다. 무적 중에는 그냥 지나간다.
func _check_player_hits() -> void:
	var kept: Array[Enemy] = []
	for a in enemies:
		var touching := a.pos.distance_to(player_pos) < a.radius + Balance.SHIP_RADIUS
		if touching and alive and damage_player(a.damage) and not a.sturdy():
			crashed.append(a)
			continue  # 부서진 운석은 목록에서 뺀다 (황금 운석·고대 경비선은 부딪혀도 부서지지 않음)
		kept.append(a)
	enemies = kept


# ── 규칙 계산 (자동 테스트 대상) ─────────────────────

## 자석에 끌려오는 속도: 범위 끝(또는 밖)에서 기본 속도 × MAGNET_FAR, 가까울수록 빨라져 바로 옆에서 × MAGNET_NEAR
static func magnet_speed(dist: float, radius: float) -> float:
	var near := 1.0 - clampf(dist / maxf(radius, 1.0), 0.0, 1.0)
	return Balance.MAGNET_SPEED * lerpf(Juice.MAGNET_FAR, Juice.MAGNET_NEAR, near)


## 운석을 탄으로 부쉈을 때 떨어지는 광물 목록 [{grade, count}]
static func drops_of(a: Enemy) -> Array:
	if a.golden:
		return Balance.GOLDEN_DROPS
	if a.kind == GUARD:
		return Balance.GUARD_DROPS
	if a.kind != ROCK:
		var c: Dictionary = Balance.CREATURES[a.kind]
		return [{"grade": c["grade"], "count": c["minerals"]}]
	var info: Dictionary = Balance.ASTEROID_TYPES[a.type]
	return [{"grade": info["grade"], "count": info["minerals"]}]


## 위험도 배율: 출격 후 RISK_RAMP_TIME에 걸쳐 1.0 → RISK_MAX
static func risk_mult(t: float) -> float:
	return lerpf(1.0, Balance.RISK_MAX, clampf(t / Balance.RISK_RAMP_TIME, 0.0, 1.0))


## 지금 시간의 심연의 포격 간격: 시간이 지날수록 짧아진다.
static func barrage_interval(t: float) -> float:
	var k := clampf(t / Balance.SPAWN_RAMP_TIME, 0.0, 1.0)
	return lerpf(Balance.BARRAGE_INTERVAL_START, Balance.BARRAGE_INTERVAL_MIN, k)


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


## 자동 공격 대상: 사거리 안에서 가장 가까운 적. 단, 황금 운석은 TARGET_GOLDEN_PENALTY만큼 더 멀리 있는
## 것으로 쳐서, 가까이 다가오는 적을 먼저 쏜다 (단단한 황금 운석에 탄이 모두 묶여 다른 적에 그대로 맞는 일을 줄인다).
## 고대 경비선은 따라다니며 쏘는 위협이라 다른 적과 똑같이 가까운 순서로 쏜다.
static func pick_target(from: Vector2, list: Array[Enemy], max_range: float) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for a in list:
		var d := from.distance_to(a.pos)
		if d > max_range:
			continue
		var score := d + (Balance.TARGET_GOLDEN_PENALTY if a.golden else 0.0)
		if score < best_score:
			best = a
			best_score = score
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
## angle(라디안)을 주면 그 방향, INF면 무작위 방향.
static func spawn_position(random: RandomNumberGenerator, center: Vector2, view: Vector2, radius: float, angle: float = INF) -> Vector2:
	var distance := view.length() / 2.0 + Balance.SPAWN_MARGIN + radius
	var a := random.randf() * TAU if is_inf(angle) else angle
	return center + Vector2.from_angle(a) * distance


## 쫓아가기: 지금 속도를 목표 방향의 최고 속도 쪽으로 accel만큼 바꾼다 (급하게 꺾지 못함).
static func steer(pos: Vector2, vel: Vector2, target: Vector2, max_speed: float, accel: float, delta: float) -> Vector2:
	var desired := (target - pos).normalized() * max_speed
	return vel.move_toward(desired, accel * delta)


## 생명체 최고 속도: 시간이 지날수록 빨라지되 운석보다 천천히.
static func creature_speed(creature: String, t: float) -> float:
	return float(Balance.CREATURES[creature]["speed"]) * (1.0 + maxf(t, 0.0) / Balance.CREATURE_SPEED_GROWTH_TIME)


## 고대 경비선 최고 속도: 시간이 지날수록 조금씩 빨라진다 (5분이 지나도 우주선보다 느리게).
static func guard_speed(t: float) -> float:
	return Balance.GUARD_SPEED * (1.0 + maxf(t, 0.0) / Balance.GUARD_SPEED_GROWTH_TIME)


## 생명체 등장 간격: SPAWN_RAMP_TIME에 걸쳐 시작 → 최소로 줄어든다.
static func creature_interval(start: float, minimum: float, t: float) -> float:
	var k := clampf(t / Balance.SPAWN_RAMP_TIME, 0.0, 1.0)
	return lerpf(start, minimum, k)


## 운석 폭풍의 운석 간격: 보통 등장 간격이 줄어드는 만큼 함께 줄어든다 (최소 RAID_STORM_INTERVAL_MIN).
static func raid_storm_interval(t: float) -> float:
	var ratio := spawn_interval(t) / Balance.SPAWN_INTERVAL_START
	return maxf(Balance.RAID_STORM_INTERVAL * ratio, Balance.RAID_STORM_INTERVAL_MIN)


## 이보다 멀어진 운석은 없앤다.
static func despawn_distance(view: Vector2) -> float:
	return view.length() / 2.0 * Balance.DESPAWN_DISTANCE_FACTOR + Balance.SPAWN_MARGIN
