extends TestCase
## 효과음 (Kenney 팩을 다듬은 wav, tools/make_sfx.py): 파일·라이선스, 동시 재생 수 제한, 음 높이 랜덤, 연속 줍기 음 높이, 행동별 소리 이름

const PACKS := ["kenney_sci-fi", "kenney_impact", "kenney_interface", "zer0_sol_reload"]


func _stop_all() -> void:
	for sound_name in Sfx.SOUNDS:
		for p: AudioStreamPlayer in Sfx.pool(sound_name):
			p.stop()


## 실제로 들리는 평균 크기(dB) = 파일 평균 크기 + 표의 음량
func _level_db(sound_name: String) -> float:
	var sound: Dictionary = Sfx.SOUNDS[sound_name]
	# 가져온 소리는 압축되어 있어 원본 wav의 data 덩어리를 직접 읽는다
	var wav := FileAccess.get_file_as_bytes(Sfx.SFX_DIR + sound["files"][0] + ".wav")
	var pos := 12
	while wav.slice(pos, pos + 4).get_string_from_ascii() != "data":
		pos += 8 + wav.decode_u32(pos + 4)
	var size := wav.decode_u32(pos + 4)
	var total := 0.0
	for i in range(pos + 8, pos + 8 + size, 2):
		total += pow(wav.decode_s16(i) / 32768.0, 2.0)
	return linear_to_db(sqrt(total / (size / 2.0))) + float(sound["db"])


func test_모든_소리_파일과_라이선스가_있음() -> void:
	for pack in PACKS:
		assert_true(FileAccess.file_exists("res://assets/sfx/" + pack + "/LICENSE.txt"), pack + " 라이선스")
	for sound_name in Sfx.SOUNDS:
		var sound: Dictionary = Sfx.SOUNDS[sound_name]
		for f in sound["files"]:
			assert_true(load(Sfx.SFX_DIR + f + ".wav") is AudioStreamWAV, f)
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
	var e := RunSim.Enemy.new()
	for kind in ["bug", "jelly", RunSim.GUARD]:
		e.kind = kind
		assert_true(Sfx.SOUNDS.has("destroy_" + kind), kind + " 파괴음")
		assert_true(Sfx.SOUNDS.has("hit_" + kind), kind + " 맞음 소리")
		assert_eq(Run.break_sound(e), "destroy_" + kind)
	for part in ["hit_", "destroy_"]:
		var bug_db := _level_db(part + "bug")
		assert_true(bug_db < _level_db(part + "jelly") and bug_db < _level_db(part + "guard"), part + " 날벌레가 가장 작게")
	for sound_name in ["pickup_0", "pickup_1", "pickup_2", "pickup_3"]:
		assert_true(Sfx.SOUNDS.has(sound_name))
	assert_true(Sfx.SOUNDS["pickup_0"]["files"] != Sfx.SOUNDS["pickup_3"]["files"], "등급마다 다른 음색")


func test_연속_줍기는_반음씩_올라가고_끊기면_처음부터() -> void:
	var c := PickupCombo.new()
	assert_eq(c.pick(0.0, [0])["semi"], 0, "첫 줍기")
	assert_eq(c.pick(0.5, [0])["semi"], 1)
	assert_eq(c.pick(1.0, [0])["semi"], 2, "앞 줍기에서 0.6초 안")
	for i in 20:
		c.pick(1.1 + i * 0.1, [0])
	assert_eq(c.steps, 5, "최대 +5반음")
	assert_eq(Juice.PICKUP_COMBO_MAX_SEMITONES, 5)
	assert_eq(c.pick(10.0, [0])["semi"], 0, "0.6초 넘게 쉬면 처음부터")
	assert_true(is_equal_approx(PickupCombo.pitch_of(12), 2.0), "12반음 = 한 옥타브")
	assert_true(is_equal_approx(PickupCombo.pitch_of(0), 1.0))


func test_줍기_0_05초_안은_한_번_높은_등급_우선() -> void:
	var c := PickupCombo.new()
	assert_eq(c.pick(0.0, [0, 2, 1])["grade"], 2, "한 프레임에 여럿이면 가장 높은 등급")
	assert_true(c.pick(0.02, [0]).is_empty(), "묶음 안 같거나 낮은 등급은 안 냄")
	assert_eq(c.pick(0.03, [3])["grade"], 3, "묶음 안이라도 더 높은 등급은 따로 냄")
	assert_false(c.pick(0.06, [0]).is_empty(), "0.05초 지나면 새 묶음")
	assert_true(c.pick(1.0, []).is_empty(), "주운 게 없으면 없음")


func test_줍기_1초_12번이면_한_번_6dB_작게_전설은_3dB까지만() -> void:
	var c := PickupCombo.new()
	var last := {}
	for i in 12:
		last = c.pick(i * 0.08, [0])
	assert_true(absf(last["db"] - (-6.02)) < 0.05, "1초에 12번이면 -6dB (%s)" % last["db"])
	assert_eq(PickupCombo.rate_db(3), 0.0, "3번 이하는 그대로")
	var legend := c.pick(0.95, [3])
	assert_eq(legend["db"], Juice.PICKUP_LEGEND_FLOOR_DB, "전설은 -3dB까지만")


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


func test_적_소리는_종류별_맞음_사건이고_짧음() -> void:
	var sim := RunSim.new(1234)
	sim.set("_spawn_timer", 1.0e9)
	var a := RunSim.Enemy.new()
	a.kind = "bug"
	a.radius = 40.0
	a.max_hp = 999.0
	a.hp = a.max_hp
	a.pos = Vector2(0, -30)
	sim.enemies.append(a)
	var found := false
	for i in 60:
		sim.update(0.01, Vector2.ZERO)
		if sim.events.has("hit_bug"):
			found = true
			break
	assert_true(found, "날벌레가 맞으면 hit_bug")
	# 실제 길이 = 파일 길이 / 음 높이
	for sound_name in ["hit_guard", "hit_jelly", "hit_bug", "destroy_jelly", "destroy_bug"]:
		var sound: Dictionary = Sfx.SOUNDS[sound_name]
		for f in sound["files"]:
			assert_true(load(Sfx.SFX_DIR + f + ".wav").get_length() / float(sound["pitch"]) <= 0.33, f + " 약 0.3초")
	assert_true(absf(load(Sfx.SFX_DIR + "destroy_guard.wav").get_length() / float(Sfx.SOUNDS["destroy_guard"]["pitch"]) - 0.5) < 0.06, "경비선 파괴 약 0.5초")
	var bug_len: float = load(Sfx.SFX_DIR + "destroy_bug.wav").get_length()
	assert_true(bug_len < load(Sfx.SFX_DIR + "destroy_jelly.wav").get_length(), "날벌레가 가장 짧음")
