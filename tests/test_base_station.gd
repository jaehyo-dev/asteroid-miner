extends TestCase
## 기지 정거장: 칸 배치, 건설 예정, 끌기 범위, 출격 버튼, 끌기 판정, 정수 배율, 끌어서 놓으면 안 눌림, 안내 한 번.

const MainScene := preload("res://scenes/main.tscn")
const PC := Vector2(640, 360)
const PHONE := Vector2(844, 390)


func _main(hint_seen := true) -> Control:
	var s := SaveData.new()
	s.drag_hint_seen = hint_seen
	s.save_file()
	var main: Control = MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	return main


func _mouse(main: Control, stage_pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = stage_pos * main.stage.scale
	main._input(e)


func _motion(main: Control, stage_pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = stage_pos * main.stage.scale
	main._input(e)


# ── 칸 배치 ────────────────────────────────────────────

func test_건물_칸은_겹치지_않고_착륙장_3칸을_피함() -> void:
	var seen := {}
	for id in BaseLayout.CELLS:
		var c: Vector2i = BaseLayout.CELLS[id]
		assert_false(seen.has(c), "%s 칸 겹침" % id)
		seen[c] = true
		assert_true(c.x != 0, "%s 착륙장 자리" % id)
	for large in [false, true]:
		for r: int in BaseLayout.PAD_ROWS:
			var cell := Vector2i(0, r)
			assert_true(BaseLayout.station_cells(false).has(cell), "착륙장 %s" % cell)
		assert_eq(BaseLayout.cell_center(Vector2i.ZERO, large), Vector2.ZERO, "착륙장 고리가 원점")


func test_모든_건물에_칸과_누르는_자리가_있고_겹치지_않음() -> void:
	for large in [false, true]:
		var touch := {}
		for id in BaseLayout.IDS:
			touch[id] = BaseLayout.touch_rect(id, large)
			var min_side: float = 44.0
			assert_true(touch[id].size.x >= min_side and touch[id].size.y >= min_side, "%s 누르기 크기 %s" % [id, touch[id].size])
		for i in BaseLayout.IDS.size():
			for j in range(i + 1, BaseLayout.IDS.size()):
				var a: String = BaseLayout.IDS[i]
				var b: String = BaseLayout.IDS[j]
				assert_false(touch[a].intersects(touch[b]), "%s %s와 %s 겹침" % [large, a, b])


func test_건설_예정은_다음_2칸만이고_건물이_생기면_다음_칸() -> void:
	var built: Array = BaseLayout.CELLS.values()
	var slots := BaseLayout.next_slots(built)
	assert_eq(slots.size(), 2)
	assert_eq(slots[0], BaseLayout.NEXT_SLOTS[0])
	built.append(slots[0])
	var after := BaseLayout.next_slots(built)
	assert_false(after.has(slots[0]), "지은 칸은 빠짐")
	assert_eq(after[0], slots[1])
	# 다 채우면 빈 칸 없음
	assert_eq(BaseLayout.next_slots(built + Array(BaseLayout.NEXT_SLOTS)).size(), 0)


func test_건설_예정_칸은_정거장에_이어져_있음() -> void:
	var built: Array = BaseLayout.CELLS.values()
	built.append(Vector2i(0, -1))
	built.append(Vector2i(0, 0))
	built.append(Vector2i(0, 1))
	for s in BaseLayout.NEXT_SLOTS:
		var touching: bool = built.has(s + Vector2i.LEFT) or built.has(s + Vector2i.RIGHT) or built.has(s + Vector2i.UP) or built.has(s + Vector2i.DOWN)
		assert_true(touching, "%s가 떨어져 있음" % s)
		built.append(s)


func test_둘레는_바깥_변만_있고_안쪽_변은_없음() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var segs := BaseLayout.outline(cells, false)
	assert_eq(segs.size(), 6, "두 칸이 붙으면 맞닿은 2변이 빠짐")
	var mid := BaseLayout.cell_block(Vector2i(0, 0), false).end.x
	for seg in segs:
		assert_false(seg[0].x == mid and seg[1].x == mid, "안쪽 변")


# ── 끌어서 둘러보기 범위 ────────────────────────────────

func test_처음에는_착륙장이_가운데이고_범위_안() -> void:
	for view: Vector2 in [PC, PHONE, Vector2(1280, 360), Vector2(683, 328)]:
		for busy in [false, true]:
			var large: bool = view == PHONE
			var map := BaseLayout.map_rect(BaseLayout.station_cells(busy), large)
			assert_eq(BaseLayout.clamp_cam(Vector2.ZERO, map, view), Vector2.ZERO, "%s %s" % [view, busy])


func test_지도_끝에서_멈춤_지도가_작으면_안_움직임() -> void:
	var map := Rect2(-500, -100, 1000, 200)
	var view := PC
	var o := BaseLayout.center_origin(view)
	var left := BaseLayout.clamp_cam(Vector2(-99999, 0), map, view)
	assert_eq(o.x + left.x + map.end.x, view.x, "지도 오른쪽 끝이 화면 오른쪽 끝에")
	var right := BaseLayout.clamp_cam(Vector2(99999, 0), map, view)
	assert_eq(o.x + right.x + map.position.x, 0.0, "지도 왼쪽 끝이 화면 왼쪽 끝에")
	assert_eq(BaseLayout.clamp_cam(Vector2(0, 99999), map, view).y, 0.0, "세로는 화면보다 작아 그대로")
	assert_false(BaseLayout.can_pan(Rect2(-100, -100, 200, 200), view), "작은 지도")
	assert_true(BaseLayout.can_pan(map, view), "큰 지도")


func test_키보드로_고른_칸이_보이게_따라감() -> void:
	var map := Rect2(-800, -100, 1600, 200)
	var view := PC
	var r := Rect2(600, -40, 100, 80)
	var cam := BaseLayout.reveal_cam(Vector2.ZERO, r, map, view, 28.0, 25.0)
	var o := BaseLayout.center_origin(view) + cam
	assert_true(o.x + r.end.x <= view.x, "오른쪽이 화면 안")
	assert_eq(BaseLayout.reveal_cam(cam, r, map, view, 28.0, 25.0), cam, "이미 보이면 안 움직임")


func test_출격_버튼은_어디로_끌어도_화면_안() -> void:
	var button := Vector2(100, 44)
	for anchor: Vector2 in [Vector2(320, 200), Vector2(-500, 200), Vector2(5000, 200), Vector2(320, -300), Vector2(320, 900)]:
		var p := BaseLayout.sortie_pos(anchor, button, PC, 28.0, 25.0)
		assert_true(Rect2(Vector2.ZERO, PC).encloses(Rect2(p, button)), "%s → %s" % [anchor, p])


# ── 끌기 판정 ──────────────────────────────────────────

func test_문턱_안의_움직임은_누름이고_넘으면_끌기() -> void:
	var d := BaseDrag.new()
	d.threshold = 8.0
	d.press(Vector2(100, 100))
	assert_eq(d.move(Vector2(105, 100)), Vector2.ZERO)
	assert_false(d.dragged, "문턱 안")
	assert_eq(d.move(Vector2(120, 100)), Vector2.ZERO, "넘는 순간은 튀지 않게 0")
	assert_true(d.dragged, "문턱 넘음")
	assert_eq(d.move(Vector2(130, 95)), Vector2(10, -5))
	d.release()
	assert_eq(d.move(Vector2(200, 100)), Vector2.ZERO, "놓은 뒤에는 무시")
	d.press(Vector2.ZERO)
	assert_false(d.dragged, "새 누름")


func test_끌었다_놓으면_건물_창이_안_열리고_다음_누름은_열림() -> void:
	var main: Control = await _main()
	var start: Vector2 = main.world.position + BaseLayout.touch_rect("research", main.view.large).get_center()
	_mouse(main, start, true)
	var before: Vector2 = main.cam
	_motion(main, start + Vector2(40, 0))
	_motion(main, start + Vector2(80, 0))
	assert_true(main.cam != before, "화면이 움직임")
	main.press("research")  # 버튼이 놓일 때 부르는 것과 같음
	assert_false(main.panel.visible, "끌기 중에는 안 열림")
	_mouse(main, start + Vector2(80, 0), false)
	await wait_frames()
	main.press("research")
	assert_true(main.panel.visible, "끌기가 끝나면 다시 열림")
	main.queue_free()


func test_창이_열려_있으면_안_끌림() -> void:
	var main: Control = await _main()
	main.press("research")
	await wait_frames()
	var before: Vector2 = main.cam
	_mouse(main, Vector2(300, 200), true)
	_motion(main, Vector2(100, 200))
	assert_eq(main.cam, before)
	_mouse(main, Vector2(100, 200), false)
	main.queue_free()


func test_고정_버튼_위에서는_끌기를_시작하지_않음() -> void:
	var main: Control = await _main()
	var s: Button = main.hud.sortie
	_mouse(main, s.position + s.size / 2.0, true)
	assert_false(main.drag.down, "출격 버튼 위")
	_mouse(main, s.position + s.size / 2.0, false)
	main.queue_free()


func test_출격하면_끌어_둔_화면이_착륙장으로_돌아옴() -> void:
	var main: Control = await _main()
	main._apply_cam(Vector2(-99999, 0))
	assert_true(main.cam != Vector2.ZERO, "끌어 둠")
	main.launch()
	await get_tree().create_timer(0.8).timeout
	assert_eq(main.cam, Vector2.ZERO, "가운데로")
	main.queue_free()


func test_출격_버튼을_누르면_이륙() -> void:
	var main: Control = await _main()
	main.hud.sortie.pressed.emit()
	assert_true(main.launching)
	assert_true(main.hud.sortie.disabled, "이륙 중에는 못 누름")
	main.queue_free()


# ── 정수 배율 ──────────────────────────────────────────

func test_창_크기별_기지_정수_배율() -> void:
	assert_eq(App.base_pixel_scale(Vector2i(1280, 720)), 2)
	assert_eq(App.base_pixel_scale(Vector2i(844, 390)), 1)
	assert_eq(App.base_pixel_scale(Vector2i(2532, 1170)), 3)
	assert_eq(App.base_pixel_scale(Vector2i(1366, 657)), 2)
	assert_eq(App.base_pixel_scale(Vector2i(320, 180)), 1, "아주 작아도 1 이상")


func test_무대의_최종_배율이_정수이고_글자도_고정() -> void:
	var main: Control = await _main()
	var k := App.base_pixel_scale(main.get_window().size)
	var final: Vector2 = (main.stage.get_global_transform_with_canvas() * Transform2D()).get_scale() * main.get_tree().root.get_final_transform().get_scale()
	assert_true(is_equal_approx(final.x, float(k)) and is_equal_approx(final.y, float(k)), "최종 배율 %s, k %d" % [final, k])
	assert_eq(main.stage.theme.default_font.oversampling, 1.0, "글자를 격자대로")
	assert_eq(fmod(main.world.position.x, 1.0), 0.0, "그림 픽셀에 맞음")
	main.queue_free()


# ── 안내 ───────────────────────────────────────────────

func test_안내는_처음_한_번만_끌면_사라짐() -> void:
	var main: Control = await _main(false)
	var pannable := BaseLayout.can_pan(main.view.map, main.stage.size)
	assert_eq(main.hud.hint.visible, pannable, "끌 수 있으면 표시")
	assert_true(not pannable or SaveData.load_file().drag_hint_seen, "저장")
	_mouse(main, Vector2(300, 300), true)
	_motion(main, Vector2(200, 300))
	assert_false(main.hud.hint.visible, "끌면 사라짐")
	_mouse(main, Vector2(200, 300), false)
	main.queue_free()
	await wait_frames()
	var again: Control = MainScene.instantiate()
	again.auto_start = false
	add_child(again)
	await wait_frames()
	assert_false(again.hud.hint.visible, "다시 들어와도 없음")
	again.queue_free()


func test_저장에_안내_본_기록이_남고_옛_저장은_안_본_것() -> void:
	var s := SaveData.new()
	s.drag_hint_seen = true
	assert_true(SaveData.from_dict(s.to_dict()).drag_hint_seen)
	assert_false(SaveData.from_dict({}).drag_hint_seen, "옛 저장")
	assert_false(SaveData.from_dict({"drag_hint_seen": 1}).drag_hint_seen, "이상한 값")


# ── 그림 ───────────────────────────────────────────────

func test_쉬익_소리_길이가_앞면이_보일_때까지와_같음() -> void:
	var swell: AudioStream = load("res://assets/sfx/game/card_swell.wav")
	assert_true(absf(swell.get_length() - (Juice.CARD_DROP_TIME + Juice.CARD_FLIP_TIME * 0.5)) < 0.01, "쉬익 %f초" % swell.get_length())
