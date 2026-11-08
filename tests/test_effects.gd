extends TestCase
## 효과 강화 7종·레전드리 4종의 규칙 (design.md 4번 표).


func _sim() -> RunSim:
	var sim := RunSim.new(77)
	sim.set("_spawn_timer", 1.0e9)
	sim.set("_golden_timer", 1.0e9)
	sim.set("_barrage_timer", 1.0e9)
	sim.set("_jelly_timer", 1.0e9)
	sim.set("_bug_timer", 1.0e9)
	sim.set("_guard_timer", 1.0e9)
	sim.raid.state = RaidDirector.State.CALM
	return sim


## 멈춰 있는 운석을 정해진 자리에 놓는다
func _rock(sim: RunSim, pos: Vector2, hp := 100.0) -> RunSim.Enemy:
	var a := sim.spawn_asteroid()
	a.pos = pos
	a.vel = Vector2.ZERO
	a.radius = 8.0
	a.hp = hp
	a.max_hp = hp
	return a


## 지정한 방향으로 나는 탄을 만든다
func _bullet(sim: RunSim, from: Vector2, to: Vector2) -> RunSim.Bullet:
	return sim._fire_bullet(from, (to - from).angle(), 1.0, 2.0)


func _tick(sim: RunSim, frames := 40) -> void:
	sim.set("_fire_timer", 1.0e9)
	for i in frames:
		sim.update(1.0 / 60.0, Vector2.ZERO)


func test_관통탄은_대상을_더_뚫고_같은_적을_두_번_맞히지_않음() -> void:
	var sim := _sim()
	sim.apply_pick("pierce", Upgrades.EPIC)
	var near := _rock(sim, Vector2(60, 0))
	var far := _rock(sim, Vector2(90, 0))
	var last := _rock(sim, Vector2(120, 0))
	_bullet(sim, Vector2(40, 0), Vector2(200, 0))
	_tick(sim)
	assert_eq(near.hp, 98.0, "첫 대상 한 번만")
	assert_eq(far.hp, 98.0, "1개 더 관통")
	assert_eq(last.hp, 100.0, "두 번째로 더는 못 뚫음")


func test_관통은_합쳐서_4까지() -> void:
	var sim := _sim()
	for i in 3:
		sim.apply_pick("pierce", Upgrades.UNIQUE)
	assert_eq(sim.pierce_count, Balance.PIERCE_CAP)


func test_반사탄은_가까운_대상으로_튕기고_피해가_70퍼센트() -> void:
	var sim := _sim()
	sim.apply_pick("ricochet", Upgrades.EPIC)
	var first := _rock(sim, Vector2(60, 0))
	var second := _rock(sim, Vector2(60, 50))
	var third := _rock(sim, Vector2(60, 100))
	_bullet(sim, Vector2(40, 0), Vector2(200, 0))
	sim.set("_fire_timer", 1.0e9)
	var saw_bounce := false
	for i in 40:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		saw_bounce = saw_bounce or sim.fx.any(func(f: Dictionary) -> bool: return f["type"] == "bounce")
	assert_true(saw_bounce, "튕김 궤적 연출")
	assert_eq(first.hp, 98.0)
	assert_true(is_equal_approx(second.hp, 100.0 - 2.0 * Balance.RICOCHET_DAMAGE), "70%% 피해 %f" % second.hp)
	assert_eq(third.hp, 100.0, "1번만 튕김")


func test_튕길_대상이_없으면_사라짐() -> void:
	var sim := _sim()
	sim.apply_pick("ricochet", Upgrades.EPIC)
	_rock(sim, Vector2(60, 0))
	_bullet(sim, Vector2(40, 0), Vector2(200, 0))
	_tick(sim)
	assert_eq(sim.bullets.size(), 0)


func test_고폭_탄두는_부술_때_주변만_피해를_주고_연쇄하지_않음() -> void:
	var sim := _sim()
	sim.apply_pick("explosive", Upgrades.EPIC)
	assert_eq(sim.explosive_radius, 24.0)
	assert_eq(sim.explosive_share, 0.5)
	_rock(sim, Vector2(60, 0), 1.0)
	var close := _rock(sim, Vector2(60, 25), 1.0)  # 폭발로 부서짐
	var chained := _rock(sim, Vector2(60, 50), 5.0)  # 부서진 close 옆이지만 연쇄 안 됨
	var far := _rock(sim, Vector2(200, 200))
	sim.bullet_damage = 2.0
	_bullet(sim, Vector2(40, 0), Vector2(200, 0))
	_tick(sim)
	assert_true(close.hp <= 0.0, "주변 폭발 피해")
	assert_eq(chained.hp, 5.0, "폭발로 부서진 적은 다시 터지지 않음")
	assert_eq(far.hp, 100.0)
	assert_eq(sim.kills, 2)


func test_폭발_피해는_부순_탄의_피해_기준() -> void:
	var sim := _sim()
	sim.apply_pick("explosive", Upgrades.EPIC)
	_rock(sim, Vector2(60, 0), 1.0)
	var near := _rock(sim, Vector2(60, 25))
	var b := _bullet(sim, Vector2(40, 0), Vector2(200, 0))
	b.damage = 1.0  # 드론처럼 줄어든 피해
	sim.bullet_damage = 100.0
	_tick(sim)
	assert_eq(near.hp, 99.5, "1.0의 50%")


func test_고폭_탄두_단계마다_반경이_늘어남() -> void:
	var sim := _sim()
	sim.apply_pick("explosive", Upgrades.EPIC)
	sim.apply_pick("explosive", Upgrades.EPIC)
	assert_eq(sim.explosive_radius, 30.0)
	sim.apply_pick("explosive", Upgrades.UNIQUE)
	assert_eq(sim.explosive_radius, 42.0, "유니크 36 + 6")
	assert_eq(sim.explosive_share, 0.75)


func test_치명타는_2배_피해와_연출() -> void:
	var sim := _sim()
	for i in 3:
		sim.apply_pick("crit", Upgrades.UNIQUE)
	assert_eq(sim.crit_chance, Balance.CRIT_CAP, "최대 50%")
	sim.crit_chance = 1.0
	var a := _rock(sim, Vector2(60, 0))
	_bullet(sim, Vector2(40, 0), Vector2(200, 0))
	sim.set("_fire_timer", 1.0e9)
	var crit := {}
	for i in 40:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		for f in sim.fx:
			if f["type"] == "crit":
				crit = f
	assert_eq(a.hp, 96.0)
	assert_eq(crit.get("damage"), 4.0)


func test_편향_실드는_충전되면_한_번_막고_다시_충전() -> void:
	var sim := _sim()
	sim.apply_pick("shield", Upgrades.EPIC)
	assert_eq(sim.shield_interval, 20.0)
	assert_false(sim.shield_ready(), "처음에는 비어 있음")
	sim.shield_charge = 19.99
	sim.update(0.1, Vector2.ZERO)
	assert_true(sim.shield_ready(), "완충")
	var hp := sim.hp
	assert_true(sim.damage_player(10.0), "막음도 맞은 것으로 처리")
	assert_eq(sim.hp, hp, "피해 없음")
	assert_true(sim.events.has("shield_block"))
	assert_false(sim.events.has("hit"), "피격 연출 없음")
	assert_eq(sim.shield_charge, 0.0)
	assert_eq(sim.invuln, Balance.SHIELD_BLOCK_INVULN)
	sim.invuln = 0.0
	assert_true(sim.damage_player(10.0))
	assert_eq(sim.hp, hp - 10.0, "빈 실드는 못 막음")


func test_편향_실드_단계마다_빨라지고_최소_8초() -> void:
	var sim := _sim()
	sim.apply_pick("shield", Upgrades.EPIC)
	sim.apply_pick("shield", Upgrades.EPIC)
	assert_eq(sim.shield_interval, 17.0)
	sim.apply_pick("shield", Upgrades.UNIQUE)
	assert_eq(sim.shield_interval, 9.0, "유니크 12 - 3")
	sim.apply_pick("shield", Upgrades.UNIQUE)
	assert_eq(sim.shield_interval, Balance.SHIELD_MIN_INTERVAL)


func test_실드_간격이_줄어도_충전_비율은_1을_넘지_않음() -> void:
	var sim := _sim()
	sim.apply_pick("shield", Upgrades.EPIC)
	sim.shield_charge = 15.0
	sim.apply_pick("shield", Upgrades.UNIQUE)
	assert_true(sim.shield_ready())
	assert_eq(sim.shield_ratio(), 1.0)


func test_호위_드론은_수가_늘고_절반_피해로_쏨() -> void:
	var sim := _sim()
	sim.apply_pick("drone", Upgrades.UNIQUE)
	sim.apply_pick("drone", Upgrades.UNIQUE)
	sim.bullet_damage = 2.0
	sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(sim.drones.size(), Balance.DRONE_CAP, "합쳐서 최대 3기")
	_rock(sim, Vector2(50, 0))
	sim.set("_fire_timer", 1.0e9)
	var shots := 0
	for i in 150:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		if sim.events.has("drone_shoot"):
			shots += 1
			assert_eq(sim.bullets[-1].damage, 2.0 * Balance.DRONE_DAMAGE)
	assert_true(shots >= 3, "1초에 1발씩 3기 %d" % shots)


func test_정밀_채굴_레이저는_운석_광물만_늘림() -> void:
	var sim := _sim()
	sim.apply_pick("mining_laser", Upgrades.UNIQUE)
	sim.apply_pick("mining_laser", Upgrades.UNIQUE)
	assert_eq(sim.mineral_bonus, Balance.MINING_CAP, "합쳐서 최대 +100%")
	var rock := _rock(sim, Vector2(500, 0), 0.0)
	var count: int = RunSim.drops_of(rock)[0]["count"]
	sim._on_enemy_destroyed(rock)
	assert_eq(sim.minerals.size(), count * 2, "+100%면 2배")
	sim.minerals.clear()
	var jelly := sim.spawn_creature("jelly")
	sim._on_enemy_destroyed(jelly)
	assert_eq(sim.minerals.size(), int(RunSim.drops_of(jelly)[0]["count"]), "생명체는 그대로")


func test_궤도_관통_가속기는_끝까지_뚫고_관통탄_카드를_뺌() -> void:
	var sim := _sim()
	sim.apply_pick("orbit_pierce", Upgrades.LEGENDARY)
	var rocks: Array = []
	for i in 6:
		rocks.append(_rock(sim, Vector2(60 + 12 * i, 0)))
	_bullet(sim, Vector2(40, 0), Vector2(300, 0))
	_tick(sim)
	for r in rocks:
		assert_eq(r.hp, 98.0, "모두 한 번씩")
	assert_false(Upgrades.available_in(Balance.EFFECT_UPGRADES, sim.upgrade_levels).has("pierce"), "관통탄 카드 제외")
	assert_false(Upgrades.available_in(Balance.LEGENDARY_UPGRADES, sim.upgrade_levels).has("orbit_pierce"), "한 판 1번")


func test_연쇄_반사는_3번_튕기고_피해가_20퍼센트씩_줄어듦() -> void:
	var sim := _sim()
	sim.apply_pick("chain_matrix", Upgrades.LEGENDARY)
	assert_eq(sim.bounce_count, Balance.CHAIN_BOUNCES)
	var rocks: Array = []
	for i in 5:
		rocks.append(_rock(sim, Vector2(60, 40.0 * i)))
	_bullet(sim, Vector2(40, 0), Vector2(200, 0))
	_tick(sim, 60)
	assert_eq(rocks[0].hp, 98.0)
	assert_true(is_equal_approx(rocks[1].hp, 100.0 - 1.6), "%f" % rocks[1].hp)
	assert_true(is_equal_approx(rocks[2].hp, 100.0 - 1.28), "%f" % rocks[2].hp)
	assert_true(is_equal_approx(rocks[3].hp, 100.0 - 1.024), "%f" % rocks[3].hp)
	assert_eq(rocks[4].hp, 100.0, "3번까지")


func test_과부하_반응로는_체력_절반_이하에서_발사_속도_2배() -> void:
	var sim := _sim()
	sim.apply_pick("overload", Upgrades.LEGENDARY)
	assert_eq(sim.current_fire_interval(), sim.fire_interval, "체력이 많으면 그대로")
	sim.hp = sim.max_hp * 0.5
	assert_eq(sim.current_fire_interval(), sim.fire_interval / 2.0)


func test_전역_견인_비콘은_8초마다_화면_안_광물만_끌어옴() -> void:
	var sim := _sim()
	sim.apply_pick("tractor_beacon", Upgrades.LEGENDARY)
	var inside := sim.drop_mineral(Vector2(200, 100))
	var outside := sim.drop_mineral(sim.view_size)
	var seen := false
	for i in int(Balance.BEACON_INTERVAL * 30.0) + 2:
		sim.update(1.0 / 30.0, Vector2.ZERO)
		seen = seen or sim.events.has("beacon")
	assert_true(seen, "비콘 신호")
	assert_true(inside.attracted, "화면 안")
	assert_false(outside.attracted, "화면 밖")


func test_탄_수_상한() -> void:
	var sim := _sim()
	for i in Balance.MAX_BULLETS + 5:
		sim._fire_bullet(Vector2.ZERO, 0.0, 1.0, 1.0)
	assert_eq(sim.bullets.size(), Balance.MAX_BULLETS)


func test_우주선_윤곽은_그림_바로_바깥이고_각도_순서() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.set_pixel(4, 4, Color.WHITE)
	var o := ShipOutline.trace(img)
	assert_eq(o["line"].size(), 4, "상하좌우")
	assert_eq(o["glow"].size(), 8, "바깥 빛")
	var angles: Array = []
	for p: Vector2 in o["line"]:
		angles.append(p.angle())
	var sorted := angles.duplicate()
	sorted.sort()
	assert_eq(angles, sorted)
	assert_true(ShipOutline.of_dir(0)["line"].size() > 10, "진짜 우주선 윤곽")


func test_레벨업_카드_등장은_등급이_높을수록_크고_레전드리는_모은다() -> void:
	for i in Juice.CARD_BURST_PARTS.size() - 1:
		assert_true(Juice.CARD_BURST_PARTS[i] < Juice.CARD_BURST_PARTS[i + 1])
		assert_true(Juice.CARD_BURST_TIME[i] < Juice.CARD_BURST_TIME[i + 1])
	var starts := LevelUpCards.card_starts([Upgrades.LEGENDARY, Upgrades.NORMAL] as Array[int], false)
	assert_true(is_equal_approx(starts[1] - starts[0], Juice.CARD_STAGGER + Juice.CARD_LEGEND_GATHER), "모으는 만큼 다음 카드가 늦음")
	var reroll := LevelUpCards.card_starts([Upgrades.LEGENDARY, Upgrades.NORMAL] as Array[int], true)
	assert_true(is_equal_approx(reroll[1] - reroll[0], Juice.CARD_REROLL_STAGGER), "다시 뽑기는 모으기 없음")


func test_카드_효과_파티클은_상한을_넘지_않음() -> void:
	var fx := CardFx.new()
	add_child(fx)
	for i in 10:
		fx.burst(Rect2(0, 0, 144, 200), Upgrades.LEGENDARY)
	assert_true(fx.parts.size() <= Juice.CARD_FX_MAX, "%d" % fx.parts.size())
	fx.queue_free()


func _screen(choices: Array) -> LevelUpCards:
	var screen := LevelUpCards.new()
	add_child(screen)
	screen.show_cards(choices, {}, 2)
	return screen


func test_건너뛰면_가장_높은_등급_연출만_짧게() -> void:
	var screen := _screen([{"id": "speed", "grade": 0}, {"id": "orbit_pierce", "grade": 4}, {"id": "drone", "grade": 2}])
	await wait_frames(1)
	screen.skip()
	assert_true(screen.is_revealing(), "잠깐은 잠금")
	for c in screen.cards:
		assert_true(c.visible, "한 번에 3장 모두")
	assert_eq(screen._fx.pillars.size(), 1, "가장 높은 등급 빛 기둥 1개")
	assert_true(screen._fx.parts.size() < Juice.CARD_BURST_PARTS[4], "짧게")
	screen.queue_free()


func test_슬로모션_중_누름은_카드가_뜨자마자_건너뜀() -> void:
	var screen := LevelUpCards.new()
	add_child(screen)
	screen.queue_skip()
	screen.show_cards([{"id": "speed", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "range", "grade": 2}], {}, 2)
	assert_eq(screen.state, LevelUpCards.State.GUARD)
	screen.close()
	screen.show_cards([{"id": "speed", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "range", "grade": 2}], {}, 2)
	assert_eq(screen.state, LevelUpCards.State.REVEAL, "한 번만 적용")
	screen.queue_free()


func test_카드가_뜨기_전부터_누른_손가락은_카드를_고르지_못함() -> void:
	var screen := LevelUpCards.new()
	add_child(screen)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	screen._input(touch)  # 조이스틱을 누르고 있는 중
	screen.show_cards([{"id": "speed", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "range", "grade": 2}], {}, 2)
	screen.skip()
	screen._open_input()
	screen._on_card_pressed(0)
	assert_eq(screen.state, LevelUpCards.State.READY, "누르고 있는 동안은 못 고름")
	touch = touch.duplicate()
	touch.pressed = false
	screen._input(touch)
	screen._on_card_pressed(0)
	assert_eq(screen.state, LevelUpCards.State.READY, "막 뗀 직후도 못 고름")
	screen._stale_released_at -= Juice.CARD_STALE_RELEASE_MS + 1
	screen._on_card_pressed(0)
	assert_eq(screen.state, LevelUpCards.State.PICKING, "그 뒤로는 고를 수 있음")
	screen.queue_free()


func test_뗀_신호를_놓친_손가락은_선택을_영영_막지_않음() -> void:
	var screen := LevelUpCards.new()
	add_child(screen)
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	screen._input(touch)  # 뗀 신호가 오지 않는 손가락
	screen.show_cards([{"id": "speed", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "range", "grade": 2}], {}, 2)
	screen.skip()
	screen._open_input()
	screen._on_card_pressed(0)
	assert_eq(screen.state, LevelUpCards.State.READY, "아직은 막음")
	screen._shown_at -= Juice.CARD_STALE_MAX_MS + 1
	screen._on_card_pressed(0)
	assert_eq(screen.state, LevelUpCards.State.PICKING, "시간이 지나면 고를 수 있음")
	screen.queue_free()


func test_조이스틱을_누른_채_다른_손가락으로_카드를_고름() -> void:
	var screen := LevelUpCards.new()
	add_child(screen)
	var hold := InputEventScreenTouch.new()
	hold.index = 0
	hold.pressed = true
	screen._input(hold)
	screen.show_cards([{"id": "speed", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "range", "grade": 2}], {}, 2)
	screen.skip()
	screen._open_input()
	var tap := InputEventScreenTouch.new()
	tap.index = 1
	tap.pressed = true
	tap.position = Vector2(5000, 5000)
	screen._input(tap)
	assert_eq(screen.state, LevelUpCards.State.READY, "카드 밖은 무시")
	tap.position = screen.get_global_transform_with_canvas() * screen.cards[1].home + Vector2(10, 10)
	screen._input(tap)
	assert_eq(screen.state, LevelUpCards.State.PICKING, "둘째 손가락으로 고름")
	screen.queue_free()
