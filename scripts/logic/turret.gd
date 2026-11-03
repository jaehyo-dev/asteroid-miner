class_name Turret
extends RefCounted
## 고대 포탑의 규칙: 제자리에 떠 있는 구조물. 포신을 천천히 돌려 우주선을 노리고,
## 화면에 보이고 사거리 안이면 충전(빛) → 에너지탄 한 발을 쏜다.
## 포탑 상태(포신 각도, 충전, 재장전)는 RunSim.Enemy에 있고, 여기는 계산만 한다.


## 한 프레임 진행. 포신을 돌리고, 쏠 때가 되면 true를 돌려준다 (탄은 RunSim이 만든다).
## can_fire: 화면에 보이고 사거리 안인지 (보이지 않는 곳에서는 쏘지 않는다 → 억울하지 않게)
static func update(e: RunSim.Enemy, delta: float, target: Vector2, can_fire: bool) -> bool:
	e.aim = RunSim.turn_toward(e.aim, (target - e.pos).angle(), Balance.TURRET_TURN_SPEED * delta)
	e.reload = maxf(e.reload - delta, 0.0)
	if e.charge >= 0.0:
		# 충전 중: 다 차면 쏜다 (충전 중 화면 밖으로 벗어나면 취소)
		if not can_fire:
			e.charge = -1.0
			return false
		e.charge += delta
		if e.charge >= Balance.TURRET_CHARGE_TIME:
			e.charge = -1.0
			e.reload = Balance.TURRET_FIRE_INTERVAL
			return true
		return false
	if can_fire and e.reload <= 0.0 and aimed(e, target):
		e.charge = 0.0
	return false


## 포신이 우주선 쪽을 거의 바라보는지 (TURRET_AIM_TOLERANCE_DEG 안)
static func aimed(e: RunSim.Enemy, target: Vector2) -> bool:
	return absf(wrapf((target - e.pos).angle() - e.aim, -PI, PI)) <= deg_to_rad(Balance.TURRET_AIM_TOLERANCE_DEG)


## 충전 진행도 0~1 (그리기용: 충전 중이 아니면 0)
static func charge_progress(e: RunSim.Enemy) -> float:
	if e.charge < 0.0:
		return 0.0
	return clampf(e.charge / Balance.TURRET_CHARGE_TIME, 0.0, 1.0)


## 포탑이 쏠 수 있는 자리인지: 화면 안쪽(가장자리에서 margin 안)에 보이고 우주선과 사거리 안
static func can_fire_at(turret_pos: Vector2, ship_pos: Vector2, view: Vector2, margin: float) -> bool:
	var rel := turret_pos - ship_pos
	var half := view / 2.0 - Vector2(margin, margin)
	return absf(rel.x) <= half.x and absf(rel.y) <= half.y and rel.length() <= Balance.TURRET_RANGE


## 포탑 등장 방향: 우주선이 움직이면 가는 쪽 앞(±TURRET_SPAWN_AHEAD_DEG)에, 멈춰 있으면 아무 방향.
## (멈춰 있지 않은 구조물이라 지나쳐 가는 쪽에 두어야 만난다)
static func spawn_angle(random: RandomNumberGenerator, ship_vel: Vector2) -> float:
	if ship_vel.length() < 1.0:
		return random.randf() * TAU
	return ship_vel.angle() + deg_to_rad(random.randf_range(-Balance.TURRET_SPAWN_AHEAD_DEG, Balance.TURRET_SPAWN_AHEAD_DEG))
