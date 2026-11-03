class_name Guard
extends RefCounted
## 고대 경비선의 규칙: 우주선과 일정 거리를 두고 따라다니며 주위를 도는 적 함선.
## 선체를 천천히 돌려 우주선을 노리고, 화면에 보이고 사거리 안이면 충전(뱃머리 빛) → 에너지탄 한 발을 쏜다.
## 경비선 상태(선체 방향, 충전, 재장전)는 RunSim.Enemy에 있고, 여기는 계산만 한다.


## 한 프레임 진행. 선체(포)를 돌리고, 쏠 때가 되면 true를 돌려준다 (탄은 RunSim이 만든다).
## can_fire: 화면에 보이고 사거리 안인지 (보이지 않는 곳에서는 쏘지 않는다 → 억울하지 않게)
static func update(e: RunSim.Enemy, delta: float, target: Vector2, can_fire: bool) -> bool:
	e.aim = RunSim.turn_toward(e.aim, (target - e.pos).angle(), Balance.GUARD_TURN_SPEED * delta)
	e.reload = maxf(e.reload - delta, 0.0)
	if e.charge >= 0.0:
		# 충전 중: 다 차면 쏜다 (충전 중 화면 밖으로 벗어나면 취소)
		if not can_fire:
			e.charge = -1.0
			return false
		e.charge += delta
		if e.charge >= Balance.GUARD_CHARGE_TIME:
			e.charge = -1.0
			e.reload = Balance.GUARD_FIRE_INTERVAL
			return true
		return false
	if can_fire and e.reload <= 0.0 and aimed(e, target):
		e.charge = 0.0
	return false


## 선체가 우주선 쪽을 거의 바라보는지 (GUARD_AIM_TOLERANCE_DEG 안)
static func aimed(e: RunSim.Enemy, target: Vector2) -> bool:
	return absf(wrapf((target - e.pos).angle() - e.aim, -PI, PI)) <= deg_to_rad(Balance.GUARD_AIM_TOLERANCE_DEG)


## 충전 진행도 0~1 (그리기용: 충전 중이 아니면 0)
static func charge_progress(e: RunSim.Enemy) -> float:
	if e.charge < 0.0:
		return 0.0
	return clampf(e.charge / Balance.GUARD_CHARGE_TIME, 0.0, 1.0)


## 경비선이 쏠 수 있는 자리인지: 화면 안쪽(가장자리에서 margin 안)에 보이고 우주선과 사거리 안
static func can_fire_at(guard_pos: Vector2, ship_pos: Vector2, view: Vector2, margin: float) -> bool:
	var rel := guard_pos - ship_pos
	var half := view / 2.0 - Vector2(margin, margin)
	return absf(rel.x) <= half.x and absf(rel.y) <= half.y and rel.length() <= Balance.GUARD_RANGE


## 따라다니기: 우주선과 GUARD_KEEP_DISTANCE를 유지하도록 다가가거나 물러나면서, 주위를 orbit_sign 방향으로 돈다.
## 지금 속도를 원하는 속도 쪽으로 accel만큼만 바꿔서 급하게 꺾지 못한다.
static func steer(pos: Vector2, vel: Vector2, target: Vector2, max_speed: float, orbit_sign: float, delta: float) -> Vector2:
	return vel.move_toward(desired_velocity(pos, target, max_speed, orbit_sign), Balance.GUARD_ACCEL * delta)


## 원하는 속도: 거리 차이만큼 다가가거나 물러나는 성분 + 주위를 도는 성분 (최고 속도 안)
static func desired_velocity(pos: Vector2, target: Vector2, max_speed: float, orbit_sign: float) -> Vector2:
	var rel := pos - target
	var dist := rel.length()
	if dist < 0.001:
		return Vector2.ZERO
	var out := rel / dist  # 우주선에서 경비선 쪽
	# 멀면 다가가고(안쪽), 가까우면 물러난다(바깥쪽). 거리 차이 1픽셀당 1.5픽셀/초, 최고 속도까지
	var radial := clampf((Balance.GUARD_KEEP_DISTANCE - dist) * 1.5, -max_speed, max_speed)
	var tangent := Vector2(-out.y, out.x) * orbit_sign * max_speed * Balance.GUARD_ORBIT_RATIO
	return (out * radial + tangent).limit_length(max_speed)
