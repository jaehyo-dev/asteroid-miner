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
	assert_true(run.menu.body_text().contains("광물 가치"))
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


func test_광물과_파편이_있어도_오류_없이_진행() -> void:
	# 그리기 함수 밖에서 그리면 엔진 오류가 나고, 테스트 실행기가 실패로 잡는다.
	var run: Node = await _start()
	for i in 5:
		run.sim.drop_mineral(run.sim.player_pos + Vector2(80 + i * 10, 0)).grade = i % 4
	var a := RunSim.Asteroid.new()
	a.radius = 9.0
	a.pos = run.sim.player_pos + Vector2(0, 60)
	run.sim.destroyed.append(a)
	run.world.step(0.016)
	await wait_frames(5)
	assert_true(run.sim.minerals.size() >= 1, "광물이 남아 있음")
	run.queue_free()


func test_레벨업하면_강화_메뉴가_뜨고_고르면_닫힘() -> void:
	var run: Node = await _start()
	run.sim.gain_xp(Balance.XP_BASE)
	await wait_frames(2)
	assert_true(run.menu.visible, "레벨업 메뉴")
	assert_true(run.menu.title_text().begins_with("레벨 업"), run.menu.title_text())
	assert_eq(run.menu.buttons().size(), Balance.UPGRADE_CHOICE_COUNT)
	assert_true(run.menu.buttons()[0].disabled, "뜬 직후에는 누를 수 없음")
	var t: float = run.sim.time
	await get_tree().create_timer(Balance.LEVEL_UP_INPUT_DELAY + 0.1).timeout
	assert_false(run.menu.buttons()[0].disabled, "잠시 뒤 누를 수 있음")
	assert_eq(run.sim.time, t, "고르는 동안 멈춤")
	run.menu.choose(1)
	await wait_frames(2)
	assert_false(run.menu.visible, "닫힘")
	assert_eq(run.sim.pending_levelups, 0)
	assert_true(run.sim.time > t, "다시 진행")
	run.queue_free()


func test_두_번_레벨업하면_메뉴가_두_번_뜸() -> void:
	var run: Node = await _start()
	run.sim.gain_xp(Upgrades.xp_to_next(1) + Upgrades.xp_to_next(2))
	await wait_frames(2)
	assert_true(run.menu.title_text().contains("Lv 2"), run.menu.title_text())
	await get_tree().create_timer(Balance.LEVEL_UP_INPUT_DELAY + 0.1).timeout
	run.menu.choose(0)
	await wait_frames(2)
	assert_true(run.menu.visible, "두 번째 메뉴")
	assert_true(run.menu.title_text().contains("Lv 3"), run.menu.title_text())
	await get_tree().create_timer(Balance.LEVEL_UP_INPUT_DELAY + 0.1).timeout
	run.menu.choose(0)
	await wait_frames(2)
	assert_false(run.menu.visible)
	run.queue_free()


func test_숫자키로_강화를_고름() -> void:
	var run: Node = await _start()
	run.sim.gain_xp(Balance.XP_BASE)
	await wait_frames(2)
	await get_tree().create_timer(Balance.LEVEL_UP_INPUT_DELAY + 0.1).timeout
	var expected: String = run.sim.choices[2]
	var key := InputEventKey.new()
	key.physical_keycode = KEY_3
	key.pressed = true
	run._unhandled_input(key)
	await wait_frames(1)
	assert_eq(int(run.sim.upgrade_levels.get(expected, 0)), 1, "3번 강화 적용")
	run.queue_free()


func test_숫자키_번호() -> void:
	var script: GDScript = load("res://scripts/run.gd")
	assert_eq(script.number_key_index(KEY_1), 0)
	assert_eq(script.number_key_index(KEY_3), 2)
	assert_eq(script.number_key_index(KEY_KP_2), 1, "키패드")
	assert_eq(script.number_key_index(KEY_A), -1)
