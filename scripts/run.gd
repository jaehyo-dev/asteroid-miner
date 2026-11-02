extends Node2D
## 출격 화면. 입력을 모아 RunSim을 진행시키고, 카메라·배경·HUD·메뉴를 갱신한다.
## 게임 규칙은 모두 RunSim(scripts/logic/run_sim.gd)에 있다.

const MAIN_SCENE := "res://scenes/main.tscn"

## 메뉴 종류
enum Menu { NONE, PAUSE, GAME_OVER }

@onready var world: WorldView = $World
@onready var camera: Camera2D = $Camera
@onready var starfield: Starfield = $Background/Starfield
@onready var hud: Hud = $UI/Hud
@onready var joystick: TouchJoystick = $UI/Joystick
@onready var pause_button: Button = $UI/PauseButton
@onready var menu: MenuPanel = $UI/Menu

var sim: RunSim
var current_menu := Menu.NONE


func _ready() -> void:
	sim = RunSim.new()
	world.sim = sim
	hud.sim = sim
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
		if not sim.alive:
			_show_game_over()
	camera.position = sim.player_pos.round()
	starfield.scroll = camera.position
	world.queue_redraw()
	hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if current_menu == Menu.NONE:
			pause()
		elif current_menu == Menu.PAUSE:
			_close_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# 휴대폰에서 다른 앱으로 가거나 탭을 바꾸면 자동으로 멈춘다.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and current_menu == Menu.NONE and sim.alive:
		pause()


func pause() -> void:
	if current_menu != Menu.NONE or not sim.alive:
		return
	_open_menu(Menu.PAUSE, "일시 정지", "", ["계속하기", "처음으로"])


func _show_game_over() -> void:
	var body := "버틴 시간 %s" % Hud.format_time(sim.time)
	_open_menu(Menu.GAME_OVER, "우주선 파괴", body, ["다시 출격", "처음으로"])


func _open_menu(kind: Menu, title: String, body: String, options: PackedStringArray) -> void:
	current_menu = kind
	joystick.enabled = false
	pause_button.hide()
	world.moving = false
	menu.show_menu(title, body, options)


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
		Menu.GAME_OVER:
			if index == 0:
				get_tree().reload_current_scene()
			else:
				get_tree().change_scene_to_file(MAIN_SCENE)
