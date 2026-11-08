extends SceneTree
## QUALITY_BAR "판정 방법"의 30초 장면 캡처 도구 (게임에는 쓰지 않음): 워프 출격 → 전투·채굴 → 레벨업 카드 → 게이트 귀환.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <폴더>/f.png -s res://tools/capture_final.gd -- <프레임 기록 파일>
## 진짜 게임 규칙 그대로 돌리되 세 가지만 다르다: 첫 게이트를 40초에서 18초로 당김, 죽지 않게 체력을 크게, 봇이 조작.
## 봇: 위험하면 피하고, 광물을 줍고, 게이트가 열리면 들어간다 (tests/balance_bot.gd의 returner와 비슷함).

const SEED := 2026
const GATE_AT := 18.0
const MAX_FRAMES := 1500

var frame := 0
var marks := {}
var mark_path := ""
var run: Node
var chosen_at := -1


func _initialize() -> void:
	mark_path = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	SaveData.path = "user://capture_final_save.json"  # 실제 저장을 건드리지 않게
	SaveData.new().save_file()


func _mark(name: String) -> void:
	if not marks.has(name):
		marks[name] = frame


func _process(_delta: float) -> bool:
	frame += 1
	RenderingServer.force_draw(false)  # 창이 다른 창에 가려져도 그린다
	if frame > MAX_FRAMES:
		return true  # 봇이 귀환하지 못해도 프레임이 끝없이 쌓이지 않게
	if frame == 1:
		change_scene_to_file("res://scenes/main.tscn")
	elif frame == 30:
		current_scene.press("ship")
		_mark("launch")
	elif current_scene != null and current_scene.has_method("bank_result"):
		_step_run()
	elif marks.has("base"):
		return frame > int(marks["base"]) + 45
	return false


func _step_run() -> void:
	if run != current_scene:
		run = current_scene
		run.sim.rng.seed = SEED
		run.sim.max_hp = 1.0e5  # 죽지 않게 (맞는 연출은 그대로)
		run.sim.hp = 1.0e5
		run.sim.gate.timer = GATE_AT
		_mark("run")
	if run.intro_t >= 0.0:
		return
	_mark("play")
	var sim: RunSim = run.sim
	if run.current_menu == run.Menu.PAUSE:
		run._close_menu()  # 캡처 창이 포커스를 잃으면 게임이 스스로 멈추므로
	elif run.current_menu == run.Menu.LEVEL_UP:
		_mark("card")
		if run.cards.state == run.cards.State.READY and frame >= int(marks["card"]) + 75:
			run.cards.choose(BalanceBot.best_choice(sim.choices))
	elif run.current_menu == run.Menu.GAME_OVER:
		_mark("result")
		if frame == int(marks["result"]) + 45:
			_mark("base")
			_save_marks()
			run._on_menu_chosen(1)
	elif not sim.is_over():
		run.joystick.vector = _move(sim)
		if sim.events.has("hit"):
			_mark("hit")
		if sim.events.has("destroy"):
			_mark("destroy")
		if sim.events.has("pickup"):
			_mark("pickup")
		if sim.events.has("gate_open"):
			_mark("gate_open")
		if sim.events.has("warp_charge"):
			_mark("charge")
	elif sim.returned:
		_mark("jump")


func _move(sim: RunSim) -> Vector2:
	var escape := sim.barrage_escape(sim.player_pos, BalanceBot.BARRAGE_DODGE_MARGIN)
	if escape != Vector2.ZERO:
		return escape
	if sim.gate.state == WarpGate.State.OPEN:
		return (sim.gate.pos - sim.player_pos).limit_length(1.0)
	var danger := RunSim.nearest_enemy(sim.player_pos, sim.enemies, BalanceBot.COLLECTOR_DANGER)
	if danger != null:
		return (sim.player_pos - danger.pos).normalized()
	var best := 260.0
	var move := Vector2.ZERO
	for m in sim.minerals:
		var d := m.pos.distance_to(sim.player_pos)
		if d < best:
			best = d
			move = (m.pos - sim.player_pos).normalized()
	return move


func _save_marks() -> void:
	if mark_path != "":
		var f := FileAccess.open(mark_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(marks))
