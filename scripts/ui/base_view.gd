class_name BaseView
extends Control
## 기지 풍경 (1280x720 기준): 소행성 바닥 배경, 착륙장의 우주선과 조종사, 건물 5채, 이름표, 길·가로등, 작은 드론, 가끔 지나가는 운석.
## 그림은 Codex로 만든 뒤 tools/pixelate.py로 정리한 픽셀 아트(assets/sprites/base/)이고, 그림 1픽셀 = 화면 PIXEL픽셀이다.
## 코드로 그리는 것(길, 불빛, 드론, 운석, 이름표)도 같은 격자(_cell)에 맞춰 그려서 한 화면의 픽셀 크기를 통일한다.
## 누르기는 main.gd가 BaseLayout.touch_rect 자리에 놓은 버튼이 맡고, 여기서는 그리기만 한다.

## 이륙 연출 시간: 앞부분은 조종사가 우주선에 오르고, 나머지는 우주선이 솟아오른다
const LAUNCH_TIME := 1.0
const BOARD_TIME := 0.3
const P := BaseLayout.PIXEL

const DARK := Color("#1c1d30")
const METAL := Color("#6f748a")
const METAL_D := Color("#43475c")
const YELLOW := Color("#f2c230")
const CYAN := Color("#59e4ff")
const ORANGE := Color("#ff9a2e")
const LABEL_BG := Color(0.03, 0.03, 0.08, 0.8)
const LABEL_TEXT := Color("#e8ecf6")
const GLOW := Color("#7cf0ff")
const GOLD := Color("#ffd34f")

## 연구소 위 부품 자리 (연구소 그림 기준 그림 픽셀, 부품 그림의 아래 가운데가 닿는 곳): [부품 번호, x, y]
## 1 = 안테나 기둥, 2 = 접시 안테나. 연구할수록 앞에서부터 하나씩 늘어난다.
## 이름표와 겹치지 않게 모두 연구소 그림 안쪽(받침 지붕 모서리, 돔 옆)에 둔다.
const ANTENNA_SPOTS := [[2, 74, 32], [1, 11, 32], [1, 82, 34], [1, 20, 30]]
## 연구소 불빛(부품 3) 자리: 돔 아래 띠를 따라 왼쪽부터
const LIGHT_SPOTS := [[17, 37], [22, 37], [28, 37], [34, 37], [39, 37], [45, 37], [50, 37], [56, 37], [62, 37], [67, 37]]
## 창고 앞 광물 더미 자리 (창고 그림 기준, 더미 그림의 아래 가운데)
const PILE_SPOT := Vector2(62, 61)
## 드론 공장 앞 빈 표지판 자리 (그림 기준, 표지판 아래 가운데)
const SIGN_SPOT := Vector2(30, 67)
## 착륙장 위 우주선·조종사 자리 (착륙장 그림 기준, 그림의 아래 가운데)
const SHIP_SPOT := Vector2(46, 32)
const PILOT_SPOT := Vector2(74, 32)

## 밤 기지: 출격 화면(어두운 우주)과 어울리게 바닥과 건물을 어둡게 눌러 그린다 (불빛·이름표·빛 고리는 그대로 밝게)
const GROUND_SHADE := Color(0.5, 0.5, 0.62)
const BUILDING_SHADE := Color(0.78, 0.78, 0.88)
## 마우스를 올리거나 키보드로 고른 건물: 윤곽선이 빛나고, 누르는 순간 PRESS_TIME 동안 더 밝게 번쩍인다
const HOVER_COLOR := Color("#9ff6ff")
const PRESS_TIME := 0.18

## 진행 상황 (연구 단계·보유 광물로 기지 모습이 바뀜)
var levels: Dictionary = {}
var credits := 0
## 지난 시간 (깜빡임·움직임)
var time := 0.0
## 이륙 연출 진행 시간 (-1이면 이륙 전)
var launch_t := -1.0
## 지금 배치 (BaseLayout.rects)
var rects: Dictionary = {}
## 지나가는 운석: [위치, 속도]
var _meteors: Array = []
var _meteor_timer := 2.0
var _rng := RandomNumberGenerator.new()
var _tex := {}
## 바닥 그림이 모자란 곳(아주 긴 화면의 아래)을 채우는 색
var _ground_fill := Color("#4a3d38")
## 화면 크기가 바뀔 때 한 번만 계산해 두는 칸 목록 (매 프레임 다시 계산하지 않게)
## 길 바닥: [Rect2, 색] / 건물 바닥 빛 고리: id → Rect2 목록 (밝기만 매 프레임 바뀜)
var _path_cells: Array = []
var _glow_cells: Dictionary = {}
## 강조할 건물 id (마우스를 올렸거나 키보드로 고름, 없으면 "")와 누른 건물·남은 번쩍임 시간
var hover_id := ""
var pressed_id := ""
var press_time := 0.0
## 그림 이름 → 윤곽선 칸 (그림 픽셀 좌표, 불투명한 픽셀과 맞닿은 투명한 칸)
var _outlines: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 2026
	resized.connect(relayout)
	relayout()


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(BaseLayout.SPRITE_DIR + name + ".png")
	return _tex[name]


func relayout() -> void:
	rects = BaseLayout.rects(size)
	var img := ground().get_image()
	_ground_fill = img.get_pixel(img.get_width() / 2, img.get_height() - 1)
	_path_cells.clear()
	_glow_cells.clear()
	for id in BaseLayout.IDS:
		_glow_cells[id] = _glow_ring(rects[id])
		if id != "ship":
			_path_cells.append_array(_path_floor(id))


## 칸 하나 (격자에 맞춘 P×P 크기 사각형 w×h개)
static func _cell_rect(pos: Vector2, w: float = 1.0, h: float = 1.0) -> Rect2:
	return Rect2(BaseLayout.snap(pos), Vector2(w, h) * P)


## 길 양끝: 착륙장 가운데 아래 → 건물 문 앞
func _path_ends(id: String) -> Array[Vector2]:
	var a: Vector2 = (rects["ship"] as Rect2).get_center() + Vector2(0, P * 6)
	var r: Rect2 = rects[id]
	var below := r.get_center().y > a.y
	return [a, Vector2(r.get_center().x, r.position.y + P * 2 if below else r.end.y - P * 4)]


## 길 바닥 칸 (콘셉트처럼 어두운 바닥 + 노랑·검정 점선 가장자리)
func _path_floor(id: String) -> Array:
	var ends := _path_ends(id)
	var a := ends[0]
	var b := ends[1]
	var steps := int(a.distance_to(b) / P)
	var side := (b - a).normalized().orthogonal()
	var cells := []
	for i in steps:
		var p := a.lerp(b, float(i) / steps)
		var edge := YELLOW if (i / 2) % 2 == 0 else DARK
		for k in range(-3, 4):
			cells.append([_cell_rect(p + side * k * P), edge if absi(k) == 3 else METAL_D])
	return cells


## 건물 바닥의 타원 고리 칸
static func _glow_ring(r: Rect2) -> Array[Rect2]:
	var c := r.get_center() + Vector2(0, r.size.y * 0.36)
	var rx := r.size.x * 0.5 / P
	var ry := r.size.y * 0.16 / P
	var cells: Array[Rect2] = []
	for y in range(-int(ry) - 1, int(ry) + 2):
		for x in range(-int(rx) - 1, int(rx) + 2):
			var d := (x * x) / (rx * rx) + (y * y) / (ry * ry)
			if d <= 1.0 and d > 0.72:
				cells.append(_cell_rect(c + Vector2(x, y) * P))
	return cells


func ground() -> Texture2D:
	return tex("ground_portrait" if BaseLayout.is_portrait(size) else "ground_landscape")


## 이륙을 시작한다 (main.gd가 LAUNCH_TIME 뒤 출격 화면으로 넘어간다).
func start_launch() -> void:
	launch_t = 0.0


## 누른 순간 더 밝게 번쩍인다 (main.gd가 버튼을 누를 때 부름)
func flash(id: String) -> void:
	pressed_id = id
	press_time = PRESS_TIME


func _process(delta: float) -> void:
	time += delta
	press_time = maxf(press_time - delta, 0.0)
	if launch_t >= 0.0:
		launch_t += delta
	# 가끔 하늘을 가로지르는 운석
	_meteor_timer -= delta
	if _meteor_timer <= 0.0:
		_meteor_timer = BaseLife.next_meteor_gap(_rng)
		var from_left := _rng.randf() < 0.5
		var start := Vector2(-30.0 if from_left else size.x + 30.0, _rng.randf_range(BaseLayout.TOP_BAR, sky_height() * 0.9))
		_meteors.append([start, Vector2(1.0 if from_left else -1.0, 0.3) * _rng.randf_range(260.0, 400.0)])
	var kept: Array = []
	for m in _meteors:
		m[0] += m[1] * delta
		if m[0].x > -60.0 and m[0].x < size.x + 60.0:
			kept.append(m)
	_meteors = kept
	queue_redraw()


## 하늘 높이 (바닥 그림의 하늘 부분, 운석이 지나가는 곳)
func sky_height() -> float:
	return P * (40.0 if BaseLayout.is_portrait(size) else 45.0)


## 깜빡임: period초마다 on_ratio만큼 켜짐 (phase로 서로 엇갈리게)
func _blink(period: float, phase: float = 0.0, on_ratio: float = 0.5) -> bool:
	return fposmod(time / period + phase, 1.0) < on_ratio


## 그림 칸 (격자에 맞춘 P×P 크기 사각형 w×h개). pos는 화면 좌표.
func _cell(pos: Vector2, color: Color, w: float = 1.0, h: float = 1.0) -> void:
	draw_rect(_cell_rect(pos, w, h), color)


## 그림을 격자에 맞춰 PIXEL배로 그린다. foot는 그림 아래 가운데가 닿을 화면 좌표.
func _sprite(t: Texture2D, foot: Vector2, modulate: Color = BUILDING_SHADE) -> void:
	var s := t.get_size() * P
	draw_texture_rect(t, Rect2(BaseLayout.snap(foot - Vector2(s.x / 2.0, s.y)), s), false, modulate)


func _draw() -> void:
	if rects.is_empty():
		return
	_draw_ground()
	for c in _path_cells:
		draw_rect(c[0], c[1])
	for id in BaseLayout.IDS:
		if id != "ship":
			_draw_path_lamps(id)
	for id in BaseLayout.IDS:
		var r: Rect2 = rects[id]
		if launch_t < 0.0:
			_draw_glow(id)
		var lit: bool = launch_t < 0.0 and (id == hover_id or (id == pressed_id and press_time > 0.0))
		if lit:
			_draw_outline(id, r)
		var shade := BUILDING_SHADE
		if id == pressed_id and press_time > 0.0:
			shade = Color(1.25, 1.25, 1.3)  # 누른 순간 번쩍
		elif lit:
			shade = Color.WHITE  # 고른 건물은 원래 밝기로
		draw_texture_rect(tex(BaseLayout.SPRITES[id]), r, false, shade)
		match id:
			"ship":
				_draw_ship_and_pilot(r)
			"research":
				_draw_research_parts(r)
			"storage":
				_draw_pile(r)
			"drone":
				_draw_sign(r)
	_draw_drone()
	_draw_meteors()
	for id in BaseLayout.IDS:
		_draw_label(id)


# ── 배경과 길 ──────────────────────────────────────

func _draw_ground() -> void:
	var g := ground()
	var s := g.get_size() * P
	var x := BaseLayout.snap(Vector2((size.x - s.x) / 2.0, 0)).x
	draw_texture_rect(g, Rect2(Vector2(x, 0), s), false, GROUND_SHADE)
	# 아주 넓은 화면: 양옆에 좌우를 뒤집은 배경을 이어 붙인다 (이음매가 자연스럽고 배율은 그대로)
	if x > 0.0:
		draw_set_transform(Vector2(x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(g, Rect2(Vector2.ZERO, s), false, GROUND_SHADE)
		draw_set_transform(Vector2(x + s.x * 2.0, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(g, Rect2(Vector2.ZERO, s), false, GROUND_SHADE)
		draw_set_transform(Vector2.ZERO)
	if s.y < size.y:
		draw_rect(Rect2(0, s.y, size.x, size.y - s.y), _ground_fill * GROUND_SHADE)


## 길의 깜빡이는 불빛: 양끝 주황 표시등(건물 문 앞)과 사이사이 가로등 (바닥은 relayout에서 미리 계산)
func _draw_path_lamps(id: String) -> void:
	var ends := _path_ends(id)
	var a := ends[0]
	var b := ends[1]
	var side := (b - a).normalized().orthogonal()
	# 길 양끝 주황 표시등 (건물 문 앞)
	for s: float in [-5.0, 5.0]:
		_cell(b + side * s * P - Vector2(0, P), DARK, 1, 2)
		_cell(b + side * s * P - Vector2(0, P * 2), ORANGE if _blink(1.2, s * 0.05) else Color(ORANGE, 0.35))
	# 가로등: 길 가운데쯤 양옆에 하나씩
	for t: float in [0.35, 0.65]:
		var p := a.lerp(b, t)
		for s: float in [-4.0, 4.0]:
			var q := p + side * s * P
			_cell(q, DARK, 1, 3)
			_cell(q - Vector2(0, P), CYAN if _blink(1.6, t + s * 0.1) else Color(CYAN, 0.35))


## 누를 수 있는 건물은 바닥이 살짝 빛난다 (천천히 맥박): 미리 계산한 타원 고리 칸에 밝기만 바꿔 그린다
func _draw_glow(id: String) -> void:
	var color := Color(GLOW, 0.16 + 0.1 * sin(time * 2.4))
	for c in _glow_cells[id]:
		draw_rect(c, color)


## 건물 위(착륙장은 아래)에 이름표. 테두리가 은은하게 빛난다.
func _draw_label(id: String) -> void:
	if launch_t >= 0.0:
		return
	var font := get_theme_default_font()
	var text: String = BaseLayout.NAMES[id]
	var lr := BaseLayout.label_rect(id, rects[id])
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BaseLayout.FONT_SIZE).x + P * 6
	var box := Rect2(BaseLayout.snap(Vector2(lr.get_center().x - w / 2.0, lr.position.y)), BaseLayout.snap(Vector2(w, lr.size.y)))
	draw_rect(box, LABEL_BG)
	draw_rect(box.grow(-P / 2.0), Color(GLOW, 0.5 + 0.25 * sin(time * 2.4)), false, P)
	var color := GOLD if id == "ship" else LABEL_TEXT
	draw_string(font, Vector2(box.position.x, box.position.y + P * 12), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, BaseLayout.FONT_SIZE, color)


## 고른 건물의 윤곽선 (그림 테두리 바깥 1칸, 천천히 맥박)
func _draw_outline(id: String, r: Rect2) -> void:
	var name: String = BaseLayout.SPRITES[id]
	if not _outlines.has(name):
		_outlines[name] = outline_cells(tex(name).get_image())
	var a := 0.75 + 0.25 * sin(time * 6.0)
	if id == pressed_id and press_time > 0.0:
		a = 1.0
	var color := Color(HOVER_COLOR, a)
	for c: Vector2i in _outlines[name]:
		draw_rect(Rect2(r.position + Vector2(c) * P, Vector2(P, P)), color)


## 그림의 윤곽선 칸: 불투명한 픽셀과 맞닿은(상하좌우) 투명한 칸. 그림 밖 1칸까지 포함.
static func outline_cells(img: Image) -> Array[Vector2i]:
	img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and img.get_pixel(x, y).a > 0.5
	var cells: Array[Vector2i] = []
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			if solid.call(x, y):
				continue
			if solid.call(x - 1, y) or solid.call(x + 1, y) or solid.call(x, y - 1) or solid.call(x, y + 1):
				cells.append(Vector2i(x, y))
	return cells


# ── 건물마다 바뀌는 부분 ────────────────────────────

## 연구소: 연구할수록 안테나와 불빛이 늘어난다
func _draw_research_parts(r: Rect2) -> void:
	for i in BaseLife.antennas(levels):
		var spot: Array = ANTENNA_SPOTS[i]
		_sprite(tex("research_parts_%d" % spot[0]), r.position + Vector2(spot[1], spot[2]) * P)
	for i in BaseLife.research_lights(levels):
		var spot: Array = LIGHT_SPOTS[i]
		var on := Color.WHITE if _blink(2.0, i * 0.13, 0.8) else Color(1, 1, 1, 0.45)
		_sprite(tex("research_parts_3"), r.position + Vector2(spot[0], spot[1]) * P, on)


## 광물 창고: 보유 광물이 많을수록 앞에 쌓인 광물 더미가 커진다
func _draw_pile(r: Rect2) -> void:
	var level := BaseLife.pile_level(credits)
	if level > 0:
		_sprite(tex("pile_%d" % level), r.position + PILE_SPOT * P)


## 드론 공장 앞 빈 표지판 자리에 "곧 개방"
func _draw_sign(r: Rect2) -> void:
	var font := get_theme_default_font()
	var text := "곧 개방"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BaseLayout.FONT_SIZE).x + P * 4
	var foot := r.position + SIGN_SPOT * P
	var box := Rect2(BaseLayout.snap(Vector2(foot.x - w / 2.0, foot.y - P * 14)), BaseLayout.snap(Vector2(w, P * 14)))
	draw_rect(box, YELLOW)
	draw_rect(Rect2(box.position + Vector2(0, box.size.y - P), Vector2(box.size.x, P)), Color("#a8841e"))
	draw_string(font, Vector2(box.position.x, box.position.y + P * 11), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, BaseLayout.FONT_SIZE, DARK)


# ── 우주선, 조종사, 이륙 ────────────────────────────

func _draw_ship_and_pilot(pad: Rect2) -> void:
	var ship := tex("ship")
	var pilot := tex("pilot")
	var ship_foot := pad.position + SHIP_SPOT * P
	var pilot_foot := pad.position + PILOT_SPOT * P
	if launch_t < 0.0:
		_sprite(ship, ship_foot)
		# 숨 쉬듯 살짝 움직이는 대기 동작: 2초마다 그림 1픽셀 오르내림
		_sprite(pilot, pilot_foot - Vector2(0, P if _blink(2.0, 0.0, 0.45) else 0))
		return
	# 이륙 연출: 조종사가 우주선에 오르고(사라짐), 우주선이 불꽃을 뿜으며 솟아오른다
	var board := clampf(launch_t / BOARD_TIME, 0.0, 1.0)
	if board < 1.0:
		_sprite(pilot, pilot_foot.lerp(ship_foot - Vector2(0, P * 4), board), Color(1, 1, 1, 1.0 - board))
	var k := clampf((launch_t - BOARD_TIME) / (LAUNCH_TIME - BOARD_TIME), 0.0, 1.0)
	var rise := k * k * (ship_foot.y + ship.get_height() * P)
	var foot := ship_foot - Vector2(0, rise)
	if k > 0.0:
		# 땅에 이는 먼지와 엔진 불꽃 (격자 칸)
		for i in 8:
			var spread := (i - 3.5) * (4.0 + k * 10.0)
			_cell(ship_foot + Vector2(spread * P / 3.0, 0), Color(0.75, 0.68, 0.62, 0.7 * (1.0 - k)), 2, 1)
		var flame := 3 + int(k * 5) + (1 if _blink(0.08) else 0)
		_cell(foot + Vector2(-P, 0), PixelArt.FLAME_COLORS[1], 3, flame)
		_cell(foot, PixelArt.FLAME_COLORS[0], 1, flame - 1)
	_sprite(ship, foot)


# ── 움직이는 것들 ─────────────────────────────────

## 기지 위를 도는 작은 정찰 드론 (깜빡이는 불빛)
func _draw_drone() -> void:
	var a: Rect2 = rects["ship"]
	var c := a.get_center() - Vector2(0, a.size.y * 0.9)
	var p := c + Vector2(cos(time * 0.5) * a.size.x * 0.8, sin(time * 1.0) * P * 4)
	_cell(p - Vector2(P * 3, 0), METAL, 7, 2)
	_cell(p - Vector2(P * 4, P), Color("#c8cde0"), 3, 1)
	_cell(p + Vector2(P * 2, -P), Color("#c8cde0"), 3, 1)
	_cell(p + Vector2(0, P * 2), CYAN if _blink(0.6) else Color(CYAN, 0.3))


func _draw_meteors() -> void:
	for m in _meteors:
		var p: Vector2 = m[0]
		var dir: Vector2 = m[1].normalized()
		for k in 7:
			_cell(p - dir * k * P * 2.0, Color(1.0, 0.85, 0.5, 0.8 - k * 0.11))
		_cell(p - Vector2(P, P), Color("#fff3c8"), 2, 2)
