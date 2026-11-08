extends TestCase
## 운석 깨짐 소리 몰림 줄이기 (SoundThrottle)


func test_창_안에서는_뒤로_갈수록_작고_최대_수가_넘으면_안_남() -> void:
	var t := SoundThrottle.new(0.5, 3, -5.0)
	assert_eq(t.next_db(10.0), 0.0, "처음은 그대로")
	assert_eq(t.next_db(10.1), -5.0)
	assert_eq(t.next_db(10.2), -10.0)
	assert_eq(t.next_db(10.3), -INF, "4번째는 안 남")
	assert_eq(t.next_db(10.45), -INF, "안 난 소리는 세지 않지만 창 안에 3개가 남아 있음")


func test_창이_지나면_다시_처음_크기() -> void:
	var t := SoundThrottle.new(0.5, 3, -5.0)
	t.next_db(1.0)
	t.next_db(1.1)
	assert_eq(t.next_db(1.55), -5.0, "1.0은 지났고 1.1만 남음")
	assert_eq(t.next_db(3.0), 0.0, "모두 지남")


func test_운석_깨짐_소리는_짧음() -> void:
	# 꼬리를 잘라 약 0.3초 (큰 운석은 조금 길게): 게임의 음 높이(재생 속도)로 나눈 실제 길이
	for n in ["break_small", "break_mid"]:
		var s: AudioStreamWAV = load(Sfx.SFX_DIR + n + ".wav")
		assert_true(s.get_length() / float(Sfx.SOUNDS[n]["pitch"]) <= 0.33, "%s %.2f초" % [n, s.get_length()])
	var big: AudioStreamWAV = load(Sfx.SFX_DIR + "break_big.wav")
	assert_true(big.get_length() / float(Sfx.SOUNDS["break_big"]["pitch"]) <= 0.6, "큰 운석 %.2f초" % big.get_length())


func test_한_프레임에_운석이_많이_깨져도_소리는_최대_수까지만_작아지며_남() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	var names := ["break_small", "break_mid"]
	for n in names:
		for p: AudioStreamPlayer in Sfx.pool(n):
			p.stop()
	run.sim.events.clear()
	run.sim.picked.clear()
	run.sim.crashed.clear()
	run.sim.destroyed.clear()
	for type in [0, 0, 1, 1]:
		var rock := RunSim.Enemy.new()
		rock.type = type
		run.sim.destroyed.append(rock)
	run._play_sounds()
	var dbs: Array[float] = []
	for n in names:
		for p: AudioStreamPlayer in Sfx.pool(n):
			if p.playing:
				dbs.append(p.volume_db - float(Sfx.SOUNDS[n]["db"]))
	dbs.sort()
	assert_eq(dbs.size(), Juice.BREAK_SOUND_MAX, "최대 수까지만")
	assert_true(is_equal_approx(dbs[0], Juice.BREAK_SOUND_STEP_DB * 2) and is_equal_approx(dbs[2], 0.0), "뒤로 갈수록 작게 %s" % [dbs])
	run.queue_free()


func test_큰_운석은_몰려도_제_크기로_남() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	for p: AudioStreamPlayer in Sfx.pool("break_big"):
		p.stop()
	for i in Juice.BREAK_SOUND_MAX:
		run._break_sounds.next_db(run.sim.time)  # 이미 다 찬 상태
	run.sim.events.clear()
	run.sim.picked.clear()
	run.sim.crashed.clear()
	run.sim.destroyed.clear()
	var big := RunSim.Enemy.new()
	big.type = 2
	run.sim.destroyed.append(big)
	run._play_sounds()
	var player: AudioStreamPlayer = Sfx.pool("break_big")[0]
	assert_true(player.playing, "소리가 남")
	assert_eq(player.volume_db, float(Sfx.SOUNDS["break_big"]["db"]), "작아지지 않음")
	run.queue_free()
