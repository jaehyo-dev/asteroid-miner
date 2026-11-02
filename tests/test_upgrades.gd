extends TestCase
## 4단계: 경험치·레벨업 강화 테스트 (Upgrades 규칙과 RunSim 연동).


func _sim() -> RunSim:
	var sim := RunSim.new(77)
	sim.set("_spawn_timer", 1.0e9)
	return sim


func test_필요_경험치는_레벨마다_늘어남() -> void:
	assert_eq(Upgrades.xp_to_next(1), Balance.XP_BASE)
	assert_eq(Upgrades.xp_to_next(2), Balance.XP_BASE + Balance.XP_GROWTH)
	assert_eq(Upgrades.xp_to_next(0), Balance.XP_BASE, "0 이하는 1레벨로 봄")


func test_선택지는_서로_다른_강화_3개() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 50:
		var c := Upgrades.roll_choices(rng, {}, Balance.UPGRADE_CHOICE_COUNT)
		assert_eq(c.size(), Balance.UPGRADE_CHOICE_COUNT)
		assert_true(c[0] != c[1] and c[1] != c[2] and c[0] != c[2], "중복 없음 %s" % c)
		for id in c:
			assert_false(Upgrades.info(id).is_empty(), "알려진 강화 " + id)


func test_최대_단계_강화는_나오지_않음() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var levels := {}
	for u in Balance.UPGRADES:
		levels[u["id"]] = u["max"]
	levels["speed"] = 0
	levels["range"] = 0
	for i in 30:
		var c := Upgrades.roll_choices(rng, levels, 3)
		assert_eq(c.size(), 2, "남은 2개만")
		assert_true(c.has("speed") and c.has("range"))


func test_모두_최대면_긴급_수리() -> void:
	var levels := {}
	for u in Balance.UPGRADES:
		levels[u["id"]] = u["max"]
	assert_eq(Upgrades.roll_choices(RandomNumberGenerator.new(), levels, 3), PackedStringArray([Upgrades.REPAIR]))


func test_모든_강화에_이름과_설명이_있음() -> void:
	for u in Balance.UPGRADES:
		assert_false(Upgrades.describe(u["id"]).is_empty(), u["id"] + " 설명")
		assert_eq(Upgrades.display_name(u["id"]), u["name"])
	assert_false(Upgrades.describe(Upgrades.REPAIR).is_empty())
	assert_eq(Upgrades.describe("fire_rate"), "발사 간격 -15%")


func test_경험치가_모이면_레벨업하고_선택지가_열림() -> void:
	var sim := _sim()
	sim.gain_xp(Balance.XP_BASE - 1)
	assert_eq(sim.level, 1)
	assert_true(sim.choices.is_empty())
	sim.gain_xp(1)
	assert_eq(sim.level, 2)
	assert_eq(sim.xp, 0)
	assert_eq(sim.choices.size(), Balance.UPGRADE_CHOICE_COUNT)
	assert_true(sim.events.has("levelup"))


func test_선택지가_열려_있으면_게임이_멈춤() -> void:
	var sim := _sim()
	sim.gain_xp(Balance.XP_BASE)
	var t := sim.time
	sim.update(0.1, Vector2.RIGHT)
	assert_eq(sim.time, t, "시간 멈춤")
	assert_eq(sim.player_pos, Vector2.ZERO, "이동 멈춤")
	sim.choose(0)
	assert_true(sim.choices.is_empty())
	sim.update(0.1, Vector2.RIGHT)
	assert_true(sim.time > t, "다시 진행")


func test_한번에_여러_레벨이_오르면_차례로_고름() -> void:
	var sim := _sim()
	sim.gain_xp(Upgrades.xp_to_next(1) + Upgrades.xp_to_next(2) + 1)
	assert_eq(sim.level, 3)
	assert_eq(sim.xp, 1, "남은 경험치")
	assert_eq(sim.pending_levelups, 2)
	sim.choose(0)
	assert_eq(sim.pending_levelups, 1)
	assert_false(sim.choices.is_empty(), "두 번째 선택지")
	sim.choose(0)
	assert_eq(sim.pending_levelups, 0)
	assert_true(sim.choices.is_empty())
	var total := 0
	for id in sim.upgrade_levels:
		total += sim.upgrade_levels[id]
	assert_eq(total, 2, "강화 2번")


func test_잘못된_번호는_무시() -> void:
	var sim := _sim()
	sim.gain_xp(Balance.XP_BASE)
	sim.choose(9)
	sim.choose(-1)
	assert_eq(sim.pending_levelups, 1)


func _apply(sim: RunSim, id: String, times: int = 1) -> void:
	for i in times:
		sim.upgrade_levels[id] = int(sim.upgrade_levels.get(id, 0)) + 1
	sim.apply_upgrades()


func test_강화_효과() -> void:
	var sim := _sim()
	_apply(sim, "fire_rate", 2)
	assert_true(is_equal_approx(sim.fire_interval, Balance.FIRE_INTERVAL * Balance.UP_FIRE_INTERVAL_MULT * Balance.UP_FIRE_INTERVAL_MULT))
	_apply(sim, "multishot")
	assert_eq(sim.bullet_count, Balance.BULLET_COUNT + 1)
	_apply(sim, "damage")
	assert_eq(sim.bullet_damage, Balance.BULLET_DAMAGE + Balance.UP_DAMAGE_ADD)
	_apply(sim, "magnet")
	assert_true(is_equal_approx(sim.magnet_radius, Balance.MAGNET_RADIUS * (1.0 + Balance.UP_MAGNET_ADD)))
	_apply(sim, "speed")
	assert_true(is_equal_approx(sim.move_speed, Balance.SHIP_SPEED * (1.0 + Balance.UP_SPEED_ADD)))
	_apply(sim, "range")
	assert_true(is_equal_approx(sim.fire_range, Balance.FIRE_RANGE * (1.0 + Balance.UP_RANGE_ADD)))


func test_이동_속도_강화가_실제_이동에_반영됨() -> void:
	var sim := _sim()
	_apply(sim, "speed", 2)
	sim.update(0.05, Vector2.RIGHT)
	assert_true(is_equal_approx(sim.player_pos.x, Balance.SHIP_SPEED * (1.0 + 2.0 * Balance.UP_SPEED_ADD) * 0.05))


func test_최대_체력_강화는_그만큼_회복() -> void:
	var sim := _sim()
	sim.hp = 50.0
	sim.choices = PackedStringArray(["max_hp"])
	sim.pending_levelups = 1
	sim.choose(0)
	assert_eq(sim.max_hp, Balance.SHIP_MAX_HP + Balance.UP_MAX_HP_ADD)
	assert_eq(sim.hp, 50.0 + Balance.UP_MAX_HP_ADD)


func test_긴급_수리는_최대_체력까지만_회복() -> void:
	var sim := _sim()
	sim.hp = sim.max_hp - 5.0
	sim.choices = PackedStringArray([Upgrades.REPAIR])
	sim.pending_levelups = 1
	sim.choose(0)
	assert_eq(sim.hp, sim.max_hp)
	assert_true(sim.upgrade_levels.is_empty(), "강화 단계는 그대로")


func test_운석을_부숴도_경험치는_없음() -> void:
	for type in Balance.ASTEROID_TYPES.size():
		var sim := _sim()
		var a := RunSim.Enemy.new()
		a.type = type
		a.pos = Vector2(500, 500)
		sim.call("_on_enemy_destroyed", a)
		assert_eq(sim.xp, 0, "%d번 크기" % type)
		assert_eq(sim.level, 1)


func test_광물을_주우면_가치에_비례한_경험치() -> void:
	for grade in Balance.MINERAL_GRADES.size():
		var expected := maxi(1, roundi(Balance.MINERAL_GRADES[grade]["value"] * Balance.MINERAL_XP_PER_VALUE))
		assert_eq(RunSim.mineral_xp(grade), expected, Balance.MINERAL_GRADES[grade]["name"])
	# 등급이 높을수록 경험치도 많다
	for grade in range(1, Balance.MINERAL_GRADES.size()):
		assert_true(RunSim.mineral_xp(grade) > RunSim.mineral_xp(grade - 1))


func test_광물을_실제로_주우면_경험치가_오름() -> void:
	var sim := _sim()
	sim.drop_mineral(Vector2(1, 0)).grade = 0
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.collected[0], 1)
	assert_eq(sim.xp + (Upgrades.xp_to_next(1) if sim.level > 1 else 0), RunSim.mineral_xp(0))

func test_탄_개수_강화는_실제로_여러_발_발사() -> void:
	var sim := _sim()
	_apply(sim, "multishot", 2)
	var a := RunSim.Enemy.new()
	a.radius = 5.0
	a.hp = 100.0
	a.pos = Vector2(0, -100)
	sim.enemies.append(a)
	sim.update(0.01, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 3)
