extends Control
## 기지 화면 (시작 화면): 소행성 위의 광부 조합 전초기지.
## 가운데 우주선을 누르면 출격, 건물을 누르면 그 화면이 열린다 (연구소·격납고·광물 창고·전시관, 드론 공장은 안내만).
## 풍경은 BaseView, 고정 UI는 BaseHud, 건물 화면은 BasePanel, 배치는 BaseLayout, 끌기 판정은 BaseDrag, 저장은 SaveData에 있다.
## 풍경과 고정 UI는 정수 배율 Stage 안에 있고(App.base_pixel_scale), 건물 창·결과 창·안내 문구는 1280x720 격자에 그대로 둔다.

const RUN_SCENE := "res://scenes/run.tscn"
## 안내 문구가 보이는 시간
const TOAST_TIME := 2.5
## 착륙장 고리와 출격 버튼 사이 (누르는 자리가 판보다 커서 음수로 판이 고리에 붙는다)
const SORTIE_GAP := -4.0
const DRONE_NOTICE := "드론 공장은 공사 중이에요. 곧 개방!"

## 이전 버전 목록 페이지로 이동하는 자바스크립트.
## 보관된 이전 버전(.../versions/v0.0.1/)에서 눌러도 같은 목록(.../versions/)으로 가도록
## 현재 주소에 '/versions/'가 있으면 그 앞부분을 기준으로 삼는다.
const OPEN_OLD_VERSIONS_JS := """
(function () {
	var path = window.location.pathname;
	var i = path.indexOf('/versions/');
	var base = i >= 0 ? path.slice(0, i + 1) : path.slice(0, path.lastIndexOf('/') + 1);
	window.location.href = base + 'versions/';
})();
"""

## 이륙이 끝나 출격 화면으로 넘어가기 직전
signal launched

@onready var version_label: Label = %VersionLabel
@onready var old_versions_button: Button = %OldVersionsButton
@onready var credits_label: Label = %CreditsLabel
@onready var fullscreen_button: Button = %FullscreenButton
@onready var stage: Control = %Stage
@onready var world: Control = %World
@onready var view: BaseView = %View
@onready var spots: Control = %Spots
@onready var hud: BaseHud = %Hud
@onready var starfield: Starfield = %Starfield
@onready var panel: BasePanel = %Panel
@onready var toast: Label = %Toast

var save: SaveData
## id(BaseLayout.IDS) → 누르는 자리 버튼
var spot_buttons: Dictionary = {}
## 이륙 중인지
var launching := false
## 이륙이 끝나면 출격 화면으로 넘어갈지 (테스트에서는 끈다)
var auto_start := true
## 지금까지 소리를 낸 워프 단계 (WarpJump.Phase)
var _launch_phase := WarpJump.Phase.TAKEOFF
var _launch_done := false
## 점프·착륙 때 화면 전체를 덮는 흰 번쩍임
var _white := ColorRect.new()
## 귀환 결과 창 (착륙이 끝나면 기지 위에 뜬다)
var result_menu := MenuPanel.new()
var _pending_result := {}
var _toast_time := 0.0
## 마지막 입력이 키보드였는지 (건물 화면을 키보드로 닫았을 때만 우주선에 포커스 테두리를 보인다)
var _keyboard := false
## 첫 화면에서 끌어 옮긴 양 (그림 픽셀), 끌기 판정
var cam := Vector2.ZERO
var drag := BaseDrag.new()
## 착륙장으로 돌아가는 중에 쓰는 소수 위치 (이륙 때)
var _cam_smooth := Vector2.ZERO


func _ready() -> void:
	App.set_base_mode(true)  # 건물 창·결과 창은 1280x720 격자 (그림 1픽셀 = 화면 3픽셀)
	_setup_stage()
	Music.set_base()
	version_label.text = "v" + game_version()
	# 이전 버전 링크는 웹(GitHub Pages)에서만 의미가 있으므로 웹에서만 보여 준다.
	old_versions_button.visible = OS.has_feature("web")
	old_versions_button.pressed.connect(_on_old_versions_pressed)
	# 버튼 눌림: 그림 1픽셀 내려감 + 밝아짐
	MenuPanel.add_press_feel(old_versions_button, 1)
	# 전체 화면 버튼도 웹에서 브라우저가 허용할 때만 보인다 (전체 화면에 들어가면 App이 가로 고정을 시도)
	fullscreen_button.visible = OS.has_feature("web") and bool(JavaScriptBridge.eval("!!document.fullscreenEnabled"))
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	MenuPanel.add_press_feel(fullscreen_button, 1)
	hud.sortie.pressed.connect(press.bind("ship"))
	MenuPanel.add_press_feel(hud.sortie, 1)
	save = SaveData.load_file()
	panel.save = save
	panel.closed.connect(_on_panel_closed)
	panel.bought.connect(func(_id: String) -> void: refresh())
	for id in BaseLayout.IDS:
		var b := Button.new()
		b.flat = true
		b.tooltip_text = BaseLayout.NAMES[id]
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, empty)
		b.add_theme_stylebox_override("focus", empty)  # 고른 표시는 BaseView가 건물 윤곽선으로 그린다
		b.pressed.connect(press.bind(id))
		# 마우스를 올리거나 키보드로 고르면 윤곽선이 빛나고, 누르는 순간 번쩍인다
		b.mouse_entered.connect(_set_hover.bind(id, true))
		b.mouse_exited.connect(_set_hover.bind(id, false))
		b.focus_entered.connect(_on_spot_focus.bind(id))
		b.focus_exited.connect(_set_hover.bind(id, false))
		b.button_down.connect(view.flash.bind(id))
		spots.add_child(b)
		spot_buttons[id] = b
	var toast_bg := StyleBoxFlat.new()
	toast_bg.bg_color = Color(0.02, 0.02, 0.06, 0.85)
	toast_bg.border_color = Color("#ffd34f")
	toast_bg.set_border_width_all(BaseLayout.UI_PIXEL)
	toast_bg.set_content_margin_all(BaseLayout.UI_PIXEL * 3)
	toast.add_theme_stylebox_override("normal", toast_bg)
	get_tree().root.size_changed.connect(_fit_stage)
	_fit_stage()
	refresh()
	_white.color = Color.WHITE
	_white.modulate.a = 0.0
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_menu.ui_scale = BaseLayout.UI_PIXEL
	result_menu.chosen.connect(_on_result_chosen)
	add_child(result_menu)
	result_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if App.landing:
		App.landing = false
		_pending_result = App.return_result
		App.return_result = {}
		view.start_landing()
		Sfx.play_landing()
	_show_hint_once()
	# 처음엔 포커스 테두리를 띄우지 않는다. Enter/Space는 바로 출격, 방향키를 누르면 그때부터 포커스가 생긴다 (_unhandled_input).


## 게임 버전 (project.godot의 application/config/version)
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Stage에 끌어도 흔들리지 않는 격자용 설정: 글자도 그림과 같은 칸으로 그려지게 번짐·겹쳐 그리기를 끈다.
func _setup_stage() -> void:
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var font: FontFile = (load("res://assets/fonts/galmuri/Galmuri11.ttf") as FontFile).duplicate()
	font.oversampling = 1.0
	stage.theme = Theme.new()
	stage.theme.default_font = font
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("base10"):
		App.base_debug_busy = true


## 창 크기가 바뀔 때: 정수 배율을 다시 맞추고 배치·버튼·카메라를 다시 잡는다.
## 부모(루트)가 1280x720 기준 소수 배율이라, 그 배율을 나눠서 최종 배율이 정확히 k가 되게 한다.
func _fit_stage() -> void:
	var win := get_window().size
	var k := App.base_pixel_scale(win)
	var root_scale := get_tree().root.get_final_transform().get_scale()
	stage.scale = Vector2(k, k) / root_scale
	stage.size = (Vector2(win) / k).floor()
	hud.relayout()
	view.setup(hud.large, App.base_debug_busy)
	drag.threshold = Balance.BASE_DRAG_THRESHOLD_LARGE if hud.large else Balance.BASE_DRAG_THRESHOLD_SMALL
	_place_spots()
	_apply_cam(cam)


## 건물·착륙장 버튼을 누르는 자리에 맞춘다.
func _place_spots() -> void:
	for id in spot_buttons:
		var r := BaseLayout.touch_rect(id, view.large)
		var b: Button = spot_buttons[id]
		b.position = r.position
		b.size = r.size


## 카메라를 옮긴다: 지도 끝에서 멈추고, 풍경·별·출격 버튼을 따라 움직인다.
func _apply_cam(value: Vector2) -> void:
	cam = BaseLayout.clamp_cam(value, view.map, stage.size)
	world.position = BaseLayout.center_origin(stage.size) + cam
	view.visible_rect = Rect2(-world.position, stage.size)
	starfield.scroll = -cam * stage.scale.x  # 별은 루트(1280x720) 좌표
	var s := hud.sortie
	var front := world.position + Vector2(0, BaseLayout.RING_TOUCH.y / 2.0 + SORTIE_GAP + s.size.y)
	s.position = BaseLayout.sortie_pos(front, s.size, stage.size, hud.top_h, hud.bottom_h)


## 강조할 건물을 정한다 (빠져나간 건물이 지금 강조 중일 때만 끈다)
func _set_hover(id: String, on: bool) -> void:
	if on:
		view.hover_id = id
	elif view.hover_id == id:
		view.hover_id = ""


## 키보드로 고른 건물: 강조하고, 화면 밖이면 따라간다
func _on_spot_focus(id: String) -> void:
	_set_hover(id, true)
	_apply_cam(BaseLayout.reveal_cam(cam, BaseLayout.touch_rect(id, view.large), view.map, stage.size, hud.top_h, hud.bottom_h))


## 보유 광물과 기지 모습(연구 불빛, 광물 더미)을 저장 내용에 맞춘다.
func refresh() -> void:
	credits_label.text = "보유 광물 %s" % Hud.thousands(save.credits)
	hud.refresh_text()
	view.levels = save.upgrades
	view.credits = save.credits


## 우주선·건물을 눌렀을 때
func press(id: String) -> void:
	if drag.dragged:
		return  # 끌다가 놓은 것은 누름이 아니다
	if launching or panel.visible or result_menu.visible or view.landing_t >= 0.0:
		return
	match id:
		"ship":
			launch()
		"drone":
			Sfx.play("click")
			show_toast(DRONE_NOTICE)
		_:
			Sfx.play("open")
			panel.open(id)


## 워프 점프 출격: 이륙 → 충전 → 점프 뒤 출격 화면(터널 → 도착)으로 넘어간다.
func launch() -> void:
	if launching:
		return
	launching = true
	_cam_smooth = cam
	toast.hide()
	view.start_launch()
	Sfx.play_takeoff()
	for b in spot_buttons.values():
		b.disabled = true
	hud.sortie.disabled = true
	hud.sortie.hide()
	hud.hint.hide()


## 이륙 진행: 단계가 바뀔 때 소리를 내고, 끝나면 출격 화면으로 넘어간다.
func _step_launch() -> void:
	var t := view.launch_t
	var phase := WarpJump.phase(t)
	if phase != _launch_phase:
		_launch_phase = phase
		if phase == WarpJump.Phase.CHARGE:
			Sfx.play_warp_launch()
		elif phase == WarpJump.Phase.JUMP:
			Sfx.play_warp_done()
	_white.modulate.a = WarpJump.base_white(t)
	if t >= BaseView.LAUNCH_TIME:
		_finish_launch(true)


## with_tunnel: 끝까지 봤으면 터널이 이어지고, 건너뛰었으면 바로 출격 화면
func _finish_launch(with_tunnel: bool) -> void:
	if _launch_done:
		return
	_launch_done = true
	launched.emit()
	if auto_start:
		App.warp_intro = with_tunnel
		start_run()


func start_run() -> void:
	get_tree().change_scene_to_file(RUN_SCENE)


func show_toast(text: String) -> void:
	toast.text = text
	toast.show()
	_toast_time = TOAST_TIME


func _process(delta: float) -> void:
	if launching and not _launch_done:
		_cam_smooth = _cam_smooth.lerp(Vector2.ZERO, minf(delta * Juice.BASE_CAM_RETURN, 1.0))  # 끌어 둔 화면이 착륙장으로 돌아온다
		_apply_cam(_cam_smooth)
		_step_launch()
	elif view.landing_t >= 0.0:
		_white.modulate.a = WarpJump.land_white(view.landing_t)
	else:
		_white.modulate.a = 0.0
		if not _pending_result.is_empty():
			_show_result()
	if _toast_time > 0.0:
		_toast_time -= delta
		toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		if _toast_time <= 0.0:
			toast.hide()


## 착륙이 끝나면 귀환 결과를 기지 위에 띄운다. 뒤쪽 건물은 키보드로도 못 고르게 숨긴다.
func _show_result() -> void:
	spots.hide()
	hud.sortie.hide()
	result_menu.show_menu(_pending_result["title"], _pending_result["body"], ["다시 출격", "확인"])
	_pending_result = {}


func _on_result_chosen(index: int) -> void:
	Sfx.play("click")
	spots.show()
	hud.sortie.show()
	if index == 0:
		launch()


func _on_panel_closed() -> void:
	refresh()
	if _keyboard:
		spot_buttons["ship"].grab_focus()  # 키보드로 닫았으면 이어서 키보드로 고를 수 있게
	else:
		if get_viewport().gui_get_focus_owner() != null:
			get_viewport().gui_get_focus_owner().release_focus()  # 터치·마우스로 닫았으면 테두리 없이
		view.hover_id = ""  # 휴대폰은 탭이 마우스 올림으로도 들어와 닫은 뒤에도 빛나 있지 않게


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_keyboard = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		_keyboard = false
	_drag_input(event)
	# 두 번째 출격부터는 눌러서 건너뛴다 (저장)
	if launching and not _launch_done and save.warp_seen and WarpJump.is_skip_press(event):
		Sfx.stop_launch_sounds()
		_finish_launch(false)


## 끌어서 둘러보기. 손가락은 Godot가 마우스로도 바꿔 주므로 마우스 이벤트만 본다 (둘 다 보면 두 배로 움직임).
func _drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos: Vector2 = event.position / stage.scale
			if _can_drag(pos):
				drag.press(pos)
		else:
			drag.release()
			_clear_drag.call_deferred()  # 버튼의 pressed가 먼저 막힌 뒤에 푼다
	elif event is InputEventMouseMotion and drag.down:
		var was := drag.dragged
		var d := drag.move(event.position / stage.scale)
		if drag.dragged and not was:
			_on_drag_started()
		if d != Vector2.ZERO:
			_apply_cam(cam + d)


func _clear_drag() -> void:
	drag.dragged = false


func _can_drag(pos: Vector2) -> bool:
	return not (launching or panel.visible or result_menu.visible or view.landing_t >= 0.0 or App.portrait or hud.hits_button(pos))


## 끌기가 시작되면 누른 건물의 번쩍임·이름표를 끄고, 안내를 거둔다.
func _on_drag_started() -> void:
	view.pressed_id = ""
	view.hover_id = ""
	hud.hint.hide()


## 첫 방문에 한 번만: 끌어서 볼 곳이 있으면 안내. 본 것으로 저장한다.
func _show_hint_once() -> void:
	if save.drag_hint_seen or not BaseLayout.can_pan(view.map, stage.size):
		return
	save.drag_hint_seen = true
	save.save_file()
	hud.hint.show()


func _exit_tree() -> void:
	App.set_base_mode(false)  # 출격 화면은 정수 배율 (논리 화면 = 창 / 배율)


## 아무것도 고르지 않았을 때: Enter/Space → 출격, 방향키 → 우주선부터 고르기 시작
func _unhandled_input(event: InputEvent) -> void:
	if panel.visible or result_menu.visible or launching or get_viewport().gui_get_focus_owner() != null:
		return
	if event.is_action_pressed("confirm"):
		press("ship")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		spot_buttons["ship"].grab_focus()
		get_viewport().set_input_as_handled()


## 웹에서 같은 탭으로 이전 버전 목록을 연다.
func _on_old_versions_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(OPEN_OLD_VERSIONS_JS)


## 전체 화면을 켜고 끈다 (사용자가 누른 순간에 요청해야 브라우저가 허용한다).
func _on_fullscreen_pressed() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
