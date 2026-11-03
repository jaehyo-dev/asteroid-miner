class_name Barrage
extends RefCounted
## 심연의 포격 한 번: 예고(조준선) → 충전 → 에너지탄 BARRAGE_SHOTS발 연사.
## 쏘는 곳(origin)은 화면 밖 먼 곳이고, 탄은 조준선(origin에서 dir 방향)을 따라 날아간다.
## 언제 몇 발을 쏠지만 정하고, 탄 이동과 충돌은 RunSim이 맡는다.

enum Phase { WARN, CHARGE, FIRE, DONE }

## 쏘는 곳 (월드 좌표, 화면 밖)
var origin := Vector2.ZERO
## 날아가는 방향 (길이 1)
var dir := Vector2.RIGHT
var phase := Phase.WARN
## 지금 단계에서 남은 시간 (발사 단계에서는 다음 탄까지 남은 시간)
var timer := Balance.BARRAGE_WARN_TIME
## 아직 쏘지 않은 탄 수
var shots_left := Balance.BARRAGE_SHOTS
## 다 쏜 뒤 포격을 남겨 둘 남은 시간 (마지막 탄이 우주선 쪽을 지나갈 때까지). 0이 되면 끝.
## 이 동안 조준선은 사라지고, 화면 가장자리 "!" 표시만 남는다.
var linger := 0.0
## 첫 탄을 쏜 뒤 지난 시간 (쏘기 전에는 -1). 조준선이 사라지는 연출에 쓴다.
var since_fire := -1.0


func _init(from: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.RIGHT) -> void:
	origin = from
	dir = direction.normalized()


## 시간을 진행하고, 이번 프레임에 일어난 일을 돌려준다: {"charge": 충전 시작했는지, "fired": 쏜 탄 수}
func step(delta: float) -> Dictionary:
	var result := {"charge": false, "fired": 0}
	if since_fire >= 0.0:
		since_fire += delta
	timer -= delta
	while timer <= 0.0 and phase != Phase.DONE:
		match phase:
			Phase.WARN:
				phase = Phase.CHARGE
				timer += Balance.BARRAGE_CHARGE_TIME
				result["charge"] = true
			Phase.CHARGE:
				phase = Phase.FIRE
				since_fire = -timer  # 첫 탄은 충전이 끝나는 순간 바로 (이번 프레임에 넘친 시간만큼 지남)
			Phase.FIRE:
				result["fired"] += 1
				shots_left -= 1
				if shots_left <= 0:
					phase = Phase.DONE
				else:
					timer += Balance.BARRAGE_SHOT_GAP
	return result


## 다 쏜 뒤 남겨 둔 시간이 끝났는지 (RunSim이 목록에서 뺄 때)
func finished() -> bool:
	return phase == Phase.DONE and linger <= 0.0


## 조준선이 그어진 비율 0~1: 예고 시작 뒤 BARRAGE_DRAW_RATIO 동안 쏘는 곳에서부터 쭉 뻗는다.
func draw_progress() -> float:
	if phase != Phase.WARN:
		return 1.0
	return clampf(warn_progress() / Balance.BARRAGE_DRAW_RATIO, 0.0, 1.0)


## 조준선이 보이는 정도 0~1: 쏘기 전에는 1, 첫 탄을 쏜 뒤 BARRAGE_LINE_FADE_TIME 동안 0으로 사라진다.
## (쏘는 순간 탄이 지나갈 길을 잠깐 비춰 주고 사라짐)
func line_visibility() -> float:
	if since_fire < 0.0:
		return 1.0
	return 1.0 - clampf(since_fire / Balance.BARRAGE_LINE_FADE_TIME, 0.0, 1.0)


## 예고·충전 중인지 (조준선을 보여 줄 때)
func is_telegraphing() -> bool:
	return phase == Phase.WARN or phase == Phase.CHARGE


## 예고 단계 진행도 0~1 (그리기용: 충전 중에는 1)
func warn_progress() -> float:
	if phase == Phase.WARN:
		return 1.0 - clampf(timer / Balance.BARRAGE_WARN_TIME, 0.0, 1.0)
	return 1.0


## 충전 진행도 0~1 (그리기용)
func charge_progress() -> float:
	if phase == Phase.CHARGE:
		return 1.0 - clampf(timer / Balance.BARRAGE_CHARGE_TIME, 0.0, 1.0)
	return 1.0 if phase == Phase.FIRE or phase == Phase.DONE else 0.0


## 점 p가 조준선(쏘는 곳 앞쪽으로 뻗은 반직선)에서 떨어진 거리. 쏘는 곳 뒤쪽이면 INF.
static func distance_from_line(from: Vector2, direction: Vector2, p: Vector2) -> float:
	var along := (p - from).dot(direction)
	if along < 0.0:
		return INF
	return (p - (from + direction * along)).length()


## 조준: 예고를 시작할 때 우주선이 lead초 뒤에 있을 곳을 향한 방향
static func aim_direction(from: Vector2, ship_pos: Vector2, ship_vel: Vector2, lead: float) -> Vector2:
	var target := ship_pos + ship_vel * lead
	if target.is_equal_approx(from):
		return Vector2.RIGHT
	return (target - from).normalized()
