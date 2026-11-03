extends TestCase
## v0.2.0 위기감 2: 쫓아오는 적(우주 해파리, 날벌레 떼)과 습격 이벤트 테스트.


## 평소 운석·포격·습격이 끼어들지 않는 조용한 시뮬레이션
func _quiet() -> RunSim:
	var sim := RunSim.new(77)
	for t in ["_spawn_timer", "_barrage_timer", "_golden_timer", "_jelly_timer", "_bug_timer"]:
		sim.set(t, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.fire_range = -1.0  # 쏘지 않음
	sim.set("hp", 1.0e9)
	sim.max_hp = 1.0e9  # 강화를 골라도 체력이 최대 체력으로 깎이지 않게
	return sim


# ── 우주 해파리 ──

func test_해파리는_정해진_시각에_처음_나오고_새로운_위협_이벤트() -> void:
	var sim := RunSim.new(5)
	sim.set("hp", 1.0e9)
	sim.max_hp = 1.0e9  # 강화를 골라도 체력이 최대 체력으로 깎이지 않게
	var seen := -1.0
	while sim.time < Balance.JELLY_FIRST_TIME + 1.0 and sim.alive:
		if not sim.choices.is_empty():
			sim.choose(0)
			continue
		sim.update(0.05, Vector2.ZERO)
		if sim.events.has("new_jelly"):
			seen = sim.time
	assert_true(absf(seen - Balance.JELLY_FIRST_TIME) < 0.06, "첫 해파리 %f초" % seen)
	var count := 0
	for e in sim.enemies:
		if e.kind == "jelly":
			count += 1
	assert_true(count >= 1)


func test_새로운_위협_이벤트는_종류마다_한_번만() -> void:
	var sim := _quiet()
	sim.spawn_creature("jelly")
	assert_true(sim.events.has("new_jelly"))
	sim.events.clear()
	sim.spawn_creature("jelly")
	assert_false(sim.events.has("new_jelly"))


func test_해파리는_멀리_도망가도_끝까지_쫓아옴() -> void:
	var sim := _quiet()
	var j := sim.spawn_creature("jelly")
	j.pos = Vector2(200, 0)
	j.vel = Vector2(0, 30)  # 엉뚱한 방향으로 움직이던 중
	var start := j.pos.distance_to(sim.player_pos)
	for i in 120:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	assert_true(j.pos.distance_to(sim.player_pos) < start - 20.0, "다가옴")
	assert_true(j.vel.length() <= RunSim.creature_speed("jelly", sim.time) + 0.01, "최고 속도를 넘지 않음")


func test_쫓아가기는_급하게_꺾지_못함() -> void:
	var v := RunSim.steer(Vector2.ZERO, Vector2(50, 0), Vector2(-100, 0), 50.0, 10.0, 0.1)
	assert_true(v.distance_to(Vector2(50, 0)) <= 1.0 + 0.001, "한 번에 accel×delta만큼만 바뀜: %s" % v)


func test_생명체_속도는_운석보다_천천히_빨라짐() -> void:
	var t := 180.0
	var creature_growth := RunSim.creature_speed("jelly", t) / float(Balance.CREATURES["jelly"]["speed"])
	assert_true(creature_growth < RunSim.asteroid_speed_mult(t), "%f < %f" % [creature_growth, RunSim.asteroid_speed_mult(t)])
	assert_true(creature_growth > 1.0, "그래도 빨라짐")


# ── 날벌레 떼 ──

func test_날벌레는_무리로_나와_우주선을_향해_돌진() -> void:
	var sim := _quiet()
	sim.player_pos = Vector2(40, -20)
	var group := sim.spawn_swarm()
	assert_eq(group.size(), Balance.BUG_SWARM_SIZE)
	for b in group:
		assert_eq(b.kind, "bug")
		var angle := absf(rad_to_deg(b.vel.angle_to(sim.player_pos - b.pos)))
		assert_true(angle < 15.0, "우주선 쪽으로: %f도" % angle)
		assert_true(b.pos.distance_to(group[0].pos) <= Balance.BUG_SWARM_SPREAD * 1.5, "무리 지어")


func test_날벌레는_잠깐만_방향을_틀고_그_뒤엔_그대로_지나감() -> void:
	var sim := _quiet()
	var b := sim.spawn_creature("bug")
	b.pos = Vector2(0, -300)
	b.vel = Vector2(90, 0)
	b.age = Balance.BUG_HOMING_TIME + 0.1  # 쫓는 시간이 끝남
	var before := b.vel
	for i in 10:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	assert_true(b.vel.is_equal_approx(before), "방향 그대로")


func test_날벌레_떼는_정해진_시각부터_나옴() -> void:
	var sim := RunSim.new(6)
	sim.set("hp", 1.0e9)
	sim.max_hp = 1.0e9  # 강화를 골라도 체력이 최대 체력으로 깎이지 않게
	var first := -1.0
	while sim.time < Balance.BUG_FIRST_TIME + 1.0 and first < 0.0 and sim.alive:
		if not sim.choices.is_empty():
			sim.choose(0)
			continue
		sim.update(0.05, Vector2.ZERO)
		if sim.events.has("new_bug"):
			first = sim.time
	assert_true(first >= Balance.BUG_FIRST_TIME - 0.06, "첫 날벌레 %f초" % first)


# ── 생명체 공통 ──

func test_생명체를_부수면_정해진_광물() -> void:
	for creature in Balance.CREATURES:
		var sim := _quiet()
		var e := sim.spawn_creature(creature)
		e.pos = Vector2(500, 500)
		sim.call("_on_enemy_destroyed", e)
		var info: Dictionary = Balance.CREATURES[creature]
		assert_eq(sim.minerals.size(), int(info["minerals"]), creature)
		for m in sim.minerals:
			assert_eq(m.grade, int(info["grade"]), creature + " 등급")


func test_생명체와_부딪히면_피해를_받고_생명체는_사라짐() -> void:
	var sim := _quiet()
	sim.set("hp", 100.0)
	var j := sim.spawn_creature("jelly")
	j.pos = sim.player_pos + Vector2(2, 0)
	j.vel = Vector2.ZERO
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.hp, 100.0 - Balance.CREATURES["jelly"]["damage"])
	assert_false(sim.enemies.has(j))


func test_생명체는_탄에_맞아_부서짐() -> void:
	var sim := _quiet()
	sim.fire_range = Balance.FIRE_RANGE
	var b := sim.spawn_creature("bug")
	b.pos = Vector2(0, -80)
	b.vel = Vector2.ZERO
	b.age = 100.0
	for i in 60:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(sim.kills, 1)


# ── 습격 이벤트 ──

func test_습격은_경고_후_시작하고_끝나면_숨_돌릴_틈() -> void:
	var r := RaidDirector.new()
	var rng := RandomNumberGenerator.new()
	var log := {}
	var t := 0.0
	while t < Balance.RAID_FIRST_TIME + Balance.RAID_DURATION + Balance.RAID_CALM_TIME + 1.0:
		for e in r.update(0.05, rng, false):
			if not log.has(e):
				log[e] = t + 0.05
		t += 0.05
	assert_true(absf(log["raid_warning"] - (Balance.RAID_FIRST_TIME - Balance.RAID_WARNING_TIME)) < 0.06, "경고 %f" % log["raid_warning"])
	assert_true(absf(log["raid_start"] - Balance.RAID_FIRST_TIME) < 0.06, "시작 %f" % log["raid_start"])
	assert_true(absf(log["raid_end"] - (Balance.RAID_FIRST_TIME + Balance.RAID_DURATION)) < 0.06, "끝 %f" % log["raid_end"])
	assert_eq(r.state, RaidDirector.State.IDLE, "숨 돌릴 틈이 끝나면 평소로")


func test_습격은_일정_간격으로_반복() -> void:
	var r := RaidDirector.new()
	var rng := RandomNumberGenerator.new()
	var starts: Array[float] = []
	var t := 0.0
	while t < Balance.RAID_FIRST_TIME + Balance.RAID_INTERVAL * 2 + 1.0:
		if r.update(0.05, rng, true).has("raid_start"):
			starts.append(t + 0.05)
		t += 0.05
	assert_eq(starts.size(), 3)
	assert_true(absf(starts[1] - starts[0] - Balance.RAID_INTERVAL) < 0.11)


func test_습격_종류는_번갈아_오고_날벌레가_나오기_전엔_운석_폭풍만() -> void:
	assert_eq(RaidDirector.kind_for(0, true), RaidDirector.STORM)
	assert_eq(RaidDirector.kind_for(1, true), RaidDirector.SWARM)
	assert_eq(RaidDirector.kind_for(2, true), RaidDirector.STORM)
	assert_eq(RaidDirector.kind_for(1, false), RaidDirector.STORM)


func test_습격_중에는_한_방향에서_몰려옴() -> void:
	var sim := _quiet()
	sim.raid.state = RaidDirector.State.ACTIVE
	sim.raid.kind = RaidDirector.STORM
	sim.raid.direction = 0.5
	sim.raid.timer = 5.0
	for i in 60:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	assert_true(sim.enemies.size() >= 3, "운석 폭풍 %d개" % sim.enemies.size())
	for e in sim.enemies:
		var angle := absf(rad_to_deg(angle_difference(0.5, (e.pos - sim.player_pos).angle())))
		assert_true(angle <= Balance.RAID_ARC_DEG / 2.0 + 10.0, "습격 방향에서: %f도" % angle)


func test_날벌레_습격은_무리로_옴() -> void:
	var sim := _quiet()
	sim.raid.state = RaidDirector.State.ACTIVE
	sim.raid.kind = RaidDirector.SWARM
	sim.raid.timer = 5.0
	sim.update(1.0 / 30.0, Vector2.ZERO)
	var bugs := 0
	for e in sim.enemies:
		if e.kind == "bug":
			bugs += 1
	assert_eq(bugs, Balance.BUG_SWARM_SIZE)


func test_숨_돌릴_틈에는_평소_등장이_멈춤() -> void:
	var sim := RunSim.new(9)
	sim.set("hp", 1.0e9)
	sim.max_hp = 1.0e9  # 강화를 골라도 체력이 최대 체력으로 깎이지 않게
	sim.raid.state = RaidDirector.State.CALM
	sim.raid.timer = 3.0
	sim.set("_golden_timer", 1.0e9)
	var before := sim.enemies.size()
	for i in 80:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	assert_eq(sim.enemies.size(), before, "아무것도 새로 나오지 않음")
	# 틈이 끝나면 밀린 등장이 한 번씩만 나온다 (한꺼번에 몰려나오지 않음)
	sim.raid.state = RaidDirector.State.IDLE
	sim.raid.timer = 1.0e9
	sim.update(1.0 / 30.0, Vector2.ZERO)
	assert_true(sim.enemies.size() - before <= 2 + Balance.BUG_SWARM_SIZE, "몰려나오지 않음: %d" % (sim.enemies.size() - before))


func test_습격_경고음과_화면() -> void:
	assert_true(Sfx.raid_stream().data.size() > 1000)
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	# 생명체와 습격 경고를 화면에 띄워 오류 없이 그려지는지 본다
	run.sim.spawn_creature("jelly").pos = run.sim.player_pos + Vector2(60, 0)
	for b in run.sim.spawn_swarm():
		b.pos = run.sim.player_pos + Vector2(-60, 20)
	run.sim.raid.timer = 0.01  # 곧 경고
	await wait_frames(3)
	assert_eq(run.sim.raid.state, RaidDirector.State.WARNING)
	assert_true(run.hud.banner_text.contains("접근"), "습격 경고 배너: " + run.hud.banner_text)
	run.sim.raid.timer = 0.01  # 곧 시작
	await wait_frames(3)
	assert_eq(run.sim.raid.state, RaidDirector.State.ACTIVE)
	await wait_frames(3)
	run.queue_free()


func test_새로운_위협_배너() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.spawn_creature("jelly")
	run._announce(run.sim.events)
	assert_true(run.hud.banner_text.contains("우주 해파리"), run.hud.banner_text)
	run.queue_free()


func test_첫_등장_시각은_숨_돌릴_틈과_겹치지_않음() -> void:
	# 숨 돌릴 틈에는 평소 등장이 멈추므로, 첫 등장이 그 사이에 있으면 늦어진다
	for first in [Balance.JELLY_FIRST_TIME, Balance.BUG_FIRST_TIME, Balance.BARRAGE_FIRST_TIME]:
		for n in 10:
			var calm_start := Balance.RAID_FIRST_TIME + n * Balance.RAID_INTERVAL + Balance.RAID_DURATION
			assert_false(first > calm_start and first <= calm_start + Balance.RAID_CALM_TIME, "%f초가 숨 돌릴 틈과 겹침" % first)
