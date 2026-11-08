extends SceneTree
## 효과 강화·레전드리 연출 확인용 장면 캡처 도구 (게임에는 쓰지 않음). 같은 시드라 매번 같은 장면이 나온다.
## 창을 띄워 Godot 무비 모드로 프레임을 PNG로 저장한다.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <폴더>/f.png -s res://tools/capture_effects.gd -- pierce
##   장면: pierce, ricochet, explosive, crit, drone, laser, orbit, chain, overload, beacon, shield, all

const PICKS := {
	"pierce": [["pierce", 3], ["multishot", 2]],
	"ricochet": [["ricochet", 3], ["multishot", 2]],
	"explosive": [["explosive", 3], ["fire_rate", 3]],
	"crit": [["crit", 3], ["crit", 3], ["fire_rate", 3]],
	"drone": [["drone", 3], ["drone", 2]],
	"laser": [["mining_laser", 3], ["fire_rate", 3]],
	"orbit": [["orbit_pierce", 4], ["multishot", 3]],
	"chain": [["chain_matrix", 4], ["multishot", 2]],
	"overload": [["overload", 4]],
	"beacon": [["tractor_beacon", 4], ["fire_rate", 3]],
	"shield": [["shield", 3]],
	"all": [["orbit_pierce", 4], ["chain_matrix", 4], ["overload", 4], ["multishot", 3], ["multishot", 3], ["fire_rate", 3], ["fire_rate", 3], ["explosive", 3], ["crit", 3], ["drone", 3], ["drone", 3], ["mining_laser", 3], ["shield", 3]],
}
const FRAMES := 150

var run: Node
var scene := ""
var frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	scene = args[0] if args.size() > 0 else "pierce"


func _rock(offset: Vector2, type: int, hp: float) -> void:
	var a: RunSim.Enemy = run.sim.spawn_asteroid()
	var info: Dictionary = Balance.ASTEROID_TYPES[type]
	a.type = type
	a.radius = info["radius"]
	a.max_hp = hp
	a.hp = hp
	a.pos = run.sim.player_pos + offset
	a.vel = -offset.normalized() * 6.0


func _process(_delta: float) -> bool:
	frame += 1
	RenderingServer.force_draw(false)  # 창이 다른 창에 가려져도 프레임을 그린다 (macOS는 가려진 창을 안 그림)
	if frame == 1:
		run = load("res://scenes/run.tscn").instantiate()
		root.add_child(run)
	elif frame == 2:
		var sim: RunSim = run.sim
		sim.rng.seed = 4242
		sim.apply_upgrades()
		for p in PICKS[scene]:
			sim.apply_pick(p[0], p[1])
		sim.max_hp = 1.0e6
		sim.hp = 1.0e6
		if scene == "overload" or scene == "all":
			sim.hp = sim.max_hp * 0.4
		for t in ["_spawn_timer", "_golden_timer", "_barrage_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
			sim.set(t, 1.0e9)
		sim.raid.state = RaidDirector.State.CALM
		sim.set("_beacon_timer", 1.5)
		if scene == "shield":
			sim.shield_interval = 3.0  # 충전 단계를 짧은 GIF에 담으려고 줄임
		_field()
	elif frame > 2:
		if run.current_menu == run.Menu.PAUSE:
			run._close_menu()
		var sim: RunSim = run.sim
		if frame % 45 == 0 and scene != "shield":
			_field()
		if scene == "shield":
			if frame == 130:
				var hit: RunSim.Enemy = sim.spawn_creature("jelly")
				hit.pos = sim.player_pos + Vector2(0, -6)
				hit.vel = Vector2.ZERO
		return frame > FRAMES
	return false


## 우주선 둘레에 운석을 늘어놓는다
func _field() -> void:
	if scene == "shield":
		return
	for i in 7:
		var a := TAU * i / 7.0 + frame * 0.1
		_rock(Vector2.from_angle(a) * (70.0 + 22.0 * (i % 3)), i % 3, 6.0 + 4.0 * (i % 3))
	if scene == "beacon":
		for i in 30:
			run.sim.drop_mineral(run.sim.player_pos + Vector2.from_angle(i * 0.9) * (90.0 + i * 4.0), i % 4)
