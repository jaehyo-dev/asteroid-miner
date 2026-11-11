extends SceneTree
## v0.8.0 3단계 격납고·연구소·무기 그림 후보 캡처 (게임에는 쓰지 않음). 저장소 맨 위에서 (WSL은 창 없이 가상 화면):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --resolution 1280x720 \
##     -s $PWD/review/v080_step3/capture_hangar.gd -- <출력.png 또는 폴더> <장면>
## 장면: fighter([전투기] 탭), compare([기본 무기] 탭에서 레일건 → ▲▼), buy_ok(광물 2,000, 잠긴 채굴 빔 [구매]),
##       buy_poor(광물 780, 잠긴 플라스마 대포 [광물 부족]), research(연구소 무기 가지),
##       art(<폴더>에 무기 그림 후보 12장을 설명 칸에 넣은 캡처 <무기>_<번호>.png)
## 표본 저장: 산탄포·레일건 산 상태, 펄스 연사포 장착 (실제 저장은 건드리지 않음)

var f := 0
var out := ""
var scene := ""
var art := []  # [무기, 번호] 남은 후보


func _initialize() -> void:
	SaveData.path = "user://capture_v080_step3_save.json"
	var s := SaveData.new()
	s.credits = 2000 if scene_arg() == "buy_ok" else 780
	s.upgrades["damage"] = 1
	s.weapons_owned = ["shotgun", "rail"] if scene_arg() != "art" else ["shotgun", "rail", "plasma", "beam"]
	s.save_file()
	out = OS.get_cmdline_user_args()[0]
	scene = scene_arg()
	if scene == "art":
		for id in ["shotgun", "rail", "plasma", "beam"]:
			for n in [1, 2, 3]:
				art.append([id, n])


func scene_arg() -> String:
	return OS.get_cmdline_user_args()[1]


func _process(_d: float) -> bool:
	f += 1
	if f == 1:
		change_scene_to_file("res://scenes/main.tscn")
		root.warp_mouse(Vector2(2, 2))  # 가상 화면 마우스가 가운데(착륙장) 위에 있으면 말풍선이 떠서 치운다
	if f == 60:
		var win: Variant = root.get_node("Main").panel
		win.open("research" if scene == "research" else "hangar")
	if f == 66:
		var win: Variant = root.get_node("Main").panel
		var v: Variant = win.view
		match scene:
			"fighter":
				v.select_tab("fighter")
			"compare":
				v.select_tab("weapon")
				v.pick("rail")
			"buy_ok":
				v.select_tab("weapon")
				v.pick("beam")
			"buy_poor":
				v.select_tab("weapon")
				v.pick("plasma")
			"research":
				pass  # 처음 열면 무기 가지 (설명 창 없이 가지 전체)
			"art":
				v.select_tab("weapon")
	if scene == "art" and f >= 80 and f % 10 == 0:
		var win: Variant = root.get_node("Main").panel
		if f > 80:
			var done: Array = art.pop_front()
			root.get_texture().get_image().save_png("%s/%s_%d.png" % [out, done[0], done[1]])
			if art.is_empty():
				return true
		var next: Array = art[0]
		WindowArt._tex["weapon_" + next[0]] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://review/v080_step3/art/cand/%s_%d.png" % next)))
		win.view.pick(next[0])
		win.view.queue_redraw()
	if scene != "art" and f == 110:
		root.get_texture().get_image().save_png(out)
		return true
	return false
