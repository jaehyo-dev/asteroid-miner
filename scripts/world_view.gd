class_name WorldView
extends Node2D
## 출격 화면의 월드(우주선, 운석, 광물, 탄, 파편, 줍기 연출)를 그린다. 상태는 RunSim에서 읽기만 한다.

## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08
## 파편 파티클(1픽셀 점): 기본 수(+크기에 비례), 지속 시간, 속도. 황금 운석은 금빛 파편을 더 많이
const DEBRIS_COUNT := 6
const DEBRIS_TIME := 0.35
const DEBRIS_SPEED := 60.0
const GOLDEN_DEBRIS_COUNT := 24
## 파편 색: 운석(팩 바위색), 황금, 해파리(Nautolan), 날벌레(Nairan), 경비선(Kla'ed)
const DEBRIS_COLORS := {"rock": Color("#625565"), "gold": Color("#f6ce50"), "jelly": Color("#917487"), "bug": Color("#577e66"), "guard": Color("#f89419")}
## 파괴 애니메이션 속도 (초당 프레임). 운석은 금 간 프레임(0~1)을 건너뛰고 2번부터
const BOOM_FPS := 14.0
const ROCK_BOOM_START := 2
## 엔진 불꽃: 최고 속도의 이 비율보다 빠르면 출력(Powering), 아니면 대기(Idle). 불꽃·적 엔진 프레임 속도
const ENGINE_POWER_RATIO := 0.5
const ENGINE_FPS := 12.0
## 화물이 무거울 때 엔진이 힘겨워 보이는 연출: 불꽃이 느리게 깜빡이고(프레임 속도 최대 -50%),
## 1초에 SPUTTER_RATE번 잠깐 꺼지듯 대기 불꽃으로 떨어지며(가득 차면 한 번의 SPUTTER_MAX 비율 동안), 뒤로 회색 연기가 샌다.
const SPUTTER_RATE := 2.5
const SPUTTER_MAX := 0.35
const SMOKE_COLOR := Color("#917487")
## 연기가 나오는 곳: 두 엔진(몸 가운데에서 옆으로 SMOKE_SIDE, 뒤로 SMOKE_TAIL)
const SMOKE_TAIL := 11.0
const SMOKE_SIDE := 7.0
## 심연의 포격 에너지 구체: 맥동 프레임 속도, 바깥 빛 반지름(맥동 폭), 꼬리 점 수와 간격(초 단위: 그만큼 전 위치)
const ORB_FPS := 10.0
const ORB_GLOW_RADIUS := 11.0
const ORB_GLOW_PULSE := 2.0
const ORB_TRAIL_COUNT := 4
const ORB_TRAIL_STEP := 0.025
## 자동 포: 쏠 때 1번부터 끝까지 재생 (0번은 쉬는 모습)
const CANNON_FPS := 28.0
## 내 탄 프레임 속도
const BULLET_FPS := 16.0
## 등급별 줍기 연출 시간 (일반, 희귀, 영웅, 전설)
const PICKUP_FX_TIME := [0.2, 0.35, 0.45, 0.7]
## 줍기 연출에서 퍼지는 고리의 최대 반지름
const PICKUP_RING_RADIUS := [0.0, 10.0, 14.0, 24.0]
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
## 맞으면 탄이 날아온 쪽으로 튕기는 거리(픽셀)
const HIT_KNOCK_DISTANCE := 2.0
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

## 파편 효과: [위치, 속도, 남은 시간, 색]
var _debris: Array = []
## 파괴 애니메이션: {name(시트), dir, pos, t(지난 시간), start(시작 프레임)}
var _booms: Array[Dictionary] = []
## 줍기 연출: {pos, grade, gain(화물칸에서 늘어난 가치에 광물 보너스를 적용한 값), color(그때 보너스 색), t(지난 시간)}
var _pickups: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## 우주선 그림의 8방향 번호 (경계에서 깜빡이지 않게 이전 값을 기억)
var _ship_dir := -1
## 마지막으로 쏜 뒤 지난 시간 (자동 포 프레임용)
var _cannon_t := 1.0
var _time := 0.0


## 매 프레임 효과를 갱신한다 (RunSim.update 다음에 부름).
func step(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_cannon_t = 0.0 if sim.events.has("shoot") else _cannon_t + delta
	for a in sim.destroyed + sim.crashed:
		_add_boom(a)
	# 방향 전환(sim.facing)은 부드럽게 돌고, 그림만 가장 가까운 8방향으로 맞춘다
	_ship_dir = PixelArt.dir8(sim.facing + PI / 2.0, _ship_dir)
	for p in sim.picked:
		_pickups.append({"pos": p["pos"], "grade": p["grade"], "gain": RiskBonus.applied(p["gain"], sim.time), "color": Hud.bonus_color(sim.time), "t": 0.0})
	var kept: Array = []
	for d in _debris:
		d[0] += d[1] * delta
		d[1] *= 1.0 - minf(delta * 4.0, 1.0)  # 파편은 튀어 나가며 느려진다
		d[2] -= delta
		if d[2] > 0.0:
			kept.append(d)
	_debris = kept
	var kept_booms: Array[Dictionary] = []
	for b in _booms:
		b["t"] += delta
		if b["start"] + int(b["t"] * BOOM_FPS) < RunSprites.frames(b["name"]):
			kept_booms.append(b)
	_booms = kept_booms
	var kept_fx: Array[Dictionary] = []
	for fx in _pickups:
		fx["t"] += delta
		if fx["t"] < maxf(PICKUP_FX_TIME[fx["grade"]], POPUP_TIME):
			kept_fx.append(fx)
	_pickups = kept_fx


## 부서진 적: 팩 파괴 애니메이션 + 파편 파티클 (크기가 클수록 파편이 많다)
func _add_boom(a: RunSim.Enemy) -> void:
	var name := boom_sheet(a)
	var is_rock := a.kind == RunSim.ROCK
	_booms.append({"name": name, "dir": 0 if is_rock else enemy_dir(a), "pos": a.pos.round(), "t": 0.0, "start": ROCK_BOOM_START if is_rock else 1})
	var key := "gold" if a.golden else ("rock" if is_rock else a.kind)
	var count := GOLDEN_DEBRIS_COUNT if a.golden else DEBRIS_COUNT + int(a.radius / 3.0)
	for i in count:
		var vel := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.4, 1.0) * DEBRIS_SPEED
		_debris.append([a.pos, vel, DEBRIS_TIME * (1.6 if a.golden else 1.0) * _rng.randf_range(0.7, 1.3), DEBRIS_COLORS[key]])


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
		RunSprites.draw(self, b["name"], b["start"] + int(b["t"] * BOOM_FPS), b["dir"], b["pos"])
	for m in sim.minerals:
		_draw_mineral(m)
	for d in _debris:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE), d[3])
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


## 운석: 8방향 그림으로 천천히 돌고, 맞으면 흰색으로 번쩍이며 튕기고, 체력이 줄면 금 간 프레임으로 바뀐다.
func _draw_rock(a: RunSim.Enemy) -> void:
	var center := (a.pos + knock_offset(a)).round()
	var dir := PixelArt.dir8(a.age * spin_speed(a.variant, a.radius))
	RunSprites.draw(self, RunSprites.rock(a.type, a.golden), crack_level(a.hp, a.max_hp), dir, center, a.flash > 0.0)


## 적 함선 3종 (해파리 = Nautolan Fighter, 날벌레 = Nairan Scout, 경비선 = Kla'ed Support): 엔진 불꽃 + 몸.
## 경비선은 충전 중 뱃머리에 빛이 모이고, 쏜 직후에는 뒤로 살짝 밀린다(반동).
func _draw_ship_enemy(e: RunSim.Enemy) -> void:
	var dir := enemy_dir(e)
	var center := e.pos + knock_offset(e)
	var charge := 0.0
	if e.kind == RunSim.GUARD:
		var aim := Vector2.from_angle(e.aim)
		charge = Guard.charge_progress(e)
		center -= aim * 2.0 * clampf((e.reload - (Balance.GUARD_FIRE_INTERVAL - 0.2)) / 0.2, 0.0, 1.0)
	center = center.round()
	RunSprites.draw(self, e.kind + "_engine", int(e.age * ENGINE_FPS) + e.variant, dir, center)
	RunSprites.draw(self, e.kind, 0, dir, center, e.flash > 0.0)
	if e.kind == RunSim.GUARD:
		draw_circle(center, 4.0, Color(GUARD_GLOW, 0.1 + 0.08 * sin(e.age * 4.0) + 0.25 * charge))
		if charge > 0.0:
			var nose := center + Vector2.from_angle(e.aim) * GUARD_NOSE
			draw_circle(nose, 2.0 + 5.0 * charge, Color(GUARD_SHOT_GLOW, 0.25 + 0.35 * charge))
			draw_circle(nose, 1.0 + 2.0 * charge, Color(GUARD_SHOT_CORE, 0.6 + 0.4 * charge))


## 맞았을 때 탄이 날아온 쪽으로 밀리는 그림 위치 (실제 위치는 그대로)
static func knock_offset(e: RunSim.Enemy) -> Vector2:
	if e.hit_time <= 0.0:
		return Vector2.ZERO
	return e.hit_dir * HIT_KNOCK_DISTANCE * (e.hit_time / Balance.HIT_KNOCK_TIME)


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


## 대상 둘레에서 깜빡이는 흰 반짝임 점들 (위치는 시간에 따라 바뀜)
func _draw_sparkles(center: Vector2, radius: float, count: int, seed_offset: float) -> void:
	for i in count:
		var phase := sim.time * 3.0 + i * 2.1 + seed_offset
		if fposmod(phase, 1.0) > 0.55:
			continue  # 반짝였다 꺼졌다
		var angle := floorf(phase) * 2.4 + i * 1.7
		var p := center + Vector2.from_angle(angle) * radius * (0.4 + 0.5 * fposmod(angle, 1.0))
		draw_rect(Rect2(p.round(), Vector2.ONE), Color.WHITE)
		if i == 0:
			# 십자 모양 반짝임
			draw_rect(Rect2(p.round() + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 1, 0.6))
			draw_rect(Rect2(p.round() + Vector2(0, -1), Vector2(1, 3)), Color(1, 1, 1, 0.6))


## 등급별 광물: 모두 등급색의 은은한 빛, 영웅은 반짝임, 전설은 도는 빛줄기
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
	if m.grade >= 2:
		_draw_sparkles(m.pos, 7.0, 2 if m.grade == 2 else 3, m.pos.x)


## 줍기 연출: 등급이 높을수록 크고 화려하게. 희귀 이상은 "+가치" 숫자가 떠오른다.
func _draw_pickup_fx(fx: Dictionary) -> void:
	var grade: int = fx["grade"]
	var t: float = fx["t"]
	var pos: Vector2 = (fx["pos"] as Vector2).round()
	var color: Color = MINERAL_GLOW[grade]
	var k: float = t / PICKUP_FX_TIME[grade]
	if k < 1.0:
		var alpha: float = 1.0 - k
		if grade == 0:
			# 작은 부스러기 4개가 튄다
			for i in 4:
				var dir := Vector2.from_angle(i * TAU / 4.0 + 0.6)
				draw_rect(Rect2((pos + dir * 6.0 * k).round(), Vector2.ONE), Color(color, alpha))
		else:
			draw_arc(pos, 2.0 + PICKUP_RING_RADIUS[grade] * k, 0.0, TAU, 20, Color(color, alpha), 1.0)
		if grade >= 2:
			var rays := 6 if grade == 2 else 10
			for i in rays:
				var dir := Vector2.from_angle(i * TAU / rays)
				draw_rect(Rect2((pos + dir * PICKUP_RING_RADIUS[grade] * k * 0.8).round(), Vector2.ONE), Color(1, 1, 1, alpha))
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


## 내 우주선 (팩 Main Ship): 엔진 불꽃(빠르면 출력, 느리면 대기) → 엔진 → 몸(피해 단계) → 자동 포(쏠 때 총구 불꽃)
func _draw_ship() -> void:
	# 무적 중에는 깜빡인다.
	if sim.invuln > 0.0 and int(sim.invuln / BLINK_INTERVAL) % 2 == 1:
		return
	var dir := maxi(_ship_dir, 0)
	var center := sim.player_pos.round()
	# 화물이 무거우면 불꽃이 느리게 깜빡이고 가끔 꺼지듯 줄며 연기가 샌다 (Cargo.heaviness 0~1)
	var heavy := Cargo.heaviness(sim.cargo.fill_ratio())
	var frame := int(_time * ENGINE_FPS * (1.0 - 0.5 * heavy))
	# 멈춰 있거나 느리면 작은 대기 불꽃, 빠르면 큰 출력 불꽃 (무게로 느려진 속도 기준)
	var power := moving and sim.player_vel.length() > sim.current_speed() * ENGINE_POWER_RATIO
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
	var back := -Vector2.from_angle(sim.facing)
	for side: float in [-1.0, 1.0]:
		var origin := center + back * SMOKE_TAIL + back.orthogonal() * SMOKE_SIDE * side
		for i in 3:
			var t := fmod(_time * 1.6 + i / 3.0 + side * 0.17, 1.0)
			draw_circle((origin + back * t * 12.0).round(), 1.0 + t * 2.0, Color(SMOKE_COLOR, (1.0 - t) * 0.7 * heavy))


## 자동 포 프레임: 쏜 직후 1번부터 끝까지 빠르게, 그 뒤엔 0번(쉼)
static func cannon_frame(since_shot: float) -> int:
	var f := 1 + int(since_shot * CANNON_FPS)
	return f if f < RunSprites.frames("ship_cannon") else 0
