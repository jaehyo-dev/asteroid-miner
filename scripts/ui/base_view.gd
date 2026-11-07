class_name BaseView
extends Control
## 기지 풍경: 소행성 표면, 착륙장의 우주선과 조종사, 건물 5채, 이름표, 작은 드론, 가끔 지나가는 운석.
## 모두 코드로 그리는 픽셀 아트다 (콘셉트 그림: assets/raw/base_concept_*.png).
## 누르기는 main.gd가 BaseLayout.touch_rect 자리에 놓은 버튼이 맡고, 여기서는 그리기만 한다.

## 이륙 연출 시간: 앞부분은 조종사가 우주선에 오르고, 나머지는 우주선이 솟아오른다
const LAUNCH_TIME := 1.0
const BOARD_TIME := 0.3

const METAL_L := Color("#a3a9bd")
const METAL := Color("#6f748a")
const METAL_D := Color("#4a4e63")
const DARK := Color("#202234")
const HAZARD := [Color("#f2b630"), Color("#2b2b38")]
const CYAN := Color("#4fd1ff")
const ORANGE := Color("#ff9a2e")
const GLASS := Color("#2f5fb0")
const GLASS_L := Color("#7fd4ff")
const RUST := Color("#9a4a32")
const YELLOW := Color("#f2c230")
const GROUND := Color("#4a3d38")
const GROUND_L := Color("#5e4e46")
const GROUND_D := Color("#33292a")
const LABEL_BG := Color(0.03, 0.03, 0.08, 0.75)
const LABEL_TEXT := Color("#e8ecf6")
const GLOW := Color("#7cf0ff")

## 진행 상황 (연구 단계·보유 광물로 기지 모습이 바뀜)
var levels: Dictionary = {}
var credits := 0
## 지난 시간 (깜빡임·움직임)
var time := 0.0
## 이륙 연출 진행 시간 (-1이면 이륙 전)
var launch_t := -1.0
## 지금 배치 (BaseLayout.rects)
var rects: Dictionary = {}
## 땅의 구덩이·돌 (화면 크기가 바뀔 때만 다시 만든다): [위치, 크기, 종류]
var _ground: Array = []
var _horizon: PackedVector2Array = []
## 지나가는 운석: [위치, 속도]
var _meteors: Array = []
var _meteor_timer := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 2026
	resized.connect(relayout)
	relayout()


## 화면 크기에 맞게 건물 자리와 땅 모양을 다시 정한다.
func relayout() -> void:
	rects = BaseLayout.rects(size)
	var g := RandomNumberGenerator.new()
	g.seed = 7  # 같은 크기면 늘 같은 땅
	var top := horizon_y()
	_horizon = PackedVector2Array([Vector2(0, size.y)])
	var x := 0.0
	while x <= size.x + 8.0:
		_horizon.append(Vector2(x, top + g.randi_range(-3, 3)))
		x += 8.0
	_horizon.append(Vector2(size.x + 8.0, size.y))
	_ground.clear()
	for i in int(size.x * size.y / 2600.0):
		_ground.append([Vector2(g.randf_range(0, size.x), g.randf_range(top + 6, size.y)).round(), g.randi_range(2, 9), g.randi() % 3])


## 땅이 시작되는 높이 (위쪽은 별이 보이는 하늘)
func horizon_y() -> float:
	return roundf(size.y * (0.14 if BaseLayout.is_portrait(size) else 0.2))


## 이륙을 시작한다 (main.gd가 LAUNCH_TIME 뒤 출격 화면으로 넘어간다).
func start_launch() -> void:
	launch_t = 0.0


func _process(delta: float) -> void:
	time += delta
	if launch_t >= 0.0:
		launch_t += delta
	# 가끔 하늘을 가로지르는 운석
	_meteor_timer -= delta
	if _meteor_timer <= 0.0:
		_meteor_timer = BaseLife.next_meteor_gap(_rng)
		var from_left := _rng.randf() < 0.5
		var start := Vector2(-10.0 if from_left else size.x + 10.0, _rng.randf_range(4.0, horizon_y() * 0.8))
		_meteors.append([start, Vector2(1.0 if from_left else -1.0, 0.35) * _rng.randf_range(90.0, 140.0)])
	var kept: Array = []
	for m in _meteors:
		m[0] += m[1] * delta
		if m[0].x > -20.0 and m[0].x < size.x + 20.0:
			kept.append(m)
	_meteors = kept
	queue_redraw()


## 깜빡임: period초마다 on_ratio만큼 켜짐 (phase로 서로 엇갈리게)
func _blink(period: float, phase: float = 0.0, on_ratio: float = 0.5) -> bool:
	return fposmod(time / period + phase, 1.0) < on_ratio


func _draw() -> void:
	if rects.is_empty():
		return
	_draw_ground()
	_draw_sky()
	for id in BaseLayout.IDS:
		_draw_path(id)
	for id in BaseLayout.IDS:
		var r: Rect2 = rects[id]
		if launch_t < 0.0:
			_draw_glow(r)
		match id:
			"ship":
				_draw_pad(r.position)
			"research":
				_draw_research(r.position)
			"hangar":
				_draw_hangar(r.position)
			"storage":
				_draw_storage(r.position)
			"museum":
				_draw_museum(r.position)
			"drone":
				_draw_drone_factory(r.position)
	_draw_drone()
	for id in BaseLayout.IDS:
		_draw_label(id)


# ── 배경 ──────────────────────────────────────────

func _draw_ground() -> void:
	draw_colored_polygon(_horizon, GROUND)
	for g in _ground:
		var p: Vector2 = g[0]
		var s: int = g[1]
		match g[2]:
			0:  # 구덩이
				_ellipse(p, s * 1.6, s * 0.6, GROUND_D)
				_ellipse(p + Vector2(0, -1), s * 1.3, s * 0.4, Color(GROUND_D, 0.6))
			1:  # 돌
				draw_rect(Rect2(p, Vector2(s * 0.6, s * 0.4).ceil()), GROUND_L)
				draw_rect(Rect2(p + Vector2(0, roundf(s * 0.4)), Vector2(ceilf(s * 0.6), 1)), GROUND_D)
			_:  # 자갈
				draw_rect(Rect2(p, Vector2(2, 1)), GROUND_L)


func _draw_sky() -> void:
	# 멀리 떠 있는 소행성 (천천히 오르내림)
	var top := horizon_y()
	for i in 3:
		var pos := Vector2(size.x * (0.12 + i * 0.36), top * (0.35 + 0.2 * (i % 2)))
		pos.y += roundf(sin(time * 0.5 + i) * 2.0)
		var tex := PixelArt.asteroid(4.0 + i * 2.0, i)
		draw_texture(tex, (pos - tex.get_size() / 2.0).round(), Color(0.7, 0.7, 0.8))
	for m in _meteors:
		var p: Vector2 = m[0]
		var dir: Vector2 = m[1].normalized()
		for k in 6:
			draw_rect(Rect2((p - dir * k * 3.0).round(), Vector2(2, 2)), Color(1.0, 0.85, 0.5, 0.8 - k * 0.13))
		draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 3)), Color("#fff3c8"))


## 착륙장에서 건물로 이어진 길 (노란 점선)
func _draw_path(id: String) -> void:
	if id == "ship":
		return
	var a: Vector2 = (rects["ship"] as Rect2).get_center()
	var b: Vector2 = (rects[id] as Rect2).get_center() + Vector2(0, 22)
	var n := int(a.distance_to(b) / 6.0)
	for i in n:
		var p := a.lerp(b, float(i) / n).round()
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(5, 3)), METAL_D)
		if i % 2 == 0:
			draw_rect(Rect2(p, Vector2(1, 1)), YELLOW)


## 누를 수 있는 건물은 살짝 빛난다 (천천히 맥박)
func _draw_glow(r: Rect2) -> void:
	var a := 0.1 + 0.07 * sin(time * 2.4)
	_ellipse(r.get_center() + Vector2(0, r.size.y * 0.3), r.size.x * 0.58, r.size.y * 0.32, Color(GLOW, a))
	_ellipse(r.get_center() + Vector2(0, r.size.y * 0.3), r.size.x * 0.48, r.size.y * 0.24, Color(GLOW, a))


## 건물 위(착륙장은 아래)에 작은 이름표. 테두리가 은은하게 빛난다.
func _draw_label(id: String) -> void:
	if launch_t >= 0.0:
		return
	var font := get_theme_default_font()
	var text: String = BaseLayout.NAMES[id]
	var lr := BaseLayout.label_rect(id, rects[id])
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	var box := Rect2(Vector2(roundf(lr.get_center().x - w / 2.0), lr.position.y), Vector2(ceilf(w), lr.size.y))
	draw_rect(box, LABEL_BG)
	draw_rect(box, Color(GLOW, 0.45 + 0.25 * sin(time * 2.4)), false, 1.0)
	var color := Color("#ffd34f") if id == "ship" else LABEL_TEXT
	draw_string(font, Vector2(box.position.x, box.position.y + 11), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, color)


# ── 착륙장, 우주선, 조종사 ────────────────────────

func _draw_pad(o: Vector2) -> void:
	var c := o + BaseLayout.PAD_SIZE / 2.0
	var w := BaseLayout.PAD_SIZE.x / 2.0 - 2.0
	var h := BaseLayout.PAD_SIZE.y / 2.0 - 6.0
	var oct := PackedVector2Array()
	for i in 8:
		var ang := TAU * (i + 0.5) / 8.0
		oct.append((c + Vector2(cos(ang) * w, sin(ang) * h)).round())
	# 받침 기둥과 그림자
	draw_rect(Rect2(c + Vector2(-w * 0.6, h - 2), Vector2(w * 1.2, 7)), DARK)
	draw_colored_polygon(oct, METAL_D)
	var inner := PackedVector2Array()
	for p in oct:
		inner.append(c + (p - c) * 0.72)
	draw_polyline(inner + PackedVector2Array([inner[0]]), HAZARD[0], 1.0)
	draw_polyline(oct + PackedVector2Array([oct[0]]), METAL, 1.0)
	_ellipse(c + Vector2(0, 4), w * 0.3, h * 0.28, Color(DARK, 0.6))  # 우주선 그림자
	# 둘레 표시등 (번갈아 깜빡임)
	for i in oct.size():
		var on := _blink(1.2, i * 0.5)
		draw_rect(Rect2(oct[i] - Vector2(1, 1), Vector2(2, 2)), ORANGE if on else Color(ORANGE, 0.3))
	_draw_ship_and_pilot(c)


func _draw_ship_and_pilot(c: Vector2) -> void:
	var ship := PixelArt.ship_large()
	var ship_pos := (c - ship.get_size() / 2.0 - Vector2(0, 4)).round()
	var pilot := PixelArt.pilot()
	var pilot_pos := ship_pos + Vector2(ship.get_width() + 5, ship.get_height() - pilot.get_height())
	if launch_t < 0.0:
		draw_texture(ship, ship_pos)
		# 숨 쉬듯 살짝 움직이는 대기 동작: 2초마다 1픽셀 오르내림
		draw_texture(pilot, pilot_pos + Vector2(0, -1 if _blink(2.0, 0.0, 0.45) else 0))
		return
	# 이륙 연출: 조종사가 우주선에 오르고(사라짐), 우주선이 불꽃을 뿜으며 솟아오른다
	var board := clampf(launch_t / BOARD_TIME, 0.0, 1.0)
	if board < 1.0:
		var p := pilot_pos.lerp(ship_pos + Vector2(ship.get_width() / 2.0 - 2, 6), board).round()
		draw_texture(pilot, p, Color(1, 1, 1, 1.0 - board))
	var k := clampf((launch_t - BOARD_TIME) / (LAUNCH_TIME - BOARD_TIME), 0.0, 1.0)
	var rise := roundf(k * k * (c.y + 40.0))
	if k > 0.0:
		# 땅에 이는 먼지
		_ellipse(c + Vector2(0, 6), 14.0 + k * 30.0, 4.0 + k * 6.0, Color(GROUND_L, 0.6 * (1.0 - k)))
		var flame := 4.0 + (3.0 if _blink(0.08) else 0.0) + k * 6.0
		var fx := ship_pos.x + ship.get_width() / 2.0
		var fy := ship_pos.y + ship.get_height() - rise
		draw_rect(Rect2(fx - 2, fy, 4, flame), PixelArt.FLAME_COLORS[1])
		draw_rect(Rect2(fx - 1, fy, 2, flame * 0.6), PixelArt.FLAME_COLORS[0])
	draw_texture(ship, ship_pos - Vector2(0, rise))


# ── 건물 (원점 o, 크기 BaseLayout.BUILDING_SIZE = 96x64) ──

func _box(o: Vector2, x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), color)


## 노랑-검정 경고 줄무늬
func _hazard(o: Vector2, x: float, y: float, w: float, h: float) -> void:
	var i := 0
	while i < w:
		_box(o, x + i, y, minf(3.0, w - i), h, HAZARD[(int(i) / 3) % 2])
		i += 3


## 벽: 밝은 윗줄, 어두운 아랫줄이 있는 금속 덩어리
func _wall(o: Vector2, x: float, y: float, w: float, h: float) -> void:
	_box(o, x, y, w, h, METAL)
	_box(o, x, y, w, 1, METAL_L)
	_box(o, x, y + h - 1, w, 1, DARK)


## 깜빡이는 표시등
func _lamp(o: Vector2, x: float, y: float, color: Color, period: float, phase: float) -> void:
	_box(o, x, y, 2, 2, color if _blink(period, phase) else Color(color, 0.35))


func _draw_research(o: Vector2) -> void:
	# 안테나 (연구할수록 늘어남)
	var spots := [[18.0, 20.0], [78.0, 22.0], [30.0, 10.0], [66.0, 12.0]]
	for i in BaseLife.antennas(levels):
		var s: Array = spots[i]
		_box(o, s[0], s[1], 1, 36 - s[1], METAL_L)
		_lamp(o, s[0] - 0.5, s[1] - 2, ORANGE if i % 2 == 0 else CYAN, 1.4, i * 0.3)
	# 유리 돔
	var c := o + Vector2(48, 37)
	var dome := PackedVector2Array([c + Vector2(-24, 0)])
	for i in 13:
		var ang := PI + PI * i / 12.0
		dome.append((c + Vector2(cos(ang) * 24.0, sin(ang) * 22.0)).round())
	draw_colored_polygon(dome, GLASS)
	for r in [16.0, 8.0]:
		_arc(c, r, r * 22.0 / 24.0, PI, TAU, Color(GLASS_L, 0.5))
	_box(o, 47.5, 15, 1, 22, Color(GLASS_L, 0.5))
	_arc(c, 21.0, 19.0, PI * 1.15, PI * 1.45, Color.WHITE)
	# 받침 건물
	_wall(o, 8, 36, 80, 24)
	_hazard(o, 8, 37, 80, 2)
	_box(o, 14, 43, 16, 9, Color(GLASS_L, 0.7))
	_box(o, 66, 43, 16, 9, Color(GLASS_L, 0.7))
	_box(o, 16, 45, 6, 1, CYAN)
	_box(o, 68, 47, 8, 1, CYAN)
	_box(o, 41, 45, 14, 15, METAL_D)
	_box(o, 47, 45, 1, 15, DARK)
	# 연구 불빛 (연구할수록 늘어남)
	# 앞 5개는 문 왼쪽, 나머지는 문 오른쪽에 줄지어 켜진다
	for i in BaseLife.research_lights(levels):
		var x := 11 + i * 6 if i < 5 else 59 + (i - 5) * 6
		_lamp(o, x, 56, CYAN, 2.0, i * 0.13)


func _draw_hangar(o: Vector2) -> void:
	# 둥근 지붕 (붉은 녹 줄무늬)
	var c := o + Vector2(48, 28)
	var roof := PackedVector2Array([c + Vector2(-44, 0)])
	for i in 13:
		var ang := PI + PI * i / 12.0
		roof.append((c + Vector2(cos(ang) * 44.0, sin(ang) * 18.0)).round())
	draw_colored_polygon(roof, METAL)
	for k in [0.7, 0.45]:
		_arc(c, 44.0 * k, 18.0 * k, PI * 1.05, PI * 1.95, RUST)
	_wall(o, 4, 28, 88, 32)
	# 큰 문
	_box(o, 26, 32, 44, 28, METAL_D)
	for y in [38, 44, 50, 56]:
		_box(o, 26, y, 44, 1, DARK)
	_box(o, 47, 32, 2, 28, DARK)
	_hazard(o, 26, 58, 44, 2)
	_lamp(o, 22, 34, ORANGE, 1.0, 0.0)
	_lamp(o, 72, 34, ORANGE, 1.0, 0.5)
	_box(o, 40, 29, 16, 2, ORANGE if _blink(2.0, 0.2, 0.8) else Color(ORANGE, 0.5))
	# 옆 창문
	_box(o, 8, 36, 12, 3, Color("#ffd27a"))
	_box(o, 76, 36, 12, 3, Color("#ffd27a"))


func _draw_storage(o: Vector2) -> void:
	# 굴뚝과 건물
	_box(o, 30, 8, 4, 12, METAL_L)
	_box(o, 36, 11, 4, 9, METAL_L)
	_lamp(o, 31, 6, ORANGE, 1.6, 0.0)
	_box(o, 22, 18, 70, 4, METAL_D)
	_box(o, 42, 19, 22, 2, Color("#ffd27a"))
	_wall(o, 24, 22, 66, 36)
	# 열린 문 안의 상자들
	_hazard(o, 40, 28, 38, 2)
	_box(o, 40, 30, 38, 28, DARK)
	_box(o, 44, 46, 10, 8, Color("#8a5a2e"))
	_box(o, 56, 48, 8, 6, Color("#a8743a"))
	_box(o, 66, 44, 9, 10, Color("#8a5a2e"))
	_lamp(o, 82, 34, CYAN, 1.3, 0.3)
	# 컨테이너
	_box(o, 2, 34, 22, 12, Color("#a8433a"))
	_box(o, 2, 34, 22, 1, Color("#d8705f"))
	_box(o, 0, 46, 26, 12, Color("#3a5aa8"))
	_box(o, 0, 46, 26, 1, Color("#6f8ad8"))
	for x in [6, 12, 18]:
		_box(o, x, 36, 1, 9, Color("#7a2a22"))
		_box(o, x - 2, 48, 1, 9, Color("#22386f"))
	# 앞에 쌓인 광물 더미 (보유 광물이 많을수록 큼)
	var level := BaseLife.pile_level(credits)
	if level <= 0:
		return
	var grades := [0, 1, 0, 2, 1, 0, 1, 2, 3, 1, 2, 0, 1, 2, 3]
	var n := level * 4
	var x0 := 30.0 + (5 - level) * 4.0
	var i := 0
	var row := 0
	while i < n:
		var per := maxi(level + 1 - row, 1)
		for k in per:
			if i >= n:
				break
			var tex := PixelArt.mineral(grades[i % grades.size()])
			draw_texture(tex, (o + Vector2(x0 + row * 3.0 + k * 7.0, 58 - row * 4 - tex.get_height())).round())
			i += 1
		row += 1
	# 반짝임
	if _blink(1.7, 0.0, 0.15):
		_box(o, x0 + 6, 52 - level * 2, 1, 1, Color.WHITE)


func _draw_museum(o: Vector2) -> void:
	# 유리 지붕
	var roof := PackedVector2Array([o + Vector2(26, 18), o + Vector2(70, 18), o + Vector2(80, 28), o + Vector2(16, 28)])
	draw_colored_polygon(roof, Color(GLASS_L, 0.8))
	for x in [36, 48, 60]:
		_box(o, x, 19, 1, 9, GLASS)
	_lamp(o, 14, 25, ORANGE, 1.5, 0.0)
	_lamp(o, 80, 25, ORANGE, 1.5, 0.5)
	_wall(o, 6, 28, 84, 30)
	_hazard(o, 6, 29, 84, 2)
	# 진열창과 전시품 (희귀 결정, 금괴)
	for x in [11.0, 61.0]:
		_box(o, x, 35, 24, 17, Color(0.25, 0.45, 0.5))
		_box(o, x, 35, 24, 1, GLASS_L)
		_box(o, x + 7, 47, 10, 3, METAL_L)
	var crystal := PixelArt.mineral(1)
	draw_texture(crystal, (o + Vector2(23 - crystal.get_width() / 2.0, 46 - crystal.get_height())).round())
	var gold := PixelArt.mineral(3)
	draw_texture(gold, (o + Vector2(73 - gold.get_width() / 2.0, 46 - gold.get_height())).round())
	# 문
	_box(o, 41, 38, 14, 20, METAL_D)
	_box(o, 47, 38, 1, 20, DARK)
	_lamp(o, 47, 34, CYAN, 1.1, 0.2)


func _draw_drone_factory(o: Vector2) -> void:
	# 크레인 (팔이 천천히 흔들림)
	_box(o, 66, 0, 3, 30, YELLOW)
	for y in range(2, 30, 4):
		_box(o, 66, y, 3, 1, Color("#a8841e"))
	_box(o, 40, 1, 40, 2, YELLOW)
	var hook_x := 48.0 + roundf(sin(time * 0.8) * 3.0)
	_box(o, hook_x, 3, 1, 10, METAL_L)
	_box(o, hook_x - 2, 13, 5, 3, METAL)
	_lamp(o, 78, 0, ORANGE, 1.0, 0.0)
	# 짓다 만 뼈대
	for x in [14, 46, 78]:
		_box(o, x, 22, 4, 36, METAL_L)
	_box(o, 14, 22, 68, 3, RUST)
	_box(o, 14, 38, 68, 3, RUST)
	_box(o, 8, 56, 80, 4, METAL_D)
	# 비계
	for sx in [2.0, 84.0]:
		for y in range(28, 58, 6):
			_box(o, sx, y, 10, 1, YELLOW)
		_box(o, sx, 28, 1, 30, YELLOW)
		_box(o, sx + 9, 28, 1, 30, YELLOW)
	# 차단막
	_hazard(o, 6, 60, 84, 2)
	# "곧 개방" 표지
	_box(o, 26, 42, 44, 13, YELLOW)
	_box(o, 26, 54, 44, 1, Color("#a8841e"))
	draw_string(get_theme_default_font(), o + Vector2(26, 52), "곧 개방", HORIZONTAL_ALIGNMENT_CENTER, 44, 12, DARK)


## 기지 위를 도는 작은 드론 (깜빡이는 불빛)
func _draw_drone() -> void:
	var a: Rect2 = rects["ship"]
	var c := a.get_center() + Vector2(0, -a.size.y * 0.9)
	var p := (c + Vector2(cos(time * 0.6) * a.size.x * 0.9, sin(time * 1.2) * 8.0)).round()
	_box(p, -3, 0, 7, 2, METAL_L)
	_box(p, -4, -1, 2, 1, METAL)
	_box(p, 3, -1, 2, 1, METAL)
	_box(p, 0, 2, 1, 1, CYAN if _blink(0.6) else Color(CYAN, 0.3))


## 타원 호 (지붕 줄무늬, 돔 반사광): 점을 이어 그린다
func _arc(center: Vector2, rx: float, ry: float, from: float, to: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var ang := lerpf(from, to, i / 12.0)
		pts.append((center + Vector2(cos(ang) * rx, sin(ang) * ry)).round())
	draw_polyline(pts, color, 1.0)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(rx, 0.01)))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform(Vector2.ZERO)
