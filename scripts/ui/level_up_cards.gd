class_name LevelUpCards
extends Control
## 레벨업 카드 화면: 카드 3장 + 다시 뽑기·건너뛰기 버튼 + 등장 연출. 고를 카드가 없으면 건너뛰기 버튼만 크게 가운데.
## 다 펼쳐지기 전에 누르면 건너뛰기만 하고, 선택은 되지 않는다 (실수 선택 방지).

signal chosen(index: int)
signal reroll_pressed
signal skip_pressed

enum State { CLOSED, REVEAL, GUARD, READY, PICKING }

const DIM_COLOR := Color(8.0 / 255.0, 6.0 / 255.0, 14.0 / 255.0, 170.0 / 255.0)
const LABEL_INK := Color("#fef8e5")
const COUNT_COLOR := Color("#f6ce50")
const OFF_COLOR := Color("#5c5164")
const OFF_MODULATE := Color(0.55, 0.55, 0.55)

## 등급별로 뒤집힘 위에 쌓는 소리 (노멀은 뒤집힘만)
const CARD_GRADE_SOUND: Array[String] = ["card_normal", "card_normal", "card_epic", "card_unique", "card_legendary"]

var state := State.CLOSED
var cards: Array[LevelCard] = []
var reroll_button: Button
var rerolls_left := 0
## 건너뛰기 버튼과 보상(광물 가치)
var skip_button: Button
var skip_reward := 0

var _dim: ColorRect
var _choices: Array = []
var _levels: Dictionary = {}
var _t := 0.0
var _guard_until := 0
var _picked := -1
var _is_reroll := false
var _sounded: Array[bool] = []
## 등장 소리를 이미 튼 카드 (빛보다 CARD_SOUND_LEAD만큼 먼저)
var _voiced: Array[bool] = []
var _gathered: Array[bool] = []
## 카드별 등장 시작 시각과 빛이 모이는 시간
var _starts: Array[float] = []
var _fx := CardFx.new()
var _shake_left := 0.0
var _shake_power := 0.0
var _shake_rng := RandomNumberGenerator.new()
## 눌려 있는 손가락과, 카드가 뜨기 전부터 눌려 있던 손가락 (조이스틱 손가락 실수 선택 방지)
var _touches := {}
var _stale := {}
var _stale_released_at := -100000
var _shown_at := 0
## 슬로모션 중에 누른 건너뛰기를 카드가 뜰 때 적용한다
var _skip_queued := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 떠 있는 동안 뒤쪽 입력을 막고, 연출 중 누름은 건너뛰기로 받는다
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	for side: Side in [SIDE_LEFT, SIDE_TOP]:
		_dim.set_offset(side, -4.0)  # 흔들림으로 화면 끝이 비지 않게 조금 넓게
	for side: Side in [SIDE_RIGHT, SIDE_BOTTOM]:
		_dim.set_offset(side, 4.0)
	add_child(_fx)
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reroll_button = _new_button(reroll)
	skip_button = _new_button(skip_pick)
	add_child(_fx.front)
	_fx.front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_layout)
	hide()
	set_process(false)


## 카드 화면을 연다. is_reroll이면 어둡게 하는 단계 없이 짧은 연출만 한다.
func show_cards(choices: Array, levels: Dictionary, rerolls: int, is_reroll: bool = false, skip_value: int = 0) -> void:
	_choices = choices
	_levels = levels
	rerolls_left = rerolls
	skip_reward = skip_value
	_is_reroll = is_reroll
	_t = 0.0
	_picked = -1
	_sounded.clear()
	_sounded.resize(choices.size())
	_sounded.fill(false)
	_voiced.clear()
	_voiced.resize(choices.size())
	_voiced.fill(false)
	_gathered.clear()
	_gathered.resize(choices.size())
	_gathered.fill(false)
	var grades: Array[int] = []
	for c in choices:
		grades.append(c["grade"])
	_starts = card_starts(grades, is_reroll)
	_shake_left = 0.0
	position = Vector2.ZERO
	_fx.clear()
	for c in cards:
		remove_child(c)
		c.queue_free()
	cards.clear()
	for i in choices.size():
		var card := LevelCard.new()
		card.pressed.connect(_on_card_pressed.bind(i))
		add_child(card)
		cards.append(card)
	move_child(_fx.front, -1)
	_stale = _touches.duplicate()
	_shown_at = Time.get_ticks_msec()
	state = State.REVEAL
	show()
	set_process(true)
	_apply_layout()
	reroll_button.visible = is_reroll and not cards.is_empty()
	skip_button.visible = is_reroll or cards.is_empty()
	_set_input_open(false)
	_dim.modulate.a = 1.0 if is_reroll else 0.0
	_step_reveal()
	if _skip_queued and not is_reroll:
		skip()
	_skip_queued = false


func close() -> void:
	state = State.CLOSED
	set_process(false)
	position = Vector2.ZERO
	_fx.clear()
	hide()


## 카드가 뜨기 직전(레벨업 슬로모션)에 누르면, 뜨자마자 건너뛴다.
func queue_skip() -> void:
	_skip_queued = true


func is_revealing() -> bool:
	return state == State.REVEAL or state == State.GUARD


## 카드별 등장 시작 시각. 레전드리는 빛이 모이는 만큼 다음 카드가 늦게 나온다. (다시 뽑기는 짧게, 모으기 없음)
static func card_starts(grades: Array[int], is_reroll: bool) -> Array[float]:
	var result: Array[float] = []
	var t := 0.0 if is_reroll else Juice.CARD_FIRST_DELAY
	for g in grades:
		result.append(t)
		t += Juice.CARD_REROLL_STAGGER if is_reroll else Juice.CARD_STAGGER
		t += gather_time(g, is_reroll)
	return result


static func gather_time(grade: int, is_reroll: bool) -> float:
	return Juice.CARD_LEGEND_GATHER if grade == Upgrades.LEGENDARY and not is_reroll else 0.0


func _reveal_end() -> float:
	var last := 0.0
	for i in cards.size():
		last = maxf(last, _starts[i] + gather_time(_choices[i]["grade"], _is_reroll))
	return last + Juice.CARD_DROP_TIME + Juice.CARD_FLIP_TIME + Juice.CARD_FLASH_TIME


func _process(delta: float) -> void:
	_step_shake(delta)
	match state:
		State.REVEAL:
			_t += delta
			if _t >= _reveal_end():
				_finish_reveal()
			else:
				_step_reveal()
		State.GUARD:
			if Time.get_ticks_msec() >= _guard_until:  # 프레임이 느려도 실제 시간으로 막는다
				_open_input()


func _step_reveal() -> void:
	if not _is_reroll:
		_dim.modulate.a = minf(_t / Juice.CARD_DIM_TIME, 1.0)
	var distance := Juice.CARD_REROLL_DROP_DISTANCE if _is_reroll else Juice.CARD_DROP_DISTANCE
	for i in cards.size():
		var ct := _t - _starts[i]
		var wait := gather_time(_choices[i]["grade"], _is_reroll)
		cards[i].set_reveal(ct, distance, wait)
		if wait > 0.0 and ct >= Juice.CARD_DROP_TIME and not _gathered[i]:
			_gathered[i] = true
			_fx.gather(_card_rect(i), wait)
			Sfx.play_card_gather()
		# 모으기가 없는 유니크·레전드리(다시 뽑기): 앞면이 보이는 순간 "쾅"이 맞도록 카드가 떨어질 때부터 "쉬익"
		if wait == 0.0 and _choices[i]["grade"] >= Upgrades.UNIQUE and ct >= 0.0 and not _gathered[i]:
			_gathered[i] = true
			Sfx.play("card_swell")
		var show_at := Juice.CARD_DROP_TIME + wait + Juice.CARD_FLIP_TIME * 0.5
		if ct >= show_at - Juice.CARD_SOUND_LEAD:
			_voice(i)
		if ct >= show_at:
			_play_show(i)


func _card_rect(i: int) -> Rect2:
	return Rect2(cards[i].home, cards[i].size)


func _voice(i: int) -> void:
	if not _voiced[i]:
		_voiced[i] = true
		Sfx.play(CARD_GRADE_SOUND[_choices[i]["grade"]])


## 앞면이 보이는 순간: 등급만큼 소리와 빛. 유니크부터 빛 기둥과 약한 흔들림
func _play_show(i: int, strength := 1.0) -> void:
	if _sounded[i]:
		return
	_sounded[i] = true
	var grade: int = _choices[i]["grade"]
	_voice(i)  # 건너뛰기로 바로 온 카드
	_fx.burst(_card_rect(i), grade, strength)
	_fx.add_halo(i, _card_rect(i), grade)
	if Juice.CARD_SHAKE[grade] > 0.0 and App.settings.shake:
		_shake_left = Juice.CARD_SHAKE_TIME
		_shake_power = Juice.CARD_SHAKE[grade]


## 화면 전체를 잠깐 정수 픽셀로 흔든다
func _step_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		position = Vector2.ZERO
	else:
		var p := _shake_power * _shake_left / Juice.CARD_SHAKE_TIME
		position = Vector2(_shake_rng.randf_range(-p, p), _shake_rng.randf_range(-p, p)).round()


func _finish_reveal() -> void:
	_dim.modulate.a = 1.0
	for c in cards:
		c.settle()
	reroll_button.visible = not cards.is_empty()
	skip_button.visible = true
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
	skip_button.mouse_filter = filter


## 연출 건너뛰기: 바로 다 펼치고, 소리는 가장 높은 등급 한 번만. 잠깐 동안은 연타가 선택으로 이어지지 않게 막는다.
func skip() -> void:
	if state != State.REVEAL:
		return
	var best := -1
	for i in cards.size():
		if not _sounded[i] and (best < 0 or _choices[i]["grade"] > _choices[best]["grade"]):
			best = i
	_finish_reveal()
	if best >= 0:
		_play_show(best, Juice.CARD_SKIP_BURST)
	for i in cards.size():  # 건너뛴 나머지 카드도 소리·폭발 없이 후광은 남긴다
		if not _sounded[i]:
			_fx.add_halo(i, _card_rect(i), _choices[i]["grade"])
	_sounded.fill(true)
	state = State.GUARD
	_guard_until = Time.get_ticks_msec() + int(Juice.CARD_SKIP_GUARD * 1000.0)
	_set_input_open(false)


## 눌려 있는 손가락을 센다 (화면이 닫혀 있어도 세야 카드가 뜰 때 "미리 누르고 있던 손가락"을 안다)
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_stale.erase(event.index)  # 같은 번호로 새로 눌렀으면 뗀 신호를 놓친 것이다
			_touches[event.index] = true
			_tap_with_other_finger(event)
		else:
			_touches.erase(event.index)
			if _stale.erase(event.index):
				_stale_released_at = Time.get_ticks_msec()


## 조이스틱을 누른 채 다른 손가락으로 카드를 누른 경우: 둘째 손가락은 버튼에 전달되지 않아 여기서 직접 고른다.
func _tap_with_other_finger(event: InputEventScreenTouch) -> void:
	if state != State.READY or _stale_expired() or _stale.is_empty():
		return
	var at := get_global_transform_with_canvas().affine_inverse() * event.position
	for i in cards.size():
		if _card_rect(i).has_point(at):
			choose(i)
			return


## 뗀 신호를 놓친 손가락 때문에 카드를 영영 못 고르는 일이 없게, 기록은 잠깐만 믿는다.
func _stale_expired() -> bool:
	return Time.get_ticks_msec() - _shown_at >= Juice.CARD_STALE_MAX_MS


## 카드를 눌렀을 때: 미리 누르고 있던 손가락이 있거나 막 뗐으면 선택하지 않는다.
func _on_card_pressed(index: int) -> void:
	if _stale_expired() or (_stale.is_empty() and Time.get_ticks_msec() - _stale_released_at >= Juice.CARD_STALE_RELEASE_MS):
		choose(index)


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
	_fx.clear_halos()
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


## 건너뛰기 (버튼, 키보드 S). 다 펼쳐진 뒤에만 된다. 광물은 부르는 쪽이 금고에 넣는다.
func skip_pick() -> void:
	if state != State.READY:
		return
	state = State.PICKING
	_set_input_open(false)
	Sfx.play("click")
	_fx.clear_halos()
	close()
	skip_pressed.emit()


## 화면 크기에 맞춰 카드와 버튼을 놓는다 (연출 중에도 다시 부를 수 있음)
func _apply_layout() -> void:
	if state == State.CLOSED:
		return
	var view := size
	var lay := LevelCard.layout_for(view, _choices)
	if cards.is_empty():  # 고를 카드가 없음: 건너뛰기만 2배 크기로 가운데
		var big: Vector2i = lay["btn"] * 2
		var text := skip_text_for(int(view.x), 1, int(lay["btn_size"]) * 2, 0)
		big.x = maxi(big.x, button_width("건너뛰기", text, int(lay["btn_size"]) * 2))
		_build_button(skip_button, Vector2((int(view.x) - big.x) / 2, (int(view.y) - big.y) / 2), big, int(lay["btn_size"]) * 2, "건너뛰기", text, true)
		return
	var w: int = lay["w"]
	var gap: int = lay["gap"]
	var x0 := (int(view.x) - cards.size() * w - (cards.size() - 1) * gap) / 2
	var top := (int(view.y) - int(lay["total"])) / 2 + LevelCard.CREST_RISE
	for i in cards.size():
		var id: String = _choices[i]["id"]
		cards[i].home = Vector2(x0 + i * (w + gap), top)
		cards[i].setup(_choices[i], int(_levels.get(id, 0)) + 1, lay)
		_fx.move_halo(i, _card_rect(i))
		if state != State.REVEAL:
			cards[i].settle()
	# 버튼 줄: [다시 뽑기 N회] [건너뛰기 광물 +N], 카드 사이 간격만큼 떨어져 가운데 정렬
	var y := top + int(lay["h"]) + int(lay["btn_gap"])
	var btn: Vector2i = lay["btn"]
	var text := skip_text_for(int(view.x), 2, lay["btn_size"], gap)
	btn.x = maxi(btn.x, button_width("건너뛰기", text, lay["btn_size"]))  # 두 버튼은 같은 너비, 건너뛰기 글자가 다 들어가게
	var left := (int(view.x) - 2 * btn.x - gap) / 2
	_build_button(reroll_button, Vector2(left, y), btn, lay["btn_size"], "다시 뽑기", "%d회" % rerolls_left, rerolls_left > 0)
	_build_button(skip_button, Vector2(left + btn.x + gap, y), btn, lay["btn_size"], "건너뛰기", text, true)


## 건너뛰기 버튼의 노란 글자: 숫자가 광물 보상이라는 걸 바로 알게. short면 좁은 화면용 "(광물 N)"
func skip_text(short := false) -> String:
	return ("(광물 %d)" if short else "(보상 광물 %d)") % skip_reward


## 버튼 count개가 화면 폭(양옆 4픽셀 여백) 안에 들어가는 건너뛰기 글자: 긴 글자가 넘치면 짧은 글자
func skip_text_for(view_w: int, count: int, font_size: int, gap: int) -> String:
	var full := skip_text()
	return full if count * button_width("건너뛰기", full, font_size) + (count - 1) * gap <= view_w - 8 else skip_text(true)


## "제목 값"이 버튼 안에 다 들어가는 너비: 글자 + 판 그림 양 끝 장식(화살표) + 양옆 여백(글자 크기의 반씩)
static func button_width(title: String, count: String, font_size: int) -> int:
	var font := LevelCard.FONT
	var text_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size / 2 + font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return int(ceil(text_w)) + font_size + LevelCard.tex("button").get_width()


func _new_button(on_press: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	MenuPanel.add_press_feel(b)
	add_child(b)
	return b


## 판 그림 버튼 + "제목 값" (값은 노란 글자). 꺼지면 어둡게. 너비는 부르는 쪽이 button_width로 글자가 들어가게 잡는다
func _build_button(button: Button, pos: Vector2, btn: Vector2i, font_size: int, title: String, count: String, on: bool) -> void:
	for child in button.get_children():
		button.remove_child(child)
		child.queue_free()
	button.disabled = not on
	button.size = btn
	button.position = pos
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
	button.add_child(plate)
	var font := LevelCard.FONT
	var space := font_size / 2
	var title_w := int(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var count_w := int(font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var x := (btn.x - title_w - space - count_w) / 2
	var label_y := (btn.y - int(font.get_height(font_size))) / 2
	_button_label(button, title, Vector2(x, label_y), font_size, LABEL_INK if on else OFF_COLOR)
	_button_label(button, count, Vector2(x + title_w + space, label_y), font_size, COUNT_COLOR if on else OFF_COLOR)


func _button_label(button: Button, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	button.add_child(label)
