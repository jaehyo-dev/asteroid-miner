extends SceneTree
## v0.8.0 3b단계 최종 공격 이펙트 GIF 프레임 (게임에는 쓰지 않음). 저장소 맨 위에서 (WSL은 창 없이 가상 화면):
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --resolution 1280x720 --fixed-fps 30 \
##     -s $PWD/review/v080_step3b/capture_fx_gif.gd -- <프레임 폴더> <장면>
## 장면: pulse·shotgun·rail·plasma·beam(그 무기로 5초), rail_line(한 줄로 놓인 운석·적을 한 발에 꿰뚫음),
##       rail_fast(기지 이동 속도 5단계 + 레벨업 이동 속도 카드 5장, 사각형으로 빠르게 돌며 쏨)
## 판을 WARM초까지 빨리 돌린 뒤 5초를 15장/초로 찍는다 → <폴더>/<장면>/. 포격은 끄고, 촬영 중 죽지 않게 체력만 크게.
## 프레임 → GIF: python3 review/v080_step3b/make_gifs.py <프레임 폴더>

const WARM := 44.0
const FRAMES := 75  # 5초 × 15장
const MOVES := ["move_right", "move_down", "move_left", "move_up"]

var f := 0
var out := ""
var scene := ""
var weapon := ""
var run: Node
var start := 0
var shot := 0


func _initialize() -> void:
	SaveData.path = "user://capture_v080_fx_save.json"
	var s := SaveData.new()
	s.warp_seen = true
	s.risk_tip_seen = true
	s.save_file()
	Weapons.test_mode = true  # 구석에 무기 이름이 나온다
	var a := OS.get_cmdline_user_args()
	out = a[0]
	scene = a[1]
	weapon = scene.get_slice("_", 0)


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


## 무기가 닿는 거리 안에 운석 6개 + 해파리 2마리가 늘 있게 (계속 맞는 장면)
func _feed(sim: RunSim) -> void:
	var reach := minf(sim.fire_range, 140.0)
	var near := sim.enemies.filter(func(e: RunSim.Enemy) -> bool: return e.pos.distance_to(sim.player_pos) < reach)
	var rng := RandomNumberGenerator.new()
	rng.seed = f
	for i in maxi(0, 8 - near.size()):
		var jelly := near.filter(func(e: RunSim.Enemy) -> bool: return e.kind != RunSim.ROCK).size() + i < 2
		var a := sim.spawn_creature("jelly") if jelly else sim.spawn_asteroid()
		var ang := rng.randf() * TAU
		a.pos = sim.player_pos + Vector2.from_angle(ang) * rng.randf_range(reach * 0.45, reach * 0.95)
		a.vel = Vector2.from_angle(ang + PI * 0.5) * rng.randf_range(4.0, 12.0)


## 레일건 한 줄: 쏘기 직전에 가까운 곳부터 사거리 끝까지 운석·해파리 5개를 일렬로 (방향은 매번 바뀜)
func _line(sim: RunSim, n: int) -> void:
	sim.enemies = sim.enemies.filter(func(e: RunSim.Enemy) -> bool: return e.pos.distance_to(sim.player_pos) > sim.fire_range + 40.0)
	var dir := Vector2.from_angle(-0.5 + n * 1.3)
	for i in 5:
		var a := sim.spawn_creature("jelly") if i % 2 == 1 else sim.spawn_asteroid()
		a.pos = sim.player_pos + dir * (36.0 + i * 55.0) + dir.orthogonal() * (i % 3 - 1) * 3.0  # 굵기 안에서 살짝 어긋나게
		a.vel = Vector2.ZERO


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
		if scene == "rail_fast":
			sim.apply_base({"speed": 5})
			for i in 5:
				sim.apply_pick("speed", 0)
		sim.max_hp = 1.0e6
		sim.hp = sim.max_hp
		sim.xp = -1000000  # 촬영 중 레벨업 카드가 뜨지 않게
		run.call("_update_fx_label")
		start = f + 10
	if start > 0 and f >= start:
		var sim: RunSim = run.sim
		_quiet(sim)
		sim.hp = sim.max_hp
		for e in sim.enemies:  # 해파리가 우주선에 부딪히면 화면이 붉게 번쩍여 이펙트를 가린다: 닿기 직전에 부서지게
			if e.kind != RunSim.ROCK and e.pos.distance_to(sim.player_pos) < e.radius + 14.0:
				e.hp = 0.0
		var k := f - start
		if scene == "rail_line":
			if sim.fire_wait() < 0.15 and not _lined:
				_line(sim, k)
				_lined = true
			elif sim.fire_wait() > 0.5:
				_lined = false
		elif k % 15 == 0:
			_feed(sim)
		if scene == "rail_fast" and k % 18 == 0:  # 0.6초마다 방향을 바꿔 사각형으로 돈다
			for m in MOVES:
				Input.action_release(m)
			Input.action_press(MOVES[(k / 18) % 4])
		if k % 2 == 0:
			var dir := "%s/%s" % [out, scene]
			DirAccess.make_dir_recursive_absolute(dir)
			root.get_texture().get_image().save_png("%s/%03d.png" % [dir, shot])
			shot += 1
			if shot >= FRAMES:
				return true
	return false


var _lined := false
