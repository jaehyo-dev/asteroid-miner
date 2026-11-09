extends Node
## 게임 전체 설정 (자동 로드: App).
## - 키보드 입력 동작(move_left 등)을 등록한다.
## - 게임은 가로 고정이다. 창이 세로로 길어지면(폰을 세로로 듦) 게임 화면은 가리고 "폰을 가로로 돌려주세요"만 보인다.
##   게임은 지워지지 않고 그대로 남으며(저장·기지 화면), 출격 화면은 일시 정지가 된다. 가로로 돌리면 이어진다.
## - 웹에서 전체 화면에 들어가면 가로 고정(screen.orientation.lock)을 시도한다 (안 되는 환경은 조용히 넘어감).
## - 기지 화면은 2배 기준 해상도(1280x720)로 그린다. 출격 화면은 정수 배율로 키우고 논리 화면을 창 / 배율로 맞춘다 (run_pixel_scale).

## 기지 화면 기준 해상도 배율
const BASE_SCREEN_SCALE := 2

## 지금 기지 화면인지 (main.gd가 켜고 끈다)
var base_mode := false
## 창이 세로로 길어 안내 화면이 떠 있는지 (출격 화면이 이 신호로 일시 정지한다)
var portrait := false
signal portrait_changed(is_portrait: bool)
## 다음 출격 화면이 워프 터널로 시작할지, 다음 기지 화면이 착륙으로 시작할지 (화면을 넘어가며 한 번만 쓴다)
var warp_intro := false
var landing := false
## 귀환 결과 {title, body}: 기지가 착륙을 마친 뒤 띄운다 (저장은 넘어오기 전에 끝나 있다)
var return_result := {}
## 임시 건물 5채를 더한 기지 모습 (캡처·확인용, 웹 주소 ?base10)
var base_debug_busy := false
## 플레이어 설정 (화면 흔들림, 효과음·배경음 크기, FPS 표시). 바꾸면 apply_settings()로 적용하고 save_file()로 저장한다.
var settings := GameSettings.load_file()

## 세로일 때 게임 위를 덮는 안내 (CanvasLayer가 가장 위)
const ROTATE_TEXT := "폰을 가로로 돌려주세요"
var _rotate_layer: CanvasLayer
var _rotate_label: Label
var _rotate_icon: RotateIcon

## 웹: 전체 화면에 들어가면 가로 고정을 시도하고, 나오면 푼다. 지원하지 않거나 거절돼도 오류 없이 넘어간다.
const LOCK_LANDSCAPE_JS := """
(function () {
	document.addEventListener('fullscreenchange', function () {
		try {
			var o = screen.orientation;
			if (!o) return;
			if (document.fullscreenElement) { var p = o.lock && o.lock('landscape'); if (p && p.catch) p.catch(function () {}); }
			else if (o.unlock) { o.unlock(); }
		} catch (e) {}
	});
})();
"""

## 동작 이름 → 키 목록
const KEY_ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"pause": [KEY_ESCAPE, KEY_P],
	"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
}


func _ready() -> void:
	register_actions()
	apply_settings()
	_build_rotate_overlay()
	get_tree().root.size_changed.connect(fit_screen)
	fit_screen()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(LOCK_LANDSCAPE_JS)


## 설정의 효과음·배경음 크기를 각 버스(SFX, Music)에 적용한다. 0단계는 음소거.
func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(bus, settings.sfx_level == 0)
	AudioServer.set_bus_volume_db(bus, settings.sfx_db() if settings.sfx_level > 0 else 0.0)
	bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus, settings.music_level == 0)
	AudioServer.set_bus_volume_db(bus, settings.music_db() if settings.music_level > 0 else 0.0)


## 가로 안내 화면: 게임을 가리는 꽉 찬 배경 + 큰 글자. 눌러도 아래 게임으로 입력이 가지 않는다.
func _build_rotate_overlay() -> void:
	_rotate_layer = CanvasLayer.new()
	_rotate_layer.layer = 100
	_rotate_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_rotate_layer.visible = false
	var bg := ColorRect.new()
	bg.color = Color("#05060f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate_layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate_icon = RotateIcon.new()
	_rotate_label = _rotate_text(ROTATE_TEXT, Color("#e8ecf6"))
	box.add_child(_rotate_icon)
	box.add_child(_rotate_label)
	_rotate_layer.add_child(box)
	add_child(_rotate_layer)


func _rotate_text(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l


## 세로로 긴 창인지
static func is_portrait_size(window_size: Vector2i) -> bool:
	return window_size.y > window_size.x


## 입력 동작 등록 (이미 있으면 건너뜀)
static func register_actions() -> void:
	for action in KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEY_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


## 기준 해상도: 항상 가로용. 기지 화면은 2배. (세로 창은 안내 화면만 보이므로 따로 없음)
static func base_size_for(_window_size: Vector2i, base_screen: bool = false) -> Vector2i:
	return Balance.BASE_LANDSCAPE * BASE_SCREEN_SCALE if base_screen else Balance.BASE_LANDSCAPE


## 기지 풍경의 정수 배율: 출격 화면과 같은 기준, 범위 밖 창은 가장 가까운 정수 (1 이상). 건물 창·결과 창은 1280x720 격자에 그대로 둔다.
static func base_pixel_scale(window_size: Vector2i) -> int:
	var k := run_pixel_scale(window_size)
	if k > 0:
		return k
	return maxi(1, roundi(minf(window_size.x / float(Balance.BASE_LANDSCAPE.x), window_size.y / float(Balance.BASE_LANDSCAPE.y))))


## 기지 화면에 들어오고 나갈 때 기준 해상도를 바꾼다.
func set_base_mode(on: bool) -> void:
	base_mode = on
	fit_screen()


## 출격 화면의 정수 배율: 가장 가까운 정수 k를 고르고, 논리 화면(창 / k)이 RUN_VIEW_MIN보다 작으면 k를 낮춘다.
## 0이면 정수 배율로는 논리 화면을 범위(RUN_VIEW_MIN ~ 높이 RUN_VIEW_MAX_HEIGHT) 안에 못 맞춘다는 뜻 → 소수 배율로 그린다.
static func run_pixel_scale(window_size: Vector2i) -> int:
	var base := Balance.BASE_LANDSCAPE
	var k := maxi(1, roundi(minf(window_size.x / float(base.x), window_size.y / float(base.y))))
	while k > 1 and (window_size.x / k < Balance.RUN_VIEW_MIN.x or window_size.y / k < Balance.RUN_VIEW_MIN.y):
		k -= 1
	var view := run_view_size(window_size, k)
	if view.x < Balance.RUN_VIEW_MIN.x or view.y < Balance.RUN_VIEW_MIN.y or view.y > Balance.RUN_VIEW_MAX_HEIGHT:
		return 0
	return k


## 정수 배율 k일 때 출격 화면의 논리 크기 (남는 k-1 픽셀 이하는 가장자리 빈칸)
static func run_view_size(window_size: Vector2i, k: int) -> Vector2i:
	return Vector2i(window_size.x / k, window_size.y / k)


func fit_screen() -> void:
	var root := get_tree().root
	var k := 0 if base_mode else run_pixel_scale(root.size)
	if k > 0:
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		root.content_scale_size = run_view_size(root.size, k)
	else:
		# 기지 화면(1280x720, 3배 그림)과 정수 배율이 안 맞는 창은 예전처럼 소수 배율
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		root.content_scale_size = base_size_for(root.size, base_mode)
	set_portrait(is_portrait_size(root.size))


## 안내 화면을 켜고 끈다. 글자와 그림은 보이는 폭에 맞춰 크게.
func set_portrait(on: bool) -> void:
	var vis := get_tree().root.get_visible_rect().size
	var unit := vis.x / 10.0  # 폭의 10분의 1: 글자는 두 줄로 크게, 그림은 폭의 70%
	_rotate_label.add_theme_font_size_override("font_size", int(unit * 1.2))
	_rotate_icon.custom_minimum_size = Vector2(unit * 7.0, unit * 3.0)
	_rotate_layer.visible = on
	if on != portrait:
		portrait = on
		portrait_changed.emit(on)


## 세로 폰 → 가로 폰 그림 (글꼴에 화살표 글자가 없어도 보이게 도형으로 그린다)
class RotateIcon extends Control:
	const COLOR := Color("#59e4ff")

	func _draw() -> void:
		var u := size.y / 3.0
		var mid := size / 2.0
		# 왼쪽: 세로 폰 (단 0.9u 폭 × 2u 높이), 오른쪽: 가로 폰
		draw_rect(Rect2(mid + Vector2(-2.6 * u, -1.0 * u), Vector2(1.2 * u, 2.0 * u)), COLOR, false, maxf(u * 0.12, 2.0))
		draw_rect(Rect2(mid + Vector2(1.4 * u, -0.6 * u), Vector2(2.0 * u, 1.2 * u)), COLOR, false, maxf(u * 0.12, 2.0))
		# 가운데 화살표
		var w := maxf(u * 0.14, 2.0)
		draw_line(mid + Vector2(-0.7 * u, 0), mid + Vector2(0.9 * u, 0), COLOR, w)
		draw_colored_polygon(PackedVector2Array([mid + Vector2(1.2 * u, 0), mid + Vector2(0.7 * u, -0.35 * u), mid + Vector2(0.7 * u, 0.35 * u)]), COLOR)
