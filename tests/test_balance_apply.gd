extends TestCase
## v0.7.0 밸런스 적용: 상한 카드 빼기, "지금 → 다음" 문구, 후반 적 피해, 경험치 기준 등급, 건너뛰기, 광물 합치기, 드론 탄.

const RunScene := preload("res://scenes/run.tscn")


func _sim(base: Dictionary = {}) -> RunSim:
	var sim := RunSim.new(1)
	sim.apply_base(base)
	return sim


# ── 1) 스킬 점검 ────────────────────────────────

func test_상한에_닿은_효과_카드는_안_나옴() -> void:
	for id in ["pierce", "crit", "drone", "mining_laser", "ricochet"]:
		var sim := _sim()
		while float(sim.upgrade_bonus.get(id, 0.0)) < Upgrades.cap_of(id):
			sim.apply_pick(id, Upgrades.UNIQUE)
		assert_true(int(sim.upgrade_levels[id]) < Upgrades.max_stage(id) or id == "ricochet", id + ": 단계는 남았는데 상한")
		assert_false(Upgrades.available_in(Balance.EFFECT_UPGRADES, sim.upgrade_levels, sim.upgrade_bonus).has(id), id + " 카드 빠짐")
	var one := _sim()
	one.apply_pick("drone", Upgrades.UNIQUE)
	assert_true(Upgrades.available_in(Balance.EFFECT_UPGRADES, one.upgrade_levels, one.upgrade_bonus).has("drone"), "상한 전이면 나옴")


func test_상한_카드는_실제_뽑기에도_안_나옴() -> void:
	var sim := _sim()
	sim.apply_pick("drone", Upgrades.UNIQUE)
	sim.apply_pick("drone", Upgrades.UNIQUE)
	for i in 300:
		sim._roll_choices()
		for c in sim.choices:
			assert_true(c["id"] != "drone", "드론 3기 뒤 드론 카드")


func test_가진_효과_카드는_지금_다음_문구() -> void:
	var b := {}
	Upgrades.add_bonus(b, "drone", Upgrades.UNIQUE)
	assert_eq(Upgrades.describe_next("drone", Upgrades.UNIQUE, b, true), "드론 2기 → 3기")
	b = {}
	Upgrades.add_bonus(b, "shield", Upgrades.UNIQUE)
	assert_eq(Upgrades.describe_next("shield", Upgrades.EPIC, b), "12초 → 9초마다 피해 1번을 막음")
	b = {}
	Upgrades.add_bonus(b, "explosive", Upgrades.EPIC)
	assert_eq(Upgrades.describe_next("explosive", Upgrades.EPIC, b, true), "폭발 반경 24 → 30")
	assert_eq(Upgrades.describe_next("explosive", Upgrades.UNIQUE, b), "폭발 반경 24 → 42, 피해 50% → 75%")
	assert_eq(Upgrades.describe("drone", Upgrades.UNIQUE), "드론 +2기가 따라다니며 함께 공격", "처음 찍는 유니크는 +2기")


func test_뽑힌_카드에_지금_다음_문구가_붙음() -> void:
	var sim := _sim()
	sim.apply_pick("shield", Upgrades.UNIQUE)
	var found := false
	for i in 300:
		sim._roll_choices()
		for c in sim.choices:
			if c["id"] == "shield":
				found = true
				assert_true(Upgrades.card_text(c).contains("12초 →"), Upgrades.card_text(c))
				assert_true(LevelCard.desc_lines(c, 12, 200.0)[0].contains("→"))
	assert_true(found, "실드 카드가 한 번은 나옴")


func test_이름_정리() -> void:
	assert_eq(Upgrades.display_name("shield"), "자동 방어막 발생기")
	assert_true(BaseUpgrades.info("shield")["name"] != Upgrades.display_name("shield"), "연구소 실드와 이름이 다름")
	assert_eq(BaseUpgrades.info("over")["name"], "증폭 탄창")
	assert_true(Upgrades.describe("chain_matrix", Upgrades.LEGENDARY).contains("80%"))


func test_HUD_실드_칸은_연구소_실드_횟수() -> void:
	assert_eq(_sim().block_slots(), 0)
	var sim := _sim({"shield": 3})
	assert_eq(sim.block_slots(), 3)
	sim.damage_player(1.0)
	assert_eq(sim.blocks_left, 2)
	assert_eq(_sim({"bolt": 1}).block_slots(), 1, "실드 충전만 있어도 1칸")


# ── 2) 난이도 D ────────────────────────────────

func test_후반_적_피해는_2분30초부터_1분마다_25퍼센트_최대_2_5배() -> void:
	var table := {0.0: 1.0, 209.0: 1.0, 210.0: 1.25, 270.0: 1.5, 390.0: 2.0, 450.0: 2.25, 510.0: 2.5, 900.0: 2.5}
	for t in table:
		assert_true(is_equal_approx(RunSim.enemy_damage_mult(t), table[t]), "%s초 ×%s" % [t, RunSim.enemy_damage_mult(t)])
	var sim := _sim()
	sim.time = 300.0
	sim.damage_player(10.0)
	assert_true(is_equal_approx(sim.hp, sim.max_hp - 15.0), "5:00에 10 → 15")


func test_적_피해가_오를_때_안내_이벤트() -> void:
	var sim := _sim()
	sim.invuln = 1.0e9
	sim.time = 209.99
	sim.update(0.02, Vector2.ZERO)
	assert_true(sim.events.has("enemy_damage_up"))
	sim.update(0.02, Vector2.ZERO)
	assert_false(sim.events.has("enemy_damage_up"), "한 번만")


func test_경험치는_떨어질_때_등급_기준() -> void:
	var sim := _sim({"radar": 5})
	sim.rng.seed = 3
	var raised := 0
	for i in 400:
		var a := RunSim.Enemy.new()
		a.type = 0
		sim._on_enemy_destroyed(a)
	for m in sim.minerals:
		assert_eq(m.xp, RunSim.mineral_xp(0), "탐지기로 올라도 경험치는 일반")
		raised += 1 if m.grade == 1 else 0
	assert_true(raised > 0, "탐지기로 오른 광물이 있음")
	var picked := _sim()
	var m := picked.drop_mineral(picked.player_pos, 1)
	m.xp = 1
	picked._update_minerals(0.01)
	assert_eq(picked.xp, 1, "주우면 붙은 경험치")
	assert_eq(picked.cargo.value(), 5, "가치는 오른 등급")


# ── 3) 건너뛰기 ────────────────────────────────

func test_건너뛰기는_필요_경험치의_15퍼센트를_금고로_경험치_없음() -> void:
	var sim := _sim()
	assert_eq(sim.skip(), 0, "레벨업 중이 아니면 없음")
	sim.level = 3
	sim.gain_xp(Upgrades.xp_to_next(3))
	assert_true(sim.choosing())
	var xp := sim.xp
	var reward := sim.skip()
	assert_eq(reward, roundi(Upgrades.xp_to_next(4) * 0.15))
	assert_eq(sim.skip_banked, reward)
	assert_eq(sim.xp, xp, "경험치 없음")
	assert_eq(sim.cargo.value(), 0, "화물칸이 아님")
	assert_false(sim.choosing(), "닫힘")
	sim.alive = false
	assert_eq(sim.skip_banked, reward, "죽어도 그대로")


func test_건너뛰기_뒤_남은_레벨업이_있으면_다음_카드() -> void:
	var sim := _sim()
	sim.gain_xp(Upgrades.xp_to_next(1) + Upgrades.xp_to_next(2))
	assert_eq(sim.pending_levelups, 2)
	sim.skip()
	assert_true(sim.choosing() and not sim.choices.is_empty(), "다음 카드")


func test_고를_카드가_없어도_건너뛰기로_넘어감() -> void:
	var sim := _sim()
	for u in Balance.UPGRADES:
		sim.upgrade_levels[u["id"]] = u["max"]
	sim.effects_enabled = false
	sim.gain_xp(Upgrades.xp_to_next(1))
	assert_true(sim.choosing() and sim.choices.is_empty(), "카드 없이 레벨업 화면")
	var t := sim.time
	sim.update(0.1, Vector2.ZERO)
	assert_eq(sim.time, t, "고르는 동안 멈춤")
	assert_true(sim.skip() > 0)
	assert_false(sim.choosing())


func test_건너뛰기_버튼은_금고에_더하고_저장() -> void:
	var run: Node = RunScene.instantiate()
	add_child(run)
	await wait_frames(2)
	run.sim.invuln = 1.0e9
	var before: int = run.save.credits
	run.sim.gain_xp(Upgrades.xp_to_next(1))
	var reward: int = run.sim.skip_reward()
	run.slowmo = 0.0
	await wait_frames(2)
	assert_true(run.cards.visible)
	assert_true(run.cards.skip_button.visible or run.cards.is_revealing(), "건너뛰기 버튼")
	run.cards.skip()
	run.cards._open_input()
	run.cards.skip_pick()
	await wait_frames(1)
	assert_eq(run.save.credits, before + reward, "금고에 바로")
	assert_true(run.hud.banner_text.contains("금고"), run.hud.banner_text)
	assert_false(run.sim.choosing())
	run.queue_free()


# ── 6) 광물 합치기 ────────────────────────────────

## 우주선에서 멀리(자석 밖) 같은 등급 n개를 좁게 놓는다
func _pile(sim: RunSim, grade: int, n: int, at := Vector2(500, 0), step := 3.0) -> void:
	for i in n:
		sim.drop_mineral(at + Vector2(i * step, 0), grade)


func _value(sim: RunSim) -> int:
	var v := 0
	for m in sim.minerals:
		v += int(Balance.MINERAL_GRADES[m.grade]["value"])
	return v


func test_합치기_개수는_가치를_보존() -> void:
	for g in 3:
		assert_eq(int(Balance.MERGE_COUNT[g]) * int(Balance.MINERAL_GRADES[g]["value"]), int(Balance.MINERAL_GRADES[g + 1]["value"]), "등급 %d" % g)
	assert_eq(Balance.MERGE_COUNT[3], 0, "전설은 안 합침")


func test_같은_등급_정해진_개수가_1_5초_넘게_있으면_한_단계_위로() -> void:
	for g in 3:
		var sim := _sim()
		_pile(sim, g, Balance.MERGE_COUNT[g])
		var value := _value(sim)
		sim._update_minerals(1.0)
		assert_eq(sim.minerals.size(), Balance.MERGE_COUNT[g], "1초는 아직")
		sim._update_minerals(0.6)
		assert_eq(sim.minerals.size(), 1, "등급 %d 합쳐짐" % g)
		assert_eq(sim.minerals[0].grade, g + 1)
		assert_eq(_value(sim), value, "가치 그대로")
		assert_eq(sim.minerals[0].xp, value, "경험치도 가치 기준 그대로")
		assert_eq(sim.merged.size(), 1, "연출 정보")


func test_개수가_모자라거나_반경_밖이면_안_합침() -> void:
	var few := _sim()
	_pile(few, 0, 4)
	few._update_minerals(2.0)
	few._update_minerals(0.1)
	assert_eq(few.minerals.size(), 4, "4개는 안 합침")
	var far := _sim()
	_pile(far, 0, 4)
	far.drop_mineral(Vector2(500 + Balance.MERGE_RADIUS + 13.0, 0), 0)  # 처음 광물에서 반경 밖
	far._update_minerals(2.0)
	far._update_minerals(0.1)
	assert_eq(far.minerals.size(), 5, "반경 밖은 빠짐")
	var mixed := _sim()
	_pile(mixed, 0, 4)
	mixed.drop_mineral(Vector2(506, 2), 1)
	mixed._update_minerals(2.0)
	assert_eq(mixed.minerals.size(), 5, "다른 등급은 세지 않음")


func test_끌려오는_광물은_빠짐() -> void:
	var sim := _sim()
	_pile(sim, 0, 5)
	sim._update_minerals(1.0)
	sim.minerals[2].attracted = true
	sim.minerals[2].pos = Vector2(4000, 0)  # 끌려가는 중 (여기서는 멀리 둬서 줍지 않게)
	sim._update_minerals(1.0)
	assert_eq(sim.minerals.size(), 5)


func test_움직이는_동안은_놓인_시간이_안_쌓임() -> void:
	var sim := _sim()
	_pile(sim, 0, 5)
	sim._update_minerals(1.0)
	sim.minerals[0].vel = Vector2(1000, 0)
	sim._update_minerals(0.01)
	assert_eq(sim.minerals[0].rest, 0.0, "튕겨 나가는 광물은 놓인 시간이 처음부터")
	assert_true(sim.minerals[1].rest > 1.0)


func test_연쇄_합치기와_전설_도감() -> void:
	var sim := _sim()
	_pile(sim, 0, 20, Vector2(500, 0), 1.0)
	_pile(sim, 1, 12, Vector2(500, 4), 1.0)
	_pile(sim, 2, 1, Vector2(500, 8), 1.0)
	var value := _value(sim)
	sim._update_minerals(1.6)
	var seen := {}
	for i in 6:
		for id in Discovery.seen_now(sim):
			seen[id] = true
		sim._update_minerals(Balance.MERGE_CHECK_INTERVAL)
	assert_eq(_value(sim), value, "가치 그대로")
	assert_eq(sim.minerals.size(), 1, "일반 20 → 희귀 4, 희귀 16 → 영웅 4, 영웅 5 → 전설 1")
	assert_eq(sim.minerals[0].grade, 3)
	assert_true(seen.has("mineral_3"), "합쳐 생긴 전설도 발견")


func test_합치기_검사는_정해진_간격마다() -> void:
	var sim := _sim()
	_pile(sim, 0, 5)
	sim._update_minerals(1.6)  # 놓인 시간은 넘었고 첫 검사로 합쳐짐
	assert_eq(sim.minerals.size(), 1)
	_pile(sim, 0, 5, Vector2(800, 0))
	for m in sim.minerals:
		m.rest = 2.0  # 놓인 시간은 이미 넘김
	sim._update_minerals(Balance.MERGE_CHECK_INTERVAL * 0.5)
	assert_eq(sim.minerals.size(), 6, "간격 전에는 검사 안 함")
	sim._update_minerals(Balance.MERGE_CHECK_INTERVAL * 0.6)
	assert_eq(sim.minerals.size(), 2, "간격이 차면 검사")


func test_한_프레임_검사_수_제한() -> void:
	var sim := _sim()
	for i in 200:
		sim.drop_mineral(Vector2(500 + i * 100, 0), 0)  # 흩어진 광물: 합칠 것 없음
	sim._update_minerals(2.0)
	assert_eq(sim._merge_cursor, Balance.MERGE_CHECKS_PER_FRAME, "한 프레임에 정해진 수만 기준으로 봄")


# ── 4) 드론 탄 ────────────────────────────────

func test_드론_탄은_표시가_붙고_판정은_같음() -> void:
	var sim := _sim()
	sim.apply_pick("drone", Upgrades.EPIC)
	sim.spawn_asteroid()
	sim.enemies[0].pos = sim.player_pos + Vector2(40, 0)
	sim.enemies[0].vel = Vector2.ZERO
	sim.enemies[0].hp = 1.0e9
	sim._update_drones(0.0)
	sim.drones[0].timer = 0.0
	sim.bullets.clear()
	sim._update_drones(0.01)
	assert_eq(sim.bullets.size(), 1)
	assert_true(sim.bullets[0].drone, "드론 탄")
	assert_eq(RunSprites.CELL["drone_bullet"], 16)
	assert_true(RunAtlas.ENTRIES.has("drone_bullet"))


func test_카드_문구는_화살표에서_안_끊기고_넘치면_나눔() -> void:
	var size := func(t: String) -> float: return LevelCard.FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var w: float = maxf(size.call("폭발 반경"), size.call("24 → 30")) + 1.0
	assert_eq(LevelCard.wrap_text("폭발 반경 24 → 30", 12, w), PackedStringArray(["폭발 반경", "24 → 30"]))
	var narrow: float = size.call("12초 →") + 1.0
	for line in LevelCard.wrap_text("12초 → 9초마다 막음", 12, narrow):
		assert_true(size.call(line) <= narrow or not line.contains(" "), "넘치는 줄 없음: " + line)
