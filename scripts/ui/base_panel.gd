class_name BasePanel
extends Control
## 기지 건물 화면: 연구소(업그레이드 카드), 격납고(전투기·능력치), 광물 창고, 전시관(도감).
## open(kind)로 내용을 새로 만들어 보여 주고, 닫기 버튼이나 Esc로 닫는다.
## 규칙은 BaseUpgrades·Hangar·Discovery, 저장은 SaveData에 있고 여기서는 보여 주기만 한다.
## 기지 화면 기준(1280x720)에 맞춰 글자는 픽셀 글꼴 3배(36px), 아이콘·테두리도 3배로 그려 픽셀 크기를 통일한다.

signal closed
## 연구소에서 업그레이드를 샀을 때
signal bought(id: String)

const COLOR_BG := Color(0.03, 0.03, 0.08, 0.95)
const COLOR_CARD := Color(0.08, 0.09, 0.16, 1.0)
const COLOR_BORDER := Color("#4fd1ff")
const COLOR_TITLE := Color("#ffd34f")
const COLOR_TEXT := Color("#c8cde0")
const COLOR_DIM := Color("#8a90a8")
const COLOR_MAX := Color("#7cf0ff")
const COLOR_BAR := Color("#4fd1ff")
const COLOR_BAR_BG := Color("#2a2a40")
## 광물이 모자란 카드의 흐림 정도
const DIM_ALPHA := 0.45
## 그림 1픽셀 = 화면 P픽셀 (기지 화면과 같음), 글자 크기
const P := BaseLayout.PIXEL
const FONT := BaseLayout.FONT_SIZE

var save: SaveData
## 지금 열린 화면 ("research", "hangar", "storage", "museum", 닫혀 있으면 "")
var kind := ""
## 연구소: 업그레이드 id → 구매 버튼 / 카드 (테스트·갱신용)
var buy_buttons: Dictionary = {}
var cards: Dictionary = {}
var close_button: Button

var _panel: PanelContainer
var _content: VBoxContainer
## 내용을 만들 때의 화면 방향 (휴대폰을 돌리면 다시 만든다)
var _built_portrait := false


## 능력치 막대 (격납고)
class StatBar extends Control:
	var ratio := 0.0

	func _draw() -> void:
		var p := BasePanel.P
		var h := p * 4
		var y := floorf((size.y - h) / 2.0 / p) * p
		draw_rect(Rect2(Vector2(0, y), Vector2(size.x, h)), BasePanel.COLOR_BAR_BG)
		draw_rect(Rect2(Vector2(0, y), Vector2(floorf(size.x * clampf(ratio, 0.0, 1.0) / p) * p, h)), BasePanel.COLOR_BAR)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 열려 있으면 뒤쪽 기지를 누를 수 없다
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(COLOR_BG, COLOR_BORDER, P * 6))
	center.add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", P * 4)
	_panel.add_child(_content)
	resized.connect(_on_resized)
	hide()


static func _style(bg: Color, border: Color, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(P)
	s.set_content_margin_all(margin)
	return s


static func _label(text: String, color: Color = COLOR_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", FONT)
	return l


## 픽셀 아트 아이콘을 P배(정수)로. box는 그림 픽셀 단위 칸 크기 (가운데 정렬).
static func _icon(tex: Texture2D, tint: Color = Color.WHITE, box: Vector2 = Vector2(10, 10)) -> TextureRect:
	var t := TextureRect.new()
	t.modulate = tint
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = box * P
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# STRETCH_KEEP_CENTERED는 원래 크기로 그리므로, P배로 키운 텍스처를 쓴다
	t.texture = _scaled(tex)
	return t


static var _scaled_cache := {}


## 텍스처를 P배 nearest로 키운 것 (아이콘을 정수 배율로만 보여 주려고)
static func _scaled(tex: Texture2D) -> Texture2D:
	if not _scaled_cache.has(tex):
		var img := tex.get_image()
		img.resize(img.get_width() * P, img.get_height() * P, Image.INTERPOLATE_NEAREST)
		_scaled_cache[tex] = ImageTexture.create_from_image(img)
	return _scaled_cache[tex]


func _portrait() -> bool:
	return BaseLayout.is_portrait(size)


## 열린 채로 휴대폰을 돌리면 그 방향에 맞는 배치(열 수, 카드 너비)로 다시 만든다
func _on_resized() -> void:
	if visible and _portrait() != _built_portrait:
		_rebuild()


## 건물 화면을 연다.
func open(new_kind: String) -> void:
	kind = new_kind
	_rebuild()
	show()
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	kind = ""
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		Sfx.play_click()
		close()
		get_viewport().set_input_as_handled()


## 지금 화면 내용을 다시 만든다 (구매 후 갱신 포함).
func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	buy_buttons.clear()
	cards.clear()
	_built_portrait = _portrait()
	var header := HBoxContainer.new()
	var title := _label(BaseLayout.NAMES.get(kind, ""), COLOR_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("보유 광물 %s" % Hud.thousands(save.credits), COLOR_TITLE))
	close_button = Button.new()
	close_button.text = "닫기"
	close_button.add_theme_font_size_override("font_size", FONT)
	close_button.custom_minimum_size = Vector2(P * 40, P * 18)
	close_button.pressed.connect(func() -> void:
		Sfx.play_click()
		close())
	header.add_child(close_button)
	_content.add_child(header)
	match kind:
		"research":
			_build_research()
		"hangar":
			_build_hangar()
		"storage":
			_build_storage()
		"museum":
			_build_museum()


# ── 연구소 ────────────────────────────────────────

func _build_research() -> void:
	var grid := GridContainer.new()
	grid.columns = 1 if _portrait() else 2
	grid.add_theme_constant_override("h_separation", P * 4)
	grid.add_theme_constant_override("v_separation", P * 3)
	for u in Balance.BASE_UPGRADES:
		grid.add_child(_research_card(u["id"]))
	_content.add_child(grid)


func _research_card(id: String) -> PanelContainer:
	var lv := save.level_of(id)
	var top := lv >= BaseUpgrades.max_level(id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(P * 210 if _portrait() else P * 186, 0)
	card.add_theme_stylebox_override("panel", _style(COLOR_CARD, COLOR_MAX if top else Color(COLOR_BORDER, 0.4), P * 3))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", P * 3)
	head.add_child(_icon(PixelArt.upgrade_icon(id)))
	head.add_child(_label(BaseUpgrades.info(id)["name"]))
	var pips := _label(BaseUpgrades.pips(id, lv), COLOR_MAX)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(pips)
	box.add_child(head)
	box.add_child(_label(BaseUpgrades.change_text(id, lv), COLOR_DIM))
	var button := Button.new()
	button.add_theme_font_size_override("font_size", FONT)
	button.custom_minimum_size = Vector2(0, P * 16)
	if top:
		button.text = "MAX"
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", COLOR_MAX)
	else:
		button.text = "강화  %s" % Hud.thousands(BaseUpgrades.cost(id, lv))
		button.disabled = not BaseUpgrades.can_buy(save, id)
		if button.disabled:
			card.modulate = Color(1, 1, 1, DIM_ALPHA)  # 광물이 모자라면 흐리게
	button.pressed.connect(_buy.bind(id))
	box.add_child(button)
	buy_buttons[id] = button
	cards[id] = card
	return card


func _buy(id: String) -> void:
	if not BaseUpgrades.buy(save, id):
		return
	save.save_file()
	Sfx.play_pickup(2)
	bought.emit(id)
	_rebuild()
	# 산 카드에 포커스를 남긴다 (막혔으면 닫기 버튼으로)
	var b: Button = buy_buttons[id]
	if b.disabled:
		close_button.grab_focus()
	else:
		b.grab_focus()


# ── 격납고 ────────────────────────────────────────

func _build_hangar() -> void:
	var body: BoxContainer = VBoxContainer.new() if _portrait() else HBoxContainer.new()
	body.add_theme_constant_override("separation", P * 8)
	var slots := GridContainer.new()
	slots.columns = 2 if _portrait() else 1
	slots.add_theme_constant_override("h_separation", P * 3)
	slots.add_theme_constant_override("v_separation", P * 3)
	for i in Hangar.slots().size():
		slots.add_child(_fighter_slot(Hangar.slots()[i], i == 0))
	body.add_child(slots)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	stats.add_child(_label("지금 우주선 능력치 (업그레이드 반영)", COLOR_DIM))
	for s in Hangar.stats(save.upgrades):
		var row := HBoxContainer.new()
		var name_label := _label(s["name"])
		name_label.custom_minimum_size = Vector2(P * 56, 0)
		row.add_child(name_label)
		var bar := StatBar.new()
		bar.ratio = s["ratio"]
		bar.custom_minimum_size = Vector2(P * (70 if _portrait() else 90), P * 12)
		row.add_child(bar)
		var value := _label(s["value"], COLOR_TITLE)
		value.custom_minimum_size = Vector2(P * 62, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		stats.add_child(row)
	body.add_child(stats)
	_content.add_child(body)


## 전투기 칸: 있는 전투기는 그림·이름·스타일, 없는 칸은 자물쇠와 "곧 추가"
func _fighter_slot(fighter: Dictionary, selected: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(P * 110, P * 30)
	var locked := fighter.has("locked")
	card.add_theme_stylebox_override("panel", _style(COLOR_CARD, COLOR_TITLE if selected else Color(COLOR_BORDER, 0.3), P * 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", P * 3)
	card.add_child(row)
	if locked:
		row.add_child(_icon(PixelArt.lock()))
		row.add_child(_label("곧 추가", COLOR_DIM))
		card.modulate = Color(1, 1, 1, 0.7)
		return card
	row.add_child(_icon(PixelArt.ship()))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.add_child(_label(fighter["name"], COLOR_TITLE if selected else COLOR_TEXT))
	info.add_child(_label("%s · %s" % [fighter["style"], fighter["weapon"]], COLOR_DIM))
	row.add_child(info)
	return card


# ── 광물 창고 ─────────────────────────────────────

func _build_storage() -> void:
	_content.add_child(_label("보유 광물 총가치  %s" % Hud.thousands(save.credits), COLOR_TITLE))
	_content.add_child(_label("지금까지 기지로 가져온 광물", COLOR_DIM))
	var grid := GridContainer.new()
	grid.columns = 2 if _portrait() else 4
	grid.add_theme_constant_override("h_separation", P * 10)
	grid.add_theme_constant_override("v_separation", P * 2)
	for i in Balance.MINERAL_GRADES.size():
		var row := HBoxContainer.new()
		row.add_child(_icon(PixelArt.mineral(i)))
		row.add_child(_label("%s %s개" % [Balance.MINERAL_GRADES[i]["name"], Hud.thousands(save.hauled[i])]))
		grid.add_child(row)
	_content.add_child(grid)


# ── 전시관 (도감) ─────────────────────────────────

func _build_museum() -> void:
	_content.add_child(_label("발견 %d / %d" % [save.seen.size(), Discovery.ENTRIES.size()], COLOR_DIM))
	var grid := GridContainer.new()
	grid.columns = 3 if _portrait() else 4
	grid.add_theme_constant_override("h_separation", P * 3)
	grid.add_theme_constant_override("v_separation", P * 3)
	for e in Discovery.ENTRIES:
		var found: bool = save.seen.has(e["id"])
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(P * (74 if _portrait() else 90), 0)
		cell.add_theme_stylebox_override("panel", _style(COLOR_CARD, Color(COLOR_BORDER, 0.35 if found else 0.12), P * 2))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var icon := _icon(PixelArt.discovery_icon(e["id"]), Color.WHITE if found else Color.BLACK, Vector2(30, 30))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		box.add_child(_label(e["name"] if found else "?", COLOR_TEXT if found else COLOR_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(box)
		grid.add_child(cell)
	_content.add_child(grid)
