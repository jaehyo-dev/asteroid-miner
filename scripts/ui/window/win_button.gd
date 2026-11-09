class_name WinButton
extends Button
## 창 안 버튼: 판 그림 + 글자 + 광물 가격. text는 비워 두고 label·cost로 그린다.

var label := ""
var cost := -1
const MARGIN_X := 12


func _init(new_label := "", new_cost := -1) -> void:
	label = new_label
	cost = new_cost
	flat = true
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_info(new_label: String, new_cost := -1, off := false) -> void:
	label = new_label
	cost = new_cost
	disabled = off
	queue_redraw()


func _draw() -> void:
	var down := is_pressed() or get_draw_mode() == DRAW_PRESSED
	var name_ := "btn_off" if disabled else ("btn_down" if down else "btn")
	var y := 1 if down and not disabled else 0
	WindowArt.plate(self, name_, Rect2(0, y, size.x, size.y - 1), MARGIN_X)
	var color := WindowArt.GREY if disabled else (WindowArt.INK if down else WindowArt.DARK)
	var ty := int(size.y - WindowArt.FONT_SIZE) / 2 - 2 + y
	if cost < 0:
		WindowArt.text(self, Vector2i(int(size.x) / 2, ty), label, color, 0)
	else:
		var s := Hud.thousands(cost)
		var ore := RunSprites.mineral(3)
		var total := WindowArt.width(label) + 6 + 14 + WindowArt.width(s)
		var x := (int(size.x) - total) / 2
		WindowArt.text(self, Vector2i(x, ty), label, color)
		x += WindowArt.width(label) + 6
		draw_texture(ore, Vector2(x, ty + (WindowArt.FONT_SIZE - ore.get_height()) / 2 + 2))
		WindowArt.text(self, Vector2i(x + 14, ty), s, color)
	WindowArt.focus_mark(self)
