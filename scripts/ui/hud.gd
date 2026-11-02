class_name Hud
extends Control
## 출격 중 화면 정보: 체력 막대, 버틴 시간, 부순 운석 수, 주운 광물.

const MARGIN := 8.0
const BAR_SIZE := Vector2(80, 6)
const FONT_SIZE := 12
const COLOR_TEXT := Color("#c8cde0")
const COLOR_HP := Color("#ff5a5a")
const COLOR_VALUE := Color("#ffd34f")
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
	# 부순 운석 수
	draw_string(font, Vector2(MARGIN, MARGIN + 26), "파괴 %d" % sim.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	# 주운 광물: 등급별 아이콘과 개수, 총 가치
	var x := MARGIN
	for grade in sim.collected.size():
		draw_texture(PixelArt.mineral(grade), Vector2(x, MARGIN + 33))
		var text := str(sim.collected[grade])
		draw_string(font, Vector2(x + 7, MARGIN + 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
		x += 7 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 6
	draw_string(font, Vector2(MARGIN, MARGIN + 58), "가치 %d" % sim.mineral_value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_VALUE)
	# 버틴 시간 (가운데 위)
	draw_string(font, Vector2(0, MARGIN + 10), format_time(sim.time), HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, COLOR_TEXT)


func _draw_bar(pos: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, BAR_SIZE), COLOR_BAR_BG)
	draw_rect(Rect2(pos, Vector2(roundf(BAR_SIZE.x * clampf(ratio, 0.0, 1.0)), BAR_SIZE.y)), color)


## 등급별 개수 → "일반 3 · 희귀 1" 형태 (0개인 등급은 뺌)
static func minerals_text(counts: PackedInt32Array) -> String:
	var parts: PackedStringArray = []
	for i in counts.size():
		if counts[i] > 0:
			parts.append("%s %d" % [Balance.MINERAL_GRADES[i]["name"], counts[i]])
	return " · ".join(parts) if not parts.is_empty() else "없음"
