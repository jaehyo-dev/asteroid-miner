class_name CardFx
extends Control
## 레벨업 카드 등장 효과: 빛줄기, 파티클, 빛 기둥, 고리. 등급이 높을수록 커진다.
## 이 노드는 카드 뒤(빛 기둥·빛줄기)를, front는 카드 앞(파티클·고리)을 그린다. 수치는 Juice.
## 모두 코드 효과이고 정수 픽셀 사각형·1픽셀 선으로만 그려 뒤 화면과 격자가 같다.

const RAINBOW: Array[Color] = [Color("#f25c76"), Color("#f89419"), Color("#f6ce50"), Color("#a5cc5f"), Color("#30e1b9"), Color("#99e9e6"), Color("#a884f3")]
const GRADE_COLORS: Array[Color] = [Color("#a5b29d"), Color("#30e1b9"), Color("#a884f3"), Color("#f6ce50")]

## 카드 앞에 그리는 층 (LevelUpCards가 카드들 위에 놓는다)
var front := Control.new()
## 파티클: [위치, 속도, 남은 시간, 전체 시간, 색, 크기]
var parts: Array = []
var rays: Array[Dictionary] = []
var pillars: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front)
	_rng.randomize()


static func grade_color(grade: int, rng: RandomNumberGenerator) -> Color:
	return RAINBOW[rng.randi_range(0, RAINBOW.size() - 1)] if grade == Upgrades.LEGENDARY else GRADE_COLORS[grade]


func clear() -> void:
	parts.clear()
	rays.clear()
	pillars.clear()
	rings.clear()
	_redraw()


## 카드 앞면이 나오는 순간의 폭발. strength: 건너뛸 때처럼 짧게 보여 줄 때 줄이는 배율.
func burst(rect: Rect2, grade: int, strength := 1.0) -> void:
	var center := rect.get_center().round()
	var scale_by := rect.size.x / float(LevelCard.CARD_W_SMALL)
	var life: float = Juice.CARD_BURST_TIME[grade] * lerpf(0.6, 1.0, strength)
	for i in int(Juice.CARD_BURST_PARTS[grade] * strength):
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		var from := center + dir * Vector2(rect.size.x * 0.35, rect.size.y * 0.35)
		var speed: float = Juice.CARD_BURST_SPEED[grade] * scale_by * _rng.randf_range(0.4, 1.0)
		_spawn(from, dir * speed, life * _rng.randf_range(0.6, 1.0), grade_color(grade, _rng), 2.0 if i % 4 == 0 else 1.0)
	var ray_count: int = int(Juice.CARD_BURST_RAYS[grade] * strength)
	for i in ray_count:
		rays.append({"pos": center, "angle": TAU * i / ray_count + _rng.randf_range(-0.12, 0.12),
			"len": Juice.CARD_BURST_RAY_LEN[grade] * scale_by * _rng.randf_range(0.7, 1.1), "t": 0.0, "life": life * 0.7, "color": grade_color(grade, _rng)})
	if grade >= Upgrades.UNIQUE:
		pillars.append({"rect": rect, "t": 0.0, "life": Juice.CARD_PILLAR_TIME * lerpf(0.6, 1.0, strength), "grade": grade})
		for i in (3 if grade == Upgrades.LEGENDARY else 1):
			rings.append({"pos": center, "t": -0.06 * i, "life": life, "radius": rect.size.y * (0.7 + 0.25 * i), "grade": grade})
	_redraw()


## 레전드리: 앞면이 나오기 전에 카드 둘레에서 빛 알갱이가 가운데로 모인다.
func gather(rect: Rect2, time: float) -> void:
	var center := rect.get_center()
	for i in Juice.CARD_GATHER_PARTS:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		var dist := rect.size.y * _rng.randf_range(0.55, 0.95)
		_spawn(center + dir * dist, -dir * dist / time, time, grade_color(Upgrades.LEGENDARY, _rng), 1.0)
	_redraw()


func _spawn(pos: Vector2, vel: Vector2, life: float, color: Color, size_px: float) -> void:
	if parts.size() < Juice.CARD_FX_MAX:
		parts.append([pos, vel, life, life, color, size_px])


func busy() -> bool:
	return not (parts.is_empty() and rays.is_empty() and pillars.is_empty() and rings.is_empty())


func _process(delta: float) -> void:
	if not busy():
		return
	var kept: Array = []
	for p in parts:
		p[0] += p[1] * delta
		p[2] -= delta
		if p[2] > 0.0:
			kept.append(p)
	parts = kept
	rays = _aged(rays, delta)
	pillars = _aged(pillars, delta)
	rings = _aged(rings, delta)
	_redraw()


func _aged(list: Array[Dictionary], delta: float) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for e in list:
		e["t"] += delta
		if e["t"] < e["life"]:
			kept.append(e)
	return kept


func _redraw() -> void:
	queue_redraw()
	front.queue_redraw()


## 카드 뒤: 빛 기둥(화면 위아래로 뻗고 폭이 줄어듦, 계단 3겹) + 뻗어 나갔다 사라지는 빛줄기
func _draw() -> void:
	for p in pillars:
		var k: float = p["t"] / p["life"]
		var rect: Rect2 = p["rect"]
		var color: Color = GRADE_COLORS[Upgrades.UNIQUE] if p["grade"] == Upgrades.UNIQUE else RAINBOW[int(p["t"] * 24.0) % RAINBOW.size()]
		for band in 3:
			var half := roundi(rect.size.x * 0.5 * (1.0 - k) * (1.0 - band * 0.3))
			if half > 0:
				draw_rect(Rect2(rect.get_center().x - half, 0, half * 2, size.y).abs(), Color(color, 0.14 * (1.0 - k) + 0.05 * band))
	for r in rays:
		var k: float = r["t"] / r["life"]
		var dir := Vector2.from_angle(r["angle"])
		var from: Vector2 = r["pos"] + dir * (r["len"] as float) * k * 0.5
		var to: Vector2 = r["pos"] + dir * (r["len"] as float) * minf(k * 2.0, 1.0)
		draw_line(from.round(), to.round(), Color(r["color"], 0.8 * (1.0 - k)), 1.0)


## 카드 앞: 고리 + 파티클
func _draw_front() -> void:
	for r in rings:
		if r["t"] < 0.0:
			continue
		var k: float = r["t"] / r["life"]
		var color: Color = GRADE_COLORS[Upgrades.UNIQUE] if r["grade"] == Upgrades.UNIQUE else RAINBOW[int(k * 14.0) % RAINBOW.size()]
		front.draw_arc(r["pos"], maxf(r["radius"] * (1.0 - (1.0 - k) * (1.0 - k)), 1.0), 0.0, TAU, 48, Color(color, 0.9 * (1.0 - k)), 1.0)
	for p in parts:
		var c: Color = p[4]
		c.a = clampf(p[2] / p[3] * 1.6, 0.0, 1.0)
		front.draw_rect(Rect2((p[0] as Vector2).round(), Vector2.ONE * p[5]), c)
