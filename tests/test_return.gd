extends TestCase
## 귀환 시스템 테스트: 워프 게이트 등장·소멸, 충전·취소, 위험도 배율, 화물칸 교체, 사망 보존과 비상 보험.

const RunScene := preload("res://scenes/run.tscn")
const STEP := 1.0 / 30.0


## 게이트를 seconds초 동안 진행한다 (우주선 위치 고정). 일어난 일을 모두 모아 돌려준다.
func _advance(g: WarpGate, rng: RandomNumberGenerator, seconds: float, player := Vector2.ZERO) -> PackedStringArray:
	var events: PackedStringArray = []
	var t := 0.0
	while t < seconds - 0.0001:
		events.append_array(g.update(STEP, rng, player))
		t += STEP
	return events


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return r


# ── 워프 게이트 ──────────────────────────────────────

func test_게이트는_정해진_시각에_열리고_닫힌다() -> void:
	var g := WarpGate.new()
	var rng := _rng()
	_advance(g, rng, Balance.GATE_FIRST_TIME - 0.1)
	assert_eq(g.state, WarpGate.State.WAITING, "첫 시각 전에는 닫힘")
	var events := _advance(g, rng, 0.2)
	assert_eq(g.state, WarpGate.State.OPEN, "첫 시각에 열림")
	assert_true(events.has("gate_open"))
	_advance(g, rng, Balance.GATE_OPEN_TIME - 0.3)
	assert_eq(g.state, WarpGate.State.OPEN, "열린 시간 동안 유지")
	events = _advance(g, rng, 0.3)
	assert_eq(g.state, WarpGate.State.WAITING, "열린 시간이 지나면 닫힘")
	assert_true(events.has("gate_close"))
	# 다음 게이트는 첫 게이트로부터 GATE_INTERVAL 뒤
	_advance(g, rng, Balance.GATE_INTERVAL - Balance.GATE_OPEN_TIME - 0.3)
	assert_eq(g.state, WarpGate.State.WAITING)
	_advance(g, rng, 0.3)
	assert_eq(g.state, WarpGate.State.OPEN, "다음 게이트")


func test_게이트는_미리_알린_방향_정해진_거리에_생긴다() -> void:
	var g := WarpGate.new()
	var player := Vector2(300, -120)
	var rng := _rng()
	_advance(g, rng, STEP, player)
	assert_false(is_nan(g.direction), "기다리는 동안 열릴 방향을 미리 알 수 있음")
	var hint := g.direction
	_advance(g, rng, Balance.GATE_FIRST_TIME, player)
	assert_eq(g.state, WarpGate.State.OPEN)
	assert_true(absf(g.pos.distance_to(player) - Balance.GATE_DISTANCE) < 0.01, "거리 %.1f" % g.pos.distance_to(player))
	assert_true(absf(wrapf((g.pos - player).angle() - hint, -PI, PI)) < 0.001, "알린 방향에 열림")
	_advance(g, rng, Balance.GATE_OPEN_TIME + 0.1, player)
	assert_eq(g.state, WarpGate.State.WAITING)
	_advance(g, rng, STEP, player)
	assert_false(is_nan(g.direction), "다음 게이트 방향도 미리 정해짐")


func _open_gate() -> WarpGate:
	var g := WarpGate.new()
	g.timer = 0.0
	g.update(STEP, _rng(), Vector2.ZERO)
	assert_eq(g.state, WarpGate.State.OPEN)
	return g


func test_게이트_안에_5초_머무르면_귀환() -> void:
	var g := _open_gate()
	var rng := _rng()
	var events := _advance(g, rng, 0.5, g.pos)
	assert_true(events.has("warp_charge"), "들어가면 충전 시작")
	_advance(g, rng, Balance.WARP_CHARGE_TIME - 1.0, g.pos)
	assert_false(g.done, "5초 전에는 아직")
	events = _advance(g, rng, 0.6, g.pos)
	assert_true(g.done, "5초 채우면 귀환")
	assert_true(events.has("warp_done"))


func test_충전_중_게이트를_벗어나면_취소되고_처음부터() -> void:
	var g := _open_gate()
	var rng := _rng()
	_advance(g, rng, 3.0, g.pos)
	var outside := g.pos + Vector2(Balance.GATE_RADIUS + 1.0, 0)
	var events := _advance(g, rng, STEP, outside)
	assert_true(events.has("warp_cancel"), "벗어나면 취소")
	assert_eq(g.charge, -1.0)
	_advance(g, rng, 3.0, g.pos)
	assert_false(g.done, "다시 들어오면 처음부터 충전")
	# 가장자리 바로 안쪽은 게이트 안
	events = _advance(g, rng, STEP, g.pos + Vector2(Balance.GATE_RADIUS - 0.5, 0))
	assert_false(events.has("warp_cancel"), "반지름 안쪽은 취소 아님")


func test_충전_중에는_게이트가_닫히지_않고_다음_일정은_그대로() -> void:
	var g := _open_gate()
	var rng := _rng()
	_advance(g, rng, Balance.GATE_OPEN_TIME - 2.0)
	_advance(g, rng, 3.0, g.pos)  # 닫힐 시간을 넘겨 충전
	assert_eq(g.state, WarpGate.State.OPEN, "충전 중에는 열려 있음")
	var events := _advance(g, rng, STEP, g.pos + Vector2(100, 0))
	assert_true(events.has("warp_cancel") and events.has("gate_close"), "벗어나면 바로 닫힘")
	# 열린 뒤 GATE_INTERVAL에 다음 게이트 (늦게 닫혀도 밀리지 않음)
	assert_true(absf(g.timer - (Balance.GATE_INTERVAL - Balance.GATE_OPEN_TIME - 1.0)) < 0.1, "다음까지 %.2f초" % g.timer)


func test_닫힌_게이트는_충전되지_않음() -> void:
	var g := WarpGate.new()
	var events := _advance(g, _rng(), 1.0, g.pos)
	assert_false(events.has("warp_charge"))
	assert_eq(g.charge_progress(), 0.0)


# ── 위험도 배율 ──────────────────────────────────────

func test_위험도_배율은_시간에_따라_오르고_상한이_있다() -> void:
	assert_eq(RunSim.risk_mult(0.0), 1.0)
	assert_true(is_equal_approx(RunSim.risk_mult(Balance.RISK_RAMP_TIME / 2.0), 1.5))
	assert_eq(RunSim.risk_mult(Balance.RISK_RAMP_TIME), Balance.RISK_MAX)
	assert_eq(RunSim.risk_mult(Balance.RISK_RAMP_TIME * 3.0), Balance.RISK_MAX, "상한")
	assert_eq(RunSim.risk_mult(-5.0), 1.0)
	assert_eq(Hud.bonus_text(Balance.RISK_RAMP_TIME / 2.0), "광물 보너스 +50%")


# ── 화물칸 ───────────────────────────────────────────

func _full_cargo(capacity: int, grade: int) -> Cargo:
	var c := Cargo.new()
	c.capacity = capacity
	for i in capacity:
		c.add(grade)
	return c


func test_빈칸이_있으면_그대로_싣는다() -> void:
	var c := Cargo.new()
	assert_eq(c.add(1), 5)
	assert_eq(c.size(), 1)
	assert_eq(c.value(), 5)
	assert_false(c.is_full())


func test_꽉_차면_더_좋은_광물은_가장_싼_광물과_바꿔_싣는다() -> void:
	var c := _full_cargo(3, 0)
	c.counts = PackedInt32Array([1, 2, 0, 0])
	assert_true(c.is_full())
	assert_eq(c.add(2), 20 - 1, "늘어난 가치 = 차이")
	assert_eq(c.counts, PackedInt32Array([0, 2, 1, 0]), "가장 싼 일반을 버림")
	assert_eq(c.size(), 3, "칸수는 그대로")
	assert_eq(c.add(3), 100 - 5, "다음으로 싼 희귀를 버림")
	assert_eq(c.counts, PackedInt32Array([0, 1, 1, 1]))


func test_꽉_차면_같거나_낮은_등급은_싣지_않는다() -> void:
	var c := _full_cargo(2, 1)
	assert_eq(c.add(1), 0, "같은 등급")
	assert_eq(c.add(0), 0, "낮은 등급")
	assert_eq(c.counts, PackedInt32Array([0, 2, 0, 0]))


func test_화물칸이_꽉_차도_경험치는_그대로_받는다() -> void:
	var sim := RunSim.new(1)
	sim.cargo.capacity = 0
	var before := sim.xp
	var gain := sim.collect(1)
	assert_eq(gain, 0, "화물칸에는 못 실음")
	assert_eq(sim.xp - before, RunSim.mineral_xp(1), "경험치는 받음")
	assert_eq(sim.collected[1], 1, "주운 기록은 남음")


func test_주우면_화물칸에_실리고_줍기_정보에_늘어난_가치가_담긴다() -> void:
	var sim := RunSim.new(1)
	sim.drop_mineral(sim.player_pos, 2)
	sim.update(STEP, Vector2.ZERO)
	assert_eq(sim.cargo.counts[2], 1)
	assert_eq(sim.picked.size(), 1)
	assert_eq(sim.picked[0]["gain"], 20)
	assert_eq(Hud.cargo_text(sim.cargo), "화물 1/%d · 가치 20" % Balance.CARGO_CAPACITY)
	sim.cargo.capacity = 1
	assert_eq(Hud.cargo_text(sim.cargo), "화물 가득 1/1 · 가치 20")


# ── 사망 보존과 비상 보험 ────────────────────────────

func test_보존_비율은_50퍼센트에서_보험_단계마다_5퍼센트_최대_75퍼센트() -> void:
	assert_eq(Cargo.keep_ratio(0), 0.5)
	assert_true(is_equal_approx(Cargo.keep_ratio(1), 0.55))
	assert_true(is_equal_approx(Cargo.keep_ratio(5), 0.75))
	assert_eq(Cargo.keep_ratio(6), 0.75, "상한")
	assert_eq(Cargo.keep_ratio(-1), 0.5)


func test_죽으면_비싼_광물부터_남긴다() -> void:
	# 10개 중 5개: 전설 1, 영웅 2, 희귀 2 (일반 5개는 버림)
	var kept := Cargo.preserved(PackedInt32Array([5, 3, 2, 1]), 0.5)
	assert_eq(kept, PackedInt32Array([0, 2, 2, 1]))
	assert_eq(Cargo.preserved(PackedInt32Array([3, 0, 0, 0]), 0.5), PackedInt32Array([1, 0, 0, 0]), "내림")
	assert_eq(Cargo.preserved(PackedInt32Array([20, 0, 0, 0]), Cargo.keep_ratio(1)), PackedInt32Array([11, 0, 0, 0]), "55%: 소수 오차 없이 11개")
	assert_eq(Cargo.preserved(PackedInt32Array([0, 0, 0, 0]), 0.5), PackedInt32Array([0, 0, 0, 0]))


func test_귀환하면_화물칸_100퍼센트_죽으면_보존분만_배율을_곱해_가져간다() -> void:
	var sim := RunSim.new(1)
	sim.cargo.counts = PackedInt32Array([4, 2, 1, 1])  # 가치 4 + 10 + 20 + 100 = 134
	sim.time = Balance.RISK_RAMP_TIME / 2.0  # 배율 x1.5
	sim.returned = true
	assert_true(sim.is_over())
	assert_eq(sim.brought_home(), PackedInt32Array([4, 2, 1, 1]), "100% 보존")
	assert_eq(sim.final_value(), roundi(134 * 1.5))
	sim.returned = false
	sim.alive = false
	assert_eq(sim.brought_home(), PackedInt32Array([0, 2, 1, 1]), "8개 중 4개, 비싼 것부터")
	assert_eq(sim.final_value(), roundi(130 * 1.5))
	sim.insurance_level = 5
	assert_eq(Cargo.total(sim.brought_home()), 6, "보험 75%")


func test_게이트에서_충전을_마치면_판이_끝나고_멈춘다() -> void:
	var sim := RunSim.new(3)
	sim.gate.timer = 0.0
	sim.update(STEP, Vector2.ZERO)
	assert_eq(sim.gate.state, WarpGate.State.OPEN)
	sim.enemies.clear()
	var t := 0.0
	while not sim.returned and t < Balance.WARP_CHARGE_TIME + 1.0:
		sim.player_pos = sim.gate.pos  # 게이트 안에 머문다 (적에 맞아도 움직이지 않음)
		sim.hp = sim.max_hp
		sim.update(STEP, Vector2.ZERO)
		t += STEP
	assert_true(sim.returned, "귀환")
	assert_true(sim.alive)
	assert_true(absf(t - Balance.WARP_CHARGE_TIME) < 0.1, "충전 %.2f초" % t)
	var time := sim.time
	sim.update(STEP, Vector2.ZERO)
	assert_eq(sim.time, time, "귀환 뒤에는 멈춤")


# ── 화면 ─────────────────────────────────────────────

func test_게이트_글자() -> void:
	var g := WarpGate.new()
	g.timer = 23.2
	assert_eq(Hud.gate_text(g), "다음 게이트 00:24")
	g.state = WarpGate.State.OPEN
	g.timer = 11.5
	assert_eq(Hud.gate_text(g), "게이트 닫힘 12")
	g.charge = Balance.WARP_CHARGE_TIME * 0.5
	assert_eq(Hud.gate_text(g), "워프 충전 50%")


func test_워프_소리가_만들어져_있다() -> void:
	for s in Sfx.warp_streams():
		assert_true(s.data.size() > 1000)


func test_귀환하면_저장하고_기지로_넘길_결과를_만든다() -> void:
	var old_path := SaveData.path
	SaveData.path = "user://test_return_flow_save.json"
	var saved := SaveData.new()
	saved.credits = 100
	saved.save_file()
	var run: Node = RunScene.instantiate()
	run.auto_leave = false
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([2, 0, 1, 0])
	run.sim.enemies.clear()
	run.sim.gate.timer = 0.0
	await wait_frames(2)
	assert_eq(run.sim.gate.state, WarpGate.State.OPEN)
	run.sim.gate.charge = Balance.WARP_CHARGE_TIME - 0.001
	run.sim.player_pos = run.sim.gate.pos
	await wait_frames(3)
	assert_true(run.sim.returned)
	assert_false(run.banked, "빨려 들어가는 연출 동안은 아직 안 넘어감")
	var white_seen := false
	for i in 300:  # 연출(약 1.2초)이 끝날 때까지
		await wait_frames(1)
		white_seen = white_seen or run.hud.white > 0.5
		if run.banked:
			break
	assert_true(white_seen, "화면이 하얗게 번쩍임")
	assert_false(run.menu.visible, "결과 화면은 출격 화면에 뜨지 않음")
	assert_true(App.landing, "기지가 착륙으로 시작")
	assert_eq(App.return_result["title"], "귀환 성공!")
	var body: String = App.return_result["body"]
	assert_true(body.contains("100% 귀환"), body)
	assert_true(body.contains("광물 가치 22"), body)
	var earned: int = run.sim.final_value()
	assert_eq(SaveData.load_file().credits, 100 + earned, "기지로 넘어가기 전에 저장됨")
	await wait_frames(5)
	assert_eq(SaveData.load_file().credits, 100 + earned, "두 번 더하지 않음")
	run.pause()
	assert_false(run.menu.visible, "귀환 뒤에는 일시 정지 안 됨")
	run.queue_free()
	App.landing = false
	App.return_result = {}
	DirAccess.remove_absolute(SaveData.path)
	SaveData.path = old_path


func test_파괴되면_보존_정보가_나온다() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([2, 0, 1, 1])
	run.sim.alive = false
	run._show_game_over()
	assert_eq(run.menu.title_text(), "우주선 파괴")
	assert_true(run.menu.body_text().contains("50% 보존 (2/4개"), run.menu.body_text())
	run.queue_free()


func test_충전음은_메뉴가_뜨면_멈추고_닫으면_이어지며_화면을_떠나면_꺼진다() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	Sfx.play_warp_charge()
	assert_true(Sfx.warp_charge_audible(), "충전 중")
	run.pause()
	assert_false(Sfx.warp_charge_audible(), "일시 정지 중에는 멈춤")
	assert_false(run.gate_view.particles.can_process(), "일시 정지 중에는 게이트 빛 알갱이도 멈춤")
	run._close_menu()
	assert_true(Sfx.warp_charge_audible(), "닫으면 이어짐")
	assert_true(run.gate_view.particles.can_process(), "닫으면 빛 알갱이도 이어짐")
	run.queue_free()
	await wait_frames(1)
	assert_false(Sfx.warp_charge_audible(), "출격 화면을 떠나면 꺼짐")


func test_게이트_예고_화살표와_열린_게이트를_오류_없이_그린다() -> void:
	# 그리기 함수 밖에서 그리거나 값이 잘못되면 엔진 오류가 나고, 테스트 실행기가 실패로 잡는다.
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.gate.timer = Balance.GATE_HINT_TIME / 2.0  # 예고 화살표가 보이는 때
	await wait_frames(2)
	assert_false(is_nan(run.sim.gate.direction), "예고 방향이 정해짐")
	run.sim.gate.timer = 0.0
	await wait_frames(2)
	assert_eq(run.sim.gate.state, WarpGate.State.OPEN)
	run.sim.gate.timer = 2.0  # 닫히기 직전 깜빡임
	await wait_frames(2)
	run.queue_free()
