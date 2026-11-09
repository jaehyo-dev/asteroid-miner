extends TestCase
## 기지 귀환 충격 셔터: 닫힘 → 쿵 흔들림 → 기다림 → 열림 순서, 입력 막기, 열린 뒤에 착륙.


## 셔터를 seconds초 동안 직접 진행한다 (프레임을 기다리지 않아 시간이 정확하다)
func _run(s: Shutter, seconds: float, step := 0.01) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		s._process(step)
		t += step


func test_셔터는_닫히고_쿵_흔들린_뒤_열리며_신호를_냄() -> void:
	var s := Shutter.new()
	add_child(s)
	s.set_process(false)  # 시간은 _run으로만
	var got := [false]
	s.opened.connect(func() -> void: got[0] = true)
	assert_false(s.busy())
	s.close_to("")
	assert_true(s.busy() and s.visible, "닫히기 시작")
	assert_eq(s.mouse_filter, Control.MOUSE_FILTER_STOP, "누름을 막음")
	_run(s, Juice.SHUTTER_CLOSE / 2.0)
	assert_true(s.closed > 0.0 and s.closed < 0.5, "점점 빨라지며 닫힘 (반 시간에 반도 안 닫힘)")
	_run(s, Juice.SHUTTER_CLOSE / 2.0 + 0.005)
	assert_eq(s.state, Shutter.State.SHAKE, "닫히는 순간 쿵")
	assert_eq(s.closed, 1.0)
	s.close_to("res://scenes/run.tscn")
	assert_eq(s._scene, "", "움직이는 중에 다시 불러도 무시")
	_run(s, Juice.SHUTTER_SHAKE.size() * Juice.SHUTTER_SHAKE_STEP + 0.005)
	assert_eq(s.state, Shutter.State.HOLD)
	assert_eq(s._shake, 0, "흔들림은 제자리에서 끝남")
	_run(s, Juice.SHUTTER_HOLD + 0.005)
	assert_eq(s.state, Shutter.State.OPENING)
	assert_false(got[0], "열리는 중에는 아직 신호 없음")
	_run(s, Juice.SHUTTER_OPEN + 0.01)
	assert_true(got[0], "다 열리면 신호")
	assert_false(s.busy() or s.visible, "끝나면 숨김")
	assert_eq(s.mouse_filter, Control.MOUSE_FILTER_IGNORE, "누름을 다시 통과")
	s.queue_free()


func test_흔들림_끄기면_셔터도_안_흔들림() -> void:
	var s := Shutter.new()
	add_child(s)
	s.set_process(false)
	var old: bool = App.settings.shake
	App.settings.shake = false
	s.close_to("")
	_run(s, Juice.SHUTTER_CLOSE + 0.015)
	assert_eq(s.state, Shutter.State.SHAKE)
	assert_eq(s._shake, 0)
	App.settings.shake = old
	s.queue_free()


func test_셔터가_움직이는_동안_키_입력이_아래로_안_감() -> void:
	var s := Shutter.new()
	add_child(s)
	s.set_process(false)
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	s.close_to("")
	s._input(key)
	assert_true(get_viewport().is_input_handled(), "막음")
	s.queue_free()


func test_귀환하면_셔터가_열린_뒤에_착륙하고_그다음_결과() -> void:
	var sh: Shutter = App.shutter
	sh.close_to("")
	_run(sh, Juice.SHUTTER_CLOSE + 0.015)  # 닫힌 채
	App.landing = true
	App.return_result = {"title": "귀환 성공!", "body": "시험"}
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	assert_true(main.view.landing_hold and main.view.landing_t == 0.0, "셔터가 닫혀 있는 동안은 위에 떠서 기다림 (착륙장에 먼저 서 있지 않음)")
	await wait_frames(3)
	assert_eq(main.view.landing_t, 0.0, "기다리는 동안 안 내려옴")
	assert_false(main.result_menu.visible, "결과 창도 아직")
	assert_false(main._can_drag(Vector2(10, 300)), "끌기 막음")
	_run(sh, 2.0)
	assert_false(sh.busy())
	assert_true(main.view.landing_t >= 0.0 and not main.view.landing_hold, "열리면 착륙 시작")
	assert_eq(main._white.modulate.a, 0.0, "흰 번쩍임 없음")
	main.queue_free()
