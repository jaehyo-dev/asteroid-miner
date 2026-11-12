class_name SubWeaponFx
extends RefCounted
## 보조 무기 6종 그리기: 블랙홀, 파동, 기뢰, 미사일·기뢰 폭발, 번개(적 아래), 미사일·톱날(내 탄 층).
## 상태는 RunSim.subs(SubWeapons)를 읽기만 하고, 폭발·번개는 sim.fx("sub_burst", "zap")를 받아 잠깐 남긴다.
## 수치는 Juice.SUB_FX. 모두 정수 픽셀 위치로 그리고 적 탄보다 아래에 그린다(WorldView 순서).

const ORANGE := Color("#f89419")
const GOLD := Color("#f6ce50")
const WHITE := Color("#fef8e5")
const PURPLE := Color("#a884f3")
const DARK := Color("#14111c")
const CYAN := Color("#99e9e6")
const RED := Color("#f25c76")
const METAL := Color("#5c5164")
const METAL_LIGHT := Color("#a5b29d")

var sim: RunSim
## 폭발 {pos, radius, t} / 번개 {points(꺾은 점들), t}
var _bursts: Array[Dictionary] = []
var _zaps: Array[Dictionary] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _init(run_sim: RunSim) -> void:
	sim = run_sim
	_rng.seed = 7


func step(delta: float) -> void:
	_time += delta
	for f in sim.fx:
		if f["type"] == "sub_burst":
			_bursts.append({"pos": f["pos"], "radius": f["radius"], "t": 0.0})
		elif f["type"] == "zap":
			_zaps.append({"points": _jagged(f["points"]), "t": 0.0})
	var p := Juice.SUB_FX
	_bursts = _bursts.filter(func(b: Dictionary) -> bool:
		b["t"] += delta
		return b["t"] < float(p["burst_time"]))
	_zaps = _zaps.filter(func(z: Dictionary) -> bool:
		z["t"] += delta
		return z["t"] < float(p["zap_time"]))
	while _bursts.size() > Juice.SUB_FX_MAX:
		_bursts.pop_front()
	while _zaps.size() > Juice.SUB_FX_MAX:
		_zaps.pop_front()


## 번개 꺾은선: 대상 사이마다 zap_kinks번 옆으로 꺾는다 (그릴 때마다 흔들리지 않게 받을 때 한 번 정함)
func _jagged(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var kinks := int(Juice.SUB_FX["zap_kinks"])
	var jitter := float(Juice.SUB_FX["zap_jitter"])
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var side := (b - a).orthogonal().normalized()
		out.append(a)
		for k in kinks:
			out.append(a.lerp(b, float(k + 1) / (kinks + 1)) + side * _rng.randf_range(-jitter, jitter))
	out.append(points[points.size() - 1])
	return out


# ── 그리기 ─────────────────────────────

## 적·운석 아래: 블랙홀, 파동, 기뢰, 폭발, 번개
func draw_under(ci: CanvasItem) -> void:
	var subs := sim.subs
	var p := Juice.SUB_FX
	for h in subs.holes:
		_draw_hole(ci, h, p)
	for w in subs.waves:
		var k: float = float(w["r"]) / float(w["radius"])
		RunSprites.ring(ci, (w["pos"] as Vector2).round(), w["r"], Color(GOLD, float(p["wave_alpha"]) * (1.0 - k * 0.7)))
		if w["r"] > 4.0:
			RunSprites.ring(ci, (w["pos"] as Vector2).round(), float(w["r"]) - 3.0, Color(WHITE, 0.35 * (1.0 - k)))
	for m in subs.mines:
		_draw_mine(ci, m, p)
	for b in _bursts:
		var k: float = b["t"] / float(p["burst_time"])
		var pos: Vector2 = (b["pos"] as Vector2).round()
		var r: float = float(b["radius"]) * (1.0 - (1.0 - k) * (1.0 - k))
		RunSprites.disc(ci, pos, r * 0.75, Color(ORANGE, 0.4 * (1.0 - k)))
		RunSprites.ring(ci, pos, r, Color(GOLD, 1.0 - k))
		if k < 0.3:
			RunSprites.disc(ci, pos, r * 0.35, Color(WHITE, 0.8))
	for z in _zaps:
		var a: float = 1.0 - z["t"] / float(p["zap_time"])
		var pts: PackedVector2Array = z["points"]
		for i in pts.size() - 1:
			RunSprites.line(ci, pts[i].round(), pts[i + 1].round(), Color(CYAN, 0.45 * a), 3.0)
			RunSprites.line(ci, pts[i].round(), pts[i + 1].round(), Color(WHITE, a), 1.0)


func _draw_hole(ci: CanvasItem, h: Dictionary, p: Dictionary) -> void:
	var t: float = h["t"]
	if t < Balance.SUB_HOLE_FLIGHT:  # 날아가는 중: 작은 검은 구슬 + 보라 테두리
		var at: Vector2 = (h["from"] as Vector2).lerp(h["pos"], t / Balance.SUB_HOLE_FLIGHT).round()
		RunSprites.disc(ci, at, 4.0, PURPLE)
		RunSprites.disc(ci, at, 3.0, DARK)
		return
	var life := (t - Balance.SUB_HOLE_FLIGHT) / float(h["time"])
	var grow := minf(life * 6.0, 1.0) * (1.0 - maxf(life - 0.85, 0.0) / 0.15)  # 열리며 커지고 끝에 오므라든다
	var c: Vector2 = (h["pos"] as Vector2).round()
	var r: float = float(h["radius"]) * grow
	RunSprites.disc(ci, c, r, Color(PURPLE, 0.12))
	RunSprites.ring(ci, c, r, Color(PURPLE, 0.6))
	RunSprites.disc(ci, c, maxf(r * 0.22, 3.0), Color(DARK, float(p["hole_alpha"]) + 0.3))
	RunSprites.ring(ci, c, maxf(r * 0.22, 3.0) + 1.0, Color(CYAN, 0.8))
	# 둘레의 빛 점들이 안쪽으로 감겨 들어간다
	var n := int(p["hole_dots"])
	for i in n:
		var phase := fposmod(_time * 0.8 + float(i) / n, 1.0)
		var at := c + Vector2.from_angle(_time * float(p["hole_spin"]) + TAU * i / n + phase * 2.0) * r * (1.0 - phase)
		RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(WHITE if i % 2 == 0 else PURPLE, 0.9 * (1.0 - phase * 0.5)))


func _draw_mine(ci: CanvasItem, m: Dictionary, p: Dictionary) -> void:
	var c: Vector2 = (m["pos"] as Vector2).round()
	RunSprites.disc(ci, c, 3.0, METAL)
	for i in 4:  # 뿔 4개
		RunSprites.rect(ci, Rect2(c + Vector2.from_angle(TAU * i / 4.0 + PI / 4.0).round() * 3.0 - Vector2.ONE, Vector2(2, 2)), METAL_LIGHT)
	var armed: bool = m["t"] >= Balance.SUB_MINE_ARM
	var on := armed and fposmod(_time * float(p["mine_blink"]), 1.0) < 0.5
	RunSprites.rect(ci, Rect2(c - Vector2.ONE, Vector2(2, 2)), RED if on else Color(RED, 0.4))


## 내 탄 층: 미사일, 톱날
func draw_over(ci: CanvasItem) -> void:
	var subs := sim.subs
	var p := Juice.SUB_FX
	for m in subs.missiles:
		var pos: Vector2 = m["pos"]
		var dir: Vector2 = (m["vel"] as Vector2).normalized()
		for i in int(p["missile_trail"]):  # 꼬리 불꽃: 뒤로 갈수록 작고 옅게
			var at := (pos - dir * (3.0 + i * 2.0)).round()
			RunSprites.rect(ci, Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(ORANGE if i == 0 else GOLD, 0.9 - i * 0.25))
		RunSprites.line(ci, (pos - dir * 2.0).round(), (pos + dir * 2.0).round(), WHITE, 3.0)
		RunSprites.rect(ci, Rect2((pos + dir * 2.0).round() - Vector2.ONE, Vector2(2, 2)), RED)
	var s := subs.stage_of("saw")
	if s > 0 and sim.alive and not sim.returned:
		var teeth := int(p["saw_teeth"])
		for c in subs.saw_points(sim.player_pos, s):
			var center := c.round()
			RunSprites.disc(ci, center, Balance.SUB_SAW_RADIUS, Color(METAL_LIGHT, 0.95))
			for i in teeth:  # 이가 톱날과 같이 돈다
				var at := center + Vector2.from_angle(-subs.saw_angle * 2.0 + TAU * i / teeth) * (Balance.SUB_SAW_RADIUS + 1.0)
				RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), WHITE)
			RunSprites.disc(ci, center, 2.0, ORANGE)
