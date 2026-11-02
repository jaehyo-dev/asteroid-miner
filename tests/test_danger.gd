extends TestCase
## v0.1.3 위기감: 피격·위험 표시(DangerAlert), 조준 운석, 경고음, 화면 연결 테스트.

const STEP := 1.0 / 30.0


## 시간을 흘려 보내며 경고음 횟수를 센다.
func _run(alert: DangerAlert, seconds: float, ratio: float) -> int:
	var sounds := 0
	for i in int(seconds / STEP):
		if alert.update(STEP, false, ratio):
			sounds += 1
	return sounds


func test_맞으면_흔들림과_붉은_번쩍임이_잠깐_생김() -> void:
	var alert := DangerAlert.new()
	alert.update(STEP, true, 0.9)
	assert_true(alert.shake > 0.0 and alert.flash > 0.0)
	assert_true(alert.shake_offset(RandomNumberGenerator.new()).length() <= Balance.HIT_SHAKE_STRENGTH * 1.5)
	_run(alert, maxf(Balance.HIT_SHAKE_TIME, Balance.HIT_FLASH_TIME) + 0.1, 0.9)
	assert_eq(alert.shake, 0.0, "흔들림 끝")
	assert_eq(alert.flash_strength(), 0.0, "번쩍임 끝")
	assert_eq(alert.shake_offset(RandomNumberGenerator.new()), Vector2.ZERO)


func test_체력이_충분하면_경고_없음() -> void:
	var alert := DangerAlert.new()
	assert_false(alert.update(STEP, true, 0.5))
	assert_false(alert.low)
	assert_eq(alert.border_strength(0.0), 0.0)


func test_처음_30퍼센트_밑으로_떨어지면_테두리_2초와_경고음_한_번() -> void:
	var alert := DangerAlert.new()
	assert_true(alert.update(STEP, true, Balance.LOW_HP_RATIO - 0.01), "경고음")
	assert_true(alert.low)
	assert_true(is_equal_approx(alert.border, Balance.LOW_HP_BORDER_TIME), "테두리 %f초" % alert.border)
	assert_eq(_run(alert, Balance.LOW_HP_BORDER_TIME + 0.1, 0.2), 0, "가만히 있으면 경고음 다시 안 울림")
	assert_eq(alert.border_strength(1.0), 0.0, "2초 뒤 테두리 사라짐")
	assert_true(alert.low, "체력 막대 깜빡임 상태는 유지")


func test_낮은_체력에서_또_맞으면_짧게_붉어지고_경고음은_10초에_한_번() -> void:
	var alert := DangerAlert.new()
	alert.update(STEP, true, 0.25)  # 처음 → 경고음
	_run(alert, Balance.LOW_HP_BORDER_TIME + 0.1, 0.25)
	assert_false(alert.update(STEP, true, 0.2), "10초 안이라 경고음 없음")
	assert_true(alert.border > 0.0 and alert.border <= Balance.LOW_HP_REHIT_BORDER_TIME + 0.001, "짧게 다시 붉어짐 %f" % alert.border)
	_run(alert, Balance.LOW_HP_SOUND_COOLDOWN, 0.2)
	assert_true(alert.update(STEP, true, 0.15), "10초가 지나면 다시 경고음")


func test_체력이_30퍼센트_위로_회복되면_초기화() -> void:
	var alert := DangerAlert.new()
	alert.update(STEP, true, 0.25)
	alert.update(STEP, false, 0.6)
	assert_false(alert.low, "경고 상태 해제")
	assert_true(alert.update(STEP, true, 0.25), "다시 떨어지면 처음처럼 경고음")
	assert_true(is_equal_approx(alert.border, Balance.LOW_HP_BORDER_TIME))


func test_파괴되면_경고하지_않음() -> void:
	var alert := DangerAlert.new()
	assert_false(alert.update(STEP, true, 0.0))
	assert_false(alert.low)


func test_체력_막대는_경고_상태일_때만_깜빡임() -> void:
	var alert := DangerAlert.new()
	var colors := {}
	for i in 20:
		colors[Hud.hp_bar_color(alert, i * 0.05)] = true
	assert_eq(colors.size(), 1, "평소엔 한 색")
	alert.update(STEP, true, 0.2)
	colors.clear()
	for i in 20:
		colors[Hud.hp_bar_color(alert, i * 0.05)] = true
	assert_eq(colors.size(), 2, "경고 상태엔 깜빡임")


# ── 조준 운석 ──

func test_조준_운석은_30초_안에_처음_나옴() -> void:
	assert_true(Balance.AIMED_FIRST_TIME <= 30.0)
	var sim := RunSim.new(11)
	sim.set("hp", 1.0e9)
	var first := -1.0
	while sim.time < 30.0 and first < 0.0:
		if not sim.choices.is_empty():
			sim.choose(0)
			continue
		sim.update(0.05, Vector2.ZERO)
		if sim.events.has("aimed"):
			first = sim.time
	assert_true(first > 0.0 and first <= 30.0, "첫 조준 운석 %f초" % first)


func test_조준_운석은_줄지어_우주선을_정확히_노림() -> void:
	var sim := RunSim.new(12)
	sim.set("_spawn_timer", 1.0e9)
	sim.player_pos = Vector2(300, -100)
	var group := sim.spawn_aimed()
	assert_eq(group.size(), Balance.AIMED_COUNT)
	for a in group:
		assert_true(a.aimed)
		var angle := absf(rad_to_deg(a.vel.angle_to(sim.player_pos - group[0].pos)))
		assert_true(angle < 0.5, "정확히 노림: %f도" % angle)
	assert_true(group[0].pos.distance_to(sim.player_pos) < group[1].pos.distance_to(sim.player_pos), "한 줄로 뒤따라옴")


func test_조준_운석은_움직이는_우주선을_앞질러_노림() -> void:
	var sim := RunSim.new(13)
	sim.player_vel = Vector2(80, 0)
	var group := sim.spawn_aimed()
	var a := group[0]
	# 날아가 만나는 시점에 우주선이 있을 곳 근처를 지나간다
	var best := INF
	for i in 400:
		var t := i * 0.02
		best = minf(best, (a.pos + a.vel * t).distance_to(sim.player_pos + sim.player_vel * t))
	assert_true(best < 2.0, "만나는 지점 오차 %f" % best)


func test_조준_운석_간격은_점점_짧아짐() -> void:
	assert_true(is_equal_approx(RunSim.aimed_interval(0.0), Balance.AIMED_INTERVAL_START))
	assert_true(RunSim.aimed_interval(Balance.SPAWN_RAMP_TIME) < RunSim.aimed_interval(0.0))
	assert_true(is_equal_approx(RunSim.aimed_interval(99999.0), Balance.AIMED_INTERVAL_MIN))


func test_가만히_있으면_30초_안팎에_첫_피격() -> void:
	# 첫 위협이 실제로 위협인지: 가만히 있는 우주선이 처음 맞는 시각의 중앙값
	var firsts: Array[float] = []
	for seed in range(3000, 3008):
		var sim := RunSim.new(seed)
		var t := 999.0
		while sim.time < 90.0 and t > 900.0:
			if not sim.choices.is_empty():
				sim.choose(0)
				continue
			sim.update(1.0 / 30.0, Vector2.ZERO)
			if sim.events.has("hit"):
				t = sim.time
		firsts.append(t)
	firsts.sort()
	assert_true(firsts[firsts.size() / 2] <= 30.0, "첫 피격 중앙값 %f초" % firsts[firsts.size() / 2])


# ── 경고음과 화면 ──

func test_경고음이_있음() -> void:
	var s: AudioStreamWAV = Sfx.warning_stream()
	assert_not_null(s)
	assert_true(s.data.size() > 1000)


func test_출격_화면에서_맞으면_흔들리고_체력_낮으면_경고_표시() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.hp = run.sim.max_hp * 0.35
	run.sim.invuln = 0.0
	var a := RunSim.Asteroid.new()
	a.radius = 9.0
	a.damage = 10.0
	a.hp = 1000.0
	a.max_hp = 1000.0
	a.pos = run.sim.player_pos
	run.sim.asteroids.append(a)
	run.sim.drop_mineral(run.sim.player_pos + Vector2(2000, 0))  # 아무 효과 없는 광물
	# 화면 밖 조준 운석도 함께 그려 본다
	for r in run.sim.spawn_aimed():
		r.pos = run.sim.player_pos + Vector2(900, 0)
	await wait_frames(2)
	assert_true(run.alert.low, "체력 30% 아래 → 경고 상태")
	assert_true(run.alert.border > 0.0, "테두리 맥박")
	assert_true(run.alert.shake > 0.0, "흔들림")
	await wait_frames(3)
	run.queue_free()
