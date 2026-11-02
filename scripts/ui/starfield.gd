class_name Starfield
extends Control
## 별 배경. scroll(카메라 위치)에 따라 층마다 다른 속도로 움직여 깊이감을 준다.

## 층별: 별 개수, 움직임 비율, 밝기
const LAYERS := [
	{"count": 50, "parallax": 0.1, "bright": 0.35},
	{"count": 35, "parallax": 0.25, "bright": 0.6},
	{"count": 20, "parallax": 0.5, "bright": 0.95},
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
		var offset := scroll * float(layer["parallax"])
		for p in _stars[li]:
			var pos := Vector2(fposmod(p.x * size.x - offset.x, size.x), fposmod(p.y * size.y - offset.y, size.y))
			draw_rect(Rect2(pos.floor(), Vector2.ONE), color)
