class_name SaveData
extends RefCounted
## 기기에 남기는 진행 상황 (로컬 저장): 기지 보유 광물과 공용 업그레이드 단계.
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


func level_of(id: String) -> int:
	return int(upgrades.get(id, 0))


## 판 결과를 더한다 (음수는 무시)
func add_credits(amount: int) -> void:
	credits += maxi(amount, 0)


func to_dict() -> Dictionary:
	return {"format": FORMAT, "credits": credits, "upgrades": upgrades.duplicate()}


## 저장된 Dictionary → SaveData. 모르는 업그레이드는 버리고, 단계는 0~최대, 광물은 0 이상으로 고친다.
static func from_dict(d: Variant) -> SaveData:
	var s := SaveData.new()
	if typeof(d) != TYPE_DICTIONARY:
		return s
	s.credits = maxi(_to_int(d.get("credits", 0)), 0)
	var ups: Variant = d.get("upgrades", {})
	if typeof(ups) == TYPE_DICTIONARY:
		for u in Balance.BASE_UPGRADES:
			var lv := clampi(_to_int(ups.get(u["id"], 0)), 0, int(u["max"]))
			if lv > 0:
				s.upgrades[u["id"]] = lv
	return s


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
