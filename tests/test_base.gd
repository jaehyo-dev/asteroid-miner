extends TestCase
## 기지: 공용 업그레이드 비용·구매·효과, 로컬 저장/불러오기, 기지 화면, 판 결과 저장.

const MainScene := preload("res://scenes/main.tscn")
const RunScene := preload("res://scenes/run.tscn")


func _maxed() -> Dictionary:
	var d := {}
	for u in Balance.BASE_UPGRADES:
		d[u["id"]] = u["max"]
	return d


# ── 비용과 구매 ─────────────────────────────────────

func test_비용은_단계마다_늘어남() -> void:
	for u in Balance.BASE_UPGRADES:
		var id: String = u["id"]
		assert_eq(BaseUpgrades.cost(id, 0), int(u["cost"]), id + " 첫 단계")
		assert_eq(BaseUpgrades.cost(id, 1), roundi(u["cost"] * Balance.BASE_COST_GROWTH), id + " 둘째 단계")
		assert_true(BaseUpgrades.cost(id, 4) > BaseUpgrades.cost(id, 3), id + " 계속 비싸짐")
		assert_false(BaseUpgrades.describe(id).is_empty(), id + " 설명")


func test_광물이_모자라면_못_삼() -> void:
	var save := SaveData.new()
	save.credits = BaseUpgrades.cost("damage", 0) - 1
	assert_false(BaseUpgrades.buy(save, "damage"))
	assert_eq(save.credits, BaseUpgrades.cost("damage", 0) - 1, "광물 그대로")
	assert_eq(save.level_of("damage"), 0, "단계 그대로")


func test_사면_광물이_빠지고_단계가_오름() -> void:
	var save := SaveData.new()
	save.credits = 1000
	assert_true(BaseUpgrades.buy(save, "cargo"))
	assert_eq(save.credits, 1000 - BaseUpgrades.cost("cargo", 0))
	assert_eq(save.level_of("cargo"), 1)
	assert_true(BaseUpgrades.buy(save, "cargo"))
	assert_eq(save.credits, 1000 - BaseUpgrades.cost("cargo", 0) - BaseUpgrades.cost("cargo", 1))
	assert_eq(save.level_of("cargo"), 2)


func test_최대_단계면_더_못_삼() -> void:
	var save := SaveData.new()
	save.credits = 999999
	for i in BaseUpgrades.max_level("magnet"):
		assert_true(BaseUpgrades.buy(save, "magnet"))
	var left := save.credits
	assert_false(BaseUpgrades.can_buy(save, "magnet"))
	assert_false(BaseUpgrades.buy(save, "magnet"))
	assert_eq(save.credits, left, "광물 그대로")
	assert_eq(save.level_of("magnet"), BaseUpgrades.max_level("magnet"))


func test_모르는_업그레이드는_못_삼() -> void:
	var save := SaveData.new()
	save.credits = 999999
	assert_false(BaseUpgrades.buy(save, "drone"))
	assert_eq(save.credits, 999999)


# ── 출격에 적용되는 효과 ─────────────────────────────

func test_업그레이드가_없으면_기본_능력치() -> void:
	var sim := RunSim.new(1)
	sim.apply_base({})
	assert_eq(sim.max_hp, Balance.SHIP_MAX_HP)
	assert_eq(sim.hp, Balance.SHIP_MAX_HP)
	assert_eq(sim.bullet_damage, Balance.BULLET_DAMAGE)
	assert_eq(sim.move_speed, Balance.SHIP_SPEED)
	assert_eq(sim.magnet_radius, Balance.MAGNET_RADIUS)
	assert_eq(sim.cargo.capacity, Balance.CARGO_CAPACITY)
	assert_eq(sim.insurance_level, 0)


func test_기지_업그레이드_효과() -> void:
	var sim := RunSim.new(1)
	sim.apply_base({"damage": 2, "max_hp": 3, "speed": 4, "cargo": 5, "insurance": 5, "magnet": 1})
	assert_true(is_equal_approx(sim.bullet_damage, Balance.BULLET_DAMAGE * (1.0 + 2 * Balance.BASE_DAMAGE_MULT_ADD)), "공격력")
	assert_eq(sim.max_hp, Balance.SHIP_MAX_HP + 3 * Balance.BASE_MAX_HP_ADD, "최대 체력")
	assert_eq(sim.hp, sim.max_hp, "체력 가득")
	assert_true(is_equal_approx(sim.move_speed, Balance.SHIP_SPEED * (1.0 + 4 * Balance.BASE_SPEED_ADD)), "이동 속도")
	assert_eq(sim.cargo.capacity, Balance.CARGO_CAPACITY + 5 * Balance.BASE_CARGO_ADD, "화물칸")
	assert_true(is_equal_approx(sim.magnet_radius, Balance.MAGNET_RADIUS * (1.0 + Balance.BASE_MAGNET_ADD)), "자석")
	assert_eq(Cargo.keep_ratio(sim.insurance_level), Balance.DEATH_KEEP_MAX, "보험 5단계면 최대 보존")


func test_레벨업_강화와_기지_업그레이드가_함께_적용됨() -> void:
	var sim := RunSim.new(1)
	sim.apply_base({"damage": 5, "max_hp": 2, "speed": 2})
	sim.upgrade_levels = {"damage": 1, "max_hp": 1, "speed": 1}
	sim.apply_upgrades()
	# 공격력: (기본 + 강화) × 기지 배율
	assert_true(is_equal_approx(sim.bullet_damage, (Balance.BULLET_DAMAGE + Balance.UP_DAMAGE_ADD) * (1.0 + 5 * Balance.BASE_DAMAGE_MULT_ADD)), "공격력 %f" % sim.bullet_damage)
	assert_eq(sim.max_hp, Balance.SHIP_MAX_HP + Balance.UP_MAX_HP_ADD + 2 * Balance.BASE_MAX_HP_ADD, "체력")
	assert_true(is_equal_approx(sim.move_speed, Balance.SHIP_SPEED * (1.0 + Balance.UP_SPEED_ADD + 2 * Balance.BASE_SPEED_ADD)), "속도")


func test_보험_단계에_따라_죽어도_더_많이_남음() -> void:
	var sim := RunSim.new(1)
	sim.apply_base({"insurance": 3})
	sim.cargo.counts = PackedInt32Array([20, 0, 0, 0])
	sim.alive = false
	assert_eq(Cargo.total(sim.brought_home()), 13, "20개 × 65% = 13개")


func test_화물칸_업그레이드로_더_많이_실음() -> void:
	var sim := RunSim.new(1)
	sim.apply_base({"cargo": 1})
	for i in Balance.CARGO_CAPACITY + Balance.BASE_CARGO_ADD:
		sim.collect(0)
	assert_eq(sim.cargo.size(), Balance.CARGO_CAPACITY + Balance.BASE_CARGO_ADD)
	assert_true(sim.cargo.is_full())


# ── 저장과 불러오기 ─────────────────────────────────

func test_저장하고_다시_불러오면_같음() -> void:
	var save := SaveData.new()
	save.credits = 1234
	save.upgrades = {"damage": 2, "insurance": 5}
	assert_true(save.save_file())
	var loaded := SaveData.load_file()
	assert_eq(loaded.credits, 1234)
	assert_eq(loaded.level_of("damage"), 2)
	assert_eq(loaded.level_of("insurance"), 5)
	assert_eq(loaded.level_of("speed"), 0)


func test_저장_파일이_없으면_새_저장() -> void:
	var save := SaveData.load_file()
	assert_eq(save.credits, 0)
	assert_true(save.upgrades.is_empty())


func test_깨진_저장_파일은_새_저장으로_읽음() -> void:
	for text in ["{망가진", "", "[1, 2]", "\"글자\"", "123"]:
		var f := FileAccess.open(SaveData.path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		var save := SaveData.load_file()
		assert_eq(save.credits, 0, "내용: " + text)
		assert_true(save.upgrades.is_empty(), "내용: " + text)


func test_이상한_값은_안전하게_고침() -> void:
	var save := SaveData.from_dict({
		"credits": -50,
		"upgrades": {"damage": 99, "speed": -3, "cargo": "많이", "drone": 4, "magnet": 2.0},
	})
	assert_eq(save.credits, 0, "음수 광물")
	assert_eq(save.level_of("damage"), BaseUpgrades.max_level("damage"), "최대를 넘는 단계")
	assert_eq(save.level_of("speed"), 0, "음수 단계")
	assert_eq(save.level_of("cargo"), 0, "숫자가 아닌 단계")
	assert_false(save.upgrades.has("drone"), "모르는 업그레이드는 버림")
	assert_eq(save.level_of("magnet"), 2, "JSON 실수(2.0)도 정수로")
	assert_eq(SaveData.from_dict({"credits": "많이", "upgrades": [1]}).credits, 0, "숫자가 아닌 광물")


func test_판_결과는_음수를_더하지_않음() -> void:
	var save := SaveData.new()
	save.add_credits(100)
	save.add_credits(-30)
	assert_eq(save.credits, 100)


func test_저장_형식_번호를_함께_저장() -> void:
	assert_eq(SaveData.new().to_dict()["format"], SaveData.FORMAT)


# ── 기지 화면 ───────────────────────────────────────

func test_기지_화면에_보유_광물과_업그레이드가_보임() -> void:
	var save := SaveData.new()
	save.credits = 500
	save.upgrades = {"cargo": 1}
	save.save_file()
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	assert_eq(main.credits_label.text, "보유 광물 500")
	assert_eq(main.buy_buttons.size(), Balance.BASE_UPGRADES.size(), "업그레이드 줄 수")
	var cargo_button: Button = main.buy_buttons["cargo"]
	assert_eq(cargo_button.text, "강화 %d" % BaseUpgrades.cost("cargo", 1))
	assert_false(cargo_button.disabled, "살 수 있음")
	main.queue_free()


func test_광물이_없으면_구매_버튼이_막힘() -> void:
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	for id in main.buy_buttons:
		assert_true(main.buy_buttons[id].disabled, id)
	assert_true(main.start_button.has_focus(), "출격 버튼 포커스")
	main.queue_free()


func test_기지에서_사면_바로_저장됨() -> void:
	var save := SaveData.new()
	save.credits = 300
	save.save_file()
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	main.buy_buttons["magnet"].pressed.emit()
	await wait_frames()
	var cost := BaseUpgrades.cost("magnet", 0)
	assert_eq(main.credits_label.text, "보유 광물 %d" % (300 - cost))
	var loaded := SaveData.load_file()
	assert_eq(loaded.credits, 300 - cost, "파일에 저장")
	assert_eq(loaded.level_of("magnet"), 1)
	main.queue_free()


func test_최대_단계는_최대로_표시() -> void:
	var save := SaveData.new()
	save.upgrades = _maxed()
	save.credits = 999999
	save.save_file()
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	for id in main.buy_buttons:
		assert_eq(main.buy_buttons[id].text, "최대", id)
		assert_true(main.buy_buttons[id].disabled, id)
	main.queue_free()


# ── 출격과 판 결과 ───────────────────────────────────

func test_출격하면_저장된_업그레이드가_적용됨() -> void:
	var save := SaveData.new()
	save.upgrades = {"max_hp": 2, "cargo": 3}
	save.save_file()
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	assert_eq(run.sim.max_hp, Balance.SHIP_MAX_HP + 2 * Balance.BASE_MAX_HP_ADD)
	assert_eq(run.sim.cargo.capacity, Balance.CARGO_CAPACITY + 3 * Balance.BASE_CARGO_ADD)
	run.queue_free()


func test_판이_끝나면_최종_가치가_한_번만_저장됨() -> void:
	var save := SaveData.new()
	save.credits = 40
	save.save_file()
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([0, 0, 2, 0])  # 영웅 2개 = 40
	run.sim.hp = 1.0
	run.sim.invuln = 0.0
	var a := RunSim.Enemy.new()
	a.radius = 5.0
	a.damage = 50.0
	a.hp = 1000.0
	a.max_hp = 1000.0
	a.pos = run.sim.player_pos
	run.sim.enemies.append(a)
	await wait_frames(3)
	assert_false(run.sim.alive)
	var earned: int = run.sim.final_value()
	assert_true(earned > 0, "가져온 가치 %d" % earned)
	assert_eq(SaveData.load_file().credits, 40 + earned, "저장됨")
	assert_true(run.menu.body_text().contains("보유 광물 %d" % (40 + earned)), run.menu.body_text())
	assert_eq(run.bank_result(), earned)
	assert_eq(SaveData.load_file().credits, 40 + earned, "두 번 더하지 않음")
	assert_eq(run.menu.buttons()[1].text, "기지로")
	run.queue_free()


func test_일시_정지에서_포기하면_광물을_저장하지_않음() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.cargo.counts = PackedInt32Array([0, 0, 2, 0])
	run.pause()
	assert_true(run.menu.body_text().contains("사라집니다"), "포기 안내")
	assert_false(run.banked)
	assert_eq(SaveData.load_file().credits, 0)
	run.queue_free()
