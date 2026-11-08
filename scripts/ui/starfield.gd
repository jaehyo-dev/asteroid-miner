class_name Starfield
extends Control
## 별 배경 (Foozle Void Environment 팩). scroll(카메라 위치)에 따라 층마다 다른 속도로 움직여 깊이감을 준다.
## 바닥색 → 먼 행성(아주 느림) → 팩 별 2겹(느림·중간, 반짝이는 프레임) → 월드에 고정된 우주 먼지(1픽셀 점).
## 팩 별은 tools/clean_stars.py로 색 있는 무늬를 빼고 1~2픽셀 회색 별만 남긴 그림을 쓴다 (광물·탄과 헷갈리지 않게).
## 모두 어둡게 보정해서 화면에서 가장 덜 보이게 한다 (ART_BIBLE 6번: 배경이 가장 약함).
## 우주 먼지(parallax 1.0)는 운석과 똑같이 움직여 우주선이 움직이는 느낌을 분명하게 한다.

const BG_DIR := "res://assets/sprites/run/"
## 팩 배경 한 프레임 크기 (시트는 이 크기 프레임이 가로로 9장, 이어 붙여도 이음새 없음)
const FRAME := Vector2(640, 360)
## 바닥색: 거의 검정인 어두운 남색 (기지 화면도 같은 Starfield를 써서 같은 우주로 보임)
const BASE_COLOR := Color("#070a17")
## 팩 별 층: 그림, 움직임 비율(카메라 이동 대비), 밝기(곱함), 반짝임 프레임 속도(초당)
const PACK_LAYERS := [
	{"file": "bg_stars_far.png", "parallax": 0.2, "dim": 0.35, "fps": 3.0},
	{"file": "bg_stars_near.png", "parallax": 0.4, "dim": 0.3, "fps": 4.0},
]
## 먼 행성: 회전 프레임 시트(96x96 x 77), 움직임 비율, 색(곱함: 아주 어두운 남색), 화면 비율 위치(카메라 0일 때), 회전 속도(초당 프레임)
## 물체(운석·목표)로 읽히지 않게 오른쪽 위 모서리에 일부만 걸치고 바닥색에 가깝게 어둡게 한다.
const PLANET := {"file": "res://assets/vendor/foozle/environment/Planets/PNGs/Earth-Like planet - Without back glow.png",
	"cell": 96, "parallax": 0.05, "tint": Color(0.07, 0.08, 0.13), "anchor": Vector2(1.006, 0.05), "fps": 5.0}
## 우주 먼지: 별 개수, 움직임 비율, 밝기
const LAYERS := [
	{"count": 30, "parallax": 1.0, "bright": 0.22},
]
const STAR_SEED := 20261102

## 카메라 위치. 바뀌면 다시 그린다.
var scroll := Vector2.ZERO:
	set(value):
		if value != scroll:
			scroll = value
			queue_redraw()

## 층별 별 위치 (0~1 비율 좌표)
var _stars: Array = []
var _textures: Array[Texture2D] = []
var _planet: Texture2D
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for layer in LAYERS:
		var points: Array[Vector2] = []
		for i in layer["count"]:
			points.append(Vector2(rng.randf(), rng.randf()))
		_stars.append(points)
	for layer in PACK_LAYERS:
		_textures.append(load(BG_DIR + layer["file"]))
	_planet = load(PLANET["file"])
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	# 별 반짝임·행성 회전 프레임이 바뀔 때만 다시 그린다
	var before := _frame_key()
	_time += delta
	if _frame_key() != before:
		queue_redraw()


func _frame_key() -> int:
	var key := int(_time * PLANET["fps"])
	for layer in PACK_LAYERS:
		key = key * 31 + int(_time * layer["fps"])
	return key


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BASE_COLOR)
	_draw_planet()
	for i in PACK_LAYERS.size():
		var layer: Dictionary = PACK_LAYERS[i]
		var tex := _textures[i]
		var frame := int(_time * layer["fps"]) % int(tex.get_width() / FRAME.x)
		var d: float = layer["dim"]
		var origin := tile_origin(scroll * float(layer["parallax"]))
		# 화면을 덮을 만큼 프레임을 이어 붙인다 (정수 픽셀 위치)
		var y := origin.y
		while y < size.y:
			var x := origin.x
			while x < size.x:
				draw_texture_rect_region(tex, Rect2(Vector2(x, y), FRAME), Rect2(frame * FRAME.x, 0, FRAME.x, FRAME.y), Color(d, d, d))
				x += FRAME.x
			y += FRAME.y
	for li in LAYERS.size():
		var layer: Dictionary = LAYERS[li]
		var b: float = layer["bright"]
		var color := Color(b, b, minf(b + 0.1, 1.0))
		for p in _stars[li]:
			draw_rect(Rect2(star_position(p, size, scroll, float(layer["parallax"])).floor(), Vector2.ONE), color)


## 먼 행성: 화면 오른쪽 위쯤에서 아주 천천히 밀리고 천천히 돈다
func _draw_planet() -> void:
	var cell: int = PLANET["cell"]
	var frame := int(_time * PLANET["fps"]) % (_planet.get_width() / cell)
	# 멀리 가도 다시 돌아오게 화면 + 행성 크기만큼씩 감싼다
	var p := size * (PLANET["anchor"] as Vector2) - scroll * float(PLANET["parallax"]) + Vector2(cell, cell) / 2.0
	var span := size + Vector2(cell, cell) * 2.0
	var pos := (Vector2(fposmod(p.x, span.x), fposmod(p.y, span.y)) - Vector2(cell, cell)).round()
	draw_texture_rect_region(_planet, Rect2(pos, Vector2(cell, cell)), Rect2(frame * cell, 0, cell, cell), PLANET["tint"])


## 이어 붙인 배경 타일의 왼쪽 위 (항상 화면 왼쪽 위 0 이하, 정수 픽셀)
static func tile_origin(offset: Vector2) -> Vector2:
	return Vector2(-fposmod(offset.x, FRAME.x), -fposmod(offset.y, FRAME.y)).floor()


## 별 하나의 화면 위치: 카메라가 움직인 만큼(× parallax) 반대로 밀리고, 화면 밖으로 나가면 반대편에서 나온다.
static func star_position(ratio: Vector2, area: Vector2, camera: Vector2, parallax: float) -> Vector2:
	var offset := camera * parallax
	return Vector2(fposmod(ratio.x * area.x - offset.x, area.x), fposmod(ratio.y * area.y - offset.y, area.y))
