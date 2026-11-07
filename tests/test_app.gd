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
	var root := get_tree().root
	App.set_base_mode(true)
	assert_eq(root.content_scale_size, App.base_size_for(root.size, true))
	assert_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "기지는 예전 그대로")
	App.set_base_mode(false)
	var k := App.run_pixel_scale(root.size)
	if k > 0:
		assert_eq(root.content_scale_size, App.run_view_size(root.size, k))
		assert_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER)
	else:
		assert_eq(root.content_scale_size, App.base_size_for(root.size))
		assert_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_FRACTIONAL)


## 실제 화면 픽셀 크기(CSS 크기 × 기기 픽셀 비율) → 기대하는 정수 배율, 논리 화면 크기
const RUN_WINDOWS := [
	[Vector2i(1280, 720), 2, Vector2i(640, 360)],  # PC
	[Vector2i(1366, 657), 2, Vector2i(683, 328)],  # 노트북 브라우저 창 (소수 1.83배였던 곳)
	[Vector2i(2532, 1170), 3, Vector2i(844, 390)],  # 폰 가로 844x390, 픽셀 비율 3
	[Vector2i(2402, 1082), 3, Vector2i(800, 360)],  # 폰 가로 915x412, 픽셀 비율 2.625
	[Vector2i(1920, 1080), 3, Vector2i(640, 360)],  # 큰 PC
	[Vector2i(844, 390), 1, Vector2i(844, 390)],  # 폰 가로, 픽셀 비율 1
]


func test_출격_화면은_창_크기마다_정수_배율이고_논리_화면이_범위_안() -> void:
	for row in RUN_WINDOWS:
		var window: Vector2i = row[0]
		var k := App.run_pixel_scale(window)
		var view := App.run_view_size(window, k)
		assert_eq(k, row[1], "%s 배율" % window)
		assert_eq(view, row[2], "%s 논리 화면" % window)
		assert_true(view.x >= Balance.RUN_VIEW_MIN.x and view.y >= Balance.RUN_VIEW_MIN.y and view.y <= Balance.RUN_VIEW_MAX_HEIGHT, "%s 범위 %s" % [window, view])
		# 정수 배율로 그린 논리 화면이 창 안에 들어가고, 남는 빈칸은 배율보다 작다
		var rest := window - view * k
		assert_true(rest.x >= 0 and rest.y >= 0 and rest.x < k and rest.y < k, "%s 빈칸 %s" % [window, rest])


func test_논리_화면이_너무_작아지면_배율을_낮추고_범위를_못_맞추면_소수_배율() -> void:
	# 1600x900: 3배면 533x300으로 너무 작음 → 2배(800x450)
	assert_eq(App.run_pixel_scale(Vector2i(1600, 900)), 2)
	# 1024x650: 2배면 512 폭으로 작고, 1배면 650 높이로 너무 큼 → 소수 배율(0)
	assert_eq(App.run_pixel_scale(Vector2i(1024, 650)), 0)
	# 아주 작은 창
	assert_eq(App.run_pixel_scale(Vector2i(400, 300)), 0)


func test_창_크기가_바뀌어도_운석은_논리_화면_밖에서_나타남() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in RUN_WINDOWS:
		var view := Vector2(row[2])
		var screen := Rect2(-view / 2.0, view)  # 우주선(원점)이 가운데인 화면
		for i in 64:
			var p := RunSim.spawn_position(rng, Vector2.ZERO, view, 5.0)
			# 가장 작은 운석(반지름 5)도 화면에 조금도 걸치지 않는다
			assert_false(screen.grow(5.0).has_point(p), "%s 화면 밖 %s" % [view, p])
