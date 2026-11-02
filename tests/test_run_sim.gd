extends TestCase
## 출격 로직(RunSim) 테스트: 이동, 운석 등장, 충돌, 체력, 무적, 사망.


## 운석이 저절로 생기지 않고(등장 타이머를 미룸) 자동 공격도 하지 않는 시뮬레이션
func _quiet_sim(shoot: bool = false) -> RunSim:
	var sim := RunSim.new(1234)
	sim.set("_spawn_timer", 1.0e9)
	if not shoot:
		sim.fire_range = -1.0
	return sim


func _add_asteroid(sim: RunSim, pos: Vector2, vel: Vector2 = Vector2.ZERO, type: int = 0) -> RunSim.Asteroid:
	var a := RunSim.Asteroid.new()
	a.type = type
	a.radius = Balance.ASTEROID_TYPES[type]["radius"]
	a.damage = Balance.ASTEROID_TYPES[type]["damage"]
	a.max_hp = Balance.ASTEROID_TYPES[type]["hp"]
	a.hp = a.max_hp
	a.pos = pos
	a.vel = vel
	sim.asteroids.append(a)
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
	assert_true(is_equal_approx(RunSim.spawn_interval(9999.0), Balance.SPAWN_INTERVAL_MIN))


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
		var before := sim.asteroids.size()
		sim.update(1.0 / 60.0, Vector2.ZERO)
		spawned += maxi(sim.asteroids.size() - before, 0)
	# 처음 10초 간격은 약 1초 → 대략 9~10개 (충돌로 사라진 것은 제외될 수 있어 최소만 확인)
	assert_true(sim.asteroids.size() >= 5 and sim.asteroids.size() <= 12, "운석 수 %d" % sim.asteroids.size())


func test_운석_최대_개수를_넘지_않음() -> void:
	var sim := RunSim.new(5)
	sim.set("hp", 1.0e9)
	sim.view_size = Vector2(10000, 10000)  # 아무것도 멀어져서 사라지지 않게
	sim.time = 10000.0
	for i in 2000:
		sim.update(0.1, Vector2.ZERO)
	assert_true(sim.asteroids.size() <= Balance.MAX_ASTEROIDS, "운석 수 %d" % sim.asteroids.size())


func test_운석에_맞으면_체력이_줄고_운석은_부서짐() -> void:
	var sim := _quiet_sim()
	_add_asteroid(sim, Vector2(2, 0), Vector2.ZERO, 1)
	sim.update(0.01, Vector2.ZERO)
	assert_true(is_equal_approx(sim.hp, Balance.SHIP_MAX_HP - Balance.ASTEROID_TYPES[1]["damage"]), "체력 %f" % sim.hp)
	assert_eq(sim.asteroids.size(), 0, "부서짐")
	assert_true(sim.events.has("hit"), "hit 이벤트")
	assert_true(sim.invuln > 0.0, "무적 시작")


func test_무적_중에는_운석이_지나감() -> void:
	var sim := _quiet_sim()
	sim.invuln = 0.5
	_add_asteroid(sim, Vector2(2, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.hp, Balance.SHIP_MAX_HP, "데미지 없음")
	assert_eq(sim.asteroids.size(), 1, "운석은 그대로")


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
	assert_eq(sim.asteroids.size(), 1)


func test_같은_시드면_같은_결과() -> void:
	var a := RunSim.new(42)
	var b := RunSim.new(42)
	for i in 300:
		var move := Vector2.from_angle(i * 0.1)
		a.update(1.0 / 60.0, move)
		b.update(1.0 / 60.0, move)
	assert_eq(a.asteroids.size(), b.asteroids.size())
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
	assert_eq(RunSim.nearest_asteroid(Vector2.ZERO, sim.asteroids, 200.0), near)
	assert_eq(RunSim.nearest_asteroid(Vector2.ZERO, sim.asteroids, 40.0), null, "사거리 밖")
	assert_eq(RunSim.nearest_asteroid(Vector2(100, 10), sim.asteroids, 200.0), far)


func test_여러_발은_가운데_기준_부채꼴() -> void:
	var one := RunSim.spread_angles(1.0, 1, 0.2)
	assert_eq(one.size(), 1)
	assert_true(is_equal_approx(one[0], 1.0))
	var three := RunSim.spread_angles(0.0, 3, 0.2)
	assert_true(is_equal_approx(three[0], -0.2) and is_equal_approx(three[1], 0.0) and is_equal_approx(three[2], 0.2), "%s" % three)
	var two := RunSim.spread_angles(0.0, 2, 0.2)
	assert_true(is_equal_approx(two[0], -0.1) and is_equal_approx(two[1], 0.1), "%s" % two)


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
	assert_eq(sim.asteroids.size(), 0)
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
	sim.asteroids.clear()  # 맞을 대상을 없앤다
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

func _kill(sim: RunSim, a: RunSim.Asteroid) -> void:
	# 탄으로 부순 것과 같은 처리
	sim.call("_on_asteroid_destroyed", a)


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
	assert_eq(sim.asteroids.size(), 0, "부딪혀 부서짐")
	assert_eq(sim.minerals.size(), 0, "광물 없음")


func test_광물_등급_비율() -> void:
	var sim := _quiet_sim()
	var counts := [0, 0, 0, 0]
	for i in 20000:
		counts[sim.drop_mineral(Vector2(1000, 1000)).grade] += 1
		sim.minerals.clear()
	var total := 0.0
	for g in Balance.MINERAL_GRADES:
		total += g["weight"]
	for i in 4:
		var expected: float = 20000.0 * Balance.MINERAL_GRADES[i]["weight"] / total
		assert_true(absf(counts[i] - expected) < maxf(expected * 0.15, 30.0), "%s: %d (예상 %.0f)" % [Balance.MINERAL_GRADES[i]["name"], counts[i], expected])


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
