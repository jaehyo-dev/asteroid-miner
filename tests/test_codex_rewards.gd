extends TestCase
## 전시관 도감 보상: 조건, 두 번 받기 방지, 옛 저장 호환, 출격 능력치 적용.


func _saw(save: SaveData, count: int) -> void:
	for i in count:
		save.discover(Discovery.ENTRIES[i]["id"])


func test_조건이_안_되면_못_받음() -> void:
	var save := SaveData.new()
	_saw(save, 2)
	assert_false(Discovery.claim(save, "at3"))
	assert_eq(save.credits, 0)
	_saw(save, 3)
	assert_true(Discovery.claim(save, "at3"))
	assert_eq(save.credits, 150)


func test_같은_보상은_두_번_못_받음() -> void:
	var save := SaveData.new()
	_saw(save, 9)
	assert_true(Discovery.claim(save, "at9"))
	assert_false(Discovery.claim(save, "at9"))
	assert_eq(save.credits, 400)
	var loaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_false(Discovery.claim(loaded, "at9"), "저장했다 불러와도 못 받음")
	assert_eq(loaded.credits, 400)


func test_모르는_보상은_거절() -> void:
	var save := SaveData.new()
	_saw(save, 12)
	assert_false(Discovery.claim(save, "nope"))


func test_전부_찾아야_도색을_받음() -> void:
	var save := SaveData.new()
	_saw(save, Discovery.ENTRIES.size() - 1)
	assert_false(Discovery.claim(save, "all"))
	_saw(save, Discovery.ENTRIES.size())
	assert_true(Discovery.claim(save, "all"))
	assert_eq(Discovery.bonus(save, "paint"), 1.0)


func test_옛_저장은_받은_보상_없이_그대로_읽힘() -> void:
	var old := {"format": 1, "credits": 500, "upgrades": {"damage": 2}, "seen": ["mineral_0"], "hauled": [1, 2, 3, 4]}
	var save := SaveData.from_dict(old)
	assert_eq(save.credits, 500)
	assert_eq(save.level_of("damage"), 2)
	assert_eq(save.codex_claimed.size(), 0)


func test_이상한_저장값은_버림() -> void:
	assert_eq(SaveData.from_dict({"codex_claimed": "x"}).codex_claimed.size(), 0)
	assert_eq(SaveData.from_dict({"codex_claimed": ["at3", 7, "nope"]}).codex_claimed.keys(), ["at3"])


func test_이동_속도와_보존_보상이_출격에_적용됨() -> void:
	var save := SaveData.new()
	_saw(save, 12)
	var plain := RunSim.new(1)
	plain.apply_base({"insurance": 5})
	plain.apply_codex(save)
	var base_speed := plain.move_speed
	var base_keep := plain.keep_ratio()
	assert_true(Discovery.claim(save, "at6"))
	assert_true(Discovery.claim(save, "at12"))
	var sim := RunSim.new(1)
	sim.apply_base({"insurance": 5})
	sim.apply_codex(save)
	assert_true(is_equal_approx(sim.move_speed, base_speed + Balance.SHIP_SPEED * 0.02), "이동 속도 +2%")
	assert_true(is_equal_approx(sim.keep_ratio(), base_keep + 0.03), "최대 단계여도 보존 +3%")
	sim.apply_upgrades()
	assert_true(is_equal_approx(sim.move_speed, base_speed + Balance.SHIP_SPEED * 0.02), "다시 계산해도 유지")
