class_name RunSprites
extends RefCounted
## 출격 화면 그림 시트 (tools/build_run_sprites.py가 Foozle Void 팩과 Codex 그림으로 만든 assets/sprites/run/*.png).
## 8방향 시트는 열 = 프레임, 행 = 방향(PixelArt.dir8 번호, 0 = 위쪽). 깨지는 운석 시트(rock_*_boom)는 행이 하나다.
## 화면에서 돌리거나 늘이지 않고 칸 그대로 그려서 픽셀 격자가 유지된다.
## 화면에 그릴 때는 시트 대신 아틀라스 두 장(tools/build_run_atlas.py, 표는 RunAtlas)에서 잘라 그린다:
## 같은 텍스처의 사각형은 한 번에 묶여 그려져서 그리기 호출이 크게 줄어든다. 원·고리·선·점도 아틀라스의 흰 그림으로 그린다.

const DIR := "res://assets/sprites/run/"
## 시트 이름 → 칸 한 변 (픽셀)
const CELL := {
	"ship": 48, "ship_gold": 48, "ship_engine": 48, "ship_flame_idle": 48, "ship_flame_power": 48, "ship_cannon": 48, "bullet": 32, "drone": 16,
	"jelly": 64, "jelly_engine": 64, "jelly_boom": 64,
	"bug": 64, "bug_engine": 64, "bug_boom": 64,
	"guard": 64, "guard_engine": 64, "guard_boom": 64,
	"guard_shot": 16, "barrage_shot": 20,
	"rock_0": 64, "rock_0_boom": 64, "rock_1": 96, "rock_1_boom": 96, "rock_2": 144, "rock_2_boom": 144,
	"rock_gold": 96, "rock_gold_boom": 96,
}

const ATLAS_DIR := "res://assets/sprites/run_atlas/"
static var _tex := {}
static var _atlas: Array[Texture2D] = []


## 시트 텍스처
static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]


## 시트의 프레임 수 (열 수)
static func frames(name: String) -> int:
	return int(RunAtlas.ENTRIES[name][3]) / int(CELL[name])  # 표에서 읽어 시트 텍스처를 불러오지 않는다


## 프레임·방향의 칸 영역
static func region(name: String, frame: int, dir := 0) -> Rect2:
	var c: int = CELL[name]
	var rows := int(RunAtlas.ENTRIES[name][4]) / c
	return Rect2(posmod(frame, frames(name)) * c, posmod(dir, rows) * c, c, c)


## center(정수 픽셀)에 한 칸을 그린다.
static func draw(ci: CanvasItem, name: String, frame: int, dir: int, center: Vector2, modulate := Color.WHITE) -> void:
	var c: int = CELL[name]
	var top_left := center.round() - Vector2(c / 2, c / 2)
	var e: Array = RunAtlas.ENTRIES[name]
	var r := region(name, frame, dir)
	r.position += Vector2(e[1], e[2])
	ci.draw_texture_rect_region(atlas(e[0]), Rect2(top_left, Vector2(c, c)), r, modulate)


## 아틀라스 텍스처 (0 = 나머지·원·흰색, 1 = 운석)
static func atlas(index: int) -> Texture2D:
	if _atlas.is_empty():
		_atlas = [load(ATLAS_DIR + "atlas_0.png"), load(ATLAS_DIR + "atlas_1.png")]
	return _atlas[index]


## 아틀라스 안 그림 하나의 영역 (원판·고리·흰색·광물처럼 시트가 아닌 것)
static func entry_rect(name: String) -> Rect2:
	var e: Array = RunAtlas.ENTRIES[name]
	return Rect2(e[1], e[2], e[3], e[4])


## 흰 사각형을 색으로 칠한다 (draw_rect 대신: 같은 아틀라스라 묶여 그려짐). 흰 칸의 가운데만 써서 가장자리를 집지 않는다
static func rect(ci: CanvasItem, r: Rect2, color: Color) -> void:
	ci.draw_texture_rect_region(atlas(0), r, entry_rect("white").grow(-1.0), color)


## 선 (draw_line 대신): 흰 사각형을 a → b 방향으로 돌려 늘인다
static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 1.0) -> void:
	ci.draw_set_transform(a, (b - a).angle())
	rect(ci, Rect2(0.0, -width / 2.0, a.distance_to(b), width), color)
	ci.draw_set_transform(Vector2.ZERO)


## 채운 원 (draw_circle 대신): 반올림한 반지름의 픽셀 원판. MAX_RADIUS보다 크면 가장 큰 원판을 늘여 그린다
static func disc(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var r := roundi(radius)
	if r < 1:
		return
	var src := entry_rect("disc_%d" % mini(r, RunAtlas.MAX_RADIUS))
	ci.draw_texture_rect_region(atlas(0), Rect2(center - Vector2(r, r), Vector2(2 * r, 2 * r)), src, color)


## 굵기 1 고리 (draw_arc 대신). 반지름이 MAX_RADIUS보다 크면 늘이면 굵어지므로 draw_arc로 그린다
static func ring(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var r := roundi(radius)
	if r < 1:
		return
	if r > RunAtlas.MAX_RADIUS:
		ci.draw_arc(center, radius, 0.0, TAU, 40, color, 1.0)
		return
	var src := entry_rect("ring_%d" % r)
	ci.draw_texture_rect_region(atlas(0), Rect2(center - Vector2(r + 1, r + 1), src.size), src, color)


## 등급별 광물 그림을 top_left(정수 픽셀)에 그린다
static func draw_mineral(ci: CanvasItem, grade: int, top_left: Vector2) -> void:
	var src := entry_rect("mineral_%d" % clampi(grade, 0, 3))
	ci.draw_texture_rect_region(atlas(0), Rect2(top_left, src.size), src)


## 운석 시트 이름 (크기 번호, 황금 운석)
static func rock(type: int, golden: bool) -> String:
	return "rock_gold" if golden else "rock_%d" % type


## 등급별 광물 그림 (0 일반 ~ 3 전설)
static func mineral(grade: int) -> Texture2D:
	var key := "mineral_%d" % clampi(grade, 0, 3)
	if not _tex.has(key):
		_tex[key] = load(DIR + key + ".png")
	return _tex[key]


## 기지 화면 아이콘용: 시트의 한 칸(위쪽 방향)에서 그림이 있는 부분만 잘라 낸 텍스처
static func icon(name: String, frame := 0) -> Texture2D:
	var key := "icon_%s_%d" % [name, frame]
	if not _tex.has(key):
		var img := tex(name).get_image().get_region(Rect2i(region(name, frame)))
		_tex[key] = ImageTexture.create_from_image(img.get_region(img.get_used_rect()))
	return _tex[key]
