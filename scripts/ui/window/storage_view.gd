class_name StorageView
extends WindowView
## 광물 금고: 금고 그림과 총가치, 등급별 탱크. 탱크에 찬 더미는 개수의 로그 눈금 (1,000개면 가득). 폰은 위아래로 끈다.

const TANK_W := 88
const TANK_H := 196
const INNER := Rect2i(14, 50, 59, 118)
const GRADE_COLOR := [Color("#a5b29d"), Color("#99e9e6"), Color("#a884f3"), Color("#f6ce50")]
const LEFT_W := 176
const TOP_SMALL := 22

var _top := 0
var _spark := 0.0


func setup() -> void:
	gui_input.connect(_input_drag)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	max_scroll = maxi(0, TOP_SMALL + TANK_H + 34 + 4 - int(size.y)) if win.compact else maxi(0, TANK_H + 34 - int(size.y))


func _input_drag(event: InputEvent) -> void:
	drag_input(event)


func _process(delta: float) -> void:
	_spark += delta
	queue_redraw()


## 더미 그림 칸 번호: 개수 이하 중 가장 큰 눈금
static func pile_step(count: int) -> int:
	var step := -1
	for i in Balance.TANK_PILE_COUNTS.size():
		if count >= Balance.TANK_PILE_COUNTS[i]:
			step = i
	return step


func _draw() -> void:
	var w := int(size.x)
	var hauled := win.save.hauled
	var x0 := 0
	var y0 := -scroll
	if win.compact:
		WindowArt.text(self, Vector2i(w / 2 - 6, y0 + 2), "보유 광물 총가치 %s · 지금까지 가져온 광물" % Hud.thousands(win.save.credits), WindowArt.TEAL2, 0)
		y0 += TOP_SMALL
	else:
		x0 = LEFT_W + 10
		var v := WindowArt.tex("vault")
		var vy := (int(size.y) - v.get_height() - 90) / 2
		draw_texture(v, Vector2((LEFT_W - v.get_width()) / 2, vy))
		var ty := vy + v.get_height() + 18
		WindowArt.text(self, Vector2i(LEFT_W / 2, ty), "보유 광물 총가치", WindowArt.TEAL2, 0)
		var money := Hud.thousands(win.save.credits)
		var ore := RunSprites.mineral(3)
		var mx := (LEFT_W - WindowArt.width(money) - ore.get_width() - 4) / 2
		draw_texture(ore, Vector2(mx, ty + 18))
		WindowArt.text(self, Vector2i(mx + ore.get_width() + 4, ty + 16), money, WindowArt.GOLD)
		WindowArt.text(self, Vector2i(LEFT_W / 2, ty + 34), "지금까지 기지로 가져온 광물", WindowArt.MUTED, 0)
		y0 = (int(size.y) - TANK_H - 34) / 2
	var right := w - (6 if max_scroll > 0 else 0)
	var pitch := (right - x0) / 4
	for g in 4:
		var tx := x0 + g * pitch + (pitch - TANK_W) / 2
		draw_texture(WindowArt.tex("tank"), Vector2(tx, y0))
		var step := pile_step(hauled[g])
		if step >= 0:
			draw_texture_rect_region(WindowArt.tex("pile_%d" % g), Rect2(tx + INNER.position.x, y0 + INNER.position.y, INNER.size.x, INNER.size.y), Rect2(step * INNER.size.x, 0, INNER.size.x, INNER.size.y))
			draw_rect(Rect2(tx + INNER.position.x + 2, y0 + INNER.position.y + 4, 1, INNER.size.y - 10), WindowArt.TEAL2)  # 유리 반사선을 더미 위에
			_twinkle(tx, y0, g, hauled[g])
		var cx := tx + TANK_W / 2
		WindowArt.text(self, Vector2i(cx, y0 + TANK_H + 3), "%s 광물" % Balance.MINERAL_GRADES[g]["name"].trim_suffix(" 광물"), GRADE_COLOR[g], 0)
		WindowArt.text(self, Vector2i(cx, y0 + TANK_H + 18), "%s개" % Hud.thousands(hauled[g]), WindowArt.INK, 0)
	if max_scroll > 0:
		var r := Rect2i(0, 0, w, int(size.y))
		draw_scroll_bar(r, float(scroll) / float(max_scroll), float(size.y) / float(int(size.y) + max_scroll), WindowArt.TEAL)


## 더미 위 잠깐 켜지는 십자 반짝임 (가벼운 코드 그림)
func _twinkle(tx: int, y0: int, g: int, count: int) -> void:
	var fill := minf(log(count + 1.0) / log(10.0) / 3.0, 1.0)
	var top_h := int(INNER.size.y * fill)
	for n in 3:
		var t := fmod(_spark * 0.5 + n * 0.37 + g * 0.21, 1.0)
		if t >= 0.2:
			continue
		var px := tx + INNER.position.x + 8 + ((n * 23 + g * 11) % (INNER.size.x - 16))
		var py := y0 + INNER.position.y + INNER.size.y - 4 - ((n * 31 + g * 7) % maxi(top_h - 4, 1))
		var arm := 1 if t < 0.07 or t > 0.14 else 2
		draw_rect(Rect2(px - arm, py, arm * 2 + 1, 1), WindowArt.INK)
		draw_rect(Rect2(px, py - arm, 1, arm * 2 + 1), WindowArt.INK)
