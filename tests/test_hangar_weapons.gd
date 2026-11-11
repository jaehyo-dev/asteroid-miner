extends TestCase
## 격납고 기본 무기 탭 (v0.8.0 시안 B 수정안): 탭, 무기 카드 글자, 장착(저장), 잠긴 무기 → 연구소 무기 가지.

const MainScene := preload("res://scenes/main.tscn")
const SAVE := "user://test_hangar_weapons_save.json"

var _old_path := ""


## 창 크기를 정해 연다 (헤드리스 창은 64x64라 그대로면 배치가 무너진다)
func _main(window := Vector2i(1280, 720)) -> Control:
	get_window().size = window
	_old_path = SaveData.path if _old_path == "" else _old_path
	SaveData.path = SAVE
	var s := SaveData.new()
	s.credits = 780
	s.upgrades = {"damage": 1, "w_shotgun": 1, "w_rail": 1}
	s.save_file()
	HangarView.tab = "fighter"
	HangarView.picked = ""
	var main: Control = MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	main.press("hangar")
	await wait_frames()
	return main


func _done(main: Control) -> void:
	main.queue_free()
	get_window().size = Vector2i(64, 64)
	await wait_frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	SaveData.path = _old_path


func test_처음은_전투기_탭이고_무기_카드는_숨김() -> void:
	var main: Control = await _main()
	var hv: HangarView = main.panel.view
	assert_eq(HangarView.tab, "fighter")
	assert_eq(hv.tab_buttons.size(), 2)
	assert_false(hv.cards.any(func(c: Button) -> bool: return c.visible), "카드 숨김")
	assert_false(hv.action_button.visible)
	await _done(main)


func test_무기_탭은_카드_5장과_버튼_글자() -> void:
	var main: Control = await _main()
	var hv: HangarView = main.panel.view
	hv.tab_buttons[1].pressed.emit()
	assert_eq(HangarView.tab, "weapon")
	assert_eq(hv.cards.size(), 5)
	assert_true(hv.cards.all(func(c: Button) -> bool: return c.visible))
	assert_eq(HangarView.picked, "pulse", "장착한 무기가 먼저 골라져 있음")
	assert_eq(hv.action_button.label, "장착 중")
	assert_true(hv.action_button.disabled)
	hv.cards[2].pressed.emit()  # 레일건 (해금)
	assert_eq(hv.action_button.label, "장착")
	hv.cards[3].pressed.emit()  # 플라스마 (잠김)
	assert_eq(hv.action_button.label, "연구소로 ▶")
	assert_eq([hv.weapon_state("pulse"), hv.weapon_state("rail"), hv.weapon_state("plasma")], ["on", "open", "lock"])
	await _done(main)


func test_장착하면_저장되고_능력치가_바뀜() -> void:
	var main: Control = await _main()
	var hv: HangarView = main.panel.view
	hv.select_tab("weapon")
	hv.pick("rail")
	hv.action_button.pressed.emit()
	assert_eq(main.panel.save.weapon, "rail")
	assert_eq(SaveData.load_file().weapon, "rail", "파일에 저장")
	assert_eq(hv.action_button.label, "장착 중")
	assert_eq(hv.weapon_state("pulse"), "open")
	await _done(main)


func test_잠긴_무기는_연구소_무기_가지_그_칸으로() -> void:
	var main: Control = await _main()
	var hv: HangarView = main.panel.view
	hv.select_tab("weapon")
	hv.pick("beam")
	hv.action_button.pressed.emit()
	await wait_frames()
	assert_eq(main.panel.kind, "research")
	var rv: ResearchView = main.panel.view
	assert_eq(rv.branch, "weapon")
	assert_eq(rv.selected, "%dc" % Research.tree("weapon").find("w_beam"))
	var y: int = rv.lay["cells"][rv.selected].y + rv.pan
	assert_true(y > 0 and y < rv.board.size.y, "고른 칸이 판 안에 보임 %d" % y)
	await _done(main)


func test_탭은_능력치_줄과_떨어지고_버튼에_해금_글자가_없음() -> void:
	for window in [Vector2i(1280, 720), Vector2i(844, 390)]:
		var main: Control = await _main(window)
		var hv: HangarView = main.panel.view
		var tabs: Rect2 = Rect2(hv.tab_buttons[0].position, hv.tab_buttons[0].size).merge(Rect2(hv.tab_buttons[1].position, hv.tab_buttons[1].size))
		var stats := Rect2(0, 0, int(hv._l["stats_w"]), int(hv._l["stats_h"]))
		assert_eq(main.panel.compact, window.y < 400, "%s 배치" % window)
		assert_false(tabs.grow(2).intersects(stats), "%s 탭과 능력치 칸 사이 여백" % window)
		var desc_x: int = int(hv._l["w"]) - int(hv._l["desc_w"])
		assert_true(tabs.end.x <= desc_x, "%s 탭이 설명 칸과 안 겹침" % window)
		for id in Weapons.ids():
			hv.pick(id)
			assert_false(hv.action_button.label.contains("해금"), "%s %s" % [window, id])
		await _done(main)
