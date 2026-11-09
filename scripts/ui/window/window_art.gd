class_name WindowArt
extends RefCounted
## 건물 창 그림·글자 도우미. 창 안은 논리 픽셀 격자 하나(글자 12칸)로만 그린다. 그림은 tools/export_window_art.py가 만든다.

const DIR := "res://assets/sprites/window/"
const FONT_SIZE := 12
const INK := Color("#fef8e5")
const MUTED := Color("#a5b29d")
const DIM := Color("#70525e")
const DARK := Color("#14111c")
const PLATE := Color("#2b1925")
const TEAL := Color("#30e1b9")
const TEAL2 := Color("#99e9e6")
const GOLD := Color("#f6ce50")
const RED := Color("#f25c76")
const ORANGE := Color("#dc7f47")
const GREY := Color("#3c3544")
## 가지 색: 본색, 밝은 색, 관 속 그늘
const BRANCH := {
	"weapon": [Color("#cb3738"), Color("#f25c76"), Color("#6f2626")],
	"hull": [Color("#4d80cd"), Color("#99e9e6"), Color("#3a1c57")],
	"mine": [Color("#f89419"), Color("#f6ce50"), Color("#984633")],
	"elec": [Color("#6b3e75"), Color("#a884f3"), Color("#3a1c57")],
	"survey": [Color("#77931e"), Color("#a5cc5f"), Color("#355148")],
}
const BRANCH_NAME := {"weapon": "무기", "hull": "선체", "mine": "채굴", "elec": "전자", "survey": "탐사"}

static var _tex := {}
static var _boxes := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]


static func font() -> Font:
	return ThemeDB.fallback_font


static func width(s: String) -> int:
	return ceili(font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)


## 글자. align: -1 왼쪽, 0 가운데, 1 오른쪽 (pos.x 기준). pos.y는 글자 위쪽
static func text(ci: CanvasItem, pos: Vector2i, s: String, color: Color, align := -1) -> void:
	var x := pos.x - (0 if align < 0 else (width(s) / 2 if align == 0 else width(s)))
	ci.draw_string(font(), Vector2(x, pos.y + roundi(font().get_ascent(FONT_SIZE))), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## 띄어쓰기에서 먼저 끊고, 안 되면 글자에서 끊는다
static func wrap(s: String, w: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for word in s.split(" "):
		var trial := (cur + " " + word).strip_edges()
		if width(trial) <= w:
			cur = trial
			continue
		if not cur.is_empty():
			lines.append(cur)
		cur = word
		while cur.length() > 1 and width(cur) > w:  # 폭이 아주 좁아도 멈추게
			var n := cur.length()
			while n > 1 and width(cur.left(n)) > w:
				n -= 1
			lines.append(cur.left(n))
			cur = cur.substr(n)
	if not cur.is_empty():
		lines.append(cur)
	return lines


## 9칸 판. mx·my를 안 주면 거의 절반(가운데 2칸만 늘어남)
static func plate(ci: CanvasItem, name: String, r: Rect2, mx := -1, my := -1, modulate := Color.WHITE) -> void:
	var id := "%s/%d/%d" % [name, mx, my]
	if not _boxes.has(id):
		var t := tex(name)
		var s := StyleBoxTexture.new()
		s.texture = t
		var ax := mx if mx >= 0 else t.get_width() / 2 - 1
		var ay := my if my >= 0 else t.get_height() / 2 - 1
		s.texture_margin_left = ax
		s.texture_margin_right = ax
		s.texture_margin_top = ay
		s.texture_margin_bottom = ay
		_boxes[id] = s
	var box: StyleBoxTexture = _boxes[id]
	box.modulate_color = modulate
	ci.draw_style_box(box, r)


## 도감 아이콘: 출격 화면과 같은 그림
static func discovery_icon(id: String) -> Texture2D:
	if id.begins_with("mineral_"):
		return RunSprites.mineral(int(id.substr(8)))
	if id.begins_with("rock_"):
		return RunSprites.icon(id)
	match id:
		"golden":
			return RunSprites.icon("rock_gold")
		"jelly", "bug", "guard":
			return RunSprites.icon(id)
	return PixelArt.barrage_icon()


## 단계 점: 찍은 만큼 밝게
static func pips(ci: CanvasItem, pos: Vector2i, lv: int, total: int, branch: String, sz := 5, gap := 1) -> void:
	var light: Color = BRANCH[branch][1]
	for i in total:
		var r := Rect2(pos + Vector2i(i * (sz + gap), 0), Vector2(sz, sz))
		ci.draw_rect(r, DARK)
		ci.draw_rect(r.grow(-1), light if i < lv else GREY)
