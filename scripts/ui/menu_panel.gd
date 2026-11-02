class_name MenuPanel
extends Control
## 화면 가운데 메뉴 (일시 정지, 게임 오버 등). 제목, 설명, 버튼 목록을 코드로 만든다.
## 첫 버튼에 포커스를 주므로 Enter/Space로 바로 고를 수 있다.

signal chosen(index: int)

const COLOR_BG := Color(0.03, 0.03, 0.08, 0.92)
const COLOR_BORDER := Color("#4fd1ff")
const COLOR_TITLE := Color("#ffd34f")
const COLOR_TEXT := Color("#c8cde0")

var _box: VBoxContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
## 메뉴를 열 때마다 1씩 늘린다. 이전 메뉴의 지연 타이머가 새 메뉴를 건드리지 않게 한다.
var _generation := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 메뉴가 떠 있으면 뒤쪽 클릭을 막는다
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)
	_title = _label(COLOR_TITLE, 24)
	_body = _label(COLOR_TEXT, 12)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	_box.add_child(_title)
	_box.add_child(_body)
	_box.add_child(_buttons)
	hide()


func _label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


## 메뉴를 보여 준다. options의 순서대로 버튼을 만들고, 누르면 chosen(인덱스)를 보낸다.
## input_delay초 동안은 버튼을 눌러도 반응하지 않는다 (게임 중 갑자기 뜬 메뉴를 실수로 누르지 않게).
func show_menu(title: String, body: String, options: PackedStringArray, input_delay: float = 0.0) -> void:
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	_generation += 1
	var generation := _generation
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.custom_minimum_size = Vector2(180, 24)
		button.disabled = input_delay > 0.0
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_pressed.bind(i))
		_buttons.add_child(button)
	show()
	if input_delay > 0.0:
		await get_tree().create_timer(input_delay, true, false, true).timeout
		if generation != _generation:
			return  # 그사이 다른 메뉴가 열렸다
		for b in buttons():
			b.disabled = false
	if visible and not buttons().is_empty():
		buttons()[0].grab_focus()


## 메뉴의 버튼 목록 (테스트용)
func buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in _buttons.get_children():
		if not child.is_queued_for_deletion():
			result.append(child)
	return result


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


## 번호로 고르기 (키보드 1, 2, 3). 버튼이 막혀 있으면 무시한다.
func choose(index: int) -> void:
	var list := buttons()
	if visible and index >= 0 and index < list.size() and not list[index].disabled:
		_on_pressed(index)


func _on_pressed(index: int) -> void:
	hide()
	chosen.emit(index)
