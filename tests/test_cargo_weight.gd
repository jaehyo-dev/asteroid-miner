extends TestCase
## 화물 무게 테스트: 화물 비율별 이동 속도, 이동 속도 강화와 곱해지는 순서, 처음 느려질 때 안내 한 번, HUD 색.

const STEP := 1.0 / 30.0


func _approx(actual: float, expected: float, message: String) -> void:
	assert_true(is_equal_approx(actual, expected), "%s: %s ≠ %s" % [message, actual, expected])


## 빈 우주에서 화물칸을 count개 채운 출격 (적이 나오기 전 첫 프레임만 쓴다)
func _sim_with_cargo(count: int, base := {}) -> RunSim:
	var sim := RunSim.new(3)
	sim.apply_base(base)
	sim.cargo.counts = PackedInt32Array([count, 0, 0, 0])
	return sim


func test_화물_비율별_속도_배율() -> void:
	_approx(Cargo.speed_mult(0.0), 1.0, "빈 화물칸")
	_approx(Cargo.speed_mult(Balance.CARGO_HEAVY_START), 1.0, "느려지기 시작하는 비율까지는 그대로")
	_approx(Cargo.speed_mult(1.0), 1.0 - Balance.CARGO_HEAVY_SLOW, "가득 차면 최대 감속")
	var mid := (Balance.CARGO_HEAVY_START + 1.0) / 2.0
	_approx(Cargo.speed_mult(mid), 1.0 - Balance.CARGO_HEAVY_SLOW / 2.0, "중간은 직선으로 절반 감속")
	_approx(Cargo.speed_mult(1.5), 1.0 - Balance.CARGO_HEAVY_SLOW, "넘쳐도 최대 감속까지만")
	# 지금 기준값 확인: 25%까지 그대로, 가득 차면 -30%
	_approx(Balance.CARGO_HEAVY_START, 0.25, "시작 비율")
	_approx(Balance.CARGO_HEAVY_SLOW, 0.3, "최대 감속")


func test_실제_이동_속도에_무게가_적용됨() -> void:
	var cap := Balance.CARGO_CAPACITY
	for case in [[0, 1.0], [cap / 4, 1.0], [cap, 1.0 - Balance.CARGO_HEAVY_SLOW]]:
		var sim := _sim_with_cargo(case[0])
		sim.update(STEP, Vector2.RIGHT)
		_approx(sim.player_vel.length(), Balance.SHIP_SPEED * case[1], "화물 %d칸" % case[0])


func test_이동_속도_강화에_무게가_곱해짐() -> void:
	var sim := _sim_with_cargo(Balance.CARGO_CAPACITY, {"speed": 2})
	sim.upgrade_levels["speed"] = 3
	sim.apply_upgrades()
	var boosted := Balance.SHIP_SPEED * (1.0 + 3 * Balance.UP_SPEED_ADD + 2 * Balance.BASE_SPEED_ADD)
	_approx(sim.move_speed, boosted, "강화 속도는 무게와 상관없이 기본값 기준")
	_approx(sim.current_speed(), boosted * (1.0 - Balance.CARGO_HEAVY_SLOW), "무게는 강화된 속도에 곱함")
	sim.update(STEP, Vector2.UP)
	_approx(sim.player_vel.length(), sim.current_speed(), "실제 이동")


func test_처음_느려질_때_한_번만_안내() -> void:
	var sim := _sim_with_cargo(Balance.CARGO_CAPACITY / 4)
	sim.update(STEP, Vector2.RIGHT)
	assert_false(sim.events.has("cargo_heavy"), "25%까지는 안내 없음")
	sim.cargo.counts[0] += 1
	sim.update(STEP, Vector2.ZERO)
	assert_false(sim.events.has("cargo_heavy"), "멈춰 있으면 아직 안내 없음 (느려진 걸 못 느낌)")
	sim.update(STEP, Vector2.RIGHT)
	assert_true(sim.events.has("cargo_heavy"), "무거운 채로 움직이면 안내")
	sim.update(STEP, Vector2.RIGHT)
	assert_false(sim.events.has("cargo_heavy"), "한 판에 한 번만")


func test_HUD_화물_글자색은_노랑에서_주황으로() -> void:
	var cargo := Cargo.new()
	assert_eq(Hud.cargo_color(cargo), Hud.COLOR_VALUE, "빈 화물칸은 노랑")
	cargo.counts = PackedInt32Array([cargo.capacity / 4, 0, 0, 0])
	assert_eq(Hud.cargo_color(cargo), Hud.COLOR_VALUE, "느려지기 전까지 노랑")
	cargo.counts = PackedInt32Array([cargo.capacity, 0, 0, 0])
	assert_eq(Hud.cargo_color(cargo), Hud.COLOR_FULL, "가득 차면 주황")


func test_이동_속도_설명에_무게_도움이_드러남() -> void:
	assert_true(Upgrades.describe("speed").contains("무거워도"), "레벨업 설명")
	assert_true(BaseUpgrades.describe("speed").contains("무거워도"), "기지 설명")
	assert_true(BaseUpgrades.note("speed").contains("무거운"), "연구소 카드 도움말")
	assert_eq(BaseUpgrades.note("cargo"), "", "다른 카드는 도움말 없음")
