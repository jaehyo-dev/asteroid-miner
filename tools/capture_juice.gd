extends SceneTree
## 손맛(4a) 확인용 장면 캡처 도구 (게임에는 쓰지 않음). 같은 시드·같은 입력이라 매번 같은 장면이 나온다.
## 창을 띄워 실행하고(헤드리스는 그림이 안 그려짐), Godot 무비 모드로 프레임을 PNG로 저장한다.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <폴더>/f.png -s res://tools/capture_juice.gd -- combat
##   장면: combat(전투·큰 운석 깨짐), minerals(광물 튕김·자석), hit(피격·레벨업)
##   glow: 우주선 아래 옅은 빛 있음/없음 스크린샷 2장 (무비 모드 없이, -- glow <저장 폴더>)

var run: Node
var scene := ""
var out_dir := ""
var frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	scene = args[0] if args.size() > 0 else "combat"
	out_dir = args[1] if args.size() > 1 else "."


## 적 하나를 정해진 자리에 놓는다 (운석 크기 type, 체력 hp, 속도 vel)
func _rock(type: int, offset: Vector2, hp: float, vel := Vector2.ZERO) -> RunSim.Enemy:
	var a: RunSim.Enemy = run.sim.spawn_asteroid()
	var info: Dictionary = Balance.ASTEROID_TYPES[type]
	a.type = type
	a.radius = info["radius"]
	a.max_hp = maxf(info["hp"], hp)
	a.hp = hp
	a.pos = run.sim.player_pos + offset
	a.vel = vel
	return a


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		# 자동 로드(App, Sfx 등)가 준비된 뒤에 불러야 run.gd가 컴파일된다 (preload는 너무 이름)
		run = load("res://scenes/run.tscn").instantiate()
		root.add_child(run)
	elif frame == 2:
		run.sim.rng.seed = 4242
		run.sim.set("_spawn_timer", 1.0e9)  # 저절로 나오는 운석은 막고 장면에 필요한 것만 놓는다
		run.sim.set("_golden_timer", 1.0e9)
		run.sim.set("_barrage_timer", 1.0e9)
		_setup()
	elif frame > 2:
		if run.current_menu == run.Menu.PAUSE:
			run._close_menu()  # 캡처 창이 포커스를 잃으면 게임이 스스로 멈추므로 바로 닫는다
		return _step()
	return false


func _setup() -> void:
	match scene:
		"combat", "glow":
			run.sim.max_hp = 1.0e6  # 무적은 깜빡임이 보여서 체력만 크게
			run.sim.hp = 1.0e6
			_rock(0, Vector2(80, -30), 1.0, Vector2(-12, 4))
			_rock(1, Vector2(-90, -20), 2.0, Vector2(15, 0))
			_rock(2, Vector2(30, -85), 3.0, Vector2(0, 8))
			_rock(0, Vector2(-40, 70), 1.0, Vector2(6, -10))
			var j: RunSim.Enemy = run.sim.spawn_creature("jelly")
			j.pos = run.sim.player_pos + Vector2(150, 50)
		"minerals":
			run.sim.max_hp = 1.0e6  # 무적은 깜빡임이 보여서 체력만 크게
			run.sim.hp = 1.0e6
			run.sim.xp = -100000  # 이 장면은 광물만 보이게 레벨업 메뉴가 뜨지 않게 한다
			_rock(2, Vector2(95, -15), 0.5)
			_rock(1, Vector2(100, 35), 0.5)
			_rock(1, Vector2(80, -55), 0.5)
			var g: RunSim.Enemy = run.sim.spawn_golden()
			g.pos = run.sim.player_pos + Vector2(120, 10)
			g.vel = Vector2.ZERO
			g.hp = 0.5
		"hit":
			_rock(1, Vector2(70, 0), 50.0, Vector2(-90, 0))  # 우주선으로 날아와 부딪힘


func _step() -> bool:
	match scene:
		"combat":
			_hold("move_right", frame > 20 and frame < 70)
			_hold("move_up", frame > 50 and frame < 110)
			_hold("move_left", frame > 100 and frame < 140)
			if frame == 75:
				_rock(2, Vector2(-60, -80), 3.0, Vector2(10, 10))
			return frame >= 160
		"minerals":
			_hold("move_right", frame > 45 and frame < 85)
			_hold("move_down", frame > 85 and frame < 100)
			return frame >= 150
		"hit":
			if frame == 60:
				run.sim.xp = Upgrades.xp_to_next(run.sim.level) - 1
				run.sim.drop_mineral(run.sim.player_pos + Vector2(30, 0), 1)
			_hold("move_right", frame > 55 and frame < 75)
			return frame >= 125
		"glow":
			if frame == 40:
				run.process_mode = Node.PROCESS_MODE_DISABLED  # 이 순간에 멈추고 빛만 켜고 끈다
			elif frame == 42:
				root.get_texture().get_image().save_png(out_dir.path_join("glow_on.png"))
				run.world.ship_glow = false
				run.world.queue_redraw()
			elif frame == 44:
				root.get_texture().get_image().save_png(out_dir.path_join("glow_off.png"))
				return true
	return false
