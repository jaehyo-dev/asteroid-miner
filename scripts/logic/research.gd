class_name Research
extends RefCounted
## 연구소 나무 규칙: 칸 상태, 강화, 갈림길 해금·바꾸기, 출격에 넘길 단계 표. 화면과 분리해 테스트한다.
## 나무는 Balance.RESEARCH_TREE, 새 칸 수치는 Balance.RESEARCH_NODES에 있다. 칸 번호 i는 나무 안 순서.


static func tree(branch: String) -> Array:
	return Balance.RESEARCH_TREE[branch]


static func is_fork(node: Variant) -> bool:
	return typeof(node) == TYPE_DICTIONARY


static func fork_id(node: Dictionary) -> String:
	return "%s_%s" % [node["a"], node["b"]]


## 칸 이름. 갈림길은 side("a"/"b")로 고른다
static func name_of(node: Variant, side := "") -> String:
	return BaseUpgrades.info(node[side] if is_fork(node) else node)["name"]


static func is_soon(id: String) -> bool:
	return bool(BaseUpgrades.info(id).get("soon", false))


## 앞 칸을 지났는지: 1단계 이상 연구함(갈림길은 한쪽 이상 해금). "곧 추가" 칸은 찍을 수 없으니 지나지 못한다 →
## 그 위 칸들도 모두 잠긴다 (2026-11-12 사용자 결정, 모든 가지 같은 규칙)
static func _passed(save: SaveData, branch: String, i: int) -> bool:
	if i < 0:
		return true
	var node: Variant = tree(branch)[i]
	if is_fork(node):
		return not owned(save, node).is_empty()
	if is_soon(node):
		return false
	return save.level_of(node) > 0


static func is_open(save: SaveData, branch: String, i: int) -> bool:
	return _passed(save, branch, i - 1)


## 칸 상태: soon, max, locked(앞 칸 안 찍음), on(찍음, 더 올릴 수 있음), can, poor(광물 부족).
## 옛 저장에서 앞 칸 없이 올린 칸은 잠그지 않는다
static func state(save: SaveData, branch: String, i: int) -> String:
	var id: String = tree(branch)[i]
	if is_soon(id):
		return "soon"
	var lv := save.level_of(id)
	if lv >= BaseUpgrades.max_level(id):
		return "max"
	if lv > 0:
		return "on"
	if not is_open(save, branch, i):
		return "locked"
	return "can" if BaseUpgrades.can_buy(save, id) else "poor"


## 한 단계 강화. 앞 칸이 막혔거나 광물이 모자라면 false
static func buy(save: SaveData, branch: String, i: int) -> bool:
	if state(save, branch, i) in ["soon", "max", "locked"]:
		return false
	return BaseUpgrades.buy(save, tree(branch)[i])


# ── 갈림길 ────────────────────────────────────────

## 해금한 쪽들: "", "a", "b", "ab"
static func owned(save: SaveData, node: Dictionary) -> String:
	return String(save.forks_owned.get(fork_id(node), ""))


## 사용 중인 쪽: "", "a", "b"
static func active(save: SaveData, node: Dictionary) -> String:
	return String(save.forks_on.get(fork_id(node), ""))


## 갈림길 한쪽 상태: on 사용 중, idle 해금했지만 꺼짐, locked 앞 칸 안 찍음, can 해금 가능, poor 광물 부족
static func fork_state(save: SaveData, branch: String, i: int, side: String) -> String:
	var node: Dictionary = tree(branch)[i]
	if active(save, node) == side:
		return "on"
	if owned(save, node).contains(side):
		return "idle"
	if not is_open(save, branch, i):
		return "locked"
	return "can" if save.credits >= int(node["cost"]) else "poor"


## 갈림길 한쪽 해금. 처음 해금한 쪽은 바로 사용 중이 된다
static func unlock_fork(save: SaveData, branch: String, i: int, side: String) -> bool:
	if fork_state(save, branch, i, side) != "can":
		return false
	var node: Dictionary = tree(branch)[i]
	save.credits -= int(node["cost"])
	var both := owned(save, node) + side
	save.forks_owned[fork_id(node)] = "ab" if both.length() == 2 else both
	if active(save, node).is_empty():
		save.forks_on[fork_id(node)] = side
	return true


## 해금한 다른 쪽으로 바꾸기 (추가 비용 없음)
static func swap_fork(save: SaveData, branch: String, i: int, side: String) -> bool:
	if fork_state(save, branch, i, side) != "idle":
		return false
	save.forks_on[fork_id(tree(branch)[i])] = side
	return true


# ── 출격 ────────────────────────────────────────

## 출격에 넘길 단계 표: 찍은 칸 + 사용 중인 갈림길 쪽만 1단계. 꺼진 쪽은 효과가 없다
static func run_levels(save: SaveData) -> Dictionary:
	var levels := save.upgrades.duplicate()
	for branch in Balance.RESEARCH_TREE:
		for node in tree(branch):
			if is_fork(node) and not active(save, node).is_empty():
				levels[node[active(save, node)]] = 1
	return levels


# ── 표시 ────────────────────────────────────────

## 가지 진행: [찍은 수, 전체]. 갈림길은 양쪽 해금까지, "곧 추가"는 세지 않는다
static func progress(save: SaveData, branch: String) -> Array:
	var done := 0
	var total := 0
	for node in tree(branch):
		if is_fork(node):
			total += 2
			done += owned(save, node).length()
		elif not is_soon(node):
			total += BaseUpgrades.max_level(node)
			done += save.level_of(node)
	return [done, total]


## 설명 창의 "지금 → 다음"
static func effect_text(id: String, level: int) -> String:
	var info := BaseUpgrades.info(id)
	if not info.has("effect"):
		return BaseUpgrades.change_text(id, level)  # 기존 6칸은 실제 능력치로
	var top := BaseUpgrades.max_level(id)
	if top <= 1:
		return String(info["effect"]) if level >= 1 else "없음 → %s" % info["effect"]
	var step := float(info["step"])
	var fmt := String(info["effect"])
	var now := fmt % (step * level) if level > 0 else "없음"
	if level >= top:
		return now
	var next := fmt % (step * (level + 1))
	return "%s → %s" % [now, next.substr(next.rfind(" ") + 1) if level > 0 else next]
