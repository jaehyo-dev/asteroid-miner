extends TestCase
## 배경음 (Music, MusicMix), 일시 정지 화면, 숨은 FPS 표시


func test_필터는_시간이_지날수록_열리고_끝에서_멈춤() -> void:
	assert_eq(MusicMix.run_cutoff(0.0), Juice.MUSIC_CUTOFF_START)
	assert_true(MusicMix.run_cutoff(60.0) > MusicMix.run_cutoff(0.0), "1분이면 더 열림")
	assert_true(MusicMix.run_cutoff(120.0) > MusicMix.run_cutoff(60.0), "2분이면 더 열림")
	assert_true(absf(MusicMix.run_cutoff(Juice.MUSIC_CUTOFF_RAMP) - Juice.MUSIC_CUTOFF_END) < 0.01, "끝")
	assert_eq(MusicMix.run_cutoff(999.0), MusicMix.run_cutoff(Juice.MUSIC_CUTOFF_RAMP), "더 안 열림")


func test_리듬_층은_2분_뒤에_들어옴() -> void:
	assert_true(MusicMix.run_layer_db(0.0) <= -60.0 + Juice.MUSIC_LAYER_DB, "처음엔 안 들림")
	assert_true(MusicMix.run_layer_db(119.0) <= -60.0 + Juice.MUSIC_LAYER_DB, "2분 전에도")
	assert_true(MusicMix.run_layer_db(125.0) > MusicMix.run_layer_db(120.0), "커지는 중")
	assert_true(absf(MusicMix.run_layer_db(Juice.MUSIC_LAYER_TIME + Juice.MUSIC_LAYER_FADE) - Juice.MUSIC_LAYER_DB) < 0.01, "다 커짐")


func test_곡과_리듬_층은_길이가_같고_음악_버스로_반복() -> void:
	var list := Music.players()
	assert_eq(list.size(), 2)
	assert_true(absf(list[0].stream.get_length() - list[1].stream.get_length()) < 0.01, "함께 돌아도 박이 안 어긋남")
	for p in list:
		assert_eq(p.bus, &"Music")
		assert_true(p.stream.loop, "반복")
		assert_true(p.playing, "재생 중")
	var bus := AudioServer.get_bus_index("Music")
	assert_true(AudioServer.get_bus_effect(bus, 0) is AudioEffectLowPassFilter, "높은 음 깎는 필터")


func test_다른_앱으로_가면_멈추고_돌아오면_이어서_남() -> void:
	Music.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	for p in Music.players():
		assert_true(p.stream_paused, "멈춤")
	Music.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	for p in Music.players():
		assert_false(p.stream_paused, "이어서")


func test_기지는_출격보다_작고_먹먹함() -> void:
	Music.set_run_time(0.0)
	var run_cut := Music.target_cutoff
	var run_db := Music.target_main_db
	Music.set_base()
	assert_true(Music.target_cutoff < run_cut, "더 먹먹")
	assert_true(Music.target_main_db < run_db, "더 작음")


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
