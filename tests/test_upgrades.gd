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
	for i in 200:
		var c := Upgrades.roll_choices(rng, {}, Balance.UPGRADE_CHOICE_COUNT, 300.0, true)
		assert_eq(c.size(), Balance.UPGRADE_CHOICE_COUNT)
		assert_true(c[0]["id"] != c[1]["id"] and c[1]["id"] != c[2]["id"] and c[0]["id"] != c[2]["id"], "중복 없음 %s" % [c])
		for card in c:
			assert_false(Upgrades.info(card["id"]).is_empty(), "알려진 강화 " + card["id"])


func test_최대_단계_강화는_나오지_않음() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var levels := {}
	for u in Balance.UPGRADES:
		levels[u["id"]] = u["max"]
	levels["speed"] = 0
	for i in 30:
		var c := Upgrades.roll_choices(rng, levels, 3, 0.0, false)
		var ids: Array = c.map(func(card: Dictionary) -> String: return card["id"])
		assert_eq(ids.size(), 2, "남은 2개만")
		assert_true(ids.has("speed") and ids.has(Upgrades.REPAIR), str(ids))
	var without := Upgrades.roll_choices(rng, levels, 3, 0.0, false, false, false)
	assert_eq(without.size(), 1, "수리를 빼면 속도만")
	assert_eq(without[0]["id"], "speed")


func test_수리는_체력이_낮을_때만_뽑기에_들어감() -> void:
	var saw := {true: false, false: false}
	for low in [true, false]:
		var sim := _sim()
		sim.hp = sim.max_hp * (Balance.REPAIR_POOL_HP_RATIO - 0.1 if low else 1.0)
		for i in 200:
			sim.choices = [{"id": "speed", "grade": 0}]
			sim.rerolls_left = 1
			sim.reroll()
			for card in sim.choices:
				saw[low] = saw[low] or card["id"] == Upgrades.REPAIR
	assert_true(saw[true], "체력이 낮으면 나옴")
	assert_false(saw[false], "체력이 넉넉하면 안 나옴")


func test_모두_최대면_체력이_넉넉할_때_카드_없음_낮으면_수리만() -> void:
	var levels := {}
	for u in Balance.UPGRADES:
		levels[u["id"]] = u["max"]
	var c := Upgrades.roll_choices(RandomNumberGenerator.new(), levels, 3, 0.0, false, false, false)
	assert_eq(c.size(), 0, "체력이 넉넉하면 고를 카드 없음 (건너뛰기만)")
	c = Upgrades.roll_choices(RandomNumberGenerator.new(), levels, 3, 0.0, false, false, true)
	assert_eq(c.size(), 1, "체력이 낮으면 수리만")
	assert_eq(c[0]["id"], Upgrades.REPAIR)


func test_모든_강화에_이름_종류_설명_아이콘이_있음() -> void:
	for list in [Balance.UPGRADES, Balance.EFFECT_UPGRADES, Balance.LEGENDARY_UPGRADES]:
		for u in list:
			assert_eq(Upgrades.display_name(u["id"]), u["name"])
			assert_false(Upgrades.kind_of(u["id"]).is_empty(), u["id"] + " 종류")
			var grades: Array = [Upgrades.LEGENDARY] if list == Balance.LEGENDARY_UPGRADES else ([Upgrades.EPIC, Upgrades.UNIQUE] if list == Balance.EFFECT_UPGRADES else [0, 1, 2, 3])
			for grade in grades:
				assert_false(Upgrades.describe(u["id"], grade).is_empty(), u["id"] + " 설명")
				assert_false(Upgrades.describe(u["id"], grade, true).is_empty(), u["id"] + " 짧은 설명")
			var icon: Texture2D = load("res://assets/sprites/run/card/icons/%s.png" % u["id"])
			assert_eq(icon.get_size(), Vector2(48, 48), u["id"] + " 아이콘")


func test_강화는_8종_효과는_7종_레전드리는_4종() -> void:
	assert_eq(Balance.UPGRADES.size(), 8)
	assert_eq(Balance.EFFECT_UPGRADES.size(), 7)
	assert_eq(Balance.LEGENDARY_UPGRADES.size(), 4)


func test_등급별_수치와_설명() -> void:
	assert_eq(Upgrades.describe("fire_rate", Upgrades.NORMAL), "발사 속도 +10%")
	assert_eq(Upgrades.describe("fire_rate", Upgrades.UNIQUE), "발사 속도 +30%")
	assert_eq(Upgrades.describe("multishot", Upgrades.NORMAL), "한 번에 1발 더")
	assert_eq(Upgrades.describe("multishot", Upgrades.RARE), "한 번에 1발 더, 탄 피해 +10%")
	assert_eq(Upgrades.describe("multishot", Upgrades.UNIQUE), "한 번에 2발 더")
	assert_eq(Upgrades.describe("damage", Upgrades.NORMAL), "탄 피해 +75%")
	assert_eq(Upgrades.describe("damage", Upgrades.UNIQUE), "탄 피해 +225%")
	assert_eq(Upgrades.describe("repair", Upgrades.EPIC), "체력 40 회복")
	assert_eq(Upgrades.describe("pierce", Upgrades.UNIQUE, true), "2개 더 관통")


func test_시간별_등급_확률은_설계_표와_같음() -> void:
	var expected := {0.0: [55.0, 27.0, 12.0, 5.0, 1.0], 60.0: [51.0, 27.6, 13.6, 6.4, 1.4], 180.0: [43.0, 28.8, 16.8, 9.2, 2.2], 300.0: [35.0, 30.0, 20.0, 12.0, 3.0], 600.0: [35.0, 30.0, 20.0, 12.0, 3.0]}
	for t in expected:
		var w := Upgrades.grade_weights(t)
		var total := 0.0
		for i in 5:
			assert_true(absf(w[i] - expected[t][i]) < 0.001, "%s초 %d번 %f" % [t, i, w[i]])
			total += w[i]
		assert_true(absf(total - 100.0) < 0.001, "합 100")


func test_등급_분포가_확률을_따름() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts := [0, 0, 0, 0, 0]
	for i in 20000:
		counts[Upgrades.roll_grade(rng, 0.0)] += 1
	for g in 5:
		var pct: float = counts[g] / 200.0
		assert_true(absf(pct - Balance.GRADE_WEIGHTS_START[g]) < 1.0, "%d번 등급 %f%%" % [g, pct])


func test_잠겨_있으면_효과와_레전드리가_뽑히지_않음() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sim := _sim()
	sim.effects_enabled = false
	sim.effect_dry = 99  # 보정이 켜질 만한 값이어도
	for i in 3000:
		sim.rerolls_left = 1
		sim.choices = [{"id": "speed", "grade": 0}]
		sim.reroll()
		for card in sim.choices:
			assert_false(card["grade"] == Upgrades.LEGENDARY, "레전드리 없음")
			assert_true(Balance.UPGRADES.any(func(u: Dictionary) -> bool: return u["id"] == card["id"]), "수치 강화만 " + card["id"])


func test_효과_카드는_켜져_있음() -> void:
	assert_true(Balance.EFFECT_CARDS_ENABLED)
	assert_true(_sim().effects_enabled)


func test_잠겨_있으면_보정이_세어지지_않음() -> void:
	var sim := _sim()
	sim.effects_enabled = false
	sim.gain_xp(Balance.XP_BASE)
	sim.choose(0)
	assert_eq(sim.effect_dry, 0)


func test_풀리면_효과는_에픽부터_레전드리는_한_화면에_1장() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var saw_effect := false
	var saw_legend := false
	for i in 5000:
		var c := Upgrades.roll_choices(rng, {}, 3, 300.0, true)
		var legends := 0
		for card in c:
			if card["grade"] == Upgrades.LEGENDARY:
				legends += 1
				saw_legend = true
				assert_true(Balance.LEGENDARY_UPGRADES.any(func(u: Dictionary) -> bool: return u["id"] == card["id"]))
			elif Upgrades.is_effect(card["id"]):
				saw_effect = true
				assert_true(card["grade"] >= Upgrades.EPIC, "효과는 에픽부터")
			else:
				assert_true(card["grade"] <= Upgrades.UNIQUE)
		assert_true(legends <= 1, "레전드리 1장까지")
	assert_true(saw_effect and saw_legend)


func test_보정_확정이면_에픽_효과가_꼭_나옴() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 2000:
		var c := Upgrades.roll_choices(rng, {}, 3, 0.0, true, true)
		assert_true(Upgrades.has_effect(c), "효과 카드 있음 %s" % [c])
		var ids := {}
		for card in c:
			ids[card["id"]] = true
		assert_eq(ids.size(), 3, "확정 카드도 중복 없음")


func test_보정은_효과_카드_없는_레벨업_2번_뒤에_동작() -> void:
	var sim := _sim()
	sim.effects_enabled = true
	# 효과 없는 화면 2번을 강제로 지나간다
	for i in Balance.EFFECT_PITY_LEVELUPS:
		sim.choices = [{"id": "speed", "grade": 0}]
		sim.pending_levelups = 1
		sim.choose(0)
	assert_eq(sim.effect_dry, Balance.EFFECT_PITY_LEVELUPS)
	sim.gain_xp(Balance.XP_BASE)
	assert_true(Upgrades.has_effect(sim.choices), "다음 화면 확정")
	assert_true(sim.reroll(), "다시 뽑아도")
	assert_true(Upgrades.has_effect(sim.choices), "확정 유지")
	assert_eq(sim.effect_dry, Balance.EFFECT_PITY_LEVELUPS, "다시 뽑기는 레벨업으로 세지 않음")
	sim.choose(0)
	assert_eq(sim.effect_dry, 0, "효과 카드를 본 레벨업이면 처음부터")


func test_다시_뽑기는_한_판에_2번() -> void:
	var sim := _sim()
	assert_false(sim.reroll(), "고를 카드가 없으면 안 됨")
	assert_eq(sim.rerolls_left, Balance.REROLLS_PER_RUN)
	sim.gain_xp(Balance.XP_BASE)
	var pending := sim.pending_levelups
	assert_true(sim.reroll())
	assert_eq(sim.choices.size(), Balance.UPGRADE_CHOICE_COUNT, "3장 다시")
	assert_true(sim.reroll())
	assert_false(sim.reroll(), "3번째는 안 됨")
	assert_eq(sim.rerolls_left, 0)
	assert_eq(sim.pending_levelups, pending, "레벨업 수는 그대로")
	sim.choose(0)
	sim.gain_xp(Upgrades.xp_to_next(sim.level))
	assert_eq(sim.rerolls_left, 0, "다음 레벨업에 다시 채워지지 않음")


func test_같은_시드면_다시_뽑기_결과도_같음() -> void:
	var a := _sim()
	var b := _sim()
	for sim in [a, b]:
		sim.gain_xp(Balance.XP_BASE)
		sim.reroll()
	assert_eq(a.choices, b.choices)


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


func _apply(sim: RunSim, id: String, times: int = 1, grade: int = Upgrades.NORMAL) -> void:
	for i in times:
		sim.apply_pick(id, grade)


func test_강화_효과() -> void:
	var sim := _sim()
	_apply(sim, "fire_rate", 2)
	assert_true(is_equal_approx(sim.fire_interval, Balance.FIRE_INTERVAL / 1.2), "발사 속도는 더해짐")
	_apply(sim, "multishot")
	assert_eq(sim.bullet_count, Balance.BULLET_COUNT + 1)
	_apply(sim, "damage")
	assert_eq(sim.bullet_damage, Balance.BULLET_DAMAGE + 0.75)
	_apply(sim, "magnet")
	assert_true(is_equal_approx(sim.magnet_radius, Balance.MAGNET_RADIUS * 1.3))
	_apply(sim, "speed")
	assert_true(is_equal_approx(sim.move_speed, Balance.SHIP_SPEED * 1.09))
	_apply(sim, "range")
	assert_true(is_equal_approx(sim.fire_range, Balance.FIRE_RANGE * 1.15))


func test_등급이_높으면_더_크게_오르고_단계는_똑같이_1() -> void:
	var sim := _sim()
	_apply(sim, "speed", 1, Upgrades.UNIQUE)
	assert_true(is_equal_approx(sim.move_speed, Balance.SHIP_SPEED * 1.27))
	assert_eq(sim.upgrade_levels["speed"], 1)
	_apply(sim, "speed", 1, Upgrades.NORMAL)
	assert_true(is_equal_approx(sim.move_speed, Balance.SHIP_SPEED * 1.36), "등급마다 오른 양이 쌓임")
	assert_eq(sim.upgrade_levels["speed"], 2)


func test_다중_포신_등급별() -> void:
	var sim := _sim()
	_apply(sim, "multishot", 1, Upgrades.EPIC)
	assert_eq(sim.bullet_count, Balance.BULLET_COUNT + 1)
	assert_true(is_equal_approx(sim.bullet_damage, Balance.BULLET_DAMAGE * 1.2), "에픽 탄 피해 +20%")
	_apply(sim, "multishot", 1, Upgrades.UNIQUE)
	assert_eq(sim.bullet_count, Balance.BULLET_COUNT + 3, "유니크 +2발")


func test_이동_속도_강화가_실제_이동에_반영됨() -> void:
	var sim := _sim()
	_apply(sim, "speed", 2)
	sim.update(0.05, Vector2.RIGHT)
	assert_true(is_equal_approx(sim.player_pos.x, Balance.SHIP_SPEED * 1.18 * 0.05))


func test_최대_체력_강화는_그만큼_회복() -> void:
	var sim := _sim()
	sim.hp = 50.0
	sim.choices = [{"id": "max_hp", "grade": Upgrades.RARE}]
	sim.pending_levelups = 1
	sim.choose(0)
	assert_eq(sim.max_hp, Balance.SHIP_MAX_HP + 22.0)
	assert_eq(sim.hp, 72.0)


func test_수리는_최대_체력까지만_회복하고_단계가_없음() -> void:
	var sim := _sim()
	sim.hp = sim.max_hp - 5.0
	sim.choices = [{"id": Upgrades.REPAIR, "grade": Upgrades.NORMAL}]
	sim.pending_levelups = 1
	sim.choose(0)
	assert_eq(sim.hp, sim.max_hp)
	assert_true(sim.upgrade_levels.is_empty(), "강화 단계는 그대로")
	sim.hp = 10.0
	sim.apply_pick(Upgrades.REPAIR, Upgrades.UNIQUE)
	assert_eq(sim.hp, 70.0, "유니크 60 회복")


func test_효과_카드를_골라도_깨지지_않음() -> void:
	var sim := _sim()
	var before := sim.bullet_damage
	sim.choices = [{"id": "pierce", "grade": Upgrades.EPIC}]
	sim.pending_levelups = 1
	sim.choose(0)
	assert_eq(sim.upgrade_levels["pierce"], 1)
	assert_eq(sim.bullet_damage, before, "효과는 3부에서")


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
