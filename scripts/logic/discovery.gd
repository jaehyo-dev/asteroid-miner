class_name Discovery
extends RefCounted
## 전시관(도감): 광물 등급과 만난 적 목록. 출격 중 처음 본 것을 SaveData.seen에 기록한다.

## 도감 항목: id, 이름, 종류(mineral 광물 / enemy 적). 보여 주는 순서대로.
const ENTRIES := [
	{"id": "mineral_0", "name": "일반 광물", "kind": "mineral"},
	{"id": "mineral_1", "name": "희귀 광물", "kind": "mineral"},
	{"id": "mineral_2", "name": "영웅 광물", "kind": "mineral"},
	{"id": "mineral_3", "name": "전설 광물", "kind": "mineral"},
	{"id": "rock_0", "name": "작은 운석", "kind": "enemy"},
	{"id": "rock_1", "name": "중간 운석", "kind": "enemy"},
	{"id": "rock_2", "name": "큰 운석", "kind": "enemy"},
	{"id": "golden", "name": "황금 운석", "kind": "enemy"},
	{"id": "jelly", "name": "우주 해파리", "kind": "enemy"},
	{"id": "bug", "name": "날벌레 떼", "kind": "enemy"},
	{"id": "guard", "name": "고대 경비선", "kind": "enemy"},
	{"id": "barrage", "name": "??? 의 포격", "kind": "enemy"},
]


static func has(id: String) -> bool:
	return ENTRIES.any(func(e): return e["id"] == id)


## 적 하나의 도감 id
static func enemy_id(e: RunSim.Enemy) -> String:
	if e.golden:
		return "golden"
	if e.kind == RunSim.ROCK:
		return "rock_%d" % e.type
	return e.kind


## 이번 프레임에 화면 안(우주선 중심, view_size)에서 보인 것과 주운 광물의 도감 id 목록 (중복 없음)
static func seen_now(sim: RunSim) -> PackedStringArray:
	var ids := {}
	var view := Rect2(sim.player_pos - sim.view_size / 2.0, sim.view_size)
	for e in sim.enemies:
		if view.grow(e.radius).has_point(e.pos):
			ids[enemy_id(e)] = true
	for p in sim.picked:
		ids["mineral_%d" % p["grade"]] = true
	if sim.events.has("barrage_warning"):
		ids["barrage"] = true
	return PackedStringArray(ids.keys())
