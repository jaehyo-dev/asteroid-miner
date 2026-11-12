extends TestCase
## 보조 무기 6종 (v0.8.0 4단계): 칸 수, 카드 뽑기, 첫 레벨업 보장, 동작, 블랙홀 광물 끌기


## 적이 저절로 나오지 않는 판 (원하는 자리에만 적을 놓는다)
func _sim(seed_value := 1234) -> RunSim:
	var sim := RunSim.new(seed_value)
	for t in ["_spawn_timer", "_golden_timer", "_barrage_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
		sim.set(t, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.invuln = 1.0e9
	sim.apply_upgrades()
	sim.fire_range = 0.0  # 기본 무기는 쏘지 않게 (보조 무기만 확인)
	sim.weapon = sim.weapon.duplicate()
	sim.weapon["range"] = 0.0
	return sim


func _rock(sim: RunSim, pos: Vector2, hp := 100.0) -> RunSim.Enemy:
	var a := RunSim.Enemy.new()
	a.type = 0
	a.radius = Balance.ASTEROID_TYPES[0]["radius"]
	a.max_hp = hp
	a.hp = hp
	a.pos = pos
	sim.enemies.append(a)
	return a


func _sub_cards(cards: Array) -> Array:
	return cards.filter(func(c: Dictionary) -> bool: return SubWeapons.is_sub(c["id"]))


func test_칸은_3개로_시작하고_연구소_단계마다_1칸() -> void:
	for lv in 3:
		var sim := RunSim.new(1)
		sim.apply_base({"sub": lv})
		assert_eq(sim.sub_slots, 3 + lv, "보조 무기 해금 %d단계" % lv)


func test_칸이_차면_새_보조_무기_카드는_안_나오고_가진_것만() -> void:
	for slots in [3, 4, 5]:
		var owned := {}
		for id in SubWeapons.ids().slice(0, slots):
			owned[id] = 1
		var pool := SubWeapons.pool(owned, slots)
		assert_eq(pool.size(), slots, "칸 %d개가 다 차면 가진 %d개만" % [slots, slots])
		for id in pool:
			assert_true(owned.has(id), "새 보조 무기 없음: " + id)
		owned.erase(owned.keys()[0])
		assert_eq(SubWeapons.pool(owned, slots).size(), 6, "한 칸 비면 다시 모두")
	# 실제 레벨업에서도: 3칸이 찬 판은 수천 번 뽑아도 가진 것만
	var sim := _sim()
	for id in ["missile", "saw", "coil"]:
		sim.apply_pick(id, 0)
	for i in 500:
		sim.screens_done = 1
		sim.rerolls_left = 1
		sim.choices = [{"id": "speed", "grade": 0}]
		sim.reroll()
		for c in _sub_cards(sim.choices):
			assert_true(c["id"] in ["missile", "saw", "coil"], "칸이 차면 새 보조 무기 안 나옴: " + c["id"])
			assert_eq(c["tag"], "보조 무기 3/3")


func test_5단계면_그_보조_무기_카드는_안_나옴() -> void:
	var sim := _sim()
	for id in ["missile", "saw", "coil"]:
		for i in 5:
			sim.apply_pick(id, 0)
	assert_eq(sim.subs.stage_of("missile"), 5)
	assert_eq(sim.upgrade_levels["missile"], 5, "카드 단계 점")
	sim.apply_pick("missile", 0)
	assert_eq(sim.subs.stage_of("missile"), 5, "5단계에서 더 오르지 않음")
	assert_true(SubWeapons.pool(sim.subs.stages, sim.sub_slots).is_empty(), "칸이 찼고 가진 것이 모두 5단계면 뽑을 것 없음")
	for i in 500:
		sim.screens_done = 0  # 첫 화면 보장이 있어도
		sim.rerolls_left = 1
		sim.choices = [{"id": "speed", "grade": 0}]
		sim.reroll()
		assert_true(_sub_cards(sim.choices).is_empty(), "보조 무기 카드 없음")


func test_첫_레벨업_카드에는_보조_무기가_꼭_1장() -> void:
	for seed_value in range(1, 201):
		var sim := RunSim.new(seed_value)
		sim.gain_xp(Upgrades.xp_to_next(1))
		assert_true(_sub_cards(sim.choices).size() >= 1, "시드 %d 첫 화면" % seed_value)
		assert_true(sim.reroll(), "다시 뽑아도")
		assert_true(_sub_cards(sim.choices).size() >= 1, "시드 %d 다시 뽑은 첫 화면" % seed_value)


func test_보조_무기_카드는_종류와_칸_수_지금_다음() -> void:
	var c: Dictionary = SubWeapons.mix_cards(RandomNumberGenerator.new(), [], {"missile": 1}, 3, 1, true)[0]
	assert_true(c["sub"])
	assert_eq(Upgrades.kind_of(c["id"]), "보조 무기")
	assert_eq(c["tag"], "보조 무기 1/3")
	assert_eq(Upgrades.max_stage("missile"), 5)
	assert_eq(SubWeapons.card_text("missile", 0), "몇 초마다 적을 쫓아가는 미사일을 쏜다", "처음 얻는 카드는 설명")
	assert_eq(SubWeapons.card_text("missile", 1), "피해 280 → 360, 폭발 반경 18 → 20, 간격 2.6초 → 2.4", "가진 카드는 바뀌는 수치만")
	assert_eq(SubWeapons.card_text("missile", 1, true), "피해 280 → 360", "폰은 첫 줄만")


func test_보조_무기_6종은_혼자서도_가까운_적에게_피해() -> void:
	for id in SubWeapons.ids():
		var sim := _sim()
		sim.apply_pick(id, 0)
		var rock := _rock(sim, Vector2(24, 0), 1000.0)  # 톱날 반경(26) 근처, 다른 무기 사거리 안
		var other := _rock(sim, Vector2(60, 20), 1000.0)
		sim.player_vel = Vector2.ZERO
		for i in 300:
			sim.update(1.0 / 60.0, Vector2.RIGHT * (0.3 if id == "mine" else 0.0))  # 기뢰는 지나간 자리에 놓인다
			if id == "mine":
				sim.player_pos = Vector2(fposmod(sim.time * 40.0, 50.0) - 10.0, 0.0)
		assert_true(rock.hp < 1000.0 or other.hp < 1000.0, id + " 피해를 줌")


func test_블랙홀은_적과_광물을_끌어당김() -> void:
	var sim := _sim()
	sim.apply_pick("blackhole", 0)
	var center := _rock(sim, Vector2(100, 0), 1000.0)
	var far := _rock(sim, Vector2(130, 0), 1000.0)
	var m := sim.drop_mineral(Vector2(100, 30), 0)
	m.vel = Vector2.ZERO
	sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(sim.subs.holes.size(), 1, "던짐")
	var hole: Vector2 = sim.subs.holes[0]["pos"]
	var m_before := m.pos.distance_to(hole)
	var e_before := far.pos.distance_to(hole)
	for i in 60:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_true(m.pos.distance_to(hole) < m_before - 10.0, "광물이 끌려옴 %.1f → %.1f" % [m_before, m.pos.distance_to(hole)])
	assert_true(far.pos.distance_to(hole) < e_before - 10.0, "적이 끌려옴")
	assert_true(center.hp < 1000.0, "가운데 적은 피해")


func test_자석에_끌려오는_광물은_블랙홀이_빼앗지_않음() -> void:
	var sim := _sim()
	sim.apply_pick("blackhole", 0)
	_rock(sim, Vector2(100, 0), 1000.0)
	var m := sim.drop_mineral(Vector2(100, 30), 0)
	m.attracted = true
	sim.update(1.0 / 60.0, Vector2.ZERO)
	for i in 30:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_true(m.pos.length() < Vector2(100, 30).length(), "우주선 쪽으로 계속 옴")


func test_보조_무기로_부순_적도_광물을_떨어뜨림() -> void:
	var sim := _sim()
	sim.apply_pick("wave", 0)
	_rock(sim, Vector2(30, 0), 0.1)
	sim.update(1.0 / 60.0, Vector2.ZERO)
	for i in 30:
		sim.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(sim.kills, 1)
	var got := sim.minerals.size()
	for c in sim.collected:
		got += c
	assert_true(got >= 1, "광물이 떨어짐 (자석으로 이미 주웠을 수도 있음)")


func test_같은_시드면_보조_무기도_같은_결과() -> void:
	var runs: Array = []
	for k in 2:
		var sim := RunSim.new(77)
		sim.invuln = 1.0e9
		for id in ["missile", "blackhole", "saw", "mine", "coil", "wave"]:
			sim.sub_slots = 6
			sim.apply_pick(id, 0)
		for i in 1800:
			if sim.choosing():
				sim.skip()
			sim.update(1.0 / 60.0, Vector2.from_angle(i * 0.01))
		runs.append([sim.kills, sim.minerals.size(), sim.time])
	assert_eq(runs[0], runs[1])


## Codex 리뷰 반영: 효과 카드 보정으로 나온 효과 카드는 보조 무기 카드로 덮지 않는다
func test_보조_무기_카드는_효과_카드를_덮지_않음() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 300:
		rng.seed = i
		var cards := [{"id": "pierce", "grade": Upgrades.EPIC}, {"id": "speed", "grade": 0}, {"id": "damage", "grade": 0}]
		var mixed := SubWeapons.mix_cards(rng, cards, {}, 3, 3, true)
		assert_eq(mixed[0]["id"], "pierce", "시드 %d" % i)


## Codex 리뷰 반영: 같은 프레임에 이미 부서진(체력 0) 적은 코일·미사일이 노리지 않는다
func test_체력_0인_적은_노리지_않음() -> void:
	var sim := _sim()
	sim.apply_pick("coil", 0)
	var dead := _rock(sim, Vector2(10, 0), 1000.0)
	dead.hp = 0.0
	var alive := _rock(sim, Vector2(60, 0), 1000.0)
	sim.subs.update(sim, 1.0 / 60.0)
	assert_true(alive.hp < 1000.0, "살아 있는 적을 맞힘")


## ?fxtest 확인용 (v0.8.0 배포 전에 지움): Backspace 모두 지우기, Alt+1~6 하나만 1 → 3 → 5단계로 돌기
func test_확인용_보조_무기_지우기와_하나만_최대() -> void:
	var sim := _sim()
	sim.apply_pick("missile", 0)
	sim.apply_pick("mine", 0)
	_rock(sim, Vector2(60, 0), 1000.0)
	for i in 30:
		sim.update(1.0 / 60.0, Vector2.RIGHT)
	assert_false(sim.subs.missiles.is_empty() and sim.subs.mines.is_empty(), "미사일·기뢰가 나와 있음")
	sim.clear_subs()
	assert_true(sim.subs.stages.is_empty())
	assert_true(sim.subs.missiles.is_empty() and sim.subs.mines.is_empty(), "나와 있던 것도 사라짐")
	assert_false(sim.upgrade_levels.has("missile"))
	sim.apply_pick("saw", 0)
	assert_eq(sim.only_sub("coil"), 1)
	assert_eq(sim.subs.stages, {"coil": 1}, "다른 것이 있으면 코일 하나만 1단계부터")
	assert_eq(sim.only_sub("coil"), 3)
	assert_eq(sim.only_sub("coil"), 5)
	assert_eq(sim.subs.stages, {"coil": 5}, "코일 하나만 5단계")
	assert_eq(sim.upgrade_levels["coil"], 5)
	assert_eq(sim.only_sub("coil"), 1, "5단계 다음은 다시 1단계")
	assert_eq(sim.only_sub("wave"), 1, "다른 보조 무기로 바꾸면 1단계부터")


## 단계 연출 (2026-11-12): 1·2단계 / 3·4단계 / 5단계로 모양이 바뀐다
func test_보조_무기_연출은_1_3_5단계에서_모양이_바뀜() -> void:
	var sim := _sim()
	var fx := SubWeaponFx.new(sim)
	var tiers: Array = []
	for i in 5:
		sim.apply_pick("wave", 0)
		tiers.append(fx._tier("wave"))
	assert_eq(tiers, [0, 0, 1, 1, 2])
	assert_eq(fx._lift("wave", Color.BLACK), Color.BLACK, "5단계는 밝기 덤 없음")
	sim.only_sub("wave")
	sim.apply_pick("wave", 0)
	assert_true(fx._lift("wave", Color.BLACK).v > 0.0, "2단계는 조금 밝게")


func test_채굴_펄스와_톱날은_맞은_자리를_그리기용으로_남김() -> void:
	var sim := _sim()
	var fx := SubWeaponFx.new(sim)
	sim.apply_pick("wave", 0)
	_rock(sim, Vector2(30, 0), 1000.0)
	var kinds := {}
	for i in 30:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		for f: Dictionary in sim.fx:
			if f["type"] == "sub_hit":
				kinds[f["kind"]] = true
		fx.step(1.0 / 60.0)
	assert_true(kinds.has("wave"), "파동이 운석에 닿으면 sub_hit")
	assert_false(fx._hits.is_empty(), "1단계 파동도 금이 간다")
	assert_false(fx._waves.is_empty() and fx._hits.is_empty())


func test_5단계_블랙홀은_사라질_때_붕괴_연출() -> void:
	var sim := _sim()
	var fx := SubWeaponFx.new(sim)
	for i in 5:
		sim.apply_pick("blackhole", 0)
	_rock(sim, Vector2(60, 0), 1.0e6)
	var seen := false
	for i in 60 * 5:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		fx.step(1.0 / 60.0)
		seen = seen or not fx._collapses.is_empty()
	assert_true(seen, "블랙홀이 끝나면 붕괴")


func test_보조_무기_효과_개수는_상한을_넘지_않음() -> void:
	var sim := _sim()
	var fx := SubWeaponFx.new(sim)
	for id in ["wave", "saw", "coil", "mine", "missile"]:
		for i in 5:
			sim.apply_pick(id, 0)
	for i in 40:
		_rock(sim, Vector2.from_angle(i * 0.7) * (20.0 + i * 3.0), 1.0e6)
	for i in 60 * 6:
		sim.update(1.0 / 60.0, Vector2.from_angle(i * 0.05))
		fx.step(1.0 / 60.0)
		assert_true(fx._hits.size() <= Juice.SUB_HIT_MAX and fx._bursts.size() <= Juice.SUB_FX_MAX and fx._zaps.size() <= Juice.SUB_FX_MAX and fx._waves.size() <= Juice.SUB_FX_MAX)


## 그리기 코드가 단계마다 오류 없이 도는지 (화면에 붙여 실제로 그린다)
func test_보조_무기_6종_1_3_5단계_그리기() -> void:
	for id in SubWeapons.ids():
		for stage in [1, 3, 5]:
			var sim := _sim()
			for i in stage:
				sim.apply_pick(id, 0)
			for i in 6:
				_rock(sim, Vector2.from_angle(i) * 40.0, 1.0e6)
			var view := WorldView.new()
			view.sim = sim
			add_child(view)
			for f in 20:
				sim.update(1.0 / 20.0, Vector2.RIGHT if f % 4 < 2 else Vector2.LEFT)
				view.step(1.0 / 20.0)
				view.queue_redraw()
				await wait_frames(1)
			assert_true(sim.alive, "%s %d단계" % [id, stage])
			view.queue_free()
