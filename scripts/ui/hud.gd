class_name Hud
extends Control
## 출격 중 화면 정보: 체력 막대, 버틴 시간, 부순 적 수(운석·생명체), 화물칸(등급별 개수·칸수·가치),
## 위험도 배율, 워프 게이트(남은 시간·방향·충전), 레벨과 경험치 막대, 화면 밖 황금 운석의 방향 표시.

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
## 위험 경고 색 (심연의 포격, 습격)
const COLOR_DANGER := Color("#ff4040")
## 습격 방향 표시: 가장자리 빛의 반지름
const RAID_GLOW_RADIUS := 70.0
## 알림 배너 글자 위치 (왼쪽 위 광물·가치 줄보다 아래)
const BANNER_Y := 88.0
## 포격 표시를 하나로 묶는 거리 (거의 같은 곳에서 쏘면 "!" 하나만)
const BARRAGE_MARKER_MERGE := 24.0
const COLOR_BAR_BG := Color("#2a2a40")
## 워프 게이트 색 (화살표, 남은 시간, 충전)
const COLOR_GATE := Color("#7cf0ff")
## 화물칸이 꽉 찼을 때 글자 색
const COLOR_FULL := Color("#ff9a2e")
## 위험도 배율 글자 크기와 색 (x1.0 기본 색 → 최대일 때 붉은 주황)
const RISK_FONT_SIZE := 24
const COLOR_RISK_MAX := Color("#ff6a3d")
## 오른쪽 위 일시 정지 버튼 자리 (위험도 배율은 그 왼쪽에 쓴다)
const PAUSE_BUTTON_SPACE := 34.0

var sim: RunSim
## 피격·위험 표시 상태 (체력 낮음이면 체력 막대가 깜빡임)
var alert: DangerAlert
## 화면 가운데 위 알림 배너 (새로운 위협, 습격 경고)
var banner_text := ""
var banner_color := Color.WHITE
var banner_time := 0.0


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
	# 부순 적 수(운석·생명체)
	draw_string(font, Vector2(MARGIN, MARGIN + 26), "파괴 %d" % sim.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	# 주운 광물: 등급별 아이콘과 개수, 총 가치
	var x := MARGIN
	var cargo := sim.cargo
	for grade in cargo.counts.size():
		var icon := PixelArt.mineral(grade)
		# 아이콘 크기가 등급마다 달라서 세로 가운데를 맞춘다
		draw_texture(icon, Vector2(x, MARGIN + 38 - floorf(icon.get_height() / 2.0)))
		var text := str(cargo.counts[grade])
		draw_string(font, Vector2(x + icon.get_width() + 2, MARGIN + 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
		x += icon.get_width() + 2 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 6
	draw_string(font, Vector2(MARGIN, MARGIN + 58), cargo_text(cargo), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_FULL if cargo.is_full() else COLOR_VALUE)
	_draw_risk(font)
	_draw_gate_info(font)
	# 레벨과 경험치 막대 (화면 맨 아래 전체 너비)
	var need := Upgrades.xp_to_next(sim.level)
	draw_rect(Rect2(0, size.y - XP_BAR_HEIGHT, size.x, XP_BAR_HEIGHT), COLOR_BAR_BG)
	draw_rect(Rect2(0, size.y - XP_BAR_HEIGHT, roundf(size.x * clampf(float(sim.xp) / need, 0.0, 1.0)), XP_BAR_HEIGHT), COLOR_XP)
	draw_string(font, Vector2(MARGIN, size.y - XP_BAR_HEIGHT - 4), "Lv %d" % sim.level, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_XP)
	_draw_raid_direction()
	_draw_golden_markers()
	_draw_gate_marker()
	_draw_barrage_markers()
	_draw_banner(font)
	# 버틴 시간 (가운데 위)
	draw_string(font, Vector2(0, MARGIN + 10), format_time(sim.time), HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, COLOR_TEXT)


## 화면 밖 황금 운석마다 가장자리에 금색 화살표를 띄운다 (카메라는 우주선을 따라감).
func _draw_golden_markers() -> void:
	var center := sim.player_pos.round()
	var pulse := 0.6 + 0.4 * sin(sim.time * 6.0)
	for a in sim.enemies:
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


## 화물칸 글자: "화물 12/80 · 가치 120" (꽉 차면 "화물 가득")
static func cargo_text(cargo: Cargo) -> String:
	var label := "가득 " if cargo.is_full() else ""
	return "화물 %s%d/%d · 가치 %d" % [label, cargo.size(), cargo.capacity, cargo.value()]


## 위험도 배율을 오른쪽 위(일시 정지 버튼 왼쪽)에 크게 쓴다. 배율이 오를수록 붉어진다.
func _draw_risk(font: Font) -> void:
	var mult := RunSim.risk_mult(sim.time)
	var k := (mult - 1.0) / maxf(Balance.RISK_MAX - 1.0, 0.001)
	draw_string(font, Vector2(0, MARGIN + 16), risk_text(mult), HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAUSE_BUTTON_SPACE, RISK_FONT_SIZE, COLOR_TEXT.lerp(COLOR_RISK_MAX, k))


static func risk_text(mult: float) -> String:
	return "x%.2f" % mult


## 오른쪽 위 게이트 정보: 다음 게이트까지 남은 시간 / 열린 게이트가 닫힐 때까지 / 충전 진행도
func _draw_gate_info(font: Font) -> void:
	draw_string(font, Vector2(0, MARGIN + 34), gate_text(sim.gate), HORIZONTAL_ALIGNMENT_RIGHT, size.x - MARGIN, FONT_SIZE, COLOR_GATE)


static func gate_text(gate: WarpGate) -> String:
	if gate.charge >= 0.0:
		return "워프 충전 %d%%" % floori(gate.charge_progress() * 100.0)
	if gate.state == WarpGate.State.OPEN:
		return "게이트 닫힘 %d" % ceili(maxf(gate.timer, 0.0))
	return "다음 게이트 %s" % format_time(ceilf(gate.timer))


## 열린 워프 게이트가 화면 밖이면 가장자리에 하늘색 화살표와 작은 고리를 띄운다.
## 열리기 GATE_HINT_TIME 전부터는 열릴 방향에 흐린 화살표와 남은 초를 띄운다.
func _draw_gate_marker() -> void:
	var g := sim.gate
	if g.state == WarpGate.State.WAITING:
		if is_nan(g.direction) or g.timer > Balance.GATE_HINT_TIME:
			return
		var hint_dir := Vector2.from_angle(g.direction)
		var edge: Vector2 = Offscreen.edge_marker(Vector2.ZERO, hint_dir * 100000.0, size, MARKER_MARGIN)
		draw_colored_polygon(arrow_points(edge, hint_dir), Color(COLOR_GATE, 0.45))
		var label_pos := edge - hint_dir * (MARKER_BACK + 10.0)
		draw_string(get_theme_default_font(), (label_pos + Vector2(-12, 4)).round(), str(ceili(g.timer)), HORIZONTAL_ALIGNMENT_CENTER, 24, FONT_SIZE, Color(COLOR_GATE, 0.7))
		return
	var center := sim.player_pos.round()
	var marker: Variant = Offscreen.edge_marker(center, sim.gate.pos, size, MARKER_MARGIN, Balance.GATE_RADIUS)
	if marker == null:
		return
	var dir := (sim.gate.pos - center).normalized()
	var pulse := 0.6 + 0.4 * sin(sim.time * 6.0)
	draw_colored_polygon(arrow_points(marker, dir), Color(COLOR_GATE, pulse))
	draw_arc(marker - dir * (MARKER_BACK + 8.0), 4.0, 0.0, TAU, 12, COLOR_GATE, 1.5)


## 알림 배너를 띄운다 (Balance.BANNER_TIME 동안).
func show_banner(text: String, color: Color) -> void:
	banner_text = text
	banner_color = color
	banner_time = Balance.BANNER_TIME


## 배너 시간 진행 (게임이 진행될 때만 부름)
func step(delta: float) -> void:
	banner_time = maxf(banner_time - delta, 0.0)


func _draw_banner(font: Font) -> void:
	if banner_time <= 0.0:
		return
	# 처음과 끝 0.3초는 서서히 나타나고 사라진다
	var a := clampf(minf(banner_time, Balance.BANNER_TIME - banner_time) / 0.3, 0.0, 1.0)
	var y := BANNER_Y
	draw_rect(Rect2(0, y - 13, size.x, 18), Color(0, 0, 0, 0.45 * a))
	draw_string(font, Vector2(0, y), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, Color(banner_color, a))


## 습격이 오는 방향의 화면 가장자리를 붉게 밝힌다: 경고 중에는 맥박치고, 습격 중에는 은은하게.
## 습격 중에는 시간 아래에 남은 시간을 보여 준다.
func _draw_raid_direction() -> void:
	var r := sim.raid
	if r.state != RaidDirector.State.WARNING and r.state != RaidDirector.State.ACTIVE:
		return
	var dir := Vector2.from_angle(r.direction)
	var edge: Vector2 = Offscreen.edge_marker(Vector2.ZERO, dir * 100000.0, size, 0.0)
	var strength := 0.5 + 0.5 * sin(sim.time * TAU * 2.0) if r.state == RaidDirector.State.WARNING else 0.35
	for i in 5:
		var radius := RAID_GLOW_RADIUS * (1.0 - i * 0.18)
		draw_circle(edge, radius, Color(COLOR_DANGER, 0.06 * strength))
	draw_colored_polygon(arrow_points(edge - dir * (MARKER_MARGIN + MARKER_SIZE), dir), Color(COLOR_DANGER, 0.5 + 0.5 * strength))
	if r.state == RaidDirector.State.ACTIVE:
		var text := "%s %d" % [RaidDirector.display_name(r.kind), ceili(r.timer)]
		draw_string(get_theme_default_font(), Vector2(0, MARGIN + 24), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, COLOR_DANGER)


## 체력 막대 색: 체력 낮음 경고 상태면 빨강과 밝은 색을 오가며 깜빡인다.
static func hp_bar_color(danger: DangerAlert, time: float) -> Color:
	if danger != null and danger.low and int(time * HP_BLINK_RATE * 2.0) % 2 == 1:
		return COLOR_HP_BLINK
	return COLOR_HP


## 심연의 포격을 쏘는 곳(화면 밖)이 있는 쪽 가장자리에 붉은 화살표와 "!"를 띄운다 (예고·충전·발사 동안).
func _draw_barrage_markers() -> void:
	var center := sim.player_pos.round()
	var font := get_theme_default_font()
	var drawn: Array[Vector2] = []
	for b in sim.barrages:
		var marker: Variant = Offscreen.edge_marker(center, b.origin, size, MARKER_MARGIN)
		if marker == null or _near_any(marker, drawn, BARRAGE_MARKER_MERGE):
			continue
		drawn.append(marker)
		var dir := (b.origin - center).normalized()
		draw_colored_polygon(arrow_points(marker, dir), COLOR_DANGER)
		var label_pos: Vector2 = marker - dir * (MARKER_BACK + 8.0)
		draw_string(font, (label_pos + Vector2(-6, 5)).round(), "!", HORIZONTAL_ALIGNMENT_CENTER, 12, FONT_SIZE, COLOR_DANGER)


static func _near_any(p: Vector2, points: Array[Vector2], distance: float) -> bool:
	for q in points:
		if p.distance_to(q) < distance:
			return true
	return false


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
