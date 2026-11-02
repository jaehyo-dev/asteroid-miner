class_name TouchJoystick
extends Control
## 휴대폰용 가상 조이스틱.
## 화면 아무 곳이나 누르면 그 자리가 조이스틱 중심이 되고, 손가락을 끄는 방향으로 움직인다.
## 반지름보다 멀리 끌면 중심이 손가락을 따라온다.

const COLOR_BASE := Color(1, 1, 1, 0.25)
const COLOR_KNOB := Color(1, 1, 1, 0.5)

## 이동 방향과 세기 (길이 0~1)
var vector := Vector2.ZERO
## false면 입력을 받지 않는다 (일시 정지, 메뉴 표시 중)
var enabled := true:
	set(value):
		enabled = value
		if not value:
			release()

var _touch_index := -1
var _base := Vector2.ZERO
var _current := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_active() -> bool:
	return _touch_index >= 0


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0:
			_touch_index = event.index
			_base = event.position
			_current = event.position
			_update_vector()
		elif not event.pressed and event.index == _touch_index:
			release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_current = event.position
		_base = MoveInput.follow_base(_base, _current, Balance.JOYSTICK_RADIUS)
		_update_vector()


## 손을 뗀 상태로 되돌린다.
func release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	queue_redraw()


func _update_vector() -> void:
	vector = MoveInput.joystick_vector(_base, _current, Balance.JOYSTICK_RADIUS, Balance.JOYSTICK_DEAD_ZONE)
	queue_redraw()


func _draw() -> void:
	if not is_active():
		return
	# 이벤트 좌표는 화면(뷰포트) 기준이므로 이 컨트롤 기준으로 바꿔 그린다.
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var base := to_local * _base
	draw_arc(base, Balance.JOYSTICK_RADIUS, 0.0, TAU, 24, COLOR_BASE, 1.0)
	draw_circle(base + vector * Balance.JOYSTICK_RADIUS, 6.0, COLOR_KNOB)
