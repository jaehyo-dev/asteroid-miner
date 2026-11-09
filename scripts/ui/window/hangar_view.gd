class_name HangarView
extends WindowView
## 격납고: 능력치 + 홀로그램 받침 위 회전 그림(눕힌 우주선, 카메라 35도) + 설명 + 전투기 칸.

const SPIN := Vector2i(64, 56)
const FRAMES := 40
const SPIN_FPS := 13.33  # 3초에 한 바퀴
const STAT_COLOR := {"체력": "hull", "사망 보존": "hull", "공격력": "weapon", "공격 속도": "weapon", "이동 속도": "mine", "화물칸": "mine", "자석 범위": "mine"}
const PLAY := {"pioneer": "무엇이든 무난하게 해내는 전투기."}
const WEAPON := {"name": "펄스 연사포", "desc": "가까운 거리에서 빠른 연사로 앞을 쓸어 버립니다."}
const RING_TOP := 8

var _t := 0.0
var _stats: Array = []
var _fighter: Dictionary


func setup() -> void:
	_stats = Hangar.stats(Research.run_levels(win.save), win.save)
	_fighter = Hangar.slots()[0]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	var small := win.compact
	var slot_h := 32 if small else 44
	var area_h := h - slot_h - 4
	var stats_w := 118 if small else 146
	var desc_w := 132 if small else 170
	_draw_stats(4, 2, stats_w - 8, area_h - 2)
	_draw_stage(stats_w, 0, w - stats_w - desc_w, area_h)
	_draw_desc(w - desc_w, 0, desc_w, area_h)
	var slots := Hangar.slots()
	var sw := (w - 3 * 4) / 4
	for i in 4:
		_draw_slot(i * (sw + 4), h - slot_h, sw, slot_h, slots[i] if i < slots.size() else {"locked": true}, i == 0)


func _draw_stats(x: int, y: int, w: int, h: int) -> void:
	var gap := h / _stats.size()
	var bar_at := 12
	for i in _stats.size():
		var st: Dictionary = _stats[i]
		var ry := y + i * gap
		var light: Color = WindowArt.BRANCH[STAT_COLOR[st["name"]]][1]
		WindowArt.text(self, Vector2i(x, ry - 2), st["name"], light)
		WindowArt.text(self, Vector2i(x + w, ry - 2), st["value"], WindowArt.INK, 1)
		draw_rect(Rect2(x, ry + bar_at, w, 3), WindowArt.DARK)  # 글자 바로 아래, 다음 줄과 띄움
		draw_rect(Rect2(x + 1, ry + bar_at + 1, int((w - 2) * float(st["ratio"])), 1), light)


func _draw_stage(x: int, y: int, w: int, h: int) -> void:
	var cx := x + w / 2
	var ped := WindowArt.tex("pedestal")
	var k := 1 if win.compact else 2
	var pw := ped.get_width() * k
	var ph := ped.get_height() * k
	var py := y + h - ph - 2
	draw_texture_rect(ped, Rect2(cx - pw / 2, py, pw, ph), false)
	var mid := py + (RING_TOP + 17) * k  # 윗면 타원 가운데
	var i := int(_t * SPIN_FPS) % FRAMES
	var ship_k := 2 if win.compact else 3
	# 빛기둥: 점 줄무늬가 위로 사라진다
	var half0 := pw / 2 - 12 * k
	var yy := mid + 6 * k
	while yy > y + 6:
		var ratio := clampf(float(mid - yy) / float(maxi(mid - y - 6, 1)), 0.0, 1.0)
		var half := int(half0 * (1.0 - 0.25 * ratio))
		var step := 2 + int(ratio * 7)
		var off := (i + yy) % step
		var col := Color("#1da775") if ratio < 0.5 else Color("#125952")
		var xx := cx - half + off
		while xx < cx + half:
			draw_rect(Rect2(xx, yy, 1, 1), col)
			xx += step
		yy -= 3
	var src := Rect2(i % 8 * SPIN.x, i / 8 * SPIN.y, SPIN.x, SPIN.y)
	var sw := SPIN.x * ship_k
	var sh := SPIN.y * ship_k
	draw_texture_rect_region(WindowArt.tex("spin_shadow"), Rect2(cx - sw / 2, mid - sh / 2 + 2, sw, sh), src)
	var bob := int(round(sin(_t * TAU / 4.0) * 3.0))
	var lift := (34 if not win.compact else 22)
	draw_texture_rect_region(WindowArt.tex("spin"), Rect2(cx - sw / 2, maxi(y, mid - lift - sh / 2 + bob), sw, sh), src)


func _draw_desc(x: int, y: int, w: int, h: int) -> void:
	WindowArt.plate(self, "tab", Rect2(x, y, w, h))
	var tx := x + 10
	var tw := w - 20
	var ty := y + 8
	WindowArt.text(self, Vector2i(tx, ty), _fighter["name"], WindowArt.GOLD)
	WindowArt.text(self, Vector2i(x + w - 10, ty), _fighter["style"], WindowArt.TEAL2, 1)
	ty += 15
	for line in WindowArt.wrap(PLAY[_fighter["id"]], tw):
		WindowArt.text(self, Vector2i(tx, ty), line, WindowArt.INK)
		ty += 14
	ty += 2
	draw_rect(Rect2(tx, ty, tw, 1), WindowArt.GREY)
	ty += 3
	var icon := WindowArt.tex("weapon_pulse")
	if win.compact:
		WindowArt.text(self, Vector2i(tx, ty), WEAPON["name"], WindowArt.TEAL2)
		ty += 14
	else:
		WindowArt.text(self, Vector2i(tx, ty), "기본 무기", WindowArt.MUTED)
		ty += 15
		draw_texture_rect(icon, Rect2(tx, ty, icon.get_width() * 2, icon.get_height() * 2), false)
		WindowArt.text(self, Vector2i(x + w - 10, ty + 18), WEAPON["name"], WindowArt.TEAL2, 1)
		ty += icon.get_height() * 2 + 4
	for line in WindowArt.wrap(WEAPON["desc"], tw):
		if ty + 12 > y + h - 6:
			break
		WindowArt.text(self, Vector2i(tx, ty), line, WindowArt.INK)
		ty += 14


func _draw_slot(x: int, y: int, w: int, h: int, fighter: Dictionary, chosen: bool) -> void:
	WindowArt.plate(self, "tab", Rect2(x, y, w, h), -1, -1, Color.WHITE if chosen else Color(0.7, 0.7, 0.7))
	if chosen:
		draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), WindowArt.GOLD, false, 1.0)
	var locked := fighter.has("locked")
	var tx := x + 8
	if not win.compact:  # 폰은 칸이 좁아 글자만
		var ship := load("res://assets/sprites/station/ship.png") as Texture2D
		draw_texture(ship, Vector2(tx, y + (h - ship.get_height()) / 2 - 1), Color.BLACK if locked else Color.WHITE)
		tx += ship.get_width() + 6
	var ty := y + (h - 28) / 2 - 1
	if win.compact:  # 폰은 칸이 낮아 이름 한 줄만
		var line: String = "해금 조건 ???" if locked else fighter["name"]
		WindowArt.text(self, Vector2i(x + w / 2, y + (h - 12) / 2 - 2), line, WindowArt.DIM if locked else WindowArt.GOLD, 0)
		return
	if locked:
		WindowArt.text(self, Vector2i(tx, ty), "해금 조건", WindowArt.DIM)
		WindowArt.text(self, Vector2i(tx, ty + 14), "???", WindowArt.DIM)
	else:
		WindowArt.text(self, Vector2i(tx, ty), fighter["name"], WindowArt.GOLD if chosen else WindowArt.INK)
		WindowArt.text(self, Vector2i(tx, ty + 14), fighter["style"], WindowArt.TEAL2)
