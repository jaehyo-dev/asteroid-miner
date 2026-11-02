extends TestCase
## 출격 화면 테스트: 진행, 일시 정지, 게임 오버 메뉴.

const RunScene := preload("res://scenes/run.tscn")


func _start() -> Node:
	var run := RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	return run


func test_출격하면_시간이_흐르고_카메라가_우주선을_따라감() -> void:
	var run: Node = await _start()
	await wait_frames(5)
	assert_true(run.sim.time > 0.0, "시간 흐름")
	run.sim.player_pos = Vector2(123, -45)
	await wait_frames(1)
	assert_eq(run.camera.position, Vector2(123, -45))
	run.queue_free()


func test_일시_정지하면_멈추고_계속하기로_재개() -> void:
	var run: Node = await _start()
	run.pause()
	var t: float = run.sim.time
	await wait_frames(5)
	assert_eq(run.sim.time, t, "멈춤")
	assert_true(run.menu.visible, "메뉴 표시")
	assert_eq(run.menu.title_text(), "일시 정지")
	assert_false(run.joystick.enabled, "조이스틱 꺼짐")
	run.menu.buttons()[0].pressed.emit()
	await wait_frames(3)
	assert_false(run.menu.visible, "메뉴 닫힘")
	assert_true(run.sim.time > t, "다시 진행")
	assert_true(run.joystick.enabled, "조이스틱 켜짐")
	run.queue_free()


func test_파괴되면_게임_오버_메뉴() -> void:
	var run: Node = await _start()
	run.sim.hp = 1.0
	run.sim.invuln = 0.0
	var a := RunSim.Asteroid.new()
	a.radius = 5.0
	a.damage = 50.0
	a.hp = 1000.0
	a.max_hp = 1000.0
	a.pos = run.sim.player_pos
	run.sim.asteroids.append(a)
	await wait_frames(2)
	assert_false(run.sim.alive)
	assert_true(run.menu.visible, "게임 오버 메뉴")
	assert_eq(run.menu.title_text(), "우주선 파괴")
	assert_true(run.menu.body_text().contains("버틴 시간"))
	assert_true(run.menu.body_text().contains("부순 운석"))
	assert_eq(run.menu.buttons().size(), 2)
	assert_false(run.pause_button.visible, "일시 정지 버튼 숨김")
	run.queue_free()


func test_게임_오버_중에는_일시_정지가_안_됨() -> void:
	var run: Node = await _start()
	run.sim.alive = false
	run.pause()
	assert_ne_menu(run)
	run.queue_free()


func assert_ne_menu(run: Node) -> void:
	assert_false(run.menu.visible and run.menu.title_text() == "일시 정지", "일시 정지 메뉴가 뜨면 안 됨")
