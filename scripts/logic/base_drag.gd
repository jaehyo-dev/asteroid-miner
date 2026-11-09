class_name BaseDrag
extends RefCounted
## 끌어서 둘러보기 판정: 누른 뒤 threshold 넘게 움직여야 끌기가 된다 (그 전에는 건물 누름). 화면·노드와 분리.

var threshold := 8.0
var down := false
## 이번 누름이 끌기가 됐는지 (놓을 때 건물 창이 열리지 않게 main이 본다)
var dragged := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO


func press(pos: Vector2) -> void:
	down = true
	dragged = false
	_start = pos
	_last = pos


## 움직임 → 카메라에 더할 양. 끌기가 시작되는 순간에는 문턱 넘은 만큼을 버려 화면이 튀지 않게 한다
func move(pos: Vector2) -> Vector2:
	if not down:
		return Vector2.ZERO
	if not dragged:
		if pos.distance_to(_start) <= threshold:
			return Vector2.ZERO
		dragged = true
		_last = pos
		return Vector2.ZERO
	var d := pos - _last
	_last = pos
	return d


func release() -> void:
	down = false
