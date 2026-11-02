extends Node2D
## 출격 화면. 입력을 모아 RunSim을 진행시키고, 카메라·배경·HUD·메뉴를 갱신한다.
## 게임 규칙은 모두 RunSim(scripts/logic/run_sim.gd)에 있다.

const MAIN_SCENE := "res://scenes/main.tscn"

## 메뉴 종류
enum Menu { NONE, PAUSE, GAME_OVER, LEVEL_UP }


@onready var world: WorldView = $World
@onready var camera: Camera2D = $Camera
@onready var starfield: Starfield = $Background/Starfield
@onready var hud: Hud = $UI/Hud
@onready var joystick: TouchJoystick = $UI/Joystick
@onready var pause_button: Button = $UI/PauseButton
@onready var menu: MenuPanel = $UI/Menu
@onready var danger: DangerOverlay = $UI/Danger

var sim: RunSim
var current_menu := Menu.NONE
## 피격·위험 표시 상태
var alert := DangerAlert.new()
var _shake_rng := RandomNumberGenerator.new()


func _ready() -> void:
	sim = RunSim.new()
	world.sim = sim
	hud.sim = sim
	hud.alert = alert
	danger.alert = alert
	pause_button.pressed.connect(pause)
	menu.chosen.connect(_on_menu_chosen)


func _process(delta: float) -> void:
	sim.view_size = get_viewport_rect().size
	if current_menu == Menu.NONE and sim.alive:
		var keys := MoveInput.keyboard_vector(
			Input.is_action_pressed("move_left"), Input.is_action_pressed("move_right"),
			Input.is_action_pressed("move_up"), Input.is_action_pressed("move_down"))
		var move := MoveInput.combine(keys, joystick.vector)
		world.moving = move != Vector2.ZERO
		sim.update(delta, move)
		world.step(delta)
		_play_pickup_sounds()
		if alert.update(delta, sim.events.has("hit"), sim.hp / sim.max_hp):
			Sfx.play_warning()
		danger.time = sim.time
		if not sim.alive:
			_show_game_over()
		elif not sim.choices.is_empty():
			_show_level_up()
	camera.position = sim.player_pos.round()
	# 맞았을 때 화면 흔들림 (카메라만 살짝 밀고, 배경 별은 흔들지 않음)
	camera.offset = alert.shake_offset(_shake_rng) if current_menu == Menu.NONE else Vector2.ZERO
	starfield.scroll = camera.position
	world.queue_redraw()
	hud.queue_redraw()
	danger.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# 레벨업 메뉴에서는 숫자키 1, 2, 3으로도 고를 수 있다.
	if current_menu == Menu.LEVEL_UP and event is InputEventKey and event.pressed and not event.echo:
		var index := number_key_index(event.physical_keycode)
		if index >= 0 and index < sim.choices.size():
			menu.choose(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if current_menu == Menu.NONE:
			pause()
		elif current_menu == Menu.PAUSE:
			_close_menu()
		get_viewport().set_input_as_handled()


## 이번 프레임에 주운 광물의 효과음. 같은 등급은 한 프레임에 한 번만 낸다 (한꺼번에 주워도 시끄럽지 않게).
func _play_pickup_sounds() -> void:
	var played := {}
	for p in sim.picked:
		if not played.has(p["grade"]):
			played[p["grade"]] = true
			Sfx.play_pickup(p["grade"])


## 숫자키(윗줄 1~9, 키패드 1~9) → 0부터 시작하는 번호. 숫자키가 아니면 -1.
static func number_key_index(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_1
	return -1


func _notification(what: int) -> void:
	# 휴대폰에서 다른 앱으로 가거나 탭을 바꾸면 자동으로 멈춘다.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and current_menu == Menu.NONE and sim.alive:
		pause()


func pause() -> void:
	if current_menu != Menu.NONE or not sim.alive:
		return
	_open_menu(Menu.PAUSE, "일시 정지", "", ["계속하기", "처음으로"])


func _show_game_over() -> void:
	var body := "버틴 시간 %s · 레벨 %d\n부순 운석 %d개\n모은 광물 가치 %d\n(%s)" % [
		Hud.format_time(sim.time), sim.level, sim.kills, sim.mineral_value, Hud.minerals_text(sim.collected)]
	_open_menu(Menu.GAME_OVER, "우주선 파괴", body, ["다시 출격", "처음으로"])


## 레벨업 강화 선택 메뉴
func _show_level_up() -> void:
	var options: PackedStringArray = []
	for i in sim.choices.size():
		var id := sim.choices[i]
		var next := int(sim.upgrade_levels.get(id, 0)) + 1
		var label := Upgrades.display_name(id)
		if id != Upgrades.REPAIR:
			label += " Lv%d" % next
		options.append("%d. %s\n%s" % [i + 1, label, Upgrades.describe(id)])
	_open_menu(Menu.LEVEL_UP, "레벨 업! Lv %d" % (sim.level - sim.pending_levelups + 1), "강화를 하나 고르세요", options, Balance.LEVEL_UP_INPUT_DELAY)


func _open_menu(kind: Menu, title: String, body: String, options: PackedStringArray, input_delay: float = 0.0) -> void:
	current_menu = kind
	joystick.enabled = false
	pause_button.hide()
	world.moving = false
	menu.show_menu(title, body, options, input_delay)


func _close_menu() -> void:
	current_menu = Menu.NONE
	menu.hide()
	joystick.enabled = true
	pause_button.show()


func _on_menu_chosen(index: int) -> void:
	match current_menu:
		Menu.PAUSE:
			if index == 0:
				_close_menu()
			else:
				get_tree().change_scene_to_file(MAIN_SCENE)
		Menu.LEVEL_UP:
			sim.choose(index)
			_close_menu()  # 남은 레벨업이 있으면 다음 프레임에 다시 뜬다
		Menu.GAME_OVER:
			if index == 0:
				get_tree().reload_current_scene()
			else:
				get_tree().change_scene_to_file(MAIN_SCENE)
