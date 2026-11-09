extends TestCase
## 연구소 나무: 갈림길 해금·바꾸기, 잠금, 옛 저장, 새 칸 효과.


func _rich() -> SaveData:
	var s := SaveData.new()
	s.credits = 100000
	return s


func _fork_i(branch: String) -> int:
	for i in Research.tree(branch).size():
		if Research.is_fork(Research.tree(branch)[i]):
			return i
	return -1


func _sim(levels: Dictionary) -> RunSim:
	var sim := RunSim.new(1)
	sim.apply_base(levels)
	return sim


# ── 나무 ────────────────────────────────────────

func test_모든_칸_id가_정보를_가짐() -> void:
	assert_eq(Balance.RESEARCH_TREE.keys(), Balance.RESEARCH_BRANCHES)
	for branch in Balance.RESEARCH_BRANCHES:
		for node in Research.tree(branch):
			var ids: Array = [node["a"], node["b"]] if Research.is_fork(node) else [node]
			for id in ids:
				assert_false(BaseUpgrades.info(id).is_empty(), id)
				assert_true(BaseUpgrades.max_level(id) > 0, id)


func test_앞_칸을_찍어야_다음_칸이_열림() -> void:
	var s := _rich()
	assert_eq(Research.state(s, "hull", 1), "locked")
	assert_false(Research.buy(s, "hull", 1), "잠긴 칸은 못 삼")
	assert_true(Research.buy(s, "hull", 0))
	assert_eq(Research.state(s, "hull", 1), "can")


func test_옛_저장에서_앞_칸_없이_올린_칸은_잠그지_않음() -> void:
	var s := SaveData.from_dict({"credits": 9999, "upgrades": {"insurance": 2}})
	assert_eq(Research.state(s, "hull", 1), "on")
	assert_true(Research.buy(s, "hull", 1))


func test_곧_추가_칸은_못_사지만_뒤_칸을_막지_않음() -> void:
	var s := _rich()
	assert_eq(Research.state(s, "weapon", 1), "soon")
	assert_false(Research.buy(s, "weapon", 1))
	assert_eq(Research.fork_state(s, "weapon", 2, "a"), "locked", "앞 칸(공격) 안 찍음")
	assert_true(Research.buy(s, "weapon", 0))
	assert_eq(Research.fork_state(s, "weapon", 2, "a"), "can")


# ── 갈림길 ──────────────────────────────────────

func test_갈림길은_앞_칸을_찍어야_해금됨() -> void:
	var s := _rich()
	var i := _fork_i("hull")
	assert_false(Research.unlock_fork(s, "hull", i, "a"))
	assert_eq(s.credits, 100000)
	Research.buy(s, "hull", 0)
	Research.buy(s, "hull", 1)
	assert_true(Research.unlock_fork(s, "hull", i, "a"))


func test_처음_해금한_쪽이_바로_사용_중이고_다른_쪽은_따로_값을_냄() -> void:
	var s := _rich()
	var i := _fork_i("hull")
	Research.buy(s, "hull", 0)
	Research.buy(s, "hull", 1)
	var before := s.credits
	assert_true(Research.unlock_fork(s, "hull", i, "b"))
	assert_eq(s.credits, before - 500)
	assert_eq(Research.fork_state(s, "hull", i, "b"), "on")
	assert_true(Research.unlock_fork(s, "hull", i, "a"))
	assert_eq(s.credits, before - 1000)
	assert_eq(Research.fork_state(s, "hull", i, "b"), "on", "새로 해금해도 사용 중은 그대로")
	assert_eq(Research.fork_state(s, "hull", i, "a"), "idle")


func test_해금한_것끼리는_무료로_바꾸고_켜지는_건_하나() -> void:
	var s := _rich()
	var i := _fork_i("hull")
	Research.buy(s, "hull", 0)
	Research.buy(s, "hull", 1)
	assert_false(Research.swap_fork(s, "hull", i, "b"), "해금 전에는 못 바꿈")
	Research.unlock_fork(s, "hull", i, "a")
	Research.unlock_fork(s, "hull", i, "b")
	var before := s.credits
	assert_true(Research.swap_fork(s, "hull", i, "b"))
	assert_eq(s.credits, before, "바꾸기는 무료")
	var levels := Research.run_levels(s)
	assert_true(levels.has("dodge"))
	assert_false(levels.has("thick"), "꺼진 쪽 효과 없음")


func test_광물이_모자라면_해금_못함() -> void:
	var s := SaveData.new()
	s.upgrades = {"max_hp": 1, "insurance": 1}
	s.credits = 499
	var i := _fork_i("hull")
	assert_eq(Research.fork_state(s, "hull", i, "a"), "poor")
	assert_false(Research.unlock_fork(s, "hull", i, "a"))
	assert_eq(s.credits, 499)


func test_갈림길과_새_칸이_저장되고_옛_저장은_그대로_읽힘() -> void:
	var s := _rich()
	var i := _fork_i("hull")
	s.upgrades = {"max_hp": 1, "insurance": 1, "repair": 1, "shield": 3}
	Research.unlock_fork(s, "hull", i, "a")
	Research.unlock_fork(s, "hull", i, "b")
	Research.swap_fork(s, "hull", i, "b")
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.forks_owned, {"thick_dodge": "ab"})
	assert_eq(back.forks_on, {"thick_dodge": "b"})
	assert_eq(back.level_of("repair"), 1)
	assert_eq(back.level_of("shield"), 3)
	var old := SaveData.from_dict({"credits": 10, "upgrades": {"damage": 5}})
	assert_eq(old.forks_owned.size(), 0)
	assert_eq(old.level_of("damage"), 5)


func test_이상한_갈림길_저장값은_고쳐_읽음() -> void:
	var s := SaveData.from_dict({"forks_owned": {"thick_dodge": "a", "nope_x": "a", "rapid_heavy": 7}, "forks_on": {"thick_dodge": "b"}})
	assert_eq(s.forks_owned, {"thick_dodge": "a"})
	assert_eq(s.forks_on, {"thick_dodge": "a"}, "해금 안 한 쪽은 사용 중일 수 없음")
	assert_eq(SaveData.from_dict({"forks_owned": "x", "forks_on": 3}).forks_owned.size(), 0)


# ── 새 칸 효과 ───────────────────────────────────

func test_연사형과_한_방형() -> void:
	var plain := _sim({})
	var rapid := _sim({"rapid": 1})
	var heavy := _sim({"heavy": 1})
	assert_true(is_equal_approx(rapid.fire_interval, plain.fire_interval / 1.15))
	assert_true(is_equal_approx(rapid.bullet_damage, plain.bullet_damage * 0.95))
	assert_true(is_equal_approx(heavy.fire_interval, plain.fire_interval / 0.85))
	assert_true(is_equal_approx(heavy.bullet_damage, plain.bullet_damage * 1.25))


func test_중장갑과_회피형() -> void:
	var plain := _sim({})
	var thick := _sim({"thick": 1})
	assert_eq(thick.max_hp, plain.max_hp + 30.0)
	assert_eq(thick.hp, thick.max_hp)
	assert_true(is_equal_approx(thick.move_speed, plain.move_speed - Balance.SHIP_SPEED * 0.05))
	var dodge := _sim({"dodge": 1})
	dodge.damage_player(1.0)
	plain.damage_player(1.0)
	assert_true(is_equal_approx(dodge.invuln, plain.invuln + 0.3))


func test_넓게_끌기() -> void:
	assert_true(is_equal_approx(_sim({"wide": 1}).magnet_radius, Balance.MAGNET_RADIUS * 1.4))


func test_빨리_나르기는_끌리는_광물이_더_빠름() -> void:
	var a := _sim({})
	var b := _sim({"fast": 1})
	for sim: RunSim in [a, b]:
		sim.player_pos = Vector2.ZERO
		var m := sim.drop_mineral(Vector2(sim.magnet_radius - 1.0, 0.0))
		m.attracted = true
		sim._update_minerals(0.02)
	assert_true(b.minerals[0].pos.x < a.minerals[0].pos.x)


func test_과부하_탄두는_5발째가_2배() -> void:
	var sim := _sim({"over": 1})
	sim.spawn_asteroid()
	var target := sim.enemies[0]
	target.pos = sim.player_pos + Vector2(40, 0)
	target.vel = Vector2.ZERO
	target.hp = 1000000.0
	var seen: Array[float] = []
	for i in 5:
		sim._fire_timer = 0.0
		sim.bullets.clear()
		sim._auto_fire(0.0)
		seen.append(sim.bullets[0].damage)
	assert_eq(seen[0], sim.bullet_damage)
	assert_eq(seen[3], sim.bullet_damage)
	assert_eq(seen[4], sim.bullet_damage * 2.0)


func test_긴급_수리는_위험할_때_판마다_한_번() -> void:
	var sim := _sim({"repair": 1})
	sim.damage_player(sim.max_hp * 0.8)
	assert_true(is_equal_approx(sim.hp, sim.max_hp * 0.5), "20%% → 50%%: %f" % sim.hp)
	sim.invuln = 0.0
	sim.damage_player(sim.max_hp * 0.4)
	assert_true(is_equal_approx(sim.hp, sim.max_hp * 0.1), "두 번째는 없음")
	var plain := _sim({})
	plain.damage_player(plain.max_hp * 0.8)
	assert_true(is_equal_approx(plain.hp, plain.max_hp * 0.2))


func test_편향_실드는_단계만큼_막음() -> void:
	var sim := _sim({"shield": 2})
	for i in 2:
		sim.invuln = 0.0
		sim.damage_player(10.0)
		assert_eq(sim.hp, sim.max_hp, "막음 %d" % i)
	sim.invuln = 0.0
	sim.damage_player(10.0)
	assert_eq(sim.hp, sim.max_hp - 10.0)


func test_실드_충전은_60초마다_1번() -> void:
	var sim := _sim({"bolt": 1})
	assert_eq(sim.blocks_left, 0)
	sim._update_shield(59.0)
	assert_eq(sim.blocks_left, 0)
	sim._update_shield(1.0)
	assert_eq(sim.blocks_left, 1)
	sim._update_shield(60.0)
	assert_eq(sim.blocks_left, 1, "실드 칸이 없으면 1번까지")


func test_재추첨_회로는_다시_뽑기를_늘림() -> void:
	assert_eq(_sim({"reroll": 3}).rerolls_left, Balance.REROLLS_PER_RUN + 3)
	assert_eq(_sim({}).rerolls_left, Balance.REROLLS_PER_RUN)


func test_고급_회로는_에픽을_늘리고_합은_같음() -> void:
	var plain := Upgrades.grade_weights(0.0)
	var chip := Upgrades.grade_weights(0.0, 0.03)
	var total := 0.0
	for v in plain:
		total += v
	assert_true(is_equal_approx(chip[Upgrades.EPIC], plain[Upgrades.EPIC] + total * 0.03))
	assert_true(is_equal_approx(chip[Upgrades.NORMAL], plain[Upgrades.NORMAL] - total * 0.03))


func test_행운_코어는_가끔_카드가_한_장_더() -> void:
	var sim := _sim({"luck": 1})
	var extra := 0
	for i in 200:
		sim._roll_choices()
		assert_true(sim.choices.size() >= Balance.UPGRADE_CHOICE_COUNT)
		if sim.choices.size() > Balance.UPGRADE_CHOICE_COUNT:
			extra += 1
	assert_true(extra > 3 and extra < 60, "한 장 더 %d번" % extra)


func test_감정기는_최종_가치를_올림() -> void:
	var a := _sim({})
	var b := _sim({"appraise": 5})
	for sim: RunSim in [a, b]:
		sim.time = 0.0
		for i in 20:
			sim.cargo.add(3)
	assert_true(is_equal_approx(float(b.final_value()), roundf(a.final_value() * 1.15)))


func test_탐지기와_심부_스캔은_등급을_올림() -> void:
	var sim := _sim({"radar": 5, "deep": 1})
	var up0 := 0
	var up2 := 0
	for i in 4000:
		up0 += 1 if sim.rolled_grade(0) == 1 else 0
		up2 += 1 if sim.rolled_grade(2) == 3 else 0
		assert_eq(sim.rolled_grade(3), 3, "전설은 그대로")
	assert_true(up0 > 120 and up0 < 300, "희귀 %d" % up0)
	assert_true(up2 > 40 and up2 < 130, "전설 %d" % up2)
	assert_eq(_sim({}).rolled_grade(0), 0)


func test_정밀_드릴은_운석에서_가끔_더_떨어뜨림() -> void:
	var extra := func(levels: Dictionary) -> int:
		var sim := _sim(levels)
		sim.rng.seed = 7
		for i in 300:
			var a: RunSim.Enemy = sim.spawn_asteroid()
			sim.enemies.erase(a)
			sim._on_enemy_destroyed(a)
		return sim.fx.filter(func(f: Dictionary) -> bool: return f["type"] == "drop_extra").size()
	assert_eq(int(extra.call({})), 0)
	var n: int = extra.call({"drill": 1})
	assert_true(n > 10 and n < 60, "더 떨어진 판 %d" % n)


func test_광역_스캔은_황금_운석을_앞당김() -> void:
	var sim := _sim({"wide_scan": 1})
	assert_true(is_equal_approx(sim.next_golden_gap(), _sim({}).next_golden_gap() * 0.8))


func test_글자_나누기는_폭이_0이어도_멈춤() -> void:
	assert_true(WindowArt.wrap("광물이 모자라요", 0).size() > 0)
	assert_true(WindowArt.wrap("광물이 모자라요", -40).size() > 0)
	assert_eq(WindowArt.wrap("", 100).size(), 0)


# ── 배치와 관 연결 ───────────────────────────────

const SCREENS := [Vector2i(540, 292), Vector2i(350, 159), Vector2i(620, 340)]


func _save_mid() -> SaveData:
	var s := _rich()
	s.upgrades = {"max_hp": 1, "insurance": 1, "repair": 1, "damage": 1}
	s.forks_owned = {"thick_dodge": "ab"}
	s.forks_on = {"thick_dodge": "b"}
	return s


func test_격자_대칭_직각() -> void:
	for sz: Vector2i in SCREENS:
		for b: String in Balance.RESEARCH_BRANCHES:
			var lay := ResearchLayout.compute(b, sz.x, sz.y)
			var cx: int = lay["cx"]
			assert_eq(cx, sz.x / 2)
			for k: String in lay["cells"]:
				var c: Vector2i = lay["cells"][k]
				assert_eq((c.x - cx) % ResearchLayout.CELL, 0, "세로줄 %s" % k)
				assert_eq((int(lay["base"]) - c.y) % ResearchLayout.CELL, 0, "가로줄 %s" % k)
				if k.right(1) == "a":
					var o: Vector2i = lay["cells"][k.left(-1) + "b"]
					assert_eq(o.y, c.y, "갈림길 같은 높이")
					assert_eq(cx - c.x, o.x - cx, "갈림길 대칭")
			for l: Dictionary in ResearchLayout.links(b, lay):
				var pts: Array = l["pts"]
				for j in pts.size() - 1:
					assert_true(pts[j].x == pts[j + 1].x or pts[j].y == pts[j + 1].y, "직각")


func test_모든_칸은_위아래_소켓으로_이어짐() -> void:
	for sz: Vector2i in SCREENS:
		for b: String in Balance.RESEARCH_BRANCHES:
			var lay := ResearchLayout.compute(b, sz.x, sz.y)
			assert_eq(ResearchLayout.broken(b, lay, ResearchLayout.links(b, lay)), [], "%s %s" % [b, sz])


func test_끊긴_관은_검사가_잡아냄() -> void:
	var lay := ResearchLayout.compute("hull", 540, 292)
	var full := ResearchLayout.links("hull", lay)
	for i in full.size():  # 관을 하나씩 빼면 어느 것이든 실패해야 한다
		var cut := full.duplicate()
		cut.remove_at(i)
		assert_true(ResearchLayout.broken("hull", lay, cut).size() > 0, "관 %d을 빼도 통과함" % i)


func test_글자가_관과_다른_칸을_덮지_않음() -> void:
	for sz: Vector2i in SCREENS:
		for b: String in Balance.RESEARCH_BRANCHES:
			var lay := ResearchLayout.compute(b, sz.x, sz.y)
			for k: String in lay["cells"]:
				var label := ResearchLayout.label_rect(k, lay, _label_w(b, k))
				assert_true(label.position.x >= 0 and label.end.x <= sz.x - 6, "%s %s 판 밖 %s" % [b, k, label])
				for o: String in lay["cells"]:
					if o != k:
						assert_false(label.intersects(ResearchLayout.cell_rect(o, lay)), "%s %s가 %s를 덮음" % [b, k, o])
				for l: Dictionary in ResearchLayout.links(b, lay):
					var pts: Array = l["pts"]
					for j in pts.size() - 1:
						var box := Rect2i(pts[j].min(pts[j + 1]) - Vector2i(4, 4), (pts[j] - pts[j + 1]).abs() + Vector2i(8, 8))
						assert_false(label.intersects(box), "%s %s 글자가 관을 덮음" % [b, k])


func _label_w(b: String, k: String) -> int:
	var node: Variant = Research.tree(b)[k.to_int()]
	return WindowArt.width(Research.name_of(node, k.right(1)) if Research.is_fork(node) else Research.name_of(node))


func test_사용_중인_쪽으로만_빛이_이어져_위_칸까지_감() -> void:
	var s := _save_mid()
	var lay := ResearchLayout.compute("hull", 540, 292)
	var runs := ResearchLayout.routes(ResearchLayout.tiers(s, "hull", lay))
	assert_eq(runs.size(), 1, "끊기지 않음")
	var run: Array = runs[0]
	assert_true(run.has(lay["cells"]["2b"]), "사용 중인 오른쪽")
	assert_false(run.has(lay["cells"]["2a"]), "꺼진 왼쪽은 안 지남")
	assert_eq(run[-1], lay["cells"]["3c"], "위 칸까지")
	s.forks_on["thick_dodge"] = "a"
	var run2: Array = ResearchLayout.routes(ResearchLayout.tiers(s, "hull", lay))[0]
	assert_true(run2.has(lay["cells"]["2a"]), "바꾸면 흐름이 옮겨 감")


func test_PC_설명_창은_다른_칸을_가리지_않고_누른_칸도_안_가림() -> void:
	for b: String in Balance.RESEARCH_BRANCHES:
		var lay := ResearchLayout.compute(b, 540, 292)
		var avoid := {}
		for k: String in lay["cells"]:
			avoid[k] = [ResearchLayout.cell_rect(k, lay), ResearchLayout.label_rect(k, lay, _label_w(b, k) + 8)]
		for pan: int in [0, lay["max_pan"]]:
			for k: String in lay["cells"]:
				var at := ResearchLayout.popup_pos(k, Vector2i(156, 140), lay, avoid, 540, 292, pan, 6)
				assert_eq(at[2], 0, "%s %s 끌기 %d" % [b, k, pan])
				var box := Rect2i(at[0], at[1], 156, 140)
				var mine := ResearchLayout.cell_rect(k, lay)
				assert_false(box.intersects(Rect2i(mine.position + Vector2i(0, pan), mine.size)), "누른 칸 %s" % k)


# ── 창 배율 ─────────────────────────────────────

func test_창_배율은_정수이고_폰은_2배() -> void:
	assert_eq(BaseWindow.scale_for(Vector2i(1280, 720), 1.0), 2)
	assert_eq(BaseWindow.scale_for(Vector2i(1920, 1080), 1.0), 3)
	assert_eq(BaseWindow.scale_for(Vector2i(844, 390), 1.0), 2)
	assert_eq(BaseWindow.scale_for(Vector2i(2532, 1170), 3.0), 6)
	assert_true(BaseWindow.is_compact(Vector2i(422, 195)))
	assert_false(BaseWindow.is_compact(Vector2i(640, 360)))


func test_폰에서_고른_칸이_띠_위로_보임() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	var w: BaseWindow = main.panel
	w.open("research")
	await wait_frames()
	var v: ResearchView = w.view
	v.win.compact = true
	v._board_size = Vector2i(350, 159)
	v._select_branch("hull")
	v.select_cell("0c")
	assert_eq(v._pan_target, v._board_size.y - ResearchView.STRIP_H - 26 - int(v.lay["cells"]["0c"].y), "맨 아래 칸을 띠 위로")
	assert_true(v.lay["cells"]["0c"].y + v._pan_target + 26 <= v._board_size.y - ResearchView.STRIP_H)
	main.queue_free()


# ── 강화 소리, 강화 소리 시험, focus 표시, 빛기둥 ─────────────

func test_강화_소리_후보는_평소_버튼이_없고_시험에서_차례로_돎() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	assert_true(main.hud.test_buttons.is_empty(), "정식 화면에는 없음")
	main.enable_upgrade_test()
	assert_eq(main.hud.test_buttons.size(), 3)
	var up: Button = main.hud.test_buttons[0]
	for i in Sfx.UPGRADE_SOUNDS.size():
		up.pressed.emit()
	assert_eq(main._upgrade_i, 0, "한 바퀴 돌면 처음으로")
	assert_true(main.toast.text.contains(Sfx.UPGRADE_SOUNDS[0]["name"]))
	main.hud.test_buttons[1].pressed.emit()
	assert_true(main.toast.text.contains(Sfx.MAX_SOUNDS[1]["name"]))
	var before: int = main.save.credits
	main.hud.test_buttons[2].pressed.emit()
	assert_eq(main.save.credits, before + main.TEST_CREDITS, "광물을 넣어 줌")
	for b: Button in main.hud.test_buttons:
		assert_true(main.hud.hits_button(b.position + Vector2.ONE), "눌러도 끌기가 아님")
	for s: Dictionary in Sfx.UPGRADE_SOUNDS + Sfx.MAX_SOUNDS:
		assert_not_null(load(Sfx.SFX_DIR + s["file"] + ".wav"), s["name"])
	for s: Dictionary in Sfx.UPGRADE_SOUNDS:
		var e3: AudioStreamWAV = load(Sfx.SFX_DIR + "card_pick.wav")
		assert_true((load(Sfx.SFX_DIR + s["file"] + ".wav") as AudioStreamWAV).get_length() < e3.get_length(), "%s e3보다 짧음" % s["name"])
	Sfx.use_sound("upgrade", "upgrade_1")  # 다른 테스트에 영향 없게 기본으로
	Sfx.use_sound("upgrade_max", "upgrade_max_1")
	main.save.credits = before
	main.queue_free()


func test_만렙_강화는_번쩍일_때_울림을_내고_광물_부족은_툭() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.auto_start = false
	add_child(main)
	await wait_frames()
	var save: SaveData = main.save
	var old_credits := save.credits
	var old_upgrades := save.upgrades.duplicate()
	var w: BaseWindow = main.panel
	w.open("research")
	await wait_frames()
	var v: ResearchView = w.view
	v._select_branch("hull")
	var id: String = Research.tree("hull")[0]
	save.upgrades[id] = BaseUpgrades.max_level(id) - 1
	save.credits = 0
	v.select_cell("0c")
	assert_eq(v.action_info()["note"], "광물이 모자라요")
	v._on_denied()  # 꺼진 버튼을 누름
	assert_true(Sfx.pool("deny").any(func(p: AudioStreamPlayer) -> bool: return p.playing), "광물 부족 툭")
	save.credits = 1000000
	v.act()
	assert_eq(v._flash_i, 0, "맨 아래 칸은 빛이 달리지 않고 바로 번쩍")
	assert_false(v._max_pending)
	assert_true(Sfx.pool("upgrade_max").any(func(p: AudioStreamPlayer) -> bool: return p.playing), "번쩍일 때 만렙 울림")
	save.credits = old_credits
	save.upgrades = old_upgrades
	save.save_file()
	main.queue_free()


func test_모든_버튼의_focus_테두리가_비어_있음() -> void:
	var b := Button.new()
	add_child(b)
	assert_true(b.get_theme_stylebox("focus") is StyleBoxEmpty)
	b.queue_free()


func test_빛기둥은_무작위_없이_띠로_옅어지고_위로_좁아지며_팔레트만_씀() -> void:
	var palette := PackedStringArray(["125952", "1da775", "30e1b9", "355148", "3c3544"])
	for style in HangarView.BEAM_STYLES.size():
		var img := HangarView.bake_beam(34, 100, 16, style)
		var name: String = HangarView.BEAM_STYLES[style]["name"]
		assert_true(img.get_data() == HangarView.bake_beam(34, 100, 16, style).get_data(), "%s 매번 같음" % name)
		var widths: Array[int] = []
		for y in 100:
			var n := 0
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					assert_true(palette.has(c.to_html(false)), "%s void32 색만" % name)
					n += 1
			widths.append(n)
		assert_eq(widths[0], 0, "%s 윗변 없이 사라짐" % name)
		assert_true(widths[30] < widths[95], "%s 위로 좁아짐" % name)
		# 가운데 열을 같은 체크 칸끼리(2줄 간격) 보며 아래에서 위로 띠 순서(진함 → 옅음 → 투명)를 거꾸로 가지 않음
		var order: Array = HangarView.BEAM_STYLES[style]["bands"].map(func(b: Array) -> String: return b[1].trim_prefix("#"))
		var prev := 0
		for y in range(98, 0, -2):
			var c := img.get_pixel(33, y)
			var r := order.size() if c.a == 0.0 else order.find(c.to_html(false))
			assert_true(r >= prev, "%s 위로 갈수록 옅어짐 (y=%d)" % [name, y])
			prev = r
		assert_eq(prev, order.size(), "%s 맨 위는 투명" % name)
	assert_true(HangarView.bake_beam(34, 100, 16).get_pixel(1, 115).a == 0.0, "아래는 타원 호 따라 끝남")
