extends TestCase
## 옛 저장 파일(v0.6.x, v0.7.0 초기)을 지금 게임이 읽어도 강화 단계·광물·도감이 그대로인지. 저장 파일 경로를 바꿔 실제 파일로 확인한다.

const V066 := {"format": 1, "credits": 12345, "upgrades": {"damage": 4, "max_hp": 3, "speed": 2, "cargo": 1, "insurance": 2, "magnet": 5},
	"risk_tip_seen": true, "hauled": [300, 80, 12, 1], "seen": ["mineral_0", "mineral_1", "rock_0"]}
const V070_EARLY := {"format": 1, "credits": 780, "upgrades": {"damage": 3, "max_hp": 5, "insurance": 2, "magnet": 1},
	"risk_tip_seen": true, "warp_seen": true, "drag_hint_seen": true, "hauled": [412, 96, 23, 3], "seen": ["mineral_0", "mineral_1", "mineral_2"], "codex_claimed": ["at3"]}


func _load_as_file(d: Dictionary) -> SaveData:
	var old_path := SaveData.path
	SaveData.path = "user://test_old_save.json"
	var f := FileAccess.open(SaveData.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var s := SaveData.load_file()
	s.save_file()  # 지금 게임이 다시 저장해도
	var again := SaveData.load_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	SaveData.path = old_path
	assert_eq(again.to_dict(), s.to_dict(), "다시 저장해도 같음")
	return again


func _check(d: Dictionary, s: SaveData) -> void:
	assert_eq(s.credits, d["credits"], "광물 그대로")
	for id: String in d["upgrades"]:
		assert_eq(s.level_of(id), d["upgrades"][id], "강화 단계 그대로: " + id)
		assert_eq(Research.run_levels(s).get(id, 0), d["upgrades"][id], "출격 적용도 그대로: " + id)
	assert_eq(Array(s.hauled), d["hauled"])
	assert_eq(s.seen.size(), d["seen"].size())
	assert_true(s.forks_owned.is_empty() and s.forks_on.is_empty(), "갈림길은 새로 시작")


func test_v066_저장() -> void:
	var s := _load_as_file(V066)
	_check(V066, s)
	assert_true(s.codex_claimed.is_empty())


func test_v070_초기_저장() -> void:
	var s := _load_as_file(V070_EARLY)
	_check(V070_EARLY, s)
	assert_eq(s.codex_claimed.keys(), ["at3"], "받은 도감 보상 유지 (두 번 못 받음)")
	assert_false(Discovery.claim(s, "at3"))
