extends TestCase
## 설정 (화면 흔들림, 효과음 크기): 저장·불러오기, 일시 정지 메뉴, 적용


func test_설정은_따로_저장되고_다시_불러옴() -> void:
	var s := GameSettings.load_file()
	assert_true(s.shake, "기본은 흔들림 켜짐")
	assert_eq(s.sfx_level, GameSettings.SFX_LEVELS, "기본은 최대 크기")
	s.shake = false
	s.sfx_level = 1
	assert_true(s.save_file())
	var again := GameSettings.load_file()
	assert_false(again.shake)
	assert_eq(again.sfx_level, 1)
	assert_false(FileAccess.file_exists(SaveData.path), "세이브 데이터 파일은 만들지 않음")


func test_망가진_값은_범위_안으로() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "sfx_level", 99)
	cfg.save(GameSettings.path)
	assert_eq(GameSettings.load_file().sfx_level, GameSettings.SFX_LEVELS)


func test_효과음_크기는_한_바퀴_돌고_0은_음소거() -> void:
	var s := GameSettings.new()
	s.cycle_sfx()
	assert_eq(s.sfx_level, 0, "최대에서 누르면 끄기")
	assert_eq(s.sfx_label(), "효과음: 끄기")
	s.cycle_sfx()
	assert_eq(s.sfx_level, 1)
	assert_true(s.sfx_db() < -6.0, "작아짐")
	App.settings = s
	App.apply_settings()
	var bus := AudioServer.get_bus_index("SFX")
	assert_true(bus > 0, "효과음 버스가 있음")
	assert_false(AudioServer.is_bus_mute(bus))
	s.sfx_level = 0
	App.apply_settings()
	assert_true(AudioServer.is_bus_mute(bus), "끄기 = 음소거")
	for child in Sfx.get_children():
		assert_eq((child as AudioStreamPlayer).bus, &"SFX", "모든 효과음이 효과음 버스로")


func test_일시_정지_메뉴에서_바꾸면_저장되고_흔들림이_꺼짐() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	run.pause()
	assert_eq(run.menu.buttons()[1].text, "화면 흔들림: 켜짐")
	run.menu.buttons()[1].pressed.emit()
	await wait_frames(1)
	assert_true(run.menu.visible, "메뉴는 그대로")
	assert_eq(run.menu.buttons()[1].text, "화면 흔들림: 꺼짐")
	assert_false(GameSettings.load_file().shake, "파일에 저장됨")
	run.menu.buttons()[2].pressed.emit()
	await wait_frames(1)
	assert_eq(run.menu.buttons()[2].text, "효과음: 끄기")
	assert_eq(run.menu.buttons()[3].text, "배경음: 100%")
	assert_eq(run.menu.buttons()[4].text, "포기하고 기지로")
	run.menu.buttons()[0].pressed.emit()
	await wait_frames(1)
	run.alert.kick(1.0, 5.0)
	await wait_frames(2)
	assert_eq(run.camera.offset, Vector2.ZERO, "흔들림 꺼짐")
	run.queue_free()
