extends Node2D
## 출격 화면. 입력을 모아 RunSim을 진행시키고, 카메라·배경·HUD·메뉴를 갱신한다.
## 게임 규칙은 모두 RunSim(scripts/logic/run_sim.gd)에 있다.

const MAIN_SCENE := "res://scenes/main.tscn"

## "??? 의 포격" 배너 색 (심연의 붉은 보라)
const BARRAGE_BANNER_COLOR := Color("#ff6aa8")
## 워프 게이트 배너 색
const GATE_BANNER_COLOR := Color("#7cf0ff")

## 메뉴 종류
enum Menu { NONE, PAUSE, GAME_OVER, LEVEL_UP }
## 일시 정지 메뉴의 설정 버튼 번호
const PAUSE_SHAKE := 1
const PAUSE_SFX := 2
const PAUSE_MUSIC := 3
## 일시 정지 제목을 이만큼 이 시간(밀리초) 안에 누르면 FPS 표시를 켜고 끈다
const FPS_TAPS := 5
const FPS_TAP_WINDOW_MS := 2000


@onready var world: WorldView = $World
@onready var gate_view: GateView = $Gate
@onready var camera: Camera2D = $Camera
@onready var starfield: Starfield = $Background/Starfield
@onready var hud: Hud = $UI/Hud
@onready var joystick: TouchJoystick = $UI/Joystick
@onready var pause_button: Button = $UI/PauseButton
@onready var menu: MenuPanel = $UI/Menu
@onready var danger: DangerOverlay = $UI/Danger

var sim: RunSim
var current_menu := Menu.NONE
## 기지 저장 (출격 전 업그레이드 적용, 판이 끝나면 광물을 더해 저장)
var save: SaveData
## 이번 판 결과를 저장에 더했는지 (한 판에 한 번만)
var banked := false
## 피격·위험 표시 상태
var alert := DangerAlert.new()
var _shake_rng := RandomNumberGenerator.new()
## 히트스톱 남은 시간 (큰 운석·황금 운석을 부순 순간 시뮬레이션만 멈춤, Engine.time_scale은 안 씀)
var hitstop := 0.0
## 레벨업 슬로모션 남은 시간 (끝나면 강화 카드가 뜬다)
var slowmo := 0.0
## 광물 연속 줍기 음 높이
var _combo := PickupCombo.new()
## 운석 깨짐 소리가 몰리면 작게·적게
var _break_sounds := SoundThrottle.new(Juice.BREAK_SOUND_WINDOW, Juice.BREAK_SOUND_MAX, Juice.BREAK_SOUND_STEP_DB)
## 다음 히트스톱을 걸 수 있는 시뮬레이션 시각
var _hitstop_ready_at := 0.0
## 일시 정지 제목을 누른 시각 (FPS 표시)
var _title_taps: Array[int] = []


func _ready() -> void:
	sim = RunSim.new()
	save = SaveData.load_file()
	sim.apply_base(save.upgrades)
	world.sim = sim
	gate_view.sim = sim
	world.gate_fx = gate_view.fx
	hud.sim = sim
	hud.alert = alert
	danger.alert = alert
	pause_button.pressed.connect(func() -> void:
		Sfx.play("click")
		pause())
	MenuPanel.add_press_feel(pause_button)
	menu.chosen.connect(_on_menu_chosen)
	menu.title_tapped.connect(_on_title_tapped)
	Music.set_run_time(0.0)
	# 폰을 세로로 들면 일시 정지 (가로로 돌리면 일시 정지 메뉴에서 이어서 한다)
	App.portrait_changed.connect(_on_portrait_changed)
	if App.portrait:
		pause()


func _process(delta: float) -> void:
	sim.view_size = get_viewport_rect().size
	Music.set_run_time(sim.time)
	if current_menu == Menu.NONE and not sim.is_over() and hitstop > 0.0:
		# 히트스톱: 시뮬레이션·월드 효과는 멈추고 화면 흔들림·HUD만 진행 (입력은 매 프레임 다시 읽으므로 끊기지 않음)
		hitstop = maxf(hitstop - delta, 0.0)
		alert.update(delta, false, sim.hp / sim.max_hp)
		hud.step(delta)
	elif current_menu == Menu.NONE and not sim.is_over():
		var keys := MoveInput.keyboard_vector(
			Input.is_action_pressed("move_left"), Input.is_action_pressed("move_right"),
			Input.is_action_pressed("move_up"), Input.is_action_pressed("move_down"))
		var move := MoveInput.combine(keys, joystick.vector)
		world.moving = move != Vector2.ZERO
		# 레벨업 슬로모션: 실제 시간 LEVELUP_SLOWMO_TIME 동안 시뮬레이션을 느리게 (그동안은 강화를 고르기 전이어도 진행)
		var sim_delta := delta * Juice.LEVELUP_SLOWMO_SCALE if slowmo > 0.0 else delta
		slowmo = maxf(slowmo - delta, 0.0)
		sim.run_during_levelup = slowmo > 0.0
		sim.update(sim_delta, move)
		world.step(sim_delta)
		_start_juice()
		world.levelup_light = slowmo / Juice.LEVELUP_SLOWMO_TIME
		_announce(gate_view.step(sim_delta, sim.events))
		_play_sounds()
		if alert.update(delta, sim.events.has("hit"), sim.hp / sim.max_hp):
			Sfx.play_warning()
		hud.step(delta)
		_update_bonus(delta)
		_discover()
		_announce(sim.events)
		danger.time = sim.time
		if not sim.alive:
			_show_game_over()
		elif not sim.choices.is_empty() and slowmo <= 0.0:
			_show_level_up()
	elif current_menu == Menu.NONE and sim.returned:
		# 귀환 성공 연출: 우주선이 빨려 들어가고 화면이 하얗게 번쩍인 뒤 결과 화면
		gate_view.step(delta, PackedStringArray())
		hud.white = gate_view.fx.white_flash()
		if gate_view.fx.warp_finished():
			hud.white = 0.0
			_show_game_over()
	camera.position = sim.player_pos.round()
	# 맞았을 때 화면 흔들림 (카메라만 살짝 밀고, 배경 별은 흔들지 않음)
	camera.offset = alert.shake_offset(_shake_rng) if current_menu == Menu.NONE and App.settings.shake else Vector2.ZERO
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


## 이번 프레임 사건으로 손맛 연출을 건다: 큰 운석·황금 운석 히트스톱+약한 흔들림, 레벨업 슬로모션.
func _start_juice() -> void:
	for a in sim.destroyed:
		if a.golden or (a.kind == RunSim.ROCK and a.type == 2):
			alert.kick(Juice.BREAK_SHAKE_TIME, Juice.BREAK_SHAKE_STRENGTH)
			if sim.time >= _hitstop_ready_at or a.golden:
				hitstop = maxf(hitstop, Juice.HITSTOP_GOLD if a.golden else Juice.HITSTOP_BIG)
				_hitstop_ready_at = sim.time + Juice.HITSTOP_COOLDOWN
	if sim.events.has("levelup") and slowmo <= 0.0:
		slowmo = Juice.LEVELUP_SLOWMO_TIME


## 새로운 위협과 습격을 배너·소리로 알린다.
func _announce(events: PackedStringArray) -> void:
	for e in events:
		if e == "new_barrage":
			hud.show_banner("??? 의 포격", BARRAGE_BANNER_COLOR)
		elif e == "cargo_heavy":
			hud.show_banner("화물이 무거워 느려져요", Hud.COLOR_FULL)
			Sfx.play("cargo_heavy")
		elif e == "barrage_warning":
			Sfx.play("barrage_warn")
		elif e == "barrage_fire":
			Sfx.play("barrage_fire")
		elif e == "guard_fire":
			Sfx.play_guard()
		elif e == "gate_open":
			hud.show_banner("워프 게이트 열림!", GATE_BANNER_COLOR)
			Sfx.play_gate_assemble()
		elif e == "gate_locked":
			Sfx.play_gate_lock()
			Sfx.start_gate_hum()
		elif e == "gate_closing":
			Sfx.play_gate_alarm()
		elif e == "gate_close":
			Sfx.stop_gate_hum()
			Sfx.play_gate_collapse()
		elif e == "warp_charge":
			Sfx.play_warp_charge()
		elif e == "warp_cancel":
			Sfx.stop_warp_charge()
			hud.show_banner("워프 충전 취소", Hud.COLOR_DANGER)
		elif e == "warp_done":
			Sfx.stop_gate_hum()
			Sfx.play_warp_done()
		elif e == "raid_golden":
			hud.show_banner("습격 속에 황금 운석!", Hud.COLOR_GOLD)
		elif e == "new_guard":
			hud.show_banner("새로운 위협: %s" % Balance.GUARD["name"], WorldView.GUARD_GLOW)
		elif e == "raid_warning":
			hud.show_banner("!! %s 접근 !!" % RaidDirector.display_name(sim.raid.kind), Hud.COLOR_DANGER)
			Sfx.play_raid()
		elif e.begins_with("new_"):
			var creature := e.substr(4)
			hud.show_banner("새로운 위협: %s" % Balance.CREATURES[creature]["name"], WorldView.JELLY_COLOR if creature == "jelly" else WorldView.BUG_COLOR)


## 광물 보너스 표시를 진행한다. 보너스가 처음 오를 때(+1%) 한 번만 말풍선을 띄우고, 봤다는 것을 저장한다.
func _update_bonus(delta: float) -> void:
	hud.bonus.update(delta, sim.time)
	if not save.risk_tip_seen and RiskBonus.percent(sim.time) > 0:
		save.risk_tip_seen = true
		save.save_file()
		hud.show_tip()


## 도감: 화면에 처음 보인 적과 처음 주운 광물을 기록하고, 새로 본 것이 있으면 바로 저장한다.
func _discover() -> void:
	var found := false
	for id in Discovery.seen_now(sim):
		if save.discover(id):
			found = true
	if found:
		save.save_file()


## 이번 프레임 사건의 효과음: 발사, 맞음, 깨짐(크기별)·적 파괴, 피격, 레벨업, 광물 줍기.
## 같은 소리가 많이 겹치는 것은 Sfx.play가 동시 재생 수로 막는다.
func _play_sounds() -> void:
	for e in sim.events:
		if e == "shoot" or e == "hit_rock" or e == "hit_enemy":
			Sfx.play(e)
		elif e == "hit":
			Sfx.play("player_hit")
		elif e == "levelup":
			Sfx.play("levelup")
	for a in sim.destroyed + sim.crashed:
		var db := _break_sounds.next_db(sim.time) if a.kind == RunSim.ROCK else 0.0
		if a.golden or (a.kind == RunSim.ROCK and a.type == 2):
			db = 0.0  # 큰·황금 운석은 멈칫하는 순간이므로 몰려도 소리를 그대로 낸다 (수에는 들어감)
		if db > -INF:
			Sfx.play(break_sound(a), -1.0, 1.0, db)
	# 줍기: 같은 등급은 한 프레임에 한 번만, 1초 안에 연속으로 주우면 음이 올라감
	if sim.picked.is_empty():
		return
	var pitch := PickupCombo.pitch_of(_combo.pick(sim.time))
	var played := {}
	for p in sim.picked:
		if not played.has(p["grade"]):
			played[p["grade"]] = true
			Sfx.play("pickup_%d" % p["grade"], 0.0, pitch)


## 부서진 적의 소리 이름: 운석은 크기별(황금 운석은 큰 것과 같음), 생명체·경비선은 적 파괴
static func break_sound(a: RunSim.Enemy) -> String:
	if a.kind != RunSim.ROCK:
		return "enemy_destroy"
	if a.golden:
		return "break_big"
	return ["break_small", "break_mid", "break_big"][clampi(a.type, 0, 2)]


## 숫자키(윗줄 1~9, 키패드 1~9) → 0부터 시작하는 번호. 숫자키가 아니면 -1.
static func number_key_index(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_1
	return -1


func _exit_tree() -> void:
	# 출격 화면을 떠나면 (처음으로, 다시 출격) 충전음·게이트 웅웅거림이 남지 않게
	Sfx.stop_warp_charge()
	Sfx.stop_gate_hum()


func _notification(what: int) -> void:
	# 휴대폰에서 다른 앱으로 가거나 탭을 바꾸면 자동으로 멈춘다.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and current_menu == Menu.NONE and not sim.is_over():
		pause()


func _on_portrait_changed(is_portrait: bool) -> void:
	if is_portrait:
		pause()


func pause() -> void:
	if current_menu != Menu.NONE or sim.is_over():
		return
	_open_menu(Menu.PAUSE, "일시 정지", "기지로 돌아가면 이번 판 광물은 사라집니다", _pause_options())


## 일시 정지 메뉴 버튼: 계속하기, 설정 3개(누를 때마다 바뀜), 포기
func _pause_options() -> PackedStringArray:
	return ["계속하기", App.settings.shake_label(), App.settings.sfx_label(), App.settings.music_label(), "포기하고 기지로"]


## 일시 정지 제목을 빠르게 FPS_TAPS번 누르면 숨은 FPS 표시를 켜고 끈다 (폰에서 직접 확인하는 용도)
func _on_title_tapped() -> void:
	if current_menu != Menu.PAUSE:
		return
	var now := Time.get_ticks_msec()
	_title_taps = _title_taps.filter(func(t: int) -> bool: return now - t < FPS_TAP_WINDOW_MS)
	_title_taps.append(now)
	if _title_taps.size() >= FPS_TAPS:
		_title_taps.clear()
		App.settings.show_fps = not App.settings.show_fps
		App.settings.save_file()
		Sfx.play("click")


## 일시 정지 메뉴의 설정 버튼: 바꾸고 저장한 뒤 메뉴를 그대로 다시 보여 준다 (누른 버튼에 포커스 유지)
func _change_setting(index: int) -> void:
	if index == PAUSE_SHAKE:
		App.settings.shake = not App.settings.shake
	elif index == PAUSE_SFX:
		App.settings.cycle_sfx()
	else:
		App.settings.cycle_music()
	App.apply_settings()
	App.settings.save_file()
	Sfx.play("click")  # 바뀐 효과음 크기를 바로 들려준다
	menu.show_menu("일시 정지", "기지로 돌아가면 이번 판 광물은 사라집니다", _pause_options())
	menu.buttons()[index].grab_focus()


## 판이 끝났을 때 (귀환 성공 또는 파괴): 가져가는 광물과 위험도 배율을 곱한 최종 가치를 보여 준다.
func _show_game_over() -> void:
	Sfx.stop_warp_charge()
	Sfx.stop_gate_hum()
	var earned := bank_result()
	var home := sim.brought_home()
	var kept := "화물칸 광물 100% 귀환" if sim.returned else "광물 %d%% 보존 (%d/%d개, 비싼 것부터)" % [
		roundi(Cargo.keep_ratio(sim.insurance_level) * 100.0), Cargo.total(home), sim.cargo.size()]
	var body := "버틴 시간 %s · 레벨 %d · 부순 적 %d개\n%s\n(%s)\n광물 가치 %d + 보너스 %d (+%d%%) = %d" % [
		Hud.format_time(sim.time), sim.level, sim.kills, kept, Hud.minerals_text(home),
		RunSim.value_of(home), earned - RunSim.value_of(home), RiskBonus.percent(sim.time), earned]
	body += "\n기지로 +%d → 보유 광물 %d" % [earned, save.credits]
	_open_menu(Menu.GAME_OVER, "귀환 성공!" if sim.returned else "우주선 파괴", body, ["다시 출격", "기지로"])


## 판이 끝나면 가져온 광물의 최종 가치를 기지 보유 광물에 더하고 저장한다 (한 판에 한 번만). 더한 값을 돌려준다.
func bank_result() -> int:
	var earned := sim.final_value()
	if not banked:
		banked = true
		save.add_credits(earned)
		save.add_hauled(sim.brought_home())
		save.save_file()
	return earned


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
	Sfx.play("card_show")
	menu.pop_in()  # 카드가 아래에서 튀어 오르며 등장 (카드 화면 자체는 5단계에서 새로 만듦)


func _open_menu(kind: Menu, title: String, body: String, options: PackedStringArray, input_delay: float = 0.0) -> void:
	current_menu = kind
	sim.run_during_levelup = false
	world.levelup_light = 0.0
	# 메뉴(일시 정지·레벨업·게임 오버)가 떠 있는 동안 붉은 화면 효과가 멈춘 채 남지 않게 끈다
	alert.clear_effects()
	Sfx.pause_gate_sounds(true)
	gate_view.process_mode = Node.PROCESS_MODE_DISABLED  # 빛 알갱이(입자)는 따로 움직이므로 메뉴 동안 멈춘다
	joystick.enabled = false
	pause_button.hide()
	world.moving = false
	hud.hide_tip = kind == Menu.PAUSE  # 안내 말풍선이 일시 정지 메뉴와 겹치지 않게
	menu.set_dim(MenuPanel.DIM_PAUSE if kind == Menu.PAUSE else MenuPanel.DIM_NORMAL)
	menu.show_menu(title, body, options, input_delay)


func _close_menu() -> void:
	current_menu = Menu.NONE
	hud.hide_tip = false
	Sfx.pause_gate_sounds(false)
	gate_view.process_mode = Node.PROCESS_MODE_INHERIT
	menu.hide()
	joystick.enabled = true
	pause_button.show()


func _on_menu_chosen(index: int) -> void:
	if current_menu == Menu.LEVEL_UP:
		Sfx.play("card_pick")
	elif not (current_menu == Menu.PAUSE and index >= PAUSE_SHAKE and index <= PAUSE_MUSIC):
		Sfx.play("click")  # 설정 버튼은 바뀐 크기로 _change_setting에서 딸깍
	match current_menu:
		Menu.PAUSE:
			if index == 0:
				_close_menu()
			elif index >= PAUSE_SHAKE and index <= PAUSE_MUSIC:
				_change_setting(index)
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
