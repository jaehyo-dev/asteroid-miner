extends SceneTree
## v0.8.0 3단계 공격 이펙트 후보 GIF 프레임 (게임에는 쓰지 않음). 저장소 맨 위에서 (WSL은 창 없이 가상 화면):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --resolution 1280x720 --fixed-fps 30 \
##     -s $PWD/review/v080_step3/capture_fx_gif.gd -- <프레임 폴더> <무기 id>
## 판을 WARM초까지 빨리 돌린 뒤(봇처럼 움직임, 레벨업 카드는 건너뛰기) 후보 1·2·3을 4초씩 15장/초로 찍는다 → <폴더>/<무기>_<후보>/.
## 포격은 끄고(습격 전 시간대), 운석과 일반 적(해파리)만 있는 장면. 촬영 중 죽지 않게 체력만 크게. 구석에 ?fxtest 표시가 나온다.
## 프레임 → GIF: python3 review/v080_step3/make_gifs.py <프레임 폴더>

const WARM := 44.0
const FRAMES := 60  # 4초 × 15장

var f := 0
var out := ""
var weapon := ""
var run: Node
var start := 0
var shot := 0
var cand := 1


func _initialize() -> void:
	SaveData.path = "user://capture_v080_fx_save.json"
	var s := SaveData.new()
	s.warp_seen = true
	s.risk_tip_seen = true
	s.save_file()
	Weapons.test_mode = true
	var a := OS.get_cmdline_user_args()
	out = a[0]
	weapon = a[1]


func _warm(sim: RunSim) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while sim.time < WARM:
		if sim.choosing():
			sim.skip()
			continue
		_quiet(sim)
		sim.update(1.0 / 30.0, _bot_move(sim, rng))
		sim.hp = sim.max_hp


## 포격 없음: 예고·탄을 지우고 다음 포격을 멀리 미룬다
func _quiet(sim: RunSim) -> void:
	sim.set("_barrage_timer", 999.0)
	sim.barrages.clear()
	for s in sim.shots.duplicate():
		if not s.guard:
			sim.shots.erase(s)


## 무기가 닿는 거리에 운석이 늘 몇 개 있게 (사거리가 짧은 산탄포·채굴 빔도 쏘는 장면이 나오게)
func _feed(sim: RunSim) -> void:
	var reach := minf(sim.fire_range, 140.0)
	var near := sim.enemies.filter(func(e: RunSim.Enemy) -> bool: return e.pos.distance_to(sim.player_pos) < reach + 20.0).size()
	var rng := RandomNumberGenerator.new()
	rng.seed = f
	for i in maxi(0, 5 - near):
		var a := sim.spawn_asteroid()
		var ang := rng.randf() * TAU
		a.pos = sim.player_pos + Vector2.from_angle(ang) * rng.randf_range(reach * 0.6, reach + 10.0)
		a.vel = Vector2.from_angle(ang + PI * 0.5) * rng.randf_range(4.0, 12.0)


func _bot_move(sim: RunSim, rng: RandomNumberGenerator) -> Vector2:
	var danger := RunSim.nearest_enemy(sim.player_pos, sim.enemies, 50.0)
	if danger != null:
		return (sim.player_pos - danger.pos).normalized()
	if not sim.minerals.is_empty():
		return (sim.minerals[rng.randi() % sim.minerals.size()].pos - sim.player_pos).limit_length(1.0)
	return Vector2.ZERO


func _process(_d: float) -> bool:
	f += 1
	if f == 1:
		change_scene_to_file("res://scenes/run.tscn")
	if f == 30:
		run = current_scene
		var sim: RunSim = run.sim
		sim.set_weapon(weapon)
		sim.view_size = root.get_visible_rect().size / 2.0
		_warm(sim)
		sim.max_hp = 1.0e6
		sim.hp = sim.max_hp
		sim.xp = -1000000  # 촬영 중 레벨업 카드가 뜨지 않게
		_set_cand(1)
		start = f + 10
	if start > 0 and f >= start:
		var sim: RunSim = run.sim
		_quiet(sim)
		sim.hp = sim.max_hp
		if (f - start) % 15 == 0:
			_feed(sim)
		if (f - start) % 2 == 0:
			var dir := "%s/%s_%d" % [out, weapon, cand]
			DirAccess.make_dir_recursive_absolute(dir)
			root.get_texture().get_image().save_png("%s/%03d.png" % [dir, shot])
			shot += 1
			if shot >= FRAMES:
				if cand == 3:
					return true
				_set_cand(cand + 1)
	return false


func _set_cand(n: int) -> void:
	cand = n
	shot = 0
	Weapons.fx_pick[weapon] = n
	run.call("_update_fx_label")
