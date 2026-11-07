extends TestCase
## 게임 전체 설정(App 자동 로드) 테스트.


func test_기준_해상도는_창_방향과_상관없이_가로용() -> void:
	assert_eq(App.base_size_for(Vector2i(390, 844)), Balance.BASE_LANDSCAPE)
	assert_eq(App.base_size_for(Vector2i(1280, 720)), Balance.BASE_LANDSCAPE)
	assert_eq(App.base_size_for(Vector2i(844, 390)), Balance.BASE_LANDSCAPE)


func test_세로_창인지_판정() -> void:
	assert_true(App.is_portrait_size(Vector2i(390, 844)))
	assert_false(App.is_portrait_size(Vector2i(844, 390)))
	assert_false(App.is_portrait_size(Vector2i(1000, 1000)), "정사각형은 가로로 침")


func test_세로면_안내_화면이_덮고_가로로_돌리면_사라지며_신호가_남() -> void:
	var seen: Array = []
	var f := func(p: bool) -> void: seen.append(p)
	App.portrait_changed.connect(f)
	App.set_portrait(true)
	assert_true(App._rotate_layer.visible, "안내 화면")
	assert_eq(App._rotate_label.text, "폰을 가로로 돌려주세요")
	assert_true(App._rotate_layer.layer >= 100, "게임 위")
	App.set_portrait(true)  # 같은 상태 반복은 신호 없음
	App.set_portrait(false)
	assert_false(App._rotate_layer.visible)
	assert_eq(seen, [true, false])
	App.portrait_changed.disconnect(f)


func test_세로로_돌려도_기지_화면과_저장은_그대로() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	var credits: int = main.save.credits
	App.set_portrait(true)
	await wait_frames()
	App.set_portrait(false)
	await wait_frames()
	assert_true(is_instance_valid(main) and main.is_inside_tree(), "기지 화면 그대로")
	assert_eq(main.save.credits, credits)
	assert_false(main.launching)
	main.queue_free()


func test_출격_중_세로로_돌리면_일시_정지_가로로_돌려도_메뉴에서_이어감() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames()
	assert_eq(run.current_menu, run.Menu.NONE)
	var time_before: float = run.sim.time
	App.set_portrait(true)
	assert_eq(run.current_menu, run.Menu.PAUSE, "세로 → 일시 정지")
	await wait_frames(5)
	assert_eq(run.sim.time, time_before, "정지 중에는 시간이 흐르지 않음")
	App.set_portrait(false)
	assert_eq(run.current_menu, run.Menu.PAUSE, "가로로 돌려도 일시 정지 메뉴가 남아 계속하기로 이어감")
	run._close_menu()
	await wait_frames(3)
	assert_true(run.sim.time > time_before, "계속하면 이어서 흐름")
	run.queue_free()


func test_이동과_일시_정지_키가_등록됨() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "pause"]:
		assert_true(InputMap.has_action(action), action)
		assert_true(InputMap.action_get_events(action).size() >= 1, action + " 키")


func test_자동_로드로_실행됨() -> void:
	assert_not_null(get_tree().root.get_node_or_null("App"), "App 노드")


func test_기지_화면은_2배_기준_해상도() -> void:
	assert_eq(App.base_size_for(Vector2i(1280, 720), true), Vector2i(1280, 720))
	App.set_base_mode(true)
	assert_eq(get_tree().root.content_scale_size, App.base_size_for(get_tree().root.size, true))
	App.set_base_mode(false)
	assert_eq(get_tree().root.content_scale_size, App.base_size_for(get_tree().root.size))
