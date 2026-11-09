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
var _fighter: Dictionary
var _beam: ImageTexture
var _beam_key := Vector2i.ZERO


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
