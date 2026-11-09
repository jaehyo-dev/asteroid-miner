class_name MenuPanel
extends Control
## 화면 가운데 메뉴 (일시 정지, 게임 오버 등). 제목, 설명, 버튼 목록을 코드로 만든다.
## 첫 버튼에 포커스를 주므로 Enter/Space로 바로 고를 수 있다.

signal chosen(index: int)
## 제목을 눌렀을 때 (일시 정지 화면 제목 5번 = 숨은 FPS 표시)
signal title_tapped

const COLOR_BG := Color(0.03, 0.03, 0.08, 0.92)
const COLOR_BORDER := Color("#4fd1ff")
const COLOR_TITLE := Color("#ffd34f")
const COLOR_TEXT := Color("#c8cde0")
## 메뉴 뒤를 덮는 검정의 진하기: 보통, 일시 정지
const DIM_NORMAL := 0.4
const DIM_PAUSE := 0.7

## 글자·여백 배수 (기지 화면은 1280x720 기준이라 BaseLayout.UI_PIXEL). add_child 전에 정한다
var ui_scale := 1
var _dim: ColorRect
var _box: VBoxContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 메뉴가 떠 있으면 뒤쪽 클릭을 막는다
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, DIM_NORMAL)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(ui_scale)
	style.set_content_margin_all(12 * ui_scale)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8 * ui_scale)
	panel.add_child(_box)
	_title = _label(COLOR_TITLE, 24 * ui_scale)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			title_tapped.emit())
	_body = _label(COLOR_TEXT, 12 * ui_scale)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4 * ui_scale)
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


## 메뉴 뒤를 덮는 검정의 진하기를 정한다
func set_dim(alpha: float) -> void:
	_dim.color.a = alpha


## 메뉴를 보여 준다. options의 순서대로 버튼을 만들고, 누르면 chosen(인덱스)를 보낸다.
func show_menu(title: String, body: String, options: PackedStringArray) -> void:
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.custom_minimum_size = Vector2(180, 24) * ui_scale
		button.add_theme_font_size_override("font_size", 12 * ui_scale)
		button.pressed.connect(_on_pressed.bind(i))
		add_press_feel(button, Juice.BUTTON_PRESS_PX * ui_scale)
		_buttons.add_child(button)
	show()
	if not buttons().is_empty():
		buttons()[0].grab_focus()


## 버튼 눌림 연출: 누르는 동안 px만큼 아래로 내려가고 밝아진다 (크기는 그대로: 정수 배율 규칙)
static func add_press_feel(button: BaseButton, px: int = Juice.BUTTON_PRESS_PX) -> void:
	button.button_down.connect(_set_pressed_look.bind(button, true, px))
	button.button_up.connect(_set_pressed_look.bind(button, false, px))


static func _set_pressed_look(button: BaseButton, down: bool, px: int) -> void:
	if down == button.has_meta("pressed_px"):
		return  # 같은 상태가 두 번 오면 위치가 어긋나지 않게 무시
	button.position.y += px if down else -px
	button.self_modulate = Juice.BUTTON_PRESS_MODULATE if down else Color.WHITE
	if down:
		button.set_meta("pressed_px", true)
	else:
		button.remove_meta("pressed_px")


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


func _on_pressed(index: int) -> void:
	hide()
	chosen.emit(index)
