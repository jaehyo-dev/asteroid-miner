extends SceneTree
## 기지 화면 확인용 캡처 도구 (게임에는 쓰지 않음).
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <폴더>/f.png -s res://tools/capture_base.gd -- <장면> [busy]
##   또는 godot --path . --resolution 844x390 -s res://tools/capture_base.gd -- still:<파일.png> [busy]
##   장면: still:파일(한 장), idle(대기 움직임 80프레임), pan(끌어서 둘러보기 150프레임)

var f := 0
var scene := ""
var _busy := false


func _initialize() -> void:
	SaveData.path = "user://capture_base_save.json"  # 실제 저장을 건드리지 않게
	var s := SaveData.new()
	s.credits = 2340
	s.drag_hint_seen = false
	s.save_file()
	var a := OS.get_cmdline_user_args()
	scene = a[0]
	_busy = a.size() > 1 and a[1] == "busy"


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _process(_d: float) -> bool:
	f += 1
	RenderingServer.force_draw(false)
	if f == 1:
		root.get_node("App").base_debug_busy = _busy  # 자동 로드는 첫 프레임에 준비된다
		change_scene_to_file("res://scenes/main.tscn")
	if scene.begins_with("still:"):
		if f == 20:
			root.get_texture().get_image().save_png(scene.substr(6))
			return true
	elif scene == "idle":
		return f > 90
	elif scene == "pan":
		# 왼쪽으로 끝까지 → 오른쪽으로 끝까지 → 가운데 (1280x720 기준 좌표)
		var mid := root.get_visible_rect().size / 2.0
		if f == 15:
			_mouse(mid, true)
		elif f > 15 and f < 150:
			var k := (f - 15) / 135.0
			_move(mid + Vector2(sin(k * TAU) * 1000.0, 0))
		elif f == 150:
			_mouse(mid, false)
		return f > 160
	return false
