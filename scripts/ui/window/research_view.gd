class_name ResearchView
extends WindowView
## 연구소: 왼쪽 세로 탭 + 고른 가지의 나무. 칸을 누르면 PC는 칸 옆 창, 폰은 판 아래 띠에서 강화·해금·바꾸기.
## 규칙은 Research, 배치는 ResearchLayout에 있고 여기서는 그리기와 입력만 한다.

## 탭 줄 폭, 폰 아래 띠 높이
const TAB_W := 58
const TAB_W_SMALL := 53
const STRIP_H := 44
const POPUP_W := 156
const FORK_POPUP_W := 158
const FLOW_FPS := 25.0
## 빛 덩어리 간격, 강화 빛 속도(프레임당)·꼬리, 번쩍임 세기 순서
const FLOW_SPACING := 50
const COMET_STEP := 18
const COMET_TAIL := 28
const FLASH := [3, 3, 2, 1, 1, 0]
const FORK_GUIDE := "둘 다 해금하면 언제든 바꿔 쓸 수 있어요"

const PLATE_SHAPES := ["NE", "NW", "ES", "SW", "NEW", "ESW", "ENS", "NSW"]

## 지금 가지, 고른 칸 key ("" = 없음), 끌기(0 = 맨 아래가 보임, 클수록 위쪽을 봄, 띠가 열리면 음수까지)
var branch := "weapon"
var selected := ""
var pan := 0
var lay := {}
var paths: Array = []
var tabs: Array[Button] = []
## 설명 창·띠의 버튼 (테스트·입력용). 없으면 null
var action_button: WinButton
var board: Control
var panel: Control

var _board_size := Vector2i.ZERO
var _phase := 0
var _phase_time := 0.0
var _comet: Array = []  # 달리는 칸들
var _comet_s := -1
var _comet_key := ""
var _flash_i := -1
var _max_pending := false  # 만렙 꼬리 소리를 칸이 번쩍일 때 낸다
var _unlit := {}
var _pan_target := 0
var _press := Vector2(-1, -1)
var _press_pan := 0
var _moved := false
var _strip_press := -1.0
var _rail_tile := {}
var _labels := {}
var _placed_for := ""


func setup() -> void:
	var cw := int(size.x) - _tab_w()
	if cw % 2 == 1:
		cw -= 1
	_board_size = Vector2i(cw, int(size.y))
	var tab_h := int(size.y) / Balance.RESEARCH_BRANCHES.size()
	for i in Balance.RESEARCH_BRANCHES.size():
		var b := TabButton.new()
		b.view = self
		b.branch = Balance.RESEARCH_BRANCHES[i]
		b.position = Vector2(0, i * tab_h)
		b.size = Vector2(_tab_w(), tab_h - (1 if win.compact else 2))
		b.pressed.connect(_on_tab.bind(b.branch))
		add_child(b)
		tabs.append(b)
	board = Board.new()
	board.view = self
	board.position = Vector2(int(size.x) - cw, 0)
	board.size = Vector2(_board_size)
	board.clip_contents = true
	board.gui_input.connect(_on_board_input)
	add_child(board)
	_select_branch(branch)


func _tab_w() -> int:
	return TAB_W_SMALL if win.compact else TAB_W


func _on_tab(b: String) -> void:
	Sfx.play("click")
	_select_branch(b)


func _select_branch(b: String) -> void:
	branch = b
	selected = ""
	_close_panel()
	lay = ResearchLayout.compute(branch, _board_size.x, _board_size.y)
	pan = 0
	_pan_target = 0
	_comet_s = -1
	_flash_i = -1
	_refresh()
	# 맨 처음에는 지금 찍을 수 있는 칸이 보이게
	if lay["max_pan"] > 0:
		pan = clampi(_frontier_pan(), 0, lay["max_pan"])
		_pan_target = pan
	for t in tabs:
		t.queue_redraw()
	board.queue_redraw()


func _frontier_pan() -> int:
	var nodes := Research.tree(branch)
	var top := 0
	for i in nodes.size():
		var open := Research.is_open(win.save, branch, i)
		if not open:
			break
		top = i
	var y: int = lay["base"] - top * ResearchLayout.CELL
	return _board_size.y / 2 - y


func _refresh() -> void:
	paths = ResearchLayout.tiers(win.save, branch, lay)
	_labels = _build_labels()


## 칸마다 글자 폭: 이름과 둘째 줄 중 넓은 쪽. 자리 고르기·눌림 판정에 쓴다
func _build_labels() -> Dictionary:
	var out := {}
	for k: String in lay["cells"]:
		var w := WindowArt.width(_name_of(k))
		out[k] = maxi(w, _second_width(k))
	return out


func _second_width(k: String) -> int:
	var i := k.to_int()
	var side := k.right(1)
	var node: Variant = Research.tree(branch)[i]
	if side != "c":
		match Research.fork_state(win.save, branch, i, side):
			"on":
				return WindowArt.width("사용 중")
			"idle":
				return WindowArt.width("바꾸기")
		return 14 + WindowArt.width(Hud.thousands(int(node["cost"])))
	if Research.is_soon(node):
		return WindowArt.width("곧 추가")
	var lv := win.save.level_of(node)
	if lv == 0:
		return 14 + WindowArt.width(Hud.thousands(BaseUpgrades.cost(node, 0)))
	return BaseUpgrades.max_level(node) * 6


func _name_of(k: String) -> String:
	var node: Variant = Research.tree(branch)[k.to_int()]
	return Research.name_of(node, k.right(1)) if Research.is_fork(node) else Research.name_of(node)


func _icon_of(k: String) -> Texture2D:
	var node: Variant = Research.tree(branch)[k.to_int()]
	return WindowArt.tex("icon_" + (node[k.right(1)] if Research.is_fork(node) else node))


func _process(delta: float) -> void:
	_phase_time += delta
	if _phase_time < 1.0 / FLOW_FPS:
		return
	_phase_time = fmod(_phase_time, 1.0 / FLOW_FPS)
	_phase += 1
	if _comet_s >= 0:
		_comet_s += COMET_STEP
		if _comet_s >= _comet.size() + 8:
			_comet_s = -1
			_unlit.clear()
			_start_flash()
	elif _flash_i >= 0:
		_flash_i += 1
		if _flash_i >= FLASH.size():
			_flash_i = -1
	if pan != _pan_target:
		pan = move_toward(pan, _pan_target, 8) as int
		_place_panel()
	board.queue_redraw()


# ── 입력 ───────────────────────────────────────

func _min_pan() -> int:
	return -STRIP_H if win.compact and panel != null else 0


func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.position
			_press_pan = pan
			_moved = false
		else:
			if not _moved and _press.x >= 0.0:
				_click(Vector2i(event.position))
			_press = Vector2(-1, -1)
	elif event is InputEventMouseMotion and _press.x >= 0.0:
		var dy: float = event.position.y - _press.y
		if absf(dy) > 4.0:
			_moved = true
		if _moved:
			pan = clampi(_press_pan + int(dy), _min_pan(), lay["max_pan"])
			_pan_target = pan
			_place_panel()
			board.queue_redraw()


## 누른 곳의 칸 (소켓 + 글자). 없으면 ""
func cell_at(p: Vector2i) -> String:
	var at := p - Vector2i(0, pan)
	for k: String in lay["cells"]:
		var c := ResearchLayout.cell_rect(k, lay)
		var l := ResearchLayout.label_rect(k, lay, _labels[k])
		if c.has_point(at) or l.has_point(at):
			return k
	return ""


func _click(p: Vector2i) -> void:
	var k := cell_at(p)
	Sfx.play("click")
	if k.is_empty() or k == selected:
		selected = ""
		_close_panel()
		_pan_target = clampi(pan, 0, lay["max_pan"])
	else:
		select_cell(k)
	board.queue_redraw()


## 칸을 고르고 설명을 연다
func select_cell(k: String) -> void:
	selected = k
	_open_panel()
	if win.compact:  # 누른 칸이 띠 위로 보이게 끌어 올린다
		var y: int = lay["cells"][k].y
		var view_h := _board_size.y - STRIP_H
		var want := pan
		if y + pan + 26 > view_h:
			want = view_h - 26 - y
		elif y + pan - 26 < 0:
			want = 26 - y
		_pan_target = clampi(want, _min_pan(), lay["max_pan"])
	board.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var keys: Array = lay["cells"].keys()
	if keys.is_empty():
		return
	var i := keys.find(selected)
	if event.is_action("ui_up") or event.is_action("ui_right"):
		select_cell(keys[mini(i + 1, keys.size() - 1)])
	elif event.is_action("ui_down") or event.is_action("ui_left"):
		select_cell(keys[maxi(i - 1, 0)])
	else:
		return
	if action_button != null:
		action_button.grab_focus()
	get_viewport().set_input_as_handled()


# ── 강화 ───────────────────────────────────────

## 칸 한 단계 강화 또는 갈림길 해금·바꾸기. 성공하면 빛이 시작 칸부터 달려간다
func act() -> void:
	if selected.is_empty():
		return
	var i := selected.to_int()
	var side := selected.right(1)
	var old_lit := {}
	for run: Array in ResearchLayout.routes(paths):
		for w: Vector3i in ResearchLayout.walk(run):
			old_lit[Vector2i(w.x, w.y)] = true
	var done := false
	var swapped := false
	if side == "c":
		done = Research.buy(win.save, branch, i)
	elif Research.fork_state(win.save, branch, i, side) == "idle":
		done = Research.swap_fork(win.save, branch, i, side)
		swapped = done
	else:
		done = Research.unlock_fork(win.save, branch, i, side)
	if not done:
		return
	win.save.save_file()
	_max_pending = side == "c" and Research.state(win.save, branch, i) == "max"
	if swapped:
		Sfx.play("click")
	else:
		Sfx.play("upgrade", -1.0, 1.0, 2.0 if _max_pending else 0.0)  # 만렙은 조금 크게
	win.bought.emit(selected)
	win.refresh_head()
	_refresh()
	_run_comet(selected, old_lit)
	_open_panel()
	for t in tabs:
		t.queue_redraw()
	board.queue_redraw()


## 시작 칸에서 k까지 빛을 달린다. 지나가며 새 길이 찬다. 가지 않는 쪽(꺼진 갈림길)은 지나지 않는다
func _run_comet(k: String, old_lit: Dictionary) -> void:
	var c: Vector2i = lay["cells"][k]
	_comet = []
	for run: Array in ResearchLayout.routes(paths):
		var cells := ResearchLayout.walk(run)
		for j in cells.size():
			if Vector2i(cells[j].x, cells[j].y) == c:
				_comet = cells.slice(0, j + 1)
				break
	_comet_key = k
	if _comet.is_empty():  # 맨 아래 칸이거나 길이 안 이어지면 칸만 번쩍
		_start_flash()
		_comet_s = -1
		return
	_unlit.clear()
	for run: Array in ResearchLayout.routes(paths):
		for w: Vector3i in ResearchLayout.walk(run):
			var at := Vector2i(w.x, w.y)
			if not old_lit.has(at):
				_unlit[at] = true
	_comet_s = 0
	_flash_i = -1


## 칸이 하얗게 번쩍이기 시작. 만렙이면 이때 무거운 울림
func _start_flash() -> void:
	_flash_i = 0
	if _max_pending:
		_max_pending = false
		Sfx.play("upgrade_max")


## 꺼진 강화 버튼을 눌렀을 때: 광물이 모자라면 부드럽게 막히는 툭
func _on_denied() -> void:
	if action_info().get("note", "") == "광물이 모자라요":
		Sfx.play("deny")


# ── 설명 창 ────────────────────────────────────

func _close_panel() -> void:
	if panel != null:
		remove_child(panel) if panel.get_parent() == self else board.remove_child(panel)
		panel.queue_free()
		panel = null
	action_button = null


func _open_panel() -> void:
	_close_panel()
	_placed_for = ""
	if selected.is_empty():
		return
	panel = StripPanel.new() if win.compact else PopupPanel_.new()
	panel.set("view", self)
	board.add_child(panel)
	panel.call("build")
	_place_panel()


func _avoid_rects() -> Dictionary:
	var out := {}
	for k: String in lay["cells"]:
		out[k] = [ResearchLayout.cell_rect(k, lay), ResearchLayout.label_rect(k, lay, _labels[k])]
	return out


func _place_panel() -> void:
	if panel == null:
		return
	if win.compact:
		panel.position = Vector2(0, _board_size.y - STRIP_H)
		panel.size = Vector2(_board_size.x, STRIP_H)
		return
	if _placed_for == selected:  # 끌어도 창은 그 자리에 둔다 (자리 찾기는 누를 때 한 번만)
		return
	_placed_for = selected
	var bar := 6 if lay["max_pan"] > 0 else 0
	var at := ResearchLayout.popup_pos(selected, Vector2i(panel.size), lay, _avoid_rects(), _board_size.x, _board_size.y, pan, bar)
	if not at.is_empty():
		panel.position = Vector2(at[0], at[1])


## 버튼 글·가격·꺼짐을 지금 상태로
func action_info() -> Dictionary:
	var i := selected.to_int()
	var side := selected.right(1)
	if side != "c":
		var cost := int(Research.tree(branch)[i]["cost"])
		match Research.fork_state(win.save, branch, i, side):
			"on":
				return {"label": "사용 중", "off": true, "cost": -1}
			"idle":
				return {"label": "이걸로 바꾸기", "off": false, "cost": -1}
			"locked":
				return {"label": "잠김", "off": true, "cost": -1, "note": "먼저: " + _prev_name(i)}
			"poor":
				return {"label": "해금", "off": true, "cost": cost, "note": "광물이 모자라요"}
		return {"label": "해금", "off": false, "cost": cost}
	var id: String = Research.tree(branch)[i]
	var lv := win.save.level_of(id)
	match Research.state(win.save, branch, i):
		"soon":
			return {"label": "아직 잠김", "off": true, "cost": -1}
		"locked":
			return {"label": "잠김", "off": true, "cost": -1, "note": "먼저: " + _prev_name(i)}
		"max":
			return {"label": "최대", "off": true, "cost": -1}
	var cost := BaseUpgrades.cost(id, lv)
	if cost > win.save.credits:
		return {"label": "강화", "off": true, "cost": cost, "note": "광물이 모자라요"}
	return {"label": "강화", "off": false, "cost": cost}


func _prev_name(i: int) -> String:
	var p: Variant = Research.tree(branch)[i - 1]
	return "갈림길" if Research.is_fork(p) else Research.name_of(p)


## 효과 한 줄: 칸은 지금 → 다음, 갈림길은 효과
func effect_of(k: String) -> String:
	var node: Variant = Research.tree(branch)[k.to_int()]
	if Research.is_fork(node):
		return String(BaseUpgrades.info(node[k.right(1)])["effect"])
	return Research.effect_text(node, win.save.level_of(node))


## 띠에서 갈림길 다른 쪽으로 넘기기
func flip_side() -> void:
	if selected.right(1) == "c":
		return
	selected = ResearchLayout.key(selected.to_int(), "b" if selected.right(1) == "a" else "a")
	Sfx.play("click")
	_open_panel()
	board.queue_redraw()


## 칸 상태 → 소켓 그림 이름과 글자 색
func socket_of(k: String) -> Dictionary:
	var i := k.to_int()
	var side := k.right(1)
	var light: Color = WindowArt.BRANCH[branch][1]
	if side != "c":
		var st := Research.fork_state(win.save, branch, i, side)
		match st:
			"on":
				return {"tex": "socket_on_" + branch, "glow": "glow_on", "icon": Color.WHITE, "color": light, "st": st}
			"idle":
				return {"tex": "socket_idle_" + branch, "glow": "glow_on", "icon": Color(0.75, 0.75, 0.75), "color": WindowArt.MUTED, "st": st, "faint": true}
			"locked":
				return {"tex": "socket_plan", "glow": "", "icon": Color(0.6, 0.6, 0.6), "color": WindowArt.DIM, "st": st}
		return {"tex": "socket_off", "glow": "glow_off" if st == "can" else "", "icon": Color.WHITE, "color": WindowArt.INK, "st": st}
	var id: String = Research.tree(branch)[i]
	var st := Research.state(win.save, branch, i)
	if win.save.level_of(id) > 0:
		return {"tex": "socket_on_" + branch, "glow": "glow_on", "icon": Color.WHITE, "color": light, "st": st}
	if st in ["can", "poor"]:
		return {"tex": "socket_off", "glow": "glow_off" if st == "can" else "", "icon": Color.WHITE, "color": WindowArt.INK, "st": st}
	return {"tex": "socket_plan", "glow": "", "icon": Color(0.6, 0.6, 0.6), "color": WindowArt.DIM, "st": st}


# ── 탭 ─────────────────────────────────────────

class TabButton extends Button:
	var view: ResearchView
	var branch := ""

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var on := view.branch == branch
		var out := 0 if on else (3 if view.win.compact else 5)
		var w := int(size.x) - out + (1 if on else 0)
		var h := int(size.y)
		WindowArt.plate(self, "tab", Rect2(out, 0, w, h), -1, -1, Color.WHITE if on else Color(0.65, 0.65, 0.65))
		var main: Color = WindowArt.BRANCH[branch][0]
		var light: Color = WindowArt.BRANCH[branch][1]
		var emblem := WindowArt.tex("emblem_" + branch)
		var name_color := light if on else WindowArt.MUTED
		var label: String = WindowArt.BRANCH_NAME[branch]
		var bar_x0: int
		var bar_x1: int
		var bar_y: int
		if view.win.compact:  # 폰: 아이콘 | 간격 | 이름, 아래 막대
			draw_texture(emblem, Vector2(out + 4, 5))
			WindowArt.text(self, Vector2i(out + 22, 6), label, name_color)
			bar_x0 = out + 5
			bar_x1 = int(size.x) - 5
			bar_y = 21
		else:
			var cx := out + w / 2 - (1 if on else 0)
			draw_texture(emblem, Vector2(cx - emblem.get_width() / 2, 5))
			WindowArt.text(self, Vector2i(cx, 21), label, name_color, 0)
			bar_x0 = cx - 19
			bar_x1 = cx + 19
			bar_y = 38
		var pr := Research.progress(view.win.save, branch)
		draw_rect(Rect2(bar_x0, bar_y, bar_x1 - bar_x0 + 1, 5), WindowArt.DARK)
		draw_rect(Rect2(bar_x0 + 1, bar_y + 1, bar_x1 - bar_x0 - 1, 3), WindowArt.GREY)
		if pr[0] > 0:
			draw_rect(Rect2(bar_x0 + 1, bar_y + 1, maxi(1, (bar_x1 - bar_x0 - 1) * pr[0] / pr[1]), 3), light if on else main)
		WindowArt.focus_mark(self)


# ── 판 ─────────────────────────────────────────

class Board extends Control:
	var view: ResearchView

	func _draw() -> void:
		var v := view
		var cw := int(size.x)
		var ch := int(size.y)
		draw_rect(Rect2(0, 0, cw, ch), WindowArt.DARK)
		var lay: Dictionary = v.lay
		var pan := v.pan
		var cx: int = lay["cx"]
		var y0 := posmod(int(lay["base"]) + pan, 24)
		for y in range(y0, ch, 24):
			for x in range(cx % 24, cw, 24):
				draw_rect(Rect2(x, y, 1, 1), WindowArt.GREY)
		_draw_pipes()
		for k: String in lay["cells"]:
			_draw_cell(k)
		if v._flash_i >= 0:
			_draw_flash()
		if lay["max_pan"] > 0:
			_draw_bar(cw, ch)
		draw_rect(Rect2(0, 0, cw, ch), WindowArt.BRANCH[v.branch][0], false, 1.0)

	func _draw_bar(cw: int, ch: int) -> void:
		var v := view
		var lay: Dictionary = v.lay
		var top := 1.0 - clampf(float(v.pan) / float(lay["max_pan"]), 0.0, 1.0)
		var r := Rect2i(0, 0, cw, ch - (ResearchView.STRIP_H if v.panel != null and v.win.compact else 0))
		v.draw_bar_on(self, r, top, float(ch) / float(ch + int(lay["max_pan"])))

	func _draw_cell(k: String) -> void:
		var v := view
		var c: Vector2i = v.lay["cells"][k] + Vector2i(0, v.pan)
		if c.y < -40 or c.y > int(size.y) + 40:
			return
		var s := v.socket_of(k)
		var t := WindowArt.tex(s["tex"])
		var at := c - Vector2i(t.get_width() / 2, t.get_height() / 2)
		var chosen := v.selected == k
		var glow_name: String = "glow_on" if chosen and s["glow"] == "" else s["glow"]
		if glow_name != "" or chosen:
			var g := WindowArt.tex(glow_name if glow_name != "" else "glow_on")
			var tint: Color = WindowArt.INK if chosen else WindowArt.BRANCH[v.branch][1]
			tint.a = 1.0 if chosen else (0.25 if s.has("faint") else 0.8)
			draw_texture(g, Vector2(at - Vector2i(3, 3)), tint)
		draw_texture(t, Vector2(at))
		var icon := v._icon_of(k)
		draw_texture(icon, Vector2(c.x - icon.get_width() / 2, c.y + 1 - icon.get_height() / 2), s["icon"])
		_draw_label(k, c, s)

	## 글자: 줄기 칸은 오른쪽, 갈림길은 바깥쪽. 위 줄 이름, 아래 줄 단계 점·가격·상태
	func _draw_label(k: String, c: Vector2i, s: Dictionary) -> void:
		var v := view
		var i := k.to_int()
		var side := k.right(1)
		var node: Variant = Research.tree(v.branch)[i]
		var left := side == "a"
		var x := c.x - ResearchLayout.SOCK.x / 2 - ResearchLayout.LABEL_GAP if left else c.x + ResearchLayout.SOCK.x / 2 + ResearchLayout.LABEL_GAP
		var align := 1 if left else -1
		var name_ := v._name_of(k)
		if side != "c":
			WindowArt.text(self, Vector2i(x, c.y - 15), name_, s["color"], align)
			match s["st"]:
				"on":
					WindowArt.text(self, Vector2i(x, c.y), "사용 중", WindowArt.BRANCH[v.branch][1], align)
				"idle":
					WindowArt.text(self, Vector2i(x, c.y), "바꾸기", WindowArt.MUTED, align)
				_:
					_price(x, c.y, int(node["cost"]), s["st"], left)
			return
		var lv := v.win.save.level_of(node)
		var top := BaseUpgrades.max_level(node)
		if s["st"] == "soon":
			WindowArt.text(self, Vector2i(x, c.y - 15), name_, s["color"])
			WindowArt.text(self, Vector2i(x, c.y), "곧 추가", WindowArt.MUTED)
		elif lv == 0:
			WindowArt.text(self, Vector2i(x, c.y - 15), name_, s["color"])
			_price(x, c.y, BaseUpgrades.cost(node, 0), s["st"], false)
		elif top == 1:  # 1단계 칸은 점이 얼룩처럼 보여 이름만 가운데에
			WindowArt.text(self, Vector2i(x, c.y - 8), name_, s["color"])
		else:
			WindowArt.text(self, Vector2i(x, c.y - 15), name_, s["color"])
			WindowArt.pips(self, Vector2i(x, c.y + 3), lv, top, v.branch)

	func _price(x: int, y: int, cost: int, st: String, right_align: bool) -> void:
		var s := Hud.thousands(cost)
		var color: Color = WindowArt.GOLD if st == "can" else (WindowArt.RED if st == "poor" else WindowArt.DIM)
		var w := 14 + WindowArt.width(s)
		var x0 := x - w if right_align else x
		var ore := RunSprites.mineral(3)
		draw_texture(ore, Vector2(x0, y + 2 + (12 - ore.get_height()) / 2))
		WindowArt.text(self, Vector2i(x0 + 14, y), s, color)

	func _draw_flash() -> void:
		var v := view
		var power: int = ResearchView.FLASH[v._flash_i]
		if not v.lay["cells"].has(v._comet_key):
			return
		var c: Vector2i = v.lay["cells"][v._comet_key] + Vector2i(0, v.pan)
		var t := WindowArt.tex("socket_on_" + v.branch)
		var at := c - Vector2i(t.get_width() / 2, t.get_height() / 2)
		var tint: Color = WindowArt.BRANCH[v.branch][1]
		draw_texture(WindowArt.tex("glow_on"), Vector2(at - Vector2i(3, 3)), tint)
		if power >= 2:
			draw_texture(t, Vector2(at), Color(4.0, 4.0, 4.0))  # 첫 두 장: 칸 전체가 흰색

	# ── 관 ──────────────────────────────────────
	func _draw_pipes() -> void:
		var v := view
		var atlas := WindowArt.tex("pipes")
		var ranks := {"locked": 0, "open": 1, "lit": 2}
		var segs := {}
		var conns := {}
		for p: Dictionary in v.paths:
			var pts: Array = p["pts"]
			for j in pts.size() - 1:
				var a: Vector2i = pts[j]
				var b: Vector2i = pts[j + 1]
				var key := [a, b] if (a.x < b.x or (a.x == b.x and a.y < b.y)) else [b, a]
				if not segs.has(key) or ranks[p["tier"]] > ranks[segs[key]]:
					segs[key] = p["tier"]
				_connect(conns, a, b, p["tier"], ranks)
				_connect(conns, b, a, p["tier"], ranks)
		var order: Array = segs.keys()
		order.sort_custom(func(x: Array, y: Array) -> bool: return ranks[segs[x]] < ranks[segs[y]])
		var off := Vector2i(0, v.pan)
		for key: Array in order:  # 벽
			var tier: String = segs[key]
			var pal: Array = ResearchView.TIER[tier]
			var a: Vector2i = key[0] + off
			var b: Vector2i = key[1] + off
			if a.x == b.x:
				for w in [[-4, pal[0]], [-3, pal[1]], [2, pal[2]], [3, pal[0]]]:
					draw_rect(Rect2(a.x + w[0], a.y - 4, 1, b.y - a.y + 8), w[1])
			else:
				for w in [[-4, pal[0]], [-3, pal[1]], [2, pal[2]], [3, pal[0]]]:
					draw_rect(Rect2(a.x - 4, a.y + w[0], b.x - a.x + 8, 1), w[1])
		for key: Array in order:  # 빈 관 속
			var tier: String = segs[key]
			var pal: Array = ResearchView.TIER["open" if tier == "lit" else tier]
			var a: Vector2i = key[0] + off
			var b: Vector2i = key[1] + off
			draw_rect(Rect2(a.x - 2, a.y - 2, b.x - a.x + 4, b.y - a.y + 4), pal[3])
		_draw_fill(off)
		for key: Array in segs:  # 이음새
			_draw_collars(key, segs[key], off, atlas)
		for point: Vector2i in conns:  # 모서리·T자
			var names: Array = conns[point].keys()
			names.sort()
			var shape := "".join(names)
			if v.lay["cells"].values().has(point) or shape in ["EW", "NS"] or names.size() < 2:
				continue
			var tier: String = "locked"
			for t: String in conns[point].values():
				if ranks[t] > ranks[tier]:
					tier = t
			_part(atlas, tier, "plate", shape, point + off - Vector2i(6, 6))
		for k: String in v.lay["cells"]:  # 칸 소켓
			var c: Vector2i = v.lay["cells"][k]
			var half: int = WindowArt.tex(v.socket_of(k)["tex"]).get_height() / 2
			for d: String in conns.get(c, {}):
				var tier: String = conns[c][d]
				match d:
					"N":
						_part(atlas, tier, "flange", "N", c + off + Vector2i(-7, -half - 3))
					"S":
						_part(atlas, tier, "flange", "S", c + off + Vector2i(-7, half - 1))

	func _connect(conns: Dictionary, a: Vector2i, b: Vector2i, tier: String, ranks: Dictionary) -> void:
		var d := "N" if b.y < a.y else ("S" if b.y > a.y else ("W" if b.x < a.x else "E"))
		var arms: Dictionary = conns.get_or_add(a, {})
		if not arms.has(d) or ranks[tier] > ranks[arms[d]]:
			arms[d] = tier

	## 찍은 길 관 속 + 흐름 + 강화 빛
	func _draw_fill(off: Vector2i) -> void:
		var v := view
		var main: Color = WindowArt.BRANCH[v.branch][0]
		var light: Color = WindowArt.BRANCH[v.branch][1]
		var deep: Color = WindowArt.BRANCH[v.branch][2]
		var runs := ResearchLayout.routes(v.paths)
		for run: Array in runs:
			var cells := ResearchLayout.walk(run)
			var start := 0
			# 같은 축으로 이어지는 칸은 한 사각형 줄로 묶어 그리기 수를 줄인다
			for j in range(1, cells.size() + 1):
				var brk: bool = j == cells.size() or cells[j].z != cells[start].z or v._unlit.has(Vector2i(cells[j].x, cells[j].y)) != v._unlit.has(Vector2i(cells[start].x, cells[start].y))
				if brk:
					if not v._unlit.has(Vector2i(cells[start].x, cells[start].y)):
						_cross_run(cells[start], cells[j - 1], off, [light, main, main, deep])
					start = j
			for head in range(v._phase % ResearchView.FLOW_SPACING, cells.size(), ResearchView.FLOW_SPACING):
				for back in 9:  # 빛 덩어리: 앞이 밝고 뒤로 흐려진다
					var n := head - back
					if n < 0 or n >= cells.size() or v._unlit.has(Vector2i(cells[n].x, cells[n].y)):
						continue
					var cols: Array = [light, WindowArt.INK, WindowArt.INK, light] if back < 2 else ([light, light, light, main] if back < 5 else [light, light, main, main])
					_cross_run(cells[n], cells[n], off, cols)
		if v._comet_s >= 0:
			for n in range(maxi(0, v._comet_s - ResearchView.COMET_TAIL), mini(v._comet_s, v._comet.size() - 1) + 1):
				var back := v._comet_s - n
				var cols: Array = [WindowArt.INK, WindowArt.INK, WindowArt.INK, WindowArt.INK] if back < 8 else ([WindowArt.INK, light, light, WindowArt.INK] if back < 18 else [light, light, light, main])
				_cross_run(v._comet[n], v._comet[n], off, cols)

	## 관 속 4칸 단면을 a~b까지
	func _cross_run(a: Vector3i, b: Vector3i, off: Vector2i, cols: Array) -> void:
		var x0 := mini(a.x, b.x) + off.x
		var y0 := mini(a.y, b.y) + off.y
		var len_ := absi(b.x - a.x) + absi(b.y - a.y) + 1
		for i in 4:
			if a.z == 1:
				draw_rect(Rect2(x0 - 2 + i, y0, 1, len_), cols[i])
			else:
				draw_rect(Rect2(x0, y0 - 2 + i, len_, 1), cols[i])

	func _draw_collars(key: Array, tier: String, off: Vector2i, atlas: Texture2D) -> void:
		var v := view
		var a: Vector2i = key[0]
		var b: Vector2i = key[1]
		var vert := a.x == b.x
		var cells: Array = v.lay["cells"].values()
		var lo := (a.y if vert else a.x) + (28 if cells.has(a) else 8)
		var hi := (b.y if vert else b.x) - (28 if cells.has(b) else 8)
		if hi - lo < 10:
			return
		var mid := (lo + hi) / 2
		for n in range(-2, 3):
			var at := mid + n * 24
			if at - 2 < lo or at + 2 > hi:
				continue
			var pos := Vector2i(a.x - 5, at - 2) if vert else Vector2i(at - 2, a.y - 5)
			_part(atlas, tier, "collar", "v" if vert else "h", pos + off)

	## 아틀라스 조각 하나 (tools가 만든 순서: 곧은 관 2, 이음새 2, 판 8, 소켓 4 / 찍은·빈·잠긴)
	func _part(atlas: Texture2D, tier: String, kind: String, arg: String, pos: Vector2i) -> void:
		var row := ["lit", "open", "locked"].find(tier)
		var col := 0
		var sz := Vector2i(12, 12)
		match kind:
			"collar":
				col = 2 if arg == "v" else 3
				sz = Vector2i(10, 4) if arg == "v" else Vector2i(4, 10)
			"plate":
				col = 4 + ResearchView.PLATE_SHAPES.find(arg)
			"flange":
				col = 12 + "NESW".find(arg)
				sz = Vector2i(14, 4) if arg in ["N", "S"] else Vector2i(4, 14)
		draw_texture_rect_region(atlas, Rect2(pos, sz), Rect2(col * 16, row * 16, sz.x, sz.y))


## 관 금속 색 (테두리, 밝은 면, 그림자, 빈 관 속)
const TIER := {
	"lit": [Color("#000000"), Color("#a5b29d"), Color("#5c5164"), Color("#2b1925")],
	"open": [Color("#000000"), Color("#5c5164"), Color("#3c3544"), Color("#2b1925")],
	"locked": [Color("#000000"), Color("#3c3544"), Color("#2b1925"), Color("#000000")],
}


## 판에 끌기 막대 그리기 (WindowView 도우미를 다른 캔버스에)
func draw_bar_on(ci: CanvasItem, r: Rect2i, ratio_top: float, viewable: float) -> void:
	var color: Color = WindowArt.BRANCH[branch][0]
	var x0 := r.end.x - 6
	ci.draw_rect(Rect2(x0, r.position.y + 2, 4, r.size.y - 4), WindowArt.PLATE)
	var track := r.size.y - 14
	var thumb := maxi(12, int(track * viewable))
	var top := r.position.y + 7 + int((track - thumb) * ratio_top)
	ci.draw_rect(Rect2(x0, top, 4, thumb), color)
	if ratio_top > 0.0:
		ci.draw_rect(Rect2(x0 + 1, r.position.y + 2, 2, 1), WindowArt.INK)
		ci.draw_rect(Rect2(x0, r.position.y + 3, 4, 1), WindowArt.INK)
	if ratio_top < 1.0:
		ci.draw_rect(Rect2(x0 + 1, r.end.y - 3, 2, 1), WindowArt.INK)
		ci.draw_rect(Rect2(x0, r.end.y - 4, 4, 1), WindowArt.INK)


# ── PC 설명 창 ──────────────────────────────────

class PopupPanel_ extends Control:
	var view: ResearchView
	var _lines := PackedStringArray()
	var _guide := PackedStringArray()

	func build() -> void:
		var v := view
		var fork := v.selected.right(1) != "c"
		var w := ResearchView.FORK_POPUP_W if fork else ResearchView.POPUP_W
		var info := v.action_info()
		var bh := 24
		var h: int
		if fork:
			_guide = WindowArt.wrap(ResearchView.FORK_GUIDE, w - 24)
			h = 8 + 14 + _guide.size() * 14 + 4 + 2 * (58 + 4) + (14 if info.has("note") else 0) + bh + 10
		else:
			_lines = WindowArt.wrap(v.effect_of(v.selected), w - 24)
			h = 7 + 27 + 15 + 14 + _lines.size() * 14 + 4 + (14 if info.has("note") else 0) + bh + 9
		size = Vector2(w, h)
		var b := WinButton.new(info["label"], info["cost"])
		b.disabled = info["off"]
		b.position = Vector2(12, h - bh - 9)
		b.size = Vector2(w - 24, bh)
		b.pressed.connect(v.act)
		b.denied.connect(v._on_denied)
		add_child(b)
		v.action_button = b
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var v := view
		var w := int(size.x)
		WindowArt.plate(self, "tab", Rect2(Vector2.ZERO, size))
		var light: Color = WindowArt.BRANCH[v.branch][1]
		var info := v.action_info()
		var by := int(size.y) - 24 - 9
		if info.has("note"):
			WindowArt.text(self, Vector2i(12, by - 14), info["note"], WindowArt.RED if info["note"].begins_with("광물") else WindowArt.ORANGE)
		if v.selected.right(1) != "c":
			WindowArt.text(self, Vector2i(12, 8), "갈림길", light)
			var y := 22
			for line in _guide:
				WindowArt.text(self, Vector2i(12, y), line, WindowArt.MUTED)
				y += 14
			y += 4
			for side: String in ["a", "b"]:
				_fork_card(y, w - 25, side)
				y += 62
			return
		var id: String = Research.tree(v.branch)[v.selected.to_int()]
		var lv := v.win.save.level_of(id)
		var top := BaseUpgrades.max_level(id)
		var icon := v._icon_of(v.selected)
		draw_texture(icon, Vector2(12, 7))
		var tx := 12 + icon.get_width() + 5
		WindowArt.text(self, Vector2i(tx, 6), v._name_of(v.selected), light)
		WindowArt.text(self, Vector2i(tx, 19), "%s 계통" % WindowArt.BRANCH_NAME[v.branch], WindowArt.MUTED)
		var y := 34
		if Research.is_soon(id):
			WindowArt.text(self, Vector2i(12, y), "곧 추가", WindowArt.GOLD)
		elif top == 1:
			WindowArt.text(self, Vector2i(12, y), "강화 완료" if lv > 0 else "한 번만 강화", WindowArt.INK)
		else:
			WindowArt.pips(self, Vector2i(12, y + 2), lv, top, v.branch, 6, 2)
			WindowArt.text(self, Vector2i(12 + top * 8 + 4, y), "%d/%d단계" % [lv, top], WindowArt.INK)
		y += 15
		WindowArt.text(self, Vector2i(12, y), "지금 효과" if lv >= top else "지금 → 다음", WindowArt.TEAL2)
		y += 14
		for line in _lines:
			WindowArt.text(self, Vector2i(12, y), line, WindowArt.GOLD if lv < top else WindowArt.INK)
			y += 14

	func _fork_card(y: int, w: int, side: String) -> void:
		var v := view
		var i := v.selected.to_int()
		var node: Dictionary = Research.tree(v.branch)[i]
		var st := Research.fork_state(v.win.save, v.branch, i, side)
		var light: Color = WindowArt.BRANCH[v.branch][1]
		var picked := v.selected.right(1) == side
		var dim := st == "locked"
		draw_rect(Rect2(12, y, w, 58), WindowArt.DARK)
		draw_rect(Rect2(12, y, w, 58), WindowArt.INK if picked else (light if st == "on" else Color("#5c5164")), false, 1.0)
		var icon := WindowArt.tex("icon_" + node[side])
		draw_texture(icon, Vector2(15, y + 3), Color(0.6, 0.6, 0.6) if dim else Color.WHITE)
		WindowArt.text(self, Vector2i(43, y + 3), Research.name_of(node, side), light if st == "on" else (WindowArt.DIM if dim else WindowArt.INK))
		var right := 12 + w - 4
		var y2 := y + 18
		if st in ["on", "idle"]:
			WindowArt.text(self, Vector2i(43, y2), "사용 중" if st == "on" else "해금함", light if st == "on" else WindowArt.MUTED)
		else:
			var s := Hud.thousands(int(node["cost"]))
			WindowArt.text(self, Vector2i(right, y2), s, WindowArt.GOLD if st == "can" else (WindowArt.RED if st == "poor" else WindowArt.DIM), 1)
			draw_texture(RunSprites.mineral(3), Vector2(right - WindowArt.width(s) - 14, y2 + 2))
		var yy := y + 32
		for line in WindowArt.wrap(BaseUpgrades.info(node[side])["effect"], w - 8).slice(0, 2):
			WindowArt.text(self, Vector2i(16, yy), line, WindowArt.DIM if dim else WindowArt.GOLD)
			yy += 13


# ── 폰 아래 띠 ──────────────────────────────────

class StripPanel extends Control:
	var view: ResearchView
	var _press_x := -1.0
	const BTN_W := 86

	func build() -> void:
		var v := view
		var info := v.action_info()
		var b := WinButton.new(info["label"], info["cost"])
		b.disabled = info["off"]
		b.position = Vector2(v._board_size.x - BTN_W - 6, 10)
		b.size = Vector2(BTN_W, 26)
		b.pressed.connect(v.act)
		b.denied.connect(v._on_denied)
		add_child(b)
		v.action_button = b
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)
		if v.selected.right(1) != "c":
			for side: int in [-1, 1]:
				var arrow := ArrowButton.new()
				arrow.dir = side
				arrow.size = Vector2(16, 30)
				arrow.position = Vector2(4 if side < 0 else v._board_size.x - BTN_W - 26, 8)
				arrow.pressed.connect(v.flip_side)
				add_child(arrow)

	## 띠를 좌우로 넘기면 갈림길 다른 쪽
	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_x = event.position.x
			else:
				if _press_x >= 0.0 and absf(event.position.x - _press_x) > 16.0:
					view.flip_side()
				_press_x = -1.0

	func _draw() -> void:
		var v := view
		var w := int(size.x)
		var fork := v.selected.right(1) != "c"
		WindowArt.plate(self, "tab", Rect2(Vector2.ZERO, size))
		var light: Color = WindowArt.BRANCH[v.branch][1]
		var x := 22 if fork else 10
		var limit := w - BTN_W - 12 - x - (22 if fork else 0)
		var name_ := v._name_of(v.selected)
		var info := v.action_info()
		var second := ""
		var id: String = ""
		if fork:
			var st := Research.fork_state(v.win.save, v.branch, v.selected.to_int(), v.selected.right(1))
			second = "해금함" if st == "idle" else ""
		else:
			id = Research.tree(v.branch)[v.selected.to_int()]
			var top := BaseUpgrades.max_level(id)
			if top > 1 and not Research.is_soon(id):
				second = "%d/%d단계" % [v.win.save.level_of(id), top]
		WindowArt.text(self, Vector2i(x, 5), name_, light)
		if second != "":
			WindowArt.text(self, Vector2i(w - BTN_W - 12 - (22 if fork else 0), 5), second, WindowArt.MUTED, 1)
		var line: String = info["note"] if info.has("note") else v.effect_of(v.selected)
		var lines := WindowArt.wrap(line, limit)
		var color: Color = WindowArt.RED if info.has("note") and line.begins_with("광물") else (WindowArt.ORANGE if info.has("note") else WindowArt.GOLD)
		WindowArt.text(self, Vector2i(x, 20), lines[0] if not lines.is_empty() else "", color)


## 띠의 좌우 화살표
class ArrowButton extends Button:
	var dir := 1

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var cx := int(size.x) / 2
		var cy := int(size.y) / 2
		for i in 5:
			var h := 9 - i * 2
			draw_rect(Rect2(cx + (i - 2) * dir, cy - h / 2, 1, h), WindowArt.TEAL2)
