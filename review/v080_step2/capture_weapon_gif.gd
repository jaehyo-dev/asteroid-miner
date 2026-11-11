extends SceneTree
## v0.8.0 2단계 무기별 인게임 GIF 프레임 (게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --path . --resolution 1280x720 --fixed-fps 30 -s $PWD/review/v080_step2/capture_weapon_gif.gd -- <프레임 폴더> <무기 id | shots>
## 판을 WARM초까지 빨리 돌린 뒤(봇처럼 광물 쪽으로 움직임, 레벨업 카드는 건너뛰기라 기본 무기 모습 그대로) 5초를 15장/초로 찍는다.
## 촬영 중 죽지 않게 체력만 크게 둔다. shots: 경비선·포격을 불러 플라스마 폭발(앞 3초)·채굴 빔(뒤 3초) 위로 적 탄이 지나가는 장면.
## 프레임 → GIF: python3 review/v080_step2/make_gifs.py

const WARM := 95.0
const FRAMES := 75

var f := 0
var out := ""
var mode := ""
var run: Node
var start := 0
var shot := 0


func _initialize() -> void:
	SaveData.path = "user://capture_v080_gif_save.json"
	var s := SaveData.new()
	s.warp_seen = true
	s.risk_tip_seen = true
	s.save_file()
	var a := OS.get_cmdline_user_args()
	out = a[0]
	mode = a[1]


func _warm(sim: RunSim) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while sim.time < WARM:
		if sim.choosing():
			sim.skip()
			continue
		var move := Vector2.ZERO
		var danger := RunSim.nearest_enemy(sim.player_pos, sim.enemies, 50.0)
		if danger != null:
			move = (sim.player_pos - danger.pos).normalized()
		elif not sim.minerals.is_empty():
			move = (sim.minerals[rng.randi() % sim.minerals.size()].pos - sim.player_pos).limit_length(1.0)
		sim.update(1.0 / 30.0, move)
		sim.hp = sim.max_hp


func _process(_d: float) -> bool:
	f += 1
	if f == 1:
		change_scene_to_file("res://scenes/run.tscn")
	if f == 30:
		run = current_scene
		var sim: RunSim = run.sim
		sim.set_weapon("plasma" if mode == "shots" else mode)
		sim.view_size = root.get_visible_rect().size / 2.0
		_warm(sim)
		sim.max_hp = 1.0e6
		sim.hp = sim.max_hp
		sim.xp = -1000000  # 촬영 중 레벨업 카드가 뜨지 않게
		if mode == "shots":
			sim.spawn_guard(0.0)
			sim.spawn_guard(PI)
			sim.start_barrage()
		start = f + 10
	if start > 0 and f >= start and (f - start) % 2 == 0 and shot < FRAMES + (15 if mode == "shots" else 0):
		var sim: RunSim = run.sim
		if mode == "shots" and shot == 45:
			sim.set_weapon("beam")
			for i in 3:  # 빔이 닿을 운석을 가까이 두고, 포격이 빔 위를 지나가게
				var a := sim.spawn_asteroid()
				a.pos = sim.player_pos + Vector2.from_angle(TAU * i / 3.0 + 0.4) * 55.0
				a.vel = Vector2.ZERO
				a.max_hp = 30.0
				a.hp = a.max_hp
			sim.start_barrage()
		if mode == "shots":
			sim.hp = sim.max_hp
		root.get_texture().get_image().save_png("%s/%03d.png" % [out, shot])
		shot += 1
	return shot >= FRAMES + (15 if mode == "shots" else 0)
