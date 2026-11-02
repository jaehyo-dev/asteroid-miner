class_name DangerOverlay
extends Control
## 피격·위험 표시 화면: 맞았을 때 붉은 번쩍임, 체력 낮음일 때 붉은 테두리 맥박.
## 언제 보일지는 DangerAlert가 정하고, 여기서는 그리기만 한다.

const COLOR_RED := Color(1.0, 0.15, 0.15)
## 번쩍임 최대 진하기, 테두리 두께와 최대 진하기
const FLASH_ALPHA := 0.28
const BORDER_WIDTH := 28.0
const BORDER_ALPHA := 0.55
## 테두리를 몇 겹으로 그려 안쪽으로 갈수록 옅어지게 할지
const BORDER_STEPS := 7

var alert: DangerAlert
## 맥박 계산용 시간
var time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if alert == null:
		return
	var flash := alert.flash_strength()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(COLOR_RED, FLASH_ALPHA * flash))
	var border := alert.border_strength(time)
	if border > 0.0:
		var step := BORDER_WIDTH / BORDER_STEPS
		for i in BORDER_STEPS:
			var a := BORDER_ALPHA * border * (1.0 - float(i) / BORDER_STEPS)
			var c := Color(COLOR_RED, a / BORDER_STEPS * 2.0)
			var inset := i * step
			draw_rect(Rect2(inset, inset, size.x - inset * 2.0, step), c)  # 위
			draw_rect(Rect2(inset, size.y - inset - step, size.x - inset * 2.0, step), c)  # 아래
			draw_rect(Rect2(inset, inset + step, step, size.y - (inset + step) * 2.0), c)  # 왼쪽
			draw_rect(Rect2(size.x - inset - step, inset + step, step, size.y - (inset + step) * 2.0), c)  # 오른쪽
