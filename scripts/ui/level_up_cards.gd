class_name LevelUpCards
extends Control
## 레벨업 카드 화면: 카드 3장 + 다시 뽑기 버튼 + 등장 연출.
## 다 펼쳐지기 전에 누르면 건너뛰기만 하고, 선택은 되지 않는다 (실수 선택 방지).

signal chosen(index: int)
signal reroll_pressed

enum State { CLOSED, REVEAL, GUARD, READY, PICKING }

const DIM_COLOR := Color(8.0 / 255.0, 6.0 / 255.0, 14.0 / 255.0, 170.0 / 255.0)
const LABEL_INK := Color("#fef8e5")
const COUNT_COLOR := Color("#f6ce50")
const OFF_COLOR := Color("#5c5164")
const OFF_MODULATE := Color(0.55, 0.55, 0.55)

var state := State.CLOSED
var cards: Array[LevelCard] = []
var reroll_button: Button
var rerolls_left := 0

var _dim: ColorRect
var _choices: Array = []
var _levels: Dictionary = {}
var _t := 0.0
var _guard := 0.0
var _picked := -1
var _is_reroll := false
var _sounded: Array[bool] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 떠 있는 동안 뒤쪽 입력을 막고, 연출 중 누름은 건너뛰기로 받는다
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reroll_button = Button.new()
	reroll_button.flat = true
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.pressed.connect(reroll)
	MenuPanel.add_press_feel(reroll_button)
	add_child(reroll_button)
	resized.connect(_apply_layout)
	hide()
	set_process(false)


## 카드 화면을 연다. is_reroll이면 어둡게 하는 단계 없이 짧은 연출만 한다.
func show_cards(choices: Array, levels: Dictionary, rerolls: int, is_reroll: bool = false) -> void:
	_choices = choices
	_levels = levels
	rerolls_left = rerolls
	_is_reroll = is_reroll
	_t = 0.0
	_guard = 0.0
	_picked = -1
	_sounded.clear()
	_sounded.resize(choices.size())
	_sounded.fill(false)
	for c in cards:
		remove_child(c)
		c.queue_free()
	cards.clear()
	for i in choices.size():
		var card := LevelCard.new()
		card.pressed.connect(choose.bind(i))
		add_child(card)
		cards.append(card)
	state = State.REVEAL
	show()
	set_process(true)
	_apply_layout()
	reroll_button.visible = is_reroll
	_set_input_open(false)
	_dim.modulate.a = 1.0 if is_reroll else 0.0
	_step_reveal()


func close() -> void:
	state = State.CLOSED
	set_process(false)
	hide()


func is_revealing() -> bool:
	return state == State.REVEAL or state == State.GUARD


func _first_delay() -> float:
	return 0.0 if _is_reroll else Juice.CARD_FIRST_DELAY


func _stagger() -> float:
	return Juice.CARD_REROLL_STAGGER if _is_reroll else Juice.CARD_STAGGER


func _reveal_end() -> float:
	return _first_delay() + (cards.size() - 1) * _stagger() + Juice.CARD_DROP_TIME + Juice.CARD_FLIP_TIME + Juice.CARD_FLASH_TIME


func _process(delta: float) -> void:
	match state:
		State.REVEAL:
			_t += delta
			if _t >= _reveal_end():
				_finish_reveal()
			else:
				_step_reveal()
		State.GUARD:
			_guard -= delta
			if _guard <= 0.0:
				_open_input()


func _step_reveal() -> void:
	if not _is_reroll:
		_dim.modulate.a = minf(_t / Juice.CARD_DIM_TIME, 1.0)
	var distance := Juice.CARD_REROLL_DROP_DISTANCE if _is_reroll else Juice.CARD_DROP_DISTANCE
	for i in cards.size():
		var ct := _t - _first_delay() - i * _stagger()
		cards[i].set_reveal(ct, distance)
		if ct >= Juice.CARD_DROP_TIME + Juice.CARD_FLIP_TIME * 0.5:
			_play_show(i)


## 앞면이 보이는 순간 소리. 등급이 높을수록 크다
func _play_show(i: int) -> void:
	if not _sounded[i]:
		_sounded[i] = true
		Sfx.play("card_show", -1.0, 1.0, Juice.CARD_SHOW_DB[_choices[i]["grade"]])


func _finish_reveal() -> void:
	_dim.modulate.a = 1.0
	for c in cards:
		c.settle()
	reroll_button.visible = true
	_open_input()


func _open_input() -> void:
	state = State.READY
	_set_input_open(true)


func _set_input_open(open: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	for c in cards:
		c.mouse_filter = filter
		c.queue_redraw()
	reroll_button.mouse_filter = filter


## 연출 건너뛰기: 바로 다 펼치고, 소리는 가장 높은 등급 한 번만. 잠깐 동안은 연타가 선택으로 이어지지 않게 막는다.
func skip() -> void:
	if state != State.REVEAL:
		return
	var best := -1
	for i in cards.size():
		if not _sounded[i] and (best < 0 or _choices[i]["grade"] > _choices[best]["grade"]):
			best = i
	if best >= 0:
		_play_show(best)
	_sounded.fill(true)
	_finish_reveal()
	state = State.GUARD
	_guard = Juice.CARD_SKIP_GUARD
	_set_input_open(false)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		if state == State.REVEAL:
			skip()
		accept_event()


## 번호로 고르기 (카드 누름, 키보드 1·2·3). 다 펼쳐진 뒤에만 된다.
func choose(index: int) -> void:
	if state != State.READY or index < 0 or index >= cards.size():
		return
	state = State.PICKING
	_picked = index
	_set_input_open(false)
	Sfx.play("card_pick")
	for i in cards.size():
		cards[i].play_pick(i == index)
	var t := create_tween()
	t.tween_interval(Juice.CARD_PICK_TIME)
	t.tween_callback(func() -> void:
		close()
		chosen.emit(_picked))


## 다시 뽑기 (버튼, 키보드 R). 남은 횟수가 없거나 연출 중이면 무시한다.
func reroll() -> void:
	if state == State.READY and rerolls_left > 0:
		Sfx.play("click")
		reroll_pressed.emit()


## 화면 크기에 맞춰 카드와 버튼을 놓는다 (연출 중에도 다시 부를 수 있음)
func _apply_layout() -> void:
	if cards.is_empty():
		return
	var view := size
	var lay := LevelCard.layout_for(view, _choices)
	var w: int = lay["w"]
	var gap: int = lay["gap"]
	var x0 := (int(view.x) - cards.size() * w - (cards.size() - 1) * gap) / 2
	var top := (int(view.y) - int(lay["total"])) / 2 + LevelCard.CREST_RISE
	for i in cards.size():
		var id: String = _choices[i]["id"]
		cards[i].home = Vector2(x0 + i * (w + gap), top)
		cards[i].setup(_choices[i], int(_levels.get(id, 0)) + 1, lay)
		if state != State.REVEAL:
			cards[i].settle()
	_build_button(lay, top + int(lay["h"]) + int(lay["btn_gap"]), int(view.x))


## 다시 뽑기 버튼: 판 그림 + "다시 뽑기 N회". 0회면 어둡게 꺼진다
func _build_button(lay: Dictionary, y: int, view_w: int) -> void:
	for child in reroll_button.get_children():
		reroll_button.remove_child(child)
		child.queue_free()
	var btn: Vector2i = lay["btn"]
	var on := rerolls_left > 0
	reroll_button.disabled = not on
	reroll_button.size = btn
	reroll_button.position = Vector2((view_w - btn.x) / 2, y)
	var plate := NinePatchRect.new()
	var art := LevelCard.tex("button")
	plate.texture = art
	plate.patch_margin_left = art.get_width() / 2
	plate.patch_margin_right = art.get_width() / 2
	plate.patch_margin_top = art.get_height() / 2
	plate.patch_margin_bottom = art.get_height() / 2
	plate.size = btn
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not on:
		plate.material = LevelCard.grade_material(Upgrades.NORMAL)
		plate.modulate = OFF_MODULATE
	reroll_button.add_child(plate)
	var font_size: int = lay["tag_size"]
	var title := "다시 뽑기"
	var count := "%d회" % rerolls_left
	var font := LevelCard.FONT
	var title_w := int(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var count_w := int(font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var space := font_size / 2
	var x := (btn.x - title_w - space - count_w) / 2
	var label_y := (btn.y - int(font.get_height(font_size))) / 2
	_button_label(title, Vector2(x, label_y), font_size, LABEL_INK if on else OFF_COLOR)
	_button_label(count, Vector2(x + title_w + space, label_y), font_size, COUNT_COLOR if on else OFF_COLOR)


func _button_label(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	reroll_button.add_child(label)
