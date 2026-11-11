class_name SaveData
extends RefCounted
## 기기에 남기는 진행 상황 (로컬 저장): 기지 보유 광물, 공용 업그레이드 단계, 가져온 광물 수, 도감.
## 웹에서는 user://가 브라우저 저장소(IndexedDB)에 저장된다.
## 파일이 없거나 깨졌거나 값이 이상하면 안전한 값으로 고쳐서 읽는다 (게임이 멈추지 않게).

## 저장 형식 번호. 형식이 호환되지 않게 바뀌면 올리고 from_dict에서 옮겨 준다.
const FORMAT := 1
## 저장 파일 위치 (테스트는 다른 파일로 바꿔서 실제 저장을 건드리지 않는다)
static var path := "user://save.json"

## 기지 보유 광물 (판이 끝날 때 가져온 최종 가치가 쌓인다)
var credits := 0
## 공용 업그레이드 id → 단계
var upgrades: Dictionary = {}
## 광물 보너스 말풍선을 이미 봤는지 (한 번만 보여 준다)
var risk_tip_seen := false
## 워프 출격 연출을 끝까지 본 적이 있는지 (두 번째 출격부터 눌러서 건너뛸 수 있다)
var warp_seen := false
## "드래그로 둘러보기" 안내를 본 적이 있는지
var drag_hint_seen := false
## 지금까지 기지로 가져온 광물 수 (등급별 누적, 광물 창고에 보여 줌. v0.6.0부터 셈)
var hauled := PackedInt32Array([0, 0, 0, 0])
## 도감: 처음 본 것 id → true (Discovery.ENTRIES의 id)
var seen: Dictionary = {}
## 도감 보상: 받은 보상 id → true (Balance.CODEX_REWARDS의 id). 지점별로 남겨 두 번 받지 않는다
var codex_claimed: Dictionary = {}
## 갈림길: 갈림길 id → 해금한 쪽("a", "b", "ab") / 사용 중인 쪽("a", "b")
var forks_owned: Dictionary = {}
var forks_on: Dictionary = {}
## 장착한 기본 무기 id (Balance.WEAPONS). 출격하면 이 무기로 시작한다 (v0.8.0)
var weapon := "pulse"
## 격납고에서 산 기본 무기 id 목록 (처음부터 있는 펄스 연사포는 넣지 않음)
var weapons_owned: Array = []


func level_of(id: String) -> int:
	return int(upgrades.get(id, 0))


## 판 결과를 더한다 (음수는 무시)
func add_credits(amount: int) -> void:
	credits += maxi(amount, 0)


func to_dict() -> Dictionary:
	return {"format": FORMAT, "credits": credits, "upgrades": upgrades.duplicate(), "risk_tip_seen": risk_tip_seen, "warp_seen": warp_seen, "drag_hint_seen": drag_hint_seen,
		"hauled": Array(hauled), "seen": seen.keys(), "codex_claimed": codex_claimed.keys(), "forks_owned": forks_owned.duplicate(), "forks_on": forks_on.duplicate(), "weapon": weapon, "weapons_owned": weapons_owned.duplicate()}


## 판에서 가져온 광물(등급별 개수)을 누적한다
func add_hauled(counts: PackedInt32Array) -> void:
	for i in mini(counts.size(), hauled.size()):
		hauled[i] += maxi(counts[i], 0)


## 도감에 처음 본 것을 기록한다. 새로 기록했으면 true.
func discover(id: String) -> bool:
	if seen.has(id) or not Discovery.has(id):
		return false
	seen[id] = true
	return true


## 저장된 Dictionary → SaveData. 모르는 업그레이드는 버리고, 단계는 0~최대, 광물은 0 이상으로 고친다.
static func from_dict(d: Variant) -> SaveData:
	var s := SaveData.new()
	if typeof(d) != TYPE_DICTIONARY:
		return s
	s.credits = maxi(_to_int(d.get("credits", 0)), 0)
	var hauled: Variant = d.get("hauled", [])
	if typeof(hauled) == TYPE_ARRAY:
		for i in mini(hauled.size(), s.hauled.size()):
			s.hauled[i] = maxi(_to_int(hauled[i]), 0)
	var seen: Variant = d.get("seen", [])
	if typeof(seen) == TYPE_ARRAY:
		for id in seen:
			if typeof(id) == TYPE_STRING:
				s.discover(id)  # 모르는 id는 버린다
	var claimed: Variant = d.get("codex_claimed", [])
	if typeof(claimed) == TYPE_ARRAY:
		for id in claimed:
			if typeof(id) == TYPE_STRING and not Discovery.reward_info(id).is_empty():  # 모르는 id는 버린다
				s.codex_claimed[id] = true
	var tip: Variant = d.get("risk_tip_seen", false)
	s.risk_tip_seen = typeof(tip) == TYPE_BOOL and tip  # 참/거짓이 아니면 안 본 것으로
	var warp: Variant = d.get("warp_seen", false)
	s.warp_seen = typeof(warp) == TYPE_BOOL and warp
	var hint: Variant = d.get("drag_hint_seen", false)
	s.drag_hint_seen = typeof(hint) == TYPE_BOOL and hint
	var ups: Variant = d.get("upgrades", {})
	if typeof(ups) == TYPE_DICTIONARY:
		for list in [Balance.BASE_UPGRADES, Balance.RESEARCH_NODES]:
			for u in list:
				var lv := clampi(_to_int(ups.get(u["id"], 0)), 0, int(u["max"]))
				if lv > 0:
					s.upgrades[u["id"]] = lv
	s._read_forks(d.get("forks_owned", {}), d.get("forks_on", {}))
	# 산 무기: 모르는 id·중복은 버린다. 예전(2단계) 저장은 연구소 칸 "w_<무기>"으로 해금했으니 산 것으로 옮긴다
	var owned: Variant = d.get("weapons_owned", [])
	for id in Weapons.ids():
		var old: Variant = ups.get("w_" + id, 0) if typeof(ups) == TYPE_DICTIONARY else 0
		if Weapons.cost(id) > 0 and ((typeof(owned) == TYPE_ARRAY and owned.has(id)) or _to_int(old) > 0):
			s.weapons_owned.append(id)
	var wp: Variant = d.get("weapon", "pulse")
	s.weapon = wp if typeof(wp) == TYPE_STRING and Weapons.has(wp) else "pulse"  # 모르는 무기는 기본 무기로 (해금 여부는 Weapons.equipped가 본다)
	return s


## 갈림길 저장값 고치기: 모르는 갈림길·이상한 값은 버리고, 사용 중인 쪽은 해금한 쪽이어야 한다 (없으면 처음 쪽)
func _read_forks(own: Variant, on: Variant) -> void:
	if typeof(own) != TYPE_DICTIONARY:
		return
	for branch in Balance.RESEARCH_TREE:
		for node in Balance.RESEARCH_TREE[branch]:
			if typeof(node) != TYPE_DICTIONARY:
				continue
			var key := "%s_%s" % [node["a"], node["b"]]
			var sides: Variant = own.get(key, "")
			if not sides in ["a", "b", "ab"]:
				continue
			forks_owned[key] = sides
			var pick: Variant = on.get(key, "") if typeof(on) == TYPE_DICTIONARY else ""
			forks_on[key] = pick if pick in ["a", "b"] and sides.contains(pick) else sides.substr(0, 1)


## JSON 숫자는 float로 읽히므로 int로 바꾼다. 숫자가 아니면 0.
static func _to_int(v: Variant) -> int:
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0


## 파일에서 읽는다. 없거나 깨졌으면 새 저장.
static func load_file() -> SaveData:
	if not FileAccess.file_exists(path):
		return SaveData.new()
	var json := JSON.new()  # JSON.parse_string과 달리 깨진 내용에도 오류를 찍지 않는다
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return SaveData.new()
	return from_dict(json.data)


## 파일에 쓴다. 성공하면 true.
func save_file() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("저장 실패: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true
