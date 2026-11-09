class_name BaseView
extends Control
## 기지 풍경: 소행성 위 네모 격자 갑판 정거장. 착륙장(3칸 높이), 건물, 건설 예정 칸, 통로, 맨 바깥 둘레 띠, 지도 가장자리 꾸밈, 대기 움직임.
## 좌표는 착륙장 가운데가 원점인 그림 픽셀(BaseLayout). 그림 1픽셀 = 격자 1칸이고 화면 배율은 부모 Stage가 정수로 맞춘다.
## 복잡함 줄이는 규칙(계획서 32번): 밝기 건물 > 갑판 > 통로, 흐린 이름 글자, 건설 예정은 다음 1칸, 꾸밈은 지도 가장자리에만 (착륙장 소품은 착륙장 칸 안에만).
## 누르기는 main.gd가 BaseLayout.touch_rect 자리에 놓은 버튼이 맡고, 여기서는 그리기만 한다.

## 이륙 연출 시간: 조종사 탑승 + 이륙 → 워프 충전 → 점프 (WarpJump)
const LAUNCH_TIME := WarpJump.BASE_TIME
## 그림 1칸 (연출 코드의 "칸" 단위)
const P := 1.0

const CYAN := Color("#59e4ff")
const GUIDE := Color("#30e1b9")
const GUIDE_DIM := Color("#16544a")
## 항상 보이는 흐린 이름 글자 (건물보다 어둡게), 건설 예정 글자, 강조했을 때 밝은 이름표 글자
const NAME_DIM := Color(0.62, 0.58, 0.68, 0.85)
const NAME_EMPTY := Color(0.82, 0.68, 0.32, 0.8)
const NAME_LIT := Color("#fef8e5")
const NAME_PAD := Color("#99e9e6")
const EMPTY_NAME := "건설 예정"
const NAME_OUTLINE := Color8(20, 18, 26)
## 건물 창 불빛 색 (원본 그림의 창 색). 이 자리들을 천천히 번갈아 끈다
const WINDOW_COLORS := [Color8(254, 248, 229), Color8(246, 206, 80), Color8(48, 225, 185), Color8(153, 233, 230)]
const WINDOW_OFF := Color8(60, 53, 68)
const WINDOW_SPOTS := 8

## 연구소 위 부품 자리 (연구소 그림 기준 그림 픽셀, 부품 그림의 아래 가운데가 닿는 곳): [부품 번호, x, y]
## 1 = 안테나 기둥, 2 = 접시 안테나. 연구할수록 앞에서부터 하나씩 늘어난다.
const ANTENNA_SPOTS := [[1, 12, 46], [2, 14, 62], [1, 26, 34], [1, 62, 32]]
## 연구소 불빛(부품 3) 자리: 돔 아래 띠를 따라 왼쪽부터
const LIGHT_SPOTS := [[16, 60], [22, 62], [28, 64], [34, 65], [40, 66], [48, 66], [54, 65], [60, 64], [66, 62], [72, 60]]
## 창고 앞 광물 더미 자리 (창고 그림 기준, 더미 그림의 아래 가운데). 그림 아래 끝을 넘지 않아야 이름 글자와 안 겹친다
const PILE_SPOT := Vector2(66, 84)
## 착륙장 고리 가운데에 놓는 우주선 칸(48x48)의 아래 가운데, 칸 안 여백(연출의 발 위치), 조종사 자리, 착륙장 이름표 자리
const SHIP_FOOT := Vector2(0, 24)
const SHIP_PAD := 14.0
const PILOT_FOOT := Vector2(24, 18)
const PAD_NAME_Y := -64.0
## 착륙장 유도등 줄 (착륙장 그림 기준 세로 위치, 그림 비율): 고리 위 4개, 아래 4개
const GUIDE_FRACS := [0.077, 0.135, 0.195, 0.255, 0.662, 0.72, 0.78, 0.838]
## 착륙장 그림의 고리가 가운데보다 위라 내려서 고리를 원점에 맞춘다
const PAD_DROP := 13.0
## 관제탑 자리, 착륙장 아래쪽 소품 (착륙장 가운데 기준, 그림 아래 가운데)
const TOWER_FOOT := Vector2(-40, -78)
const PAD_PROPS := {"fuel": Vector2(38, 128), "cargo": Vector2(-38, 128)}
## 지도 가장자리 꾸밈: [그림, 왼쪽(-1)/오른쪽(1), 세로 위치(둘레 높이 비율)]
const DECOR := [["solar", -1, 0.42], ["solar", 1, 0.42], ["mast", -1, 0.16], ["dish", 1, 0.16], ["tanks", -1, 0.82], ["tanks", 1, 0.82]]
const DECOR_GAP := 30.0
## 위쪽 경고등은 상단 바에 가리지 않게 귀퉁이보다 이만큼 내려 놓는다
const BEACON_TOP_FOOT := 26.0
## 맨 바깥 둘레 띠 두께: 앞쪽(아래)은 턱이 보여 두껍게
const EDGE_THIN := 3.0
const EDGE_FRONT := 4.0

## 마우스를 올리거나 키보드로 고른 건물: 윤곽선이 빛나고, 누르는 순간 PRESS_TIME 동안 더 밝게 번쩍인다
const HOVER_COLOR := Color("#9ff6ff")
const PRESS_TIME := 0.18
## 지나가는 운석이 날아다니는 높이 (보이는 화면 위쪽 띠)
const METEOR_BAND := 90.0

## 진행 상황 (연구 단계·보유 광물로 기지 모습이 바뀜)
var levels: Dictionary = {}
var credits := 0
## 지난 시간 (깜빡임·움직임)
var time := 0.0
## 이륙 연출 진행 시간 (-1이면 이륙 전)
var launch_t := -1.0
## 귀환 착륙 연출 진행 시간 (-1이면 없음)
var landing_t := -1.0
## 착륙장 이름표 글자가 2배인 폰 배치인지, 임시 건물을 더했는지
var large := false
var busy := false
## 정거장 칸, 지도 사각형, 둘레 선분
var cells: Array[Vector2i] = []
var map := Rect2()
var _outline: Array = []
## 건물 목록: [id(임시 건물은 ""), 그림 이름, 칸, 이름]. 위 칸부터
var buildings: Array = []
var empties: Array[Vector2i] = []
## 경고등 자리: 정거장 네 귀퉁이
var _beacons: Array[Vector2] = []
## 지금 화면에 보이는 지도 영역 (지나가는 운석이 나오는 자리)
var visible_rect := Rect2()
## 지나가는 운석: [위치, 속도]
var _meteors: Array = []
var _meteor_timer := 2.0
var _rng := RandomNumberGenerator.new()
var _tex := {}
var _name_plate: StyleBoxTexture
## 강조할 건물 id (마우스를 올렸거나 키보드로 고름, 없으면 "")와 누른 건물·남은 번쩍임 시간
var hover_id := ""
var pressed_id := ""
var press_time := 0.0
## 그림 이름 → 윤곽선 칸 (그림 픽셀 좌표, 불투명한 픽셀과 맞닿은 투명한 칸)
var _outlines: Dictionary = {}
## 그림 이름 → 창 자리 (그림 픽셀)
var _windows: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # 통로·둘레 띠를 이어 붙인다
	_rng.seed = 2026
	_name_plate = BaseHud.plate_style(true)
	setup(false, false)


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var dir := BaseLayout.SPRITE_DIR if ResourceLoader.exists(BaseLayout.SPRITE_DIR + name + ".png") else BaseLayout.OLD_SPRITE_DIR
		_tex[name] = load(dir + name + ".png")
	return _tex[name]


## 배치를 다시 계산한다 (폰·PC 배치가 바뀌거나 임시 건물을 켤 때)
func setup(is_large: bool, is_busy: bool) -> void:
	large = is_large
	busy = is_busy
	cells = BaseLayout.station_cells(busy)
	map = BaseLayout.map_rect(cells)
	_outline = BaseLayout.outline(cells)
	buildings.clear()
	for id in BaseLayout.CELLS:
		buildings.append([id, "b_" + id, BaseLayout.CELLS[id], BaseLayout.NAMES[id]])
	var built: Array = BaseLayout.CELLS.values()
	if busy:
		for id in BaseLayout.DEBUG_EXTRA:
			buildings.append(["", "b_" + id, BaseLayout.DEBUG_EXTRA[id], BaseLayout.DEBUG_NAMES[id]])
		built.append_array(BaseLayout.DEBUG_EXTRA.values())
	buildings.sort_custom(func(a: Array, b: Array) -> bool: return a[2].y < b[2].y)
	empties = BaseLayout.next_slots(built)
	var corners: Array[Vector2] = []
	for seg in _outline:
		corners.append(seg[0])
		corners.append(seg[1])
	var sums := corners.map(func(v: Vector2) -> float: return v.x + v.y)
	var diffs := corners.map(func(v: Vector2) -> float: return v.x - v.y)
	_beacons = [corners[sums.find(sums.min())], corners[sums.find(sums.max())], corners[diffs.find(diffs.min())], corners[diffs.find(diffs.max())]]
	queue_redraw()


## 칸 하나 (격자에 맞춘 P×P 크기 사각형 w×h개)
static func _cell_rect(pos: Vector2, w: float = 1.0, h: float = 1.0) -> Rect2:
	return Rect2(pos.round(), Vector2(w, h) * P)


## 이륙을 시작한다 (main.gd가 LAUNCH_TIME 뒤 출격 화면으로 넘어간다).
func start_launch() -> void:
	launch_t = 0.0


## 귀환해서 내려오는 착륙 연출을 시작한다.
func start_landing() -> void:
	landing_t = 0.0


## 누른 순간 더 밝게 번쩍인다 (main.gd가 버튼을 누를 때 부름)
func flash(id: String) -> void:
	pressed_id = id
	press_time = PRESS_TIME


func _process(delta: float) -> void:
	time += delta
	press_time = maxf(press_time - delta, 0.0)
	if launch_t >= 0.0:
		launch_t += delta
	if landing_t >= 0.0:
		landing_t = landing_t + delta if landing_t + delta < Juice.WARP_LAND_TIME else -1.0
	# 가끔 하늘을 가로지르는 운석
	_meteor_timer -= delta
	if _meteor_timer <= 0.0:
		_meteor_timer = BaseLife.next_meteor_gap(_rng)
		var from_left := _rng.randf() < 0.5
		var start := Vector2(visible_rect.position.x - 15.0 if from_left else visible_rect.end.x + 15.0, visible_rect.position.y + _rng.randf_range(30.0, METEOR_BAND))
		_meteors.append([start, Vector2(1.0 if from_left else -1.0, 0.3) * _rng.randf_range(130.0, 200.0)])
	var kept: Array = []
	for m in _meteors:
		m[0] += m[1] * delta
		if m[0].x > visible_rect.position.x - 30.0 and m[0].x < visible_rect.end.x + 30.0:
			kept.append(m)
	_meteors = kept
	queue_redraw()


## 깜빡임: period초마다 on_ratio만큼 켜짐 (phase로 서로 엇갈리게)
func _blink(period: float, phase: float = 0.0, on_ratio: float = 0.5) -> bool:
	return fposmod(time / period + phase, 1.0) < on_ratio


## 그림 칸 (격자에 맞춘 P×P 크기 사각형 w×h개). pos는 화면 좌표.
func _cell(pos: Vector2, color: Color, w: float = 1.0, h: float = 1.0) -> void:
	draw_rect(_cell_rect(pos, w, h), color)


## 그림을 그린다. foot는 그림 아래 가운데가 닿을 좌표.
func _sprite(t: Texture2D, foot: Vector2, modulate_color: Color = Color.WHITE) -> void:
	var s := t.get_size()
	draw_texture_rect(t, Rect2((foot - Vector2(s.x / 2.0, s.y)).round(), s), false, modulate_color)


func _draw() -> void:
	if launch_t >= 0.0 and App.settings.shake:
		# 충전이 진행될수록 화면 전체가 격자 칸 단위로 떨린다
		var amp := WarpJump.shake_cells(launch_t)
		draw_set_transform(Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp)).round())
	_draw_ground()
	_draw_decor()
	_draw_edge()
	_draw_decks()
	_draw_walkways()
	_draw_pad()
	for b in buildings:
		_draw_building(b)
	_draw_beacons()
	_draw_ship_and_pilot()
	_draw_meteors()
	_draw_names()


# ── 땅, 갑판, 통로, 둘레 ──────────────────────────────

func _draw_ground() -> void:
	var g := tex("ground_small" if BaseLayout.fits_small_ground(cells) else "ground")
	draw_texture(g, (-g.get_size() / 2.0).round())


## 꾸밈(태양광 판, 안테나, 접시, 탱크)은 둘레 바깥 돌 위에만 (계획서 32번 규칙 5)
func _draw_decor() -> void:
	var inner := map.grow_individual(-BaseLayout.MAP_MARGIN.x, -BaseLayout.MAP_MARGIN.y, -BaseLayout.MAP_MARGIN.x, -BaseLayout.MAP_MARGIN.y)
	for d in DECOR:
		var x: float = inner.position.x - DECOR_GAP if d[1] < 0 else inner.end.x + DECOR_GAP
		_sprite(tex(d[0]), Vector2(x, inner.position.y + inner.size.y * d[2] + 10.0))


## 맨 바깥 둘레에만 낮고 어두운 띠 하나 (기둥 없음). 앞쪽은 턱이 보여 조금 두껍다
func _draw_edge() -> void:
	for seg in _outline:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d: Vector2i = seg[2]
		if d.y != 0:
			var h := EDGE_FRONT if d.y > 0 else EDGE_THIN
			var y := a.y if d.y > 0 else a.y - h
			draw_texture_rect(tex("edge_h"), Rect2(a.x - EDGE_THIN, y, b.x - a.x + EDGE_THIN * 2.0, h), true)
		else:
			var x := a.x if d.x > 0 else a.x - EDGE_THIN
			draw_texture_rect(tex("edge_v"), Rect2(x, a.y, EDGE_THIN, b.y - a.y), true)


func _is_lit(id: String) -> bool:
	return id != "" and launch_t < 0.0 and (id == hover_id or (id == pressed_id and press_time > 0.0))


func _draw_decks() -> void:
	for b in buildings:
		var r := BaseLayout.plate_rect(b[2])
		draw_texture_rect(tex("deck_lit" if _is_lit(b[0]) else "deck"), Rect2(r.position, tex("deck").get_size()), false)
	for c in empties:
		var t := tex("deck_empty")
		var r := BaseLayout.plate_rect(c)
		draw_texture(t, Vector2(r.position.x, r.end.y - t.get_height()))
		_sprite(tex("icon_empty"), BaseLayout.cell_center(c) + Vector2(0, 2))


## 이웃한 칸 사이 통로. 착륙장과는 가운데 줄만 잇는다 (통로가 많으면 어지러움)
func _draw_walkways() -> void:
	var pad_half := tex("pad").get_width() / 2.0
	for c in cells:
		if c.x != 0:
			var right := c + Vector2i.RIGHT
			if c.x != -1 and cells.has(right):
				_walk_h(BaseLayout.plate_rect(c).end.x, BaseLayout.plate_rect(right).position.x, c.y)
			var down := c + Vector2i.DOWN
			if cells.has(down):
				_walk_v(c)
	var side := BaseLayout.plate_rect(Vector2i(-1, 0)).end.x
	_walk_h(side, -pad_half, 0)
	_walk_h(pad_half, -side, 0)


func _walk_h(x0: float, x1: float, row: int) -> void:
	var t := tex("walk_h")
	var h := t.get_height()
	var y := BaseLayout.cell_center(Vector2i(0, row)).y - h / 2.0 + 6.0
	# 끝을 칸 아래로 조금 밀어 넣어 틈이 없게
	draw_texture_rect_region(t, Rect2(x0 - 6.0, y, x1 - x0 + 12.0, h), Rect2(12, 0, 16, h))


func _walk_v(c: Vector2i) -> void:
	var t := tex("walk_v")
	var w := t.get_width()
	var y0 := BaseLayout.plate_rect(c).end.y - 2.0  # 위 칸 앞 턱(이름 글자 자리)을 덮지 않게 턱 끝에서 시작
	var y1 := BaseLayout.plate_rect(c + Vector2i.DOWN).position.y + 6.0
	draw_texture_rect_region(t, Rect2(BaseLayout.cell_center(c).x - w / 2.0, y0, w, y1 - y0), Rect2(0, 16, w, y1 - y0))


## 착륙장: 고리, 위아래 유도등 줄(고리 쪽으로 차례로 켜짐), 관제탑, 아래쪽 소품(연료관, 화물 컨테이너)
func _draw_pad() -> void:
	var t := tex("pad")
	var s := t.get_size()
	var top := (-s / 2.0 + Vector2(0, PAD_DROP)).round()
	draw_texture(t, top)
	for i in GUIDE_FRACS.size():
		var frac: float = GUIDE_FRACS[i]
		var step := (i if i < 4 else 7 - i) - int(time * 5.0) % 4 + 4
		var on: bool = launch_t >= 0.0 or (step % 4) == 0
		var p := Vector2(top.x + s.x / 2.0 - 2.0, top.y + s.y * frac - 2.0).round()
		draw_rect(Rect2(p, Vector2(4, 4)), GUIDE if on else GUIDE_DIM)
		if on:
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 2)), Color("#d7fff4"))
	_sprite(tex("tower"), TOWER_FOOT)
	for prop in PAD_PROPS:
		_sprite(tex(prop), PAD_PROPS[prop])


func _draw_building(b: Array) -> void:
	var t := tex(b[1])
	var r := BaseLayout.building_rect(b[2], t.get_size())
	var id: String = b[0]
	var lit := _is_lit(id)
	if lit:
		_draw_outline(b[1], id, r)
	var shade := Color.WHITE
	if id == pressed_id and press_time > 0.0:
		shade = Color(1.25, 1.25, 1.3)  # 누른 순간 번쩍
	draw_texture_rect(t, r, false, shade)
	_draw_windows(b[1], r)
	match id:
		"research":
			_draw_research_parts(r)
		"storage":
			_draw_pile(r)


## 창 불빛: 건물마다 몇 자리를 정해 천천히 번갈아 끈다
func _draw_windows(name_: String, r: Rect2) -> void:
	if not _windows.has(name_):
		_windows[name_] = window_cells(tex(name_).get_image(), hash(name_))
	var turn := int(time / 1.2) + hash(name_) % 3
	if turn % 3 == 0:
		for c: Vector2i in _windows[name_]:
			draw_rect(Rect2(r.position + Vector2(c), Vector2.ONE), WINDOW_OFF)


## 창 색 픽셀 중 몇 자리 (시드 고정)
static func window_cells(img: Image, seed_value: int) -> Array[Vector2i]:
	img.decompress()
	var found: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and WINDOW_COLORS.any(func(w: Color) -> bool: return c.is_equal_approx(w)):
				found.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Vector2i] = []
	for i in mini(WINDOW_SPOTS, found.size()):
		out.append(found[rng.randi_range(0, found.size() - 1)])
	return out


## 정거장 네 귀퉁이 칸의 경고등 (깜빡임)
func _draw_beacons() -> void:
	for i in _beacons.size():
		var on := launch_t >= 0.0 or _blink(2.0, i * 0.35, 0.4)
		_sprite(tex("beacon_on" if on else "beacon_off"), _beacons[i] + Vector2(0, BEACON_TOP_FOOT if _beacons[i].y < 0.0 else 2.0))


## 이름 글자 (갑판 앞 턱에 상자 없이 항상, 어두운 테두리). 누르거나 마우스를 올리면 밝게. 착륙장은 항상 이름표.
func _draw_names() -> void:
	if launch_t >= 0.0:
		return
	for b in buildings:
		_draw_centered(b[3], name_rect(b[2], b[3]).get_center(), BaseLayout.NAME_FONT_SIZE, NAME_LIT if _is_lit(b[0]) else NAME_DIM)
	for c in empties:
		_draw_centered(EMPTY_NAME, name_rect(c, EMPTY_NAME).get_center(), BaseLayout.NAME_FONT_SIZE, NAME_EMPTY)
	_draw_tag(BaseLayout.NAMES["ship"], Vector2(0, PAD_NAME_Y), 24 if large else 12, NAME_PAD)


## 이 이름을 그릴 자리 (글자 테두리 포함)
func name_rect(cell: Vector2i, text: String) -> Rect2:
	var font := get_theme_default_font()
	var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BaseLayout.NAME_FONT_SIZE)
	return BaseLayout.name_rect(cell, (s + Vector2.ONE * BaseLayout.NAME_OUTLINE).ceil())


## pos는 글자 가운데
func _draw_centered(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := pos + Vector2(-w / 2.0, font.get_ascent(font_size) - font.get_height(font_size) / 2.0)
	draw_string_outline(font, base.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BaseLayout.NAME_OUTLINE, NAME_OUTLINE)  # 갑판 무늬 위에서도 읽히게
	draw_string(font, base.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_tag(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var w := get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 36.0
	var h := 32.0 if large else 19.0
	draw_style_box(_name_plate, Rect2((pos - Vector2(w, h) / 2.0).round(), Vector2(w, h).round()))
	_draw_centered(text, pos, font_size, color)


## 고른 건물의 윤곽선 (그림 테두리 바깥 1칸, 천천히 맥박)
func _draw_outline(name: String, id: String, r: Rect2) -> void:
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


# ── 우주선, 조종사, 이륙 ────────────────────────────

func _draw_ship_and_pilot() -> void:
	var ship := tex("ship")
	var pilot := tex("pilot")
	var ship_foot := SHIP_FOOT
	var pilot_foot := PILOT_FOOT
	if landing_t >= 0.0:
		_draw_landing(ship, ship_foot)
		# 내려앉을 무렵 조종사가 우주선에서 걸어 나온다 (갑자기 나타나지 않게)
		var out := clampf((landing_t / Juice.WARP_LAND_TIME - 0.7) / 0.3, 0.0, 1.0)
		if out > 0.0:
			_sprite(pilot, (ship_foot - Vector2(0, P * 4)).lerp(pilot_foot, out), Color(1, 1, 1, out))
		return
	if launch_t < 0.0:
		_draw_idle_flame(ship_foot)
		_sprite(ship, ship_foot)
		# 숨 쉬듯 살짝 움직이는 대기 동작: 2초마다 그림 1픽셀 오르내림
		_sprite(pilot, pilot_foot - Vector2(0, P if _blink(2.0, 0.0, 0.45) else 0))
		return
	# 이륙: 조종사가 우주선에 오르고(사라짐), 우주선이 불꽃을 뿜으며 떠오른다
	var board := clampf(launch_t / Juice.WARP_BOARD_TIME, 0.0, 1.0)
	if board < 1.0:
		_sprite(pilot, pilot_foot.lerp(ship_foot - Vector2(0, P * 4), board), Color(1, 1, 1, 1.0 - board))
	var k := WarpJump.lift(launch_t)
	var hover := ship_foot - Vector2(0, k * Juice.WARP_HOVER_CELLS * P)
	var jump := WarpJump.jump(launch_t)
	var foot := _jump_foot(hover, WarpJump.jump_rise(jump))
	if k > 0.0:
		_draw_dust(ship_foot - Vector2(0, SHIP_PAD), k, 1.0 - jump)
		var flame := 3 + int(k * 3) + int(WarpJump.charge(launch_t) * 5.0) + (1 if _blink(0.08) else 0)
		_draw_flame(foot - Vector2(0, SHIP_PAD), flame)
	if jump > 0.0:
		_draw_jump_trail(ship, hover, foot, jump)
	_sprite(ship, foot)  # 점프 중에도 그림 크기는 그대로 (ART_BIBLE 1번 정수 배율)
	_draw_warp_glow(foot - Vector2(0, ship.get_height() - SHIP_PAD), WarpJump.charge(launch_t) * (1.0 - jump))


func _jump_foot(hover: Vector2, rise: float) -> Vector2:
	return hover - Vector2(0, rise * Juice.WARP_JUMP_CELLS * P)


## 점프: 떠 있던 자리부터 우주선까지 이어지는 엔진 빛줄기 + 뒤로 남는 잔상
func _draw_jump_trail(ship: Texture2D, hover: Vector2, foot: Vector2, jump: float) -> void:
	var top := foot - Vector2(0, SHIP_PAD)
	var cells := maxf((hover - foot).y / P, 1.0)
	_cell(top + Vector2(-P * 2, 0), Color(CYAN, 0.45 * (1.0 - jump * 0.5)), 5, cells)
	_cell(top, Color(1, 1, 1, 0.9 * (1.0 - jump * 0.5)), 1, cells)
	for i in range(Juice.WARP_GHOSTS, 0, -1):
		var a := WarpJump.ghost_alpha(jump, i)
		if a > 0.0:
			_sprite(ship, _jump_foot(hover, WarpJump.jump_rise(WarpJump.ghost_progress(jump, i))), Color(0.6, 0.95, 1.0, a))


## 대기 엔진: 팩의 작은 불꽃 프레임 (우주선 칸과 같은 48x48)
func _draw_idle_flame(foot: Vector2) -> void:
	RunSprites.draw(self, "ship_flame_idle", int(time * 8.0), 0, foot - Vector2(0, 24))


## 땅에 이는 먼지 (격자 칸)
func _draw_dust(ground_pos: Vector2, spread: float, alpha: float) -> void:
	for i in 10:
		var w := (i - 4.5) * (4.0 + spread * 12.0)
		var lift_cells := float((i * 7) % 3)
		_cell(ground_pos + Vector2(w * P / 2.0, -lift_cells * P * spread), Color(0.75, 0.68, 0.62, 0.6 * alpha * (1.0 - spread * 0.4)), 2, 1)


func _draw_flame(foot: Vector2, length: int) -> void:
	_cell(foot + Vector2(-P, 0), PixelArt.FLAME_COLORS[1], 3, length)
	_cell(foot, PixelArt.FLAME_COLORS[0], 1, maxi(length - 1, 1))


## 워프 충전: 기수 앞에 빛 알갱이가 모이고, 가운데 빛이 커진다 (격자 칸)
func _draw_warp_glow(nose: Vector2, k: float) -> void:
	if k <= 0.0:
		return
	var center := nose - Vector2(0, P * 3)
	for i in Juice.WARP_GATHER_PARTS:
		var f := fposmod(time * 1.8 + i * 0.37, 1.0)
		var dir := Vector2.from_angle(i * 2.4)
		_cell(center + dir * (1.0 - f) * Juice.WARP_GATHER_CELLS * P * (0.6 + 0.4 * k), Color(CYAN, f * k))
	var r := roundi(Juice.WARP_GLOW_CELLS * k)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				_cell(center + Vector2(x, y) * P, Color(1, 1, 1, 0.9) if x * x + y * y <= r * r / 4 else Color(CYAN, 0.45))


## 귀환 착륙: 위에서 감속하며 내려와 먼지를 일으킨다
func _draw_landing(ship: Texture2D, ship_foot: Vector2) -> void:
	var k := landing_t / Juice.WARP_LAND_TIME
	var height := (1.0 - k) * (1.0 - k) * Juice.WARP_LAND_CELLS * P  # 감속
	var foot := ship_foot - Vector2(0, height)
	_draw_flame(foot - Vector2(0, SHIP_PAD), 2 + int((1.0 - k) * 6.0) + (1 if _blink(0.08) else 0))
	_sprite(ship, foot)
	if k > 0.6:
		_draw_dust(ship_foot - Vector2(0, SHIP_PAD), (k - 0.6) / 0.4, 1.0)


# ── 움직이는 것들 ─────────────────────────────────

func _draw_meteors() -> void:
	for m in _meteors:
		var p: Vector2 = m[0]
		var dir: Vector2 = m[1].normalized()
		for k in 7:
			_cell(p - dir * k * P * 2.0, Color(1.0, 0.85, 0.5, 0.8 - k * 0.11))
		_cell(p - Vector2(P, P), Color("#fff3c8"), 2, 2)
