extends TestCase
## 워프 점프 출격·귀환 (GAME_SPEC 11번).

const RunScene := preload("res://scenes/run.tscn")
const MainScene := preload("res://scenes/main.tscn")
const SAVE := "user://test_warp_save.json"

var _old_path := ""


func _use_test_save(seen := false) -> void:
	_old_path = SaveData.path if _old_path == "" else _old_path
	SaveData.path = SAVE
	var s := SaveData.new()
	s.warp_seen = seen
	s.save_file()
	App.warp_intro = false
	App.landing = false
	App.return_result = {}


func _restore() -> void:
	SaveData.path = _old_path
	DirAccess.remove_absolute(SAVE)
	App.warp_intro = false
	App.landing = false
	App.return_result = {}


func _start_run(seen := false) -> Node:
	_use_test_save(seen)
	App.warp_intro = true
	var run := RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	return run


func test_전체_시간은_3에서_4초() -> void:
	assert_true(WarpJump.TOTAL_TIME >= 3.0 and WarpJump.TOTAL_TIME <= 4.0, "%f초" % WarpJump.TOTAL_TIME)
	assert_true(absf(Juice.WARP_TUNNEL_TIME - 1.0) < 0.2, "터널 약 1초")
	assert_true(Juice.WARP_LAND_TIME < WarpJump.TOTAL_TIME / 2.0, "귀환은 더 짧게")


func test_시간표는_순서대로_진행() -> void:
	assert_eq(WarpJump.phase(0.0), WarpJump.Phase.TAKEOFF)
	assert_eq(WarpJump.phase(Juice.WARP_TAKEOFF_TIME), WarpJump.Phase.CHARGE)
	assert_eq(WarpJump.phase(Juice.WARP_TAKEOFF_TIME + Juice.WARP_CHARGE_TIME), WarpJump.Phase.JUMP)
	assert_eq(WarpJump.phase(WarpJump.BASE_TIME), WarpJump.Phase.DONE)
	assert_eq(WarpJump.lift(0.0), 0.0, "탑승 중")
	assert_eq(WarpJump.lift(Juice.WARP_TAKEOFF_TIME), 1.0)
	assert_true(WarpJump.shake_cells(BaseView.LAUNCH_TIME) > WarpJump.shake_cells(Juice.WARP_TAKEOFF_TIME * 0.5), "충전할수록 흔들림")
	assert_eq(WarpJump.base_white(BaseView.LAUNCH_TIME), 1.0, "점프 끝에 흰 화면")
	assert_eq(WarpJump.run_white(0.0), 1.0, "터널은 흰 화면에서 시작")
	assert_eq(WarpJump.run_white(0.6), 0.0)
	assert_eq(WarpJump.tunnel_strength(0.5), 1.0)
	assert_eq(WarpJump.tunnel_strength(WarpJump.RUN_TIME), 0.0)
	assert_true(WarpJump.arrive_slide(Juice.WARP_TUNNEL_TIME) < 0.0, "앞에서 밀려 들어옴")
	assert_eq(WarpJump.arrive_slide(WarpJump.RUN_TIME), 0.0)
	assert_eq(WarpJump.hud_in(WarpJump.RUN_TIME), 1.0)


func test_건너뛰기_입력은_누름만() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(WarpJump.is_skip_press(touch))
	touch.pressed = false
	assert_false(WarpJump.is_skip_press(touch))
	var key := InputEventKey.new()
	key.pressed = true
	key.echo = true
	assert_false(WarpJump.is_skip_press(key), "키 반복")
	key.echo = false
	assert_true(WarpJump.is_skip_press(key))
	assert_false(WarpJump.is_skip_press(InputEventMouseMotion.new()))


func test_터널_중에는_게임이_멈추고_끝나면_시작하고_저장() -> void:
	var run: Node = await _start_run()
	assert_true(run.intro_t >= 0.0, "터널 중")
	assert_false(App.warp_intro, "한 번만 씀")
	assert_false(run.hud.visible, "HUD는 도착할 때")
	assert_false(run.pause_button.visible)
	assert_false(run.joystick.enabled)
	assert_eq(run.sim.time, 0.0, "시뮬레이션 멈춤")
	run._step_intro(Juice.WARP_TUNNEL_TIME)
	assert_true(run.hud.visible, "도착하면 HUD")
	assert_true(run.hud.position.y < 0.0, "밀려 들어오는 중")
	run._step_intro(WarpJump.RUN_TIME)
	assert_eq(run.intro_t, -1.0, "끝")
	assert_eq(run.hud.position, Vector2.ZERO)
	assert_true(run.pause_button.visible)
	assert_true(run.joystick.enabled)
	assert_true(SaveData.load_file().warp_seen, "한 번 봤다고 저장")
	await wait_frames(2)
	assert_true(run.sim.time > 0.0, "게임 시작")
	run.queue_free()
	_restore()


func test_처음에는_건너뛸_수_없고_두_번째부터_건너뜀() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var run: Node = await _start_run(false)
	run._input(touch)
	assert_true(run.intro_t >= 0.0, "처음은 못 건너뜀")
	run.queue_free()
	var again: Node = await _start_run(true)
	again._input(touch)
	assert_eq(again.intro_t, -1.0, "건너뜀")
	assert_true(again.get_viewport().is_input_handled(), "같은 누름이 다른 곳으로 가지 않음")
	again.queue_free()
	_restore()


func test_터널_중에는_일시_정지되지_않음() -> void:
	var run: Node = await _start_run()
	run.pause()
	assert_eq(run.current_menu, run.Menu.NONE)
	run.queue_free()
	_restore()


func test_보통_출격_화면은_터널_없이_바로_시작() -> void:
	_use_test_save()
	var run := RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	assert_eq(run.intro_t, -1.0)
	assert_true(run.hud.visible)
	run.queue_free()
	_restore()


func _main(seen := false) -> Control:
	_use_test_save(seen)
	var main := MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames(2)
	return main


func test_저장에_warp_seen이_남음() -> void:
	var s := SaveData.new()
	s.warp_seen = true
	assert_true(SaveData.from_dict(s.to_dict()).warp_seen)
	assert_false(SaveData.from_dict({}).warp_seen, "옛 저장은 안 본 것")
	assert_false(SaveData.from_dict({"warp_seen": "예"}).warp_seen, "이상한 값")


func test_기지에서_처음에는_눌러도_이륙이_이어짐() -> void:
	var main: Control = await _main(false)
	main.press("ship")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	main._input(touch)
	assert_false(main._launch_done)
	main.queue_free()
	_restore()


func test_두_번째부터_기지에서_누르면_바로_넘어감() -> void:
	var main: Control = await _main(true)
	var state := {"launched": false}
	main.launched.connect(func() -> void: state["launched"] = true)
	main.press("ship")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	main._input(touch)
	assert_true(state["launched"])
	assert_false(App.warp_intro, "건너뛰면 터널도 없음")
	main.queue_free()
	_restore()


func test_귀환하면_기지에_착륙하고_그동안_건물을_못_누름() -> void:
	_use_test_save()
	App.landing = true
	var main := MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames(1)
	assert_false(App.landing, "한 번만 씀")
	assert_true(main.view.landing_t >= 0.0, "착륙 중")
	main.press("research")
	assert_false(main.panel.visible)
	main.view.landing_t = Juice.WARP_LAND_TIME - 0.001
	await wait_frames(2)
	assert_eq(main.view.landing_t, -1.0, "착륙 끝")
	main.press("research")
	assert_true(main.panel.visible)
	main.queue_free()
	_restore()


## 착륙 중인 기지 화면을 만든다 (귀환 결과를 들고)
func _landing_main() -> Node:
	_use_test_save(true)
	App.landing = true
	App.return_result = {"title": "귀환 성공!", "body": "결과 내용"}
	var main := MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames(1)
	return main


func _finish_landing(main: Node) -> void:
	main.view.landing_t = Juice.WARP_LAND_TIME - 0.001
	await wait_frames(3)


func test_결과_화면은_착륙이_끝나야_기지_위에_뜬다() -> void:
	var main: Node = await _landing_main()
	assert_true(App.return_result.is_empty(), "한 번만 씀")
	assert_false(main.result_menu.visible, "착륙 중에는 안 뜸")
	await _finish_landing(main)
	assert_true(main.result_menu.visible)
	assert_eq(main.result_menu.title_text(), "귀환 성공!")
	assert_eq(main.result_menu.body_text(), "결과 내용")
	assert_true(main.result_menu.size == main.size, "기지 화면 전체를 덮음")
	main.queue_free()
	_restore()


func test_결과_화면이_떠_있으면_건물과_출격을_못_누름() -> void:
	var main: Node = await _landing_main()
	await _finish_landing(main)
	main.press("research")
	assert_false(main.panel.visible)
	main.press("ship")
	assert_false(main.launching)
	assert_false(main.spots.visible, "키보드로도 못 고르게 숨김")
	main.result_menu.buttons()[1].pressed.emit()  # 확인
	assert_false(main.result_menu.visible)
	assert_true(main.spots.visible)
	assert_false(main.launching, "확인은 기지에 머문다")
	main.press("research")
	assert_true(main.panel.visible, "닫으면 기지를 다시 쓸 수 있음")
	main.queue_free()
	_restore()


func test_결과_화면에서_다시_출격하면_이륙한다() -> void:
	var main: Node = await _landing_main()
	await _finish_landing(main)
	main.result_menu.buttons()[0].pressed.emit()
	assert_false(main.result_menu.visible)
	assert_true(main.launching)
	main.queue_free()
	_restore()


func test_파괴되면_착륙도_결과도_넘기지_않음() -> void:
	var run := await _start_run(true)
	run.sim.alive = false
	run._show_game_over()
	assert_eq(run.current_menu, run.Menu.GAME_OVER)
	assert_false(App.landing)
	assert_true(App.return_result.is_empty())
	run.queue_free()
	_restore()


func test_워프_소리는_wav이고_웅웅거림은_반복() -> void:
	var streams := Sfx.warp_streams()
	assert_eq((streams[2] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)
	var hum := streams[2] as AudioStreamWAV
	assert_eq(hum.loop_end, int(hum.get_length() * hum.mix_rate), "끝까지 돌고 반복")
	for s in Sfx.jump_streams():
		assert_true(s.data.size() > 1000)
