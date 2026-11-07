class_name RunSprites
extends RefCounted
## 출격 화면 그림 시트 (tools/build_run_sprites.py가 Foozle Void 팩과 Codex 그림으로 만든 assets/sprites/run/*.png).
## 8방향 시트는 열 = 프레임, 행 = 방향(PixelArt.dir8 번호, 0 = 위쪽). 깨지는 운석 시트(rock_*_boom)는 행이 하나다.
## 화면에서 돌리거나 늘이지 않고 칸 그대로 그려서 픽셀 격자가 유지된다.

const DIR := "res://assets/sprites/run/"
## 시트 이름 → 칸 한 변 (픽셀)
const CELL := {
	"ship": 48, "ship_engine": 48, "ship_flame_idle": 48, "ship_flame_power": 48, "ship_cannon": 48, "bullet": 32,
	"jelly": 64, "jelly_engine": 64, "jelly_boom": 64,
	"bug": 64, "bug_engine": 64, "bug_boom": 64,
	"guard": 64, "guard_engine": 64, "guard_boom": 64,
	"guard_shot": 16, "barrage_shot": 9,
	"rock_0": 64, "rock_0_boom": 64, "rock_1": 96, "rock_1_boom": 96, "rock_2": 144, "rock_2_boom": 144,
	"rock_gold": 96, "rock_gold_boom": 96,
}

static var _tex := {}


## 시트 텍스처 (white면 흰 실루엣 *_white.png)
static func tex(name: String, white := false) -> Texture2D:
	var key := name + ("_white" if white else "")
	if not _tex.has(key):
		_tex[key] = load(DIR + key + ".png")
	return _tex[key]


## 시트의 프레임 수 (열 수)
static func frames(name: String) -> int:
	return tex(name).get_width() / int(CELL[name])


## 프레임·방향의 칸 영역
static func region(name: String, frame: int, dir := 0) -> Rect2:
	var c: int = CELL[name]
	var rows := tex(name).get_height() / c
	return Rect2(posmod(frame, frames(name)) * c, posmod(dir, rows) * c, c, c)


## center(정수 픽셀)에 한 칸을 그린다.
static func draw(ci: CanvasItem, name: String, frame: int, dir: int, center: Vector2, white := false, modulate := Color.WHITE) -> void:
	var c: int = CELL[name]
	var top_left := center.round() - Vector2(c / 2, c / 2)
	ci.draw_texture_rect_region(tex(name, white), Rect2(top_left, Vector2(c, c)), region(name, frame, dir), modulate)


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
