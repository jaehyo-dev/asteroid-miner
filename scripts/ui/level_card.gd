class_name LevelCard
extends BaseButton
## 레벨업 카드 한 장 (프레임 S). 9칸 프레임 + 등급 색 바꾸기 + 장식, 원형 받침과 아이콘, 종류 표, 이름, 설명, 단계 점.
## 프레임·장식·꼬리표·받침·아이콘은 모두 논리 1배로 뒤 출격 화면과 같은 픽셀 격자다. 글자는 PC 12px, 폰 24px.

const ART := "res://assets/sprites/run/card/"
const FONT := preload("res://assets/fonts/galmuri/Galmuri11.ttf")
const GRADE_SHADER := preload("res://scripts/card_grade.gdshader")

const INK := Color("#fef8e5")
## 이름과 글자 크기가 같아서 설명은 조금 어둡게 구분한다
const DESC_COLOR := Color("#d9d0c0")
const NAME_COLORS: Array[Color] = [INK, Color("#99e9e6"), Color("#a884f3"), Color("#f6ce50"), INK]
## 등급별 빛 색과 계단 빛의 알파 (0~255). 높은 등급일수록 띠가 많다
const GLOW_COLORS: Array[Color] = [Color("#5c5164"), Color("#30e1b9"), Color("#a884f3"), Color("#f6ce50"), Color.WHITE]
const GLOW_ALPHA: Array[Array] = [[], [80, 34], [110, 60, 24], [130, 80, 44, 18], [150, 100, 60, 30, 14]]
## 번쩍일 때 더 퍼지는 빛 띠의 알파, 커서를 올렸을 때 빛
const GLOW_BOOST_ALPHA := 24.0 / 255.0
const HOVER_ALPHA := 0.35
const HOVER_BANDS := 2

## 발광 부분으로 쓰인 색 (등급 색으로 바뀌는 자리)
const TEAL_LIKE: Array[String] = ["#30e1b9", "#125952", "#1da775", "#4d80cd"]
const TEAL_LIGHT := "#99e9e6"
const GOLD := {"#a5b29d": "#f6ce50", "#917487": "#dc7f47", "#5c5164": "#984633", "#3c3544": "#6f2626", "#a5cc5f": "#f6ce50", "#70525e": "#984633", "#577e66": "#dc7f47"}
const EPIC_TINT := {"#917487": "#6b3e75", "#70525e": "#6b3e75"}
## 노멀·레어·에픽·유니크의 발광 색 (진한 색, 밝은 색). 노멀은 금속처럼 꺼진 색
const ACCENT: Array[Array] = [["#5c5164", "#917487"], ["#30e1b9", "#99e9e6"], ["#a884f3", "#fef8e5"], ["#f6ce50", "#fef8e5"]]
const RAINBOW_BAND_TEAL := 10.0
const RAINBOW_BAND_METAL := 14.0

## 프레임 9칸: 모서리 크기와 안쪽 판 시작 위치, 아래 띠 두께, 프레임 위로 튀어나오는 장식 높이, 둥근 모서리 반지름
const CORNER_X := 70
const CORNER_Y := 84
const PAD := 19
const PAD_BOTTOM := 23
const CREST_RISE := 8
const FRAME_RADIUS := 8
const FRAME_INSET := 2
## 설명 최대 줄 수
const DESC_MAX_LINES := 2
## 카드 폭: 글자 작은 화면(PC) · 글자 큰 화면(폰). 예전 196 · 262의 약 73%
const CARD_W_SMALL := 144
const CARD_W_LARGE := 190
## 프레임 그림이 찌그러지지 않는 최소 높이 (9칸 나누기의 위아래 모서리)
const FRAME_MIN_H := 169
## 아이콘 한 변 (게임 그림과 같은 1배)
const ICON_SIZE := 48

## 글자 큰 화면(폰)을 쓰는 최소 논리 크기: 카드 3장에 이름 24px 두 줄, 설명 24px 두 줄이 들어가야 한다
const LARGE_MIN := Vector2(700, 340)

static var _materials := {}
static var _rainbow_material: ShaderMaterial

var choice: Dictionary
var layout: Dictionary
var home := Vector2.ZERO

var _content: Control
var _flash: Panel
var _ring := StyleBoxFlat.new()
var _flash_strength := 0.0
var _boost_bands := 0


## 등급 색 바꾸기 재질 (등급마다 하나를 함께 쓴다)
static func grade_material(grade: int) -> ShaderMaterial:
	if _materials.has(grade):
		return _materials[grade]
	var map := {}
	if grade == Upgrades.LEGENDARY:
		map = GOLD.duplicate()
		map["#a5b29d"] = RAINBOW_BAND_METAL
		for c in TEAL_LIKE:
			map[c] = RAINBOW_BAND_TEAL
		map[TEAL_LIGHT] = RAINBOW_BAND_TEAL
	else:
		if grade == Upgrades.UNIQUE:
			map = GOLD.duplicate()
		elif grade == Upgrades.EPIC:
			map = EPIC_TINT.duplicate()
		for c in TEAL_LIKE:
			map[c] = ACCENT[grade][0]
		map[TEAL_LIGHT] = ACCENT[grade][1]
	var src := PackedVector3Array()
	var dst := PackedColorArray()
	for key in map:
		var from := Color(key)
		src.append(Vector3(from.r, from.g, from.b))
		var to = map[key]
		dst.append(Color(to / 100.0, 0.0, 0.0, 0.0) if to is float else Color(to))
	var mat := ShaderMaterial.new()
	mat.shader = GRADE_SHADER
	mat.set_shader_parameter("color_count", src.size())
	mat.set_shader_parameter("src", src)
	mat.set_shader_parameter("dst", dst)
	_materials[grade] = mat
	return mat


## 레전드리 이름과 바깥 빛: 모든 픽셀이 무지개로 흐른다
static func rainbow_material() -> ShaderMaterial:
	if _rainbow_material == null:
		_rainbow_material = ShaderMaterial.new()
		_rainbow_material.shader = GRADE_SHADER
		_rainbow_material.set_shader_parameter("rainbow_all", true)
	return _rainbow_material


static func tex(file: String) -> Texture2D:
	return load(ART + file + ".png")


## 공백에서만 줄을 바꾼다 (Label 자동 줄바꿈은 한글 낱자 사이에서도 끊겨 줄 수를 믿을 수 없다)
static func wrap_text(text: String, font_size: int, width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var cur := ""
	for word in text.split(" "):
		var joined := word if cur.is_empty() else cur + " " + word
		if cur.is_empty() or FONT.get_string_size(joined, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			cur = joined
		else:
			lines.append(cur)
			cur = word
	lines.append(cur)
	return lines


## 설명 줄: 긴 문구가 DESC_MAX_LINES를 넘으면 짧은 문구를 쓴다
static func desc_lines(card: Dictionary, font_size: int, width: float) -> PackedStringArray:
	var lines := wrap_text(Upgrades.describe(card["id"], card["grade"]), font_size, width)
	if lines.size() > DESC_MAX_LINES:
		lines = wrap_text(Upgrades.describe(card["id"], card["grade"], true), font_size, width)
	return lines


## 논리 화면과 보여 줄 카드에 맞춘 크기표. 카드 높이는 가장 긴 내용에 맞춘다 (설명 아래 빈 공간이 없게).
## 화면이 낮으면 위 여백과 버튼을 차례로 줄인다.
static func layout_for(view: Vector2, cards: Array) -> Dictionary:
	var large := view.x >= LARGE_MIN.x and view.y >= LARGE_MIN.y
	var count := maxi(cards.size(), Balance.UPGRADE_CHOICE_COUNT)
	var gap := 12 if large else 10
	var w := mini(CARD_W_LARGE if large else CARD_W_SMALL, (int(view.x) - 2 * 4 - (count - 1) * gap) / count)
	var inner := float(w - 2 * PAD - 2)
	var text_size := 24 if large else 12
	var name_lines := 1
	var desc_count := 1
	for c in cards:
		name_lines = maxi(name_lines, wrap_text(Upgrades.display_name(c["id"]), text_size, inner).size())
		desc_count = maxi(desc_count, desc_lines(c, text_size, inner).size())
	var ped := "ped_phone" if large else "ped_pc"
	var lay := {
		"large": large, "w": w, "gap": gap, "inner": inner, "name_size": text_size, "desc_size": text_size, "tag_size": 12,
		"btn_size": text_size, "tag_h": 21, "dot": 6 if large else 5, "glow_u": 2 if large else 1,
		"name_h": name_lines * (text_size + 1), "ped": ped, "ped_h": tex(ped).get_height(),
	}
	for tight in 2:
		lay["ped_top"] = 20 if tight == 0 else 14
		lay["btn_gap"] = (6 if large else 5) if tight == 0 else 3
		var btn_h := (36 if large else 26) if tight == 0 else (32 if large else 25)
		lay["btn"] = Vector2i(220 if large else 150, btn_h)
		var body: int = lay["ped_top"] + lay["ped_h"] + lay["tag_h"] / 2 + 3 + lay["name_h"] + 2 + desc_count * (text_size + 1) + 4 + lay["dot"] + 3 + PAD_BOTTOM
		lay["h"] = maxi(body, FRAME_MIN_H)
		lay["total"] = CREST_RISE + lay["h"] + lay["btn_gap"] + btn_h
		if lay["total"] + 16 <= view.y:
			break
	return lay


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	MenuPanel.add_press_feel(self)
	# 눌린 동안 카드 전체가 밝아진다 (add_press_feel은 위치만 내림: self_modulate는 자식에 안 먹음)
	button_down.connect(func() -> void: modulate = Juice.BUTTON_PRESS_MODULATE)
	button_up.connect(func() -> void: modulate = Color.WHITE)
	_ring.draw_center = false
	_ring.anti_aliasing = false
	_ring.set_border_width_all(1)


## 카드 내용을 만든다 (다시 뽑거나 화면 크기가 바뀌면 다시 부른다). next_level: 이 카드를 고르면 채워질 단계 점 수.
func setup(card: Dictionary, next_level: int, lay: Dictionary) -> void:
	choice = card
	layout = lay
	var grade: int = card["grade"]
	var w: int = lay["w"]
	var h: int = lay["h"]
	for child in get_children():
		remove_child(child)
		child.queue_free()
	size = Vector2(w, h)
	pivot_offset = Vector2(w, h) / 2.0
	material = rainbow_material() if grade == Upgrades.LEGENDARY else null
	var mat := grade_material(grade)

	var frame := NinePatchRect.new()
	frame.texture = tex("frame")
	frame.patch_margin_left = CORNER_X
	frame.patch_margin_right = CORNER_X
	frame.patch_margin_top = CORNER_Y
	frame.patch_margin_bottom = CORNER_Y
	frame.size = size
	_add_part(frame, mat)
	_add_shade(w, h)
	if grade >= Upgrades.UNIQUE:
		_add_corners(w, h, grade == Upgrades.LEGENDARY, mat)
	var cx := w / 2
	var crest := tex("crest")
	if grade >= Upgrades.EPIC:
		var wing := "wing_b" if grade >= Upgrades.UNIQUE else "wing_s"
		var left := tex(wing + "_l")
		var right := tex(wing + "_r")
		_add_sprite(left, Vector2(cx - crest.get_width() / 2 - left.get_width() + 3, 2 - CREST_RISE), mat)
		_add_sprite(right, Vector2(cx + crest.get_width() / 2 - 3, 2 - CREST_RISE), mat)
	_add_sprite(crest, Vector2(cx - crest.get_width() / 2, -CREST_RISE), mat)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = size
	add_child(_content)
	_add_body(card, next_level, lay, mat)

	_flash = Panel.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var white := StyleBoxFlat.new()
	white.bg_color = Color.WHITE
	white.anti_aliasing = false
	white.set_corner_radius_all(FRAME_RADIUS)
	_flash.add_theme_stylebox_override("panel", white)
	_flash.position = _frame_rect().position
	_flash.size = _frame_rect().size
	_flash.modulate.a = 0.0
	add_child(_flash)
	queue_redraw()


func _add_part(part: Control, mat: ShaderMaterial, parent: Control = self) -> void:
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.material = mat
	parent.add_child(part)


func _add_sprite(texture: Texture2D, pos: Vector2, mat: ShaderMaterial, scale_by: int = 1, parent: Control = self) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = texture.get_size() * scale_by
	rect.position = pos
	_add_part(rect, mat, parent)
	return rect


## 입체감: 안쪽 판 위쪽은 살짝 밝게, 아래쪽은 어둡게 (계단 띠)
func _add_shade(w: int, h: int) -> void:
	var shade := Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func() -> void:
		var iw := float(w - 2 * PAD)
		for i in 3:
			shade.draw_rect(Rect2(PAD, PAD + i * 3, iw, 3), Color(INK, [26, 16, 8][i] / 255.0))
			shade.draw_rect(Rect2(PAD, h - PAD_BOTTOM - (i + 1) * 4, iw, 4), Color(0.03, 0.02, 0.05, [70, 44, 22][i] / 255.0)))
	add_child(shade)


func _add_corners(w: int, h: int, bottom: bool, mat: ShaderMaterial) -> void:
	var corner := tex("corner")
	var cw := corner.get_width()
	var ch := corner.get_height()
	_add_sprite(corner, Vector2(2, 2), mat)
	_add_sprite(corner, Vector2(w - cw - 2, 2), mat).flip_h = true
	if bottom:
		_add_sprite(corner, Vector2(2, h - ch - 2), mat).flip_v = true
		var last := _add_sprite(corner, Vector2(w - cw - 2, h - ch - 2), mat)
		last.flip_h = true
		last.flip_v = true


## 앞면 내용: 받침 + 아이콘, 종류 표, 이름, 설명, 단계 점
func _add_body(card: Dictionary, next_level: int, lay: Dictionary, mat: ShaderMaterial) -> void:
	var w: int = lay["w"]
	var h: int = lay["h"]
	var cx := w / 2
	var grade: int = card["grade"]
	var ped := tex(str(lay["ped"]))
	var py: int = lay["ped_top"]
	_add_sprite(ped, Vector2(cx - ped.get_width() / 2, py), mat, 1, _content)
	_add_sprite(tex("icons/" + str(card["id"])), Vector2(cx - ICON_SIZE / 2, py + (int(lay["ped_h"]) - ICON_SIZE) / 2), null, 1, _content)
	# 알약 꼬리표: 받침 아래쪽에 걸침. 양끝은 그대로 두고 가운데 한 줄만 늘린다
	var kind := Upgrades.kind_of(card["id"])
	var tag_size: int = lay["tag_size"]
	var tag_h: int = lay["tag_h"]
	var tag_w := maxi(int(FONT.get_string_size(kind, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x) + 30, tex("pill").get_width())
	var y: int = py + lay["ped_h"] - tag_h / 2
	var pill := NinePatchRect.new()
	var pill_art := tex("pill")
	pill.texture = pill_art
	pill.patch_margin_left = pill_art.get_width() / 2
	pill.patch_margin_right = pill_art.get_width() - pill.patch_margin_left - 1
	pill.patch_margin_top = pill_art.get_height() / 2
	pill.patch_margin_bottom = pill_art.get_height() - pill.patch_margin_top - 1
	pill.position = Vector2(cx - tag_w / 2, y)
	pill.size = Vector2(tag_w, tag_h)
	_add_part(pill, mat, _content)
	_add_line(kind, y + (tag_h - tag_size) / 2, tag_size, INK)
	y += tag_h + 3
	var name_size: int = lay["name_size"]
	var name_y := y
	for line in wrap_text(Upgrades.display_name(card["id"]), name_size, lay["inner"]):
		var label := _add_line(line, name_y, name_size, NAME_COLORS[grade])
		if grade == Upgrades.LEGENDARY:
			label.material = rainbow_material()
		name_y += name_size + 1
	y += lay["name_h"] + 2
	var desc_size: int = lay["desc_size"]
	for line in desc_lines(card, desc_size, lay["inner"]):
		_add_line(line, y, desc_size, DESC_COLOR)
		y += desc_size + 1
	_add_dots(Upgrades.max_stage(card["id"]), next_level, grade, w, h, lay["dot"])


## 글자 한 줄 (카드 폭 가운데 정렬). 글꼴 줄 높이가 글자 크기보다 커서 그만큼 위로 올린다
func _add_line(text: String, y: int, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(0, y - int(FONT.get_height(font_size) - font_size) / 2)
	label.size.x = size.x
	_content.add_child(label)
	return label


## 단계 점: 프레임 바닥 위쪽 가운데. max_stage가 0이면(수리처럼 단계 없음) 그리지 않는다
func _add_dots(count: int, filled: int, grade: int, w: int, h: int, dot: int) -> void:
	if count <= 0:
		return
	var dots := Control.new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = Color("#f6ce50") if grade == Upgrades.LEGENDARY else NAME_COLORS[grade]
	dots.draw.connect(func() -> void:
		var total := count * dot + (count - 1) * 2
		var x0 := w / 2 - total / 2
		var y0 := h - PAD_BOTTOM - dot - 3
		for i in count:
			var x := x0 + i * (dot + 2)
			dots.draw_rect(Rect2(x, y0, dot, dot), Color("#5c5164"))
			dots.draw_rect(Rect2(x + 1, y0 + 1, dot - 2, dot - 2), color if i < filled else Color("#14111c")))
	_content.add_child(dots)


## 카드 윤곽을 따라 도는 계단 빛 (자식보다 먼저 그려져 프레임 뒤에 깔린다)
func _draw() -> void:
	if layout.is_empty():
		return
	var grade: int = choice["grade"]
	var bands: Array = []
	for a in GLOW_ALPHA[grade]:
		for i in int(layout["glow_u"]):
			bands.append(a / 255.0)
	for i in _boost_bands:
		bands.append(GLOW_BOOST_ALPHA)
	var base_color := GLOW_COLORS[grade]
	if is_hovered() and not disabled and mouse_filter == Control.MOUSE_FILTER_STOP:
		for i in HOVER_BANDS:
			_band(i, Color(INK, HOVER_ALPHA))
	for i in bands.size():
		_band(i, Color(base_color, bands[i]))


func _band(i: int, color: Color) -> void:
	_ring.border_color = color
	_ring.set_corner_radius_all(FRAME_RADIUS + i + 1)
	draw_style_box(_ring, _frame_rect().grow(i + 1))


## 프레임 그림에서 실제로 보이는 부분 (그림 둘레에 투명 여백이 있다)
func _frame_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-FRAME_INSET)


## 등장 연출: ct = 이 카드의 경과 시간(초). 내려옴(뒷면) → (레전드리는 빛이 모이는 동안 대기) → 뒤집힘 → 앞면 번쩍.
func set_reveal(ct: float, drop_distance: float, wait := 0.0) -> void:
	visible = ct >= 0.0
	if ct < 0.0:
		return
	var grade: int = choice["grade"]
	var flip_start := Juice.CARD_DROP_TIME + wait
	var flash_start := flip_start + Juice.CARD_FLIP_TIME
	position = home
	scale.x = 1.0
	_content.visible = ct >= flip_start + Juice.CARD_FLIP_TIME * 0.5
	var flash := 0.0
	var boost := 0
	if ct < Juice.CARD_DROP_TIME:
		var r := ct / Juice.CARD_DROP_TIME
		position.y -= roundf(drop_distance * (1.0 - r) * (1.0 - r))  # 감속하며 내려옴
	elif ct < flip_start:
		flash = 0.5 * (ct - Juice.CARD_DROP_TIME) / wait  # 빛이 모이는 동안 카드가 점점 밝아진다
	elif ct < flash_start:
		scale.x = maxf(absf(1.0 - 2.0 * (ct - flip_start) / Juice.CARD_FLIP_TIME), 0.04)  # 폭이 줄었다 늘어남
	else:
		var k := clampf(1.0 - (ct - flash_start) / Juice.CARD_FLASH_TIME, 0.0, 1.0)
		flash = Juice.CARD_FLASH_STRENGTH[grade] * k
		boost = int(Juice.CARD_FLASH_RING[grade] * k) * int(layout["glow_u"])
	_set_flash(flash, boost)


func _set_flash(strength: float, boost: int) -> void:
	_flash.modulate.a = strength
	if boost != _boost_bands:
		_boost_bands = boost
		queue_redraw()


## 연출을 끝낸 모습으로 둔다
func settle() -> void:
	visible = true
	position = home
	scale.x = 1.0
	modulate = Color.WHITE
	_content.visible = true
	_set_flash(0.0, 0)


## 얼마나 번쩍이는지 (테스트·연출 확인용)
func flash_strength() -> float:
	return _flash.modulate.a


## 골랐을 때: 고른 카드는 강하게 번쩍, 나머지는 사라진다
func play_pick(picked: bool) -> void:
	var tween := create_tween()
	if picked:
		_set_flash(Juice.CARD_PICK_FLASH, Juice.CARD_PICK_RING * int(layout["glow_u"]))
		tween.tween_method(func(k: float) -> void: _set_flash(Juice.CARD_PICK_FLASH * k, int(Juice.CARD_PICK_RING * k) * int(layout["glow_u"])), 1.0, 0.0, Juice.CARD_PICK_TIME)
	else:
		tween.tween_property(self, "modulate:a", 0.0, Juice.CARD_PICK_TIME * 0.7)
