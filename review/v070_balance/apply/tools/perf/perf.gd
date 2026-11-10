extends Node
## 웹 성능 비교용 장면 (게임에 포함하지 않음). 측정용 사본의 perf/에 복사하고 main_scene을 이 장면으로 바꿔 내보낸다.
## 주소 ?scene=early|late. 같은 시드로 출격 화면을 열고 collector 봇처럼 자동으로 움직이며(카드는 첫 번째),
## 3초 데운 뒤 20초 동안 프레임 시간과 Godot 스크립트 처리 시간(TIME_PROCESS)을 재서 콘솔에 "PERF:{json}"으로 찍는다.
## late: 4:00, 연구소 거의 다, 광물 250개를 화면 둘레에 뿌려 둔 후반 장면.

const FULL := {"damage": 5, "max_hp": 5, "speed": 5, "cargo": 5, "insurance": 5, "magnet": 5, "shield": 5, "reroll": 5,
	"appraise": 5, "radar": 5, "over": 1, "repair": 1, "drill": 1, "luck": 1, "rapid": 1, "thick": 1, "wide": 1, "bolt": 1, "deep": 1}

var run: Node
var scene := "early"
var t := 0.0
var frames: Array[float] = []
var proc := 0.0
var minerals := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if OS.has_feature("web"):
		var q: String = str(JavaScriptBridge.eval("location.search", true))
		scene = "late" if q.contains("late") else "early"
	SaveData.path = "user://perf_save.json"
	var save := SaveData.new()
	save.warp_seen = true
	save.risk_tip_seen = true
	if scene == "late":
		save.upgrades = FULL.duplicate()
	save.save_file()
	run = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	var sim: RunSim = run.sim
	sim.rng.seed = 7
	rng.seed = 7
	sim.max_hp = 1.0e6
	sim.hp = 1.0e6
	if scene == "late":
		sim.time = 240.0
		for i in 250:
			var m := sim.drop_mineral(sim.player_pos + Vector2(rng.randf_range(-330, 330), rng.randf_range(-190, 190)), rng.randi_range(0, 2))
			if m.pos.distance_to(sim.player_pos) < 80.0:
				m.pos += (m.pos - sim.player_pos).normalized() * 80.0


func _process(delta: float) -> void:
	if run == null or run.sim == null:
		return
	var sim: RunSim = run.sim
	if run.current_menu == run.Menu.LEVEL_UP and run.cards.state == run.cards.State.READY:
		run.cards.choose(0)
	run.joystick.vector = _move(sim)
	t += delta
	if t < 3.0:
		return
	if t < 23.0:
		frames.append(delta * 1000.0)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		minerals += sim.minerals.size()
	elif not frames.is_empty():
		var n := frames.size()
		var sorted := frames.duplicate()
		sorted.sort()
		var total := 0.0
		for f in frames:
			total += f
		print("PERF:" + JSON.stringify({"scene": scene, "fps": snappedf(n * 1000.0 / total, 0.1), "p95_ms": snappedf(sorted[int(n * 0.95)], 0.1),
			"max_ms": snappedf(sorted[n - 1], 0.1), "process_ms": snappedf(proc / n, 0.01), "minerals": snappedf(float(minerals) / n, 0.1), "frames": n}))
		frames.clear()


## collector 봇: 가까운 적·포격은 피하고, 아니면 가장 가까운 광물로
func _move(sim: RunSim) -> Vector2:
	var escape := sim.barrage_escape(sim.player_pos, 16.0)
	if escape != Vector2.ZERO:
		return escape
	var danger := RunSim.nearest_enemy(sim.player_pos, sim.enemies, 52.0)
	if danger != null:
		return (sim.player_pos - danger.pos).normalized()
	var move := Vector2.ZERO
	var best := 260.0
	for m in sim.minerals:
		var d := m.pos.distance_to(sim.player_pos)
		if d < best:
			best = d
			move = (m.pos - sim.player_pos).normalized()
	return move
