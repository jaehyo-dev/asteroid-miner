class_name Shutter
extends Control
## 기지로 돌아갈 때의 충격 셔터 (App이 가장 위 CanvasLayer에 하나 둔다).
## 위아래 금속 판이 닫히며 "쿵"(약한 흔들림) → 닫힌 채 장면을 기지로 바꿈 → 열림. 건물 창과 같은 금속·금색 위험 띠.
## 화면 배율이 출격(정수 배율)과 기지(소수 배율)에서 달라도 창 픽셀 기준 정수 칸(App.base_pixel_scale)으로 그린다.

signal opened

enum State { IDLE, CLOSING, SHAKE, HOLD, OPENING }

const BODY := Color("#3c3544")
const SEAM := Color("#14111c")
const RIVET := Color("#917487")
const GOLD := Color("#f6ce50")
const INK := Color("#fef8e5")
const PLATE_H := 44  # 판 한 줄 높이(칸)
const PLATE_W := 80
const EDGE := 16  # 맨 앞 위험 띠 높이(칸): 크림 선 3칸 + 어두운 띠

var state := State.IDLE
## 0 = 열림, 1 = 닫힘
var closed := 0.0
var _t := 0.0
var _scene := ""
var _shake := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## 셔터가 움직이거나 닫혀 있는 동안 (입력을 막는다)
func busy() -> bool:
	return state != State.IDLE


## 닫고 나서 scene으로 넘어간 뒤 연다. 이미 움직이는 중이면 무시.
func close_to(scene: String) -> void:
	if busy():
		return
	_scene = scene
	_go(State.CLOSING)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("shutter_close")


func _go(s: State) -> void:
	state = s
	_t = 0.0


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	# 출격(정수 배율)과 기지(1280x720)의 화면 좌표 크기가 달라, 앵커 대신 매 프레임 보이는 화면에 맞춘다
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_t += delta
	match state:
		State.CLOSING:
			closed = minf(pow(_t / Juice.SHUTTER_CLOSE, 3.0), 1.0)  # 점점 빨라져 쾅
			if _t >= Juice.SHUTTER_CLOSE:
				_go(State.SHAKE)
				if _scene != "":  # 빈 경로 = 장면은 그대로 (테스트)
					get_tree().change_scene_to_file(_scene)
		State.SHAKE:
			var i := int(_t / Juice.SHUTTER_SHAKE_STEP)
			_shake = Juice.SHUTTER_SHAKE[i] if i < Juice.SHUTTER_SHAKE.size() and App.settings.shake else 0
			if i >= Juice.SHUTTER_SHAKE.size():
				_go(State.HOLD)
		State.HOLD:
			if _t >= Juice.SHUTTER_HOLD:
				_go(State.OPENING)
				Sfx.play("shutter_open")
		State.OPENING:
			closed = pow(1.0 - minf(_t / Juice.SHUTTER_OPEN, 1.0), 3.0)  # 처음 빨리 풀리고 천천히 멈춤
			if _t >= Juice.SHUTTER_OPEN:
				closed = 0.0
				_go(State.IDLE)
				visible = false
				mouse_filter = Control.MOUSE_FILTER_IGNORE
				opened.emit()
	queue_redraw()


## 움직이는 동안 키보드·패드 입력도 아래 장면으로 가지 않게
func _input(event: InputEvent) -> void:
	if busy() and not event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


## 한 칸의 크기(이 Control 좌표): 창 픽셀 k개
func cell() -> float:
	var win := get_window().size
	return App.base_pixel_scale(win) / get_tree().root.get_final_transform().get_scale().x


func _draw() -> void:
	var c := cell()
	var area := get_viewport_rect().size  # 장면이 바뀐 첫 프레임엔 size가 아직 옛 배율이라 화면 크기를 직접 본다
	var rows := ceili(area.y / c)
	var cols := ceili(area.x / c)
	var half := ceili(rows / 2.0)
	var reach := int(round(half * closed))  # 판 앞쪽 끝이 가장자리에서 들어온 칸 수
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(c, c))
	# 쿵 흔들림은 두 판을 같이 아래로·위로 밀어 가운데에 틈이 생기지 않게 (틈으로 바뀌는 장면이 비치지 않게)
	_panel(reach + _shake, cols, false)
	_panel(reach - _shake, cols, true, rows)


## 판 하나. 위 판 기준 칸 번호(0 = 화면 가장자리, reach-1 = 앞쪽 끝)로 그리고, 아래 판은 위아래를 뒤집어 놓는다.
func _panel(reach: int, cols: int, flip: bool, rows := 0) -> void:
	if reach <= 0:
		return
	var lead := reach - 1
	# a~b칸(위 판 기준, 화면 밖은 잘라냄)을 x에서 w칸 폭으로 칠한다
	var span := func(a: int, b: int, x: int, w: int, col: Color) -> void:
		a = maxi(a, 0)
		if b < a:
			return
		draw_rect(Rect2(x, rows - b - 1 if flip else a, w, b - a + 1), col)
	span.call(0, lead, 0, cols, BODY)
	# 앞 끝 16칸: 크림 선 3칸 → 어두운 띠 13칸 안에 금색 빗금(앞 끝 1칸은 비움)
	span.call(lead - 15, lead - 13, 0, cols, INK)
	span.call(lead - 12, lead, 0, cols, SEAM)
	for x in range(-14, cols, 14):
		for d in 10:
			span.call(lead - 1 - d, lead - 1 - d, x + int(d * 0.7), 7, GOLD)
	# 몸통: 앞 끝 띠 뒤로 PLATE_H칸마다 가로 이음새, 줄마다 엇갈린 세로 이음새와 리벳 2쌍
	var body_end := lead - EDGE
	var r := body_end - PLATE_H + 1
	var band := 0
	while r + PLATE_H > 0:
		span.call(r, r, 0, cols, SEAM)
		for x in range(8 + (band % 2) * 40, cols, PLATE_W):
			span.call(r + 1, mini(r + PLATE_H - 1, body_end), x + 32, 1, SEAM)
			span.call(r + 4, mini(r + 5, body_end), x, 2, RIVET)
			span.call(r + 4, mini(r + 5, body_end), x + 60, 2, RIVET)
		r -= PLATE_H
		band += 1
