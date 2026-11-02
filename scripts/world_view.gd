class_name WorldView
extends Node2D
## 출격 화면의 월드(우주선, 운석, 광물, 탄, 파편)를 그린다. 상태는 RunSim에서 읽기만 한다.

## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08
## 운석이 부서질 때 파편 수와 지속 시간, 속도
const DEBRIS_COUNT := 6
const DEBRIS_TIME := 0.35
const DEBRIS_SPEED := 50.0

var sim: RunSim
## 이번 프레임에 움직이는 중인지 (엔진 불꽃 표시용)
var moving := false

## 파편 효과: [위치, 속도, 남은 시간]
var _debris: Array = []
var _rng := RandomNumberGenerator.new()


## 매 프레임 효과를 갱신한다 (RunSim.update 다음에 부름).
func step(delta: float) -> void:
	if sim == null:
		return
	for a in sim.destroyed:
		for i in DEBRIS_COUNT + int(a.radius / 3.0):
			var vel := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.4, 1.0) * DEBRIS_SPEED
			_debris.append([a.pos, vel, DEBRIS_TIME])
	var kept: Array = []
	for d in _debris:
		d[0] += d[1] * delta
		d[2] -= delta
		if d[2] > 0.0:
			kept.append(d)
	_debris = kept


func _draw() -> void:
	if sim == null:
		return
	for a in sim.asteroids:
		var tex := PixelArt.asteroid_flash(a.radius, a.variant) if a.flash > 0.0 else PixelArt.asteroid(a.radius, a.variant)
		draw_texture(tex, (a.pos - tex.get_size() / 2.0).round())
	for m in sim.minerals:
		var tex := PixelArt.mineral(m.grade)
		draw_texture(tex, (m.pos - tex.get_size() / 2.0).round())
		# 희귀 이상은 반짝임 한 점
		if m.grade > 0 and int(sim.time * 4.0 + m.pos.x) % 4 == 0:
			draw_rect(Rect2((m.pos + Vector2(2, -3)).round(), Vector2.ONE), Color.WHITE)
	for d in _debris:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE), PixelArt.DEBRIS_COLOR)
	for b in sim.bullets:
		var p := b.pos.round()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), PixelArt.BULLET_COLORS[1])
		draw_rect(Rect2(p, Vector2.ONE), PixelArt.BULLET_COLORS[0])
	if sim.alive:
		_draw_ship()


func _draw_ship() -> void:
	# 무적 중에는 깜빡인다.
	if sim.invuln > 0.0 and int(sim.invuln / BLINK_INTERVAL) % 2 == 1:
		return
	var tex := PixelArt.ship()
	# 그림은 위쪽을 바라보므로 바라보는 방향(facing)에서 90도를 더해 돌린다.
	draw_set_transform(sim.player_pos.round(), sim.facing + PI / 2.0)
	var top_left := -(tex.get_size() / 2.0).floor()
	if moving:
		# 엔진 불꽃: 뒤쪽 두 엔진에서 깜빡이는 픽셀
		var flicker := int(sim.time * 20.0) % 2
		for x in [2, 6]:
			draw_rect(Rect2(top_left + Vector2(x, 7), Vector2(1, 1 + flicker)), PixelArt.FLAME_COLORS[flicker])
	draw_texture(tex, top_left)
	draw_set_transform(Vector2.ZERO)
