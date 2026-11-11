extends TestCase
## 격납고 기본 무기 탭 (v0.8.0): 탭, 무기 카드 글자, 장착(저장), 잠긴 무기 구매, 능력치 ▲▼ 미리 보기.

const MainScene := preload("res://scenes/main.tscn")
const SAVE := "user://test_hangar_weapons_save.json"

var _old_path := ""


## 창 크기를 정해 연다 (헤드리스 창은 64x64라 그대로면 배치가 무너진다)
func _main(window := Vector2i(1280, 720), credits := 780) -> Control:
	get_window().size = window
	_old_path = SaveData.path if _old_path == "" else _old_path
	SaveData.path = SAVE
	var s := SaveData.new()
	s.credits = credits
	s.upgrades = {"damage": 1}
	s.weapons_owned = ["shotgun", "rail"]
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
	hv.cards[3].pressed.emit()  # 플라스마 (잠김, 1,200 > 780)
	assert_eq([hv.action_button.label, hv.action_button.cost], ["구매", 1200])
	assert_true(hv.action_button.disabled, "광물이 모자라면 꺼짐")
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


func test_잠긴_무기는_광물로_사면_바로_장착() -> void:
	var main: Control = await _main(Vector2i(1280, 720), 2000)
	var hv: HangarView = main.panel.view
	hv.select_tab("weapon")
	hv.pick("beam")
	assert_eq([hv.action_button.label, hv.action_button.cost, hv.action_button.disabled], ["구매", 1500, false])
	hv.action_button.pressed.emit()
	assert_eq(main.panel.kind, "hangar", "연구소로 가지 않음")
	assert_eq(main.panel.save.credits, 500)
	assert_eq(hv.weapon_state("beam"), "on", "사면 바로 장착")
	var saved := SaveData.load_file()
	assert_eq([saved.credits, saved.weapon, saved.weapons_owned.has("beam")], [500, "beam", true], "파일에 저장")
	assert_eq(hv.action_button.label, "장착 중")
	hv.pick("plasma")
	assert_true(hv.action_button.disabled, "남은 500으로는 1,200 못 삼")
	hv.action_button.pressed.emit()
	assert_eq(main.panel.save.credits, 500, "꺼진 버튼은 사지 않음")
	await _done(main)


func test_다른_무기를_고르면_능력치에_오르고_내림이_보임() -> void:
	var main: Control = await _main()
	var hv: HangarView = main.panel.view
	var names: Array = hv._stats.map(func(r: Dictionary) -> String: return r["name"])
	assert_eq(names, ["체력", "공격력", "공격 속도", "사거리", "이동 속도", "화물칸", "자석 범위", "사망 보존"])
	hv.pick("rail")
	assert_eq(hv.stat_delta(1), 0, "전투기 탭은 화살표 없음")
	hv.select_tab("weapon")
	hv.pick("rail")  # 레일건: 공격력 오름, 공격 속도 내림, 사거리 오름, 체력 그대로
	assert_eq([hv.stat_delta(0), hv.stat_delta(1), hv.stat_delta(2), hv.stat_delta(3)], [0, 1, -1, 1])
	hv.pick("pulse")
	assert_true(range(8).all(func(i: int) -> bool: return hv.stat_delta(i) == 0), "장착한 무기는 화살표 없음")
	hv.pick("rail")
	hv.action_button.pressed.emit()  # 장착하면 왼쪽 값이 새 무기 값이 되고 화살표가 사라짐
	assert_eq(hv._stats[3]["value"], "300")
	assert_eq(hv.stat_delta(3), 0)
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
		hv.select_tab("weapon")
		for i in hv.cards.size():
			var id: String = Weapons.ids()[i]
			hv.pick(id)
			assert_false(hv.action_button.label.contains("해금"), "%s %s" % [window, id])
			for row: Dictionary in hv._pick_stats:  # 능력치 이름·값·화살표가 한 줄에 겹치지 않음
				assert_true(WindowArt.width(row["name"]) + 4 + WindowArt.width(row["value"]) + 7 <= int(hv._l["stats_w"]) - 8, "%s %s %s" % [window, id, row["name"]])
			if main.panel.compact:  # 폰 카드: 짧은 이름이 카드 안에 들어감
				var short: String = Weapons.info(id)["short"]
				assert_true(WindowArt.width(short) <= hv.cards[i].size.x - 4, "%s 카드에 이름 %s" % [window, short])
				assert_true(WindowArt.width(Hud.thousands(Weapons.cost(id))) + 14 <= hv.cards[i].size.x - 4, "%s 카드에 가격" % id)
		await _done(main)
