class_name DroneView
extends WindowView
## 드론 공장: 어두운 설계도 + "건설 예정" 표지판. 아직 지을 수 없다.


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	draw_rect(Rect2(0, 0, w, h), Color("#3a1c57"))
	draw_rect(Rect2(2, 2, w - 4, h - 4), WindowArt.DARK)
	for x in range(10, w - 2, 16):
		for y in range(10, h - 2, 16):
			draw_rect(Rect2(x, y, 1, 1), WindowArt.GREY)
	for x in range(2, w - 2, 64):
		draw_rect(Rect2(x, 2, 1, h - 4), WindowArt.GREY)
	for y in range(2, h - 2, 64):
		draw_rect(Rect2(2, y, w - 4, 1), WindowArt.GREY)
	var art := WindowArt.tex("blueprint")
	var k := 1 if win.compact else 2
	var aw := art.get_width() * k
	var ah := art.get_height() * k
	var sign_w := 150
	var sign_h := 34
	var note_w := 170
	var total := aw + 40 + note_w
	var ax := (w - total) / 2
	var ay := (h - ah) / 2
	draw_texture_rect(art, Rect2(ax, ay, aw, ah), false)
	var line := Color("#4d80cd")
	draw_rect(Rect2(ax, ay - 8, aw, 1), line)
	draw_rect(Rect2(ax, ay - 12, 1, 9), line)
	draw_rect(Rect2(ax + aw, ay - 12, 1, 9), line)
	draw_rect(Rect2(ax + aw + 8, ay, 1, ah), line)
	draw_rect(Rect2(ax + aw + 4, ay, 9, 1), line)
	draw_rect(Rect2(ax + aw + 4, ay + ah, 9, 1), line)
	var sx := ax + aw + 40 + (note_w - sign_w) / 2
	var sy := (h - sign_h - 50) / 2
	WindowArt.plate(self, "sign", Rect2(sx, sy, sign_w, sign_h), 12)
	WindowArt.text(self, Vector2i(sx + sign_w / 2, sy + 10), "건설 예정", WindowArt.DARK, 0)
	var ny := sy + sign_h + 6
	WindowArt.plate(self, "tab", Rect2(ax + aw + 40, ny, note_w, 44))
	WindowArt.text(self, Vector2i(ax + aw + 40 + note_w / 2, ny + 8), "드론 공장 설계도", WindowArt.TEAL2, 0)
	WindowArt.text(self, Vector2i(ax + aw + 40 + note_w / 2, ny + 23), "완공되면 채굴 드론 제작", WindowArt.INK, 0)
