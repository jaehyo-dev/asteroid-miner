extends TestCase
## 광물 보너스 표시 (v0.5.1): 퍼센트, 오를 때 커짐, 색, 주울 때 숫자, 처음 한 번만 말풍선, 지금 귀환하면 얻는 가치.
## 게임 규칙(위험도 배율)은 바뀌지 않았는지도 확인한다.

const RunScene := preload("res://scenes/run.tscn")


## 보너스 x%가 되는 시각
func _time_for(percent: float) -> float:
	return Balance.RISK_RAMP_TIME * percent / 100.0 / (Balance.RISK_MAX - 1.0)


func test_보너스_퍼센트() -> void:
	assert_eq(RiskBonus.percent(0.0), 0)
	assert_eq(RiskBonus.percent(_time_for(40.0)), 40, "x1.40 → +40%")
	assert_eq(RiskBonus.percent(_time_for(40.0) - 0.5), 39, "내림")
	assert_eq(RiskBonus.percent(Balance.RISK_RAMP_TIME * 2.0), roundi((Balance.RISK_MAX - 1.0) * 100.0), "상한")
	assert_eq(Hud.bonus_text(_time_for(40.0)), "광물 보너스 +40%")


func test_보너스가_10퍼센트_오를_때만_정수_픽셀로_들썩임() -> void:
	var b := RiskBonus.new()
	assert_false(b.update(0.1, 0.0), "시작")
	assert_eq(b.lift(), 0, "평소 위치")
	assert_false(b.update(0.1, _time_for(9.0)), "+9%는 아직")
	assert_true(b.update(0.1, _time_for(10.0)), "+10%에서 오름")
	b.update(RiskBonus.PULSE_TIME / 2.0, _time_for(10.0))
	assert_eq(b.lift(), RiskBonus.PULSE_LIFT, "중간에 가장 높이 뜸")
	assert_false(b.update(RiskBonus.PULSE_TIME, _time_for(15.0)), "같은 단계에서는 다시 오르지 않음")
	assert_eq(b.lift(), 0, "다시 제자리")
	assert_true(b.update(0.1, _time_for(20.0)), "+20%에서 또 오름")


func test_보너스_색은_노랑_주황_빨강() -> void:
	assert_eq(Hud.bonus_color(0.0), Hud.BONUS_COLORS[0], "시작 노랑")
	assert_true(Hud.bonus_color(Balance.RISK_RAMP_TIME / 2.0).is_equal_approx(Hud.BONUS_COLORS[1]), "절반 주황")
	assert_true(Hud.bonus_color(Balance.RISK_RAMP_TIME).is_equal_approx(Hud.BONUS_COLORS[2]), "최대 빨강")


func test_주울_때_숫자는_보너스_적용값() -> void:
	assert_eq(RiskBonus.applied(20, 0.0), 20)
	assert_eq(RiskBonus.applied(20, _time_for(40.0)), 28, "20 × 1.4")
	assert_eq(RiskBonus.applied(5, Balance.RISK_RAMP_TIME), 10, "최대 배율")


func test_천_단위_쉼표() -> void:
	assert_eq(Hud.thousands(0), "0")
	assert_eq(Hud.thousands(999), "999")
	assert_eq(Hud.thousands(1240), "1,240")
	assert_eq(Hud.thousands(1234567), "1,234,567")


func test_게이트가_열려_있을_때만_지금_귀환하면_얻는_가치() -> void:
	var sim := RunSim.new(1)
	sim.cargo.counts = PackedInt32Array([0, 0, 50, 0])  # 영웅 50개 = 1000
	sim.time = _time_for(24.0)
	assert_eq(Hud.return_text(sim), "", "닫혀 있음")
	sim.gate.state = WarpGate.State.OPEN
	assert_eq(Hud.return_text(sim), "지금 귀환하면 1,240 확보")
	assert_eq(sim.final_value(), 1240, "실제 귀환 가치와 같음")


func test_규칙은_그대로() -> void:
	# 표시만 바뀌고 배율 규칙은 v0.4.0 그대로
	assert_eq(Balance.RISK_MAX, 2.0)
	assert_eq(Balance.RISK_RAMP_TIME, 300.0)
	assert_eq(RunSim.risk_mult(150.0), 1.5)


func test_말풍선은_처음_한_번만_뜨고_저장됨() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.time = _time_for(0.5)
	await wait_frames(2)
	assert_eq(run.hud.tip_time, 0.0, "+0%에서는 아직")
	run.sim.time = _time_for(1.0)
	await wait_frames(2)
	assert_true(run.hud.tip_time > 0.0, "말풍선")
	assert_true(SaveData.load_file().risk_tip_seen, "봤다고 저장")
	run.hud.tip_time = 0.0
	run.sim.time = _time_for(20.0)
	await wait_frames(2)
	assert_eq(run.hud.tip_time, 0.0, "다음에 올라도 다시 안 뜸")
	run.queue_free()
	await wait_frames()
	# 다음 판에서도 안 뜸
	var run2: Node = RunScene.instantiate()
	add_child(run2)
	await wait_frames(2)
	run2.sim.time = _time_for(10.0)
	await wait_frames(2)
	assert_eq(run2.hud.tip_time, 0.0, "이미 봤으면 안 뜸")
	run2.queue_free()


func test_말풍선_봤는지_저장_불러오기() -> void:
	var save := SaveData.new()
	save.risk_tip_seen = true
	save.save_file()
	assert_true(SaveData.load_file().risk_tip_seen)
	assert_false(SaveData.from_dict({"risk_tip_seen": "네"}).risk_tip_seen, "참/거짓이 아니면 안 본 것")
	assert_false(SaveData.from_dict({}).risk_tip_seen, "예전 저장(v0.5.0)은 안 본 것")


func test_보너스_말풍선과_게이트_가치가_있어도_오류_없이_그림() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([10, 5, 3, 1])
	run.sim.gate.state = WarpGate.State.OPEN
	run.hud.show_tip()
	run.sim.time = _time_for(55.0)
	await wait_frames(3)
	assert_true(run.hud.tip_time > 0.0)
	run.queue_free()


func test_결과_화면_보너스_계산이_맞아_보임() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([0, 0, 50, 0])  # 영웅 50개 = 1000
	run.sim.time = _time_for(24.95)  # 보너스 24.95%: 내림 24%, 최종 1249.5 → 반올림
	run.sim.returned = true
	run._show_game_over()
	var earned: int = run.sim.final_value()
	assert_true(run.menu.body_text().contains("광물 가치 1000 + 보너스 %d (+24%%) = %d" % [earned - 1000, earned]), run.menu.body_text())
	run.queue_free()
