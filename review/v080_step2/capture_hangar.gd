extends SceneTree
## v0.8.0 2단계 확인용 격납고·연구소 캡처 (게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --path . --resolution 1280x720 -s $PWD/review/v080_step2/capture_hangar.gd -- <출력.png> <장면>
## 장면: fighter(전투기 탭), weapon_open(해금한 레일건), weapon_lock(잠긴 플라스마 대포), research(연구소로 버튼 → 무기 가지)
## 표본 저장: 광물 780, 산탄포·레일건 해금, 펄스 연사포 장착 (실제 저장은 건드리지 않음)

var f := 0
var out := ""
var scene := ""


func _initialize() -> void:
	SaveData.path = "user://capture_v080_save.json"
	var s := SaveData.new()
	s.credits = 780
	for id in ["damage", "w_shotgun", "w_rail"]:
		s.upgrades[id] = 1
	s.save_file()
	var a := OS.get_cmdline_user_args()
	out = a[0]
	scene = a[1]


func _process(_d: float) -> bool:
	f += 1
	if f == 1:
		change_scene_to_file("res://scenes/main.tscn")
	if f == 60:
		var win: Variant = root.get_node("Main").panel
		win.open("hangar")
	if f == 66:
		var win: Variant = root.get_node("Main").panel
		var hv: Variant = win.view
		match scene:
			"fighter":
				hv.select_tab("fighter")
			"weapon_open":
				hv.select_tab("weapon")
				hv.pick("rail")
			"weapon_lock", "research":
				hv.select_tab("weapon")
				hv.pick("plasma")
		if scene == "research":
			hv.go_research("plasma")
	if f == 110:
		root.get_texture().get_image().save_png(out)
		return true
	return false
