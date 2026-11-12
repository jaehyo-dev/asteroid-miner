class_name MuseumView
extends WindowView
## 전시관: 등급 틀 진열장, 도감 보상 지점, 고른 칸 설명. 폰은 위아래로 끈다. 보상 규칙은 Discovery에 있다.

const RANK_OF := {"mineral_0": "common", "mineral_1": "rare", "mineral_2": "epic", "mineral_3": "legend", "rock_0": "common", "rock_1": "common", "jelly": "common", "bug": "common",
	"rock_2": "elite", "golden": "elite", "guard": "elite", "barrage": "boss"}
const RANK_NAME := {"common": "일반", "rare": "희귀", "epic": "영웅", "legend": "전설", "elite": "정예", "boss": "보스"}
const RANK_COLOR := {"common": Color("#fef8e5"), "rare": Color("#99e9e6"), "epic": Color("#a884f3"), "legend": Color("#f6ce50"), "elite": Color("#f89419"), "boss": Color("#f25c76")}
const SHORT := {"mineral_0": "어디서나 나오는 기본 광물.", "mineral_1": "푸른 결이 도는 광물.", "mineral_2": "운석 깊은 곳에서 나오는 광물.", "mineral_3": "아주 드문 광물.",
	"rock_0": "작지만 많이 떠다닌다.", "rock_1": "부수면 작은 조각으로 흩어진다.", "rock_2": "단단하고 광물이 많다. 부수면 화면이 흔들린다.", "golden": "습격 중에만 나타나는 금빛 운석.",
	"jelly": "천천히 끈질기게 쫓아온다.", "bug": "무리 지어 돌진한다.", "guard": "따라다니며 에너지탄을 쏜다. 좋은 광물을 준다.", "barrage": "심연에서 날아오는 포격. 부술 수 없다."}
const CASE := Vector2i(72, 76)
const HEAD_H := 20
const DETAIL_H := 26
## 진화 도감 (v0.8.0 5단계): 발견 칸 아래 따로 줄을 두고 발견 보상 수에는 세지 않는다. 진화는 금 틀 + 진홍 이름
const EVO_HEAD := 18
const EVO_COLOR := Color("#ff2567")
const REWARD_TEXT := {"credits": "광물 %d", "speed": "이동 속도 +%d%%", "keep": "사망 보존 +%d%%", "paint": "금빛 도색"}

## 고른 진열장 id와 고른 보상 id ("" = 없음)
var selected := ""
var reward := ""
var claim_button: WinButton
var _t := 0.0
var _cols := 6
var _cell := Vector2i(100, 94)
var _press := Vector2(-1, -1)
static var _evo_icons: Dictionary = {}


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)
	clip_contents = true
	_cols = 5 if win.compact else 6
	var grid_h := int(size.y) - HEAD_H - 4 - DETAIL_H - 2
	var rows := ceili(float(Discovery.ENTRIES.size()) / _cols) + _evo_rows()
	_cell = Vector2i((int(size.x) - 6) / _cols, maxi(CASE.y + 16, (grid_h - EVO_HEAD) / rows))
	max_scroll = maxi(0, rows * _cell.y + EVO_HEAD - grid_h)
	claim_button = WinButton.new()
	claim_button.size = Vector2(72, 22)
	claim_button.pressed.connect(_claim)
	claim_button.hide()
	add_child(claim_button)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _evo_rows() -> int:
	return ceili(float(Balance.EVOLUTIONS.size()) / _cols)


## 진화 도감 머리 줄의 y (스크롤 반영 전, 칸 맨 위 기준)
func _evo_top() -> int:
	return ceili(float(Discovery.ENTRIES.size()) / _cols) * _cell.y


func _found() -> int:
	return win.save.seen.size()


func _on_input(event: InputEvent) -> void:
	drag_input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.position
		elif not dragged:
			_click(Vector2i(event.position))


func _click(p: Vector2i) -> void:
	for r in Balance.CODEX_REWARDS:
		if _reward_rect(r).has_point(p):
			reward = r["id"]
			selected = ""
			Sfx.play("click")
			_update_claim()
			return
	var top := HEAD_H + 4 - scroll
	for i in Discovery.ENTRIES.size():
		var r := Rect2i(i % _cols * _cell.x, top + i / _cols * _cell.y, _cell.x, _cell.y)
		if r.has_point(p) and p.y >= HEAD_H + 4 and p.y < int(size.y) - DETAIL_H:
			selected = Discovery.ENTRIES[i]["id"]
			reward = ""
			Sfx.play("click")
			_update_claim()
			return
	var etop := top + _evo_top() + EVO_HEAD
	for i in Balance.EVOLUTIONS.size():
		var r := Rect2i(i % _cols * _cell.x, etop + i / _cols * _cell.y, _cell.x, _cell.y)
		if r.has_point(p) and p.y >= HEAD_H + 4 and p.y < int(size.y) - DETAIL_H:
			selected = Balance.EVOLUTIONS[i]["id"]
			reward = ""
			Sfx.play("click")
			_update_claim()
			return


func _bar_rect() -> Rect2i:
	var x := 4 + WindowArt.width("발견 12 / 12") + 10
	return Rect2i(x, 4, int(size.x) - x - 10, 9)


func _reward_rect(r: Dictionary) -> Rect2i:
	var bar := _bar_rect()
	var at := bar.position.x + (bar.size.x - 2) * Discovery.reward_needs(r) / Discovery.ENTRIES.size()
	var offset := 8 if int(r["at"]) == 0 else 0  # 마지막 지점 두 개(12개·전부)가 겹치지 않게
	return Rect2i(at - 7 - offset - (8 if int(r["at"]) == 12 and Discovery.reward_needs(r) == Discovery.ENTRIES.size() else 0), 0, 14, 16)


func _update_claim() -> void:
	if reward.is_empty():
		claim_button.hide()
		return
	var r := Discovery.reward_info(reward)
	var need := Discovery.reward_needs(r)
	claim_button.show()
	if win.save.codex_claimed.has(reward):
		claim_button.set_info("받음", -1, true)
	elif _found() >= need:
		claim_button.set_info("받기", -1, false)
	else:
		claim_button.set_info("%d개 더" % (need - _found()), -1, true)
	claim_button.position = Vector2(int(size.x) - 72 - 10, int(size.y) - DETAIL_H + 1)


func _claim() -> void:
	if Discovery.claim(win.save, reward):
		win.save.save_file()
		Sfx.play("pickup_3")
		win.refresh_head()
		_update_claim()


static func reward_text(r: Dictionary) -> String:
	var v := float(r["value"])
	match r["kind"]:
		"credits":
			return REWARD_TEXT["credits"] % int(v)
		"paint":
			return REWARD_TEXT["paint"]
	return REWARD_TEXT[r["kind"]] % roundi(v * 100.0)


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	var top := HEAD_H + 4
	var grid_h := h - top - DETAIL_H - 2
	var right := w - (6 if max_scroll > 0 else 0)
	var cell_w := right / _cols
	for i in Discovery.ENTRIES.size():
		_draw_case(Discovery.ENTRIES[i], (i % _cols) * cell_w + cell_w / 2, top - scroll + (i / _cols) * _cell.y)
	var ey := top - scroll + _evo_top()
	var made := win.save.evolved.size()
	WindowArt.text(self, Vector2i(4, ey + 2), "진화 도감 %d / %d" % [made, Balance.EVOLUTIONS.size()], EVO_COLOR)
	WindowArt.text(self, Vector2i(4 + WindowArt.width("진화 도감 6 / 6") + 8, ey + 2), "보조 무기 5단계 + 짝 스킬", WindowArt.MUTED)
	for i in Balance.EVOLUTIONS.size():
		_draw_evo_case(Balance.EVOLUTIONS[i], (i % _cols) * cell_w + cell_w / 2, ey + EVO_HEAD + (i / _cols) * _cell.y)
	# 위아래 줄이 끌린 칸을 덮는다
	draw_rect(Rect2(0, 0, w, top), Color("#2b1925"))
	draw_rect(Rect2(0, h - DETAIL_H - 2, w, DETAIL_H + 2), Color("#2b1925"))
	_draw_head(w)
	_draw_detail(w, h)
	if max_scroll > 0:
		draw_scroll_bar(Rect2i(0, top, w, grid_h), float(scroll) / float(max_scroll), float(grid_h) / float(grid_h + max_scroll), WindowArt.TEAL)


func _draw_case(e: Dictionary, cx: int, y: int) -> void:
	var known: bool = win.save.seen.has(e["id"])
	var rank: String = RANK_OF[e["id"]]
	var t := WindowArt.tex("case_" + rank if known else "case_off")
	var pad := 3 if known else 0
	var kx := cx - CASE.x / 2
	if e["id"] == selected:  # 고른 칸: 테두리 대신 칸 뒤 바탕을 옅게 밝힌다
		draw_rect(Rect2(kx - 3, y + 2, CASE.x + 6, CASE.y - 1), Color(WindowArt.INK, 0.18))
	draw_texture(t, Vector2(kx - pad, y - pad))
	var icon := WindowArt.discovery_icon(e["id"])
	var ix := cx - icon.get_width() / 2
	var iy := y + int(CASE.y * 0.79) - icon.get_height()
	draw_texture(icon, Vector2(ix, iy), Color.WHITE if known else Color.BLACK)
	if known:
		WindowArt.text(self, Vector2i(cx, y + CASE.y + 1), e["name"], RANK_COLOR[rank], 0)
	else:
		WindowArt.text(self, Vector2i(cx, iy + icon.get_height() / 2 - 7), "?", WindowArt.DIM, 0)
		WindowArt.text(self, Vector2i(cx, y + CASE.y + 1), "?", WindowArt.DIM, 0)


## 진화 칸: 만든 것은 금 틀 + 진화 그림 + 이름, 못 만든 것은 꺼진 틀 + 검은 실루엣 + "?"
func _draw_evo_case(e: Dictionary, cx: int, y: int) -> void:
	var known: bool = win.save.evolved.has(e["id"])
	var t := WindowArt.tex("case_legend" if known else "case_off")
	var pad := 3 if known else 0
	var kx := cx - CASE.x / 2
	if e["id"] == selected:  # 고른 칸: 테두리 대신 칸 뒤 바탕을 옅게 밝힌다
		draw_rect(Rect2(kx - 3, y + 2, CASE.x + 6, CASE.y - 1), Color(WindowArt.INK, 0.18))
	draw_texture(t, Vector2(kx - pad, y - pad))
	if not _evo_icons.has(e["id"]):  # 붙잡아 둔다: _draw에서 load만 하고 버리면 그리기 전에 풀려 흰 네모가 된다
		_evo_icons[e["id"]] = LevelCard.tex("icons/" + str(e["id"]))
	var icon: Texture2D = _evo_icons[e["id"]]
	var ix := cx - icon.get_width() / 2
	var iy := y + int(CASE.y * 0.79) - icon.get_height()
	draw_texture(icon, Vector2(ix, iy), Color.WHITE if known else Color.BLACK)
	if known:
		WindowArt.text(self, Vector2i(cx, y + CASE.y + 1), e["name"], EVO_COLOR, 0)
	else:
		WindowArt.text(self, Vector2i(cx, iy + icon.get_height() / 2 - 7), "?", WindowArt.DIM, 0)
		WindowArt.text(self, Vector2i(cx, y + CASE.y + 1), "?", WindowArt.DIM, 0)


func _draw_head(_w: int) -> void:
	var found := _found()
	var total := Discovery.ENTRIES.size()
	WindowArt.text(self, Vector2i(4, 2), "발견 %d / %d" % [found, total], WindowArt.INK)
	var bar := _bar_rect()
	draw_rect(Rect2(bar), WindowArt.DARK)
	draw_rect(Rect2(bar).grow(-1), WindowArt.GREY)
	draw_rect(Rect2(bar.position.x + 1, bar.position.y + 1, (bar.size.x - 2) * found / total, bar.size.y - 2), WindowArt.TEAL)
	var crate := WindowArt.tex("crate_s")
	var pulse := 0.65 + 0.35 * sin(_t * TAU)
	for r in Balance.CODEX_REWARDS:
		var at := _reward_rect(r)
		var pos := Vector2(at.position.x, bar.position.y + 4 - crate.get_height() / 2)
		if reward == r["id"]:  # 고른 상자: 테두리 대신 뒤 바탕을 옅게 밝힌다
			draw_rect(Rect2(pos - Vector2(2, 2), crate.get_size() + Vector2(4, 4)), Color(WindowArt.INK, 0.18))
		if win.save.codex_claimed.has(r["id"]):
			draw_texture(crate, pos, Color(0.6, 0.6, 0.6))
			draw_line(pos + Vector2(3, 8), pos + Vector2(6, 11), WindowArt.TEAL2, 2.0)
			draw_line(pos + Vector2(6, 11), pos + Vector2(12, 3), WindowArt.TEAL2, 2.0)
		elif _found() >= Discovery.reward_needs(r):
			draw_texture(crate, pos, Color(1.0, 1.0, 1.0).lerp(WindowArt.GOLD, 1.0 - pulse))  # 받을 수 있음: 금빛으로 깜빡 (테두리 없이)
		else:
			draw_texture(crate, pos, Color(0.5, 0.5, 0.5))


func _draw_detail(w: int, h: int) -> void:
	var y := h - DETAIL_H
	WindowArt.plate(self, "head", Rect2(0, y, w, DETAIL_H))
	var ty := y + (DETAIL_H - 12) / 2 - 1
	if not reward.is_empty():
		var r := Discovery.reward_info(reward)
		var title := "전부 발견 보상" if int(r["at"]) == 0 else "%d개 발견 보상" % int(r["at"])
		WindowArt.text(self, Vector2i(12, ty), title, WindowArt.GOLD)
		WindowArt.text(self, Vector2i(12 + WindowArt.width(title) + 8, ty), reward_text(r), WindowArt.INK)
		return
	if selected.is_empty():
		WindowArt.text(self, Vector2i(12, ty), "칸이나 상자를 누르면 설명이 나와요", WindowArt.MUTED)
		return
	var evo := SubWeapons.evo_info(selected)
	if not evo.is_empty():  # 진화: 만들었으면 이름 + 조합법, 아니면 짝 하나만 힌트
		var sub_name: String = SubWeapons.info(evo["sub"])["name"]
		var known: bool = win.save.evolved.has(selected)
		var title: String = evo["name"] if known else "???"
		WindowArt.text(self, Vector2i(12, ty), title, EVO_COLOR if known else WindowArt.MUTED)
		var recipe: String = sub_name + " + " + (Upgrades.display_name(evo["skill"]) if known else "?")
		var rx := 12 + WindowArt.width(title) + 8
		var fit := WindowArt.wrap(recipe if known else "힌트: " + recipe, w - rx - 10)
		if not fit.is_empty():
			WindowArt.text(self, Vector2i(rx, ty), fit[0], WindowArt.INK if known else WindowArt.MUTED)
		return
	if not win.save.seen.has(selected):
		WindowArt.text(self, Vector2i(12, ty), "아직 못 찾았어요", WindowArt.MUTED)
		return
	var entry: Dictionary = Discovery.ENTRIES.filter(func(e: Dictionary) -> bool: return e["id"] == selected)[0]
	var rank: String = RANK_OF[selected]
	WindowArt.text(self, Vector2i(12, ty), entry["name"], WindowArt.GOLD)
	var nx := 12 + WindowArt.width(entry["name"]) + 6
	WindowArt.text(self, Vector2i(nx, ty), RANK_NAME[rank], RANK_COLOR[rank])
	nx += WindowArt.width(RANK_NAME[rank]) + 6
	var lines := WindowArt.wrap(SHORT[selected], w - nx - 10)
	if not lines.is_empty():
		WindowArt.text(self, Vector2i(nx, ty), lines[0], WindowArt.INK)
