extends TestCase
## 시작 화면 씬 테스트.

const MainScene := preload("res://scenes/main.tscn")


func test_시작_화면이_열리고_버전을_표시함() -> void:
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	var version := str(ProjectSettings.get_setting("application/config/version"))
	var label: Label = main.get_node("%VersionLabel")
	assert_eq(label.text, "v" + version, "버전 표시")
	var title: Label = main.get_node("%Title")
	assert_eq(title.text, "소행성 광부", "제목")
	main.queue_free()


func test_이전_버전_버튼은_웹에서만_보임() -> void:
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	var button: Button = main.get_node("%OldVersionsButton")
	# 테스트는 웹이 아닌 환경에서 실행되므로 숨겨져 있어야 한다.
	assert_eq(button.visible, OS.has_feature("web"))
	main.queue_free()


func test_Enter로_바로_출격함() -> void:
	var main: Control = MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	var enter := InputEventAction.new()
	enter.action = "confirm"
	enter.pressed = true
	main._unhandled_input(enter)
	assert_true(main.launching, "이륙 시작")
	main.queue_free()


func test_광물_요약_문구() -> void:
	assert_eq(Hud.minerals_text(PackedInt32Array([3, 0, 1, 0])), "일반 3 · 영웅 1")
	assert_eq(Hud.minerals_text(PackedInt32Array([0, 0, 0, 0])), "없음")


func test_별_배경_층은_카메라를_따라_밀림() -> void:
	# 월드에 고정된 층(parallax 1.0)이 있어야 이동감이 난다.
	var has_world_layer := false
	for layer in Starfield.LAYERS:
		if is_equal_approx(layer["parallax"], 1.0):
			has_world_layer = true
	assert_true(has_world_layer, "월드 고정 층")
	# 팩 별 3겹은 서로 다른 속도(느림 → 빠름), 먼 행성은 가장 느림, 모두 어둡게
	assert_eq(Starfield.PACK_LAYERS.size(), 3, "별 3겹")
	var prev := float(Starfield.PLANET["parallax"])
	for layer in Starfield.PACK_LAYERS:
		assert_true(layer["parallax"] > prev and layer["parallax"] < 1.0, "시차 순서")
		assert_true(layer["dim"] <= 0.6, "배경은 어둡게")
		prev = layer["parallax"]
	assert_true(float(Starfield.PLANET["dim"]) <= 0.6, "행성도 어둡게")
	assert_eq(Starfield.tile_origin(Vector2(650, -10)), Vector2(-10, -350), "타일은 화면 왼쪽 위를 덮음")
	var area := Vector2(640, 360)
	var before := Starfield.star_position(Vector2(0.5, 0.5), area, Vector2.ZERO, 1.0)
	var after := Starfield.star_position(Vector2(0.5, 0.5), area, Vector2(10, 0), 1.0)
	assert_eq(before - after, Vector2(10, 0), "카메라가 오른쪽으로 10 가면 별은 왼쪽으로 10")
	var wrapped := Starfield.star_position(Vector2(0.01, 0.5), area, Vector2(20, 0), 1.0).x
	assert_true(is_equal_approx(wrapped, 640.0 - 20.0 + 6.4), "화면 밖은 반대편에서: %f" % wrapped)
