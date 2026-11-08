extends TestCase
## 효과음 (Kenney 팩): 파일·라이선스, 동시 재생 수 제한, 음 높이 랜덤, 연속 줍기 음 높이, 행동별 소리 이름

const PACKS := ["kenney_sci-fi", "kenney_impact", "kenney_interface"]


func _stop_all() -> void:
	for sound_name in Sfx.SOUNDS:
		for p: AudioStreamPlayer in Sfx.pool(sound_name):
			p.stop()


func test_모든_소리_파일과_라이선스가_있음() -> void:
	for pack in PACKS:
		assert_true(FileAccess.file_exists(Sfx.SFX_DIR + pack + "/LICENSE.txt"), pack + " 라이선스")
	for sound_name in Sfx.SOUNDS:
		var sound: Dictionary = Sfx.SOUNDS[sound_name]
		for f in sound["files"]:
			assert_true(load(Sfx.SFX_DIR + f + ".ogg") is AudioStream, f)
		assert_eq(Sfx.pool(sound_name).size(), int(sound["max"]), sound_name + " 재생기 수")
		for p: AudioStreamPlayer in Sfx.pool(sound_name):
			assert_eq(p.bus, &"SFX", "효과음 버스")


func test_같은_소리는_동시_재생_수까지만() -> void:
	_stop_all()
	var limit: int = Sfx.SOUNDS["shoot"]["max"]
	for i in limit:
		assert_true(Sfx.play("shoot"), "%d번째는 남" % (i + 1))
	assert_false(Sfx.play("shoot"), "넘치면 안 남")
	assert_true(Sfx.play("hit_rock"), "다른 소리는 따로 셈")
	_stop_all()


func test_음_높이는_표의_범위_안에서_랜덤() -> void:
	Sfx.rng.seed = 7
	var seen := {}
	for i in 20:
		_stop_all()
		Sfx.play("shoot")
		var pitch: float = (Sfx.pool("shoot")[0] as AudioStreamPlayer).pitch_scale
		assert_true(pitch >= 0.95 - 0.0001 and pitch <= 1.05 + 0.0001, "±5%% 안: %f" % pitch)
		seen[snappedf(pitch, 0.001)] = true
	assert_true(seen.size() > 5, "매번 조금씩 다름")
	# 랜덤 0을 주면 표의 음 높이 × 배율 그대로
	_stop_all()
	Sfx.play("break_small", 0.0, 2.0)
	assert_true(is_equal_approx((Sfx.pool("break_small")[0] as AudioStreamPlayer).pitch_scale, 2.6))
	_stop_all()


func test_운석은_클수록_낮고_크게() -> void:
	var s := Sfx.SOUNDS
	assert_true(s["break_small"]["pitch"] > s["break_mid"]["pitch"] and s["break_mid"]["pitch"] > s["break_big"]["pitch"], "낮아짐")
	assert_true(s["break_small"]["db"] < s["break_mid"]["db"] and s["break_mid"]["db"] < s["break_big"]["db"], "커짐")
	assert_true(s["shoot"]["db"] < s["levelup"]["db"], "자주 나는 발사는 레벨업보다 작게")


func test_부서진_적의_소리_이름() -> void:
	var Run := load("res://scripts/run.gd")
	var a := RunSim.Enemy.new()
	for type in 3:
		a.type = type
		assert_eq(Run.break_sound(a), ["break_small", "break_mid", "break_big"][type])
	a.golden = true
	assert_eq(Run.break_sound(a), "break_big", "황금 운석은 묵직하게")
	var bug := RunSim.Enemy.new()
	bug.kind = "bug"
	assert_eq(Run.break_sound(bug), "enemy_destroy")
	for sound_name in ["pickup_0", "pickup_1", "pickup_2", "pickup_3"]:
		assert_true(Sfx.SOUNDS.has(sound_name))
	assert_true(Sfx.SOUNDS["pickup_0"]["files"] != Sfx.SOUNDS["pickup_3"]["files"], "등급마다 다른 음색")


func test_연속_줍기는_반음씩_올라가고_끊기면_처음부터() -> void:
	var c := PickupCombo.new()
	assert_eq(c.pick(0.0), 0, "첫 줍기")
	assert_eq(c.pick(0.5), 1)
	assert_eq(c.pick(1.4), 2, "앞 줍기에서 1초 안")
	for i in 20:
		c.pick(1.5 + i * 0.1)
	assert_eq(c.steps, Juice.PICKUP_COMBO_MAX_SEMITONES, "최대 +12반음")
	assert_eq(c.pick(10.0), 0, "1초 넘게 쉬면 처음부터")
	assert_true(is_equal_approx(PickupCombo.pitch_of(12), 2.0), "12반음 = 한 옥타브")
	assert_true(is_equal_approx(PickupCombo.pitch_of(0), 1.0))


func test_탄이_맞으면_맞음_사건() -> void:
	var sim := RunSim.new(1234)
	sim.set("_spawn_timer", 1.0e9)
	var a := RunSim.Enemy.new()
	a.radius = Balance.ASTEROID_TYPES[2]["radius"]
	a.max_hp = 999.0
	a.hp = a.max_hp
	a.pos = Vector2(0, -30)
	sim.enemies.append(a)
	var found := false
	for i in 60:
		sim.update(0.01, Vector2.ZERO)
		if sim.events.has("hit_rock"):
			found = true
			break
	assert_true(found, "운석에 맞으면 hit_rock")
