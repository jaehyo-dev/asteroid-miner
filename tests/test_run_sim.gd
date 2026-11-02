extends TestCase
## 출격 로직(RunSim) 테스트: 이동, 운석 등장, 충돌, 체력, 무적, 사망.


## 운석이 저절로 생기지 않게 큰 시간 동안 등장 타이머를 미룬 시뮬레이션
func _quiet_sim() -> RunSim:
	var sim := RunSim.new(1234)
	sim.set("_spawn_timer", 1.0e9)
	return sim


func _add_asteroid(sim: RunSim, pos: Vector2, vel: Vector2 = Vector2.ZERO, type: int = 0) -> RunSim.Asteroid:
	var a := RunSim.Asteroid.new()
	a.type = type
	a.radius = Balance.ASTEROID_TYPES[type]["radius"]
	a.damage = Balance.ASTEROID_TYPES[type]["damage"]
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
