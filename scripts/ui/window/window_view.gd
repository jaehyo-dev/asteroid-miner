class_name WindowView
extends Control
## 건물 창 내용의 공통 부모. 위아래 끌기 도우미를 함께 둔다.

var win: BaseWindow
## 끌기: 내용이 넘칠 때만. 지금 내려간 양, 최대
var scroll := 0
var max_scroll := 0

var _press_y := -1.0
var _press_scroll := 0
var dragged := false


## 창이 크기를 정한 뒤 불린다
func setup() -> void:
	pass


## 끌기 처리. 눌렀다 뗄 때 누름으로 칠 수 있으면 false를 돌려준다
func drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and dragged:  # 손을 떼면 멈출 자리에 맞춘다 (창마다 snap_scroll)
			scroll = clampi(snap_scroll(scroll, scroll - _press_scroll), 0, max_scroll)
			queue_redraw()
		_press_y = event.position.y if event.pressed else -1.0
		_press_scroll = scroll
		if event.pressed:
			dragged = false
	elif event is InputEventMouseMotion and _press_y >= 0.0 and max_scroll > 0:
		if absf(event.position.y - _press_y) > 4.0:
			dragged = true
		if dragged:
			scroll = clampi(_press_scroll + int(_press_y - event.position.y), 0, max_scroll)
			queue_redraw()


## 끌기를 멈췄을 때 맞출 자리 (기본: 그대로). moved: 이번에 끈 양 (+면 아래 내용으로)
func snap_scroll(v: int, _moved := 0) -> int:
	return v


## 오른쪽 가장자리 끌기 막대: 글자를 덮지 않게 판 맨 끝에
func draw_scroll_bar(r: Rect2i, ratio_top: float, viewable: float, color: Color) -> void:
	var x0 := r.end.x - 6
	draw_rect(Rect2(x0, r.position.y + 2, 4, r.size.y - 4), WindowArt.PLATE)
	var track := r.size.y - 14
	var thumb := maxi(12, int(track * viewable))
	var top := r.position.y + 7 + int((track - thumb) * ratio_top)
	draw_rect(Rect2(x0, top, 4, thumb), color)
	if ratio_top > 0.0:
		draw_rect(Rect2(x0 + 1, r.position.y + 2, 2, 1), WindowArt.INK)
		draw_rect(Rect2(x0, r.position.y + 3, 4, 1), WindowArt.INK)
	if ratio_top < 1.0:
		draw_rect(Rect2(x0 + 1, r.end.y - 3, 2, 1), WindowArt.INK)
		draw_rect(Rect2(x0, r.end.y - 4, 4, 1), WindowArt.INK)
