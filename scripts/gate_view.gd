class_name GateView
extends Node2D
## 워프 게이트 그리기: 광부 조합이 설치한 기계식 고리(Codex 그림 조각 8개, 깜빡이는 표시등), 안쪽 소용돌이(셰이더),
## 안으로 빨려 드는 빛 알갱이(입자), 둘레 원형 게이지, 충전 빛줄기, 등장·닫힘·붕괴 연출.
## 상태는 RunSim(게임 규칙)과 GateFx(연출 시간)에서 읽기만 한다. 월드보다 먼저 그려 적·우주선 아래에 깔린다.

const VORTEX_SHADER := preload("res://scripts/gate_vortex.gdshader")
## 소용돌이 지름 (픽셀) = 고리 안쪽 지름
const VORTEX_SIZE := 44
## 원형 게이지: 반지름, 칸 수, 색 (남은 시간, 충전, 닫히기 직전, 꺼진 칸)
const GAUGE_RADIUS := 37.0
const GAUGE_DASHES := 32
const GAUGE_COLOR := Color("#3ff0d8")
const GAUGE_CHARGE := Color("#d8fff8")
const GAUGE_HOT := Color("#ff4a4a")
const GAUGE_OFF := Color(0.1, 0.22, 0.28, 0.7)
## 표시등 색: 안쪽 띠(청록), 바깥 등(주황), 닫히기 직전(빨강), 꺼짐 (void32 색)
const LIGHT_TEAL := Color("#99e9e6")
const LIGHT_ORANGE := Color("#f6ce50")
const LIGHT_RED := Color("#f25c76")
const LIGHT_OFF := Color("#3c3544")
## 조각이 모이기 전 흩어져 있는 거리, 닫힐 때 흩어지는 거리 (픽셀)
const ASSEMBLE_SPREAD := 40.0
const SCATTER_SPREAD := 34.0
## 닫히기 직전 떨어져 나가는 파편 간격(초)과 수명
const CHIP_INTERVAL := 0.12
const CHIP_LIFE := 0.8
## 빨려 드는 빛 알갱이: 생기는 반지름, 수
const PARTICLE_RADIUS := 46.0
const PARTICLE_AMOUNT := 28

var sim: RunSim
var fx := GateFx.new()
var vortex: ColorRect
var particles: CPUParticles2D
## 소용돌이·입자 위에 그리는 층 (게이지, 빛줄기, 섬광)
var front: Node2D
## 떨어져 나가는 파편 [{pos, vel, t}]
var _chips: Array[Dictionary] = []
var _chip_timer := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i in PixelArt.GATE_SEGMENTS:
		PixelArt.gate_segment(i)  # 판 시작 때 미리 만들어 게이트가 처음 열릴 때 끊기지 않게
	vortex = ColorRect.new()
	vortex.size = Vector2(VORTEX_SIZE, VORTEX_SIZE)
	vortex.position = -vortex.size / 2.0
	vortex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VORTEX_SHADER
	mat.set_shader_parameter("grid", float(VORTEX_SIZE))
	vortex.material = mat
	add_child(vortex)
	particles = _make_particles()
	add_child(particles)
	front = Node2D.new()
	front.draw.connect(_draw_front)
	add_child(front)
	visible = false


## 안쪽으로 빨려 드는 빛 알갱이: 고리 바깥 원 위에서 생겨 가운데로 끌려가며 돈다
func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = PARTICLE_AMOUNT
	p.lifetime = 0.9
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = PARTICLE_RADIUS
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	# 0.9초 만에 46픽셀을 끌려가도록 (거리 = 가속도 × 시간² / 2)
	p.radial_accel_min = -115.0
	p.radial_accel_max = -105.0
	p.orbit_velocity_min = 0.08
	p.orbit_velocity_max = 0.16
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(LIGHT_TEAL, 0.0))
	ramp.set_color(1, Color(0.8, 0.5, 1.0, 0.0))
	ramp.add_point(0.25, Color(LIGHT_TEAL, 1.0))
	ramp.add_point(0.8, Color(0.8, 0.5, 1.0, 0.9))
	p.color_ramp = ramp
	p.emitting = false
	return p


## 매 프레임 연출을 진행한다 (RunSim.update 다음에 sim.events를 넘겨 부름. 게임이 멈춘 뒤 귀환 연출 중에는 빈 목록).
## 연출 이벤트("gate_locked", "gate_closing")를 돌려준다.
func step(delta: float, events: PackedStringArray) -> PackedStringArray:
	if sim == null:
		return []
	_time += delta
	var g := sim.gate
	var out := fx.step(delta, g, events)
	var shown := g.state == WarpGate.State.OPEN or fx.collapse >= 0.0
	visible = shown
	if not shown:
		particles.emitting = false
		_chips.clear()
		return out
	position = g.pos.round()
	var heat := GateFx.heat(g)
	var mat := vortex.material as ShaderMaterial
	mat.set_shader_parameter("spin", fx.spin)
	mat.set_shader_parameter("heat", heat if fx.collapse < 0.0 else 1.0)
	mat.set_shader_parameter("open", fx.vortex_open())
	mat.set_shader_parameter("glow", g.charge_progress())
	particles.emitting = fx.vortex_open() > 0.5 and fx.collapse < 0.0 and not sim.returned
	particles.speed_scale = 1.0 + 2.0 * g.charge_progress()
	particles.modulate = Color.WHITE.lerp(Color(1.0, 0.4, 0.4), heat)
	_update_chips(delta, heat, events.has("gate_close"))
	queue_redraw()
	front.queue_redraw()
	return out


## 닫히기 직전에는 고리에서 작은 파편이 떨어져 나가고, 닫힐 때는 한꺼번에 흩어진다
func _update_chips(delta: float, heat: float, closed_now: bool) -> void:
	if closed_now:
		for i in 16:
			_spawn_chip(1.6)
	elif heat > 0.3:
		_chip_timer -= delta
		if _chip_timer <= 0.0:
			_chip_timer = CHIP_INTERVAL / heat
			_spawn_chip(1.0)
	var kept: Array[Dictionary] = []
	for c in _chips:
		c["t"] += delta
		c["pos"] += c["vel"] * delta
		if c["t"] < CHIP_LIFE:
			kept.append(c)
	_chips = kept


func _spawn_chip(speed: float) -> void:
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	var r := _rng.randf_range(PixelArt.GATE_RING_IN, PixelArt.GATE_CLAMP_OUT)
	_chips.append({"pos": dir * r, "vel": dir.rotated(_rng.randf_range(-0.4, 0.4)) * _rng.randf_range(15.0, 35.0) * speed, "t": 0.0})


## 고리 조각과 표시등, 파편 (소용돌이 아래층)
func _draw() -> void:
	if sim == null:
		return
	var g := sim.gate
	var heat := GateFx.heat(g)
	var built := fx.assembled()
	var scatter := fx.scatter()
	var step_angle := TAU / PixelArt.GATE_SEGMENTS
	var tint := Color.WHITE.lerp(Color(1.0, 0.55, 0.55), heat * 0.6)
	for i in PixelArt.GATE_SEGMENTS:
		var tex := PixelArt.gate_segment(i)
		var dir := Vector2.from_angle(i * step_angle)
		var offset := dir * ASSEMBLE_SPREAD * (1.0 - built)
		var alpha := clampf(built * 2.0, 0.0, 1.0)
		if scatter >= 0.0:
			offset = dir * SCATTER_SPREAD * scatter + dir.orthogonal() * 6.0 * scatter * (1.0 if i % 2 == 0 else -1.0)
			alpha = 1.0 - scatter
		elif heat > 0.0:
			offset += shake_offset(i, _time, heat)  # 닫히기 직전 조각마다 따로 떨린다
		draw_texture(tex, (offset - tex.get_size() / 2.0).round(), Color(tint, alpha))
	if scatter < 0.0:
		_draw_lights(g, heat, built)
	for c in _chips:
		var a: float = 1.0 - c["t"] / CHIP_LIFE
		var pos: Vector2 = (c["pos"] as Vector2).round()
		draw_rect(Rect2(pos, Vector2(2, 2)), Color(PixelArt.GATE_METAL[1], a))
		draw_rect(Rect2(pos, Vector2.ONE), Color(PixelArt.GATE_METAL[0], a))


## 표시등: 평소 청록이 차례로 도는 불빛(충전하면 빨라짐), 주황은 천천히 깜빡임, 닫히기 직전엔 모두 빨갛게 빠르게 깜빡임
func _draw_lights(g: WarpGate, heat: float, built: float) -> void:
	var chase_speed := 6.0 + 18.0 * g.charge_progress()
	var chase := int(_time * chase_speed) % PixelArt.GATE_SEGMENTS
	var lights := PixelArt.gate_lights()
	for light in lights:
		var seg: int = light["segment"]
		var color := LIGHT_OFF
		if built >= 1.0:
			if heat > 0.0:
				color = LIGHT_RED if int(_time * 8.0) % 2 == 0 else LIGHT_OFF
			elif light["clamp"]:
				color = LIGHT_ORANGE if int(_time * 2.0 + seg) % 3 != 0 else LIGHT_ORANGE.darkened(0.5)
			else:
				color = LIGHT_TEAL if seg == chase else LIGHT_TEAL.darkened(0.45)
		var p: Vector2 = (light["pos"] as Vector2).round()
		if heat > 0.0:
			p += shake_offset(seg, _time, heat)
		if color != LIGHT_OFF:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(color, 0.25))
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), color)


## 소용돌이·입자 위: 원형 게이지, 충전 빛줄기, 맞물릴 때 섬광
func _draw_front() -> void:
	if sim == null:
		return
	var g := sim.gate
	var heat := GateFx.heat(g)
	if fx.assembled() >= 1.0 and fx.collapse < 0.0:
		var lit := ceili(GateFx.gauge(g) * GAUGE_DASHES)
		var on := GAUGE_CHARGE if g.charge >= 0.0 else GAUGE_COLOR.lerp(GAUGE_HOT, heat)
		for i in GAUGE_DASHES:
			# 위쪽에서 시계 방향으로 채운다
			var p := (Vector2.from_angle(-PI / 2.0 + TAU * (i + 0.5) / GAUGE_DASHES) * GAUGE_RADIUS).round()
			front.draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), on if i < lit else GAUGE_OFF)
	if g.charge >= 0.0 and not sim.returned:
		_draw_beam(sim.player_pos - g.pos.round())
	var flash := fx.lock_flash()
	if flash > 0.0:
		# 사방으로 튀는 불꽃 + 가운데 반짝이는 별 (가로세로 긴 빛, 대각선 짧은 빛)
		var radius := lerpf(6.0, GAUGE_RADIUS + 6.0, 1.0 - flash)
		for i in 12:
			var spark := (Vector2.from_angle(i * TAU / 12.0 + 0.26) * radius).round()
			front.draw_rect(Rect2(spark, Vector2(2, 2) if i % 2 == 0 else Vector2.ONE), Color(GAUGE_CHARGE, flash))
		front.draw_circle(Vector2.ZERO, 2.0 + 3.0 * flash, Color(1, 1, 1, flash))
		var arm := 6.0 + 14.0 * flash
		for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			front.draw_line(Vector2.ZERO, dir * arm, Color(1, 1, 1, flash), 1.0)
		for dir in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			front.draw_line(Vector2.ZERO, dir * arm * 0.35, Color(GAUGE_CHARGE, flash), 1.0)


## 충전 중 우주선과 게이트 가운데를 잇는 빛줄기: 깜빡이는 굵은 빛 + 가운데로 흘러가는 빛 점
func _draw_beam(ship: Vector2) -> void:
	var k := sim.gate.charge_progress()
	var pulse := 0.75 + 0.25 * sin(_time * 30.0)
	front.draw_line(ship, Vector2.ZERO, Color(GAUGE_COLOR, 0.25 * pulse), 4.0 + 2.0 * k)
	front.draw_line(ship, Vector2.ZERO, Color(GAUGE_CHARGE, 0.85 * pulse), 1.0)
	for i in 4:
		var f := fposmod(_time * (1.5 + 2.0 * k) + i / 4.0, 1.0)
		front.draw_rect(Rect2(ship.lerp(Vector2.ZERO, f).round() - Vector2.ONE, Vector2(2, 2)), GAUGE_CHARGE)


## 떨림: 조각마다 다른 방향으로 1~2픽셀, 초당 20번 바뀐다 (같은 시각이면 같은 값)
static func shake_offset(index: int, time: float, heat: float) -> Vector2:
	var amount := roundf(heat * 2.0)
	if amount <= 0.0:
		return Vector2.ZERO
	var tick := int(time * 20.0)
	var h := absi(hash(index * 7919 + tick))
	return Vector2(float(h % 3) - 1.0, float((h / 3) % 3) - 1.0) * amount
