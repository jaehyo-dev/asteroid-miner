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
# 빛기둥 (받침 그림 한 칸 기준)
const BEAM_HALF := 34  # 기둥 반폭: 윗면 고리 바로 안쪽
const BEAM_FRONT := 16  # 윗면 타원 앞쪽 깊이: 기둥 아래가 이 호를 따라 끝난다
const BEAM_DARK := Color("#125952")
const BEAM_MID := Color("#1da775")
const BEAM_LIGHT := Color("#30e1b9")
const BEAM_SPARK := Color("#99e9e6")
const SCAN_PERIOD := 6.0  # 주사선이 아래에서 위까지 가는 시간 (둘이 반 주기 어긋나게)
const GRAINS := 7
const GRAIN_PERIOD := 3.0

var _t := 0.0
var _stats: Array = []
var _fighter: Dictionary
var _beam: Array[ImageTexture] = []  # [평소, 깜빡임]
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
	var src := Rect2(i % 8 * SPIN.x, i / 8 * SPIN.y, SPIN.x, SPIN.y)
	# 그림자는 받침과 같은 배율로 윗면 타원 안에만 놓고, 기둥 위·우주선 아래에 그린다
	var shw := SPIN.x * k
	var shh := SPIN.y * k
	draw_texture_rect_region(WindowArt.tex("spin_shadow"), Rect2(cx - shw / 2, mid - shh / 2, shw, shh), src)
	var sw := SPIN.x * ship_k
	var sh := SPIN.y * ship_k
	var bob := int(round(sin(_t * TAU / 4.0) * 3.0))
	var lift := (LIFT_SMALL if win.compact else LIFT)
	draw_texture_rect_region(WindowArt.tex("spin"), Rect2(cx - sw / 2, mid - lift - sh / 2 + bob, sw, sh), src)


## 받침 위 빛기둥 그림을 칸 단위로 굽는다. flicker면 조금 옅게.
## 밝기 = 높이(아래 진함) × 가로(가장자리 밝음) → 잡음 디더로 색을 고르므로 위로 갈수록 성기게 사라진다
static func bake_beam(half: int, above: int, front: int, flicker := false) -> Image:
	var w := half * 2
	var img := Image.create(w, above + front, false, Image.FORMAT_RGBA8)
	var ramp: Array[Color] = [Color.TRANSPARENT, BEAM_DARK, BEAM_MID, BEAM_LIGHT]
	var dim := 0.86 if flicker else 1.0
	for cy in img.get_height():
		var t := clampf(1.0 - float(cy) / float(above), 0.0, 1.0)  # 0 = 받침 면, 1 = 맨 위
		for cx in w:
			var u := absf((cx + 0.5) / half - 1.0)  # 0 = 가운데, 1 = 가장자리
			if cy >= above and float(cy - above) >= front * sqrt(1.0 - u * u):
				continue  # 윗면 타원 앞쪽 호 바깥
			var level: float
			if cx == 0 or cx == w - 1:
				level = 3.4 * pow(1.0 - t, 0.9)  # 양옆 밝은 세로선, 위에서 흩어지며 사라짐
			else:
				level = 3.4 * pow(1.0 - t, 1.5) * (0.46 + 0.22 * pow(u, 5.0))
			# 줄무늬가 보이지 않게, 고른 잡음과 무작위 잡음을 반씩 섞어 디더링
			var ign := fposmod(52.9829189 * fposmod(0.06711056 * cx + 0.00583715 * cy, 1.0), 1.0)
			var noise := (ign + fposmod(sin(cx * 12.9898 + cy * 78.233) * 43758.5453, 1.0)) * 0.5
			img.set_pixel(cx, cy, ramp[clampi(int(level * dim + noise), 0, 3)])
	return img


func _draw_beam(cx: int, mid: int, top: int, k: int) -> void:
	var above := (mid - top) / k
	if above <= 0:
		return  # 레이아웃이 잡히기 전
	var key := Vector2i(k, above)
	if key != _beam_key:
		_beam_key = key
		_beam.clear()
		for f in [false, true]:
			_beam.append(ImageTexture.create_from_image(bake_beam(BEAM_HALF, above, BEAM_FRONT, f)))
	# 아주 약한 깜빡임: 0.1초 칸마다 정해진 무작위로 드물게
	var blink := fposmod(sin(floorf(_t * 10.0) * 12.9898) * 43758.5453, 1.0) < 0.07
	var half := BEAM_HALF * k
	draw_texture_rect(_beam[1 if blink else 0], Rect2(cx - half, top, half * 2, (above + BEAM_FRONT) * k), false)
	var height := mid - top
	# 주사선 2줄: 받침에서 올라가며 옅어지고 끊어진다
	for n in 2:
		var t := fposmod(_t / SCAN_PERIOD + n * 0.5, 1.0)
		var row := mid - int(t * height) / k * k
		var col := BEAM_LIGHT if t < 0.4 else (BEAM_MID if t < 0.7 else BEAM_DARK)
		var gap := 1 + int(t * t * 4.0)  # 위로 갈수록 성기게
		for c in range(1, BEAM_HALF * 2 - 1, gap):
			draw_rect(Rect2(cx - half + c * k, row, k, k), col)
	# 떠오르는 빛 알갱이: 자리·속도는 번호로 고정
	for n in GRAINS:
		var h := fposmod(sin(n * 78.233) * 43758.5453, 1.0)
		var t := fposmod(_t / (GRAIN_PERIOD * (1.0 + h)) + h, 1.0)
		var gx := cx - half + (2 + int(h * (BEAM_HALF * 2 - 4)) ) * k
		var gy := mid - int(t * height * 0.8) / k * k
		draw_rect(Rect2(gx, gy, k, k), BEAM_SPARK if t < 0.5 else (BEAM_LIGHT if t < 0.8 else BEAM_MID))


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
