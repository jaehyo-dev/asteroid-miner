class_name WorldView
extends Node2D
## 출격 화면의 월드(우주선, 운석, 광물, 탄, 파편, 줍기 연출)를 그린다. 상태는 RunSim에서 읽기만 한다.
## 손맛 수치(반동, 번쩍임, 파편, 반짝임, 슬로모션 빛 등)는 scripts/juice.gd에 있다.

const FLASH_SHADER := preload("res://scripts/flash_white.gdshader")
## 파편 색: 운석(팩 바위색), 황금, 해파리(Nautolan), 날벌레(Nairan), 경비선(Kla'ed)
const DEBRIS_COLORS := {"rock": Color("#625565"), "gold": Color("#f6ce50"), "jelly": Color("#917487"), "bug": Color("#577e66"), "guard": Color("#f89419")}
## 운석 파괴 애니메이션은 금 간 프레임(0~1)을 건너뛰고 2번부터
const ROCK_BOOM_START := 2
## 불꽃·적 엔진 프레임 속도
const ENGINE_FPS := 12.0
## 화물이 무거울 때 엔진이 힘겨워 보이는 연출: 불꽃이 느리게 깜빡이고(프레임 속도 최대 -50%),
## 1초에 SPUTTER_RATE번 잠깐 꺼지듯 대기 불꽃으로 떨어지며(가득 차면 한 번의 SPUTTER_MAX 비율 동안), 뒤로 회색 연기가 샌다.
const SPUTTER_RATE := 2.5
const SPUTTER_MAX := 0.35
const SMOKE_COLOR := Color("#917487")
## 연기가 나오는 곳: 두 엔진 불꽃 끝(몸 가운데에서 옆으로 SMOKE_SIDE, 뒤로 SMOKE_TAIL), 뒤로 SMOKE_TRAVEL만큼 흐른다
const SMOKE_TAIL := 8.0
const SMOKE_SIDE := 4.5
const SMOKE_TRAVEL := 8.0
## 심연의 포격 에너지 구체: 맥동 프레임 속도, 바깥 빛 반지름(맥동 폭), 꼬리 점 수와 간격(초 단위: 그만큼 전 위치)
const ORB_FPS := 10.0
const ORB_GLOW_RADIUS := 11.0
const ORB_GLOW_PULSE := 2.0
const ORB_TRAIL_COUNT := 4
const ORB_TRAIL_STEP := 0.025
## 내 탄 프레임 속도
const BULLET_FPS := 16.0
## 등급별 빛 색 (광물 그림 색에 맞춤: 회색, 시안, 보라, 금)
const MINERAL_GLOW := [Color("#a5b29d"), Color("#99e9e6"), Color("#a884f3"), Color("#f6ce50")]
## 등급별 바닥 빛 반지름과 진하기: 어떤 배경 위에서도 별 조각과 구분되게 4등급 모두 깐다 (바깥 고리는 반지름 +3, 진하기 절반)
const MINERAL_GLOW_RADIUS := [6.0, 7.0, 8.0, 10.0]
const MINERAL_GLOW_ALPHA := [0.16, 0.16, 0.18, 0.2]
## "+가치" 숫자가 떠오르는 시간과 높이
const POPUP_TIME := 0.8
const POPUP_RISE := 14.0
const FONT := preload("res://assets/fonts/galmuri/Galmuri11.ttf")
## 심연의 포격 색: 조준선(예고), 충전 중 밝은 색, 에너지탄 빛
const BARRAGE_RED := Color("#ff2a4a")
const BARRAGE_HOT := Color("#ffd0e8")
const SHOT_GLOW := Color("#ff3c8c")
## 조준선 굵기(픽셀): 예고 때 → 충전이 끝날 때, 바깥 빛 추가 굵기. 휴대폰 같은 작은 화면에서도 놓치지 않게 굵고 밝게.
const BARRAGE_LINE_WARN := 4.0
const BARRAGE_LINE_CHARGE := 8.0
const BARRAGE_LINE_GLOW := 6.0
## 쏘는 순간 조준선의 진하기 (여기서 BARRAGE_LINE_FADE_TIME 동안 사라짐)
const BARRAGE_LINE_FIRE_ALPHA := 0.9
## 조준선 길이 (쏘는 곳에서 화면 반대편 밖까지 넉넉히)
const BARRAGE_LINE_LENGTH := 2000.0
## 운석 회전 속도(라디안/초)의 기준: 작은 운석일수록 빨리 돈다
const ROCK_SPIN := 1.2
## 운석이 금 가는 체력 비율: 이 아래로 떨어질 때마다 금 간 프레임이 한 단계씩 (팩 운석 Explode 1·2번)
const CRACK_STEPS := [0.67, 0.34]
## 고대 경비선: 충전 빛·경비선 탄 빛 색, 뱃머리(탄이 나가는 곳)까지 거리
const GUARD_GLOW := Color("#ffb347")
const GUARD_SHOT_CORE := Color("#fff4d6")
const GUARD_SHOT_GLOW := Color("#cb3738")
const GUARD_NOSE := 12.0
## 새로운 위협 배너 색 (해파리, 날벌레)
const JELLY_COLOR := Color("#c8a5d8")
const BUG_COLOR := Color("#a5cc5f")

var sim: RunSim
## 워프 게이트 연출 (귀환할 때 우주선이 빨려 들어가는 모습에 씀)
var gate_fx: GateFx
## 이번 프레임에 움직이는 중인지 (엔진 불꽃 표시용)
var moving := false
## 레벨업 빛 세기 (1 → 0, scripts/run.gd가 슬로모션 동안 정함)
var levelup_light := 0.0

## 파편 효과: [위치, 속도, 남은 시간, 색, 크기(픽셀)]
var _debris: Array = []
## 다 쓴 파편을 버리지 않고 모아 두었다가 다시 쓴다 (매 폭발마다 배열을 새로 만들지 않게)
var _debris_pool: Array = []
## 파괴 애니메이션: {name(시트), dir, pos, t(지난 시간), start(시작 프레임), fps}
var _booms: Array[Dictionary] = []
## 줍기 연출: {pos, grade, gain(화물칸에서 늘어난 가치에 광물 보너스를 적용한 값), color(그때 보너스 색), t(지난 시간)}
var _pickups: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## 우주선 그림의 8방향 번호 (경계에서 깜빡이지 않게 이전 값을 기억)
var _ship_dir := -1
## 보이는 우주선 방향: 실제 방향(sim.facing)을 lerp_angle로 부드럽게 따라간다
var _ship_angle := 0.0
## 맞은 적을 흰색으로 덮어 그리는 층 (흰색 섞는 셰이더, 월드 위에 겹침)
var _flash_layer: Node2D
## 마지막으로 쏜 뒤 지난 시간 (자동 포 프레임용)
var _cannon_t := 1.0
var _time := 0.0


func _ready() -> void:
	_flash_layer = Node2D.new()
	_flash_layer.name = "Flash"
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	_flash_layer.material = mat
	_flash_layer.draw.connect(_draw_flash)
	add_child(_flash_layer)


## 매 프레임 효과를 갱신한다 (RunSim.update 다음에 부름).
func step(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_cannon_t = 0.0 if sim.events.has("shoot") else _cannon_t + delta
	for a in sim.destroyed + sim.crashed:
		_add_boom(a)
	# 방향 전환은 lerp_angle로 부드럽게 따라가고, 그림만 가장 가까운 8방향으로 맞춘다
	if _ship_dir < 0:
		_ship_angle = sim.facing
	_ship_angle = lerp_angle(_ship_angle, sim.facing, 1.0 - exp(-Juice.SHIP_TURN_LERP * delta))
	_ship_dir = PixelArt.dir8(_ship_angle + PI / 2.0, _ship_dir)
	for p in sim.picked:
		_pickups.append({"pos": p["pos"], "grade": p["grade"], "gain": RiskBonus.applied(p["gain"], sim.time), "color": Hud.bonus_color(sim.time), "t": 0.0})
	var kept: Array = []
	for d in _debris:
		d[0] += d[1] * delta
		d[1] *= 1.0 - minf(delta * 4.0, 1.0)  # 파편은 튀어 나가며 느려진다
		d[2] -= delta
		if d[2] > 0.0:
			kept.append(d)
		else:
			_debris_pool.append(d)
	_debris = kept
	var kept_booms: Array[Dictionary] = []
	for b in _booms:
		b["t"] += delta
		if b["start"] + int(b["t"] * b["fps"]) < RunSprites.frames(b["name"]):
			kept_booms.append(b)
	_booms = kept_booms
	var kept_fx: Array[Dictionary] = []
	for fx in _pickups:
		fx["t"] += delta
		if fx["t"] < maxf(Juice.PICKUP_FX_TIME[fx["grade"]], POPUP_TIME):
			kept_fx.append(fx)
	_pickups = kept_fx


## 부서진 적: 팩 파괴 애니메이션 + 파편 파티클. 클수록 파편이 많고 굵고 빠르며, 깨지는 애니메이션은 느리다(묵직함)
func _add_boom(a: RunSim.Enemy) -> void:
	var is_rock := a.kind == RunSim.ROCK
	_booms.append({"name": boom_sheet(a), "dir": 0 if is_rock else enemy_dir(a), "pos": a.pos.round(), "t": 0.0,
		"start": ROCK_BOOM_START if is_rock else 1, "fps": boom_fps(a)})
	var key := "gold" if a.golden else ("rock" if is_rock else a.kind)
	var count := Juice.GOLDEN_DEBRIS_COUNT if a.golden else Juice.DEBRIS_COUNT + int(a.radius / Juice.RADIUS_PER_DEBRIS)
	var size := 2.0 if a.radius >= Juice.DEBRIS_BIG_RADIUS else 1.0
	var speed := Juice.DEBRIS_SPEED * (1.0 + a.radius / 40.0)
	for i in count:
		var vel := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.4, 1.0) * speed
		_spawn_debris(a.pos, vel, Juice.DEBRIS_TIME * (1.6 if a.golden else 1.0) * _rng.randf_range(0.7, 1.3), DEBRIS_COLORS[key], size)


## 파편 하나를 만든다. 총량 상한(Juice.PARTICLE_MAX)이 차면 만들지 않고, 풀에 남은 것이 있으면 다시 쓴다.
func _spawn_debris(pos: Vector2, vel: Vector2, life: float, color: Color, size: float) -> void:
	if _debris.size() >= Juice.PARTICLE_MAX:
		return
	var d: Array = _debris_pool.pop_back() if not _debris_pool.is_empty() else [Vector2.ZERO, Vector2.ZERO, 0.0, Color.WHITE, 1.0]
	d[0] = pos
	d[1] = vel
	d[2] = life
	d[3] = color
	d[4] = size
	_debris.append(d)


## 파괴 애니메이션 속도: 적 함선은 같고, 운석은 클수록 느리게
static func boom_fps(a: RunSim.Enemy) -> float:
	if a.kind != RunSim.ROCK:
		return Juice.ENEMY_BOOM_FPS
	return Juice.GOLD_BOOM_FPS if a.golden else float(Juice.ROCK_BOOM_FPS[clampi(a.type, 0, 2)])


## 적의 파괴 시트 이름
static func boom_sheet(a: RunSim.Enemy) -> String:
	if a.kind == RunSim.ROCK:
		return RunSprites.rock(a.type, a.golden) + "_boom"
	return a.kind + "_boom"


## 적 그림의 8방향 번호: 경비선은 포가 노리는 쪽, 생명체는 날아가는 쪽 (그림은 위쪽을 봄)
static func enemy_dir(e: RunSim.Enemy) -> int:
	if e.kind == RunSim.GUARD:
		return PixelArt.dir8(e.aim + PI / 2.0)
	return PixelArt.dir8(e.vel.angle() + PI / 2.0) if e.vel.length() > 0.1 else 4


func _draw() -> void:
	if sim == null:
		return
	for a in sim.enemies:
		if a.kind == RunSim.ROCK:
			if a.golden:
				_draw_golden_glow(a)
			_draw_rock(a)
			if a.golden:
				_draw_sparkles(a.pos, a.radius, 3, 0.0)
		else:
			_draw_ship_enemy(a)
	for b in _booms:
		RunSprites.draw(self, b["name"], b["start"] + int(b["t"] * b["fps"]), b["dir"], b["pos"])
	for m in sim.minerals:
		_draw_mineral(m)
	for d in _debris:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE * d[4]), d[3])
	_draw_barrages()
	var bullet_frame := int(_time * BULLET_FPS)
	for b in sim.bullets:
		RunSprites.draw(self, "bullet", bullet_frame, PixelArt.dir8(b.vel.angle() + PI / 2.0), b.pos)
	for fx in _pickups:
		_draw_pickup_fx(fx)
	if sim.returned:
		_draw_ship_warp()
	elif sim.alive:
		_draw_ship()
	_flash_layer.queue_redraw()


## 맞은 적·운석을 흰색으로 덮는다 (셰이더가 색을 흰색으로, 알파 = 섞는 정도: 맞은 순간 가장 하얗고 사라짐)
func _draw_flash() -> void:
	if sim == null:
		return
	for e in sim.enemies:
		if e.flash <= 0.0:
			continue
		var mix := Color(1, 1, 1, clampf(e.flash / Juice.ENEMY_FLASH_TIME, 0.0, 1.0))
		if e.kind == RunSim.ROCK:
			RunSprites.draw(_flash_layer, RunSprites.rock(e.type, e.golden), crack_level(e.hp, e.max_hp), rock_dir(e), (e.pos + knock_offset(e)).round(), mix)
		else:
			RunSprites.draw(_flash_layer, e.kind, 0, enemy_dir(e), ship_enemy_center(e), mix)


## 심연의 포격: 예고 때는 맥박치는 붉은 조준선, 충전 때는 점점 굵고 밝아지는 선, 발사 후엔 에너지탄.
func _draw_barrages() -> void:
	for b in sim.barrages:
		var fade := b.line_visibility()
		if fade <= 0.0:
			continue  # 쏜 뒤 조준선은 잠깐만 보이고 사라진다 (가장자리 "!"는 HUD가 탄이 지나갈 때까지 남김)
		var start := b.origin
		# 예고가 시작되면 쏘는 곳에서부터 쭉 그어진다
		var end := b.origin + b.dir * BARRAGE_LINE_LENGTH * b.draw_progress()
		var width := lerpf(BARRAGE_LINE_WARN, BARRAGE_LINE_CHARGE, b.charge_progress())
		var pulse := 0.5 + 0.5 * sin(sim.time * TAU * 4.0)
		var alpha := 0.55 + 0.35 * pulse if b.phase == Barrage.Phase.WARN else 0.9
		if b.phase == Barrage.Phase.FIRE or b.phase == Barrage.Phase.DONE:
			alpha = BARRAGE_LINE_FIRE_ALPHA * fade  # 쏘는 순간 밝게 길을 비추고 금방 사라진다
		# 바깥 빛 → 붉은 선 → 밝은 가운데 줄 (어두운 배경에서도, 작은 화면에서도 잘 보이게)
		draw_line(start, end, Color(BARRAGE_RED, alpha * 0.3), width + BARRAGE_LINE_GLOW)
		draw_line(start, end, Color(BARRAGE_RED, alpha), width)
		draw_line(start, end, Color(BARRAGE_HOT, alpha * (0.4 + 0.6 * b.charge_progress())), maxf(1.0, width * 0.35))
	var frame := int(_time * ENGINE_FPS)
	for s in sim.shots:
		if s.guard:
			# 경비선 탄: 빨간 Kla'ed 탄. 둘레 빛은 내 탄(주황)과 구분되는 색
			draw_circle(s.pos.round(), s.radius + 3.0, Color(GUARD_SHOT_GLOW, 0.3))
			RunSprites.draw(self, "guard_shot", frame, PixelArt.dir8(s.vel.angle() + PI / 2.0), s.pos)
		else:
			_draw_orb(s)


## 심연의 포격 에너지 구체: 짧은 꼬리(지나온 자리에 작아지는 빛 점) → 맥동하는 바깥 빛 → 맥동 프레임 그림
func _draw_orb(s: RunSim.Shot) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * TAU * ORB_FPS / 4.0)
	for i in range(ORB_TRAIL_COUNT, 0, -1):
		var k := float(i) / ORB_TRAIL_COUNT
		draw_circle((s.pos - s.vel * ORB_TRAIL_STEP * i).round(), 6.0 * (1.0 - k * 0.6), Color(SHOT_GLOW, 0.45 * (1.0 - k)))
	draw_circle(s.pos.round(), ORB_GLOW_RADIUS + ORB_GLOW_PULSE * pulse, Color(SHOT_GLOW, 0.18 + 0.1 * pulse))
	draw_circle(s.pos.round(), ORB_GLOW_RADIUS * 0.7, Color(SHOT_GLOW, 0.22))
	RunSprites.draw(self, "barrage_shot", int(_time * ORB_FPS), 0, s.pos)


## 운석: 8방향 그림으로 천천히 돌고, 맞으면 튕기고(흰 번쩍임은 _draw_flash), 체력이 줄면 금 간 프레임으로 바뀐다.
func _draw_rock(a: RunSim.Enemy) -> void:
	RunSprites.draw(self, RunSprites.rock(a.type, a.golden), crack_level(a.hp, a.max_hp), rock_dir(a), (a.pos + knock_offset(a)).round())


static func rock_dir(a: RunSim.Enemy) -> int:
	return PixelArt.dir8(a.age * spin_speed(a.variant, a.radius))


## 적 함선 3종 (해파리 = Nautolan Fighter, 날벌레 = Nairan Scout, 경비선 = Kla'ed Support): 엔진 불꽃 + 몸.
## 경비선은 충전 중 뱃머리에 빛이 모이고, 쏜 직후에는 뒤로 살짝 밀린다(반동).
func _draw_ship_enemy(e: RunSim.Enemy) -> void:
	var dir := enemy_dir(e)
	var center := ship_enemy_center(e)
	var charge := Guard.charge_progress(e) if e.kind == RunSim.GUARD else 0.0
	RunSprites.draw(self, e.kind + "_engine", int(e.age * ENGINE_FPS) + e.variant, dir, center)
	RunSprites.draw(self, e.kind, 0, dir, center)
	if e.kind == RunSim.GUARD:
		draw_circle(center, 4.0, Color(GUARD_GLOW, 0.1 + 0.08 * sin(e.age * 4.0) + 0.25 * charge))
		if charge > 0.0:
			var nose := center + Vector2.from_angle(e.aim) * GUARD_NOSE
			draw_circle(nose, 2.0 + 5.0 * charge, Color(GUARD_SHOT_GLOW, 0.25 + 0.35 * charge))
			draw_circle(nose, 1.0 + 2.0 * charge, Color(GUARD_SHOT_CORE, 0.6 + 0.4 * charge))


## 적 함선 그림 가운데 (정수 픽셀): 맞으면 밀리고, 경비선은 쏜 직후 뒤로 살짝 밀린다(반동)
static func ship_enemy_center(e: RunSim.Enemy) -> Vector2:
	var center := e.pos + knock_offset(e)
	if e.kind == RunSim.GUARD:
		center -= Vector2.from_angle(e.aim) * 2.0 * clampf((e.reload - (Balance.GUARD_FIRE_INTERVAL - 0.2)) / 0.2, 0.0, 1.0)
	return center.round()


## 맞았을 때 탄이 날아온 쪽으로 밀리는 그림 위치 (실제 위치는 그대로)
static func knock_offset(e: RunSim.Enemy) -> Vector2:
	if e.hit_time <= 0.0:
		return Vector2.ZERO
	return e.hit_dir * Juice.HIT_KNOCK_DISTANCE * (e.hit_time / Balance.HIT_KNOCK_TIME)


## 운석 회전 속도(라디안/초): 변형 번호마다 방향과 빠르기가 다르고, 작을수록 빨리 돈다
static func spin_speed(variant: int, radius: float) -> float:
	return ROCK_SPIN * (float(variant) - 1.5) / 1.5 * 5.0 / maxf(radius, 1.0)


## 금 간 정도: 0 (멀쩡) ~ CRACK_STEPS.size(). 한 방에 부서지는 적(최대 체력 1 이하)은 금이 가지 않는다.
static func crack_level(hp: float, max_hp: float) -> int:
	if max_hp <= 1.0:
		return 0
	var ratio := hp / max_hp
	var level := 0
	for step in CRACK_STEPS:
		if ratio <= step:
			level += 1
	return level


## 황금 운석 둘레에서 숨 쉬듯 커졌다 작아지는 금빛 후광 (멀리서도 눈에 띄게)
func _draw_golden_glow(a: RunSim.Enemy) -> void:
	var pulse := 0.5 + 0.5 * sin(sim.time * 4.0)
	draw_circle(a.pos.round(), a.radius + 6.0 + pulse * 3.0, Color(1.0, 0.85, 0.3, 0.1 + 0.08 * pulse))
	draw_arc(a.pos.round(), a.radius + 5.0 + pulse * 4.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.35 * (1.0 - pulse) + 0.15), 1.0)


## 대상 둘레에서 깜빡이는 흰 반짝임 점들 (위치는 시간에 따라 바뀜).
## rate: 초당 반짝임 횟수, on: 한 번에 켜져 있는 비율, cross: 첫 점의 십자 팔 길이(0이면 점만)
func _draw_sparkles(center: Vector2, radius: float, count: int, seed_offset: float, rate := 3.0, on := 0.55, cross := 1) -> void:
	for i in count:
		var phase := sim.time * rate + i * 2.1 + seed_offset
		if fposmod(phase, 1.0) > on:
			continue  # 반짝였다 꺼졌다
		var angle := floorf(phase) * 2.4 + i * 1.7
		var p := (center + Vector2.from_angle(angle) * radius * (0.4 + 0.5 * fposmod(angle, 1.0))).round()
		draw_rect(Rect2(p, Vector2.ONE), Color.WHITE)
		if i == 0 and cross > 0:
			# 십자 모양 반짝임
			draw_rect(Rect2(p + Vector2(-cross, 0), Vector2(cross * 2 + 1, 1)), Color(1, 1, 1, 0.6))
			draw_rect(Rect2(p + Vector2(0, -cross), Vector2(1, cross * 2 + 1)), Color(1, 1, 1, 0.6))


## 등급별 광물: 모두 등급색의 은은한 빛과 반짝임(등급이 높을수록 자주·크게), 전설은 도는 빛줄기
func _draw_mineral(m: RunSim.Mineral) -> void:
	var tex := RunSprites.mineral(m.grade)
	var center := m.pos.round()
	var color: Color = MINERAL_GLOW[m.grade]
	var bob := sin(sim.time * 3.0 + m.pos.x * 0.1)  # 둥실거림 (-1~1)
	var r: float = MINERAL_GLOW_RADIUS[m.grade] + bob
	var a: float = MINERAL_GLOW_ALPHA[m.grade]
	draw_circle(center, r + 3.0, Color(color, a * 0.5))
	draw_circle(center, r, Color(color, a))
	if m.grade == 3:
		# 빛줄기 4개가 천천히 돈다
		var spin := sim.time * 1.2
		for i in 4:
			var dir := Vector2.from_angle(spin + i * TAU / 4.0)
			draw_line(center + dir * 7.0, center + dir * (14.0 + 2.0 * bob), Color(1.0, 0.9, 0.4, 0.45), 1.0)
	draw_texture(tex, center - (tex.get_size() / 2.0).floor() + Vector2(0, roundf(bob * 0.6)))
	# 반짝임: 일반은 가끔 점 하나, 높은 등급일수록 자주·여러 개·큰 십자 (켜진 시간은 짧게 0.25)
	_draw_sparkles(m.pos, 7.0, 1 + mini(m.grade, 2), m.pos.x, Juice.SPARKLE_RATE[m.grade], 0.25, Juice.SPARKLE_SIZE[m.grade])


## 줍기 연출: 등급이 높을수록 크고 화려하게. 희귀 이상은 "+가치" 숫자가 떠오른다.
func _draw_pickup_fx(fx: Dictionary) -> void:
	var grade: int = fx["grade"]
	var t: float = fx["t"]
	var pos: Vector2 = (fx["pos"] as Vector2).round()
	var color: Color = MINERAL_GLOW[grade]
	var k: float = t / Juice.PICKUP_FX_TIME[grade]
	var ring: float = Juice.PICKUP_RING_RADIUS[grade]
	if k < 1.0:
		var alpha: float = 1.0 - k
		# 주운 순간 십자 반짝임 (등급이 높을수록 길게): 처음에 길고 빨리 줄어든다
		var arm := roundi((2.0 + grade * 2.0) * (1.0 - k))
		if arm > 0:
			draw_rect(Rect2(pos + Vector2(-arm, 0), Vector2(arm * 2 + 1, 1)), Color(1, 1, 1, alpha))
			draw_rect(Rect2(pos + Vector2(0, -arm), Vector2(1, arm * 2 + 1)), Color(1, 1, 1, alpha))
		if grade == 0:
			# 작은 부스러기 4개가 튄다
			for i in 4:
				var dir := Vector2.from_angle(i * TAU / 4.0 + 0.6)
				draw_rect(Rect2((pos + dir * ring * k).round(), Vector2.ONE), Color(color, alpha))
		else:
			draw_arc(pos, 2.0 + ring * k, 0.0, TAU, 20, Color(color, alpha), 1.0)
		if grade >= 2:
			var rays := 6 if grade == 2 else 10
			for i in rays:
				var dir := Vector2.from_angle(i * TAU / rays)
				draw_rect(Rect2((pos + dir * ring * k * 0.8).round(), Vector2.ONE), Color(1, 1, 1, alpha))
		if grade == 3:
			draw_circle(pos, 10.0 * (1.0 - k), Color(1.0, 0.95, 0.6, 0.5 * alpha))
	# 화물칸에서 늘어난 가치만 띄운다 (꽉 차서 바꿔 실으면 가치 차이, 못 실으면 띄우지 않음)
	var value: int = fx["gain"]
	if grade >= 1 and value > 0 and t < POPUP_TIME:
		var rise := POPUP_RISE * t / POPUP_TIME
		var text_color := Color(fx["color"], 1.0 - t / POPUP_TIME)
		draw_string(FONT, (pos + Vector2(-12, -6 - rise)).round(), "+%d" % value, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, text_color)


## 우주선 피해 그림 단계: 체력이 줄수록 0 멀쩡 → 1 살짝 → 2 망가짐 → 3 아주 망가짐 (팩 Main Ship 4단계)
static func damage_stage(hp: float, max_hp: float) -> int:
	var ratio := hp / maxf(max_hp, 1.0)
	if ratio > 0.75:
		return 0
	if ratio > 0.5:
		return 1
	if ratio > 0.25:
		return 2
	return 3


## 귀환 성공: 우주선이 게이트 쪽으로 길게 늘어나며 가운데로 빨려 들어간다 (6단계 워프 점프에서 다시 만듦)
func _draw_ship_warp() -> void:
	var k := gate_fx.suck() if gate_fx != null else 1.0
	if k >= 1.0:
		return
	var target := sim.gate.pos
	var pos := sim.player_pos.lerp(target, k * k)
	var angle := (target - sim.player_pos).angle() if sim.player_pos.distance_to(target) > 0.5 else sim.facing
	draw_set_transform(pos.round(), angle + PI / 2.0, Vector2(1.0 - 0.75 * k, 1.0 + 3.5 * k))
	var c: int = RunSprites.CELL["ship"]
	draw_texture_rect_region(RunSprites.tex("ship"), Rect2(-Vector2(c, c) / 2.0, Vector2(c, c)), RunSprites.region("ship", damage_stage(sim.hp, sim.max_hp)), Color(1, 1, 1, 1.0 - smoothstep(0.7, 1.0, k)))
	draw_set_transform(Vector2.ZERO)


## 내 우주선 (팩 Main Ship): 엔진 불꽃(빠르면 출력, 느리면 대기) → 엔진 → 자동 포(쏠 때 총구 불꽃) → 몸(피해 단계).
## 쏘면 뒤로 1~2픽셀 밀렸다 돌아온다(반동).
func _draw_ship() -> void:
	_draw_levelup_light()
	# 무적 중에는 깜빡인다.
	if sim.invuln > 0.0 and int(sim.invuln / Juice.BLINK_INTERVAL) % 2 == 1:
		return
	var dir := maxi(_ship_dir, 0)
	var center := (sim.player_pos + recoil_offset(_cannon_t, _ship_angle)).round()
	# 화물이 무거우면 불꽃이 느리게 깜빡이고 가끔 꺼지듯 줄며 연기가 샌다 (Cargo.heaviness 0~1)
	var heavy := Cargo.heaviness(sim.cargo.fill_ratio())
	var frame := int(_time * ENGINE_FPS * (1.0 - 0.5 * heavy))
	# 멈춰 있거나 느리면 작은 대기 불꽃, 빠르면 큰 출력 불꽃 (무게로 느려진 속도 기준)
	var power := moving and sim.player_vel.length() > sim.current_speed() * Juice.ENGINE_POWER_RATIO
	if power and fmod(_time * SPUTTER_RATE, 1.0) < SPUTTER_MAX * heavy:
		power = false
	if moving and heavy > 0.0:
		_draw_smoke(center, heavy)
	RunSprites.draw(self, "ship_flame_power" if power else "ship_flame_idle", frame, dir, center)
	RunSprites.draw(self, "ship_engine", 0, dir, center)
	RunSprites.draw(self, "ship_cannon", cannon_frame(_cannon_t), dir, center)
	RunSprites.draw(self, "ship", damage_stage(sim.hp, sim.max_hp), dir, center)


## 무거운 엔진 연기: 두 엔진 뒤로 회색 점이 커지며 흐려진다 (위치는 시간으로만 정해 따로 상태가 없음)
func _draw_smoke(center: Vector2, heavy: float) -> void:
	var back := -Vector2.from_angle(_ship_angle)
	for side: float in [-1.0, 1.0]:
		var origin := center + back * SMOKE_TAIL + back.orthogonal() * SMOKE_SIDE * side
		for i in 3:
			var t := fmod(_time * 1.6 + i / 3.0 + side * 0.17, 1.0)
			draw_circle((origin + back * t * SMOKE_TRAVEL).round(), 1.0 + t * 2.0, Color(SMOKE_COLOR, (1.0 - t) * 0.7 * heavy))


## 레벨업 빛: 우주선에서 밝은 빛이 퍼지며 사라진다 (슬로모션 동안)
func _draw_levelup_light() -> void:
	if levelup_light <= 0.0:
		return
	var k := 1.0 - levelup_light  # 0 → 1로 퍼짐
	var center := sim.player_pos.round()
	draw_circle(center, Juice.LEVELUP_LIGHT_RADIUS * (0.3 + 0.7 * k), Color(Juice.LEVELUP_LIGHT_COLOR, 0.25 * levelup_light))
	draw_circle(center, Juice.LEVELUP_LIGHT_RADIUS * 0.35 * (1.0 - 0.5 * k), Color(Juice.LEVELUP_LIGHT_COLOR, 0.4 * levelup_light))
	draw_arc(center, Juice.LEVELUP_LIGHT_RADIUS * k, 0.0, TAU, 40, Color(Color.WHITE, 0.8 * levelup_light), 1.0)


## 쏜 뒤 반동 위치: 바라보는 반대쪽으로 RECOIL_PX 밀렸다가 RECOIL_TIME 동안 돌아온다
static func recoil_offset(since_shot: float, facing: float) -> Vector2:
	if since_shot >= Juice.RECOIL_TIME:
		return Vector2.ZERO
	return -Vector2.from_angle(facing) * Juice.RECOIL_PX * (1.0 - since_shot / Juice.RECOIL_TIME)


## 자동 포 프레임: 쏜 직후 1번부터 끝까지 빠르게, 그 뒤엔 0번(쉼)
static func cannon_frame(since_shot: float) -> int:
	var f := 1 + int(since_shot * Juice.CANNON_FPS)
	return f if f < RunSprites.frames("ship_cannon") else 0
