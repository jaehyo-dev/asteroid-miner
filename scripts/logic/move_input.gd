class_name MoveInput
extends RefCounted
## 이동 입력 계산 (키보드, 가상 조이스틱). 화면·노드와 무관한 순수 계산이라 자동 테스트한다.


## 키보드 방향키 상태 → 이동 방향 (길이 0 또는 1). 대각선도 같은 속도.
static func keyboard_vector(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	var v := Vector2(float(right) - float(left), float(down) - float(up))
	return v.normalized() if v != Vector2.ZERO else Vector2.ZERO


## 가상 조이스틱: 처음 누른 곳(base)에서 현재 손가락 위치(current)까지의 방향과 세기 (길이 0~1).
## radius만큼 끌면 최고 속도이고, dead_zone(0~1) 안쪽은 0으로 본다.
static func joystick_vector(base: Vector2, current: Vector2, radius: float, dead_zone: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var v := (current - base) / radius
	var strength := minf(v.length(), 1.0)
	if strength <= dead_zone:
		return Vector2.ZERO
	# 데드존 바깥을 0~1로 다시 펴서 살짝 끌어도 부드럽게 움직이게 한다.
	var scaled := (strength - dead_zone) / (1.0 - dead_zone)
	return v.normalized() * scaled


## 손가락이 반지름보다 멀리 가면 조이스틱 중심을 손가락 쪽으로 끌고 온다 (방향 전환이 쉬움).
static func follow_base(base: Vector2, current: Vector2, radius: float) -> Vector2:
	var offset := current - base
	if offset.length() <= radius:
		return base
	return current - offset.normalized() * radius


## 키보드와 조이스틱을 함께 쓸 때 합친 방향 (길이 최대 1)
static func combine(a: Vector2, b: Vector2) -> Vector2:
	return (a + b).limit_length(1.0)
