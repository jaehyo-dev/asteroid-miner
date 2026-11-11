extends TestCase
## 기본 무기 5종 (v0.8.0): 무기 표, 연구소 해금, 장착·저장, 격납고 능력치 4칸, 무기마다 다른 발사·대상·채굴량.


## 아무것도 저절로 나오지 않는 시뮬레이션 (쏘기는 함)
func _sim(weapon: String) -> RunSim:
	var sim := RunSim.new(1234)
	for t in ["_spawn_timer", "_golden_timer", "_barrage_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
		sim.set(t, 1.0e9)
	sim.set_weapon(weapon)
	return sim


func _rock(sim: RunSim, pos: Vector2, type := 0, hp := -1.0) -> RunSim.Enemy:
	var a := RunSim.Enemy.new()
	a.type = type
	a.radius = Balance.ASTEROID_TYPES[type]["radius"]
	a.damage = Balance.ASTEROID_TYPES[type]["damage"]
	a.max_hp = Balance.ASTEROID_TYPES[type]["hp"] if hp < 0.0 else hp
	a.hp = a.max_hp
	a.pos = pos
	sim.enemies.append(a)
	return a


func _creature(sim: RunSim, pos: Vector2, hp := 100.0) -> RunSim.Enemy:
	var a := _rock(sim, pos, 0, hp)
	a.kind = "jelly"
	return a


func _run(sim: RunSim, seconds: float) -> void:
	for i in int(seconds / 0.02):
		if sim.choosing():
			sim.skip()  # 광물을 주워 레벨업하면 판이 멈추므로 넘긴다
		sim.update(0.02, Vector2.ZERO)


# ── 무기 표 ─────────────────────────────────────

func test_무기_5종_이름과_해금_가격() -> void:
	assert_eq(Weapons.ids(), ["pulse", "shotgun", "rail", "plasma", "beam"])
	var names := Balance.WEAPONS.map(func(w: Dictionary) -> String: return w["name"])
	assert_eq(names, ["펄스 연사포", "산탄포", "레일건", "플라스마 대포", "채굴 빔"], "weapon_names.md 이름 그대로")
	assert_eq([Weapons.cost("pulse"), Weapons.cost("shotgun"), Weapons.cost("rail"), Weapons.cost("plasma"), Weapons.cost("beam")], [0, 600, 900, 1200, 1500])


func test_무기는_연구소가_아니라_격납고에서_삼() -> void:
	for id in Weapons.ids():
		assert_false(Research.tree("weapon").has("w_" + id), "연구소 무기 가지에 %s 해금 칸 없음" % id)
		assert_true(BaseUpgrades.info("w_" + id).is_empty() or not BaseUpgrades.info("w_" + id).has("cost"), "연구소 칸 표에도 없음")


func test_펄스_연사포는_예전_수치_그대로() -> void:
	var sim := RunSim.new(1)
	assert_eq(sim.weapon["id"], "pulse", "처음은 펄스")
	assert_eq(sim.fire_interval, Balance.FIRE_INTERVAL)
	assert_eq(sim.fire_range, Balance.FIRE_RANGE)


func test_무기를_바꾸면_간격과_사거리가_바뀌고_강화가_곱해짐() -> void:
	var sim := RunSim.new(1)
	sim.apply_pick("range", 0)
	sim.set_weapon("rail")
	assert_almost(sim.fire_range, 300.0 * (1.0 + Balance.UPGRADES[3]["values"][0]))
	assert_eq(sim.fire_interval, Weapons.info("rail")["interval"])


# ── 해금·장착·저장 ────────────────────────────────

func test_사야_장착할_수_있고_사면_바로_장착() -> void:
	var s := SaveData.new()
	s.credits = 1000
	assert_true(Weapons.unlocked(s, "pulse"))
	assert_false(Weapons.unlocked(s, "shotgun"))
	assert_false(Weapons.equip(s, "shotgun"), "잠긴 무기는 장착 못 함")
	assert_eq(Weapons.equipped(s), "pulse")
	assert_true(Weapons.buy(s, "rail"), "순서 제한 없음 (산탄포 먼저 안 사도 됨)")
	assert_eq(s.credits, 100)
	assert_eq(Weapons.equipped(s), "rail", "사면 바로 장착")
	assert_false(Weapons.buy(s, "rail"), "이미 있음")
	assert_false(Weapons.buy(s, "shotgun"), "광물 부족 (100 < 600)")
	assert_eq(s.credits, 100, "못 사면 광물 그대로")
	assert_false(Weapons.buy(s, "pulse"), "처음부터 있는 무기")
	assert_false(Weapons.buy(s, "laser_sword"), "모르는 무기")
	assert_true(Weapons.equip(s, "pulse"))
	assert_true(Weapons.equip(s, "rail"), "산 무기는 다시 장착")


func test_예전_연구소_해금과_산_무기는_저장에_남음() -> void:
	var old := SaveData.from_dict({"upgrades": {"w_plasma": 1, "w_beam": 0}, "weapon": "plasma"})
	assert_eq(old.weapons_owned, ["plasma"], "2단계 저장의 연구소 해금은 산 것으로")
	assert_eq(Weapons.equipped(old), "plasma")
	assert_false(old.upgrades.has("w_plasma"), "연구소 칸은 없어짐")
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	assert_eq(back.weapons_owned, ["plasma"], "다시 저장해도 남음")
	assert_eq(SaveData.from_dict({"weapons_owned": ["rail", "rail", "pulse", "laser", 3]}).weapons_owned, ["rail"], "모르는 값·중복·기본 무기는 버림")
	assert_eq(SaveData.from_dict({"weapons_owned": "rail"}).weapons_owned, [], "목록이 아님")


func test_장착한_무기는_저장되고_모르는_값은_펄스() -> void:
	var s := SaveData.new()
	s.weapons_owned = ["beam"]
	assert_true(Weapons.equip(s, "beam"))
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.weapon, "beam")
	assert_eq(Weapons.equipped(back), "beam")
	assert_eq(SaveData.from_dict({"weapon": "laser_sword"}).weapon, "pulse", "모르는 무기")
	assert_eq(SaveData.from_dict({"weapon": 3}).weapon, "pulse", "글자가 아님")
	assert_eq(Weapons.equipped(SaveData.from_dict({"weapon": "rail"})), "pulse", "해금 안 된 무기는 펄스로 출격")
	assert_eq(SaveData.from_dict({}).weapon, "pulse", "옛 저장")


func test_확인용_스위치는_모두_해금() -> void:
	var s := SaveData.new()
	Weapons.test_mode = true
	var all := Weapons.ids().all(func(id: String) -> bool: return Weapons.unlocked(s, id))
	Weapons.test_mode = false
	assert_true(all)
	assert_false(Weapons.unlocked(s, "rail"), "끄면 원래대로")


# ── 격납고 능력치 4칸 ──────────────────────────────

func test_능력치는_4칸_같은_순서() -> void:
	for id in Weapons.ids():
		var bars := Weapons.bars(id)
		assert_eq(bars.map(func(b: Dictionary) -> String: return b["name"]), ["공격력", "사거리", "연사", "채굴량"], id)
		for b: Dictionary in bars:
			assert_true(int(b["level"]) >= 1 and int(b["level"]) <= 5, "%s %s" % [id, b])
	var lv := func(id: String, i: int) -> int: return Weapons.bars(id)[i]["level"]
	assert_eq(lv.call("rail", 1), 5, "레일건 사거리 최고")
	assert_eq(lv.call("beam", 2), 5, "빔 연사 최고")
	assert_eq(lv.call("beam", 3), 5, "빔 채굴량 최고")
	assert_true(lv.call("plasma", 3) < lv.call("pulse", 3), "플라스마 채굴량 적음")
	assert_true(lv.call("shotgun", 1) < lv.call("pulse", 1), "산탄 사거리 짧음")


# ── 무기마다 다른 발사 ─────────────────────────────

func test_산탄포는_부채꼴_다섯_발() -> void:
	var sim := _sim("shotgun")
	_rock(sim, Vector2(60, 0), 2, 100.0)
	sim.update(0.02, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 5)
	var angles := sim.bullets.map(func(b: RunSim.Bullet) -> float: return rad_to_deg(b.vel.angle()))
	assert_almost(angles.max() - angles.min(), Weapons.info("shotgun")["fan_deg"], 0.5)


func test_산탄포는_다중_포신마다_2발씩() -> void:
	var sim := _sim("shotgun")
	sim.apply_pick("multishot", 0)
	_rock(sim, Vector2(60, 0), 2, 100.0)
	sim.update(0.02, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 7)


func test_산탄포는_사거리가_짧아_먼_적은_안_쏨() -> void:
	var sim := _sim("shotgun")
	_rock(sim, Vector2(140, 0))
	sim.update(0.02, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 0)


func test_레일건은_가장_먼_적을_노리고_일렬을_모두_뚫음() -> void:
	var sim := _sim("rail")
	var near := _rock(sim, Vector2(40, 0), 2, 2.0)
	var mid := _rock(sim, Vector2(120, 0), 2, 2.0)
	var far := _rock(sim, Vector2(250, 0), 2, 2.0)
	var side := _rock(sim, Vector2(0, 60), 2, 2.0)
	_run(sim, 0.5)
	for a in [near, mid, far]:
		assert_true(a.hp <= 0.0, "일렬 관통")
	assert_true(side.hp > 0.0, "옆 적은 안 맞음")


func test_레일건은_화면_밖_적은_노리지_않음() -> void:
	var sim := _sim("rail")
	sim.view_size = Vector2(640, 360)
	_rock(sim, Vector2(0, 250), 2, 100.0)  # 사거리 안이지만 화면 위쪽 밖
	var seen := _rock(sim, Vector2(100, 0), 2, 100.0)
	sim.update(0.02, Vector2.ZERO)
	assert_eq(sim.bullets.size(), 1)
	assert_true(absf(sim.bullets[0].vel.angle()) < 0.05, "보이는 적 쪽 %f" % sim.bullets[0].vel.angle())
	assert_true(seen != null)


func test_플라스마는_모인_곳을_노려_한꺼번에_터짐() -> void:
	var sim := _sim("plasma")
	var lone := _rock(sim, Vector2(50, 0), 2, 1.0)
	var pack: Array = []
	for off in [Vector2(0, 0), Vector2(14, 6), Vector2(-10, 12), Vector2(6, -14)]:
		pack.append(_rock(sim, Vector2(0, -120) + off, 0, 1.5))
	_run(sim, 1.2)
	assert_true(pack.all(func(a: RunSim.Enemy) -> bool: return a.hp <= 0.0), "모인 4개가 한 번에")
	assert_true(lone.hp > 0.0, "가까운 외톨이는 아직")
	assert_true(sim.fx.size() >= 0)


func test_플라스마는_못_맞혀도_사거리_끝에서_터짐() -> void:
	var sim := _sim("plasma")
	var a := _rock(sim, Vector2(150, 0), 0, 1.0)
	sim.update(0.02, Vector2.ZERO)
	sim.enemies.clear()  # 탄이 날아가는 사이 대상이 사라짐
	var burst := false
	for i in 100:
		sim.update(0.02, Vector2.ZERO)
		burst = burst or sim.events.has("explode")
	assert_true(burst)
	assert_true(a != null)


func test_채굴_빔은_운석을_먼저_노리고_적에게는_약함() -> void:
	var sim := _sim("beam")
	var jelly := _creature(sim, Vector2(70, 0))
	var rock := _rock(sim, Vector2(0, 85), 2, 100.0)
	_run(sim, 0.3)
	assert_eq(sim.beam_targets, [rock] as Array[RunSim.Enemy], "더 멀어도 운석")
	assert_eq(sim.bullets.size(), 0, "탄을 쏘지 않음")
	assert_eq(jelly.hp, 100.0, "적은 안 맞음")
	var rock_loss := 100.0 - rock.hp
	assert_almost(rock_loss, 3.0 * Weapons.info("beam")["damage"], 0.25)
	sim.enemies.erase(rock)
	_run(sim, 0.3)
	assert_eq(sim.beam_targets, [jelly] as Array[RunSim.Enemy], "운석이 없으면 적")
	assert_almost(100.0 - jelly.hp, rock_loss * Weapons.info("beam")["enemy_mult"], 0.15)


func test_채굴_빔은_사거리_밖이면_안_닿음() -> void:
	var sim := _sim("beam")
	_rock(sim, Vector2(Weapons.info("beam")["range"] + 20.0, 0))
	_run(sim, 0.2)
	assert_true(sim.beam_targets.is_empty())


## 작은 운석 200개를 부숴 나온 광물 수 (시드 고정)
func _drops(weapon: String) -> int:
	var sim := _sim(weapon)
	var total := 0
	for i in 200:
		var a := _rock(sim, Vector2.ZERO)
		a.hp = 0.0
		sim.set("_spawn_timer", 1.0e9)
		var before := sim.minerals.size()
		sim.call("_check_bullet_hits")
		total += sim.minerals.size() - before
		sim.minerals.clear()
	return total


func test_채굴량은_무기마다_다름() -> void:
	assert_eq(_drops("pulse"), 200, "펄스는 그대로")
	assert_almost(float(_drops("beam")), 300.0, 30.0)
	assert_almost(float(_drops("plasma")), 150.0, 30.0)
	assert_almost(float(_drops("shotgun")), 230.0, 30.0)


func test_출격하면_장착한_무기로_시작() -> void:
	var old := SaveData.path
	SaveData.path = "user://test_weapons_save.json"
	var s := SaveData.new()
	s.weapons_owned = ["plasma"]
	s.weapon = "plasma"
	s.warp_seen = true
	s.save_file()
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await wait_frames(2)
	assert_eq(run.sim.weapon["id"], "plasma")
	run.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	SaveData.path = old


func assert_almost(actual: float, expected: float, tolerance := 0.001, message := "") -> void:
	assert_true(absf(actual - expected) <= tolerance, "%s 기대값 %f, 실제값 %f" % [message, expected, actual])


func test_효과_없는_카드는_그_무기에서_안_나옴() -> void:
	for id in ["rail", "plasma", "beam"]:
		var sim := _sim(id)
		sim.time = 300.0  # 효과·레전드리 카드가 자주 나오는 때
		var skip: Array = Weapons.info(id)["no_cards"]
		var seen := {}
		for i in 300:
			sim.call("_roll_choices")
			for c in sim.choices:
				seen[c["id"]] = true
		for bad in skip:
			assert_false(seen.has(bad), "%s에 %s" % [id, bad])
	var pulse := _sim("pulse")
	pulse.time = 300.0
	var any_pierce := false
	for i in 300:
		pulse.call("_roll_choices")
		any_pierce = any_pierce or pulse.choices.any(func(c: Dictionary) -> bool: return c["id"] == "pierce")
	assert_true(any_pierce, "펄스는 관통 카드가 나옴")


# ── 공격 이펙트 후보 (?fxtest) ──────────────────────

func test_무기마다_이펙트_후보_3개와_공통_수치() -> void:
	for id in Weapons.ids():
		assert_eq(Juice.WEAPON_FX[id].size(), 3, id)
		for p: Dictionary in Juice.WEAPON_FX[id]:
			for key in ["muzzle", "muzzle_time", "muzzle_color", "recoil", "hit_n", "hit_speed", "hit_life", "hit_size", "hit_colors", "hit_ring", "hit_flash"]:
				assert_true(p.has(key), "%s %s" % [id, key])
	assert_eq(Weapons.fx("rail"), 1, "고르기 전엔 후보 1")


func test_맞으면_hit_효과가_나오고_효과_수는_상한을_넘지_않음() -> void:
	for id in Weapons.ids():
		for cand in [1, 2, 3]:
			Weapons.fx_pick[id] = cand
			var sim := _sim(id)
			var fx := WeaponFx.new(sim)
			var hits := 0
			for i in 20:
				_rock(sim, Vector2(40 + i * 3, (i % 5) * 6 - 12))
			for i in 240:
				sim.update(1.0 / 60.0, Vector2.ZERO)
				hits += sim.fx.filter(func(f: Dictionary) -> bool: return f["type"] == "hit").size()
				fx.step(1.0 / 60.0)
				assert_true(fx._parts.size() <= Juice.WEAPON_PARTICLE_MAX and fx._trails.size() <= Juice.WEAPON_TRAIL_MAX and fx._blasts.size() <= Juice.WEAPON_BLAST_MAX, "%s %d 상한" % [id, cand])
			assert_true(hits > 0, "%s 후보 %d 맞은 자리 효과" % [id, cand])
	Weapons.fx_pick.clear()


func test_무기를_바꿔도_날아가던_탄과_폭발은_쏜_무기_수치() -> void:
	var sim := _sim("plasma")
	var fx := WeaponFx.new(sim)
	_rock(sim, Vector2(120, 0))
	for i in 120:  # 플라스마를 쏴서 날아가는 중
		sim.update(1.0 / 60.0, Vector2.ZERO)
		fx.step(1.0 / 60.0)
		if not sim.bullets.is_empty():
			break
	assert_false(sim.bullets.is_empty(), "플라스마 탄이 날아가는 중")
	sim.set_weapon("pulse")
	assert_true(WeaponFx.params_for(sim.bullets[0].style).has("orb"), "탄은 플라스마 수치로 그림")
	assert_true(WeaponFx.params_for("").has("trail"), "펄스 탄 style은 빈 글자")
	for i in 120:  # 바꾼 뒤 터져도 플라스마 폭발 수치
		sim.update(1.0 / 60.0, Vector2.ZERO)
		fx.step(1.0 / 60.0)
	assert_true(fx._blasts.all(func(b: Dictionary) -> bool: return b["p"].has("blast_time")))


func test_채굴_빔_후보_2는_부스러기도_나옴() -> void:
	Weapons.fx_pick["beam"] = 2
	var sim := _sim("beam")
	var fx := WeaponFx.new(sim)
	_rock(sim, Vector2(40, 0), 2, 1.0e6)
	var chips := 0
	for i in 120:
		sim.update(1.0 / 60.0, Vector2.ZERO)
		fx.step(1.0 / 60.0)
		chips = maxi(chips, fx._parts.filter(func(d: Array) -> bool: return Juice.CHIP_COLORS.has(d[4])).size())
	Weapons.fx_pick.clear()
	assert_true(chips > 0, "60fps에서도 광물 부스러기")
