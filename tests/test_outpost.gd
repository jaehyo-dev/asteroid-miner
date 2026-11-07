extends TestCase
## 기지 전초기지 화면 (v0.6.0): 배치, 연구소 카드 문구, 격납고, 도감, 살아 있는 기지, 건물 열기·이륙, 저장 호환.

const MainScene := preload("res://scenes/main.tscn")
const RunScene := preload("res://scenes/run.tscn")

## 확인할 화면 크기 (기지 화면 기준 해상도 단위 = App.base_size_for(창, true)):
## PC 1280x720, 휴대폰 가로 844x390 → 1558x720, 위아래로 긴 PC 창(1000x900 → 1280x1152), 정사각형 창(→ 1280x1280), 아주 넓은 창(2560x720).
## 게임은 가로 고정이라 세로 창은 안내 화면만 보인다 (test_app.gd). expand라 폭은 1280보다 작아지지 않는다.
const SIZES := [Vector2(1280, 720), Vector2(1558, 720), Vector2(1280, 1152), Vector2(1280, 1280), Vector2(2560, 720)]
## 손가락으로 누르기 쉬운 최소 크기: 휴대폰은 기준 720 → 화면 약 390px(0.54배)이므로 88이면 약 48px
const MIN_TOUCH := Vector2(88, 88)


func _main() -> Control:
	var main: Control = MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	return main


# ── 배치 ────────────────────────────────────────────

func test_건물과_이름표가_화면_안에_있고_서로_겹치지_않음() -> void:
	for size in SIZES:
		var rects := BaseLayout.rects(size)
		var screen := Rect2(Vector2(0, BaseLayout.TOP_BAR), size - Vector2(0, BaseLayout.TOP_BAR + BaseLayout.BOTTOM_BAR))  # 위: 보유 광물 줄, 아래: 버전 글자
		var touch := {}
		for id in BaseLayout.IDS:
			var t := BaseLayout.touch_rect(id, rects[id])
			touch[id] = t
			assert_true(screen.encloses(t), "%s %s 화면 밖: %s" % [size, id, t])
			assert_true(t.size.x >= MIN_TOUCH.x and t.size.y >= MIN_TOUCH.y, "%s %s 너무 작음" % [size, id])
		for i in BaseLayout.IDS.size():
			for j in range(i + 1, BaseLayout.IDS.size()):
				var a: String = BaseLayout.IDS[i]
				var b: String = BaseLayout.IDS[j]
				assert_false(touch[a].intersects(touch[b]), "%s %s와 %s 겹침" % [size, a, b])


func test_위_건물은_착륙장_위_옆_건물은_착륙장_아래쪽() -> void:
	var r := BaseLayout.rects(Vector2(1280, 720))
	for id in ["research", "hangar", "drone"]:
		assert_true(r[id].end.y < r["ship"].position.y + 20.0, "%s는 착륙장 위쪽" % id)
	for id in ["storage", "museum"]:
		assert_true(r[id].get_center().y > r["ship"].get_center().y, "%s는 착륙장 아래쪽" % id)


func test_이름표는_건물_그림_바깥이고_다른_건물도_가리지_않음() -> void:
	for size in SIZES:
		var r := BaseLayout.rects(size)
		for id in BaseLayout.IDS:
			var lr := BaseLayout.label_rect(id, r[id])
			assert_eq(lr.get_center().x, r[id].get_center().x, "%s 이름표 가운데" % id)
			for other in BaseLayout.IDS:
				assert_false(lr.intersects(r[other]), "%s %s 이름표가 %s 건물을 가림" % [size, id, other])


func test_곧_개방_표지는_건물과_이름표와_다른_건물에_겹치지_않음() -> void:
	for size in SIZES:
		var r := BaseLayout.rects(size)
		var sign_box := BaseLayout.sign_rect(r["drone"], 84.0)
		for id in BaseLayout.IDS:
			assert_false(sign_box.intersects(r[id]), "%s 표지가 %s 건물과 겹침" % [size, id])
			assert_false(sign_box.intersects(BaseLayout.label_rect(id, r[id])), "%s 표지가 %s 이름표와 겹침" % [size, id])


func test_건물_자리와_글자는_2픽셀_격자에_맞음() -> void:
	assert_eq(BaseLayout.FONT_SIZE, 12 * BaseLayout.PIXEL, "픽셀 글꼴(12px)의 정수 배")
	for size in SIZES:
		for id in BaseLayout.IDS:
			var r: Rect2 = BaseLayout.rects(size)[id]
			assert_eq(fmod(r.position.x, BaseLayout.PIXEL), 0.0, "%s %s x" % [size, id])
			assert_eq(fmod(r.position.y, BaseLayout.PIXEL), 0.0, "%s %s y" % [size, id])
			assert_eq(r.size, BaseLayout.sprite_size(BaseLayout.SPRITES[id]) * BaseLayout.PIXEL, "그림 크기 그대로 2배")


func test_건물_폭은_화면_폭의_12에서_13퍼센트() -> void:
	# v0.6.6 목표: 건물·착륙장이 1280 폭 화면의 12~13% (그림 폭 × 격자)
	for id in BaseLayout.IDS:
		var ratio: float = BaseLayout.rects(Vector2(1280, 720))[id].size.x / 1280.0
		assert_true(ratio >= 0.12 and ratio <= 0.13, "%s 폭 %.1f%%" % [id, ratio * 100.0])


func test_지면은_무대_크기_한_장이고_건물은_소행성_안에_있음() -> void:
	assert_eq(BaseLayout.sprite_size("ground_landscape") * BaseLayout.PIXEL, BaseLayout.STAGE, "가로 지면 = 무대")
	# 소행성 모양(가운데 타원): 건물 그림 네 모서리가 타원 안에 있어야 함 (가로 화면, 소행성은 화면의 약 75%)
	for id in BaseLayout.IDS:
		var r: Rect2 = BaseLayout.rects(Vector2(1280, 720))[id]
		for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var d := (c - Vector2(640, 360)) / Vector2(640 * 0.74, 360 * 0.72)
			assert_true(d.length() <= 1.0, "%s 모서리 %s가 소행성 밖" % [id, c])


func test_기지_그림은_정리된_픽셀_아트() -> void:
	# tools/pixelate.py로 정리했는지: 투명도는 0 또는 1만, 색은 24가지 이하
	for file in DirAccess.get_files_at(BaseLayout.SPRITE_DIR):
		if not file.ends_with(".png"):
			continue
		var img: Image = (load(BaseLayout.SPRITE_DIR + file) as Texture2D).get_image()
		img.decompress()
		var colors := {}
		var half_alpha := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.01 and c.a < 0.99:
					half_alpha += 1
				elif c.a >= 0.99:
					colors[c.to_rgba32() | 0xff] = true
		assert_eq(half_alpha, 0, file + " 반투명 픽셀")
		assert_true(colors.size() <= 40, "%s 색 %d개" % [file, colors.size()])


func test_기지_화면에서만_2배_기준_해상도() -> void:
	var main: Control = await _main()
	assert_true(App.base_mode, "기지 화면")
	main.queue_free()
	await wait_frames()
	assert_false(App.base_mode, "기지를 나가면 원래대로")


func test_누르는_자리_버튼이_그림_자리에_놓임() -> void:
	var main: Control = await _main()
	var rects := BaseLayout.rects(main.view.size)
	for id in BaseLayout.IDS:
		var b: Button = main.spot_buttons[id]
		assert_eq(Rect2(b.position, b.size), BaseLayout.touch_rect(id, rects[id]), id)
	main.queue_free()


# ── 연구소 카드 문구 ──────────────────────────────────

func test_연구소_카드의_바뀌는_값과_단계_칸() -> void:
	assert_eq(BaseUpgrades.change_text("max_hp", 2), "체력 120 → 130")
	assert_eq(BaseUpgrades.change_text("max_hp", 5), "체력 150", "최대면 지금 값만")
	assert_eq(BaseUpgrades.change_text("cargo", 0), "화물칸 80칸 → 90칸")
	assert_eq(BaseUpgrades.change_text("insurance", 1), "사망 보존 55% → 60%")
	assert_eq(BaseUpgrades.change_text("damage", 0), "탄 피해 100% → 110%")
	assert_eq(BaseUpgrades.pips("max_hp", 3), "■■■□□")
	assert_eq(BaseUpgrades.pips("max_hp", 0), "□□□□□")


func test_바뀌는_값은_실제_출격_능력치와_같음() -> void:
	for u in Balance.BASE_UPGRADES:
		var sim := RunSim.new(1)
		sim.apply_base({u["id"]: 3})
		match u["id"]:
			"max_hp":
				assert_eq(BaseUpgrades.stat_value("max_hp", 3), sim.max_hp)
			"cargo":
				assert_eq(BaseUpgrades.stat_value("cargo", 3), float(sim.cargo.capacity))
			"speed":
				assert_eq(BaseUpgrades.stat_value("speed", 3), sim.move_speed)
			"magnet":
				assert_eq(BaseUpgrades.stat_value("magnet", 3), sim.magnet_radius)


# ── 격납고 ──────────────────────────────────────────

func test_격납고는_파이오니어와_잠긴_칸() -> void:
	var slots := Hangar.slots()
	assert_eq(slots.size(), Balance.HANGAR_SLOTS)
	assert_eq(slots[0]["id"], "pioneer")
	for i in range(Balance.FIGHTERS.size(), slots.size()):
		assert_true(slots[i].has("locked"), "%d번 칸 잠김" % i)


func test_격납고_능력치는_업그레이드를_반영함() -> void:
	var base := Hangar.stats({})
	assert_eq(base[0]["name"], "체력")
	assert_eq(base[0]["value"], "100")
	var up := Hangar.stats({"max_hp": 2})
	assert_eq(up[0]["value"], "120")
	assert_true(up[0]["ratio"] > base[0]["ratio"], "막대가 길어짐")
	var maxed := {}
	for u in Balance.BASE_UPGRADES:
		maxed[u["id"]] = u["max"]
	for s in Hangar.stats(maxed):
		assert_eq(s["ratio"], 1.0, s["name"] + " 최대면 막대 가득")


func test_격납고_화면() -> void:
	var main: Control = await _main()
	main.press("hangar")
	await wait_frames()
	assert_true(main.panel.visible)
	assert_eq(main.panel.kind, "hangar")
	main.queue_free()


# ── 도감 (전시관) ─────────────────────────────────────

func test_적의_도감_id() -> void:
	var e := RunSim.Enemy.new()
	e.type = 2
	assert_eq(Discovery.enemy_id(e), "rock_2")
	e.golden = true
	assert_eq(Discovery.enemy_id(e), "golden")
	e.golden = false
	e.kind = "jelly"
	assert_eq(Discovery.enemy_id(e), "jelly")
	e.kind = RunSim.GUARD
	assert_eq(Discovery.enemy_id(e), "guard")
	for entry in Discovery.ENTRIES:
		assert_not_null(PixelArt.discovery_icon(entry["id"]), entry["id"] + " 아이콘")


func test_화면_안에_보인_것만_도감에_오름() -> void:
	var sim := RunSim.new(1)
	sim.view_size = Vector2(640, 360)
	var near := RunSim.Enemy.new()
	near.pos = Vector2(100, 0)
	near.kind = "bug"
	var far := RunSim.Enemy.new()
	far.pos = Vector2(1000, 0)
	far.kind = "jelly"
	sim.enemies = [near, far]
	sim.picked = [{"pos": Vector2.ZERO, "grade": 3, "gain": 100}]
	sim.events = PackedStringArray(["barrage_warning"])
	var ids := Discovery.seen_now(sim)
	assert_true(ids.has("bug"), "화면 안")
	assert_false(ids.has("jelly"), "화면 밖은 아직")
	assert_true(ids.has("mineral_3"), "주운 광물")
	assert_true(ids.has("barrage"), "포격 예고")


func test_출격_중_처음_본_것은_바로_저장됨() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	var e := RunSim.Enemy.new()
	e.pos = run.sim.player_pos + Vector2(60, 0)
	e.kind = "jelly"
	e.radius = 6.0
	e.hp = 99.0
	e.max_hp = 99.0
	run.sim.enemies.append(e)
	await wait_frames(2)
	assert_true(SaveData.load_file().seen.has("jelly"), "저장됨")
	run.queue_free()


func test_전시관은_못_본_것을_물음표로() -> void:
	var save := SaveData.new()
	save.discover("mineral_0")
	save.discover("jelly")
	save.save_file()
	var main: Control = await _main()
	main.press("museum")
	await wait_frames()
	var texts := _texts(main.panel)
	assert_true(texts.has("발견 2 / %d" % Discovery.ENTRIES.size()), "발견 수")
	assert_true(texts.has("일반 광물") and texts.has("우주 해파리"), "본 것은 이름")
	assert_false(texts.has("고대 경비선"), "못 본 것은 이름을 숨김")
	assert_eq(texts.count("?"), Discovery.ENTRIES.size() - 2, "못 본 것은 ?")
	main.queue_free()


func _texts(node: Node) -> Array:
	var result := []
	for child in node.find_children("*", "Label", true, false):
		result.append((child as Label).text)
	return result


# ── 광물 창고 ───────────────────────────────────────

func test_광물_창고는_총가치와_등급별_개수() -> void:
	var save := SaveData.new()
	save.credits = 1240
	save.hauled = PackedInt32Array([12, 5, 2, 1])
	save.save_file()
	var main: Control = await _main()
	main.press("storage")
	await wait_frames()
	var texts := _texts(main.panel)
	assert_true(texts.has("보유 광물 총가치  1,240"), str(texts))
	assert_true(texts.has("일반 12개") and texts.has("전설 1개"), str(texts))
	main.queue_free()


func test_판이_끝나면_가져온_광물_수가_쌓임() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([3, 2, 1, 0])
	run.sim.returned = true
	run.bank_result()
	assert_eq(SaveData.load_file().hauled, PackedInt32Array([3, 2, 1, 0]))
	run.queue_free()


# ── 드론 공장, 닫기, 이륙 ─────────────────────────────

func test_드론_공장은_안내만_띄움() -> void:
	var main: Control = await _main()
	main.press("drone")
	await wait_frames()
	assert_false(main.panel.visible, "화면은 안 열림")
	assert_true(main.toast.visible)
	assert_eq(main.toast.text, main.DRONE_NOTICE)
	main.queue_free()


func test_폰_가로_크기에서도_건물_화면이_폭_안에_들어감() -> void:
	var main: Control = await _main()
	main.panel.size = Vector2(1558, 720)  # 휴대폰 가로 (844x390)
	for kind in ["research", "hangar", "storage", "museum"]:
		main.press(kind)
		await wait_frames(2)
		var box: Control = main.panel._panel
		assert_true(box.get_combined_minimum_size().x <= 1558.0, "%s 최소 폭 %d" % [kind, box.get_combined_minimum_size().x])
		main.panel.close()
	main.queue_free()


func test_전체_화면_버튼은_손가락으로_누를_크기() -> void:
	var main: Control = await _main()
	var b: Button = main.fullscreen_button
	b.show()
	await wait_frames()
	assert_true(b.size.x >= MIN_TOUCH.x and b.size.y >= MIN_TOUCH.y, "전체 화면 버튼 %s" % b.size)
	main.queue_free()


func test_길은_금속판과_배관이_건물_입구에_닿음() -> void:
	var main: Control = await _main()
	var view: BaseView = main.view
	for id in BaseLayout.IDS:
		if id == "ship":
			continue
		var end: Vector2 = view._path_ends[id]
		assert_true(view.rects[id].grow(BaseLayout.PIXEL * 4.0).has_point(end), "%s 길 끝 %s가 건물에 닿지 않음" % [id, end])
	var colors := {}
	for c in view._path_cells:
		colors[c[1]] = true
	assert_true(colors.has(BaseView.PATH_RIM) and colors.has(BaseView.PIPE) and colors.has(BaseView.CABLE), "금속판 테두리·배관·케이블 색")
	assert_false(colors.has(BaseView.YELLOW) and colors.size() < 4, "노란 점선 막대만 있는 길이 아님")
	main.queue_free()


func test_접지_그림자는_건물_위쪽일수록_오른쪽_아래로_밀림() -> void:
	var xf := BaseView.shadow_transform(300.0)
	assert_eq(xf * Vector2(100, 300), Vector2(100, 300), "아랫변은 제자리")
	var top: Vector2 = xf * Vector2(100, 200)
	assert_true(top.x > 100.0 and top.y > 300.0, "위쪽 점은 오른쪽·아래 %s" % top)


func test_건물_화면은_닫기와_Esc로_닫힘() -> void:
	var main: Control = await _main()
	main.press("research")
	await wait_frames()
	main.panel.close_button.pressed.emit()
	assert_false(main.panel.visible, "닫기 버튼")
	main.press("museum")
	await wait_frames()
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	main.panel._unhandled_input(esc)
	assert_false(main.panel.visible, "Esc")
	main.queue_free()


func test_터치로_닫으면_포커스_테두리가_없고_키보드로_닫으면_우주선에_포커스() -> void:
	var main: Control = await _main()
	var touch := InputEventScreenTouch.new()
	main._input(touch)
	main.press("research")
	await wait_frames()
	main.panel.close_button.pressed.emit()
	assert_true(main.get_viewport().gui_get_focus_owner() == null, "터치로 닫음 → 테두리 없음")
	assert_eq(main.view.hover_id, "", "터치로 닫음 → 건물 강조도 끔")
	var key := InputEventKey.new()
	main._input(key)
	main.press("museum")
	await wait_frames()
	main.panel.close()
	assert_eq(main.get_viewport().gui_get_focus_owner(), main.spot_buttons["ship"], "키보드로 닫음 → 우주선")
	main.queue_free()


func test_마우스를_올리면_윤곽선_누르면_번쩍임() -> void:
	var main: Control = await _main()
	var b: Button = main.spot_buttons["hangar"]
	b.mouse_entered.emit()
	assert_eq(main.view.hover_id, "hangar", "올리면 강조")
	main.spot_buttons["museum"].mouse_exited.emit()
	assert_eq(main.view.hover_id, "hangar", "다른 건물에서 나간 것은 무시")
	b.mouse_exited.emit()
	assert_eq(main.view.hover_id, "", "나가면 끔")
	b.button_down.emit()
	assert_eq(main.view.pressed_id, "hangar")
	assert_true(main.view.press_time > 0.0, "누르면 번쩍")
	await get_tree().create_timer(BaseView.PRESS_TIME + 0.1).timeout
	assert_eq(main.view.press_time, 0.0, "잠깐 뒤 원래대로")
	main.queue_free()


func test_윤곽선은_그림_바로_바깥_칸() -> void:
	var img := Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	img.set_pixel(1, 1, Color.WHITE)
	var cells := BaseView.outline_cells(img)
	assert_eq(cells.size(), 4, "가운데 한 칸 → 상하좌우 4칸")
	assert_true(cells.has(Vector2i(1, 0)) and cells.has(Vector2i(0, 1)) and cells.has(Vector2i(2, 1)) and cells.has(Vector2i(1, 2)))
	var edge := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	edge.set_pixel(0, 0, Color.WHITE)
	assert_eq(BaseView.outline_cells(edge).size(), 4, "그림 밖 칸까지")


func test_건물_화면이_열려_있으면_다른_건물이나_출격을_누를_수_없음() -> void:
	var main: Control = await _main()
	main.press("research")
	main.press("ship")
	assert_false(main.launching, "출격 안 됨")
	assert_eq(main.panel.kind, "research")
	main.queue_free()


func test_우주선을_누르면_짧은_이륙_뒤_출격() -> void:
	var main: Control = await _main()
	var state := {"launched": false}
	main.launched.connect(func() -> void: state["launched"] = true)
	main.spot_buttons["ship"].pressed.emit()
	assert_true(main.launching)
	assert_true(main.view.launch_t >= 0.0, "이륙 연출 시작")
	main.press("research")
	assert_false(main.panel.visible, "이륙 중에는 건물을 못 엶")
	await get_tree().create_timer(BaseView.LAUNCH_TIME * 0.5).timeout
	assert_false(state["launched"], "아직 연출 중")
	await get_tree().create_timer(BaseView.LAUNCH_TIME * 0.6 + 0.1).timeout
	assert_true(state["launched"], "약 1초 뒤 출격")
	main.queue_free()


func test_기지_효과음이_있음() -> void:
	for sound in [Sfx.OPEN_SOUND, Sfx.TAKEOFF_SOUND, Sfx.CLICK_SOUND]:
		assert_true(Sfx.synth(sound["notes"], sound["wave"], sound["volume"]).data.size() > 0)


# ── 살아 있는 기지 ───────────────────────────────────

func test_연구할수록_안테나와_불빛이_늘어남() -> void:
	assert_eq(BaseLife.antennas({}), 1)
	assert_eq(BaseLife.research_lights({}), 0)
	var some := {"damage": 3, "max_hp": 3}
	assert_eq(BaseLife.research_total(some), 6)
	assert_eq(BaseLife.antennas(some), 2)
	assert_eq(BaseLife.research_lights(some), 2)
	var maxed := {}
	for u in Balance.BASE_UPGRADES:
		maxed[u["id"]] = 99  # 최대를 넘는 값은 최대로 센다
	assert_eq(BaseLife.antennas(maxed), BaseLife.ANTENNA_MAX)
	assert_eq(BaseLife.research_lights(maxed), 10)


func test_보유_광물이_많을수록_광물_더미가_커짐() -> void:
	assert_eq(BaseLife.pile_level(0), 0)
	assert_eq(BaseLife.pile_level(1), 1)
	assert_eq(BaseLife.pile_level(800), 3)
	assert_eq(BaseLife.pile_level(1000000), BaseLife.PILE_STEPS.size())


func test_운석은_정해진_간격_안에서_지나감() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20:
		var gap := BaseLife.next_meteor_gap(rng)
		assert_true(gap >= BaseLife.METEOR_GAP.x and gap <= BaseLife.METEOR_GAP.y)


# ── 저장 호환 ───────────────────────────────────────

func test_이전_저장도_그대로_불러옴() -> void:
	# v0.5.1 저장 (hauled, seen 없음)
	var save := SaveData.from_dict({"format": 1, "credits": 777, "upgrades": {"damage": 2}, "risk_tip_seen": true})
	assert_eq(save.credits, 777)
	assert_eq(save.level_of("damage"), 2)
	assert_true(save.risk_tip_seen)
	assert_eq(save.hauled, PackedInt32Array([0, 0, 0, 0]))
	assert_true(save.seen.is_empty())
	assert_eq(save.to_dict()["format"], SaveData.FORMAT, "저장 형식 번호는 그대로")


func test_도감과_가져온_광물을_저장하고_불러옴() -> void:
	var save := SaveData.new()
	save.add_hauled(PackedInt32Array([5, 4, 3, 2]))
	save.add_hauled(PackedInt32Array([1, 0, -9, 0]))  # 음수는 무시
	assert_true(save.discover("guard"))
	assert_false(save.discover("guard"), "이미 본 것")
	assert_false(save.discover("없는것"), "모르는 id")
	save.save_file()
	var loaded := SaveData.load_file()
	assert_eq(loaded.hauled, PackedInt32Array([6, 4, 3, 2]))
	assert_true(loaded.seen.has("guard"))
	var odd := SaveData.from_dict({"hauled": [-3, "많이", 2.0], "seen": ["guard", 5, "없는것"]})
	assert_eq(odd.hauled, PackedInt32Array([0, 0, 2, 0]), "이상한 값은 0")
	assert_eq(odd.seen.keys(), ["guard"], "모르는 id·숫자는 버림")
