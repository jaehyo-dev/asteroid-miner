extends SceneTree
## v0.8.0 3b단계 격납고 캡처 (게임에는 쓰지 않음). 저장소 맨 위에서 (WSL은 창 없이 가상 화면):
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --resolution 1280x720 \
##     -s $PWD/review/v080_step3b/capture_hangar.gd -- <출력.png> <장면>
## 폰은 --resolution 844x390. 장면: fighter([전투기] 탭), shotgun·rail·plasma·beam([기본 무기] 탭에서 그 무기를 고름)
## 표본 저장: 광물 780, 산탄포·레일건 산 상태, 펄스 연사포 장착 (실제 저장은 건드리지 않음)

var f := 0


func _initialize() -> void:
	SaveData.path = "user://capture_v080_step3b_save.json"
	var s := SaveData.new()
	s.credits = 780
	s.upgrades["damage"] = 1
	s.weapons_owned = ["shotgun", "rail"]
	s.save_file()


func _process(_d: float) -> bool:
	f += 1
	var args := OS.get_cmdline_user_args()
	if f == 1:
		change_scene_to_file("res://scenes/main.tscn")
		root.warp_mouse(Vector2(2, 2))  # 가상 화면 마우스가 착륙장 위에 있으면 말풍선이 떠서 치운다
	if f == 60:
		root.get_node("Main").panel.open("hangar")
	if f == 66:
		var v: Variant = root.get_node("Main").panel.view
		if args[1] == "fighter":
			v.select_tab("fighter")
		else:
			v.select_tab("weapon")
			v.pick(args[1])
	if f == 110:
		root.get_texture().get_image().save_png(args[0])
		return true
	return false
