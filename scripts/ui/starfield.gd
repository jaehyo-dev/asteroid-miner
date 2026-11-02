class_name Starfield
extends Control
## 별 배경. scroll(카메라 위치)에 따라 층마다 다른 속도로 움직여 깊이감을 준다.
## parallax 1.0 층(우주 먼지)은 월드에 고정되어 운석과 똑같이 움직이므로, 우주선이 움직이는 느낌이 분명해진다.
## (먼 별만 있으면 별이 우주선을 따라오는 것처럼 보여 어색하다)

## 층별: 별 개수, 움직임 비율(카메라 이동 대비), 밝기
const LAYERS := [
	{"count": 45, "parallax": 0.3, "bright": 0.35},
	{"count": 30, "parallax": 0.55, "bright": 0.6},
	{"count": 18, "parallax": 0.8, "bright": 0.95},
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for layer in LAYERS:
		var points: Array[Vector2] = []
		for i in layer["count"]:
			points.append(Vector2(rng.randf(), rng.randf()))
		_stars.append(points)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for li in LAYERS.size():
		var layer: Dictionary = LAYERS[li]
		var b: float = layer["bright"]
		var color := Color(b, b, minf(b + 0.1, 1.0))
		for p in _stars[li]:
			draw_rect(Rect2(star_position(p, size, scroll, float(layer["parallax"])).floor(), Vector2.ONE), color)


## 별 하나의 화면 위치: 카메라가 움직인 만큼(× parallax) 반대로 밀리고, 화면 밖으로 나가면 반대편에서 나온다.
static func star_position(ratio: Vector2, area: Vector2, camera: Vector2, parallax: float) -> Vector2:
	var offset := camera * parallax
	return Vector2(fposmod(ratio.x * area.x - offset.x, area.x), fposmod(ratio.y * area.y - offset.y, area.y))
