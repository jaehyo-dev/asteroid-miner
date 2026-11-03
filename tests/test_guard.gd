extends TestCase
## v0.3.0~: 고대 경비선(따라다니며 쏘는 적 함선), 습격 중 황금 운석, 모션 테스트.


## 평소 등장·포격·습격이 끼어들지 않는 조용한 시뮬레이션
func _quiet() -> RunSim:
	var sim := RunSim.new(91)
	for t in ["_spawn_timer", "_barrage_timer", "_golden_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
		sim.set(t, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.fire_range = -1.0  # 쏘지 않음
	return sim


## 우주선 근처(화면 안, 사거리 안)에 경비선을 놓는다
func _guard_near(sim: RunSim, offset: Vector2 = Vector2(100, 0)) -> RunSim.Enemy:
	var t := sim.spawn_guard()
	t.pos = sim.player_pos + offset
	t.vel = Vector2.ZERO
	t.aim = (sim.player_pos - t.pos).angle()
	return t


# ── 고대 경비선 ──

func test_경비선은_정해진_시각에_처음_나오고_새로운_위협_이벤트() -> void:
	var sim := RunSim.new(8)
	sim.invuln = 1.0e9
	var first := -1.0
	while sim.time < Balance.GUARD_FIRST_TIME + 1.0 and first < 0.0:
		if not sim.choices.is_empty():
			sim.choose(0)
			continue
		sim.update(0.05, Vector2.ZERO)
		if sim.events.has("new_guard"):
			first = sim.time
	assert_true(first >= Balance.GUARD_FIRST_TIME - 0.06 and first <= Balance.GUARD_FIRST_TIME + 0.06, "첫 경비선 %f초" % first)
	assert_eq(sim.guard_count(), 1)


func test_경비선은_한_번만_새로운_위협_이벤트() -> void:
	var sim := _quiet()
	sim.spawn_guard()
	assert_true(sim.events.has("new_guard"))
	sim.events.clear()
	sim.spawn_guard()
	assert_false(sim.events.has("new_guard"))


func test_경비선은_멀리_있으면_다가오고_정해진_거리에서_주위를_돈다() -> void:
	var sim := _quiet()
	sim.invuln = 1.0e9
	var t := _guard_near(sim, Vector2(350, 0))
	t.vel = Vector2.ZERO
	t.reload = 1.0e9  # 쏘지 않게
	for i in 30 * 15:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	var dist := t.pos.distance_to(sim.player_pos)
	assert_true(absf(dist - Balance.GUARD_KEEP_DISTANCE) < 25.0, "정해진 거리 근처 %f" % dist)
	# 주위를 돈다: 1초 동안 각도가 바뀜
	var before := (t.pos - sim.player_pos).angle()
	for i in 30:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	var turned := absf(wrapf((t.pos - sim.player_pos).angle() - before, -PI, PI))
	assert_true(turned > 0.2, "주위를 돎 %f" % turned)


func test_경비선은_우주선을_따라오지만_우주선보다_느림() -> void:
	var sim := _quiet()
	sim.invuln = 1.0e9
	var t := _guard_near(sim, Vector2(-120, 0))
	t.reload = 1.0e9
	for i in 30 * 3:
		sim.update(1.0 / 30.0, Vector2.RIGHT)
	var gap := t.pos.distance_to(sim.player_pos)
	assert_true(gap > 120.0, "달아나면 거리가 벌어짐 %f" % gap)
	assert_true(t.vel.x > 0.0, "따라옴")
	assert_true(RunSim.guard_speed(300.0) < Balance.SHIP_SPEED, "5분이 지나도 우주선보다 느림")


func test_가까우면_물러남() -> void:
	var v := Guard.desired_velocity(Vector2(30, 0), Vector2.ZERO, Balance.GUARD_SPEED, 1.0)
	assert_true(v.x > 0.0, "바깥쪽으로 %s" % v)
	var far := Guard.desired_velocity(Vector2(400, 0), Vector2.ZERO, Balance.GUARD_SPEED, 1.0)
	assert_true(far.x < 0.0, "안쪽으로 %s" % far)
	assert_true(far.length() <= Balance.GUARD_SPEED + 0.01)
	var cw := Guard.desired_velocity(Vector2(Balance.GUARD_KEEP_DISTANCE, 0), Vector2.ZERO, Balance.GUARD_SPEED, 1.0)
	var ccw := Guard.desired_velocity(Vector2(Balance.GUARD_KEEP_DISTANCE, 0), Vector2.ZERO, Balance.GUARD_SPEED, -1.0)
	assert_true(cw.y * ccw.y < 0.0, "도는 방향이 반대")


func test_선체는_정해진_속도로만_돈다() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(100, 0))
	t.aim = 0.0  # 오른쪽(우주선 반대)을 바라봄 → 우주선은 왼쪽(PI)
	var dt := 0.1
	Guard.update(t, dt, sim.player_pos, false)
	assert_true(absf(absf(t.aim) - Balance.GUARD_TURN_SPEED * dt) < 0.001, "한 번에 %f만 돎" % t.aim)


func test_화면_밖이나_사거리_밖이면_쏘지_않음() -> void:
	var view := Vector2(640, 360)
	assert_true(Guard.can_fire_at(Vector2(100, 0), Vector2.ZERO, view, Balance.GUARD_SCREEN_MARGIN), "가까이 화면 안")
	assert_false(Guard.can_fire_at(Vector2(0, 200), Vector2.ZERO, view, Balance.GUARD_SCREEN_MARGIN), "화면 위쪽 밖")
	assert_false(Guard.can_fire_at(Vector2(Balance.GUARD_RANGE + 10.0, 0), Vector2.ZERO, Vector2(2000, 2000), 0.0), "사거리 밖")
	# 휴대폰 세로 화면: 옆으로 조금만 떨어져도 화면 밖
	assert_false(Guard.can_fire_at(Vector2(190, 0), Vector2.ZERO, Vector2(360, 640), Balance.GUARD_SCREEN_MARGIN), "세로 화면 옆 밖")


func test_조준되면_충전한_뒤_한_발을_쏘고_재장전() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(100, 0))
	t.aim = PI  # 이미 우주선 쪽
	t.reload = 0.0
	var dt := 1.0 / 60.0
	var time := 0.0
	var charge_at := -1.0
	var fire_times: Array[float] = []
	while time < Balance.GUARD_CHARGE_TIME + Balance.GUARD_FIRE_INTERVAL + Balance.GUARD_CHARGE_TIME + 0.2:
		var charging := t.charge >= 0.0
		if Guard.update(t, dt, sim.player_pos, true):
			fire_times.append(time)
		elif not charging and t.charge >= 0.0 and charge_at < 0.0:
			charge_at = time
		time += dt
	assert_true(charge_at >= 0.0 and charge_at < 0.05, "바로 충전 시작 %f" % charge_at)
	assert_eq(fire_times.size(), 2, "두 번 쏨")
	assert_true(absf(fire_times[0] - Balance.GUARD_CHARGE_TIME) < 0.05, "충전 뒤 발사 %f" % fire_times[0])
	var gap := fire_times[1] - fire_times[0]
	assert_true(absf(gap - (Balance.GUARD_FIRE_INTERVAL + Balance.GUARD_CHARGE_TIME)) < 0.05, "재장전 + 충전 간격 %f" % gap)


func test_선체가_우주선을_보지_않으면_충전하지_않음() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(100, 0))
	t.aim = 0.0  # 반대쪽
	t.reload = 0.0
	Guard.update(t, 0.01, sim.player_pos, true)
	assert_eq(t.charge, -1.0)


func test_충전_중_화면_밖으로_벗어나면_취소() -> void:
	var sim := _quiet()
	var t := _guard_near(sim)
	t.aim = PI
	t.reload = 0.0
	Guard.update(t, 0.1, sim.player_pos, true)
	assert_true(t.charge >= 0.0, "충전 시작")
	assert_false(Guard.update(t, 0.1, sim.player_pos, false))
	assert_eq(t.charge, -1.0, "취소")


func test_경비선_탄은_부술_수_없고_맞으면_정해진_피해() -> void:
	var sim := _quiet()
	sim.fire_range = Balance.FIRE_RANGE
	var t := _guard_near(sim, Vector2(100, 0))
	t.hp = 1.0e9
	t.max_hp = 1.0e9
	t.aim = PI
	t.reload = 0.0
	var hp := sim.hp
	var fired := false
	for i in 200:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		if sim.events.has("guard_fire"):
			fired = true
			assert_eq(sim.shots.size(), 1, "탄 한 발")
			assert_true(sim.shots[0].guard)
		if sim.hp < hp:
			break
	assert_true(fired, "쏨")
	assert_true(is_equal_approx(hp - sim.hp, Balance.GUARD_SHOT_DAMAGE), "피해 %f" % (hp - sim.hp))


func test_경비선_탄은_옆으로_피할_수_있음() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(150, 0))
	t.aim = PI
	t.reload = 0.0
	var hp := sim.hp
	var fired := false
	for i in 240:
		# 쏜 뒤에 위로 비켜선다
		var move := Vector2(0, -1) if fired else Vector2.ZERO
		sim.update(1.0 / 60.0, move)
		if sim.events.has("guard_fire"):
			fired = true
	assert_true(fired)
	assert_eq(sim.hp, hp, "비켜서면 맞지 않음")


func test_경비선은_부딪혀도_부서지지_않고_피해만() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(2, 0))
	t.reload = 99.0
	var hp := sim.hp
	sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_true(is_equal_approx(hp - sim.hp, Balance.GUARD["damage"]))
	assert_true(sim.enemies.has(t), "부서지지 않음")


func test_경비선을_부수면_좋은_광물() -> void:
	var sim := _quiet()
	var t := _guard_near(sim)
	sim.call("_on_enemy_destroyed", t)
	var counts := [0, 0, 0, 0]
	for m in sim.minerals:
		counts[m.grade] += 1
	for drop in Balance.GUARD_DROPS:
		assert_eq(counts[int(drop["grade"])], int(drop["count"]), "등급 %d" % int(drop["grade"]))
	# 큰 운석보다 가치가 높음
	var value := 0
	for m in sim.minerals:
		value += int(Balance.MINERAL_GRADES[m.grade]["value"])
	var big: Dictionary = Balance.ASTEROID_TYPES[2]
	assert_true(value > int(Balance.MINERAL_GRADES[big["grade"]]["value"]) * int(big["minerals"]), "가치 %d" % value)


func test_경비선은_단단함() -> void:
	var sim := _quiet()
	var t := sim.spawn_guard()
	var big: Dictionary = Balance.ASTEROID_TYPES[2]
	assert_true(t.max_hp > float(big["hp"]), "큰 운석보다 단단함")
	assert_true(t.sturdy())


func test_경비선은_동시에_최대_개수까지만() -> void:
	var sim := _quiet()
	sim.invuln = 1.0e9
	sim.view_size = Vector2(100000, 100000)  # 멀어져서 사라지지 않게
	sim.set("_guard_timer", 0.0)
	sim.time = 1000.0
	for i in 2000:
		sim.update(0.1, Vector2.ZERO)
	assert_eq(sim.guard_count(), Balance.GUARD_MAX)


func test_멀어진_경비선은_사라짐() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(RunSim.despawn_distance(sim.view_size) * Balance.GUARD_DESPAWN_FACTOR + 10.0, 0))
	sim.update(0.01, Vector2.ZERO)
	assert_false(sim.enemies.has(t))


func test_자동_공격은_가까운_운석을_황금_운석보다_먼저() -> void:
	var sim := _quiet()
	var g := sim.spawn_golden()
	g.pos = Vector2(50, 0)
	var rock := RunSim.Enemy.new()
	rock.pos = Vector2(-90, 0)
	rock.radius = 5.0
	var list: Array[RunSim.Enemy] = [g, rock]
	assert_eq(RunSim.pick_target(Vector2.ZERO, list, 170.0), rock, "조금 더 먼 운석 먼저")
	# 운석이 많이 멀면 황금 운석을 쏜다
	rock.pos = Vector2(-160, 0)
	assert_eq(RunSim.pick_target(Vector2.ZERO, list, 170.0), g)
	# 황금 운석만 있으면 황금 운석
	var only: Array[RunSim.Enemy] = [g]
	assert_eq(RunSim.pick_target(Vector2.ZERO, only, 170.0), g)
	assert_eq(RunSim.pick_target(Vector2.ZERO, only, 10.0), null, "사거리 밖")


func test_경비선은_다른_적과_똑같이_가까운_순서로_쏨() -> void:
	var sim := _quiet()
	var t := _guard_near(sim, Vector2(50, 0))
	var rock := RunSim.Enemy.new()
	rock.pos = Vector2(-90, 0)
	var list: Array[RunSim.Enemy] = [t, rock]
	assert_eq(RunSim.pick_target(Vector2.ZERO, list, 170.0), t)


# ── 습격 중 황금 운석 ──

func test_습격이_시작되면_습격_방향에서_황금_운석() -> void:
	var sim := _quiet()
	sim.invuln = 1.0e9
	sim.raid.timer = 0.01
	var started := false
	for i in int((Balance.RAID_WARNING_TIME + 1.0) * 30.0):
		sim.update(1.0 / 30.0, Vector2.ZERO)
		if sim.events.has("raid_start"):
			started = true
			assert_true(sim.events.has("raid_golden"), "황금 운석 알림")
			break
	assert_true(started)
	assert_eq(sim.golden_count(), Balance.RAID_GOLDEN_COUNT)
	for a in sim.enemies:
		if a.golden:
			var from := rad_to_deg(absf(wrapf((a.pos - sim.player_pos).angle() - sim.raid.direction, -PI, PI)))
			assert_true(from <= Balance.RAID_ARC_DEG / 2.0 + 1.0, "습격 방향에서 옴: 차이 %f도" % from)


func test_습격_황금_운석도_최대_개수를_넘지_않음() -> void:
	var sim := _quiet()
	for i in Balance.GOLDEN_MAX + Balance.RAID_GOLDEN_COUNT:
		sim.spawn_golden().pos = sim.player_pos + Vector2(300, 0)
	sim.raid.state = RaidDirector.State.WARNING
	sim.raid.timer = 0.01
	sim.update(0.05, Vector2.ZERO)
	assert_eq(sim.golden_count(), Balance.GOLDEN_MAX + Balance.RAID_GOLDEN_COUNT)
	assert_false(sim.events.has("raid_golden"))


func test_황금_운석은_곧장_오지_않고_비껴_감() -> void:
	var sim := _quiet()
	for i in 40:
		var g := sim.spawn_golden()
		var angle := absf(rad_to_deg(g.vel.angle_to(sim.player_pos - g.pos)))
		assert_true(angle >= Balance.GOLDEN_AIM_MIN_DEG - 0.01 and angle <= Balance.GOLDEN_AIM_SPREAD_DEG + 0.01, "각도 %f" % angle)


# ── 모션 ──

func test_맞으면_탄이_날아온_쪽으로_잠깐_튕김() -> void:
	var sim := _quiet()
	var a := RunSim.Enemy.new()
	a.pos = Vector2(40, 0)
	a.radius = 9.0
	a.hp = 5.0
	a.max_hp = 5.0
	sim.enemies.append(a)
	var b := RunSim.Bullet.new()
	b.pos = Vector2(30, 0)
	b.prev_pos = Vector2(20, 0)
	b.vel = Vector2(260, 0)
	b.life = 1.0
	b.damage = 1.0
	sim.bullets.append(b)
	sim.call("_check_bullet_hits")
	assert_eq(a.hit_dir, Vector2.RIGHT)
	assert_true(WorldView.knock_offset(a).x > 0.0, "오른쪽으로 밀림")
	assert_eq(a.pos, Vector2(40, 0), "실제 위치는 그대로")
	for i in int(ceilf(Balance.HIT_KNOCK_TIME * 60.0)) + 1:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(WorldView.knock_offset(a), Vector2.ZERO, "곧 제자리")


func test_체력이_줄면_금이_감() -> void:
	assert_eq(WorldView.crack_level(3.0, 3.0), 0, "멀쩡")
	assert_eq(WorldView.crack_level(2.0, 3.0), 1, "한 번 맞음")
	assert_eq(WorldView.crack_level(1.0, 3.0), 2, "두 번 맞음")
	assert_eq(WorldView.crack_level(1.0, 1.0), 0, "한 방에 부서지는 적은 금 없음")
	assert_eq(WorldView.crack_lines(9.0, 2, 2).size(), 2)
	assert_eq(WorldView.crack_lines(9.0, 2, 1)[0], WorldView.crack_lines(9.0, 2, 2)[0], "같은 운석은 같은 금")


func test_운석은_변형마다_다르게_돌고_작을수록_빠름() -> void:
	assert_true(WorldView.spin_speed(0, 9.0) < 0.0 and WorldView.spin_speed(3, 9.0) > 0.0, "방향이 다름")
	assert_true(absf(WorldView.spin_speed(3, 5.0)) > absf(WorldView.spin_speed(3, 14.0)), "작을수록 빠름")


func test_돌면_우주선이_기울고_곧게_가면_돌아옴() -> void:
	var sim := _quiet()
	var view := WorldView.new()
	view.sim = sim
	add_child(view)
	view.step(1.0 / 60.0)
	for i in 10:
		sim.update(1.0 / 60.0, Vector2.RIGHT)  # 위쪽 → 오른쪽으로 돈다
		view.step(1.0 / 60.0)
	assert_true(absf(view.bank) > 0.3, "기울어짐 %f" % view.bank)
	for i in 60:
		sim.update(1.0 / 60.0, Vector2.RIGHT)
		view.step(1.0 / 60.0)
	assert_true(absf(view.bank) < 0.01, "곧게 가면 돌아옴 %f" % view.bank)
	view.queue_free()


func test_경비선_발사음이_있음() -> void:
	var stream: AudioStreamWAV = Sfx.guard_stream()
	assert_true(stream.data.size() > 0)
	assert_true(stream.data != Sfx.fire_stream().data, "포격 발사음과 다름")
