class_name Hud
extends Control
## 출격 중 화면 정보: 체력 막대, 버틴 시간, 부순 운석 수, 주운 광물, 레벨과 경험치 막대,
## 화면 밖 황금 운석의 방향 표시.

const MARGIN := 8.0
const BAR_SIZE := Vector2(80, 6)
const FONT_SIZE := 12
const COLOR_TEXT := Color("#c8cde0")
const COLOR_HP := Color("#ff5a5a")
const COLOR_VALUE := Color("#ffd34f")
const COLOR_XP := Color("#4fd1ff")
const XP_BAR_HEIGHT := 3.0
## 화면 밖 황금 운석 방향 표시: 가장자리에서 떨어진 거리, 화살표 크기
const MARKER_MARGIN := 12.0
const MARKER_SIZE := 6.0
## 화살표 모양: 끝까지 길이(MARKER_SIZE), 뒤쪽 길이, 밑변 반폭. 길고 뾰족해야 방향이 헷갈리지 않는다.
const MARKER_BACK := 6.0
const MARKER_HALF_WIDTH := 3.5
const COLOR_GOLD := Color("#ffcc33")
## 체력 낮음일 때 체력 막대가 깜빡이는 밝은 색과 깜빡임 속도(초당)
const COLOR_HP_BLINK := Color("#ffd0d0")
const HP_BLINK_RATE := 3.0
## 조준 운석 경고 색
const COLOR_DANGER := Color("#ff4040")
const COLOR_BAR_BG := Color("#2a2a40")

var sim: RunSim
## 피격·위험 표시 상태 (체력 낮음이면 체력 막대가 깜빡임)
var alert: DangerAlert


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
	_draw_bar(Vector2(MARGIN + 18, MARGIN + 4), sim.hp / sim.max_hp, hp_bar_color(alert, sim.time))
	# 부순 운석 수
	draw_string(font, Vector2(MARGIN, MARGIN + 26), "파괴 %d" % sim.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	# 주운 광물: 등급별 아이콘과 개수, 총 가치
	var x := MARGIN
	for grade in sim.collected.size():
		var icon := PixelArt.mineral(grade)
		# 아이콘 크기가 등급마다 달라서 세로 가운데를 맞춘다
		draw_texture(icon, Vector2(x, MARGIN + 38 - floorf(icon.get_height() / 2.0)))
		var text := str(sim.collected[grade])
		draw_string(font, Vector2(x + icon.get_width() + 2, MARGIN + 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
		x += icon.get_width() + 2 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 6
	draw_string(font, Vector2(MARGIN, MARGIN + 58), "가치 %d" % sim.mineral_value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_VALUE)
	# 레벨과 경험치 막대 (화면 맨 아래 전체 너비)
	var need := Upgrades.xp_to_next(sim.level)
	draw_rect(Rect2(0, size.y - XP_BAR_HEIGHT, size.x, XP_BAR_HEIGHT), COLOR_BAR_BG)
	draw_rect(Rect2(0, size.y - XP_BAR_HEIGHT, roundf(size.x * clampf(float(sim.xp) / need, 0.0, 1.0)), XP_BAR_HEIGHT), COLOR_XP)
	draw_string(font, Vector2(MARGIN, size.y - XP_BAR_HEIGHT - 4), "Lv %d" % sim.level, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_XP)
	_draw_golden_markers()
	_draw_aimed_markers()
	# 버틴 시간 (가운데 위)
	draw_string(font, Vector2(0, MARGIN + 10), format_time(sim.time), HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, COLOR_TEXT)


## 화면 밖 황금 운석마다 가장자리에 금색 화살표를 띄운다 (카메라는 우주선을 따라감).
func _draw_golden_markers() -> void:
	var center := sim.player_pos.round()
	var pulse := 0.6 + 0.4 * sin(sim.time * 6.0)
	for a in sim.asteroids:
		if not a.golden:
			continue
		var marker: Variant = Offscreen.edge_marker(center, a.pos, size, MARKER_MARGIN, a.radius)
		if marker == null:
			continue
		var dir := (a.pos - center).normalized()
		draw_colored_polygon(arrow_points(marker, dir), Color(COLOR_GOLD, pulse))
		# 화살표 뒤쪽(화면 안쪽)에 금괴 그림을 붙여 무엇을 가리키는지 알려 준다
		# (금괴는 깜빡이지 않고 항상 선명하게: 어두워지면 갈색 운석처럼 보인다)
		draw_texture(PixelArt.mineral(3), (marker - dir * (MARKER_BACK + 8.0) - Vector2(4, 3)).round())


## 체력 막대 색: 체력 낮음 경고 상태면 빨강과 밝은 색을 오가며 깜빡인다.
static func hp_bar_color(danger: DangerAlert, time: float) -> Color:
	if danger != null and danger.low and int(time * HP_BLINK_RATE * 2.0) % 2 == 1:
		return COLOR_HP_BLINK
	return COLOR_HP


## 화면 밖에서 다가오는 조준 운석마다 가장자리에 붉은 "!"를 띄운다.
func _draw_aimed_markers() -> void:
	var center := sim.player_pos.round()
	var font := get_theme_default_font()
	for a in sim.asteroids:
		if not a.aimed:
			continue
		var marker: Variant = Offscreen.edge_marker(center, a.pos, size, MARKER_MARGIN, a.radius)
		if marker == null:
			continue
		var dir := (a.pos - center).normalized()
		draw_colored_polygon(arrow_points(marker, dir), COLOR_DANGER)
		var label_pos: Vector2 = marker - dir * (MARKER_BACK + 8.0)
		draw_string(font, (label_pos + Vector2(-6, 5)).round(), "!", HORIZONTAL_ALIGNMENT_CENTER, 12, FONT_SIZE, COLOR_DANGER)


## 방향 표시 화살표 꼭짓점: [끝, 밑변 한쪽, 밑변 다른 쪽]. dir은 길이 1인 방향.
static func arrow_points(marker: Vector2, dir: Vector2) -> PackedVector2Array:
	var side := Vector2(-dir.y, dir.x)
	var back := marker - dir * MARKER_BACK
	return PackedVector2Array([marker + dir * MARKER_SIZE, back + side * MARKER_HALF_WIDTH, back - side * MARKER_HALF_WIDTH])


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
