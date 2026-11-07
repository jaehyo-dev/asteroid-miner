class_name BaseView
extends Control
## 기지 풍경 (1280x720 기준): 소행성 바닥(전체가 화면 안에 들어옴), 착륙장의 우주선과 조종사, 건물 5채, 이름표, 길·가로등, 작은 드론, 가끔 지나가는 운석.
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
const ANTENNA_SPOTS := [[2, 50, 39], [1, 6, 44], [1, 53, 45], [1, 3, 37]]
## 연구소 불빛(부품 3) 자리: 돔 아래 띠를 따라 왼쪽부터
const LIGHT_SPOTS := [[10, 36], [14, 36], [19, 36], [23, 36], [27, 36], [31, 36], [35, 36], [39, 36], [44, 36], [48, 36]]
## 창고 앞 광물 더미 자리 (창고 그림 기준, 더미 그림의 아래 가운데)
const PILE_SPOT := Vector2(34, 50)
## 드론 공장 앞 빈 표지판 자리 (그림 기준, 표지판 아래 가운데)
const SIGN_SPOT := Vector2(72, 48)
## 착륙장 위 우주선·조종사 자리 (착륙장 그림 기준, 그림의 아래 가운데)
const SHIP_SPOT := Vector2(26, 22)
const PILOT_SPOT := Vector2(41, 23)

## 밤 기지: 출격 화면(어두운 우주)과 어울리게 바닥과 건물을 어둡게 눌러 그린다 (불빛·이름표·빛 고리는 그대로 밝게)
const GROUND_SHADE := Color(0.64, 0.64, 0.76)
const BUILDING_SHADE := Color(0.88, 0.88, 0.96)
## 접지 그림자 (모든 건물이 왼쪽 위 광원이라 오른쪽 아래로 드리움)
const SHADOW := Color(0.02, 0.01, 0.06, 0.3)
## 마우스를 올리거나 키보드로 고른 건물: 윤곽선이 빛나고, 누르는 순간 PRESS_TIME 동안 더 밝게 번쩍인다
const HOVER_COLOR := Color("#9ff6ff")
const PRESS_TIME := 0.18
## 지나가는 운석이 날아다니는 높이 (화면 위쪽 띠)
const METEOR_BAND := 180.0

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
## 화면 크기가 바뀔 때 한 번만 계산해 두는 칸 목록 (매 프레임 다시 계산하지 않게)
## 길 바닥·배관: [Rect2, 색] / 길 꺾이는 점(가로등 자리): 건물마다 / 접지 그림자: 건물 id → Rect2 목록
var _path_cells: Array = []
var _path_ends: Dictionary = {}
var _path_bends: Dictionary = {}
var _shadow_rects: Dictionary = {}
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
	_path_cells.clear()
	_path_bends.clear()
	_path_ends.clear()
	_shadow_rects.clear()
	for id in BaseLayout.IDS:
		_shadow_rects[id] = _shadow(rects[id])
		if id != "ship":
			_build_road(id)


## 칸 하나 (격자에 맞춘 P×P 크기 사각형 w×h개)
static func _cell_rect(pos: Vector2, w: float = 1.0, h: float = 1.0) -> Rect2:
	return Rect2(BaseLayout.snap(pos), Vector2(w, h) * P)


## 접지 그림자: 건물 아래쪽 절반을 오른쪽 아래로 눕힌 모양 (P 높이 줄을 쌓아 격자에 맞춤)
static func _shadow(r: Rect2) -> Array[Rect2]:
	var rows: Array[Rect2] = []
	var top := r.position.y + r.size.y * 0.62
	var bottom := r.end.y + P * 2.0
	var y := top
	while y < bottom:
		var up := 1.0 - (y - top) / (bottom - top)  # 위쪽 줄일수록 오른쪽으로 더 뻗음
		var left := r.position.x + P * (10.0 if y > r.end.y - P * 6.0 else 18.0)
		var right := r.end.x + P * (4.0 + 6.0 * up)
		rows.append(Rect2(BaseLayout.snap(Vector2(left, y)), BaseLayout.snap(Vector2(right - left, P))))
		y += P
	return rows


## 착륙장에서 건물 입구까지 꺾이는 길 (세로·가로·세로, 건물이 착륙장 옆이면 가로·세로·가로). 점 4개.
## 세로 화면: 위 줄은 착륙장 윗면에서 양옆(±20칸)으로 올라가고, 전시관은 착륙장 아랫면에서 곧장 내려간다.
func _road_points(id: String) -> Array[Vector2]:
	var pr: Rect2 = rects["ship"]
	var r: Rect2 = rects[id]
	var portrait := BaseLayout.is_portrait(size)
	var dx := r.get_center().x - pr.get_center().x
	var pts: Array[Vector2] = []
	if portrait and r.position.y >= pr.end.y:
		# 착륙장 아래 건물(전시관): 착륙장 아랫면에서 내려가 건물 윗문으로
		var a := Vector2(pr.get_center().x, pr.end.y - P * 8)
		var b := Vector2(r.get_center().x, r.position.y)
		var mid := BaseLayout.snap(Vector2(0, (a.y + b.y) / 2.0)).y
		pts = [a, Vector2(a.x, mid), Vector2(b.x, mid), b]
	elif r.end.y <= pr.position.y or (not portrait and r.get_center().y < pr.get_center().y):
		# 착륙장 위쪽 건물: 착륙장 윗면에서 위로 올라가 건물 앞문(그림 아래)으로
		var ax := pr.get_center().x + (signf(dx) * P * 20 if portrait else clampf(dx, -P * 12, P * 12))
		var a := Vector2(ax, pr.position.y + P * 8)
		var b := Vector2(r.get_center().x, r.end.y - P * 4)
		var mid := BaseLayout.snap(Vector2(0, (r.end.y + P * 12) if portrait else (a.y + b.y) / 2.0)).y
		pts = [a, Vector2(a.x, mid), Vector2(b.x, mid), b]
	else:
		# 착륙장 옆·아래쪽 건물: 착륙장 옆면에서 옆으로 나가 건물의 안쪽 옆문으로
		var sgn := signf(dx)
		var a := Vector2(pr.get_center().x + sgn * pr.size.x * 0.4, pr.end.y - P * 12)
		var b := Vector2(r.get_center().x - sgn * r.size.x * 0.3, r.end.y - P * 8)
		var mid := BaseLayout.snap(Vector2((a.x + b.x) / 2.0, 0)).x
		pts = [a, Vector2(mid, a.y), Vector2(mid, b.y), b]
	return pts


## 길 칸과 옆을 따라가는 배관·케이블 칸을 미리 계산 (매 프레임 다시 계산하지 않게)
func _build_road(id: String) -> void:
	var pts := _road_points(id)
	_path_ends[id] = pts[3]
	for k in 3:
		var a := pts[k]
		var b := pts[k + 1]
		var horizontal := absf(b.y - a.y) < 1.0
		var length := (b - a).length()
		var dir := (b - a).normalized()
		var side := dir.orthogonal()
		# 길 바닥 5칸 폭
		var half := P * 2.5
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - (Vector2(0, half) if horizontal else Vector2(half, 0))
		var sz := Vector2(length + P, P * 5) if horizontal else Vector2(P * 5, length + P)
		_path_cells.append([Rect2(BaseLayout.snap(lo), BaseLayout.snap(sz)), METAL_D])
		# 노랑·검정 점선 가장자리 (두 줄)
		var steps := int(length / (P * 2.0)) + 1
		for i in steps:
			var p := a + dir * i * P * 2.0
			var c := YELLOW if i % 2 == 0 else DARK
			for sd: float in [-1.0, 1.0]:
				var q := p + side * sd * half
				_path_cells.append([_cell_rect(q - Vector2(P, P) * 0.5, 2 if horizontal else 1, 1 if horizontal else 2), c])
		# 길 옆 배관 (길과 같은 모양을 오른쪽 아래로 옮긴 것): 어두운 관 + 밝은 윗줄
		var off := Vector2(P * 4, P * 4)
		var plo := lo + off
		var psz := Vector2(length + P, P * 2) if horizontal else Vector2(P * 2, length + P)
		_path_cells.append([Rect2(BaseLayout.snap(plo), BaseLayout.snap(psz)), DARK])
		_path_cells.append([Rect2(BaseLayout.snap(plo), BaseLayout.snap(Vector2(psz.x, P) if horizontal else Vector2(P, psz.y))), METAL])
	_path_bends[id] = [pts[1], pts[2]]


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
		var start := Vector2(-30.0 if from_left else size.x + 30.0, _rng.randf_range(BaseLayout.TOP_BAR, METEOR_BAND))
		_meteors.append([start, Vector2(1.0 if from_left else -1.0, 0.3) * _rng.randf_range(260.0, 400.0)])
	var kept: Array = []
	for m in _meteors:
		m[0] += m[1] * delta
		if m[0].x > -60.0 and m[0].x < size.x + 60.0:
			kept.append(m)
	_meteors = kept
	queue_redraw()


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
	for id in BaseLayout.IDS:
		for c: Rect2 in _shadow_rects[id]:
			draw_rect(c, SHADOW)
	for c in _path_cells:
		draw_rect(c[0], c[1])
	for id in BaseLayout.IDS:
		if id != "ship":
			_draw_path_lamps(id)
	for id in BaseLayout.IDS:
		var r: Rect2 = rects[id]
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
	# 소행성 전체가 화면 가운데에 들어온다 (바깥은 별 배경이 비침)
	var g := ground()
	var s := g.get_size() * P
	draw_texture_rect(g, Rect2(BaseLayout.snap((size - s) / 2.0), s), false, GROUND_SHADE)


## 길의 불빛: 건물 문 앞 양옆 주황 표시등, 길이 꺾이는 곳마다 청록 가로등 (바닥은 relayout에서 미리 계산)
func _draw_path_lamps(id: String) -> void:
	var b: Vector2 = _path_ends[id]
	for s: float in [-5.0, 5.0]:
		_cell(b + Vector2(s * P, 0) - Vector2(0, P), DARK, 1, 2)
		_cell(b + Vector2(s * P, 0) - Vector2(0, P * 2), ORANGE if _blink(1.2, s * 0.05) else Color(ORANGE, 0.35))
	for p: Vector2 in _path_bends[id]:
		if p != b:
			_cell(p + Vector2(-P * 4, 0), DARK, 1, 3)
			_cell(p + Vector2(-P * 4, -P), CYAN if _blink(1.6, p.x * 0.001) else Color(CYAN, 0.35))


## 건물 위(착륙장은 아래)에 이름표. 테두리가 은은하게 빛난다.
func _draw_label(id: String) -> void:
	if launch_t >= 0.0:
		return
	var font := get_theme_default_font()
	var text: String = BaseLayout.NAMES[id]
	var portrait := BaseLayout.is_portrait(size)
	var lr := BaseLayout.label_rect(id, rects[id], portrait)
	# 세로 화면은 상자 여백을 줄여 건물을 덜 가림
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BaseLayout.FONT_SIZE).x + P * (4 if portrait else 6)
	var box := Rect2(BaseLayout.snap(Vector2(lr.get_center().x - w / 2.0, lr.position.y)), BaseLayout.snap(Vector2(w, lr.size.y)))
	draw_rect(box, LABEL_BG)
	draw_rect(box.grow(-P / 2.0), Color(GLOW, 0.5 + 0.25 * sin(time * 2.4)), false, P)
	var color := GOLD if id == "ship" else LABEL_TEXT
	draw_string(font, Vector2(box.position.x, box.position.y + box.size.y - P * 4), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, BaseLayout.FONT_SIZE, color)


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
	if BaseLayout.is_portrait(size):
		foot = Vector2(r.get_center().x, r.end.y + P * 16)  # 세로: 건물 옆 자리가 좁아 건물 바로 아래 가운데
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
