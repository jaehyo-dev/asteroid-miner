class_name HangarView
extends WindowView
## 격납고: 아래 탭 [전투기 | 기본 무기] (v0.8.0 시안 B 수정안).
## 전투기 탭: 우주선 능력치 + 홀로그램 받침 위 회전 우주선(카메라 35도) + 설명 + 전투기 칸.
## 기본 무기 탭: 고른 무기로 바꿨을 때 우주선 능력치(오르면 초록 ▲, 내리면 빨강 ▼) + 받침 위 우주선(탭과 상관없이 항상)
## + 설명(무기 그림, 작은 4칸 막대, 장착 / 장착 중 / [구매 ◆가격]) + 무기 카드 5장.

const SPIN := Vector2i(64, 56)
const FRAMES := 40
const SPIN_FPS := 13.33  # 3초에 한 바퀴
const STAT_COLOR := {"체력": "hull", "사망 보존": "hull", "공격력": "weapon", "공격 속도": "weapon", "사거리": "weapon", "이동 속도": "mine", "화물칸": "mine", "자석 범위": "mine"}
## 무기를 바꿨을 때 능력치가 오르면 ▲, 내리면 ▼
const UP_COLOR := Color("#a5cc5f")
const DOWN_COLOR := Color("#f25c76")
## 무기를 샀을 때 설명 칸 번쩍임 (초)
const BUY_FLASH := 0.3
const PLAY := {"pioneer": "무엇이든 무난하게 해내는 전투기."}
## 무기 능력치 4칸 색 (모든 화면 같은 순서: Weapons.bars)
const BAR_COLOR := {"공격력": Color("#dc7f47"), "사거리": Color("#99e9e6"), "연사": Color("#f25c76"), "채굴량": Color("#f6ce50")}
## 잠긴 무기 그림 색 (윤곽만)
const LOCKED_TINT := Color("#3a1c57")
const TABS := ["fighter", "weapon"]
const TAB_NAME := {"fighter": "전투기", "weapon": "기본 무기"}
const RING_TOP := 8
const LIFT := 62  # 받침 면에서 우주선 그림 가운데까지 (그림자와 떨어지게)
const LIFT_SMALL := 40
# 빛기둥 (받침 그림 한 칸 기준). 무작위 점 없이 깔끔한 띠 + 경계 1~2줄 체크 디더만
const BEAM_HALF := 34  # 기둥 반폭: 윗면 고리 바로 안쪽
const BEAM_FRONT := 16  # 윗면 타원 앞쪽 깊이: 기둥 아래가 이 호를 따라 끝난다
const BEAM_NARROW := 0.18  # 맨 위에서 반폭이 이 비율만큼 좁아짐
const BEAM_DOME := 0.16  # 가장자리일수록 일찍 끝나 띠 경계와 윗끝이 둥글다
## 빛기둥 색 (진하기 2번 "보통" 확정): 표는 [이 높이까지(0 = 받침 면, 1 = 맨 위), 색], 아래부터.
## 채운 띠는 아래쪽에만 두고 위는 배경이 비친다 (가장자리 선·빛줄기만 더 올라가 둥글게 사라짐)
const BEAM := {"bands": [[0.16, "#125952"], [0.34, "#355148"], [0.52, "#3c3544"]],
	"edge": [[0.35, "#30e1b9"], [0.62, "#1da775"], [0.85, "#125952"]], "streak": [[0.45, "#1da775"], [0.75, "#125952"]]}
const BEAM_STREAKS := [-0.5, 0.14, 0.6]  # 세로 빛줄기 자리 (반폭 비율)
const SCAN_PERIOD := 5.0  # 주사선이 받침에서 위까지 가는 시간
const SCAN_TOP := 0.85
const GRAINS := [-0.62, -0.22, 0.3, 0.68]  # 떠오르는 빛 알갱이 자리, 차례로 1초씩 어긋남
const GRAIN_PERIOD := 4.0
const GRAIN_TOP := 0.72
const GRAIN_COLORS := [[0.3, "#99e9e6"], [0.55, "#30e1b9"], [1.0, "#1da775"]]

var _t := 0.0
var _stats: Array = []
var _pick_stats: Array = []  # 고른 무기로 바꿨을 때 (무기 탭 ▲▼)
var _flash := 0.0
var _fighter: Dictionary
var _beam: ImageTexture
var _beam_key := Vector2i.ZERO
## 지금 탭과 고른 무기 (창 크기가 바뀌어 다시 만들어도 남게 static)
static var tab := "fighter"
static var picked := ""
var tab_buttons: Array[Button] = []
var cards: Array[Button] = []
## 설명 칸 버튼: 장착 / 장착 중(꺼짐) / 구매(광물 부족이면 꺼짐)
var action_button: WinButton
var _l := {}  # 배치 (_layout)


func setup() -> void:
	_fighter = Hangar.slots()[0]
	if not Weapons.has(picked):
		picked = Weapons.equipped(win.save)
	_layout()
	for i in TABS.size():
		var b := TabBtn.new()
		b.view = self
		b.id = TABS[i]
		b.pressed.connect(_on_tab.bind(TABS[i]))
		add_child(b)
		tab_buttons.append(b)
	for id in Weapons.ids():
		var c := CardBtn.new()
		c.view = self
		c.id = id
		c.pressed.connect(_on_card.bind(id))
		add_child(c)
		cards.append(c)
	action_button = WinButton.new()
	action_button.pressed.connect(_on_action)
	action_button.denied.connect(func() -> void: Sfx.play("deny"))
	add_child(action_button)
	_place()
	_refresh_stats()


## 배치: PC는 탭이 왼쪽 능력치 아래(카드 줄 위), 폰은 능력치 줄과 붙지 않게 가운데 받침 칸 위쪽
func _layout() -> void:
	var w := int(size.x)
	var h := int(size.y)
	var small := win.compact
	var slot_h := 36 if small else 44
	var tab_h := 20
	var area_h := h - slot_h - 4
	var stats_w := 130 if small else 146  # 폰: "공격 속도 0.6발/초 ▼"가 한 줄에 들어가게
	var desc_w := 132 if small else 170
	_l = {"w": w, "h": h, "slot_h": slot_h, "tab_h": tab_h, "area_h": area_h, "stats_w": stats_w, "desc_w": desc_w,
		"stats_h": area_h if small else area_h - tab_h - 6, "stage_top": tab_h + 4 if small else 0}
	var tw := [WindowArt.width(TAB_NAME["fighter"]) + 20, WindowArt.width(TAB_NAME["weapon"]) + 20]
	var tx: int = stats_w + (w - stats_w - desc_w - tw[0] - tw[1] - 4) / 2 if small else 4
	var ty: int = 0 if small else area_h - tab_h - 2
	_l["tabs"] = [Rect2i(tx, ty, tw[0], tab_h), Rect2i(tx + tw[0] + 4, ty, tw[1], tab_h)]


func _place() -> void:
	for i in tab_buttons.size():
		var r: Rect2i = _l["tabs"][i]
		tab_buttons[i].position = r.position
		tab_buttons[i].size = r.size
	var n := cards.size()
	var cw := (int(_l["w"]) - (n - 1) * 4) / n
	for i in n:
		cards[i].position = Vector2(i * (cw + 4), int(_l["h"]) - int(_l["slot_h"]))
		cards[i].size = Vector2(cw, int(_l["slot_h"]))
		cards[i].visible = tab == "weapon"
	var desc_w: int = _l["desc_w"]
	var bh := 18 if win.compact else 22
	action_button.size = Vector2(desc_w - 16, bh)
	action_button.position = Vector2(int(_l["w"]) - desc_w + 8, int(_l["area_h"]) - bh - 6)
	_refresh_action()


func _refresh_action() -> void:
	action_button.visible = tab == "weapon"
	if not action_button.visible:
		return
	match weapon_state(picked):
		"on":
			action_button.set_info("장착 중", -1, true)
		"open":
			action_button.set_info("장착")
		_:
			var price := Weapons.cost(picked)
			action_button.set_info("구매", price, win.save.credits < price)  # 모자라면 꺼짐 + 위에 "광물 부족"


## 무기 상태: on 장착 중, open 해금됨, lock 잠김
func weapon_state(id: String) -> String:
	if Weapons.equipped(win.save) == id:
		return "on"
	return "open" if Weapons.unlocked(win.save, id) else "lock"


func _on_tab(id: String) -> void:
	Sfx.play("click")
	select_tab(id)


func select_tab(id: String) -> void:
	tab = id
	_place()
	for b in tab_buttons:
		b.queue_redraw()
	queue_redraw()


func _on_card(id: String) -> void:
	Sfx.play("click")
	pick(id)


func pick(id: String) -> void:
	picked = id
	_pick_stats = Hangar.stats(Research.run_levels(win.save), win.save, id)
	_refresh_action()
	for c in cards:
		c.queue_redraw()
	queue_redraw()


## 설명 칸 버튼: 해금한 무기는 장착, 잠긴 무기는 광물로 사서 바로 장착 (둘 다 저장)
func _on_action() -> void:
	match weapon_state(picked):
		"open":
			Sfx.play("click")
			Weapons.equip(win.save, picked)
		"lock":
			if not Weapons.buy(win.save, picked):
				return
			Sfx.play("upgrade")
			_flash = BUY_FLASH
			win.refresh_head()  # 머리줄 광물 수
		_:
			return
	win.save.save_file()
	_refresh_stats()


func _refresh_stats() -> void:
	_stats = Hangar.stats(Research.run_levels(win.save), win.save)
	pick(picked if Weapons.has(picked) else Weapons.equipped(win.save))


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var area_h: int = _l["area_h"]
	var stats_w: int = _l["stats_w"]
	var desc_w: int = _l["desc_w"]
	var w: int = _l["w"]
	var h: int = _l["h"]
	var top: int = _l["stage_top"]
	_draw_stats(4, 2, stats_w - 8, int(_l["stats_h"]) - 2)
	_draw_stage(stats_w, top, w - stats_w - desc_w, area_h - top)
	if tab == "fighter":
		_draw_desc(w - desc_w, 0, desc_w, area_h)
		var slots := Hangar.slots()
		var sw := (w - 3 * 4) / 4
		for i in 4:
			_draw_slot(i * (sw + 4), h - int(_l["slot_h"]), sw, int(_l["slot_h"]), slots[i] if i < slots.size() else {"locked": true}, i == 0)
	else:
		_draw_weapon_desc(w - desc_w, 0, desc_w, area_h)


## 우주선 능력치. 무기 탭에서는 고른 무기로 바꿨을 때 값이고, 지금과 다르면 값 오른쪽에 ▲(초록)·▼(빨강)
func _draw_stats(x: int, y: int, w: int, h: int) -> void:
	var rows := _pick_stats if tab == "weapon" and not _pick_stats.is_empty() else _stats
	var gap := h / rows.size()
	var bar_at := 12
	for i in rows.size():
		var st: Dictionary = rows[i]
		var ry := y + i * gap
		var light: Color = WindowArt.BRANCH[STAT_COLOR[st["name"]]][1]
		var d := stat_delta(i)
		var vx := x + w - (7 if d != 0 else 0)  # 화살표 자리
		WindowArt.text(self, Vector2i(x, ry - 2), st["name"], light)
		WindowArt.text(self, Vector2i(vx, ry - 2), st["value"], WindowArt.INK if d == 0 else (UP_COLOR if d > 0 else DOWN_COLOR), 1)
		if d != 0:
			_arrow(x + w - 5, ry + 2, d > 0)
		if win.compact:  # 폰은 8줄이 줄 간격 14픽셀에 들어가 3픽셀 막대면 다음 줄 글자에 닿는다: 1픽셀 한 줄로
			draw_rect(Rect2(x, ry + bar_at - 1, w, 1), WindowArt.DARK)
			draw_rect(Rect2(x, ry + bar_at - 1, int(w * float(st["ratio"])), 1), light)
		else:
			draw_rect(Rect2(x, ry + bar_at, w, 3), WindowArt.DARK)  # 글자 바로 아래, 다음 줄과 띄움
			draw_rect(Rect2(x + 1, ry + bar_at + 1, int((w - 2) * float(st["ratio"])), 1), light)


## 능력치 i줄: 고른 무기로 바꾸면 오르는지(1) 내리는지(-1) 같은지(0). 전투기 탭은 늘 0
func stat_delta(i: int) -> int:
	if tab != "weapon" or _pick_stats.size() != _stats.size():
		return 0
	return signi(roundi((float(_pick_stats[i]["num"]) - float(_stats[i]["num"])) * 100.0))


## 5칸 너비 삼각형 (위쪽 ▲ 또는 아래쪽 ▼), 왼쪽 위가 (x, y)
func _arrow(x: int, y: int, up: bool) -> void:
	var color := UP_COLOR if up else DOWN_COLOR
	for r in 3:
		var half := r if up else 2 - r
		draw_rect(Rect2(x + 2 - half, y + r * 2, half * 2 + 1, 2), color)


## 작은 무기 능력치 4칸 (설명 칸 안): 이름 + 5칸 막대 한 줄씩
func _draw_weapon_bars(x: int, y: int, w: int) -> int:
	var label_w := 42
	var row_h := 13 if win.compact else 15
	var seg := (w - label_w - 4 * 2) / 5
	for row: Dictionary in Weapons.bars(picked):
		var color: Color = BAR_COLOR[row["name"]]
		WindowArt.text(self, Vector2i(x, y), row["name"], color)
		for j in 5:
			var r := Rect2(x + label_w + j * (seg + 2), y + 5, seg, 3)
			draw_rect(r, WindowArt.DARK)
			if j < int(row["level"]):
				draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), color)
		y += row_h
	return y


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
	var top := y + 2
	_draw_beam(cx, mid, top, k)
	draw_texture_rect(WindowArt.tex("pedestal_ring"), Rect2(cx - pw / 2, py, pw, ph), false)  # 고리는 빛 앞에 다시
	var src := Rect2(i % 8 * SPIN.x, i / 8 * SPIN.y, SPIN.x, SPIN.y)
	# 그림자는 받침과 같은 배율로 윗면 타원 안에만 놓고, 기둥 위·우주선 아래에 그린다
	var shw := SPIN.x * k
	var shh := SPIN.y * k
	draw_texture_rect_region(WindowArt.tex("spin_shadow"), Rect2(cx - shw / 2, mid - shh / 2, shw, shh), src)
	var sw := SPIN.x * ship_k
	var sh := SPIN.y * ship_k
	var bob := int(round(sin(_t * TAU / 4.0) * 3.0))
	var lift := (LIFT_SMALL if win.compact else LIFT)
	draw_texture_rect_region(WindowArt.tex("spin_gold" if Discovery.gold_paint(win.save) else "spin"), Rect2(cx - sw / 2, mid - lift - sh / 2 + bob, sw, sh), src)


## 표에서 높이 s의 색 (넘으면 투명)
static func band_color(table: Array, s: float) -> Color:
	for row: Array in table:
		if s < row[0]:
			return Color(row[1])
	return Color.TRANSPARENT


## 높이 t(0 = 받침 면)에서 반폭 (칸)
static func beam_half(half: int, t: float) -> float:
	return half * (1.0 - BEAM_NARROW * t)


## 가로 위치의 띠 높이: 가장자리일수록 커져 둥글게 끝난다. dx = 가운데에서 떨어진 칸
static func beam_s(t: float, dx: float, hw: float) -> float:
	var u := minf(dx / hw, 1.0)
	return t + BEAM_DOME * (1.0 - sqrt(1.0 - u * u))


## 받침 위 빛기둥 그림을 칸 단위로 굽는다
static func bake_beam(half: int, above: int, front: int) -> Image:
	var st: Dictionary = BEAM
	var bands: Array = st["bands"]
	var w := half * 2
	var img := Image.create(w, above + front, false, Image.FORMAT_RGBA8)
	for cy in img.get_height():
		var t := clampf(float(above - cy) / float(above), 0.0, 1.0)
		var hw := beam_half(half, t)
		for cx in w:
			var dx := absf(cx + 0.5 - half)
			if dx > hw:
				continue
			if cy >= above and float(cy - above) >= front * sqrt(1.0 - pow(dx / half, 2.0)):
				continue  # 윗면 타원 앞쪽 호 바깥
			var s := beam_s(t, dx, hw)
			var col := Color.TRANSPARENT
			var line: Array = []
			if dx > hw - 1.0:
				line = st["edge"]  # 양옆 밝은 선
			elif BEAM_STREAKS.any(func(f: float) -> bool: return cx == int(half + f * hw)):
				line = st["streak"]
			# 선 끝 4줄은 한 줄 건너 하나씩만 찍어 부드럽게 끊긴다
			if not line.is_empty() and not ((line[-1][0] - s) * above < 4.0 and cy % 2 == 0):
				col = band_color(line, s)
			if col.a == 0.0:
				for j in bands.size():
					if s < bands[j][0]:
						col = Color(bands[j][1])
						# 띠 경계 바로 아래 2줄은 위 띠 색과 체크무늬로 섞는다
						if (bands[j][0] - s) * above < 2.0 and (cx + cy) % 2 == 0:
							col = Color(bands[j + 1][1]) if j + 1 < bands.size() else Color.TRANSPARENT
						break
			img.set_pixel(cx, cy, col)
	return img


func _draw_beam(cx: int, mid: int, top: int, k: int) -> void:
	var above := (mid - top) / k
	if above <= 0:
		return  # 레이아웃이 잡히기 전
	var key := Vector2i(k, above)
	if key != _beam_key:
		_beam_key = key
		_beam = ImageTexture.create_from_image(bake_beam(BEAM_HALF, above, BEAM_FRONT))
	var half := BEAM_HALF * k
	var left := cx - half
	draw_texture_rect(_beam, Rect2(left, top, half * 2, (above + BEAM_FRONT) * k), false)
	var st: Dictionary = BEAM
	# 주사선 1줄: 받침에서 천천히 올라가며 띠처럼 옅어진다
	var t := fposmod(_t / SCAN_PERIOD, 1.0) * SCAN_TOP
	var row := mid - int(t * above) * k
	var hw := beam_half(BEAM_HALF, t)
	for c in BEAM_HALF * 2:
		var dx := absf(c + 0.5 - BEAM_HALF)
		if dx <= hw - 1.0:
			var col := band_color(st["edge"], beam_s(t, dx, hw))
			if col.a > 0.0:
				draw_rect(Rect2(left + c * k, row, k, k), col)
	# 떠오르는 빛 알갱이: 자리와 출발 시각이 정해져 규칙적으로 오른다
	for n in GRAINS.size():
		var g := fposmod(_t / GRAIN_PERIOD + float(n) / GRAINS.size(), 1.0) * GRAIN_TOP
		var gx := BEAM_HALF + int(GRAINS[n] * beam_half(BEAM_HALF, g))
		draw_rect(Rect2(left + gx * k, mid - int(g * above) * k, k, k), band_color(GRAIN_COLORS, g / GRAIN_TOP))


## 무기 설명 칸: 이름·상태, 그림(PC는 이름 아래 2배, 폰은 이름 앞 1배), 작은 4칸 막대, 한 줄 설명. 버튼은 action_button (장착 / 장착 중 / 구매)
func _draw_weapon_desc(x: int, y: int, w: int, h: int) -> void:
	WindowArt.plate(self, "tab", Rect2(x, y, w, h))
	var info := Weapons.info(picked)
	var st := weapon_state(picked)
	var tx := x + 10
	var tw := w - 20
	var ty := y + 8
	var icon := WindowArt.tex("weapon_" + picked)
	var name_x := tx
	if win.compact:  # 폰은 칸이 낮아 이름 앞에 1배로. 칸이 좁아 그림의 투명 여백은 잘라 그린다
		var used := icon.get_image().get_used_rect()
		name_x += used.size.x + 4
		_draw_icon(icon, Rect2(tx, ty - 3 + used.position.y, used.size.x, used.size.y), st, used)
		ty += 3
	WindowArt.text(self, Vector2i(name_x, ty), info["name"], WindowArt.GOLD if st != "lock" else WindowArt.MUTED)
	var tag: String = {"on": "장착 중", "open": "장착 가능", "lock": "잠김"}[st]
	if name_x - tx + WindowArt.width(info["name"]) + 6 + WindowArt.width(tag) <= tw:
		WindowArt.text(self, Vector2i(x + w - 10, ty), tag, WindowArt.TEAL2 if st != "lock" else WindowArt.DIM, 1)
	ty += 16
	if not win.compact:
		var ir := Rect2(tx, ty, icon.get_width() * 2, icon.get_height() * 2)
		_draw_icon(icon, ir, st)
		ty += icon.get_height() * 2 + 6
	ty = _draw_weapon_bars(tx, ty, tw) + 3
	var poor := st == "lock" and win.save.credits < Weapons.cost(picked)
	var bottom := int(action_button.position.y) - (18 if poor else 4)
	var lines := WindowArt.wrap(info["desc"], tw)
	if ty + lines.size() * 14 - 2 <= bottom:  # 설명이 다 들어갈 때만 (폰은 좁아서 중간에 잘리면 안 씀)
		for line in lines:
			WindowArt.text(self, Vector2i(tx, ty), line, WindowArt.INK)
			ty += 14
	if poor:
		WindowArt.text(self, Vector2i(x + w / 2, int(action_button.position.y) - 16), "광물 부족", WindowArt.RED, 0)
	if _flash > 0.0:
		draw_rect(Rect2(x + 2, y + 2, w - 4, h - 4), Color(1, 1, 1, 0.35 * _flash / BUY_FLASH))


## 설명 칸 무기 그림(src: 그림에서 쓸 부분): 잠겼으면 어둡게, 산 순간 짧게 번쩍임
func _draw_icon(icon: Texture2D, r: Rect2, st: String, src := Rect2(Vector2.ZERO, icon.get_size())) -> void:
	draw_texture_rect_region(icon, r, src, LOCKED_TINT if st == "lock" else Color.WHITE)
	if _flash > 0.0:
		draw_texture_rect_region(icon, r, src, Color(1, 1, 1, _flash / BUY_FLASH))


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
	var weapon := Weapons.info(Weapons.equipped(win.save))
	var icon := WindowArt.tex("weapon_" + weapon["id"])
	if win.compact:
		WindowArt.text(self, Vector2i(tx, ty), weapon["name"], WindowArt.TEAL2)
		ty += 14
	else:
		WindowArt.text(self, Vector2i(tx, ty), "기본 무기", WindowArt.MUTED)
		ty += 15
		draw_texture_rect(icon, Rect2(tx, ty, icon.get_width() * 2, icon.get_height() * 2), false)
		WindowArt.text(self, Vector2i(x + w - 10, ty + 18), weapon["name"], WindowArt.TEAL2, 1)
		ty += icon.get_height() * 2 + 4
	for line in WindowArt.wrap(weapon["desc"], tw):
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
		var ship := load("res://assets/sprites/station/ship_gold.png" if Discovery.gold_paint(win.save) else "res://assets/sprites/station/ship.png") as Texture2D
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


## [전투기 | 기본 무기] 탭: 고른 탭은 밝은 판 + 금빛 테두리
class TabBtn extends Button:
	var view: HangarView
	var id := ""

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var on := HangarView.tab == id
		WindowArt.plate(self, "tab", Rect2(Vector2.ZERO, size), -1, -1, Color.WHITE if on else Color(0.65, 0.65, 0.65))
		if on:
			draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), WindowArt.GOLD, false, 1.0)
		WindowArt.text(self, Vector2i(int(size.x) / 2, (int(size.y) - WindowArt.FONT_SIZE) / 2 - 2), HangarView.TAB_NAME[id], WindowArt.GOLD if on else WindowArt.MUTED, 0)
		WindowArt.focus_mark(self)


## 무기 카드: 상태(장착 중 / 장착 / 가격). PC는 그림 + 아래 줄에 이름, 폰은 좁아서 짧은 이름 + 상태 두 줄
class CardBtn extends Button:
	var view: HangarView
	var id := ""

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var st := view.weapon_state(id)
		var chosen := HangarView.picked == id
		var w := int(size.x)
		var h := int(size.y)
		WindowArt.plate(self, "tab", Rect2(0, 0, w, h), -1, -1, Color.WHITE if chosen or st == "on" else Color(0.7, 0.7, 0.7))
		if st == "on":
			draw_rect(Rect2(1, 1, w - 2, h - 2), WindowArt.GOLD, false, 1.0)
		elif chosen:
			draw_rect(Rect2(1, 1, w - 2, h - 2), WindowArt.TEAL2, false, 1.0)
		var icon := WindowArt.tex("weapon_" + id)
		var tint := HangarView.LOCKED_TINT if st == "lock" else Color.WHITE
		var small := view.win.compact
		if small:  # 폰 카드는 81픽셀이라 그림과 글자가 나란히 안 들어감: 그림(1배) 위, 상태 아래. 이름은 설명 칸에
			draw_texture(icon, Vector2((w - icon.get_width()) / 2, 2), tint)
			_status(w / 2, 19, st, 0)
		else:
			draw_texture(icon, Vector2(7, 5), tint)
			_status(w - 7, 5, st, 1)
			var info := Weapons.info(id)
			WindowArt.text(self, Vector2i(7, h - 19), info["name"], WindowArt.GOLD if st == "on" else (WindowArt.INK if st == "open" else WindowArt.MUTED))
		WindowArt.focus_mark(self)

	## 상태 글자 하나: 장착 중 / 장착 / [광물] 가격. align 0 가운데, 1 오른쪽 끝이 x
	func _status(x: int, y: int, st: String, align: int) -> void:
		if st != "lock":
			var label := "장착 중" if st == "on" else "장착"
			WindowArt.text(self, Vector2i(x, y), label, WindowArt.GOLD if st == "on" else WindowArt.TEAL2, align)
			return
		var price := Hud.thousands(Weapons.cost(id))
		var ore := RunSprites.mineral(3)
		var total := ore.get_width() + 2 + WindowArt.width(price)
		var left := x - (total / 2 if align == 0 else total)
		draw_texture(ore, Vector2(left, y + 2))
		WindowArt.text(self, Vector2i(left + ore.get_width() + 2, y), price, WindowArt.GOLD)
