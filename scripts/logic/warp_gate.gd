class_name WarpGate
extends RefCounted
## 워프 게이트의 흐름: 기다림 → 열림(GATE_OPEN_TIME) → 닫힘 → 기다림 …
## 열린 게이트 안에 들어가면 워프 충전을 시작하고, WARP_CHARGE_TIME 동안 머무르면 귀환한다.
## 충전 중에 게이트를 벗어나면 취소된다. 충전 중에는 게이트가 닫히지 않는다 (다 채우기 직전에 사라지지 않게).

enum State { WAITING, OPEN }

var state := State.WAITING
## 기다리는 중이면 열릴 때까지, 열려 있으면 닫힐 때까지 남은 시간
var timer := Balance.GATE_FIRST_TIME
## 게이트 위치 (월드 좌표, 열릴 때 정해짐)
var pos := Vector2.ZERO
## 다음 게이트가 열릴 방향 (우주선 기준 각도). 기다리기 시작할 때 미리 정해서 화면에 알려 준다. 정하기 전이면 NAN.
var direction := NAN
## 충전한 시간 (충전 중이 아니면 -1)
var charge := -1.0
## 충전을 마쳐 귀환했는지
var done := false


## 시간을 진행한다. 일어난 일 "gate_open", "gate_close", "warp_charge"(충전 시작), "warp_cancel", "warp_done"을 돌려준다.
func update(delta: float, random: RandomNumberGenerator, player_pos: Vector2) -> PackedStringArray:
	var events: PackedStringArray = []
	if done:
		return events
	timer -= delta
	if state == State.WAITING:
		if is_nan(direction):
			direction = random.randf() * TAU
		if timer <= 0.0:
			state = State.OPEN
			pos = player_pos + Vector2.from_angle(direction) * Balance.GATE_DISTANCE
			direction = NAN
			timer += Balance.GATE_OPEN_TIME
			events.append("gate_open")
		return events
	if player_pos.distance_to(pos) <= Balance.GATE_RADIUS:
		if charge < 0.0:
			charge = 0.0
			events.append("warp_charge")
		charge += delta
		if charge >= Balance.WARP_CHARGE_TIME:
			done = true
			events.append("warp_done")
			return events
	elif charge >= 0.0:
		charge = -1.0
		events.append("warp_cancel")
	# 닫힐 시간이 지나도 충전 중이면 기다린다. 다음 게이트 시각은 원래 일정대로 (timer가 음수만큼 당겨짐)
	if timer <= 0.0 and charge < 0.0:
		state = State.WAITING
		timer += Balance.GATE_INTERVAL - Balance.GATE_OPEN_TIME
		events.append("gate_close")
	return events


## 충전 진행도 0~1 (충전 중이 아니면 0)
func charge_progress() -> float:
	return clampf(charge / Balance.WARP_CHARGE_TIME, 0.0, 1.0) if charge >= 0.0 else 0.0
