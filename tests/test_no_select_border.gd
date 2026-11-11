extends TestCase
## 선택 표시로 테두리 선을 쓰지 않는다 (2026-11-12 사용자 결정, ART_BIBLE): 기지·모든 건물 창·레벨업 카드·메뉴의
## 버튼·탭·카드에 테두리가 있는 스타일이나 비어 있지 않은 focus 스타일이 있으면 실패한다.
## (그림으로 직접 그리는 테두리는 tools/test_ui_rules.py가 소스에서 막는다)

const MainScene := preload("res://scenes/main.tscn")
const RunScene := preload("res://scenes/run.tscn")
const SAVE := "user://test_no_select_border_save.json"
const STATES := ["normal", "hover", "pressed", "disabled", "hover_pressed", "normal_mirrored", "hover_mirrored", "pressed_mirrored", "disabled_mirrored", "hover_pressed_mirrored"]


## 버튼 하나의 문제 목록: focus가 비어 있지 않음, 테두리가 있는 StyleBoxFlat
static func problems(b: Control) -> Array[String]:
	var out: Array[String] = []
	if b.focus_mode != Control.FOCUS_NONE and b.has_theme_stylebox("focus"):
		var f := b.get_theme_stylebox("focus")
		if not (f is StyleBoxEmpty):
			out.append("%s focus 스타일이 비어 있지 않음 (%s)" % [b.get_path(), f])
	for st: String in STATES:
		if not b.has_theme_stylebox(st):
			continue
		var s := b.get_theme_stylebox(st)
		if s is StyleBoxFlat and (s.border_width_left + s.border_width_top + s.border_width_right + s.border_width_bottom) > 0:
			out.append("%s %s 스타일에 테두리" % [b.get_path(), st])
	return out


func _check_tree(root: Node, where: String) -> int:
	var count := 0
	for n in root.find_children("*", "BaseButton", true, false):
		count += 1
		for p in problems(n as Control):
			assert_true(false, "%s: %s" % [where, p])
	return count


func test_테스트_검사기가_테두리를_잡아냄() -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var bad := StyleBoxFlat.new()
	bad.set_border_width_all(1)
	b.add_theme_stylebox_override("hover", bad)
	b.add_theme_stylebox_override("focus", bad)
	add_child(b)
	assert_eq(problems(b).size(), 2)
	b.queue_free()


func test_기지와_모든_건물_창_버튼에_선택_테두리_없음() -> void:
	get_window().size = Vector2i(1280, 720)
	var old_path := SaveData.path
	SaveData.path = SAVE
	var s := SaveData.new()
	s.credits = 5000
	s.upgrades = {"damage": 1}
	s.save_file()
	var main: Control = MainScene.instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	var total := _check_tree(main, "기지")
	for id in ["research", "hangar", "storage", "museum", "drone"]:
		main.press(id)
		await wait_frames()
		assert_eq(main.panel.kind, id)
		if id == "hangar":
			main.panel.view.select_tab("weapon")
			await wait_frames()
		total += _check_tree(main.panel, id)
		main.panel.close()
		for i in 120:  # 닫히는 연출이 끝나야 다음 건물을 누를 수 있다
			if not main.panel.visible:
				break
			await wait_frames()
	assert_true(total > 10, "버튼을 찾음: %d" % total)
	main.queue_free()
	get_window().size = Vector2i(64, 64)
	await wait_frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	SaveData.path = old_path


func test_판_화면_레벨업_카드와_일시_정지_메뉴에_선택_테두리_없음() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.invuln = 1.0e9
	run.sim.gain_xp(Upgrades.xp_to_next(1))
	run.slowmo = 0.0
	await wait_frames(2)
	run.cards.skip()
	await wait_frames(1)
	var total := _check_tree(run, "레벨업 카드")
	run.cards.skip_pick()
	await wait_frames(1)
	run.pause()
	await wait_frames(1)
	total += _check_tree(run, "일시 정지")
	assert_true(total > 3, "버튼을 찾음: %d" % total)
	run.queue_free()
