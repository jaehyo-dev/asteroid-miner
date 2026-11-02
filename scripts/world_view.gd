class_name WorldView
extends Node2D
## 출격 화면의 월드(우주선, 운석, 광물, 탄, 파편, 줍기 연출)를 그린다. 상태는 RunSim에서 읽기만 한다.

## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08
## 운석이 부서질 때 파편 수와 지속 시간, 속도
const DEBRIS_COUNT := 6
const DEBRIS_TIME := 0.35
const DEBRIS_SPEED := 50.0
## 황금 운석이 부서질 때 금빛 파편을 더 많이
const GOLDEN_DEBRIS_COUNT := 24
## 등급별 줍기 연출 시간 (일반, 희귀, 영웅, 전설)
const PICKUP_FX_TIME := [0.2, 0.35, 0.45, 0.7]
## 줍기 연출에서 퍼지는 고리의 최대 반지름
const PICKUP_RING_RADIUS := [0.0, 10.0, 14.0, 24.0]
## "+가치" 숫자가 떠오르는 시간과 높이
const POPUP_TIME := 0.8
const POPUP_RISE := 14.0
const FONT := preload("res://assets/fonts/galmuri/Galmuri11.ttf")

var sim: RunSim
## 이번 프레임에 움직이는 중인지 (엔진 불꽃 표시용)
var moving := false

## 파편 효과: [위치, 속도, 남은 시간, 색]
var _debris: Array = []
## 줍기 연출: {pos, grade, t(지난 시간)}
var _pickups: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## 매 프레임 효과를 갱신한다 (RunSim.update 다음에 부름).
func step(delta: float) -> void:
	if sim == null:
		return
	for a in sim.destroyed:
		var count := GOLDEN_DEBRIS_COUNT if a.golden else DEBRIS_COUNT + int(a.radius / 3.0)
		var color: Color = PixelArt.GOLD_ROCK_COLORS[1] if a.golden else PixelArt.DEBRIS_COLOR
		for i in count:
			var vel := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.4, 1.0) * DEBRIS_SPEED
			_debris.append([a.pos, vel, DEBRIS_TIME * (1.6 if a.golden else 1.0), color])
	for p in sim.picked:
		_pickups.append({"pos": p["pos"], "grade": p["grade"], "t": 0.0})
	var kept: Array = []
	for d in _debris:
		d[0] += d[1] * delta
		d[2] -= delta
		if d[2] > 0.0:
			kept.append(d)
	_debris = kept
	var kept_fx: Array[Dictionary] = []
	for fx in _pickups:
		fx["t"] += delta
		if fx["t"] < maxf(PICKUP_FX_TIME[fx["grade"]], POPUP_TIME):
			kept_fx.append(fx)
	_pickups = kept_fx


func _draw() -> void:
	if sim == null:
		return
	for a in sim.asteroids:
		if a.golden:
			_draw_golden_glow(a)
		var tex := PixelArt.asteroid_flash(a.radius, a.variant, a.golden) if a.flash > 0.0 else PixelArt.asteroid(a.radius, a.variant, a.golden)
		draw_texture(tex, (a.pos - tex.get_size() / 2.0).round())
		if a.golden:
			_draw_sparkles(a.pos, a.radius, 3, 0.0)
	for m in sim.minerals:
		_draw_mineral(m)
	for d in _debris:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE), d[3])
	for b in sim.bullets:
		var p := b.pos.round()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), PixelArt.BULLET_COLORS[1])
		draw_rect(Rect2(p, Vector2.ONE), PixelArt.BULLET_COLORS[0])
	for fx in _pickups:
		_draw_pickup_fx(fx)
	if sim.alive:
		_draw_ship()


## 황금 운석 둘레에서 숨 쉬듯 커졌다 작아지는 금빛 후광 (멀리서도 눈에 띄게)
func _draw_golden_glow(a: RunSim.Asteroid) -> void:
	var pulse := 0.5 + 0.5 * sin(sim.time * 4.0)
	draw_circle(a.pos.round(), a.radius + 4.0 + pulse * 3.0, Color(1.0, 0.85, 0.3, 0.12 + 0.08 * pulse))
	draw_arc(a.pos.round(), a.radius + 3.0 + pulse * 4.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.35 * (1.0 - pulse) + 0.15), 1.0)


## 대상 둘레에서 깜빡이는 흰 반짝임 점들 (위치는 시간에 따라 바뀜)
func _draw_sparkles(center: Vector2, radius: float, count: int, seed_offset: float) -> void:
	for i in count:
		var phase := sim.time * 3.0 + i * 2.1 + seed_offset
		if fposmod(phase, 1.0) > 0.55:
			continue  # 반짝였다 꺼졌다
		var angle := floorf(phase) * 2.4 + i * 1.7
		var p := center + Vector2.from_angle(angle) * radius * (0.4 + 0.5 * fposmod(angle, 1.0))
		draw_rect(Rect2(p.round(), Vector2.ONE), Color.WHITE)
		if i == 0:
			# 십자 모양 반짝임
			draw_rect(Rect2(p.round() + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 1, 0.6))
			draw_rect(Rect2(p.round() + Vector2(0, -1), Vector2(1, 3)), Color(1, 1, 1, 0.6))


## 등급별 광물: 희귀는 은은한 빛, 영웅은 반짝임, 전설은 빛줄기와 회전
func _draw_mineral(m: RunSim.Mineral) -> void:
	var tex := PixelArt.mineral(m.grade)
	var center := m.pos.round()
	var color: Color = PixelArt.MINERAL_COLORS[m.grade][1]
	var bob := sin(sim.time * 3.0 + m.pos.x * 0.1)  # 둥실거림 (-1~1)
	match m.grade:
		1:
			draw_circle(center, 5.0 + bob, Color(color, 0.12))
		2:
			draw_circle(center, 6.0 + bob, Color(color, 0.15))
		3:
			# 빛줄기 4개가 천천히 돈다
			var spin := sim.time * 1.2
			for i in 4:
				var dir := Vector2.from_angle(spin + i * TAU / 4.0)
				draw_line(center + dir * 5.0, center + dir * (11.0 + 2.0 * bob), Color(1.0, 0.9, 0.4, 0.45), 1.0)
			draw_circle(center, 8.0 + bob, Color(color, 0.18))
	if m.grade == 3:
		# 금괴는 천천히 기울며 돈다
		draw_set_transform(center, sin(sim.time * 1.5) * 0.5)
		draw_texture(tex, -(tex.get_size() / 2.0).floor())
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture(tex, center - (tex.get_size() / 2.0).floor() + Vector2(0, roundf(bob * 0.6)))
	if m.grade >= 2:
		_draw_sparkles(m.pos, 6.0, 2 if m.grade == 2 else 3, m.pos.x)


## 줍기 연출: 등급이 높을수록 크고 화려하게. 희귀 이상은 "+가치" 숫자가 떠오른다.
func _draw_pickup_fx(fx: Dictionary) -> void:
	var grade: int = fx["grade"]
	var t: float = fx["t"]
	var pos: Vector2 = (fx["pos"] as Vector2).round()
	var color: Color = PixelArt.MINERAL_COLORS[grade][1]
	var k: float = t / PICKUP_FX_TIME[grade]
	if k < 1.0:
		var alpha: float = 1.0 - k
		if grade == 0:
			# 작은 부스러기 4개가 튄다
			for i in 4:
				var dir := Vector2.from_angle(i * TAU / 4.0 + 0.6)
				draw_rect(Rect2((pos + dir * 6.0 * k).round(), Vector2.ONE), Color(color, alpha))
		else:
			draw_arc(pos, 2.0 + PICKUP_RING_RADIUS[grade] * k, 0.0, TAU, 20, Color(color, alpha), 1.0)
		if grade >= 2:
			var rays := 6 if grade == 2 else 10
			for i in rays:
				var dir := Vector2.from_angle(i * TAU / rays)
				draw_rect(Rect2((pos + dir * PICKUP_RING_RADIUS[grade] * k * 0.8).round(), Vector2.ONE), Color(1, 1, 1, alpha))
		if grade == 3:
			draw_circle(pos, 10.0 * (1.0 - k), Color(1.0, 0.95, 0.6, 0.5 * alpha))
	if grade >= 1 and t < POPUP_TIME:
		var value := int(Balance.MINERAL_GRADES[grade]["value"])
		var rise := POPUP_RISE * t / POPUP_TIME
		var text_color := Color(PixelArt.MINERAL_COLORS[grade][0], 1.0 - t / POPUP_TIME)
		draw_string(FONT, (pos + Vector2(-12, -6 - rise)).round(), "+%d" % value, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, text_color)


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
