extends SceneTree
## v0.8.0 3c단계 화면 캡처 (게임에는 쓰지 않음). 저장소 맨 위에서 (WSL은 창 없이 가상 화면):
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --resolution 1280x720 \
##     -s <이 파일 절대 경로> -- <출력.png> <장면>
## 폰은 --resolution 844x390. 고치기 전 캡처는 이전 커밋 worktree에서 같은 파일로 찍는다.
## 장면: hangar_fighter([전투기] 탭), hangar_rail([기본 무기] 탭 레일건 고름, 레일건 장착), research_<가지>(펄스 증폭기만 연구,
##       무기 가지는 갈림길 연사형을 고름), museum(전시관 칸 고름), base_hover(격납고 위에 마우스), cards(레벨업 카드, 마우스 올림)
## 표본 저장: 광물 5000, 펄스 증폭기 1단계만, 산탄포·레일건 산 상태 (실제 저장은 건드리지 않음)

var f := 0
var out := ""
var scene := ""


func _initialize() -> void:
	SaveData.path = "user://capture_v080_step3c_save.json"
	var s := SaveData.new()
	s.credits = 5000
	s.upgrades["damage"] = 1
	s.weapons_owned = ["shotgun", "rail"]
	s.weapon = "rail" if scene_arg() == "hangar_rail" else "pulse"
	s.warp_seen = true
	s.risk_tip_seen = true
	s.seen = {"small": true, "jelly": true}
	s.save_file()
	out = OS.get_cmdline_user_args()[0]
	scene = scene_arg()


static func scene_arg() -> String:
	return OS.get_cmdline_user_args()[1]


func _process(_d: float) -> bool:
	f += 1
	if scene == "cards":
		return _cards()
	if f == 1:
		change_scene_to_file("res://scenes/main.tscn")
		root.warp_mouse(Vector2(2, 2))  # 가상 화면 마우스가 건물 위에 있으면 말풍선이 떠서 치운다
	var main: Node = root.get_node_or_null("Main")
	if f == 60:
		if scene.begins_with("hangar"):
			main.panel.open("hangar")
		elif scene.begins_with("research"):
			main.panel.open("research")
		elif scene == "museum":
			main.panel.open("museum")
	if f == 70:
		var v: Variant = main.panel.view
		match scene:
			"hangar_fighter":
				v.select_tab("fighter")
			"hangar_rail":
				v.select_tab("weapon")
				v.pick("rail")
			"museum":
				v.selected = "jelly"
				v.call("_update_claim")
			_:
				if scene.begins_with("research_"):
					var b := scene.trim_prefix("research_")
					if b == "weapon":
						v.show_cell(b, "2a")
					else:
						v.call("_select_branch", b)
	if scene == "base_hover" and f >= 60:
		main.view.hover_id = "hangar"  # 격납고에 마우스를 올린 상태 (가상 마우스 이벤트가 지우지 않게 매 프레임)
	if f == 120:
		root.get_texture().get_image().save_png(out)
		return true
	return false


var run: Node


func _cards() -> bool:
	if f == 1:
		change_scene_to_file("res://scenes/run.tscn")
	if f == 30:
		run = current_scene
		run.sim.invuln = 1.0e9
		run.sim.rerolls_left = 2
		run.sim.gain_xp(Upgrades.xp_to_next(1) * 12)  # 레벨이 올라 건너뛰기 보상이 두 자리 이상
		run.set("slowmo", 0.0)
	if f == 40:
		run.cards.skip()  # 펼치기 연출 건너뜀
	if f == 70:
		var c: Control = run.cards.cards[1]
		var at := c.get_global_rect().get_center()
		root.warp_mouse(at)  # 가운데 카드에 마우스 올림 (예전엔 흰 테두리, 지금은 카드가 밝아짐)
		var ev := InputEventMouseMotion.new()
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
	if f == 100:
		root.get_texture().get_image().save_png(out)
		return true
	return false
