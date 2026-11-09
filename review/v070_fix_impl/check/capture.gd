extends SceneTree
## 3단계 확인 자료: 표본 저장으로 기지·건물 창을 조작하며 프레임을 PNG로 남긴다 (자동 테스트가 아니라 눈으로 볼 자료).
## 실행 (저장소 맨 위, 창이 뜸):
##   godot --path . --resolution 1280x720 --fixed-fps 15 -s res://review/v070_fix_impl/check/capture.gd -- pc
##   godot --path . --resolution 844x390 --fixed-fps 15 -s res://review/v070_fix_impl/check/capture.gd -- phone
## 프레임은 user://check/<태그>/<장면>/NNNN.png, GIF는 make_gifs.py가 만든다.

var main: Control
var SaveDataS = load("res://scripts/logic/save_data.gd")
var Up = load("res://scripts/logic/base_upgrades.gd")
var Disc = load("res://scripts/logic/discovery.gd")
var tag := "pc"
var _rec := ""
var _n := 0


func _sample(gold := false):
	var s = SaveDataS.new()
	s.upgrades = {"damage": 3, "max_hp": 4, "insurance": 2, "magnet": 1, "shield": 2}
	s.credits = Up.cost("max_hp", 4) + 1000 + 40  # 만렙 1번 + 갈림길 2개 해금, 그다음은 모자람
	s.hauled = PackedInt32Array([412, 96, 23, 3])
	for i in (Disc.ENTRIES.size() if gold else 7):
		s.seen[Disc.ENTRIES[i]["id"]] = true
	s.codex_claimed = {"at3": true}
	if gold:
		s.codex_claimed["all"] = true
	return s


func _initialize() -> void:
	tag = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "pc"
	_run.call_deferred()


## 매 프레임 녹화 (끄면 멈춤)
func _process(_d: float) -> bool:
	if _rec != "":
		var img := root.get_texture().get_image()
		img.save_png("user://check/%s/%s/%04d.png" % [tag, _rec, _n])
		_n += 1
	return false


func rec(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://check/%s/%s" % [tag, name])
	_rec = name
	_n = 0


func stop() -> void:
	await process_frame
	_rec = ""


func wait(t: float) -> void:
	await create_timer(t).timeout


func still(name: String) -> void:
	await wait(0.4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://check/%s" % tag)
	root.get_texture().get_image().save_png("user://check/%s/%s.png" % [tag, name])


func _open_main(save) -> void:
	if main:
		main.queue_free()
		await process_frame
	save.save_file()
	main = load("res://scenes/main.tscn").instantiate()
	main.auto_start = false
	root.add_child(main)
	current_scene = main
	await wait(0.5)


func _run() -> void:
	SaveDataS.path = "user://check_save.json"
	root.get_node("App").set_base_mode(true)
	await _open_main(_sample())
	var w = main.panel
	if OS.get_cmdline_user_args().has("return"):
		await _return_clip()
		quit()
		return
	# 1) 건물 5개 열기·닫기
	for kind in ["research", "hangar", "storage", "museum", "drone"]:
		rec("open_close_" + kind)
		await wait(0.3)
		main.press(kind)
		await wait(1.3)
		w.close()
		await wait(0.6)
		await stop()
	# 2) 연구소 탭 5개
	main.press("research")
	await wait(0.5)
	var v = w.view
	for b in ["weapon", "hull", "mine", "elec", "survey"]:
		v._on_tab(b)
		await still("research_tab_" + b)
	# 3) 칸 강화 → 만렙 → 광물 부족
	v._on_tab("hull")
	await wait(0.3)
	rec("research_upgrade_max_poor")
	v.select_cell("0c")  # 격벽 보강 4 → 5 (만렙)
	await wait(0.6)
	v.act()
	await wait(1.6)
	await still("research_max_" + "panel")
	v.select_cell("1c")  # 화물 회수 신호기: 광물 모자람 (해금 2개 몫만 남김)
	await wait(0.5)
	var keep: int = w.save.credits
	w.save.credits = Up.cost("insurance", 2) - 1  # 강화엔 1 모자람
	w.refresh_head()
	v._refresh()
	v._open_panel()
	await wait(0.4)
	v._on_denied()
	await wait(1.0)
	await stop()
	# 4) 갈림길 해금 A → 해금 B → A로 바꾸기
	w.save.credits = keep
	w.refresh_head()
	v._refresh()
	rec("research_fork")
	v.select_cell("2a")
	await wait(0.6)
	v.act()
	await wait(1.4)
	v.select_cell("2b")
	await wait(0.6)
	v.act()
	await wait(1.4)
	v.select_cell("2b")  # 해금한 B로 바꾸기 (버튼 소리, 빛 흐름이 B 쪽으로)
	await wait(0.6)
	v.act()
	await wait(1.2)
	await stop()
	w.close()
	await wait(0.5)
	# 5) 격납고 회전
	main.press("hangar")
	await wait(0.6)
	rec("hangar_spin")
	await wait(3.0)
	await stop()
	await still("hangar")
	w.close()
	await wait(0.5)
	# 6) 금고, 드론 공장 정지 화면
	for kind in ["storage", "drone"]:
		main.press(kind)
		await still(kind)
		w.close()
		await wait(0.5)
	# 7) 전시관 보상 받기 (6개 보상)
	main.press("museum")
	await wait(0.6)
	var m = w.view
	rec("museum_claim")
	m.reward = "at6"
	m._update_claim()
	await wait(1.0)
	m.claim_button.pressed.emit()
	await wait(1.2)
	await stop()
	w.close()
	await wait(0.5)
	# 8) 금빛 도색: 기지와 격납고
	await _open_main(_sample(true))
	await still("gold_base")
	main.press("hangar")
	await wait(0.6)
	rec("gold_hangar_spin")
	await wait(2.0)
	await stop()
	main.panel.close()
	await wait(0.5)
	await _return_clip()
	quit()


func _return_clip() -> void:
	# 9) 기지 귀환 전환: 출격 화면 → 셔터 쿵 → 기지 → 착륙 → 결과
	var app: Node = root.get_node("App")
	app.warp_intro = false
	main.queue_free()
	main = null
	change_scene_to_file("res://scenes/run.tscn")
	await wait(1.5)
	rec("return_shutter")
	await wait(0.3)
	app.landing = true
	app.return_result = {"title": "귀환 성공!", "body": "시험 결과"}
	app.shutter.close_to("res://scenes/main.tscn")
	await wait(2.6)
	await stop()
