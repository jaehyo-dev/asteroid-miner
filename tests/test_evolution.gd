extends TestCase
## 짝 스킬 5종과 진화 6개 (v0.8.0 5단계): 카드 조건(A안), 진화 카드 확정, 진화 뒤 칸·짝 스킬 유지, 진화 동작, 도감 저장

const PAIRS := ["chill", "ram", "trail", "charge", "vein"]


func assert_almost_eq(actual: float, expected: float, tolerance: float, message := "") -> void:
	assert_true(absf(actual - expected) <= tolerance, "%s (기대 %s, 실제 %s)" % [message, expected, actual])


## 적이 저절로 나오지 않고 기본 무기는 쏘지 않는 판
func _sim(seed_value := 1234) -> RunSim:
	var sim := RunSim.new(seed_value)
	for t in ["_spawn_timer", "_golden_timer", "_barrage_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
		sim.set(t, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.invuln = 1.0e9
	sim.apply_upgrades()
	sim.weapon = sim.weapon.duplicate()
	sim.weapon["range"] = 0.0
	sim.fire_range = 0.0
	return sim


func _rock(sim: RunSim, pos: Vector2, hp := 100.0, type := 0) -> RunSim.Enemy:
	var a := RunSim.Enemy.new()
	a.type = type
	a.radius = Balance.ASTEROID_TYPES[type]["radius"]
	a.max_hp = hp
	a.hp = hp
	a.pos = pos
	sim.enemies.append(a)
	return a


## 보조 무기 5단계 + 짝 스킬 (진화 직전)
func _ready_for(sim: RunSim, id: String) -> void:
	for i in 5:
		sim.apply_pick(id, 0)
	sim.apply_pick(SubWeapons.evo_of(id)["skill"], Upgrades.EPIC)


func _evo_cards(cards: Array) -> Array:
	return cards.filter(func(c: Dictionary) -> bool: return c.get("evo", false))


func test_진화_6개는_보조_무기와_짝_스킬이_하나씩() -> void:
	assert_eq(Balance.EVOLUTIONS.size(), 6)
	var subs := {}
	for e in Balance.EVOLUTIONS:
		assert_true(SubWeapons.is_sub(e["sub"]), e["id"])
		assert_false(Upgrades.info(e["skill"]).is_empty(), e["skill"])
		subs[e["sub"]] = true
		var icon: Texture2D = load("res://assets/sprites/run/card/icons/%s.png" % e["id"])
		assert_eq(icon.get_size(), Vector2(48, 48), e["id"] + " 카드 아이콘")
		var small: Texture2D = load("res://assets/sprites/run/card/icons_small/%s.png" % e["id"])
		assert_eq(small.get_size(), Vector2(16, 16), e["id"] + " 칸 아이콘")
	assert_eq(subs.size(), 6, "보조 무기마다 하나")
	assert_eq(SubWeapons.evo_of("missile")["skill"], "explosive", "연쇄 폭격 = 미사일 + 고폭 탄두")


func test_새_짝_스킬은_짝_보조_무기가_없으면_안_나옴() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for i in 400:
		for c in Upgrades.roll_choices(random, {}, 3, 300.0, true, true, true, 0.0, {}, [], {}):
			assert_false(c["id"] in PAIRS, "짝 보조 무기 없이 나옴: " + c["id"])
	# 고폭 탄두는 원래 카드라 아무 때나 나온다
	assert_eq(Upgrades.available_in(Balance.EFFECT_UPGRADES, {}, {}, {}).count("explosive"), 1)
	for id in PAIRS:
		assert_eq(Upgrades.available_in(Balance.EFFECT_UPGRADES, {}, {}, {}).count(id), 0, id)


func test_짝_보조_무기를_가지면_짝_스킬이_나오고_더_자주() -> void:
	for e in Balance.EVOLUTIONS:
		var pool := Upgrades.available_in(Balance.EFFECT_UPGRADES, {}, {}, {e["sub"]: 1})
		assert_eq(pool.count(e["skill"]), Balance.PAIR_SKILL_WEIGHT, e["skill"] + " 가중치")
	# 실제 뽑기: 블랙홀을 가지면 냉각 응결탄이 나온다, 한 화면에 같은 카드 두 장은 없다
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var seen := 0
	for i in 400:
		var cards := Upgrades.roll_choices(random, {}, 3, 300.0, true, false, true, 0.0, {}, [], {"blackhole": 2})
		var ids := cards.map(func(c: Dictionary) -> String: return c["id"])
		for id in ids:
			assert_eq(ids.count(id), 1, "같은 카드 두 장")
		if ids.has("chill"):
			seen += 1
	assert_true(seen > 20, "블랙홀이 있으면 냉각 응결탄이 나옴 (%d)" % seen)


func test_짝_스킬_카드에_진화_재료_줄() -> void:
	assert_eq(SubWeapons.pair_of("chill"), "블랙홀 발사기")
	assert_eq(SubWeapons.pair_of("explosive"), "유도 미사일 포드")
	assert_eq(SubWeapons.pair_of("speed"), "")
	assert_eq(LevelCard.pair_lines({"id": "vein", "grade": Upgrades.EPIC}, 12, 400.0), PackedStringArray(["진화 재료: 채굴 펄스"]))
	assert_true(LevelCard.pair_lines({"id": "speed", "grade": 0}, 12, 400.0).is_empty())


func test_조건이_맞으면_다음_레벨업에_진화_카드_1장_확정() -> void:
	for e in Balance.EVOLUTIONS:
		for seed_value in [1, 2, 3, 4, 5]:
			var sim := _sim(seed_value)
			_ready_for(sim, e["sub"])
			sim.gain_xp(Upgrades.xp_to_next(sim.level))
			var evo := _evo_cards(sim.choices)
			assert_eq(evo.size(), 1, "%s 진화 카드 1장" % e["id"])
			assert_eq(evo[0]["id"], e["id"])
			assert_eq(evo[0]["grade"], Upgrades.EVOLUTION)
			assert_eq(evo[0]["recipe"], "%s + %s" % [SubWeapons.info(e["sub"])["name"], Upgrades.display_name(e["skill"])])
			# 다시 뽑아도 그대로 나온다
			sim.reroll()
			assert_eq(_evo_cards(sim.choices).size(), 1, "다시 뽑아도")


func test_조건이_안_맞으면_진화_카드_없음() -> void:
	var sim := _sim()
	for i in 4:
		sim.apply_pick("missile", 0)
	sim.apply_pick("explosive", Upgrades.EPIC)
	for i in 50:
		sim.gain_xp(Upgrades.xp_to_next(sim.level))
		assert_true(_evo_cards(sim.choices).is_empty(), "4단계면 진화 없음")
		sim.skip()
	var sim2 := _sim()
	for i in 5:
		sim2.apply_pick("saw", 0)
	sim2.gain_xp(Upgrades.xp_to_next(sim2.level))
	assert_true(_evo_cards(sim2.choices).is_empty(), "짝 스킬이 없으면 진화 없음")


func test_진화하면_칸_수와_짝_스킬은_그대로이고_진화_카드는_다시_안_나옴() -> void:
	var sim := _sim()
	sim.apply_pick("coil", 0)
	_ready_for(sim, "missile")
	var slots := sim.subs.stages.size()
	var skill_lv: int = sim.upgrade_levels["explosive"]
	sim.gain_xp(Upgrades.xp_to_next(sim.level))
	var index := -1
	for i in sim.choices.size():
		if sim.choices[i].get("evo", false):
			index = i
	sim.choose(index)
	assert_true(sim.subs.is_evolved("missile"))
	assert_eq(sim.subs.stages.size(), slots, "칸 수 그대로")
	assert_eq(sim.subs.stage_of("missile"), 5, "5단계 수치 그대로")
	assert_eq(sim.upgrade_levels["explosive"], skill_lv, "짝 스킬은 남음")
	assert_true(sim.explosive_radius > 0.0, "고폭 탄두 효과도 남음")
	for i in 200:
		sim.gain_xp(Upgrades.xp_to_next(sim.level))
		for c in sim.choices:
			assert_false(c["id"] in ["missile", "evo_missile"], "진화한 무기 카드는 다시 안 나옴: " + c["id"])
		sim.skip()


func test_도감_기록_저장과_읽기() -> void:
	var save := SaveData.new()
	assert_true(save.record_evolution("evo_saw"))
	assert_false(save.record_evolution("evo_saw"), "두 번 기록 안 함")
	assert_false(save.record_evolution("evo_unknown"), "모르는 id")
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_true(back.evolved.has("evo_saw"))
	assert_eq(back.evolved.size(), 1)
	var odd := SaveData.from_dict({"evolved": ["evo_wave", "nope", 3]})
	assert_eq(odd.evolved.keys(), ["evo_wave"], "모르는 값은 버림")
	assert_true(SaveData.from_dict({}).evolved.is_empty(), "예전 저장")


# ── 짝 스킬 동작 (진화 전부터 쓸모) ─────────────────

func test_냉각_응결탄은_맞은_적을_느리게() -> void:
	var sim := _sim()
	sim.apply_pick("chill", Upgrades.UNIQUE)
	var a := _rock(sim, Vector2(60, 0))
	a.vel = Vector2(100, 0)
	sim.sub_hit(a, 0.01, Vector2.ZERO)
	assert_almost_eq(a.chill_slow, 0.4, 0.001)
	var x0 := a.pos.x
	sim.update(0.1, Vector2.ZERO)
	assert_almost_eq(a.pos.x - x0, 100.0 * 0.1 * 0.6, 0.01, "40% 느려짐")


func test_냉각탄은_정지장에_언_적의_정지를_늘리지_않음() -> void:
	var sim := _sim()
	sim.apply_pick("chill", Upgrades.EPIC)
	var a := _rock(sim, Vector2(60, 0))
	a.chill = 0.2
	a.chill_slow = 1.0  # 정지장 안에서 얼음
	sim.sub_hit(a, 0.01, Vector2.ZERO)
	assert_almost_eq(a.chill, 0.2, 0.001, "정지 시간 그대로")
	a.chill = 0.0
	sim.sub_hit(a, 0.01, Vector2.ZERO)
	assert_almost_eq(a.chill_slow, 0.3, 0.001, "녹은 뒤에는 냉각탄 본래 느려짐")


func test_충각_효과는_그려도_오류가_없음() -> void:
	var sim := _sim()
	var fx := SubWeaponFx.new(sim)
	sim.fx.append({"type": "ram", "pos": Vector2.ZERO})
	fx.step(0.016)
	var canvas := Node2D.new()
	add_child(canvas)
	canvas.draw.connect(func() -> void: fx.draw_over(canvas))
	canvas.queue_redraw()
	await wait_frames(2)
	canvas.queue_free()
	assert_eq(fx._hits.size(), 1)


func test_전하_축적_탄은_같은_적을_맞힐수록_세짐() -> void:
	var sim := _sim()
	sim.apply_pick("charge", Upgrades.EPIC)
	var a := _rock(sim, Vector2(60, 0), 1000.0)
	var hits: Array[float] = []
	for i in 7:
		var before := a.hp
		sim.sub_hit(a, 1.0, Vector2.ZERO)
		hits.append(before - a.hp)
	assert_almost_eq(hits[1] / hits[0], 1.08, 0.001, "두 번째 +8%")
	assert_almost_eq(hits[5] / hits[0], 1.4, 0.001, "5번 쌓이면 +40%")
	assert_almost_eq(hits[6], hits[5], 0.001, "최대 5번")


func test_관성_충각은_빠르면_작은_운석을_몸으로_부숨() -> void:
	var sim := _sim()
	sim.invuln = 0.0
	sim.apply_pick("ram", Upgrades.EPIC)
	var small := _rock(sim, Vector2(4, 0), 50.0, 0)
	var hp := sim.hp
	sim.update(0.016, Vector2.RIGHT)
	assert_true(small.hp <= 0.0, "부서짐")
	assert_eq(sim.hp, hp, "안 다침")
	sim.update(0.016, Vector2.ZERO)
	assert_false(sim.enemies.has(small), "정리됨")
	# 멈춰 있으면 그냥 부딪혀 다친다
	var sim2 := _sim()
	sim2.invuln = 0.0
	sim2.apply_pick("ram", Upgrades.EPIC)
	_rock(sim2, Vector2(4, 0), 50.0, 0).damage = 10.0
	sim2.update(0.016, Vector2.ZERO)
	assert_true(sim2.hp < sim2.max_hp, "멈춰 있으면 충각 없음")


func test_잔류_분사_궤적은_지나간_자리에_피해() -> void:
	var sim := _sim()
	sim.apply_pick("trail", Upgrades.EPIC)
	for i in 20:
		sim.update(0.05, Vector2.RIGHT)
	assert_true(sim.trail.size() > 3, "불꽃 점이 남음")
	var a := _rock(sim, sim.trail[0]["pos"], 100.0)
	sim.update(0.1, Vector2.ZERO)
	assert_true(a.hp < 100.0, "불꽃에 닿으면 피해")
	for i in 40:
		sim.update(0.05, Vector2.ZERO)
	assert_true(sim.trail.is_empty(), "1.5초 뒤 사라짐")


func test_광맥_공명기는_운석이_부서지면_둘레에_충격파() -> void:
	var sim := _sim()
	sim.apply_pick("vein", Upgrades.UNIQUE)
	var a := _rock(sim, Vector2(60, 0), 1.0)
	var near := _rock(sim, Vector2(80, 0), 100.0)
	var far := _rock(sim, Vector2(200, 0), 100.0)
	sim.sub_hit(a, 100.0, Vector2.ZERO)
	sim.update(0.016, Vector2.ZERO)
	assert_almost_eq(100.0 - near.hp, Balance.VEIN_ADD[1] * sim.bullet_damage, 0.01, "가까운 적 충격파")
	assert_eq(far.hp, 100.0, "먼 적은 안 맞음")


func test_광맥_충격파로_부서진_운석은_다시_충격파를_안_냄() -> void:
	var sim := _sim()
	sim.apply_pick("vein", Upgrades.UNIQUE)
	var a := _rock(sim, Vector2(60, 0), 1.0)
	var b := _rock(sim, Vector2(80, 0), 0.5)
	var c := _rock(sim, Vector2(110, 0), 100.0)  # b에서는 닿고 a에서는 안 닿는 거리
	sim.sub_hit(a, 100.0, Vector2.ZERO)
	for i in 3:
		sim.update(0.016, Vector2.ZERO)
	assert_false(sim.enemies.has(b), "b는 충격파로 부서짐")
	assert_eq(c.hp, 100.0, "연쇄 없음")


# ── 진화 동작 (5단계보다 동작이 하나 더) ─────────────────

func test_연쇄_폭격은_폭발이_옆_적으로_이어_터짐() -> void:
	var sim := _sim()
	sim.fx_evolve("missile")
	assert_true(sim.subs.is_evolved("missile"))
	var target := _rock(sim, Vector2(80, 0), 1000.0)
	var next := _rock(sim, Vector2(140, 0), 1000.0)
	var chains := 0
	for i in 120:
		sim.update(0.016, Vector2.ZERO)
		for f in sim.fx:
			if f["type"] == "sub_burst" and f["kind"] == "chain":
				chains += 1
	assert_true(chains > 0, "이어 터짐")
	assert_true(next.hp < 1000.0, "옆 적도 맞음")
	assert_true(target.hp < 1000.0)


func test_정지장_붕괴탄은_얼렸다가_끝날_때_한꺼번에_피해() -> void:
	var sim := _sim()
	sim.fx_evolve("blackhole")
	var a := _rock(sim, Vector2(80, 0), 1000.0)
	var frozen := false
	var collapse := false
	for i in 400:
		sim.update(0.016, Vector2.ZERO)
		frozen = frozen or (a.chill > 0.0 and a.chill_slow >= 1.0)
		for f in sim.fx:
			collapse = collapse or f["type"] == "sub_collapse"
		if collapse:
			break
	assert_true(frozen, "블랙홀 안에서 얼어 멈춤")
	assert_true(collapse, "끝날 때 붕괴")
	assert_true(a.hp < 1000.0 - Balance.EVO_COLLAPSE_DAMAGE * sim.bullet_damage * 0.99, "붕괴 피해")


func test_회전_충각은_빠르게_움직일수록_세게_갈아냄() -> void:
	var damage := []
	for move in [Vector2.ZERO, Vector2.RIGHT]:
		var sim := _sim()
		sim.fx_evolve("saw")
		assert_eq(sim.subs.saw_radius(), Balance.EVO_SAW_RADIUS, "톱날이 커짐")
		sim.player_vel = move * sim.move_speed
		var a := _rock(sim, sim.subs.saw_points(Vector2.ZERO)[0], 1000.0)
		sim.subs._update_saw(sim, 0.0, 5)
		damage.append(1000.0 - a.hp)
	assert_true(damage[0] > 0.0)
	assert_almost_eq(damage[1] / damage[0], 1.0 + Balance.EVO_SAW_SPEED_DAMAGE, 0.01, "최고 속도면 피해 ×2.5")


func test_연소_기뢰선은_기뢰_사이_선에_닿은_적에게_피해() -> void:
	var sim := _sim()
	sim.fx_evolve("mine")
	sim.subs.mines.clear()
	sim.subs.mines.append({"pos": Vector2(0, 0), "t": 1.0})
	sim.subs.mines.append({"pos": Vector2(50, 0), "t": 1.0})
	assert_eq(sim.subs.mine_links().size(), 1, "가까운 기뢰는 선으로 이어짐")
	var a := _rock(sim, Vector2(25, 30), 100.0)  # 선 바로 옆 (기뢰엔 안 닿음)
	a.radius = 28.0
	sim.subs._update_mine_links(sim, 0.5)
	assert_almost_eq(100.0 - a.hp, Balance.EVO_MINE_LINE_DPS * sim.bullet_damage * 0.5, 0.01)
	sim.subs.mines[1]["pos"] = Vector2(200, 0)
	assert_true(sim.subs.mine_links().is_empty(), "멀면 안 이어짐")


func test_과충전_방전은_전하가_차면_넓게_방전() -> void:
	var sim := _sim()
	sim.fx_evolve("coil")
	for i in 5:
		_rock(sim, Vector2(40 + i * 10, 0), 1.0e6)
	var far := _rock(sim, Vector2(0, Balance.EVO_COIL_RADIUS - 20.0), 1.0e6)
	var discharged := false
	for i in 600:
		sim.update(0.016, Vector2.ZERO)
		discharged = discharged or sim.events.has("sub_discharge")
		if discharged:
			break
	assert_true(discharged, "방전")
	assert_true(far.hp < 1.0e6, "번개가 안 닿던 먼 적도 맞음")
	assert_true(sim.subs.coil_charge < Balance.EVO_COIL_CHARGE)


func test_공명_파쇄는_작은_운석을_한_번에_부수고_광물을_더_줌() -> void:
	var base_drops := 0
	for evolved in [false, true]:
		var sim := _sim()
		if evolved:
			sim.fx_evolve("wave")
		else:
			for i in 5:
				sim.apply_pick("wave", 0)
		var a := _rock(sim, Vector2(30, 0), 1.0e5, 1)
		var count := 0
		for i in 60:
			sim.update(0.016, Vector2.ZERO)
			for m in sim.minerals:
				count = maxi(count, sim.minerals.size())
		if evolved:
			assert_false(sim.enemies.has(a), "한 번에 부서짐")
			var drops := 0
			for d in RunSim.drops_of(a):
				drops += int(d["count"])
			assert_eq(count, drops + Balance.EVO_WAVE_DROP, "광물 +1")
		else:
			assert_true(sim.enemies.has(a), "5단계는 그대로 금만 감")
			base_drops = count
	assert_eq(base_drops, 0)


func test_진화_화면_효과는_그려도_오류가_없고_상한을_지킴() -> void:
	var sim := _sim()
	var fx := SubWeaponFx.new(sim)
	for id in SubWeapons.ids():
		sim.fx_evolve(id)
		sim.apply_pick("chill", Upgrades.EPIC)
		sim.apply_pick("charge", Upgrades.EPIC)
		sim.apply_pick("trail", Upgrades.EPIC)
		for i in 12:
			_rock(sim, Vector2.from_angle(i) * 50.0, 1.0e5)
		var canvas := Node2D.new()
		add_child(canvas)
		for i in 90:
			sim.update(0.016, Vector2.RIGHT if i % 30 < 20 else Vector2.ZERO)
			fx.step(0.016)
		canvas.draw.connect(func() -> void:
			fx.draw_under(canvas)
			fx.draw_over(canvas))
		canvas.queue_redraw()
		await wait_frames(2)
		canvas.queue_free()
		for list in [fx._links, fx._freezes, fx._discharges, fx._shocks, fx._bursts]:
			assert_true(list.size() <= Juice.SUB_FX_MAX, id + " 효과 상한")
		sim.enemies.clear()
