class_name WorldView
extends Node2D
## 출격 화면의 월드(우주선, 운석)를 그린다. 상태는 RunSim에서 읽기만 한다.

## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08

var sim: RunSim
## 이번 프레임에 움직이는 중인지 (엔진 불꽃 표시용)
var moving := false


func _draw() -> void:
	if sim == null:
		return
	for a in sim.asteroids:
		var tex := PixelArt.asteroid(a.radius, a.variant)
		draw_texture(tex, (a.pos - tex.get_size() / 2.0).round())
	if sim.alive:
		_draw_ship()


func _draw_ship() -> void:
	# 무적 중에는 깜빡인다.
	if sim.invuln > 0.0 and int(sim.invuln / BLINK_INTERVAL) % 2 == 1:
		return
	var tex := PixelArt.ship()
	var top_left := (sim.player_pos - tex.get_size() / 2.0).round()
	if moving:
		# 엔진 불꽃: 아래쪽 두 엔진에서 깜빡이는 2픽셀
		var flicker := int(sim.time * 20.0) % 2
		for x in [2, 6]:
			draw_rect(Rect2(top_left + Vector2(x, 7), Vector2(1, 1 + flicker)), PixelArt.FLAME_COLORS[flicker])
	draw_texture(tex, top_left)
