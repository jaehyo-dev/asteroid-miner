extends TestCase
## 워프 게이트 연출 테스트: 등장(조각이 모여 맞물림) → 열림 → 닫히기 직전(붉게·떨림) → 닫힘(흩어짐),
## 원형 게이지, 충전 시 빨라지는 소용돌이, 귀환 성공(빨려 들어감·하얀 번쩍임), 고리 픽셀 아트, 상태별 소리.

const RunScene := preload("res://scenes/run.tscn")
const STEP := 1.0 / 60.0


func _open_gate() -> WarpGate:
	var g := WarpGate.new()
	g.state = WarpGate.State.OPEN
	g.timer = Balance.GATE_OPEN_TIME
	return g


## 연출을 seconds초 진행하고 나온 연출 이벤트를 모두 돌려준다
func _run(fx: GateFx, g: WarpGate, seconds: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var t := 0.0
	while t < seconds - 0.0001:
		out.append_array(fx.step(STEP, g, PackedStringArray()))
		t += STEP
	return out


func test_등장하면_조각이_모여_맞물린_뒤_섬광과_함께_열린다() -> void:
	var fx := GateFx.new()
	var g := _open_gate()
	fx.step(STEP, g, PackedStringArray(["gate_open"]))
	assert_eq(fx.assembled(), 0.0, "처음엔 흩어져 있음")
	assert_eq(fx.vortex_open(), 0.0, "소용돌이는 아직 닫힘")
	var events := _run(fx, g, GateFx.ASSEMBLE_TIME * 0.5)
	assert_true(fx.assembled() > 0.5 and fx.assembled() < 1.0, "모이는 중 %.2f (처음에 빠름)" % fx.assembled())
	assert_false(events.has("gate_locked"))
	events = _run(fx, g, GateFx.ASSEMBLE_TIME * 0.5 + 0.02)
	assert_eq(fx.assembled(), 1.0, "맞물림")
	assert_eq(events.count("gate_locked"), 1, "맞물리는 순간 한 번")
	assert_true(fx.lock_flash() > 0.8, "섬광")
	_run(fx, g, GateFx.OPEN_TIME)
	assert_eq(fx.vortex_open(), 1.0, "소용돌이 열림")
	assert_eq(fx.lock_flash(), 0.0, "섬광은 잠깐")
	events = _run(fx, g, 1.0)
	assert_false(events.has("gate_locked"), "다시 울리지 않음")


func test_닫히기_직전에는_점점_붉어지고_한_번_알린다() -> void:
	var fx := GateFx.new()
	var g := _open_gate()
	g.timer = GateFx.CLOSING_TIME + 1.0
	assert_eq(GateFx.heat(g), 0.0)
	assert_false(_run(fx, g, 0.1).has("gate_closing"))
	g.timer = GateFx.CLOSING_TIME / 2.0
	assert_true(is_equal_approx(GateFx.heat(g), 0.5))
	assert_eq(_run(fx, g, 0.5).count("gate_closing"), 1, "한 번만 알림")
	g.timer = 0.0
	assert_eq(GateFx.heat(g), 1.0)
	# 충전 중에는 닫히지 않으므로 붉어지지 않음. 충전하다 나가면 다시 알린다.
	g.charge = 1.0
	assert_eq(GateFx.heat(g), 0.0, "충전 중")
	_run(fx, g, 0.1)
	g.charge = -1.0
	assert_eq(_run(fx, g, 0.1).count("gate_closing"), 1, "충전 뒤 다시 알림")
	g.state = WarpGate.State.WAITING
	assert_eq(GateFx.heat(g), 0.0, "닫힌 게이트")


func test_원형_게이지는_남은_시간_충전_중이면_충전량() -> void:
	var g := _open_gate()
	assert_eq(GateFx.gauge(g), 1.0)
	g.timer = Balance.GATE_OPEN_TIME / 4.0
	assert_true(is_equal_approx(GateFx.gauge(g), 0.25))
	g.charge = Balance.WARP_CHARGE_TIME * 0.6
	assert_true(is_equal_approx(GateFx.gauge(g), 0.6), "충전량")


func test_충전할수록_소용돌이가_빨라진다() -> void:
	var fx := GateFx.new()
	var g := _open_gate()
	_run(fx, g, 1.0)
	var idle := fx.spin
	fx.spin = 0.0
	g.charge = Balance.WARP_CHARGE_TIME * 0.99
	_run(fx, g, 1.0)
	assert_true(fx.spin > idle * 5.0, "평소 %.2f, 충전 %.2f" % [idle, fx.spin])


func test_닫히면_조각이_흩어지고_소용돌이가_오므라든다() -> void:
	var fx := GateFx.new()
	var g := _open_gate()
	_run(fx, g, 0.1)
	assert_eq(fx.scatter(), -1.0, "열려 있을 때는 흩어지지 않음")
	g.state = WarpGate.State.WAITING
	fx.step(STEP, g, PackedStringArray(["gate_close"]))
	assert_eq(fx.scatter(), 0.0)
	_run(fx, g, GateFx.COLLAPSE_TIME * 0.5)
	assert_true(fx.scatter() > 0.4 and fx.scatter() < 0.6)
	assert_true(fx.vortex_open() < 0.001, "소용돌이는 먼저 닫힘")
	_run(fx, g, GateFx.COLLAPSE_TIME * 0.5 + 0.02)
	assert_eq(fx.scatter(), -1.0, "연출 끝")


func test_귀환하면_빨려_들어가고_하얗게_번쩍인_뒤_끝난다() -> void:
	var fx := GateFx.new()
	var g := _open_gate()
	assert_eq(fx.suck(), 0.0)
	fx.step(STEP, g, PackedStringArray(["warp_done"]))
	_run(fx, g, GateFx.SUCK_TIME * 0.5)
	assert_true(fx.suck() > 0.4 and fx.suck() < 0.6)
	assert_eq(fx.white_flash(), 0.0, "빨려 들어가는 중에는 아직")
	var peak := 0.0
	var t := 0.0
	while not fx.warp_finished():
		fx.step(STEP, g, PackedStringArray())
		peak = maxf(peak, fx.white_flash())
		t += STEP
		assert_true(t < 3.0, "끝나야 함")
		if t >= 3.0:
			break
	assert_eq(fx.suck(), 1.0)
	assert_true(peak > 0.95, "하얗게 번쩍임 %.2f" % peak)
	assert_eq(fx.white_flash(), 0.0, "끝나면 꺼짐")


func test_떨림은_닫히기_직전에만_1에서_2픽셀() -> void:
	assert_eq(GateView.shake_offset(3, 1.0, 0.0), Vector2.ZERO)
	var moved := false
	for i in 8:
		var o := GateView.shake_offset(i, 1.23, 1.0)
		assert_true(absf(o.x) <= 2.0 and absf(o.y) <= 2.0)
		moved = moved or o != Vector2.ZERO
		assert_eq(o, GateView.shake_offset(i, 1.23, 1.0), "같은 시각이면 같은 값")
	assert_true(moved, "떨림")


func test_고리는_겹치지_않는_8조각이고_집게에는_경고_줄무늬() -> void:
	var size := PixelArt.GATE_TEX_SIZE
	var owner := {}
	var hazard := [0, 0, 0, 0, 0, 0, 0, 0]
	for i in PixelArt.GATE_SEGMENTS:
		var img := PixelArt.gate_segment(i).get_image()
		assert_eq(img.get_size(), Vector2i(size, size))
		var count := 0
		for y in size:
			for x in size:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					count += 1
					assert_false(owner.has(Vector2i(x, y)), "조각 %d가 다른 조각과 겹침" % i)
					owner[Vector2i(x, y)] = i
					if c.is_equal_approx(PixelArt.GATE_HAZARD[0]):
						hazard[i] += 1
		assert_true(count > 100, "조각 %d 픽셀 %d개" % [i, count])
	for i in PixelArt.GATE_SEGMENTS:
		if i % 2 == 0:
			assert_true(hazard[i] > 5, "집게 %d 경고 줄무늬" % i)
		else:
			assert_eq(hazard[i], 0, "장갑판 %d에는 줄무늬 없음" % i)


func test_표시등은_고리_위에_있다() -> void:
	var lights := PixelArt.gate_lights()
	assert_eq(lights.size(), 12, "장갑판 4 + 집게 8")
	for l in lights:
		var r := (l["pos"] as Vector2).length()
		assert_true(r > PixelArt.GATE_RING_IN and r < PixelArt.GATE_RING_OUT, "반지름 %.1f" % r)


func test_상태별_게이트_소리가_있고_웅웅거림은_반복된다() -> void:
	for s in Sfx.warp_streams():
		assert_true(s.data.size() > 1000)
	var streams := Sfx.warp_streams()
	assert_eq(streams.size(), 7)
	assert_eq((streams[2] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "열려 있는 동안 반복")


func test_잡음과_미끄러지는_소리를_만든다() -> void:
	var a := Sfx.synth([[1000.0, 0.05]], "noise", 0.5)
	var b := Sfx.synth([[1000.0, 0.05]], "noise", 0.5)
	assert_eq(a.data, b.data, "잡음도 매번 같음")
	var sweep := Sfx.synth([[200.0, 0.1, 2000.0]], "square", 0.5)
	assert_eq(sweep.data.size(), int(Sfx.MIX_RATE * 0.1) * 2)
	var rest := Sfx.synth([[0.0, 0.05]], "square", 0.5)
	for i in rest.data.size():
		if rest.data[i] != 0:
			assert_true(false, "쉼은 조용해야 함")
			break


func test_출격_화면에서_게이트_상태별로_오류_없이_그린다() -> void:
	# 그리기 함수 밖에서 그리거나 값이 잘못되면 엔진 오류가 나고, 테스트 실행기가 실패로 잡는다.
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	assert_false(run.gate_view.visible, "닫혀 있으면 숨김")
	run.sim.enemies.clear()
	run.sim.gate.timer = 0.0
	await wait_frames(3)
	assert_true(run.gate_view.visible, "열리면 보임")
	assert_eq(run.gate_view.position, run.sim.gate.pos.round())
	await _wait_until(run, func() -> bool: return run.gate_view.fx.vortex_open() >= 1.0)  # 등장 연출(약 0.9초)
	await wait_frames(2)
	assert_true(run.gate_view.particles.emitting, "빛 알갱이가 빨려 듦")
	# 충전 중 (빛줄기)
	run.sim.player_pos = run.sim.gate.pos + Vector2(10, 0)
	await wait_frames(3)
	assert_true(run.sim.gate.charge >= 0.0, "충전 중")
	# 닫히기 직전 (붉게, 떨림, 파편)
	run.sim.player_pos = run.sim.gate.pos + Vector2(120, 0)
	run.sim.gate.timer = 1.0
	await _wait_until(run, func() -> bool: return run.gate_view._chips.size() > 0)
	assert_true(run.gate_view._chips.size() > 0, "파편이 떨어져 나감")
	# 닫힘 (흩어짐)
	await _wait_until(run, func() -> bool: return run.sim.gate.state == WarpGate.State.WAITING)
	assert_eq(run.sim.gate.state, WarpGate.State.WAITING)
	await wait_frames(2)
	assert_true(run.gate_view.visible, "닫힐 때 흩어지는 연출 중에는 보임")
	assert_false(run.gate_view.particles.emitting)
	run.queue_free()


func test_게이트_웅웅거림은_메뉴에서_멈추고_화면을_떠나면_꺼진다() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	Sfx.start_gate_hum()
	assert_true(Sfx.gate_hum_audible())
	run.pause()
	assert_false(Sfx.gate_hum_audible(), "일시 정지 중에는 멈춤")
	run._close_menu()
	assert_true(Sfx.gate_hum_audible(), "닫으면 이어짐")
	run.queue_free()
	await wait_frames(1)
	assert_false(Sfx.gate_hum_audible(), "출격 화면을 떠나면 꺼짐")


## 조건이 참이 될 때까지 프레임을 진행한다 (최대 약 1000프레임). 그동안 우주선이 부서지지 않게 체력을 채운다.
func _wait_until(run: Node, cond: Callable) -> void:
	for i in 1000:
		if cond.call():
			return
		run.sim.hp = run.sim.max_hp
		await wait_frames(1)
