extends TestCase
## 출격 로직(RunSim) 테스트: 이동, 운석 등장, 충돌, 체력, 무적, 사망.


## 운석이 저절로 생기지 않고(등장 타이머를 미룸) 자동 공격도 하지 않는 시뮬레이션
func _quiet_sim(shoot: bool = false) -> RunSim:
	var sim := RunSim.new(1234)
	sim.set("_spawn_timer", 1.0e9)
	if not shoot:
		sim.fire_range = -1.0
	return sim


func _add_asteroid(sim: RunSim, pos: Vector2, vel: Vector2 = Vector2.ZERO, type: int = 0) -> RunSim.Enemy:
	var a := RunSim.Enemy.new()
	a.type = type
	a.radius = Balance.ASTEROID_TYPES[type]["radius"]
	a.damage = Balance.ASTEROID_TYPES[type]["damage"]
	a.max_hp = Balance.ASTEROID_TYPES[type]["hp"]
	a.hp = a.max_hp
	a.pos = pos
	a.vel = vel
	sim.enemies.append(a)
	return a


func test_우주선은_이동_속도대로_움직임() -> void:
	var sim := _quiet_sim()
	sim.update(0.05, Vector2.RIGHT)
	assert_true(sim.player_pos.is_equal_approx(Vector2(Balance.SHIP_SPEED * 0.05, 0)), "위치 %s" % sim.player_pos)


func test_이동_방향이_1보다_길어도_최고_속도까지만() -> void:
	var sim := _quiet_sim()
	sim.update(0.05, Vector2(10, 0))
	assert_true(is_equal_approx(sim.player_pos.x, Balance.SHIP_SPEED * 0.05))


func test_긴_프레임은_최대_시간으로_자름() -> void:
	var sim := _quiet_sim()
	sim.update(5.0, Vector2.RIGHT)
	assert_true(is_equal_approx(sim.time, Balance.MAX_FRAME_DELTA), "시간 %f" % sim.time)
	assert_true(is_equal_approx(sim.player_pos.x, Balance.SHIP_SPEED * Balance.MAX_FRAME_DELTA))


func test_등장_간격은_시간이_지날수록_줄고_최소값에서_멈춤() -> void:
	assert_true(is_equal_approx(RunSim.spawn_interval(0.0), Balance.SPAWN_INTERVAL_START))
	var mid := RunSim.spawn_interval(Balance.SPAWN_RAMP_TIME / 2.0)
	assert_true(mid < Balance.SPAWN_INTERVAL_START and mid > Balance.SPAWN_INTERVAL_MIN, "중간 %f" % mid)
	assert_true(is_equal_approx(RunSim.spawn_interval(Balance.SPAWN_RAMP_TIME), Balance.SPAWN_INTERVAL_MIN))


func test_시간이_더_지나면_등장_간격이_계속_절반씩_줄고_바닥에서_멈춤() -> void:
	var t := Balance.SPAWN_RAMP_TIME + Balance.SPAWN_LATE_HALVING_TIME
	assert_true(is_equal_approx(RunSim.spawn_interval(t), Balance.SPAWN_INTERVAL_MIN / 2.0), "절반")
	assert_true(is_equal_approx(RunSim.spawn_interval(99999.0), Balance.SPAWN_INTERVAL_FLOOR), "바닥")
	# 시간이 지날수록 절대 늘어나지 않는다
	var prev := RunSim.spawn_interval(0.0)
	for i in 120:
		var cur := RunSim.spawn_interval(i * 5.0)
		assert_true(cur <= prev + 0.00001, "%d초에 늘어남" % (i * 5))
		prev = cur


func test_운석은_시간이_지날수록_빨라짐() -> void:
	assert_eq(RunSim.asteroid_speed_mult(0.0), 1.0)
	assert_true(is_equal_approx(RunSim.asteroid_speed_mult(Balance.ASTEROID_SPEED_GROWTH_TIME), 2.0))
	var sim := _quiet_sim()
	sim.time = Balance.ASTEROID_SPEED_GROWTH_TIME
	for i in 20:
		var a := sim.spawn_asteroid()
		var info: Dictionary = Balance.ASTEROID_TYPES[a.type]
		assert_true(a.vel.length() >= info["speed_min"] * 2.0 - 0.01, "2배 속도")


func test_시간이_지나면_큰_운석_비율이_늘어남() -> void:
	var early := RunSim.asteroid_weights(0.0)
	var late := RunSim.asteroid_weights(Balance.SPAWN_RAMP_TIME)
	assert_true(late[2] / _sum(late) > early[2] / _sum(early))


func _sum(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total


func test_비율_뽑기() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var only_middle: Array[float] = [0.0, 1.0, 0.0]
	for i in 50:
		assert_eq(RunSim.pick_weighted(rng, only_middle), 1)
	var counts := [0, 0]
	var weights: Array[float] = [3.0, 1.0]
	for i in 4000:
		counts[RunSim.pick_weighted(rng, weights)] += 1
	assert_true(counts[0] > 2700 and counts[0] < 3300, "3:1 비율 %s" % [counts])


func test_운석은_화면_밖에서_나타나_우주선_쪽으로_옴() -> void:
	var sim := _quiet_sim()
	sim.player_pos = Vector2(500, -200)
	for i in 30:
		var a := sim.spawn_asteroid()
		var dist := a.pos.distance_to(sim.player_pos)
		assert_true(dist > sim.view_size.length() / 2.0, "화면 밖: %f" % dist)
		# 우주선 쪽 방향과의 각도가 퍼짐 각도 이내
		var angle := absf(rad_to_deg(a.vel.angle_to(sim.player_pos - a.pos)))
		assert_true(angle <= Balance.ASTEROID_AIM_SPREAD_DEG + 0.01, "각도 %f" % angle)
		var info: Dictionary = Balance.ASTEROID_TYPES[a.type]
		assert_true(a.vel.length() >= info["speed_min"] - 0.01 and a.vel.length() <= info["speed_max"] + 0.01, "속도")


func test_시간이_지나면_운석이_계속_나타남() -> void:
	var sim := RunSim.new(99)
	sim.set("hp", 1.0e9)
	sim.max_hp = 1.0e9
	var spawned := 0
	for i in 600:  # 10초
		var before := sim.enemies.size()
		sim.update(1.0 / 60.0, Vector2.ZERO)
		spawned += maxi(sim.enemies.size() - before, 0)
	# 처음 10초 간격은 약 1초 → 대략 9~10개 (충돌로 사라진 것은 제외될 수 있어 최소만 확인)
	assert_true(sim.enemies.size() >= 5 and sim.enemies.size() <= 12, "운석 수 %d" % sim.enemies.size())


func test_운석_최대_개수를_넘지_않음() -> void:
	var sim := RunSim.new(5)
	sim.set("hp", 1.0e9)
	sim.view_size = Vector2(10000, 10000)  # 아무것도 멀어져서 사라지지 않게
	sim.time = 10000.0
	for i in 2000:
		sim.update(0.1, Vector2.ZERO)
	assert_true(sim.enemies.size() <= Balance.MAX_ENEMIES, "운석 수 %d" % sim.enemies.size())


func test_운석에_맞으면_체력이_줄고_운석은_부서짐() -> void:
	var sim := _quiet_sim()
	_add_asteroid(sim, Vector2(2, 0), Vector2.ZERO, 1)
	sim.update(0.01, Vector2.ZERO)
	assert_true(is_equal_approx(sim.hp, Balance.SHIP_MAX_HP - Balance.ASTEROID_TYPES[1]["damage"]), "체력 %f" % sim.hp)
	assert_eq(sim.enemies.size(), 0, "부서짐")
	assert_true(sim.events.has("hit"), "hit 이벤트")
	assert_true(sim.invuln > 0.0, "무적 시작")


func test_무적_중에는_운석이_지나감() -> void:
	var sim := _quiet_sim()
	sim.invuln = 0.5
	_add_asteroid(sim, Vector2(2, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.hp, Balance.SHIP_MAX_HP, "데미지 없음")
	assert_eq(sim.enemies.size(), 1, "운석은 그대로")


func test_무적은_시간이_지나면_끝남() -> void:
	var sim := _quiet_sim()
	sim.damage_player(1.0)
	for i in int(Balance.SHIP_INVULN_TIME / 0.05) + 2:
		sim.update(0.05, Vector2.ZERO)
	assert_eq(sim.invuln, 0.0)
	assert_true(sim.damage_player(1.0), "다시 맞을 수 있음")


func test_떨어진_운석과는_충돌하지_않음() -> void:
	var sim := _quiet_sim()
	_add_asteroid(sim, Vector2(Balance.SHIP_RADIUS + 6.0, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.hp, Balance.SHIP_MAX_HP)


func test_체력이_0이_되면_파괴되고_더_진행하지_않음() -> void:
	var sim := _quiet_sim()
	sim.hp = 5.0
	_add_asteroid(sim, Vector2.ZERO)
	sim.update(0.01, Vector2.ZERO)
	assert_false(sim.alive, "파괴")
	assert_eq(sim.hp, 0.0, "체력은 0 아래로 내려가지 않음")
	assert_true(sim.events.has("dead"))
	var t := sim.time
	sim.update(0.5, Vector2.RIGHT)
	assert_eq(sim.time, t, "시간 멈춤")


func test_멀어진_운석은_사라짐() -> void:
	var sim := _quiet_sim()
	_add_asteroid(sim, Vector2(RunSim.despawn_distance(sim.view_size) - 1.0, 0), Vector2(100, 0))
	_add_asteroid(sim, Vector2(50, 0))
	sim.update(0.05, Vector2.ZERO)
	assert_eq(sim.enemies.size(), 1)


func test_같은_시드면_같은_결과() -> void:
	var a := RunSim.new(42)
	var b := RunSim.new(42)
	for i in 300:
		var move := Vector2.from_angle(i * 0.1)
		a.update(1.0 / 60.0, move)
		b.update(1.0 / 60.0, move)
	assert_eq(a.enemies.size(), b.enemies.size())
	assert_eq(a.hp, b.hp)
	assert_eq(a.player_pos, b.player_pos)


# ── 2단계: 자동 공격 ──

func test_운석_체력은_시간에_따라_늘어남() -> void:
	assert_eq(RunSim.asteroid_hp(2.0, 0.0), 2.0)
	assert_eq(RunSim.asteroid_hp(2.0, Balance.ASTEROID_HP_GROWTH_TIME - 0.01), 2.0, "첫 구간은 기본 체력 그대로")
	assert_true(is_equal_approx(RunSim.asteroid_hp(2.0, Balance.ASTEROID_HP_GROWTH_TIME), 4.0))
	var sim := _quiet_sim()
	sim.time = Balance.ASTEROID_HP_GROWTH_TIME
	var a := sim.spawn_asteroid()
	assert_true(is_equal_approx(a.hp, Balance.ASTEROID_TYPES[a.type]["hp"] * 2.0), "체력 %f" % a.hp)


func test_가장_가까운_운석을_고름() -> void:
	var sim := _quiet_sim()
	var far := _add_asteroid(sim, Vector2(100, 0))
	var near := _add_asteroid(sim, Vector2(0, -50))
	assert_eq(RunSim.nearest_enemy(Vector2.ZERO, sim.enemies, 200.0), near)
	assert_eq(RunSim.nearest_enemy(Vector2.ZERO, sim.enemies, 40.0), null, "사거리 밖")
	assert_eq(RunSim.nearest_enemy(Vector2(100, 10), sim.enemies, 200.0), far)


func _angles(pattern: Array[Dictionary]) -> Array[float]:
	var result: Array[float] = []
	for shot in pattern:
		result.append(float(shot.angle))
	return result


func test_탄_1발은_직선() -> void:
	var p := RunSim.shot_pattern(1.0, 1, 0.2, 4.0)
	assert_eq(p.size(), 1)
	assert_true(is_equal_approx(p[0].angle, 1.0))
	assert_eq(p[0].offset, Vector2.ZERO)


func test_탄_2발은_퍼지지_않고_나란히() -> void:
	var p := RunSim.shot_pattern(0.0, 2, 0.2, 4.0)  # 오른쪽으로 발사
	assert_eq(p.size(), 2)
	for shot in p:
		assert_true(is_equal_approx(shot.angle, 0.0), "같은 방향")
	# 진행 방향(오른쪽)에 수직으로 4픽셀 떨어져 있음
	assert_true(p[0].offset.distance_to(p[1].offset) > 3.99 and p[0].offset.distance_to(p[1].offset) < 4.01, "간격 4")
	assert_true(is_zero_approx(p[0].offset.x) and is_zero_approx(p[1].offset.x), "옆으로만 떨어짐")
	assert_true(is_zero_approx((p[0].offset + p[1].offset).length()), "가운데 기준 대칭")


func test_탄_3발은_가운데_1발과_양옆_부채꼴() -> void:
	var p := RunSim.shot_pattern(0.0, 3, 0.2, 4.0)
	var a := _angles(p)
	assert_true(is_equal_approx(a[0], -0.2) and is_equal_approx(a[1], 0.0) and is_equal_approx(a[2], 0.2), "%s" % [a])
	for shot in p:
		assert_eq(shot.offset, Vector2.ZERO)


func test_탄_4발은_가운데_2발_나란히와_양옆_부채꼴() -> void:
	var p := RunSim.shot_pattern(0.0, 4, 0.2, 4.0)
	var a := _angles(p)
	assert_eq(p.size(), 4)
	assert_true(is_equal_approx(a[0], -0.2) and is_equal_approx(a[3], 0.2), "양옆 %s" % [a])
	assert_true(is_equal_approx(a[1], 0.0) and is_equal_approx(a[2], 0.0), "가운데 2발 같은 방향 %s" % [a])
	assert_true(p[1].offset.distance_to(p[2].offset) > 3.99, "가운데 2발 나란히")
	assert_eq(p[0].offset, Vector2.ZERO)
	assert_eq(p[3].offset, Vector2.ZERO)


func test_탄_5발과_6발() -> void:
	var five := _angles(RunSim.shot_pattern(0.0, 5, 0.2, 4.0))
	var expected5: Array[float] = [-0.4, -0.2, 0.0, 0.2, 0.4]
	for i in 5:
		assert_true(is_equal_approx(five[i], expected5[i]), "5발 %s" % [five])
	var six := RunSim.shot_pattern(0.0, 6, 0.2, 4.0)
	var a6 := _angles(six)
	var expected6: Array[float] = [-0.4, -0.2, 0.0, 0.0, 0.2, 0.4]
	for i in 6:
		assert_true(is_equal_approx(a6[i], expected6[i]), "6발 %s" % [a6])
	assert_true(six[2].offset.distance_to(six[3].offset) > 3.99, "6발 가운데 2발 나란히")


func test_2발은_가운데_적에게_둘_다_맞음() -> void:
	var sim := _quiet_sim(true)
	sim.bullet_count = 2
	var a := _add_asteroid(sim, Vector2(0, -80))  # 작은 운석
	a.hp = 10.0
	a.max_hp = 10.0
	for i in 30:
		sim.update(0.01, Vector2.ZERO)
	assert_eq(a.hp, 8.0, "첫 발사의 두 발 모두 명중")

func test_사거리_안_운석을_향해_자동_발사() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(0, -100))
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 1, "한 발")
	assert_true(sim.events.has("shoot"))
	assert_true(sim.bullets[0].vel.normalized().is_equal_approx(Vector2.UP), "위쪽으로: %s" % sim.bullets[0].vel)


func test_대상이_없으면_쏘지_않음() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(Balance.FIRE_RANGE + 50.0, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 0)


func test_발사_간격을_지킴() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(0, -150), Vector2.ZERO, 2).hp = 1000.0
	var shots := 0
	var steps := int(Balance.FIRE_INTERVAL * 2.5 / 0.01)
	for i in steps:
		sim.update(0.01, Vector2.ZERO)
		if sim.events.has("shoot"):
			shots += 1
	# 처음, 1간격 뒤, 2간격 뒤 → 2.5간격 동안 3발
	assert_eq(shots, 3)


func test_탄_개수만큼_발사() -> void:
	var sim := _quiet_sim(true)
	sim.bullet_count = 3
	_add_asteroid(sim, Vector2(0, -100))
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 3)


func test_탄에_맞으면_체력이_줄고_0이면_부서짐() -> void:
	var sim := _quiet_sim(true)
	var a := _add_asteroid(sim, Vector2(0, -60), Vector2.ZERO, 1)  # 체력 2
	var steps := 0
	while sim.kills == 0 and steps < 300:
		sim.update(0.01, Vector2.ZERO)
		steps += 1
		if sim.kills == 0 and a.hp < a.max_hp:
			assert_true(is_equal_approx(a.hp, 1.0), "한 발 맞음")
	assert_eq(sim.kills, 1, "부서짐")
	assert_eq(sim.enemies.size(), 0)
	# 두 발이 필요하므로 최소 한 번의 발사 간격이 지나야 부서진다
	assert_true(steps * 0.01 >= Balance.FIRE_INTERVAL, "걸린 시간 %f" % (steps * 0.01))


func test_부서진_운석은_그_프레임의_destroyed에_담김() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(0, -20))
	var found := false
	for i in 30:
		sim.update(0.01, Vector2.ZERO)
		if sim.destroyed.size() > 0:
			found = true
			assert_true(sim.events.has("destroy"))
			break
	assert_true(found)
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.destroyed.size(), 0, "다음 프레임엔 비워짐")


func test_탄은_수명이_다하면_사라짐() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(0, -100), Vector2.ZERO).hp = 1000.0
	sim.update(0.01, Vector2.ZERO)
	sim.enemies.clear()  # 맞을 대상을 없앤다
	var life := Balance.FIRE_RANGE / Balance.BULLET_SPEED * Balance.BULLET_LIFETIME_FACTOR
	for i in int(life / 0.05) + 2:
		sim.update(0.05, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 0)


func test_탄_하나는_운석_하나만_맞춤() -> void:
	var sim := _quiet_sim(true)
	var a1 := _add_asteroid(sim, Vector2(0, -30))
	var a2 := _add_asteroid(sim, Vector2(0, -30))
	a1.hp = 5.0
	a2.hp = 5.0
	for i in 20:
		sim.update(0.01, Vector2.ZERO)
	assert_eq(a1.hp + a2.hp, 9.0, "총 피해 1")


func test_움직이는_운석은_앞질러_쏨() -> void:
	# 오른쪽으로 움직이는 대상: 탄은 대상의 현재 위치보다 오른쪽을 노려야 한다.
	var from := Vector2.ZERO
	var target := Vector2(0, -150)
	var vel := Vector2(60, 0)
	var angle := RunSim.intercept_angle(from, target, vel, 260.0)
	var dir := Vector2.from_angle(angle)
	assert_true(dir.x > 0.0 and dir.y < 0.0, "오른쪽 위: %s" % dir)
	# 탄과 대상이 실제로 같은 지점에서 만나는지 확인
	var t := 150.0 / sqrt(260.0 * 260.0 - 60.0 * 60.0)
	assert_true((dir * 260.0 * t).distance_to(target + vel * t) < 0.5, "만나는 지점")


func test_멈춘_운석은_똑바로_쏨() -> void:
	var angle := RunSim.intercept_angle(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 260.0)
	assert_true(is_equal_approx(angle, 0.0))


func test_따라잡을_수_없으면_현재_위치를_노림() -> void:
	var angle := RunSim.intercept_angle(Vector2.ZERO, Vector2(100, 0), Vector2(500, 0), 260.0)
	assert_true(is_equal_approx(angle, 0.0))


func test_움직이는_운석도_실제로_맞혀_부숨() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(-80, -140), Vector2(70, 10))  # 작은 운석, 체력 1
	for i in 120:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(sim.kills, 1, "움직이는 운석 명중")


func test_실제로_나온_운석은_처음엔_기본_탄_수로_부서짐() -> void:
	# 출격 초반에 나온 운석은 크기별 기본 탄 수(작음 1, 중간 2, 큼 3)로 부서져야 한다.
	var sim := _quiet_sim()
	sim.time = 30.0
	for i in 40:
		var a := sim.spawn_asteroid()
		var base: float = Balance.ASTEROID_TYPES[a.type]["hp"]
		var shots := int(ceil(a.hp / Balance.BULLET_DAMAGE))
		assert_eq(shots, int(base), "%s 탄 수" % Balance.ASTEROID_TYPES[a.type]["name"])


func test_선분과_점_거리() -> void:
	assert_true(is_equal_approx(RunSim.segment_distance(Vector2(0, 0), Vector2(10, 0), Vector2(5, 3)), 3.0))
	assert_true(is_equal_approx(RunSim.segment_distance(Vector2(0, 0), Vector2(10, 0), Vector2(-4, 3)), 5.0), "끝점 바깥")
	assert_true(is_equal_approx(RunSim.segment_distance(Vector2(1, 1), Vector2(1, 1), Vector2(4, 5)), 5.0), "길이 0")


func test_느린_프레임에서도_탄이_운석을_뚫고_지나가지_않음() -> void:
	# 10fps(최대 프레임 시간)에서는 탄이 한 프레임에 26px을 가므로 지나간 선분으로 판정해야 한다.
	var hits := 0
	for i in 20:
		var sim := _quiet_sim(true)
		_add_asteroid(sim, Vector2(0, -90 - i * 2.3), Vector2(0, 40))  # 다가오는 작은 운석
		for step in 20:
			sim.update(Balance.MAX_FRAME_DELTA, Vector2.ZERO)
		if sim.kills == 1 and sim.hp == Balance.SHIP_MAX_HP:
			hits += 1
	assert_eq(hits, 20, "모두 명중")


func test_느린_프레임에서도_발사_간격이_같음() -> void:
	for fps in [60.0, 30.0, 20.0]:
		var sim := _quiet_sim(true)
		_add_asteroid(sim, Vector2(0, -150), Vector2.ZERO, 2).hp = 1.0e6
		var shots := 0
		var steps := int(round(fps * 10.0))
		for i in steps:
			sim.update(1.0 / fps, Vector2.ZERO)
			if sim.events.has("shoot"):
				shots += 1
		var expected := int(10.0 / Balance.FIRE_INTERVAL) + 1
		assert_true(absi(shots - expected) <= 1, "%dfps 발사 %d발 (예상 %d)" % [fps, shots, expected])


# ── 3단계: 광물 ──

func _kill(sim: RunSim, a: RunSim.Enemy) -> void:
	# 탄으로 부순 것과 같은 처리
	sim.call("_on_enemy_destroyed", a)


func test_부순_운석은_크기별_개수만큼_광물을_떨어뜨림() -> void:
	for type in Balance.ASTEROID_TYPES.size():
		var sim := _quiet_sim()
		var a := _add_asteroid(sim, Vector2(100, 100), Vector2.ZERO, type)
		_kill(sim, a)
		assert_eq(sim.minerals.size(), int(Balance.ASTEROID_TYPES[type]["minerals"]), "%d번 크기" % type)
		for m in sim.minerals:
			assert_true(m.pos.distance_to(a.pos) <= Balance.MINERAL_SCATTER + 0.01, "운석 자리 근처")


func test_탄으로_부수면_실제로_광물이_나옴() -> void:
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(0, -100))
	for i in 60:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(sim.kills, 1)
	assert_eq(sim.minerals.size() + sim.collected[0] + sim.collected[1] + sim.collected[2] + sim.collected[3], 1)


func test_몸으로_부딪혀_부순_운석은_광물이_없음() -> void:
	var sim := _quiet_sim()
	_add_asteroid(sim, Vector2(2, 0), Vector2.ZERO, 2)
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.enemies.size(), 0, "부딪혀 부서짐")
	assert_eq(sim.minerals.size(), 0, "광물 없음")


func test_운석_크기별로_광물_등급이_고정됨() -> void:
	# 작은 운석 → 일반, 중간 → 희귀, 큰 운석 → 영웅 (무작위 없음)
	var expected := [0, 1, 2]
	for type in 3:
		for trial in 10:
			var sim := _quiet_sim()
			var a := _add_asteroid(sim, Vector2(500, 500), Vector2.ZERO, type)
			_kill(sim, a)
			for m in sim.minerals:
				assert_eq(m.grade, expected[type], "%s → %s" % [Balance.ASTEROID_TYPES[type]["name"], Balance.MINERAL_GRADES[expected[type]]["name"]])

func test_자석_범위_안의_광물은_끌려와_주워짐() -> void:
	var sim := _quiet_sim()
	var m := sim.drop_mineral(Vector2(Balance.MAGNET_RADIUS - 2.0, 0))
	m.grade = 1
	sim.update(0.05, Vector2.ZERO)
	assert_true(m.attracted, "끌려오기 시작")
	for i in 30:
		sim.update(0.05, Vector2.ZERO)
	assert_eq(sim.minerals.size(), 0, "주움")
	assert_eq(sim.collected[1], 1)
	assert_eq(sim.mineral_value, int(Balance.MINERAL_GRADES[1]["value"]))


func test_자석_범위_밖의_광물은_그대로() -> void:
	var sim := _quiet_sim()
	var m := sim.drop_mineral(Vector2(Balance.MAGNET_RADIUS + 5.0, 0))
	for i in 20:
		sim.update(0.05, Vector2.ZERO)
	assert_false(m.attracted)
	assert_true(m.pos.is_equal_approx(Vector2(Balance.MAGNET_RADIUS + 5.0, 0)), "움직이지 않음")
	assert_eq(sim.minerals.size(), 1)


func test_끌려오는_광물은_도망가는_우주선을_따라잡음() -> void:
	var sim := _quiet_sim()
	sim.drop_mineral(Vector2(-Balance.MAGNET_RADIUS + 10.0, 0))
	for i in 120:
		sim.update(1.0 / 60.0, Vector2.RIGHT)  # 광물 반대쪽으로 계속 이동
	assert_eq(sim.minerals.size(), 0, "따라잡아 주움")
	assert_eq(sim.mineral_value, sim.collected[0] * 1 + sim.collected[1] * 5 + sim.collected[2] * 20 + sim.collected[3] * 100)


func test_주우면_pickup_이벤트() -> void:
	var sim := _quiet_sim()
	sim.drop_mineral(Vector2(1, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_true(sim.events.has("pickup"))


func test_광물_가치_계산() -> void:
	assert_eq(RunSim.value_of(PackedInt32Array([3, 2, 1, 1])), 3 * 1 + 2 * 5 + 20 + 100)
	assert_eq(RunSim.value_of(PackedInt32Array([0, 0, 0, 0])), 0)


func test_광물이_너무_많으면_오래된_것부터_사라짐() -> void:
	var sim := _quiet_sim()
	var first := sim.drop_mineral(Vector2(5000, 0))
	for i in Balance.MAX_MINERALS + 10:
		sim.drop_mineral(Vector2(5000, i))
	assert_eq(sim.minerals.size(), Balance.MAX_MINERALS)
	assert_false(sim.minerals.has(first), "가장 오래된 광물 제거")


func test_파괴된_뒤에는_광물을_줍지_않음() -> void:
	var sim := _quiet_sim()
	sim.drop_mineral(Vector2(1, 0))
	sim.alive = false
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.mineral_value, 0)


# ── 우주선 방향 ──

func test_우주선은_처음에_위쪽을_바라봄() -> void:
	assert_true(is_equal_approx(RunSim.new(1).facing, -PI / 2.0))


func test_이동하면_그_방향으로_부드럽게_돈다() -> void:
	var sim := _quiet_sim()
	sim.update(0.01, Vector2.DOWN)  # 위 → 아래, 반 바퀴
	var turned := absf(angle_difference(-PI / 2.0, sim.facing))
	assert_true(turned > 0.0 and turned <= Balance.SHIP_TURN_SPEED * 0.01 + 0.0001, "한 프레임에 조금만 돎: %f" % turned)
	for i in 100:
		sim.update(0.01, Vector2.DOWN)
	assert_true(is_equal_approx(sim.facing, PI / 2.0), "결국 아래를 바라봄: %f" % sim.facing)


func test_멈추면_마지막_방향을_유지() -> void:
	var sim := _quiet_sim()
	for i in 100:
		sim.update(0.01, Vector2.RIGHT)
	assert_true(is_zero_approx(sim.facing), "오른쪽")
	for i in 50:
		sim.update(0.01, Vector2.ZERO)
	assert_true(is_zero_approx(sim.facing), "멈춰도 오른쪽 유지")


func test_짧은_쪽으로_돈다() -> void:
	# 오른쪽(0)에서 약간 위(-0.3)로: 시계 반대 방향으로 짧게
	assert_true(is_equal_approx(RunSim.turn_toward(0.0, -0.3, 0.1), -0.1))
	# 거의 왼쪽(3.0)에서 왼쪽 아래(-3.0)로: PI를 넘어 짧게 돈다
	var r := RunSim.turn_toward(3.0, -3.0, 0.1)
	assert_true(r > 3.0 or r < -3.0, "PI를 넘어감: %f" % r)
	assert_true(is_equal_approx(RunSim.turn_toward(1.0, 1.05, 0.1), 1.05), "가까우면 바로 도착")


func test_키보드와_조이스틱이_같은_방향이면_똑같이_돈다() -> void:
	var by_key := _quiet_sim()
	var by_stick := _quiet_sim()
	var key := MoveInput.keyboard_vector(true, false, false, false)  # 왼쪽 키
	var stick := MoveInput.joystick_vector(Vector2(100, 100), Vector2(40, 100), Balance.JOYSTICK_RADIUS, Balance.JOYSTICK_DEAD_ZONE)
	for i in 20:
		by_key.update(0.016, key)
		by_stick.update(0.016, stick)
	assert_true(is_equal_approx(by_key.facing, by_stick.facing), "%f / %f" % [by_key.facing, by_stick.facing])


func test_바라보는_방향과_조준은_따로() -> void:
	# 오른쪽으로 움직이면서 위쪽 운석을 쏜다
	var sim := _quiet_sim(true)
	_add_asteroid(sim, Vector2(0, -100)).hp = 100.0
	sim.update(0.01, Vector2.RIGHT)
	assert_true(sim.bullets[0].vel.normalized().y < -0.9, "탄은 위쪽")
	assert_true(absf(sim.facing) < PI / 2.0, "우주선은 오른쪽으로 돌기 시작")


# ── 황금 운석 ──

func test_황금_운석은_큰_운석보다_훨씬_단단함() -> void:
	var sim := _quiet_sim()
	var g := sim.spawn_golden()
	assert_true(g.golden)
	assert_true(g.hp >= Balance.ASTEROID_TYPES[2]["hp"] * 4.0, "체력 %f" % g.hp)
	sim.time = Balance.ASTEROID_HP_GROWTH_TIME
	assert_eq(sim.spawn_golden().hp, Balance.GOLDEN["hp"] * 2.0, "시간이 지나면 더 단단해짐")


func test_황금_운석을_부수면_전설_1개와_영웅_여러_개() -> void:
	var sim := _quiet_sim()
	var g := sim.spawn_golden()
	g.pos = Vector2(500, 500)
	_kill(sim, g)
	var counts := [0, 0, 0, 0]
	for m in sim.minerals:
		counts[m.grade] += 1
	assert_eq(counts[3], 1, "전설 1개")
	assert_true(counts[2] >= 2, "영웅 여러 개: %d" % counts[2])
	assert_eq(counts[0] + counts[1], 0)


func test_황금_운석은_부딪혀도_부서지지_않고_피해만_줌() -> void:
	var sim := _quiet_sim()
	var g := sim.spawn_golden()
	g.pos = Vector2(2, 0)
	g.vel = Vector2.ZERO
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.hp, Balance.SHIP_MAX_HP - Balance.GOLDEN["damage"], "피해")
	assert_true(sim.enemies.has(g), "황금 운석은 그대로")
	assert_eq(sim.minerals.size(), 0, "광물 없음")


func test_황금_운석은_정해진_시각에_처음_나오고_점점_자주_나옴() -> void:
	assert_true(RunSim.golden_interval(Balance.GOLDEN_RAMP_TIME) < RunSim.golden_interval(0.0), "점점 자주")
	assert_true(is_equal_approx(RunSim.golden_interval(0.0), Balance.GOLDEN_INTERVAL_START))
	assert_true(is_equal_approx(RunSim.golden_interval(99999.0), Balance.GOLDEN_INTERVAL_MIN), "최소 간격에서 멈춤")
	var sim := _quiet_sim()
	sim.set("hp", 1.0e9)
	var first := -1.0
	while sim.time < Balance.GOLDEN_FIRST_TIME + 1.0:
		sim.update(0.1, Vector2.ZERO)
		if first < 0.0 and sim.events.has("golden"):
			first = sim.time
	assert_true(absf(first - Balance.GOLDEN_FIRST_TIME) < 0.11, "첫 등장 %f초" % first)
	assert_eq(sim.golden_count(), 1)


func test_황금_운석은_동시에_최대_개수까지만() -> void:
	var sim := _quiet_sim()
	sim.set("hp", 1.0e9)
	sim.view_size = Vector2(100000, 100000)  # 멀어져서 사라지지 않게
	sim.time = 1000.0
	for i in 2000:
		sim.update(0.1, Vector2.ZERO)
	assert_eq(sim.golden_count(), Balance.GOLDEN_MAX)


func test_황금_운석은_우주선을_비스듬히_지나감() -> void:
	var sim := _quiet_sim()
	for i in 30:
		var g := sim.spawn_golden()
		var angle := absf(rad_to_deg(g.vel.angle_to(sim.player_pos - g.pos)))
		assert_true(angle <= Balance.GOLDEN_AIM_SPREAD_DEG + 0.01, "각도 %f" % angle)
		var speed := g.vel.length()
		assert_true(speed >= Balance.GOLDEN["speed_min"] - 0.01 and speed <= Balance.GOLDEN["speed_max"] + 0.01)


func test_황금_운석은_일반_운석보다_멀어져야_사라짐() -> void:
	var sim := _quiet_sim()
	var limit := RunSim.despawn_distance(sim.view_size)
	var g := sim.spawn_golden()
	g.pos = Vector2(limit * 1.2, 0)
	g.vel = Vector2.ZERO
	var rock := _add_asteroid(sim, Vector2(limit * 1.2, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_true(sim.enemies.has(g), "황금 운석은 남음")
	assert_false(sim.enemies.has(rock), "일반 운석은 사라짐")


func test_주운_광물은_그_프레임의_picked에_담김() -> void:
	var sim := _quiet_sim()
	sim.drop_mineral(Vector2(1, 0), 3)
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.picked.size(), 1)
	assert_eq(sim.picked[0]["grade"], 3)
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.picked.size(), 0, "다음 프레임엔 비워짐")
