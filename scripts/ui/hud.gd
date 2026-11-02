class_name Hud
extends Control
## 출격 중 화면 정보: 체력 막대, 버틴 시간.

const MARGIN := 8.0
const BAR_SIZE := Vector2(80, 6)
const FONT_SIZE := 12
const COLOR_TEXT := Color("#c8cde0")
const COLOR_HP := Color("#ff5a5a")
const COLOR_BAR_BG := Color("#2a2a40")

var sim: RunSim


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 초 → "분:초" 문자열
static func format_time(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]


func _draw() -> void:
	if sim == null:
		return
	var font := get_theme_default_font()
	# 체력
	draw_string(font, Vector2(MARGIN, MARGIN + 10), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	_draw_bar(Vector2(MARGIN + 18, MARGIN + 4), sim.hp / sim.max_hp, COLOR_HP)
	# 버틴 시간 (가운데 위)
	draw_string(font, Vector2(0, MARGIN + 10), format_time(sim.time), HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, COLOR_TEXT)


func _draw_bar(pos: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, BAR_SIZE), COLOR_BAR_BG)
	draw_rect(Rect2(pos, Vector2(roundf(BAR_SIZE.x * clampf(ratio, 0.0, 1.0)), BAR_SIZE.y)), color)
