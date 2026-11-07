extends Node
## 게임 전체 설정 (자동 로드: App).
## - 키보드 입력 동작(move_left 등)을 등록한다.
## - 화면이 가로/세로로 바뀌면 기준 해상도를 바꿔 글자와 그림 크기를 알맞게 유지한다.
## - 기지 화면은 2배 기준 해상도(1280x720, 세로 720x1280)로 그린다 (그림 1픽셀 = 화면 3픽셀, 글자는 픽셀 글꼴 3배).
##   출격 화면은 640x360 그대로.

## 기지 화면 기준 해상도 배율
const BASE_SCREEN_SCALE := 2

## 지금 기지 화면인지 (main.gd가 켜고 끈다)
var base_mode := false

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
	get_tree().root.size_changed.connect(fit_screen)
	fit_screen()


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


## 창 크기에 맞는 기준 해상도: 세로로 긴 화면은 세로용, 아니면 가로용. 기지 화면은 2배.
static func base_size_for(window_size: Vector2i, base_screen: bool = false) -> Vector2i:
	var s := Balance.BASE_PORTRAIT if window_size.y > window_size.x else Balance.BASE_LANDSCAPE
	return s * BASE_SCREEN_SCALE if base_screen else s


## 기지 화면에 들어오고 나갈 때 기준 해상도를 바꾼다.
func set_base_mode(on: bool) -> void:
	base_mode = on
	fit_screen()


func fit_screen() -> void:
	var root := get_tree().root
	root.content_scale_size = base_size_for(root.size, base_mode)
