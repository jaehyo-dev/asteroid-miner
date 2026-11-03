extends TestCase
## 위기감: 피격·위험 표시(DangerAlert), 심연의 포격, 경고음, 화면 연결 테스트.

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


# ── 심연의 포격 ──

func test_포격은_30초_안에_처음_오고_첫_포격에_배너_이벤트() -> void:
	assert_true(Balance.BARRAGE_FIRST_TIME <= 30.0)
	var sim := RunSim.new(11)
	sim.set("hp", 1.0e9)
	sim.max_hp = 1.0e9  # 강화를 골라도 체력이 최대 체력으로 깎이지 않게
	var first := -1.0
	var intro := false
	while sim.time < 30.0 and first < 0.0 and sim.alive:
		if not sim.choices.is_empty():
			sim.choose(0)
			continue
		sim.update(0.05, Vector2.ZERO)
		if sim.events.has("barrage_warning"):
			first = sim.time
			intro = sim.events.has("new_barrage")
	assert_true(first > 0.0 and first <= 30.0, "첫 포격 %f초" % first)
	assert_true(intro, "첫 포격에 new_barrage")
	sim.start_barrage()
	assert_false(sim.events.has("new_barrage") and sim.events.count("new_barrage") > 1, "배너 이벤트는 처음 한 번만")


func test_포격_흐름은_예고_충전_발사_3발() -> void:
	var b := Barrage.new(Vector2.ZERO, Vector2.RIGHT)
	var t := 0.0
	var charge_at := -1.0
	var fire_times: Array[float] = []
	while b.phase != Barrage.Phase.DONE and t < 5.0:
		var r := b.step(0.01)
		t += 0.01
		if r["charge"]:
			charge_at = t
		for i in int(r["fired"]):
			fire_times.append(t)
	assert_true(absf(charge_at - Balance.BARRAGE_WARN_TIME) < 0.011, "예고 뒤 충전 %f" % charge_at)
	assert_eq(fire_times.size(), Balance.BARRAGE_SHOTS, "3발")
	assert_true(absf(fire_times[0] - (Balance.BARRAGE_WARN_TIME + Balance.BARRAGE_CHARGE_TIME)) < 0.011, "충전 뒤 첫 발 %f" % fire_times[0])
	assert_true(absf(fire_times[1] - fire_times[0] - Balance.BARRAGE_SHOT_GAP) < 0.011, "연사 간격")


func test_포격은_우주선이_갈_곳을_노림() -> void:
	var dir := Barrage.aim_direction(Vector2(-300, 0), Vector2.ZERO, Vector2(0, 100), Balance.BARRAGE_LEAD_TIME)
	var target := Vector2(0, 100) * Balance.BARRAGE_LEAD_TIME
	assert_true(dir.is_equal_approx((target - Vector2(-300, 0)).normalized()), "앞을 막음: %s" % dir)
	var still := Barrage.aim_direction(Vector2(-300, 0), Vector2.ZERO, Vector2.ZERO, Balance.BARRAGE_LEAD_TIME)
	assert_true(still.is_equal_approx(Vector2.RIGHT), "멈춰 있으면 그 자리")


func test_에너지탄은_조준선을_따라와_가만히_있으면_맞음() -> void:
	var sim := RunSim.new(21)
	for tm in ["_spawn_timer", "_barrage_timer", "_golden_timer", "_jelly_timer", "_bug_timer"]:
		sim.set(tm, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.start_barrage()
	var hp := sim.hp
	for i in 180:
		sim.update(1.0 / 30.0, Vector2.ZERO)
	assert_true(sim.hp < hp, "맞음")
	assert_true(is_equal_approx(hp - sim.hp, Balance.BARRAGE_SHOT_DAMAGE), "무적 때문에 한 발만 맞음: %f" % (hp - sim.hp))
	assert_eq(sim.minerals.size(), 0, "광물 없음")


func test_에너지탄은_자동_공격으로_부술_수_없음() -> void:
	var sim := RunSim.new(22)
	for tm in ["_spawn_timer", "_barrage_timer", "_golden_timer", "_jelly_timer", "_bug_timer"]:
		sim.set(tm, 1.0e9)
	sim.raid.timer = 1.0e9
	var b := sim.start_barrage()
	b.timer = 0.001
	b.phase = Barrage.Phase.CHARGE
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.shots.size(), 1)
	for i in 20:
		sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 0, "에너지탄은 조준 대상이 아님 (쏘지 않음)")
	assert_eq(sim.kills, 0)


func test_조준선에서_비켜나면_피할_수_있음() -> void:
	var sim := RunSim.new(23)
	for tm in ["_spawn_timer", "_barrage_timer", "_golden_timer", "_jelly_timer", "_bug_timer"]:
		sim.set(tm, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.start_barrage()
	var hp := sim.hp
	for i in 180:
		var escape := sim.barrage_escape(sim.player_pos, 16.0)
		sim.update(1.0 / 30.0, escape)
	assert_eq(sim.hp, hp, "예고를 보고 옆으로 피하면 안 맞음")


func test_조준선과의_거리() -> void:
	assert_true(is_equal_approx(Barrage.distance_from_line(Vector2.ZERO, Vector2.RIGHT, Vector2(50, 7)), 7.0))
	assert_eq(Barrage.distance_from_line(Vector2.ZERO, Vector2.RIGHT, Vector2(-10, 0)), INF, "쏘는 곳 뒤쪽은 안전")


func test_포격_간격은_점점_짧아짐() -> void:
	assert_true(is_equal_approx(RunSim.barrage_interval(0.0), Balance.BARRAGE_INTERVAL_START))
	assert_true(RunSim.barrage_interval(Balance.SPAWN_RAMP_TIME) < RunSim.barrage_interval(0.0))
	assert_true(is_equal_approx(RunSim.barrage_interval(99999.0), Balance.BARRAGE_INTERVAL_MIN))


func test_포격_소리가_있음() -> void:
	assert_true(Sfx.charge_stream().data.size() > 1000)
	assert_true(Sfx.fire_stream().data.size() > 100)


func test_첫_포격에_배너() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.start_barrage()
	run._announce(run.sim.events)
	assert_eq(run.hud.banner_text, "??? 의 포격")
	# 조준선·에너지탄·화면 밖 표시가 오류 없이 그려지는지
	var b: Barrage = run.sim.barrages[0]
	b.phase = Barrage.Phase.CHARGE
	b.timer = 0.2
	await get_tree().create_timer(0.5).timeout  # 충전이 끝나고 발사될 만큼 (프레임 수가 아니라 실제 시간)
	assert_true(run.sim.shots.size() >= 1 or run.sim.hp < run.sim.max_hp, "발사됨")
	await wait_frames(3)
	run.queue_free()


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
	var a := RunSim.Enemy.new()
	a.radius = 9.0
	a.damage = 10.0
	a.hp = 1000.0
	a.max_hp = 1000.0
	a.pos = run.sim.player_pos
	run.sim.enemies.append(a)
	run.sim.drop_mineral(run.sim.player_pos + Vector2(2000, 0))  # 아무 효과 없는 광물
	# 화면 밖 포격 예고도 함께 그려 본다
	run.sim.start_barrage()
	await wait_frames(2)
	assert_true(run.alert.low, "체력 30% 아래 → 경고 상태")
	assert_true(run.alert.border > 0.0, "테두리 맥박")
	assert_true(run.alert.shake > 0.0, "흔들림")
	await wait_frames(3)
	run.queue_free()


func test_메뉴가_열리면_붉은_화면_효과가_남지_않음() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	# 체력 30% 밑으로 떨어진 직후 일시 정지
	run.alert.update(0.016, true, 0.2)
	assert_true(run.alert.border > 0.0 and run.alert.flash > 0.0)
	run.pause()
	await wait_frames(5)
	assert_eq(run.alert.flash_strength(), 0.0, "일시 정지 중 번쩍임 없음")
	assert_eq(run.alert.border_strength(1.0), 0.0, "일시 정지 중 테두리 없음")
	assert_true(run.alert.low, "체력 막대 깜빡임 상태는 유지")
	run.queue_free()


func test_파괴된_뒤_게임_오버_화면이_붉게_남지_않음() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.hp = 1.0
	run.sim.invuln = 0.0
	var a := RunSim.Enemy.new()
	a.radius = 9.0
	a.damage = 50.0
	a.hp = 1000.0
	a.max_hp = 1000.0
	a.pos = run.sim.player_pos
	run.sim.enemies.append(a)
	await wait_frames(30)
	assert_false(run.sim.alive)
	assert_true(run.menu.visible, "게임 오버 메뉴")
	assert_eq(run.alert.flash_strength(), 0.0, "붉은 번쩍임이 남지 않음")
	assert_eq(run.alert.shake, 0.0)
	run.queue_free()
