class_name WorldView
extends Node2D
## 출격 화면의 월드(우주선, 운석, 광물, 탄, 파편, 줍기 연출)를 그린다. 상태는 RunSim에서 읽기만 한다.

## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08
## 운석이 부서질 때 파편 수와 지속 시간, 속도
const DEBRIS_COUNT := 6
const DEBRIS_TIME := 0.35
const DEBRIS_SPEED := 50.0
## 황금 운석이 부서질 때 금빛 파편을 더 많이
const GOLDEN_DEBRIS_COUNT := 24
## 등급별 줍기 연출 시간 (일반, 희귀, 영웅, 전설)
const PICKUP_FX_TIME := [0.2, 0.35, 0.45, 0.7]
## 줍기 연출에서 퍼지는 고리의 최대 반지름
const PICKUP_RING_RADIUS := [0.0, 10.0, 14.0, 24.0]
## "+가치" 숫자가 떠오르는 시간과 높이
const POPUP_TIME := 0.8
const POPUP_RISE := 14.0
const FONT := preload("res://assets/fonts/galmuri/Galmuri11.ttf")
## 심연의 포격 색: 조준선(예고), 충전 중 밝은 색, 에너지탄 핵·빛
const BARRAGE_RED := Color("#ff2a4a")
const BARRAGE_HOT := Color("#ffd0e8")
const SHOT_CORE := Color("#fff0fa")
const SHOT_GLOW := Color("#ff3c8c")
## 조준선 굵기(픽셀): 예고 때 → 충전이 끝날 때, 바깥 빛 추가 굵기. 휴대폰 세로 화면에서도 놓치지 않게 굵고 밝게.
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
## 운석이 금 가는 체력 비율: 이 아래로 떨어질 때마다 금이 하나씩 더 생긴다
const CRACK_STEPS := [0.67, 0.34]
## 고대 경비선: 충전 빛·경비선 에너지탄 색, 뱃머리(탄이 나가는 곳)까지 거리
const GUARD_GLOW := Color("#ffb347")
const GUARD_SHOT_CORE := Color("#fff4d6")
const GUARD_SHOT_GLOW := Color("#ff9a2e")
const GUARD_NOSE := 6.0
## 우주선 기울기: 돌 때 옆으로 눌려 보이는 최대 비율, 기울기가 따라가는 빠르기
const SHIP_BANK_SQUASH := 0.35
const SHIP_BANK_RATE := 10.0

var sim: RunSim
## 워프 게이트 연출 (귀환할 때 우주선이 빨려 들어가는 모습에 씀)
var gate_fx: GateFx
## 이번 프레임에 움직이는 중인지 (엔진 불꽃 표시용)
var moving := false

## 파편 효과: [위치, 속도, 남은 시간, 색]
var _debris: Array = []
## 줍기 연출: {pos, grade, gain(화물칸에서 늘어난 가치), t(지난 시간)}
var _pickups: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## 우주선 기울기 (-1 왼쪽으로 돌 때 ~ 1 오른쪽으로 돌 때)
var bank := 0.0
var _last_facing := NAN
## 금 선 모양 캐시 ("반지름_변형_단계" → 선 목록)
static var _crack_cache := {}


## 매 프레임 효과를 갱신한다 (RunSim.update 다음에 부름).
func step(delta: float) -> void:
	if sim == null:
		return
	for a in sim.destroyed:
		var count := GOLDEN_DEBRIS_COUNT if a.golden else DEBRIS_COUNT + int(a.radius / 3.0)
		var color: Color = PixelArt.GOLD_ROCK_COLORS[1] if a.golden else PixelArt.DEBRIS_COLOR
		for i in count:
			var vel := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.4, 1.0) * DEBRIS_SPEED
			_debris.append([a.pos, vel, DEBRIS_TIME * (1.6 if a.golden else 1.0), color])
	# 우주선 기울기: 이번 프레임에 돈 만큼(최대 회전 속도 대비)을 부드럽게 따라간다
	var turn := 0.0
	if not is_nan(_last_facing) and delta > 0.0:
		turn = clampf(wrapf(sim.facing - _last_facing, -PI, PI) / delta / Balance.SHIP_TURN_SPEED, -1.0, 1.0)
	_last_facing = sim.facing
	bank = move_toward(bank, turn, SHIP_BANK_RATE * delta)
	for p in sim.picked:
		_pickups.append({"pos": p["pos"], "grade": p["grade"], "gain": p["gain"], "t": 0.0})
	var kept: Array = []
	for d in _debris:
		d[0] += d[1] * delta
		d[2] -= delta
		if d[2] > 0.0:
			kept.append(d)
	_debris = kept
	var kept_fx: Array[Dictionary] = []
	for fx in _pickups:
		fx["t"] += delta
		if fx["t"] < maxf(PICKUP_FX_TIME[fx["grade"]], POPUP_TIME):
			kept_fx.append(fx)
	_pickups = kept_fx


func _draw() -> void:
	if sim == null:
		return
	for a in sim.enemies:
		if a.kind == "jelly":
			_draw_jelly(a)
			continue
		if a.kind == "bug":
			_draw_bug(a)
			continue
		if a.kind == RunSim.GUARD:
			_draw_guard(a)
			continue
		if a.golden:
			_draw_golden_glow(a)
		_draw_rock(a)
		if a.golden:
			_draw_sparkles(a.pos, a.radius, 3, 0.0)
	for m in sim.minerals:
		_draw_mineral(m)
	for d in _debris:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE), d[3])
	_draw_barrages()
	for b in sim.bullets:
		var p := b.pos.round()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), PixelArt.BULLET_COLORS[1])
		draw_rect(Rect2(p, Vector2.ONE), PixelArt.BULLET_COLORS[0])
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
	for s in sim.shots:
		var dir := s.vel.normalized()
		# 고대 경비선 탄은 주황, 심연의 포격은 분홍 (크기도 경비선 탄이 작음)
		var glow := GUARD_SHOT_GLOW if s.guard else SHOT_GLOW
		var core := GUARD_SHOT_CORE if s.guard else SHOT_CORE
		var k := s.radius / Balance.BARRAGE_SHOT_RADIUS
		# 꼬리 잔상
		for i in range(3, 0, -1):
			draw_circle((s.pos - dir * i * 4.0 * k).round(), (5.0 - i) * k, Color(glow, 0.25))
		draw_circle(s.pos.round(), 7.0 * k, Color(glow, 0.35))
		draw_circle(s.pos.round(), 4.0 * k, glow)
		draw_circle(s.pos.round(), 2.0 * k, core)


## 운석: 천천히 돌고, 맞으면 탄이 날아온 쪽으로 살짝 튕기며, 체력이 줄면 금이 간다.
func _draw_rock(a: RunSim.Enemy) -> void:
	var tex := PixelArt.asteroid_flash(a.radius, a.variant, a.golden) if a.flash > 0.0 else PixelArt.asteroid(a.radius, a.variant, a.golden)
	var center := (a.pos + knock_offset(a)).round()
	draw_set_transform(center, a.age * spin_speed(a.variant, a.radius))
	draw_texture(tex, -(tex.get_size() / 2.0).floor())
	var cracks := crack_level(a.hp, a.max_hp)
	if cracks > 0 and a.flash <= 0.0:
		var palette: Array = PixelArt.GOLD_ROCK_COLORS if a.golden else PixelArt.ROCK_COLORS
		for line in crack_lines(a.radius, a.variant, cracks):
			draw_polyline(line, palette[3], 1.0)
	draw_set_transform(Vector2.ZERO)


## 고대 경비선: 선체가 우주선 쪽으로 천천히 돌고, 움직이면 뒤쪽 엔진이 깜빡인다.
## 충전 중에는 뱃머리(뿔 사이)에 주황빛이 모이고, 쏜 직후에는 뒤로 살짝 밀린다(반동).
func _draw_guard(t: RunSim.Enemy) -> void:
	var dir := Vector2.from_angle(t.aim)
	var charge := Guard.charge_progress(t)
	var recoil := 2.0 * clampf((t.reload - (Balance.GUARD_FIRE_INTERVAL - 0.2)) / 0.2, 0.0, 1.0)
	var center := (t.pos + knock_offset(t) - dir * recoil).round()
	var tex := PixelArt.guard(t.flash > 0.0)
	draw_set_transform(center, t.aim + PI / 2.0)
	var top_left := -(tex.get_size() / 2.0).floor()
	# 엔진 불꽃: 뒤쪽 두 엔진에서 깜빡임
	var flicker := int(t.age * 18.0 + t.variant) % 2
	for x in [3, 9]:
		draw_rect(Rect2(top_left + Vector2(x, 10), Vector2(1, 1 + flicker)), PixelArt.FLAME_COLORS[flicker])
	draw_texture(tex, top_left)
	draw_set_transform(Vector2.ZERO)
	# 핵이 은은하게 맥박치고, 충전하면 뱃머리에 빛이 모인다
	draw_circle(center, 3.0, Color(GUARD_GLOW, 0.15 + 0.1 * sin(t.age * 4.0) + 0.25 * charge))
	if charge > 0.0:
		var nose := center + dir * GUARD_NOSE
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


## 금 선들 (운석 가운데 기준 좌표). 같은 (반지름, 변형 번호)는 항상 같은 모양이고, 단계가 오르면 선이 더해진다.
static func crack_lines(radius: float, variant: int, level: int) -> Array[PackedVector2Array]:
	var key := "%d_%d_%d" % [int(radius), variant, level]
	if _crack_cache.has(key):
		return _crack_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius) * 31 + variant * 977 + 5
	var lines: Array[PackedVector2Array] = []
	for i in level:
		var angle := rng.randf() * TAU
		var line := PackedVector2Array([Vector2.from_angle(angle + PI) * radius * 0.2])
		var p := line[0]
		for j in 3:
			angle += rng.randf_range(-0.6, 0.6)
			p += Vector2.from_angle(angle) * radius * 0.28
			line.append(p.round())
		lines.append(line)
	_crack_cache[key] = lines  # 매 프레임 다시 만들지 않게 모양을 기억해 둔다
	return lines


## 우주 해파리: 몸통이 오므렸다 펴지며(맥박) 촉수가 물결치듯 흔들린다.
func _draw_jelly(e: RunSim.Enemy) -> void:
	var phase := e.age * 5.0 + e.variant
	var pulse := sin(phase)  # -1 ~ 1
	var center := (e.pos + knock_offset(e)).round()
	# 은은한 빛
	draw_circle(center, e.radius + 2.0 + pulse, Color(PixelArt.JELLY_COLORS[1], 0.12))
	# 촉수 4가닥: 몸통 아래에서 늘어져 물결친다 (오므릴 때 짧아짐)
	var length := 6.0 + 2.0 * pulse
	for i in 4:
		var x := -3.0 + i * 2.0
		var prev := center + Vector2(x, 2)
		for j in range(1, 4):
			var y := 2.0 + length * j / 3.0
			var p := center + Vector2(x + sin(phase * 1.3 + i + j * 0.9) * 1.2, y)
			draw_line(prev, p, PixelArt.JELLY_COLORS[2], 1.0)
			prev = p
	# 몸통: 오므릴 때 옆으로 좁아지고 위아래로 길어진다
	var tex := PixelArt.jelly_bell(e.flash > 0.0)
	draw_set_transform(center + Vector2(0, -2), 0.0, Vector2(1.0 - 0.12 * pulse, 1.0 + 0.12 * pulse))
	draw_texture(tex, -(tex.get_size() / 2.0).floor())
	draw_set_transform(Vector2.ZERO)


## 날벌레: 날갯짓(2프레임)을 하며 날아가는 방향을 바라본다.
func _draw_bug(e: RunSim.Enemy) -> void:
	var frame := int(e.age * 14.0 + e.variant) % 2
	var tex := PixelArt.bug(frame, e.flash > 0.0)
	draw_set_transform((e.pos + knock_offset(e)).round(), e.vel.angle() + PI / 2.0)
	draw_texture(tex, -(tex.get_size() / 2.0).floor())
	draw_set_transform(Vector2.ZERO)


## 황금 운석 둘레에서 숨 쉬듯 커졌다 작아지는 금빛 후광 (멀리서도 눈에 띄게)
func _draw_golden_glow(a: RunSim.Enemy) -> void:
	var pulse := 0.5 + 0.5 * sin(sim.time * 4.0)
	draw_circle(a.pos.round(), a.radius + 4.0 + pulse * 3.0, Color(1.0, 0.85, 0.3, 0.12 + 0.08 * pulse))
	draw_arc(a.pos.round(), a.radius + 3.0 + pulse * 4.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.35 * (1.0 - pulse) + 0.15), 1.0)


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


## 등급별 광물: 희귀는 은은한 빛, 영웅은 반짝임, 전설은 빛줄기와 회전
func _draw_mineral(m: RunSim.Mineral) -> void:
	var tex := PixelArt.mineral(m.grade)
	var center := m.pos.round()
	var color: Color = PixelArt.MINERAL_COLORS[m.grade][1]
	var bob := sin(sim.time * 3.0 + m.pos.x * 0.1)  # 둥실거림 (-1~1)
	match m.grade:
		1:
			draw_circle(center, 5.0 + bob, Color(color, 0.12))
		2:
			draw_circle(center, 6.0 + bob, Color(color, 0.15))
		3:
			# 빛줄기 4개가 천천히 돈다
			var spin := sim.time * 1.2
			for i in 4:
				var dir := Vector2.from_angle(spin + i * TAU / 4.0)
				draw_line(center + dir * 5.0, center + dir * (11.0 + 2.0 * bob), Color(1.0, 0.9, 0.4, 0.45), 1.0)
			draw_circle(center, 8.0 + bob, Color(color, 0.18))
	if m.grade == 3:
		# 금괴는 천천히 기울며 돈다
		draw_set_transform(center, sin(sim.time * 1.5) * 0.5)
		draw_texture(tex, -(tex.get_size() / 2.0).floor())
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture(tex, center - (tex.get_size() / 2.0).floor() + Vector2(0, roundf(bob * 0.6)))
	if m.grade >= 2:
		_draw_sparkles(m.pos, 6.0, 2 if m.grade == 2 else 3, m.pos.x)


## 줍기 연출: 등급이 높을수록 크고 화려하게. 희귀 이상은 "+가치" 숫자가 떠오른다.
func _draw_pickup_fx(fx: Dictionary) -> void:
	var grade: int = fx["grade"]
	var t: float = fx["t"]
	var pos: Vector2 = (fx["pos"] as Vector2).round()
	var color: Color = PixelArt.MINERAL_COLORS[grade][1]
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
		var text_color := Color(PixelArt.MINERAL_COLORS[grade][0], 1.0 - t / POPUP_TIME)
		draw_string(FONT, (pos + Vector2(-12, -6 - rise)).round(), "+%d" % value, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, text_color)


## 귀환 성공: 우주선이 게이트 쪽으로 길게 늘어나며 가운데로 빨려 들어간다
func _draw_ship_warp() -> void:
	var k := gate_fx.suck() if gate_fx != null else 1.0
	if k >= 1.0:
		return
	var target := sim.gate.pos
	var pos := sim.player_pos.lerp(target, k * k)
	var angle := (target - sim.player_pos).angle() if sim.player_pos.distance_to(target) > 0.5 else sim.facing
	var tex := PixelArt.ship()
	draw_set_transform(pos.round(), angle + PI / 2.0, Vector2(1.0 - 0.75 * k, 1.0 + 3.5 * k))
	draw_texture(tex, -(tex.get_size() / 2.0).floor(), Color(1, 1, 1, 1.0 - smoothstep(0.7, 1.0, k)))
	draw_set_transform(Vector2.ZERO)


func _draw_ship() -> void:
	# 무적 중에는 깜빡인다.
	if sim.invuln > 0.0 and int(sim.invuln / BLINK_INTERVAL) % 2 == 1:
		return
	var tex := PixelArt.ship()
	# 그림은 위쪽을 바라보므로 바라보는 방향(facing)에서 90도를 더해 돌린다.
	# 돌 때는 옆으로 살짝 눌려 몸을 기울인 것처럼 보인다 (가로 폭이 줄어듦)
	draw_set_transform(sim.player_pos.round(), sim.facing + PI / 2.0, Vector2(1.0 - SHIP_BANK_SQUASH * absf(bank), 1.0))
	var top_left := -(tex.get_size() / 2.0).floor()
	if moving:
		# 엔진 불꽃: 뒤쪽 두 엔진에서 깜빡이는 픽셀
		var flicker := int(sim.time * 20.0) % 2
		for x in [2, 6]:
			draw_rect(Rect2(top_left + Vector2(x, 7), Vector2(1, 1 + flicker)), PixelArt.FLAME_COLORS[flicker])
	draw_texture(tex, top_left)
	draw_set_transform(Vector2.ZERO)
