extends SceneTree
## 워프 점프 확인용 캡처 도구 (게임에는 쓰지 않음). 창을 띄워 Godot 무비 모드로 프레임을 저장한다.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <폴더>/f.png -s res://tools/capture_warp.gd -- launch
##   장면: launch(기지 출격 → 터널 → 도착), return(게이트 충전 → 점프 → 결과 → 기지 착륙), gate(게이트 등장·닫히기 직전)

var scene := ""
var frame := 0


func _initialize() -> void:
	scene = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "launch"
	SaveData.path = "user://capture_warp_save.json"  # 실제 저장을 건드리지 않게
	var s := SaveData.new()
	s.warp_seen = false
	s.save_file()


func _process(_delta: float) -> bool:
	frame += 1
	RenderingServer.force_draw(false)  # 창이 다른 창에 가려져도 그린다
	match scene:
		"launch":
			return _launch()
		"return":
			return _return()
		_:
			return _gate()


func _launch() -> bool:
	if frame == 1:
		change_scene_to_file("res://scenes/main.tscn")
	elif frame == 30:
		current_scene.press("ship")
	return frame > 30 + int(WarpJump.TOTAL_TIME * 30.0) + 45


func _run() -> Node:
	return current_scene


func _return() -> bool:
	if frame == 1:
		change_scene_to_file("res://scenes/run.tscn")
	elif frame == 3:
		var sim: RunSim = _run().sim
		for t in ["_spawn_timer", "_barrage_timer", "_guard_timer"]:
			sim.set(t, 1.0e9)
		sim.time = 41.0
		sim.gate.state = WarpGate.State.OPEN
		sim.gate.timer = Balance.GATE_OPEN_TIME
		sim.gate.pos = sim.player_pos + Vector2(0, -12)
		sim.gate.charge = Balance.WARP_CHARGE_TIME - 1.5
		sim.cargo.add(2)
		_run().gate_view.fx.appear = 5.0
	elif frame > 3 and current_scene != null and current_scene.has_method("bank_result"):
		var run := _run()
		if run.current_menu == run.Menu.PAUSE:
			run._close_menu()
		if run.current_menu == run.Menu.GAME_OVER and frame % 200 > 0 and not run.has_meta("seen"):
			run.set_meta("seen", frame)
		if run.has_meta("seen") and frame == int(run.get_meta("seen")) + 20:
			run._on_menu_chosen(1)  # 기지로
			set_meta("base_at", frame)
	return has_meta("base_at") and frame > int(get_meta("base_at")) + 50


func _gate() -> bool:
	if frame == 1:
		change_scene_to_file("res://scenes/run.tscn")
	elif frame == 3:
		var sim: RunSim = _run().sim
		for t in ["_spawn_timer", "_barrage_timer", "_guard_timer"]:
			sim.set(t, 1.0e9)
		sim.set("_golden_timer", 1.0e9)
		sim.gate.timer = 0.01  # 바로 열림
	elif frame == 6:
		_run().sim.gate.pos = _run().sim.player_pos + Vector2(50, 0)
	elif frame > 6:
		var run := _run()
		if run.current_menu == run.Menu.PAUSE:
			run._close_menu()
		if frame == 60:
			run.sim.gate.timer = 3.2
	return frame > 190
