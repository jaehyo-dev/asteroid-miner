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
## 레벨업 카드 화면
var cards := LevelUpCards.new()
var current_menu := Menu.NONE
## 기지 저장 (출격 전 업그레이드 적용, 판이 끝나면 광물을 더해 저장)
var save: SaveData
## 이번 판 결과를 저장에 더했는지 (한 판에 한 번만)
var banked := false
## 귀환 연출이 끝나면 기지 화면으로 넘어갈지 (테스트에서는 끈다)
var auto_leave := true
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
## 적 소리 이름 → 몰림 줄이기 (처음 날 때 만든다)
var _enemy_sounds := {}
## 다음 히트스톱을 걸 수 있는 시뮬레이션 시각
var _hitstop_ready_at := 0.0
## 일시 정지 제목을 누른 시각 (FPS 표시)
var _title_taps: Array[int] = []
## 워프 도착 연출: 지난 시간 (-1이면 없음), 배경 터널, 화면을 덮는 흰 번쩍임
var intro_t := -1.0
var tunnel := WarpTunnel.new()
var _white := ColorRect.new()
var _arrived := false
## 확인용 숨은 스위치(?fxtest): 화면 구석에 지금 무기와 가진 보조 무기·단계 ("산탄포  [1~5 무기]" / "미사일 3  톱날 1  [Shift+1~6 보조]"). v0.8.0 배포 전에 지운다
var fx_label: Label
## ?fxtest 촬영 모드 (Shift+0): 체력 유지, 우주선 가까이에 운석 6 + 해파리 2를 늘 채움, 포격·레벨업 멈춤. 다음 채우기까지 남은 시간
var fx_stage := false
var _fx_feed := 0.0


func _ready() -> void:
	sim = RunSim.new()
	save = SaveData.load_file()
	sim.apply_base(Research.run_levels(save))
	sim.set_weapon(Weapons.equipped(save))
	sim.apply_codex(save)
	world.sim = sim
	world.ship_sheet = "ship_gold" if Discovery.gold_paint(save) else "ship"
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
	$UI.add_child(cards)
	cards.chosen.connect(_on_card_chosen)
	cards.reroll_pressed.connect(_on_reroll)
	cards.skip_pressed.connect(_on_skip_pick)
	Music.set_run_time(0.0)
	# 폰을 세로로 들면 일시 정지 (가로로 돌리면 일시 정지 메뉴에서 이어서 한다)
	App.portrait_changed.connect(_on_portrait_changed)
	if App.portrait:
		pause()
	if App.warp_intro:
		App.warp_intro = false
		_start_intro()
	if Weapons.test_mode:
		fx_label = Label.new()
		fx_label.add_theme_font_override("font", WorldView.FONT)
		fx_label.add_theme_font_size_override("font_size", 12)
		fx_label.add_theme_color_override("font_outline_color", Color("#14111c"))
		fx_label.add_theme_constant_override("outline_size", 3)
		fx_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
		fx_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		fx_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		fx_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UI.add_child(fx_label)
		_update_fx_label()


## ?fxtest 표시 글자: "산탄포   [1~5 무기]" + 가진 보조 무기와 단계
func _update_fx_label() -> void:
	if fx_label == null:
		return
	var subs: PackedStringArray = []
	for id: String in sim.subs.stages:
		subs.append("%s %d" % [SubWeapons.info(id)["name"], sim.subs.stage_of(id)])
	fx_label.text = "%s   [1~5 무기]\n%s   [Shift+1~6 보조]\n[Backspace 보조 지우기] [Alt+1~6 하나만 5단계]" % [sim.weapon["name"], "  ".join(subs) if not subs.is_empty() else "보조 없음"]
	if fx_stage:
		fx_label.text += "\n촬영 모드 [Shift+0]"


## ?fxtest 촬영 모드 한 프레임: 체력 가득, 포격 없음, 경험치 멈춤, 0.5초마다 가까이(36~120) 운석·해파리 채우기.
## 해파리가 부딪히면 화면이 붉게 번쩍여 효과를 가려서 닿기 직전에 부순다. v0.8.0 배포 전에 지운다
func _fx_stage_step(delta: float) -> void:
	sim.hp = sim.max_hp
	sim.xp = 0
	sim.set("_barrage_timer", 999.0)
	sim.barrages.clear()
	for e in sim.enemies:
		if e.kind != RunSim.ROCK and e.pos.distance_to(sim.player_pos) < e.radius + 10.0:
			e.hp = 0.0
	_fx_feed -= delta
	if _fx_feed > 0.0:
		return
	_fx_feed = 0.5
	var near := sim.enemies.filter(func(e: RunSim.Enemy) -> bool: return e.pos.distance_to(sim.player_pos) < 120.0)
	var jellies := near.filter(func(e: RunSim.Enemy) -> bool: return e.kind != RunSim.ROCK).size()
	for i in maxi(0, 8 - near.size()):
		var a := sim.spawn_creature("jelly") if jellies + i < 2 else sim.spawn_asteroid()
		var ang := randf() * TAU
		a.pos = sim.player_pos + Vector2.from_angle(ang) * randf_range(36.0, 115.0)
		a.vel = Vector2.from_angle(ang + PI * 0.5) * randf_range(4.0, 12.0)


## 워프 터널로 판을 시작한다: 시뮬레이션은 멈춰 있고, HUD와 조이스틱은 도착할 때까지 없다.
func _start_intro() -> void:
	intro_t = 0.0
	_arrived = false
	$Background.add_child(tunnel)
	tunnel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.color = Color.WHITE
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_white)
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.hide()
	pause_button.hide()
	joystick.enabled = false
	world.moving = true
	_step_intro(0.0)


func _step_intro(delta: float) -> void:
	intro_t += delta
	tunnel.t = intro_t
	tunnel.queue_redraw()
	_white.modulate.a = WarpJump.run_white(intro_t)
	world.ship_offset = Vector2(0, WarpJump.arrive_slide(intro_t))
	world.step(delta)
	if intro_t >= Juice.WARP_TUNNEL_TIME and not _arrived:
		_arrived = true
		hud.show()
		Sfx.play_warp_arrive()
		alert.kick(Juice.WARP_ARRIVE_SHAKE_TIME, Juice.WARP_ARRIVE_SHAKE)
	if _arrived:
		alert.update(delta, false, 1.0)
		hud.position.y = -roundf(Juice.WARP_HUD_SLIDE * (1.0 - WarpJump.hud_in(intro_t)))
	camera.position = sim.player_pos.round()
	camera.offset = alert.shake_offset(_shake_rng) if App.settings.shake else Vector2.ZERO
	starfield.scroll = camera.position
	world.queue_redraw()
	if intro_t >= WarpJump.RUN_TIME:
		_end_intro()


## 도착 연출을 끝낸다 (끝까지 봤거나 건너뜀). 한 번 본 것을 저장한다.
func _end_intro() -> void:
	intro_t = -1.0
	hud.show()
	hud.position = Vector2.ZERO
	pause_button.show()
	joystick.enabled = true
	world.ship_offset = Vector2.ZERO
	tunnel.queue_free()
	_white.queue_free()
	if not save.warp_seen:
		save.warp_seen = true
		save.save_file()
	if App.portrait:
		pause()


func _process(delta: float) -> void:
	if intro_t >= 0.0:
		_step_intro(delta)
		return
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
		if fx_stage:
			_fx_stage_step(delta)
		if not sim.alive:
			_show_game_over()
		elif sim.choosing() and slowmo <= 0.0:
			_show_level_up()
	elif current_menu == Menu.NONE and sim.returned:
		# 귀환 성공 연출: 우주선이 빨려 들어가고 화면이 하얗게 번쩍인 뒤 기지로 (착륙 → 결과 화면)
		gate_view.step(delta, PackedStringArray())
		hud.white = gate_view.fx.white_flash()
		if gate_view.fx.warp_finished() and not banked:
			_return_to_base()
	camera.position = sim.player_pos.round()
	# 맞았을 때 화면 흔들림 (카메라만 살짝 밀고, 배경 별은 흔들지 않음)
	camera.offset = alert.shake_offset(_shake_rng) if current_menu == Menu.NONE and App.settings.shake else Vector2.ZERO
	starfield.scroll = camera.position
	world.queue_redraw()
	hud.queue_redraw()
	danger.queue_redraw()


func _input(event: InputEvent) -> void:
	if intro_t >= 0.0:
		if save.warp_seen and WarpJump.is_skip_press(event):
			_end_intro()
			get_viewport().set_input_as_handled()  # 같은 누름이 일시 정지 등으로 이어지지 않게
		return
	# 레벨업 슬로모션 동안의 누름은 카드가 뜰 때 건너뛰기로 친다 (0.3초 먼저 눌러도 한 번에 넘어가게)
	if slowmo > 0.0 and current_menu == Menu.NONE and event.is_pressed() and (event is InputEventScreenTouch or event is InputEventMouseButton):
		cards.queue_skip()


func _unhandled_input(event: InputEvent) -> void:
	if intro_t >= 0.0:
		return
	# 레벨업 카드: 숫자키 1, 2, 3으로 고르고 R로 다시 뽑고 S로 건너뛴다(광물). 다 펼쳐지기 전이면 연출 넘기기만 한다.
	if current_menu == Menu.LEVEL_UP and event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		var index := number_key_index(key)
		var known: bool = (index >= 0 and index < sim.choices.size()) or key == KEY_R or key == KEY_S or event.is_action("confirm")
		if known:
			if cards.is_revealing():
				cards.skip()
			elif key == KEY_R:
				cards.reroll()
			elif key == KEY_S:
				cards.skip_pick()
			else:
				cards.choose(index)
			get_viewport().set_input_as_handled()
			return
	# 확인용 숨은 스위치(?fxtest): 판 중 숫자키 1~5로 기본 무기, Shift+1~6으로 보조 무기 얻기·1단계 올리기(칸 수 무시),
	# Backspace 보조 무기 모두 지우기, Alt(Ctrl·Cmd)+1~6 그 보조 무기 하나만 5단계. v0.8.0 배포 전에 지운다
	# (웹에서 Ctrl·Cmd+숫자는 크롬이 탭 바꾸기로 먼저 가져가 게임에 오지 않아 안내는 Alt로. 데스크톱에서는 Ctrl·Cmd도 같게 동작)
	if Weapons.test_mode and current_menu == Menu.NONE and event is InputEventKey and event.pressed and not event.echo:
		var slot := number_key_index(event.physical_keycode)
		if event.physical_keycode == KEY_BACKSPACE:
			sim.clear_subs()
			world.clear_sub_fx()
			_update_fx_label()
			get_viewport().set_input_as_handled()
			return
		if (event.alt_pressed or event.ctrl_pressed or event.meta_pressed) and slot >= 0 and slot < SubWeapons.ids().size():
			sim.only_sub(SubWeapons.ids()[slot])
			world.clear_sub_fx()
			_update_fx_label()
			get_viewport().set_input_as_handled()
			return
		if event.shift_pressed and event.physical_keycode == KEY_0:  # 촬영 모드 켜고 끄기 (웹 빌드 캡처용)
			fx_stage = not fx_stage
			_update_fx_label()
			get_viewport().set_input_as_handled()
			return
		if event.shift_pressed and event.physical_keycode == KEY_9:  # 레벨업 1번: 첫 화면처럼 보조 무기 카드 보장
			sim.screens_done = 0
			sim.xp = 0
			sim.gain_xp(Upgrades.xp_to_next(sim.level))
			get_viewport().set_input_as_handled()
			return
		if event.shift_pressed and slot >= 0 and slot < SubWeapons.ids().size():
			sim.apply_pick(SubWeapons.ids()[slot], 0)
			_update_fx_label()
			get_viewport().set_input_as_handled()
			return
		if slot >= 0 and slot < Weapons.ids().size():
			sim.set_weapon(Weapons.ids()[slot])
			_update_fx_label()
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
		elif e == "enemy_damage_up":
			hud.show_banner("적 피해 +%d%%" % roundi((RunSim.enemy_damage_mult(sim.time) - 1.0) * 100.0), Hud.COLOR_DANGER)
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
		if e == "shoot" or e == "hit_rock":
			Sfx.play(e)
		elif e.begins_with("hit_"):
			var db := _enemy_sound_db(e, Juice.ENEMY_HIT_SOUND_WINDOW)
			if db > -INF:
				Sfx.play(e, -1.0, 1.0, db)
		elif e == "hit":
			Sfx.play("player_hit")
		elif e == "levelup":
			Sfx.play("levelup")
		elif e == "shield_block":
			Sfx.play_shield_block()
		elif e == "explode":
			Sfx.play("break_mid", -1.0, 1.15, -10.0)
		elif e == "drone_shoot":
			Sfx.play("shoot", -1.0, 1.25, -8.0)
		elif e == "beacon":
			Sfx.play("beacon", 0.0)
	for a in sim.destroyed + sim.crashed:
		var db := _break_sounds.next_db(sim.time) if a.kind == RunSim.ROCK else _enemy_sound_db(break_sound(a), Juice.ENEMY_DESTROY_SOUND_WINDOW)
		if a.golden or (a.kind == RunSim.ROCK and a.type == 2):
			db = 0.0  # 큰·황금 운석은 멈칫하는 순간이므로 몰려도 소리를 그대로 낸다 (수에는 들어감)
		if db > -INF:
			Sfx.play(break_sound(a), -1.0, 1.0, db)
	# 광물 합치기: 한 프레임에 한 번, 만들어진 등급의 줍기 소리를 조금 높게 (등급이 오를수록 밝게)
	var merged_top := -1
	for m in sim.merged:
		merged_top = maxi(merged_top, int(m["grade"]))
	if merged_top >= 0:
		Sfx.play_pickup(merged_top, PickupCombo.pitch_of(Juice.MERGE_SOUND_SEMITONES * merged_top), -3.0)
	# 줍기: 짧은 시간 안에 주운 것은 한 번으로 묶고, 많이 주울수록 한 번을 작게 (PickupCombo)
	if sim.picked.is_empty():
		return
	var grades := []
	for p in sim.picked:
		grades.append(p["grade"])
	var s := _combo.pick(sim.time, grades)
	if not s.is_empty():
		Sfx.play_pickup(s["grade"], PickupCombo.pitch_of(s["semi"]), s["db"])


## 적 소리의 몰림 보정(dB). 내지 말아야 하면 -INF
func _enemy_sound_db(sound_name: String, window: float) -> float:
	if not _enemy_sounds.has(sound_name):
		_enemy_sounds[sound_name] = SoundThrottle.new(window, Juice.BREAK_SOUND_MAX, Juice.BREAK_SOUND_STEP_DB)
	return _enemy_sounds[sound_name].next_db(sim.time)


## 부서진 적의 소리 이름: 운석은 크기별(황금 운석은 큰 것과 같음), 생명체·경비선은 종류별
static func break_sound(a: RunSim.Enemy) -> String:
	if a.kind != RunSim.ROCK:
		return "destroy_" + a.kind
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
	if current_menu != Menu.NONE or sim.is_over() or intro_t >= 0.0:
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


## 파괴됐을 때: 출격 화면 위에 결과를 보여 준다.
func _show_game_over() -> void:
	Sfx.stop_warp_charge()
	Sfx.stop_gate_hum()
	_open_menu(Menu.GAME_OVER, "우주선 파괴", result_body(), ["다시 출격", "기지로"])


## 귀환 성공: 저장부터 하고 기지로 넘어간다. 결과는 기지가 착륙 뒤에 띄운다.
func _return_to_base() -> void:
	App.return_result = {"title": "귀환 성공!", "body": result_body()}
	App.landing = true
	if auto_leave:
		App.shutter.close_to(MAIN_SCENE)


## 결과 설명: 가져가는 광물과 위험도 배율을 곱한 최종 가치. 부르면 저장까지 끝난다.
func result_body() -> String:
	var earned := bank_result()
	var home := sim.brought_home()
	var kept := "화물칸 광물 100% 귀환" if sim.returned else "광물 %d%% 보존 (%d/%d개, 비싼 것부터)" % [
		roundi(sim.keep_ratio() * 100.0), Cargo.total(home), sim.cargo.size()]
	var body := "버틴 시간 %s · 레벨 %d · 부순 적 %d개\n%s\n(%s)\n광물 가치 %d + 보너스 %d (+%d%%) = %d" % [
		Hud.format_time(sim.time), sim.level, sim.kills, kept, Hud.minerals_text(home),
		RunSim.value_of(home), earned - RunSim.value_of(home), RiskBonus.percent(sim.time), earned]
	body += "\n기지로 +%d → 보유 광물 %d" % [earned, save.credits]
	if sim.skip_banked > 0:
		body += "\n(건너뛰기로 금고에 +%d 받음)" % sim.skip_banked
	return body


## 판이 끝나면 가져온 광물의 최종 가치를 기지 보유 광물에 더하고 저장한다 (한 판에 한 번만). 더한 값을 돌려준다.
func bank_result() -> int:
	var earned := sim.final_value()
	if not banked:
		banked = true
		save.add_credits(earned)
		save.add_hauled(sim.brought_home())
		save.save_file()
	return earned


## 레벨업 카드 화면을 연다
func _show_level_up() -> void:
	_enter_menu(Menu.LEVEL_UP)
	cards.show_cards(sim.choices, sim.upgrade_levels, sim.rerolls_left, false, sim.skip_reward())


func _open_menu(kind: Menu, title: String, body: String, options: PackedStringArray) -> void:
	_enter_menu(kind)
	menu.set_dim(MenuPanel.DIM_PAUSE if kind == Menu.PAUSE else MenuPanel.DIM_NORMAL)
	menu.show_menu(title, body, options)


## 메뉴(일시 정지·레벨업·게임 오버)가 떠 있는 동안의 공통 상태
func _enter_menu(kind: Menu) -> void:
	current_menu = kind
	sim.run_during_levelup = false
	world.levelup_light = 0.0
	# 붉은 화면 효과가 멈춘 채 남지 않게 끈다
	alert.clear_effects()
	Sfx.pause_gate_sounds(true)
	gate_view.process_mode = Node.PROCESS_MODE_DISABLED  # 빛 알갱이(입자)는 따로 움직이므로 메뉴 동안 멈춘다
	joystick.enabled = false
	pause_button.hide()
	world.moving = false
	hud.hide_tip = kind == Menu.PAUSE  # 안내 말풍선이 일시 정지 메뉴와 겹치지 않게


func _close_menu() -> void:
	current_menu = Menu.NONE
	hud.hide_tip = false
	Sfx.pause_gate_sounds(false)
	gate_view.process_mode = Node.PROCESS_MODE_INHERIT
	menu.hide()
	joystick.enabled = true
	pause_button.show()


func _on_menu_chosen(index: int) -> void:
	if not (current_menu == Menu.PAUSE and index >= PAUSE_SHAKE and index <= PAUSE_MUSIC):
		Sfx.play("click")  # 설정 버튼은 바뀐 크기로 _change_setting에서 딸깍
	match current_menu:
		Menu.PAUSE:
			if index == 0:
				_close_menu()
			elif index >= PAUSE_SHAKE and index <= PAUSE_MUSIC:
				_change_setting(index)
			else:
				App.shutter.close_to(MAIN_SCENE)
		Menu.GAME_OVER:
			if index == 0:
				App.warp_intro = true  # 다시 출격도 터널로 시작
				get_tree().reload_current_scene()
			else:
				App.shutter.close_to(MAIN_SCENE)


func _on_card_chosen(index: int) -> void:
	sim.choose(index)
	_close_menu()  # 남은 레벨업이 있으면 다음 프레임에 다시 뜬다


func _on_reroll() -> void:
	if sim.reroll():
		cards.show_cards(sim.choices, sim.upgrade_levels, sim.rerolls_left, true, sim.skip_reward())


## 건너뛰기: 광물을 금고(저장)에 바로 더하고 저장한다. 화물칸·사망과 상관없이 남는다.
func _on_skip_pick() -> void:
	var reward := sim.skip()
	save.add_credits(reward)
	save.save_file()
	hud.show_banner("광물 +%d 금고로" % reward, Hud.COLOR_VALUE)
	_close_menu()  # 남은 레벨업이 있으면 다음 프레임에 다시 뜬다
