extends TestCase
## 배경음 (Music, MusicMix), 일시 정지 화면, 숨은 FPS 표시


func test_층은_출격_시간에_맞춰_차례로_쌓임() -> void:
	var enter := [30.0, 60.0, 120.0]  # 리듬, 화음, 빠른 리듬 + 멜로디 (베이스는 곡에 섞여 출격 직후부터)
	for i in enter.size():
		var stem: Array = Juice.MUSIC_STEMS[i]
		assert_true(is_equal_approx(float(stem[0]), enter[i]), "%d번 시작" % i)
		assert_true(MusicMix.run_stem_db(i, enter[i] - 0.5) <= -60.0 + float(stem[2]), "%d번은 그 전엔 안 들림" % i)
		assert_true(MusicMix.run_stem_db(i, enter[i] + float(stem[1]) * 0.5) > MusicMix.run_stem_db(i, enter[i]), "커지는 중")
		assert_true(absf(MusicMix.run_stem_db(i, enter[i] + float(stem[1])) - float(stem[2])) < 0.01, "다 커짐")


func test_곡과_층은_길이가_같고_음악_버스로_반복() -> void:
	var list := Music.players()
	assert_eq(list.size(), 2 + Juice.MUSIC_STEMS.size())
	for p in list:
		assert_true(absf(list[0].stream.get_length() - 128.0 * 60.0 / 135.0) < 0.001, "곡은 128박")
		var bars: float = p.stream.get_length() / (4.0 * 60.0 / 135.0)
		assert_true(absf(bars - round(bars)) < 0.001, "마디의 정수배라 함께 돌아도 박이 안 어긋남: %f" % bars)
		assert_eq(p.bus, &"Music")
		assert_true(p.stream.loop, "반복")
		assert_true(p.playing, "재생 중")


func test_다른_앱으로_가면_멈추고_돌아오면_이어서_남() -> void:
	Music.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	for p in Music.players():
		assert_true(p.stream_paused, "멈춤")
	Music.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	for p in Music.players():
		assert_false(p.stream_paused, "이어서")


func test_기지는_먹먹한_층만_작게_출격은_곡과_쌓인_층() -> void:
	Music.set_base()
	assert_eq(Music.target_main_db, Juice.MUSIC_SILENT_DB, "기지엔 또렷한 곡이 안 들림")
	assert_eq(Music.target_base_db, Juice.MUSIC_BASE_DB, "먹먹한 층")
	assert_true(Music.target_base_db < Juice.MUSIC_RUN_DB, "더 작음")
	for db in Music.target_stem_dbs:
		assert_true(db < -60.0, "기지에선 음 층이 꺼짐")
	Music.set_run_time(125.0)
	assert_eq(Music.target_main_db, Juice.MUSIC_RUN_DB, "출격은 곡")
	assert_eq(Music.target_base_db, Juice.MUSIC_SILENT_DB, "먹먹한 층은 꺼짐")
	assert_true(Music.target_stem_dbs[2] > -60.0, "2분 뒤엔 멜로디 층까지")
	Music.set_base()


func test_배경음_크기_설정은_버스에_적용되고_저장됨() -> void:
	var s := App.settings
	var bus := AudioServer.get_bus_index("Music")
	s.music_level = 2
	App.apply_settings()
	assert_true(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.01, "50%")
	assert_false(AudioServer.is_bus_mute(bus))
	s.music_level = GameSettings.SFX_LEVELS
	s.cycle_music()
	assert_eq(s.music_level, 0, "최대 다음은 끄기")
	assert_eq(s.music_label(), "배경음: 끄기")
	App.apply_settings()
	assert_true(AudioServer.is_bus_mute(bus), "끄기 = 음소거")
	s.save_file()
	assert_eq(GameSettings.load_file().music_level, 0, "파일에 저장")
	s.music_level = GameSettings.SFX_LEVELS
	App.apply_settings()


func _pause_run() -> Node:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	run.pause()
	return run


func test_일시_정지는_뒤를_어둡게_덮고_말풍선을_숨기며_닫으면_돌아옴() -> void:
	var run: Node = await _pause_run()
	assert_true(is_equal_approx(run.menu._dim.color.a, MenuPanel.DIM_PAUSE), "진하게")
	assert_true(run.hud.hide_tip, "말풍선 숨김")
	run.menu.buttons()[0].pressed.emit()
	await wait_frames(1)
	assert_false(run.hud.hide_tip, "다시 보임")
	run.sim.pending_levelups = 0
	run._open_menu(run.Menu.LEVEL_UP, "레벨 업", "", ["1"])
	assert_true(is_equal_approx(run.menu._dim.color.a, MenuPanel.DIM_NORMAL), "다른 메뉴는 보통 진하기")
	run.queue_free()


func test_일시_정지_메뉴_창은_화면_가운데() -> void:
	var run: Node = await _pause_run()
	await wait_frames(2)
	var panel: Control = run.menu._box.get_parent()
	var view: Vector2 = run.get_viewport_rect().size
	var center := panel.get_global_rect().get_center()
	assert_true(absf(center.x - view.x / 2.0) <= 1.0 and absf(center.y - view.y / 2.0) <= 1.0, "가운데 %s / %s" % [center, view])
	run.queue_free()


func test_제목을_5번_누르면_FPS_표시가_켜지고_저장됨() -> void:
	var run: Node = await _pause_run()
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	for i in 4:
		run.menu._title.gui_input.emit(tap)  # 실제 누름과 같은 길로
	assert_false(App.settings.show_fps, "4번으로는 안 켜짐")
	run.menu.title_tapped.emit()
	assert_true(App.settings.show_fps, "5번째에 켜짐")
	assert_true(GameSettings.load_file().show_fps, "settings.cfg에 저장")
	for i in 5:
		run.menu.title_tapped.emit()
	assert_false(App.settings.show_fps, "5번 더 누르면 꺼짐")
	run.queue_free()
