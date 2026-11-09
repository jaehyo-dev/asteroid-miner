class_name ResearchLayout
extends RefCounted
## 연구소 나무 배치: 격자 위 칸 자리, 관 경로, 글자 자리, 설명 창 자리. 화면과 분리해 격자·대칭·연결을 테스트한다.
## 모든 칸은 위아래 소켓으로 관이 꽂힌다. 갈림길 앞뒤는 칸 사이 간격 가운데 가로관에서 T자로 갈라지고 합쳐진다.

const CELL := 72  ## 격자 한 칸 (배경 점 24칸의 3배)
const SOCK := Vector2i(40, 48)
const JOIN := 36  ## 갈림길 칸 중심에서 가로관까지 (칸 사이 간격 가운데)
const MARGIN := 6
const LABEL_GAP := 10  ## 칸 테두리와 글자 사이
const LINE := 15  ## 글자 한 줄
const PIPE_W := 8


static func key(i: int, side: String) -> String:
	return "%d%s" % [i, side]


## 칸 중심 격자 계산: {cx, base, cells{key: Vector2i}, max_pan}. 넘치면 맨 아래 칸이 보이게 두고 위로 끌어 본다.
static func compute(branch: String, cw: int, ch: int) -> Dictionary:
	var nodes := Research.tree(branch)
	var cx := cw / 2
	var h := (nodes.size() - 1) * CELL + SOCK.y
	var base: int = (ch + h) / 2 - SOCK.y / 2 if h + 2 * MARGIN <= ch else ch - MARGIN - SOCK.y / 2
	var cells := {}
	for i in nodes.size():
		var y := base - i * CELL
		if Research.is_fork(nodes[i]):
			cells[key(i, "a")] = Vector2i(cx - CELL, y)
			cells[key(i, "b")] = Vector2i(cx + CELL, y)
		else:
			cells[key(i, "c")] = Vector2i(cx, y)
	return {"cx": cx, "base": base, "cells": cells, "max_pan": maxi(0, h + 2 * MARGIN - ch)}


## 관 경로: [{"p": 앞 칸 번호, "q": 뒤 칸 번호, "pside", "qside", "pts"}] 아래에서 위로 흐르는 순서.
## 갈림길이 연달아 오는 나무는 없다 (shortcut: 연달아 오면 가로관 두 줄이 필요해 그때 고친다)
static func links(branch: String, lay: Dictionary) -> Array:
	var nodes := Research.tree(branch)
	var cells: Dictionary = lay["cells"]
	var cx: int = lay["cx"]
	var out := []
	for i in range(1, nodes.size()):
		var y: int = cells[key(i, "a") if Research.is_fork(nodes[i]) else key(i, "c")].y
		if Research.is_fork(nodes[i]):
			var t := Vector2i(cx, y + JOIN)
			out.append({"p": i - 1, "pside": "c", "q": i, "qside": "", "pts": [cells[key(i - 1, "c")], t]})
			for side: String in ["a", "b"]:
				out.append({"p": i - 1, "pside": "", "q": i, "qside": side, "pts": [t, Vector2i(cells[key(i, side)].x, t.y), cells[key(i, side)]]})
		elif Research.is_fork(nodes[i - 1]):
			var t := Vector2i(cx, y + CELL - JOIN)
			for side: String in ["a", "b"]:
				out.append({"p": i - 1, "pside": side, "q": i, "qside": "", "pts": [cells[key(i - 1, side)], Vector2i(cells[key(i - 1, side)].x, t.y), t]})
			out.append({"p": i - 1, "pside": "", "q": i, "qside": "c", "pts": [t, cells[key(i, "c")]]})
		else:
			out.append({"p": i - 1, "pside": "c", "q": i, "qside": "c", "pts": [cells[key(i - 1, "c")], cells[key(i, "c")]]})
	return out


## 칸에 빛이 들어왔는지. "곧 추가" 칸은 뒤 칸으로 가는 길이라 앞 칸을 지났으면 빛이 지나간다
static func _lit(save: SaveData, branch: String, i: int, side: String) -> bool:
	var node: Variant = Research.tree(branch)[i]
	if Research.is_fork(node):
		var on := Research.active(save, node)
		return on == side if side != "" else on != ""
	if Research.is_soon(node):
		return Research.is_open(save, branch, i)
	return save.level_of(node) > 0


## 관마다 단계: lit 찍은 길, open 빈 길, locked 잠긴 길
static func tiers(save: SaveData, branch: String, lay: Dictionary) -> Array:
	var out := []
	for l: Dictionary in links(branch, lay):
		var p: int = l["p"]
		var q: int = l["q"]
		var q_node: Variant = Research.tree(branch)[q]
		var lit: bool = _lit(save, branch, p, l["pside"]) and _lit(save, branch, q, l["qside"])
		var open: bool
		if l["pside"] in ["a", "b"]:
			open = Research.owned(save, Research.tree(branch)[p]).contains(l["pside"])
		elif Research.is_fork(q_node) or not Research.is_soon(q_node):
			open = Research.is_open(save, branch, q)
		else:
			open = false
		out.append({"pts": l["pts"], "tier": "lit" if lit else ("open" if open else "locked")})
	return out


## 찍은 길을 이어 흐름 줄로. 옛 저장처럼 끊긴 곳이 있으면 거기서 새 줄
static func routes(paths: Array) -> Array:
	var runs: Array = [[]]
	for p: Dictionary in paths:
		if p["tier"] != "lit":
			continue
		var run: Array = runs[-1]
		if not run.is_empty() and run[-1] != p["pts"][0]:
			run = []
			runs.append(run)
		run.append_array(p["pts"] if run.is_empty() else p["pts"].slice(1))
	return runs.filter(func(r: Array) -> bool: return not r.is_empty())


## 꺾인 선을 1칸씩 걷는다: [Vector3i(x, y, 세로면 1)]
static func walk(points: Array) -> Array:
	var out := []
	for j in points.size() - 1:
		var a: Vector2i = points[j]
		var b: Vector2i = points[j + 1]
		var step := (b - a).sign()
		for n in maxi(absi(b.x - a.x), absi(b.y - a.y)):
			var at := a + step * n
			out.append(Vector3i(at.x, at.y, 1 if step.x == 0 else 0))
	if not out.is_empty():
		var end: Vector2i = points[-1]
		out.append(Vector3i(end.x, end.y, out[-1].z))
	return out


## 연결 검사: 칸마다 위아래 소켓에 관이 꽂히고 모두 시작 칸에서 이어지는지. 끊긴 것 목록을 돌려준다 (비어 있어야 정상)
static func broken(branch: String, lay: Dictionary, paths: Array) -> Array:
	var nodes := Research.tree(branch)
	var cells: Dictionary = lay["cells"]
	var joined := {}  # 점 → 이어진 점들
	for p: Dictionary in paths:
		var pts: Array = p["pts"]
		for j in pts.size() - 1:
			assert(pts[j].x == pts[j + 1].x or pts[j].y == pts[j + 1].y)
			joined.get_or_add(pts[j], []).append(pts[j + 1])
			joined.get_or_add(pts[j + 1], []).append(pts[j])
	var out := []
	for k: String in cells:
		var c: Vector2i = cells[k]
		var i := k.to_int()
		var arms: Array = joined.get(c, [])
		if i > 0 and not arms.any(func(o: Vector2i) -> bool: return o.x == c.x and o.y > c.y):
			out.append("%s 아래 소켓에 관 없음" % k)
		if i < nodes.size() - 1 and not arms.any(func(o: Vector2i) -> bool: return o.x == c.x and o.y < c.y):
			out.append("%s 위 소켓에 관 없음" % k)
	var seen := {cells[key(0, "c")]: true}
	var stack: Array = [cells[key(0, "c")]]
	while not stack.is_empty():
		for o: Vector2i in joined.get(stack.pop_back(), []):
			if not seen.has(o):
				seen[o] = true
				stack.append(o)
	for k: String in cells:
		if not seen.has(cells[k]):
			out.append("%s 시작 칸과 끊김" % k)
	return out


## 글자 사각형 {owner(칸 key): [Rect2i]}. 줄기 칸은 오른쪽, 갈림길은 바깥쪽 옆. 이름과 가격·상태 두 줄. measure(글) → 폭
static func label_rect(k: String, lay: Dictionary, width: int) -> Rect2i:
	var c: Vector2i = lay["cells"][k]
	var side := k.right(1)
	var x := c.x - SOCK.x / 2 - LABEL_GAP - width if side == "a" else c.x + SOCK.x / 2 + LABEL_GAP
	return Rect2i(x, c.y - LINE, width, LINE * 2)


static func cell_rect(k: String, lay: Dictionary) -> Rect2i:
	var c: Vector2i = lay["cells"][k]
	return Rect2i(c.x - SOCK.x / 2, c.y - SOCK.y / 2, SOCK.x, SOCK.y)


## 설명 창 자리 (PC): 칸 옆에서 다른 칸의 소켓·글자를 안 가리는 가장 가까운 곳. 양쪽 다 가리면 덜 가리는 쪽. 눌린 칸은 안 가린다.
## avoid: 칸 key → [Rect2i] (끌기 반영 전). 돌려주는 값: [x, y, 가린 개수]
static func popup_pos(k: String, size: Vector2i, lay: Dictionary, avoid: Dictionary, cw: int, ch: int, pan: int, right_margin: int) -> Array:
	var c: Vector2i = lay["cells"][k]
	var y := c.y + pan
	var boxes := []
	for owner: String in avoid:
		if owner == k:
			continue
		for r: Rect2i in avoid[owner]:
			var moved := Rect2i(r.position + Vector2i(0, pan), r.size)
			if moved.end.y > 0 and moved.position.y < ch:
				boxes.append(moved)
	var gap := SOCK.x / 2 + 6
	var max_x := cw - right_margin - 4 - size.x
	var best: Array = []
	var best_score := Vector3i(1 << 30, 0, 0)
	var sides := [range(c.x + gap, max_x + 1, 8) if c.x + gap <= max_x else [], range(c.x - gap - size.x, 3, -8)]
	for order in 2:
		var dist := 0
		for px: int in sides[order]:
			for py in range(4, maxi(4, ch - size.y - 4) + 1, 8):
				var box := Rect2i(px, py, size.x, size.y)
				var hits := 0
				for r: Rect2i in boxes:
					hits += 1 if box.intersects(r) else 0
				var score := Vector3i(hits, dist + absi(py + size.y / 2 - y) / 8, order)
				if score < best_score:
					best_score = score
					best = [px, py, hits]
			dist += 1
	return best
