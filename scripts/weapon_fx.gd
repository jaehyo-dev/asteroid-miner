class_name WeaponFx
extends RefCounted
## 기본 무기 5종의 공격 효과: 총구 섬광, 반동, 탄 모양, 맞은 곳 튐, 레일 자국, 플라스마 폭발, 채굴 빔.
## 수치는 Juice.WEAPON_FX[무기] (2026-11-12 고른 후보).
## WorldView가 그리는 순서: draw_under(적 아래) → … → draw_bullet(내 탄) → draw_over(튐·섬광, 적 탄 아래).

const WHITE := Color("#fef8e5")
const RAIL := Color("#30e1b9")
const RAIL_LIGHT := Color("#99e9e6")
const PLASMA := Color("#a884f3")
const PLASMA_DEEP := Color("#6b3e75")
const PLASMA_DARK := Color("#3a1c57")
const BEAM := Color("#f6ce50")
const BEAM_HOT := Color("#f89419")
const PULSE_GLOW := Color("#30e1b9")
const SMOKE := Color("#917487")
## 맞은 곳 고리·번쩍임 시간
const MARK_TIME := 0.14
## 총구가 우주선 가운데에서 떨어진 거리
const NOSE := 10.0

var sim: RunSim
## 튐·잔불·연기 [위치, 속도, 남은 시간, 처음 시간, 색, 크기, 감속(초당)]
var _parts: Array = []
## 맞은 곳 고리·번쩍임 {pos, t, ring(반지름, 0 없음), flash(반지름, 0 없음), color}
var _marks: Array[Dictionary] = []
## 레일 빛줄기 {angle(쏜 방향), offset(다중 포신 옆 간격), len, t, p}. 시작점은 그릴 때마다 지금 총구라 우주선과 같이 움직인다
var _trails: Array[Dictionary] = []
## 플라스마 폭발 {pos, radius, t, p}
var _blasts: Array[Dictionary] = []
var _muzzle_t := 1.0
var _time := 0.0
var _beam_acc := 0.0  # 빔 불꽃·부스러기를 초당 수에 맞춰 내는 누적
var _beam_n := 0  # 지금까지 낸 빔 불꽃 수 (chips 간격 세기, 프레임마다 0으로 돌리지 않음)
var _rng := RandomNumberGenerator.new()


func _init(run_sim: RunSim) -> void:
	sim = run_sim
	_rng.seed = 11


## 지금 무기의 수치
func params() -> Dictionary:
	return params_for(sim.weapon["id"])


## 그 무기의 수치. 탄·폭발은 쏜 무기 기준 (판 중 무기를 바꿔도 날아가던 탄은 원래 모양으로)
static func params_for(id: String) -> Dictionary:
	return Juice.WEAPON_FX["pulse" if id == "" else id]  # 펄스 탄의 style은 ""


func weapon_id() -> String:
	return sim.weapon["id"]


## 반동 픽셀 (WorldView.recoil_offset에 넘김)
func recoil_px() -> float:
	return float(params()["recoil"])


## 이번 프레임 사건을 받아 효과를 만들고 시간을 흘린다. "hit"·"rail"·"plasma" fx는 여기서만 쓴다
func step(delta: float) -> void:
	_time += delta
	var p := params()
	_muzzle_t += delta
	if sim.events.has("shoot") and weapon_id() != "beam":
		_muzzle_t = 0.0
		for i in int(p.get("smoke", 0)):
			var dir := Vector2.from_angle(sim.aim_angle + _rng.randf_range(-0.6, 0.6))
			_spawn(_nose(), dir * _rng.randf_range(10.0, 25.0), _rng.randf_range(0.3, 0.5), Color(SMOKE, 0.7), 2.0, 3.0)
	for f in sim.fx:
		match f["type"]:
			"hit":
				_on_hit(f, params_for(f["style"]))
			"rail":
				if _trails.size() < Juice.WEAPON_TRAIL_MAX:
					_trails.append({"angle": f["angle"], "offset": f["offset"], "len": f["len"], "t": 0.0, "p": params_for("rail")})
			"plasma":
				_on_blast(f, params_for("plasma"))
	if weapon_id() == "beam" and sim.alive and not sim.beam_targets.is_empty():
		_step_beam(delta, p)
	_trails = _trails.filter(func(t: Dictionary) -> bool:
		t["t"] += delta
		return t["t"] < float(t["p"]["fade"]))
	_marks = _marks.filter(func(m: Dictionary) -> bool:
		m["t"] += delta
		return m["t"] < MARK_TIME)
	_blasts = _blasts.filter(func(b: Dictionary) -> bool:
		b["t"] += delta
		return b["t"] < float(b["p"]["blast_time"]))
	var kept: Array = []
	for d in _parts:
		d[0] += d[1] * delta
		d[1] *= 1.0 - minf(delta * d[6], 1.0)
		d[2] -= delta
		if d[2] > 0.0:
			kept.append(d)
	_parts = kept


## 지금 총구 위치: 우주선 그림과 같은 반동을 넣어, 쏜 직후 우주선이 밀려도 빛이 총구에 붙어 있게 한다
func _nose() -> Vector2:
	var recoil := WorldView.recoil_offset(_muzzle_t, sim.aim_angle, recoil_px())
	return sim.player_pos + recoil + Vector2.from_angle(sim.aim_angle) * NOSE


## 레일 빛줄기의 지금 시작·끝 (사거리는 우주선 가운데부터라 총구만큼 짧게)
func trail_ends(t: Dictionary) -> Array[Vector2]:
	var dir := Vector2.from_angle(t["angle"])
	var from: Vector2 = _nose() + t["offset"]
	return [from, from + dir * (float(t["len"]) - NOSE)]


func _spawn(pos: Vector2, vel: Vector2, life: float, color: Color, size: float, drag := 4.0) -> void:
	if _parts.size() < Juice.WEAPON_PARTICLE_MAX:
		_parts.append([pos, vel, life, life, color, size, drag])


## 맞은 곳: 맞은 쪽 반대로 튀는 조각 (빔·플라스마는 따로)
func _on_hit(f: Dictionary, p: Dictionary) -> void:
	if f["style"] in ["beam", "plasma"] and int(p["hit_n"]) == 0:
		return
	var back: Vector2 = -(f["dir"] as Vector2)
	var colors: Array = p["hit_colors"]
	for i in int(p["hit_n"]):
		var dir := back.rotated(_rng.randf_range(-1.1, 1.1))
		_spawn(f["pos"], dir * float(p["hit_speed"]) * _rng.randf_range(0.5, 1.0), float(p["hit_life"]) * _rng.randf_range(0.7, 1.2), colors[i % colors.size()], float(p["hit_size"]))
	if (float(p["hit_ring"]) > 0.0 or float(p["hit_flash"]) > 0.0) and _marks.size() < Juice.WEAPON_TRAIL_MAX * 2:
		_marks.append({"pos": f["pos"], "t": 0.0, "ring": p["hit_ring"], "flash": p["hit_flash"], "color": colors[0]})


## 플라스마 폭발: 충격파 고리 + 잔불 (천천히 떠다니며 꺼짐)
func _on_blast(f: Dictionary, p: Dictionary) -> void:
	if _blasts.size() < Juice.WEAPON_BLAST_MAX:
		_blasts.append({"pos": f["pos"], "radius": f["radius"], "t": 0.0, "p": p})
	for i in int(p["embers"]):
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		var c := PLASMA if i % 3 else WHITE
		_spawn(f["pos"] + dir * float(f["radius"]) * _rng.randf_range(0.2, 0.7), dir * _rng.randf_range(8.0, 30.0), float(p["ember_life"]) * _rng.randf_range(0.6, 1.0), c, 1.0, 1.5)


## 채굴 빔이 닿는 곳: 초당 sparks개 불꽃, chips개 광물 부스러기
func _step_beam(delta: float, p: Dictionary) -> void:
	_beam_acc += delta
	var spark_gap := 1.0 / maxf(float(p["sparks"]), 0.01)
	var chip_every := int(round(float(p["sparks"]) / maxf(float(p["chips"]), 0.01))) if float(p["chips"]) > 0.0 else 0
	while _beam_acc >= spark_gap:
		_beam_acc -= spark_gap
		_beam_n += 1
		for t in sim.beam_targets:
			var hit := _beam_hit(t)
			var back := (sim.player_pos - t.pos).normalized()
			var colors: Array = p["hit_colors"]
			var dir := back.rotated(_rng.randf_range(-1.2, 1.2))
			_spawn(hit, dir * float(p["hit_speed"]) * _rng.randf_range(0.5, 1.0), float(p["hit_life"]), colors[_rng.randi() % colors.size()], float(p["hit_size"]))
			if chip_every > 0 and _beam_n % chip_every == 0 and t.kind == RunSim.ROCK:
				var cdir := back.rotated(_rng.randf_range(-0.9, 0.9))
				_spawn(hit, cdir * _rng.randf_range(20.0, 45.0), 0.5, Juice.CHIP_COLORS[_rng.randi() % Juice.CHIP_COLORS.size()], 2.0 if p["core"] > 2.0 else 1.0, 2.5)


func _beam_hit(t: RunSim.Enemy) -> Vector2:
	var from := sim.player_pos
	return t.pos + (from - t.pos).limit_length(t.radius * 0.6)  # 운석 겉에서 멈춘다


# ── 그리기 ─────────────────────────────

## 적·운석 아래: 레일 자국, 플라스마 폭발, 채굴 빔 (반투명이라 적과 적 탄을 가리지 않는다)
func draw_under(ci: CanvasItem) -> void:
	for t in _trails:
		_draw_trail(ci, t)
	for b in _blasts:
		_draw_blast(ci, b)
	if weapon_id() == "beam" and sim.alive and not sim.returned:
		var p := params()
		for t in sim.beam_targets:
			_draw_beam(ci, sim.player_pos.round(), _beam_hit(t).round(), p)


func _draw_trail(ci: CanvasItem, t: Dictionary) -> void:
	var p: Dictionary = t["p"]
	var k: float = t["t"] / float(p["fade"])
	var ends := trail_ends(t)
	var a := ends[0].round()
	var b := ends[1].round()
	var fade := (1.0 - k) * (1.0 - k)
	var w := maxf(1.0, float(Weapons.info("rail")["width"]) * (1.0 - k * 0.6))
	if p["dots"] and k > 0.3:
		# 묵직함: 잔상이 점선으로 부서지며 사라진다 (점 간격이 점점 벌어짐)
		var gap := 3.0 + k * 10.0
		var n := int(a.distance_to(b) / gap)
		for i in n:
			var at := a.lerp(b, float(i) / maxf(n, 1)).round()
			RunSprites.rect(ci, Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(RAIL, 0.8 * fade))
		return
	RunSprites.line(ci, a, b, Color(RAIL, 0.3 * fade), w + float(p["glow_w"]))
	RunSprites.line(ci, a, b, Color(RAIL, 0.8 * fade), w)
	if t["t"] < float(p["core_time"]):
		RunSprites.line(ci, a, b, WHITE, maxf(1.0, w - 2.0))


func _draw_blast(ci: CanvasItem, b: Dictionary) -> void:
	var p: Dictionary = b["p"]
	var k: float = b["t"] / float(p["blast_time"])
	var pos: Vector2 = (b["pos"] as Vector2).round()
	var radius: float = b["radius"]
	var r := radius * (1.0 - pow(1.0 - k, 3.0))
	if float(p["scorch"]) > 0.0:  # 묵직함: 어두운 그을음이 남아 천천히 옅어진다
		RunSprites.disc(ci, pos, radius * 0.7, Color(PLASMA_DARK, float(p["scorch"]) * (1.0 - k)))
	RunSprites.disc(ci, pos, r, Color(PLASMA_DEEP, 0.45 * (1.0 - k)))
	RunSprites.disc(ci, pos, r * 0.55, Color(PLASMA, 0.45 * (1.0 - k)))
	for i in int(p["rings"]):
		var rk := clampf(k * 1.3 - i * 0.25, 0.0, 1.0)  # 두 번째 고리는 조금 늦게
		if rk > 0.0:
			RunSprites.ring(ci, pos, radius * (1.0 - pow(1.0 - rk, 3.0)) * (1.0 + 0.25 * i), Color(PLASMA if i == 0 else WHITE, 0.95 * (1.0 - rk)))
	if k < 0.25:
		RunSprites.disc(ci, pos, r * 0.4, Color(WHITE, 0.8 * (1.0 - k / 0.25)))


func _draw_beam(ci: CanvasItem, from: Vector2, hit: Vector2, p: Dictionary) -> void:
	var hz := float(p["pulse_hz"])
	var pulse := 0.5 + 0.5 * sin(_time * TAU * hz) if hz > 0.0 else 1.0
	var wob := float(p["wobble"]) * sin(_time * 37.0)
	var glow := float(p["glow_w"]) + pulse + wob
	RunSprites.line(ci, from, hit, Color(BEAM, 0.3 * (0.7 + 0.3 * pulse)), glow)
	RunSprites.line(ci, from, hit, Color(BEAM_HOT if p["core"] > 2.0 else BEAM, 0.85), float(p["core"]) + 1.0)
	RunSprites.line(ci, from, hit, WHITE, float(p["core"]))
	# 화려함: 빔을 따라 우주선 → 운석으로 흐르는 빛 점
	var n := int(p["travel"])
	for i in n:
		var at := from.lerp(hit, fposmod(_time * 2.5 + float(i) / n, 1.0)).round()
		RunSprites.rect(ci, Rect2(at - Vector2.ONE, Vector2(3, 3)), WHITE)
	RunSprites.disc(ci, hit, 3.0 + float(p["core"]) + pulse * 2.0, Color(BEAM, 0.45))
	RunSprites.disc(ci, from + (hit - from).limit_length(NOSE), float(p["muzzle"]) * (0.7 + 0.3 * pulse), Color(p["muzzle_color"], 0.6))


## 내 탄. 그렸으면 true (드론 탄은 WorldView가 그림)
func draw_bullet(ci: CanvasItem, b: RunSim.Bullet, frame: int) -> bool:
	if b.drone:
		return false
	var p := params_for(b.style)
	var pos := b.pos.round()
	var dir := b.vel.normalized()
	match b.style:
		"", "shotgun":
			var trail := float(p["trail"])
			var color := PULSE_GLOW if b.style == "" else Color(p["hit_colors"][0])
			if trail > 0.0:
				RunSprites.line(ci, (pos - dir * trail).round(), pos, Color(color, 0.45), 1.0 if b.style == "shotgun" else 2.0)
			if float(p["glow"]) > 0.0:
				RunSprites.disc(ci, pos, float(p["glow"]), Color(color, 0.35))
			if b.style == "":
				RunSprites.draw(ci, "bullet", frame, PixelArt.dir8(b.vel.angle() + PI / 2.0), b.pos)
			else:
				var s := float(p["size"])
				RunSprites.rect(ci, Rect2(pos - Vector2.ONE * floorf(s / 2.0), Vector2(s, s)), WHITE if s >= 3.0 else color)
		"plasma":
			var pulse := 0.5 + 0.5 * sin(_time * TAU * 3.0)
			for i in range(int(p["tail"]), 0, -1):  # 꼬리: 지나온 자리에 작아지는 빛 점
				var k := float(i) / float(p["tail"])
				RunSprites.disc(ci, (b.pos - b.vel * float(p["tail_step"]) * i).round(), float(p["orb"]) * (1.0 - k * 0.6), Color(PLASMA, 0.5 * (1.0 - k)))
			RunSprites.disc(ci, pos, float(p["orb_glow"]) + pulse, Color(PLASMA, 0.4))
			RunSprites.disc(ci, pos, float(p["orb"]), PLASMA_DEEP if p["scorch"] > 0.0 else PLASMA)
			RunSprites.rect(ci, Rect2(pos - Vector2.ONE, Vector2(2, 2)), WHITE)
		_:
			return false
	return true


## 내 탄 위·적 탄 아래: 튐·잔불·연기, 총구 섬광, 레일 충전 빛
func draw_over(ci: CanvasItem) -> void:
	for d in _parts:
		var k: float = 1.0 - d[2] / d[3]
		RunSprites.rect(ci, Rect2((d[0] as Vector2).round(), Vector2.ONE * d[5]), Color(d[4], (d[4] as Color).a * (1.0 - k * k)))
	for m in _marks:
		var k: float = m["t"] / MARK_TIME
		var at: Vector2 = (m["pos"] as Vector2).round()
		if m["flash"] > 0.0:
			RunSprites.disc(ci, at, float(m["flash"]) * (1.0 - k), Color(WHITE, 0.9 * (1.0 - k)))
		if m["ring"] > 0.0:
			RunSprites.ring(ci, at, float(m["ring"]) * (0.4 + 0.6 * k), Color(m["color"], 1.0 - k))
	if not sim.alive or sim.returned:
		return
	var p := params()
	var mt := float(p["muzzle_time"])
	var nose := _nose().round()
	if mt > 0.0 and _muzzle_t < mt:
		var k := _muzzle_t / mt
		RunSprites.disc(ci, nose, float(p["muzzle"]) * (1.0 - k * 0.5), Color(p["muzzle_color"], 0.85 * (1.0 - k)))
		RunSprites.disc(ci, nose, float(p["muzzle"]) * 0.4, Color(WHITE, 1.0 - k))
		var cone := float(p.get("cone", 0.0))
		if cone > 0.0:  # 산탄: 총구 앞 부채꼴 불꽃
			for a in [-0.35, 0.0, 0.35]:
				var tip := (nose + Vector2.from_angle(sim.aim_angle + a) * cone * (1.0 - k * 0.5)).round()
				RunSprites.line(ci, nose, tip, Color(p["muzzle_color"], 0.7 * (1.0 - k)), 2.0)
	if weapon_id() == "rail":
		var wait := sim.fire_wait()
		var ct := float(p["charge_time"])
		if wait < ct and wait > 0.0:  # 쏘기 직전: 총구에 빛이 모인다
			var k := 1.0 - wait / ct
			RunSprites.disc(ci, nose, float(p["charge"]) * k + 1.0, Color(RAIL_LIGHT, 0.4 + 0.5 * k))
			if p["charge"] >= 4.0:
				RunSprites.ring(ci, nose, float(p["charge"]) * 2.5 * (1.0 - k) + 2.0, Color(RAIL, 0.8 * k))
