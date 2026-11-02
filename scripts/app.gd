extends Node
## 게임 전체 설정 (자동 로드: App).
## - 키보드 입력 동작(move_left 등)을 등록한다.
## - 화면이 가로/세로로 바뀌면 기준 해상도를 바꿔 글자와 그림 크기를 알맞게 유지한다.

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


## 창 크기에 맞는 기준 해상도: 세로로 긴 화면은 세로용, 아니면 가로용
static func base_size_for(window_size: Vector2i) -> Vector2i:
	return Balance.BASE_PORTRAIT if window_size.y > window_size.x else Balance.BASE_LANDSCAPE


func fit_screen() -> void:
	var root := get_tree().root
	root.content_scale_size = base_size_for(root.size)
