class_name BaseHud
extends Control
## 기지 화면의 고정 UI: 상단 바(제목, 보유 광물, 전체 화면), 아래 버전 표시, 이전 버전, 출격, 둘러보기 안내.
## 카드 프레임과 같은 금속 알약 판. 풍경과 같은 정수 배율 Stage 안에 있고, 끌어도 움직이지 않는다.

## 알약 그림: 원래 크기(바·버튼), 절반(이름표)
const PILL := "res://assets/sprites/run/card/pill.png"
const PILL_HALF := "res://assets/sprites/station/pill_half.png"
const INK := Color("#fef8e5")
const GOLD := Color("#f6ce50")
const TEAL := Color("#99e9e6")
const BAR_Y := 3.0
const ORE := "res://assets/sprites/run/mineral_3.png"
## 버튼은 손가락으로 누르기 쉽게 판보다 크게 (그림 픽셀)
const TOUCH_MIN := 44.0

@onready var title: Label = %Title
@onready var credits: Label = %CreditsLabel
@onready var fullscreen: Button = %FullscreenButton
@onready var version: Label = %VersionLabel
@onready var old_versions: Button = %OldVersionsButton
@onready var sortie: Button = %SortieButton
@onready var hint: Label = %Hint

## 글자가 2배인 폰 배치인지
var large := false
## 위아래 바 몫 (풍경을 키보드로 따라갈 때, 출격 버튼 자리)
var top_h := 28.0
## 창 소리 시험 버튼 (평소 없음)
var click_test: Button
var bottom_h := 25.0
var _ore := TextureRect.new()


## 금속 알약 9칸 판 (가운데 1줄만 늘어남)
static func plate_style(half := false) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(PILL_HALF if half else PILL)
	var mx := s.texture.get_width() / 2
	var my := s.texture.get_height() / 2
	s.texture_margin_left = mx
	s.texture_margin_right = mx
	s.texture_margin_top = my
	s.texture_margin_bottom = my
	s.set_content_margin_all(0.0)  # 판 크기는 relayout이 정한다 (여백이 최소 크기를 키우지 않게)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [title, credits, version, hint]:
		l.add_theme_stylebox_override("normal", plate_style(l == hint or l == version))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", TEAL)
	credits.add_theme_color_override("font_color", GOLD)
	version.add_theme_color_override("font_color", TEAL)
	hint.add_theme_color_override("font_color", TEAL)
	_ore.texture = load(ORE)
	_ore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits.add_child(_ore)
	for b: Button in [fullscreen, old_versions, sortie]:
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, empty)
		var plate := Panel.new()
		plate.name = "Plate"
		plate.show_behind_parent = true
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", plate_style(b == old_versions))
		b.add_child(plate)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		sortie.add_theme_color_override(color_name, GOLD)
		old_versions.add_theme_color_override(color_name, TEAL)
		fullscreen.add_theme_color_override(color_name, INK)


## 글자 폭 + 양끝 장식 폭으로 판 크기를 정하고 화면 가장자리에 놓는다.
func relayout() -> void:
	large = size.x >= LevelCard.LARGE_MIN.x and size.y >= LevelCard.LARGE_MIN.y
	var font_size := 24 if large else 12
	var bar := 36.0 if large else 25.0
	top_h = BAR_Y + bar
	bottom_h = 25.0
	_place_label(title, Vector2(4, BAR_Y), font_size, bar, 84.0)
	_place_label(credits, Vector2.ZERO, font_size, bar, 100.0)
	credits.position = Vector2(floorf((size.x - credits.size.x) / 2.0), BAR_Y)
	_ore.size = _ore.texture.get_size()
	_ore.position = Vector2(26, floorf((bar - _ore.size.y) / 2.0))
	_place_label(version, Vector2.ZERO, 12, 21.0, 36.0)
	version.position = Vector2(size.x - version.size.x - 8.0, size.y - 25.0)
	_place_button(fullscreen, font_size, bar, 84.0)
	fullscreen.position.x = size.x - fullscreen.size.x - 4.0
	fullscreen.position.y = BAR_Y + bar / 2.0 - fullscreen.size.y / 2.0
	_place_button(old_versions, 12, 21.0, 36.0)
	old_versions.position = Vector2(8.0, size.y - 14.5 - old_versions.size.y / 2.0)
	_place_button(sortie, font_size, 34.0 if large else 25.0, 76.0)
	_place_label(hint, Vector2.ZERO, 12, 19.0, 36.0)
	if click_test != null:
		click_test.size = Vector2(84.0, 34.0)  # 시험용이라 판 그림 없이, 손가락으로 누를 크기
		click_test.position = Vector2(size.x - click_test.size.x - 8.0, version.position.y - click_test.size.y - 4.0)
	hint.position = Vector2(version.position.x - hint.size.x - 8.0, size.y - hint.size.y)  # 버전 표시 왼쪽의 아래 띠: 가운데 착륙장을 피하고 건물 칸보다 아래


## 버튼 소리 시험 버튼 (?clicktest에서만 만든다): 오른쪽 아래, 버전 글자 위
func add_click_test() -> Button:
	click_test = Button.new()
	click_test.text = "버튼 소리"
	click_test.focus_mode = Control.FOCUS_NONE
	add_child(click_test)
	relayout()
	return click_test


## 보유 광물 글자가 바뀌면 판 폭도 다시
func refresh_text() -> void:
	if is_node_ready():
		relayout()


func _text_width(c: Control, text: String, font_size: int) -> float:
	return ceilf(c.get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


func _place_label(l: Label, pos: Vector2, font_size: int, h: float, pad: float) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.position = pos
	l.size = Vector2(_text_width(l, l.text, font_size) + pad, h)


## 버튼: 누르는 자리는 TOUCH_MIN 이상, 판은 그 가운데.
func _place_button(b: Button, font_size: int, h: float, pad: float) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	var w := _text_width(b, b.text, font_size) + pad
	b.size = Vector2(w, maxf(h, TOUCH_MIN))
	var plate: Panel = b.get_node("Plate")
	plate.size = Vector2(w, h)
	plate.position = Vector2(0, floorf((b.size.y - h) / 2.0))


## 고정 버튼이 pos(Stage 좌표)를 덮는지 (그 위에서는 끌기를 시작하지 않는다)
func hits_button(pos: Vector2) -> bool:
	for b: Button in [fullscreen, old_versions, sortie, click_test]:
		if b != null and b.visible and Rect2(b.position, b.size).has_point(pos):
			return true
	return false
