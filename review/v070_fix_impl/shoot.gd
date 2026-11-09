extends SceneTree
## 창 화면 캡처: godot --path . --resolution 1280x720 -s res://review/v070_fix_impl/shoot.gd -- 태그
## 표본 저장으로 건물을 열어 PNG로 저장한다 (자동 테스트가 아니라 눈으로 볼 자료)

var main: Control
var tag := "pc"


func _sample():
	var s = load("res://scripts/logic/save_data.gd").new()
	s.credits = 780
	s.upgrades = {"damage": 3, "max_hp": 5, "insurance": 2, "magnet": 1, "shield": 2}
	s.forks_owned = {"thick_dodge": "ab"}
	s.forks_on = {"thick_dodge": "a"}
	s.hauled = PackedInt32Array([412, 96, 23, 3])
	for id in ["mineral_0", "mineral_1", "mineral_2", "rock_0", "rock_1", "rock_2", "jelly"]:
		s.seen[id] = true
	s.codex_claimed = {"at3": true}
	return s


func _shot(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("user://shots/%s_%s.png" % [name, tag])


func _initialize() -> void:
	tag = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "pc"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	load("res://scripts/logic/save_data.gd").path = "user://shoot_save.json"
	_sample().save_file()
	root.get_node("App").set_base_mode(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var w = main.panel
	for kind in ["research", "hangar", "storage", "museum", "drone"]:
		w.open(kind)
		await create_timer(0.35).timeout
		if kind == "research":
			var v = w.view
			v._select_branch("hull")
			await _shot("research_hull")
			v.select_cell("2a")
			await create_timer(0.3).timeout
			await _shot("research_fork")
			v.select_cell("1c")
			await create_timer(0.3).timeout
			await _shot("research_node")
			v._select_branch("mine")
			await _shot("research_mine")
			v._select_branch("weapon")
			await _shot("research_weapon")
		elif kind == "museum":
			await _shot(kind)
			w.view.reward = "at6"
			w.view._update_claim()
			await _shot("museum_reward")
		else:
			await _shot(kind)
		w.close()
		await create_timer(0.25).timeout
	quit()
