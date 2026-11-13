class_name SubWeaponFx
extends RefCounted
## 보조 무기 6종 그리기: 블랙홀, 파동, 기뢰, 미사일·기뢰 폭발(적 아래), 미사일·톱날·번개·맞은 자리(내 탄 층).
## 상태는 RunSim.subs(SubWeapons)를 읽기만 하고, 폭발·번개·맞은 자리는 sim.fx("sub_burst", "zap", "sub_hit")를 받아 잠깐 남긴다.
## 단계 연출 (2026-11-12 사용자 결정): 1·3·5단계에서 모양이 바뀌고(_tier 0·1·2), 2·4단계는 조금 밝아지기만 한다(_lift).
## 수치는 Juice.SUB_FX. 모두 정수 픽셀 위치로 그리고 적 탄보다 아래에 그린다(WorldView 순서).

const ORANGE := Color("#f89419")
const EMBER := Color("#fb6b1d")
const GOLD := Color("#f6ce50")
const WHITE := Color("#fef8e5")
const PURPLE := Color("#a884f3")
const MAGENTA := Color("#ff2567")
const PLUM := Color("#861a59")
const INDIGO := Color("#3a1c57")
const BLUE := Color("#4d80cd")
const DARK := Color("#14111c")
## 블랙홀 중심: 배경(#080812)보다 어두워야 뚫린 구멍이 아니라 꽉 찬 어둠으로 보인다
const VOID := Color("#000000")
const CYAN := Color("#99e9e6")
const TEAL := Color("#30e1b9")
const RED := Color("#f25c76")
const METAL := Color("#5c5164")
const METAL_LIGHT := Color("#a5b29d")
const SMOKE := Color("#3c3544")
const CHIP := Color("#917487")
const CHIP_DARK := Color("#70525e")

var sim: RunSim
## 폭발 {pos, radius, t, life, kind, tier, sd} / 번개 {raw(대상 점), path(꺾은선), branches, t, life, tier, crackle}
var _bursts: Array[Dictionary] = []
var _zaps: Array[Dictionary] = []
## 채굴 펄스 그림 {pos, radius, t, tier, seed} (판정 파동이 끝나도 5단계 잔광이 남게 따로 둔다)
var _waves: Array[Dictionary] = []
## 맞은 자리 {kind, pos, target, t, life, tier, sd} (톱날 불꽃·부스러기, 채굴 펄스 금·광맥·금가루)
var _hits: Array[Dictionary] = []
## 5단계 블랙홀 붕괴 {pos, radius, t}
var _collapses: Array[Dictionary] = []
var _prev_holes: Array[Dictionary] = []
## 5단계 미사일 발사 때 포드 해치 번쩍임, 3단계 방전 코일 고리가 보이는 시간 (음수면 없음)
var _hatch_t := -1.0
var _ring_t := -1.0
## 진화·짝 스킬 (v0.8.0 5단계): 연쇄 불줄기 {from, to, t, life}, 정지장 붕괴 {pos, radius, t, seed}, 과충전 방전 {pos, radius, paths, t},
## 광맥 공명 충격파 {pos, radius, t, seed}, 몸통 부딪힘(관성 충각)·파쇄 조각은 _hits(kind "ram"·"shatter")
var _links: Array[Dictionary] = []
var _freezes: Array[Dictionary] = []
var _discharges: Array[Dictionary] = []
var _shocks: Array[Dictionary] = []
## 5b단계 진화: 기뢰 도미노 불길 {from, to, t, life}
var _fuses: Array[Dictionary] = []
## 공명 파쇄 (5d단계 후보): 2 진동 음파 점선 {from, to, n(연쇄 몇 번째), t, life}, 1 균열 {path, branches, t, life}, 3 날아가는 결정 조각 {from, target, t, life}
var _veins: Array[Dictionary] = []
var _cracks: Array[Dictionary] = []
var _flights: Array[Dictionary] = []
## 공명 파쇄 그림 후보 1 균열 / 2 진동 / 3 결정화. ?fxtest R로 바꾼다. 사용자가 고르면 고른 것만 남기고 지운다 (v0.8.0 배포 전)
static var res_style := 1
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## 채굴 펄스 육각 격자 꼭짓점 (가운데 기준, 한 번만 만든다)
static var _hex: PackedVector2Array = []


func _init(run_sim: RunSim) -> void:
	sim = run_sim
	_rng.seed = 7


## 1·2단계 0, 3·4단계 1, 5단계 2
func _tier(id: String) -> int:
	var s := sim.subs.stage_of(id)
	return 0 if s < 3 else (1 if s < 5 else 2)


## 진화했는지 (진화 연출은 5단계 모양 위에 하나 더 얹는다)
func _evo(id: String) -> bool:
	return sim.subs.is_evolved(id)


## 2·4단계는 모양 그대로 조금 밝게
func _lift(id: String, c: Color) -> Color:
	return c.lightened(float(Juice.SUB_FX["minor_bright"])) if sim.subs.stage_of(id) in [2, 4] else c


## 같은 효과는 매 프레임 같은 모양이 되게 seed로 정한 0~1 값
static func _h(sd: int, i: int) -> float:
	return fposmod(sin(float(sd) * 12.9898 + float(i) * 78.233) * 43758.5453, 1.0)


func step(delta: float) -> void:
	_time += delta
	var p := Juice.SUB_FX
	for f in sim.fx:
		match f["type"]:
			"sub_burst":
				var tier := 2 if f["kind"] == "chain" else _tier(f["kind"])
				var smoky: bool = f["kind"] == "mine" and tier == 2
				_bursts.append({"pos": f["pos"], "radius": f["radius"], "kind": f["kind"], "tier": tier, "t": 0.0, "seed": _rng.randi() % 997,
					"life": float(p["smoke_time"] if smoky else p["burst_time"])})
			"zap":
				var tier := _tier("coil")
				var path := _jagged(f["points"])
				_zaps.append({"raw": f["points"], "path": path, "branches": _branches(path, int(p["zap_branch"][tier])), "t": 0.0,
					"life": float(p["zap_time"][tier]), "tier": tier, "crackle": 0.0})
				_ring_t = 0.0
			"sub_hit":
				var tier := 2 if f["kind"] == "ice" else _tier("wave" if f["kind"] == "shatter" else f["kind"])
				if f["kind"] == "saw" and tier == 0:
					continue  # 1단계 톱날은 맞을 때 불꽃 없음
				_hits.append({"kind": f["kind"], "pos": f["pos"], "target": f["target"], "tier": tier, "t": 0.0, "seed": _rng.randi() % 997,
					"life": float(p["crack_time"]) if f["kind"] in ["wave", "shatter"] else 0.3, "n": f.get("n", 0)})
			"chain_link":
				_links.append({"from": f["from"], "to": f["to"], "t": 0.0, "life": float(Juice.EVO_FX["link_time"]), "seed": _rng.randi() % 997})
			"sub_collapse":
				_freezes.append({"pos": f["pos"], "radius": f["radius"], "t": 0.0, "life": float(Juice.EVO_FX["freeze_time"]), "seed": _rng.randi() % 997})
			"discharge":
				var paths: Array[PackedVector2Array] = []
				for at: Vector2 in f["points"]:
					paths.append(_jagged([f["pos"], at]))
				_discharges.append({"pos": f["pos"], "radius": f["radius"], "paths": paths, "t": 0.0, "life": float(Juice.EVO_FX["discharge_time"]), "seed": _rng.randi() % 997})
			"vein":
				_shocks.append({"pos": f["pos"], "radius": f["radius"], "t": 0.0, "life": float(Juice.EVO_FX["vein_time"]), "seed": _rng.randi() % 997})
			"ram":
				_hits.append({"kind": "ram", "pos": f["pos"], "target": null, "tier": 2, "t": 0.0, "seed": _rng.randi() % 997, "life": 0.3})
			"mine_fuse":
				_fuses.append({"from": f["from"], "to": f["to"], "t": 0.0, "life": Balance.EVO_MINE_DOMINO + float(Juice.EVO_FX["fuse_after"])})
			"res_link":  # 터지는 차례: 진동은 앞에 터진 운석에서 음파 점선이 이어진다
				if res_style == 2:
					_veins.append({"from": f["from"], "to": f["to"], "n": f["n"], "t": 0.0, "life": float(Juice.RES_FX["vein_life"])})
			"res_mark":  # 표시가 옮겨 붙음: 균열은 그 자리에서 번개처럼 뻗고, 결정화는 결정 조각이 날아가 박힌다
				var from: Vector2 = f["from"]
				var to: Vector2 = (f["target"] as RunSim.Enemy).pos
				if res_style == 1:
					var pts: Array = [from]
					var steps := maxi(int(from.distance_to(to) / 30.0), 1)
					for i in range(1, steps + 1):
						pts.append(from.lerp(to, float(i) / steps))
					var path := _jagged(pts)
					_cracks.append({"path": path, "branches": _branches(path, 2), "t": 0.0, "life": float(Juice.RES_FX["vein_life"])})
				elif res_style == 3:
					_flights.append({"from": from, "target": f["target"], "t": 0.0, "life": float(Juice.RES_FX["fly"])})
	if sim.events.has("sub_wave") and not sim.subs.waves.is_empty():  # 방금 쏜 파동 (공명 파쇄는 파동 대신 스윕이라 없음)
		var w: Dictionary = sim.subs.waves.back()
		_waves.append({"pos": w["pos"], "radius": w["radius"], "t": 0.0, "tier": _tier("wave"), "seed": _rng.randi() % 997})
	if sim.events.has("sub_missile") and _tier("missile") == 2:
		_hatch_t = 0.0
	# 5단계 블랙홀이 다 지나서 사라지면 붕괴 연출
	for h in _prev_holes:
		if not sim.subs.holes.has(h) and float(h["t"]) >= Balance.SUB_HOLE_FLIGHT + float(h["time"]) - 0.1 and _tier("blackhole") == 2:
			_collapses.append({"pos": h["pos"], "radius": h["radius"], "t": 0.0})
	_prev_holes = sim.subs.holes.duplicate()
	if _hatch_t >= 0.0:
		_hatch_t += delta
	if _ring_t >= 0.0:
		_ring_t += delta
	var crackle := float(p["zap_crackle"])
	for z in _zaps:
		if z["tier"] == 2:  # 5단계 번개는 남아 있는 동안 다시 꺾여 지직거린다
			z["crackle"] += delta
			if z["crackle"] >= crackle:
				z["crackle"] = 0.0
				z["path"] = _jagged(z["raw"])
				z["branches"] = _branches(z["path"], int(p["zap_branch"][2]))
	_bursts = _aged(_bursts, delta)
	_zaps = _aged(_zaps, delta)
	_hits = _aged(_hits, delta)
	_links = _aged(_links, delta)
	_freezes = _aged(_freezes, delta)
	_discharges = _aged(_discharges, delta)
	_shocks = _aged(_shocks, delta)
	_fuses = _aged(_fuses, delta)
	_veins = _aged(_veins, delta)
	_cracks = _aged(_cracks, delta)
	_flights = _aged(_flights, delta)
	var wave_after: float = p["wave_after"]
	_waves = _waves.filter(func(w: Dictionary) -> bool:
		w["t"] += delta
		return w["t"] < float(w["radius"]) / Balance.SUB_WAVE_SPEED + (wave_after if w["tier"] == 2 else 0.12))
	var collapse: float = p["collapse_time"]
	_collapses = _collapses.filter(func(c: Dictionary) -> bool:
		c["t"] += delta
		return c["t"] < collapse)
	for list: Array[Dictionary] in [_bursts, _zaps, _waves, _collapses, _links, _freezes, _discharges, _shocks, _fuses, _veins, _cracks, _flights]:
		while list.size() > Juice.SUB_FX_MAX:
			list.pop_front()
	while _hits.size() > Juice.SUB_HIT_MAX:
		_hits.pop_front()


## t를 늘리고 life가 지난 것을 뺀다
static func _aged(list: Array[Dictionary], delta: float) -> Array[Dictionary]:
	return list.filter(func(d: Dictionary) -> bool:
		d["t"] += delta
		return d["t"] < float(d["life"]))


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


## 잔가지: 꺾인 점마다 per번 짧은 가지(점 3개)를 옆으로 뻗는다
func _branches(path: PackedVector2Array, per: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if per <= 0:
		return out
	var kinks := int(Juice.SUB_FX["zap_kinks"])
	for i in range(1, path.size() - 1):
		if i % (kinks + 1) == 0 or _rng.randf() > 0.6:
			continue  # 대상 자리에서는 뻗지 않고, 꺾인 점 일부에서만
		var dir := (path[i + 1] - path[i - 1]).normalized().rotated(_rng.randf_range(0.6, 1.1) * (1.0 if _rng.randf() < 0.5 else -1.0))
		var mid := path[i] + dir * _rng.randf_range(4.0, 6.0)
		out.append(PackedVector2Array([path[i], mid, mid + dir.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(3.0, 5.0)]))
	return out


# ── 그리기: 적·운석 아래 ─────────────────────────────

func draw_under(ci: CanvasItem) -> void:
	var p := Juice.SUB_FX
	if not sim.trail.is_empty():
		_draw_trail(ci)
	for sh in _shocks:
		_draw_shock(ci, sh)
	if not sim.subs.holes.is_empty():
		var tier := _tier("blackhole")
		for h in sim.subs.holes:
			_draw_hole(ci, h, tier, p)
	for c in _collapses:
		_draw_collapse(ci, c, p)
	for w in _waves:
		_draw_wave(ci, w, p)
	_draw_coil_ring(ci, p)
	for pl in sim.subs.pools:
		_draw_pool(ci, pl)
	if _evo("mine"):
		_draw_mine_links(ci)
		for fu in _fuses:
			_draw_fuse(ci, fu)
	if not sim.subs.mines.is_empty():
		var tier := _tier("mine")
		for m in sim.subs.mines:
			_draw_mine(ci, m, tier, p)
	for b in _bursts:
		_draw_burst(ci, b, p)
	for l in _links:
		_draw_link(ci, l)
	for fz in _freezes:
		_draw_freeze(ci, fz)


## 블랙홀 1단계 보라 / 3단계 자홍 + 점 원반 / 5단계 남색 + 나선 팔. 모든 단계: 경계선 없이 바깥으로 옅어지는 안개·먼지,
## 끌려 들어가는 먼지 줄기, 꽉 찬 검은 중심 + 그 바로 바깥을 감싸고 도는 밝은 물질 띠
func _draw_hole(ci: CanvasItem, h: Dictionary, tier: int, p: Dictionary) -> void:
	var t: float = h["t"]
	if t < Balance.SUB_HOLE_FLIGHT:  # 날아가는 중: 작은 검은 구슬 + 단계 색 테두리
		var at: Vector2 = (h["from"] as Vector2).lerp(h["pos"], t / Balance.SUB_HOLE_FLIGHT).round()
		RunSprites.disc(ci, at, 4.0 + tier * 0.5, [PURPLE, MAGENTA, WHITE][tier])
		RunSprites.disc(ci, at, 3.0, VOID)
		return
	var life := (t - Balance.SUB_HOLE_FLIGHT) / float(h["time"])
	var grow := minf(life * 6.0, 1.0) * (1.0 - maxf(life - 0.85, 0.0) / 0.15)  # 열리며 커지고 끝에 오므라든다
	var c: Vector2 = (h["pos"] as Vector2).round()
	var r: float = float(h["radius"]) * grow
	var core := maxf(r * 0.24, 3.0)
	var tint: Color = [Color(PURPLE, 0.14), Color(PLUM, 0.3), Color(INDIGO, 0.45)][tier]
	var dust: Color = [PURPLE, RED, CYAN][tier]
	_soft_disc(ci, c, r, tint)  # 끄는 범위: 가운데 진하고 바깥으로 옅어진다
	_soft_disc(ci, c, r * 0.65, Color(VOID, 0.45))  # 가운데로 갈수록 빛을 삼켜 어두워진다
	_dust_edge(ci, c, r, Color(_lift("blackhole", dust), 0.8), int(p["hole_dust"]), int(h["pos"].x) + 3 * int(h["pos"].y))
	_hole_streams(ci, c, r, p, dust, WHITE)
	match tier:
		1:
			var n := int(p["hole_disk"])  # 둘레를 도는 납작한 점 원반
			for i in n:
				var ang := _time * float(p["hole_spin"]) * 0.6 + TAU * i / n
				var at := c + Vector2(cos(ang), sin(ang) * 0.45) * (core + 6.0)
				RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(MAGENTA if i % 2 == 0 else RED, 0.9))
		2:
			var arms := int(p["hole_arms"])
			for a in arms:  # 나선 팔: 이어진 선, 가운데에 가까울수록 굵고 밝고 바깥 끝은 옅어진다
				var prev := Vector2.ZERO
				for j in 13:
					var k := j / 12.0
					var ang := _time * float(p["hole_spin"]) + TAU * a / arms + k * 2.6
					var at := (c + Vector2.from_angle(ang) * r * (0.25 + 0.7 * k)).round()
					if j > 0:
						var col: Color = WHITE if j < 5 else (CYAN if j < 9 else BLUE)
						RunSprites.line(ci, prev, at, Color(col, 1.0 - k * 0.8), 2.0 if j < 7 else 1.0)
					prev = at
	_accretion(ci, c, core, tier, float(p["hole_band"][tier]))
	RunSprites.disc(ci, c, core, VOID)
	if _evo("blackhole"):  # 정지장: 얼음 조각이 가운데를 감싸고 천천히 돈다 (선 없이 마름모 점) + 움직이면 뒤로 서리 꼬리
		var drift: Vector2 = h.get("drift", Vector2.ZERO)
		if drift.length() > 2.0:
			var back := -drift.normalized()
			var side := back.orthogonal()
			for i in int(Juice.EVO_FX["frost_tail"]):
				var u := float(i) / int(Juice.EVO_FX["frost_tail"])
				var wob := (_h(i, int(_time * 10.0)) - 0.5) * (2.0 + 8.0 * u)
				var at := (c + back * (core + 4.0 + u * r * 1.1) + side * wob).round()
				if i % 3 == 0:
					_ice(ci, at, 1, 0.9 * (1.0 - u))
				else:
					RunSprites.rect(ci, Rect2(at, Vector2.ONE * (2.0 if u < 0.3 else 1.0)), Color(WHITE if i % 2 == 0 else CYAN, 0.85 * (1.0 - u)))
		var n := int(Juice.EVO_FX["ice_shards"])
		for i in n:
			var at := (c + Vector2.from_angle(-_time * 1.5 + TAU * i / n) * (r * 0.55 + 3.0 * sin(_time * 4.0 + i))).round()
			_ice(ci, at, 1 if i % 2 == 0 else 2, 1.0)


## 중심을 감싼 물질 띠: 빛 번짐 위에 밝기가 나선 무늬로 바뀌는 점들이 빠르게 돈다 (안쪽 가장자리는 검은 중심이 덮는다)
func _accretion(ci: CanvasItem, c: Vector2, core: float, tier: int, alpha: float) -> void:
	var hot: Color = _lift("blackhole", [PURPLE, MAGENTA, CYAN][tier])
	_soft_disc(ci, c, core + 5.0, Color(hot, alpha * 0.7), 3)
	for band in 2:
		var rr := core + 1.0 + band * 2.0
		var n := maxi(int(TAU * rr / 2.0), 8)
		for i in n:
			var ang := TAU * i / n
			var swirl := 0.5 + 0.5 * sin(ang * 3.0 - _time * 9.0 + band * 1.2)  # 세 갈래 소용돌이 무늬가 돈다
			var col := WHITE.lerp(hot, 1.0 - swirl) if band == 0 else hot
			RunSprites.rect(ci, Rect2((c + Vector2.from_angle(ang) * rr).round() - Vector2.ONE, Vector2(2, 2)), Color(col, alpha * (0.35 + 0.65 * swirl)))


## 부드러운 원판: 반지름을 줄여 가며 옅은 원판을 겹친다 (가운데 진하고, 가장 바깥 한 칸은 color.a / steps라 경계가 거의 안 보인다)
static func _soft_disc(ci: CanvasItem, c: Vector2, r: float, color: Color, steps := 6) -> void:
	for i in steps:
		RunSprites.disc(ci, c, r * (1.0 - float(i) / (steps + 1)), Color(color, color.a / steps))


## 흐린 가장자리: 0.55r ~ 1.05r에 점을 흩뿌리는데 바깥으로 갈수록 성기고 옅다 (점 자리는 seed로 고정, 천천히 돈다)
func _dust_edge(ci: CanvasItem, c: Vector2, r: float, color: Color, count: int, sd: int) -> void:
	for i in count:
		var u := _h(sd, i)
		var d := 0.55 + 0.5 * u * u  # 제곱이라 안쪽에 많고 바깥에 적다
		var at := c + Vector2.from_angle(_h(sd, i + 100) * TAU + _time * (1.6 - d)) * r * d
		RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(color, color.a * (1.05 - d) / 0.5))


## 끊어진 호: 원둘레를 48조각으로 나눠 seed로 정한 조각만 잇는다 (빈틈이 있어 한 줄 원으로 보이지 않는다). 조각 수가 고정이라 커져도 무늬가 안 흔들린다
func _arc(ci: CanvasItem, c: Vector2, r: float, color: Color, sd: int, width := 1.0) -> void:
	if r < 2.0:
		return
	var gap := float(Juice.SUB_FX["arc_gap"])
	var rot := _h(sd, 999) * TAU + _time * 0.6
	for i in 48:
		if _h(sd, i) < gap:
			continue
		var a0 := rot + TAU * i / 48.0
		RunSprites.line(ci, (c + Vector2.from_angle(a0) * r).round(), (c + Vector2.from_angle(a0 + TAU / 48.0 * 0.8) * r).round(),
			Color(color, color.a * (0.55 + 0.45 * _h(sd, i + 300))), width)


## 뒤로 옅어지는 띠: 반경 r 안쪽 depth 픽셀에 점을 3줄 흩뿌리는데 안쪽 줄일수록 성기고 옅다
func _haze(ci: CanvasItem, c: Vector2, r: float, depth: float, color: Color, sd: int) -> void:
	for row in 3:
		var keep := 1.0 - (row + 1) / 4.0
		var rr := r - (row + 1) * depth / 4.0
		if rr < 2.0:
			return
		for i in 64:
			if _h(sd, i + row * 64) > keep:
				continue
			var at := c + Vector2.from_angle((i + _h(sd, i + 500)) / 64.0 * TAU + _time * 0.6) * rr
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(color, color.a * keep))


## 끌려 들어가는 먼지 줄기: 줄기마다 점 3개가 나선으로 감겨 들어간다 (바깥 끝에서는 옅게 나타난다)
func _hole_streams(ci: CanvasItem, c: Vector2, r: float, p: Dictionary, col: Color, head: Color) -> void:
	var n := int(p["hole_dots"][_tier("blackhole")])
	for i in n:
		for j in 3:
			var phase := fposmod(_time * 0.8 + float(i) / n - j * 0.05, 1.0)
			var at := c + Vector2.from_angle(_time * float(p["hole_spin"]) * 0.5 + TAU * i / n + phase * 2.0) * r * (1.0 - phase)
			var appear := minf(phase / 0.25, 1.0)
			RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2) if j == 0 else Vector2.ONE * 1.0), Color(head if j == 0 else col, (0.9 - j * 0.25) * appear))


## 5단계 블랙홀 붕괴: 가운데 흰 번쩍임 뒤 소용돌이 무늬가 바깥으로 퍼지며 옅어진다
func _draw_collapse(ci: CanvasItem, cl: Dictionary, p: Dictionary) -> void:
	var k: float = cl["t"] / float(p["collapse_time"])
	var c: Vector2 = (cl["pos"] as Vector2).round()
	var r: float = float(cl["radius"]) * (1.0 - (1.0 - k) * (1.0 - k))
	if k < 0.2:
		RunSprites.disc(ci, c, 5.0 * (1.0 - k / 0.2) + 1.0, WHITE)
	_arc(ci, c, r, Color(CYAN, 0.6 * (1.0 - k)), 5)
	_haze(ci, c, r, 8.0, Color(CYAN, 0.6 * (1.0 - k)), 5)
	var arms := int(p["hole_arms"])
	for a in arms:
		for j in 8:
			var kk := j / 7.0
			var at := c + Vector2.from_angle(TAU * a / arms + kk * 2.5 - k * 3.0) * r * (0.25 + 0.75 * kk)
			RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(WHITE if j % 3 == 0 else CYAN, (1.0 - k) * (1.0 - kk * 0.4)))


## 채굴 펄스 1단계 금빛 띠 + 반짝이는 점 / 3단계 띠 두 겹 + 육각 격자 / 5단계 띠 세 겹 + 방사선 + 잔광.
## 띠는 한 줄 원이 아니라 앞쪽 끊어진 호(밝음) + 뒤로 옅어지는 점이고, 퍼질수록 옅어지다 사라진다
func _draw_wave(ci: CanvasItem, w: Dictionary, p: Dictionary) -> void:
	var tier: int = w["tier"]
	var full := float(w["radius"]) / Balance.SUB_WAVE_SPEED
	var r := minf(float(w["t"]) * Balance.SUB_WAVE_SPEED, w["radius"])
	var k := r / float(w["radius"])
	var after := float(p["wave_after"]) if tier == 2 else 0.12
	var a := 1.0 if w["t"] < full else 1.0 - (float(w["t"]) - full) / after
	var c: Vector2 = (w["pos"] as Vector2).round()
	var sd: int = w["seed"]
	var gold := _lift("wave", GOLD)
	if tier == 2 and w["t"] >= full:  # 잔광: 끝 반경에 금가루 안개가 남아 천천히 사라진다
		_soft_disc(ci, c, r, Color(GOLD, 0.05 * a))
		_haze(ci, c, r + 2.0, 12.0, Color(gold, 0.8 * a), sd)
		_haze(ci, c, r - 2.0, 10.0, Color(WHITE, 0.5 * a), sd + 7)
		return
	var fade := (1.0 - k * 0.75) * a
	if tier >= 1:
		_draw_hex(ci, c, r, float(p["hex_band"]), Color(gold, 0.4 * fade))
	for j in int(p["wave_rings"][tier]):
		var rr := r - j * 6.0
		var col: Color = gold if j == 0 else WHITE
		var al := float(p["wave_alpha"]) * fade * (1.0 - j * 0.3)
		_arc(ci, c, rr, Color(col, al), sd + j)
		_haze(ci, c, rr, float(p["wave_band"]), Color(col, al), sd + j + 11)
	if tier == 2:
		var rays := int(p["wave_rays"])
		for i in rays:
			var dir := Vector2.from_angle(TAU * i / rays + 0.13 + k * 0.3)
			RunSprites.line(ci, (c + dir * (r - 3.0)).round(), (c + dir * (r + 7.0)).round(), Color(WHITE if i % 2 == 0 else gold, 0.8 * fade), 1.0)
	var glints := int(p["wave_glints"])
	var blink := int(_time * 12.0)
	for i in glints:
		var at := c + Vector2.from_angle(TAU * i / glints + _time * 0.8) * r
		RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(WHITE if (i + blink) % 2 == 0 else gold, fade))


## 파동이 지나간 띠(r - band ~ r)에만 육각 격자 꼭짓점의 세 변을 그린다 (앞쪽일수록 진하게)
func _draw_hex(ci: CanvasItem, c: Vector2, r: float, band: float, col: Color) -> void:
	var size := float(Juice.SUB_FX["hex_size"])
	if _hex.is_empty():
		var a1 := Vector2(sqrt(3.0) * size, 0.0)
		var a2 := Vector2(sqrt(3.0) * size / 2.0, 1.5 * size)
		for i in range(-20, 21):
			for j in range(-14, 15):
				var v := a1 * i + a2 * j
				if v.length() <= 110.0:
					_hex.append(v)
	var edges := [Vector2(0.0, -size), Vector2(0.866 * size, 0.5 * size), Vector2(-0.866 * size, 0.5 * size)]
	for v in _hex:
		var d := v.length()
		if d > r or d < r - band:
			continue
		var fade := 1.0 - (r - d) / band
		var at := (c + v).round()
		for e: Vector2 in edges:
			RunSprites.line(ci, at, (at + e).round(), Color(col, col.a * fade), 1.0)


## 방전 코일 우주선 둘레 전기 고리: 3단계는 쏠 때 잠깐, 5단계는 늘 돈다
func _draw_coil_ring(ci: CanvasItem, p: Dictionary) -> void:
	var tier := _tier("coil")
	if tier == 0 or not sim.alive or sim.returned:
		return
	var a := 1.0
	if tier == 1:
		if _ring_t < 0.0 or _ring_t > float(p["coil_ring_time"]):
			return
		a = 1.0 - _ring_t / float(p["coil_ring_time"])
	var c := sim.player_pos.round()
	var r := float(p["coil_ring"]) + (1.0 if tier == 2 else 0.0)
	var size := Vector2(2, 2) if tier == 2 else Vector2.ONE
	for arc in 3:  # 끊어진 호 3개가 돈다
		for j in 4:
			var at := c + Vector2.from_angle(_time * 6.0 + TAU * arc / 3.0 + j * 0.2) * r
			RunSprites.rect(ci, Rect2(at.round() - size / 2.0, size), Color(WHITE if j == 0 else CYAN, a * (0.9 - j * 0.15)))
	if tier == 2 and int(_time * 20.0) % 3 == 0:  # 지직: 고리 밖으로 튀는 작은 불꽃
		var ang := _h(int(_time * 20.0), 1) * TAU
		RunSprites.line(ci, (c + Vector2.from_angle(ang) * r).round(), (c + Vector2.from_angle(ang + 0.3) * (r + 4.0)).round(), WHITE, 1.0)


## 기뢰 1단계 작은 기뢰 / 3단계 가시 + 적이 가까우면 빨리 깜빡 / 5단계 더 크고 가시 8개 (늘 보이는 경고 원은 없음: 들어가도 안 터져 오해, 2026-11-12)
## 깜빡이는 것은 가운데 2×2 빨간 점 하나뿐 (몸체·큰 불빛은 안 깜빡임, 2026-11-13 사용자 결정)
func _draw_mine(ci: CanvasItem, m: Dictionary, tier: int, p: Dictionary) -> void:
	var c: Vector2 = (m["pos"] as Vector2).round()
	var armed: bool = m["t"] >= Balance.SUB_MINE_ARM
	var rate := float(p["mine_blink"])
	if tier >= 1 and armed:
		for e in sim.enemies:
			if e.hp > 0.0 and e.pos.distance_to(c) < float(p["mine_alert"]) + e.radius:
				rate *= 3.0
				break
	var on := armed and fposmod(_time * rate + float(m["pos"].x) * 0.01, 1.0) < 0.5
	var light := _lift("mine", RED)
	var body := 3.0 + (1.0 if tier == 2 else 0.0)
	RunSprites.disc(ci, c, body, METAL)
	if tier >= 1:
		var horns := 4 if tier == 1 else 8
		for i in horns:  # 가시
			var at := c + Vector2.from_angle(TAU * i / horns + PI / 4.0) * (body + 1.5)  # 몸통 밖으로 튀어나오게
			RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), METAL_LIGHT)
	RunSprites.rect(ci, Rect2(c - Vector2.ONE, Vector2(2, 2)), light if on else Color(light, 0.4))


## 5단계 기뢰가 터질 때 번쩍이는 빨간 원의 반지름 = 실제 폭발 범위 (SubWeapons._burst가 이 반경 + 적 반지름 안을 맞힌다)
static func flash_radius(b: Dictionary) -> float:
	return b["radius"]


## 폭발: 미사일 1단계 작은 폭발 / 3단계 + 충격파 고리 / 5단계 + 불티. 기뢰 1단계 작은 폭발 / 3단계 + 고리 / 5단계 불꽃 꽃잎 + 연기 + 끊어진 호 + 범위 번쩍임
func _draw_burst(ci: CanvasItem, b: Dictionary, p: Dictionary) -> void:
	var tier: int = b["tier"]
	var k := minf(float(b["t"]) / float(p["burst_time"]), 1.0)
	var grow := 1.0 - (1.0 - k) * (1.0 - k)
	var pos: Vector2 = (b["pos"] as Vector2).round()
	var radius: float = b["radius"]
	var r := radius * grow
	var sd: int = b["seed"]
	if b["kind"] == "mine" and tier == 2:
		var ks: float = b["t"] / float(b["life"])  # 연기는 폭발보다 오래 천천히 퍼진다
		for i in 5:
			var at := pos + Vector2.from_angle(TAU * i / 5.0 + _h(sd, i)) * radius * 0.5 * ks
			RunSprites.disc(ci, at.round(), radius * (0.2 + 0.15 * ks), Color(SMOKE, 0.55 * (1.0 - ks)))
		if k < 1.0:
			for i in 6:  # 불꽃 꽃잎
				var at := pos + Vector2.from_angle(TAU * i / 6.0 + float(sd)) * r * 0.55
				RunSprites.disc(ci, at.round(), radius * 0.3 * (1.0 - k * 0.5), Color(EMBER if i % 2 == 0 else ORANGE, 0.7 * (1.0 - k)))
			RunSprites.disc(ci, pos, r * 0.3, Color(GOLD, 0.9 * (1.0 - k)))
			_arc(ci, pos, r * 1.05, Color(GOLD, 1.0 - k), sd)
		if b["t"] < float(p["mine_flash"]) and int(b["t"] * 20.0) % 2 == 0:  # 터지는 순간 실제 폭발 범위가 빨갛게 번쩍인다
			RunSprites.disc(ci, pos, flash_radius(b), Color(RED, 0.18))
			RunSprites.ring(ci, pos, flash_radius(b), RED)
		return
	if k >= 1.0:
		return
	_soft_disc(ci, pos, r * (0.6 if tier == 0 else 0.75), Color(MAGENTA if b["kind"] == "chain" else (ORANGE if b["kind"] == "missile" else EMBER), 0.6 * (1.0 - k)), 3)
	if tier >= 1:
		_arc(ci, pos, r * 1.1, Color(WHITE if k < 0.4 else GOLD, 1.0 - k), sd)
	if k < 0.3:
		RunSprites.disc(ci, pos, r * 0.3, Color(WHITE, 0.85))
	if tier == 2:
		for i in int(p["missile_sparks"]):  # 사방으로 튀는 불티
			var dir := Vector2.from_angle(_h(sd, i) * TAU)
			var at := pos + dir * radius * (0.4 + 0.9 * _h(sd, i + 50)) * grow
			RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color([WHITE, GOLD, EMBER][i % 3], 1.0 - k))


## 번개 1단계 가는 파란 선 / 3단계 + 잔가지 + 대상 흰 번쩍 / 5단계 굵은 흰·청록 + 빛 번짐 (지직거림은 step에서)
func _draw_zap(ci: CanvasItem, z: Dictionary) -> void:
	var tier: int = z["tier"]
	var a: float = 1.0 - z["t"] / float(z["life"])
	var pts: PackedVector2Array = z["path"]
	var core := _lift("coil", WHITE if tier >= 1 else CYAN)
	for i in pts.size() - 1:
		var p0 := pts[i].round()
		var p1 := pts[i + 1].round()
		match tier:
			0:
				RunSprites.line(ci, p0, p1, Color(BLUE, 0.9 * a), 2.0)
				RunSprites.line(ci, p0, p1, Color(core, a), 1.0)
			1:
				RunSprites.line(ci, p0, p1, Color(CYAN, 0.45 * a), 3.0)
				RunSprites.line(ci, p0, p1, Color(core, a), 1.0)
			2:
				RunSprites.line(ci, p0, p1, Color(TEAL, 0.25 * a), 6.0)
				RunSprites.line(ci, p0, p1, Color(CYAN, 0.7 * a), 3.0)
				RunSprites.line(ci, p0, p1, Color(core, a), 2.0)
	for br: PackedVector2Array in z["branches"]:
		for i in br.size() - 1:
			RunSprites.line(ci, br[i].round(), br[i + 1].round(), Color(CYAN if tier == 1 else WHITE, 0.8 * a), 1.0)
	if tier >= 1 and a > 0.4:  # 맞은 대상이 잠깐 하얗게
		var raw: Array = z["raw"]
		for i in range(1, raw.size()):
			var at: Vector2 = (raw[i] as Vector2).round()
			RunSprites.disc(ci, at, 4.0 + tier, Color(WHITE, 0.7 * (a - 0.4) / 0.6))
			if tier == 2:  # 대상 둘레에 도는 불꽃 점 4개 (고리 선 대신)
				for j in 4:
					var sp := at + Vector2.from_angle(_time * 8.0 + TAU * j / 4.0 + i) * 7.0
					RunSprites.rect(ci, Rect2(sp.round() - Vector2.ONE, Vector2(2, 2)), Color(CYAN if j % 2 == 0 else WHITE, a))


# ── 그리기: 내 탄 층 ─────────────────────────────

## 미사일, 5단계 해치 번쩍임, 톱날, 번개, 맞은 자리
func draw_over(ci: CanvasItem) -> void:
	var p := Juice.SUB_FX
	if not sim.subs.missiles.is_empty():
		var tier := _tier("missile")
		for m in sim.subs.missiles:
			_draw_missile(ci, m, tier, p)
	if _hatch_t >= 0.0 and _hatch_t < float(p["hatch_time"]) and sim.alive:
		var k := _hatch_t / float(p["hatch_time"])
		var c := sim.player_pos.round()
		RunSprites.disc(ci, c, 8.0 - k * 4.0, Color(WHITE, 0.8 * (1.0 - k)))
		for i in 4:
			var dir := Vector2.from_angle(PI / 4.0 + TAU * i / 4.0)
			RunSprites.line(ci, (c + dir * 6.0).round(), (c + dir * (10.0 + 4.0 * k)).round(), Color(GOLD, 1.0 - k), 1.0)
	var s := sim.subs.stage_of("saw")
	if s > 0 and sim.alive and not sim.returned:
		_draw_saws(ci, s, p)
	if sim.chill_ratio > 0.0 or sim.charge_step > 0.0 or _evo("blackhole"):
		_draw_enemy_marks(ci)
	if _evo("coil") and sim.alive and not sim.returned:
		_draw_coil_charge(ci)
	for d in _discharges:
		_draw_discharge(ci, d)
	for sh in sim.subs.shards:
		_draw_shard(ci, sh)
	for sw in sim.subs.sweeps:
		_draw_marks(ci, sw)
	for v in _veins:
		_draw_sonar(ci, v)
	for cr in _cracks:
		_draw_crack(ci, cr)
	for fl in _flights:
		_draw_flight(ci, fl)
	for z in _zaps:  # 번개는 가까운 대상과 짧게 이어져 적 아래면 가려진다 → 내 탄 층 (적 탄보다는 아래)
		_draw_zap(ci, z)
	for h in _hits:
		_draw_hit(ci, h, p)


## 미사일: 몸통 6픽셀(예전 4의 1.5배) + 단계별 탄두·꼬리. 1단계 가는 연기 / 3단계 밝은 탄두 + 불꽃 꼬리 두 줄 / 5단계 붉은 주황 탄두 + 반짝이는 꼬리
func _draw_missile(ci: CanvasItem, m: Dictionary, tier: int, p: Dictionary) -> void:
	var pos: Vector2 = m["pos"]
	var dir: Vector2 = (m["vel"] as Vector2).normalized()
	var side := dir.orthogonal()
	var n := int(p["missile_trail"][tier])
	for i in n:
		var back := pos - dir * (5.0 + i * 2.0)
		match tier:
			0:
				RunSprites.rect(ci, Rect2(back.round(), Vector2.ONE), Color(METAL_LIGHT, 0.6 - i * 0.12))
			1:
				for sgn: float in [-1.0, 1.0]:
					var at := (back + side * sgn * 1.5).round()
					RunSprites.rect(ci, Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(ORANGE if i < 2 else GOLD, 0.9 - i * 0.2))
			2:
				var at := (back + side * sin(_time * 30.0 + i) * 1.5).round()
				var col: Color = WHITE if (i + int(_time * 20.0)) % 3 == 0 else (EMBER if i < 2 else GOLD)
				RunSprites.rect(ci, Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(col, 1.0 - i * 0.13))
	var head := (pos + dir * 3.0).round()
	if tier >= 1:
		RunSprites.disc(ci, head, 3.0 + tier, Color(GOLD if tier == 1 else EMBER, 0.35))
	RunSprites.line(ci, (pos - dir * 3.0).round(), (pos + dir * 3.0).round(), _lift("missile", WHITE if tier < 2 else METAL_LIGHT), 3.0)
	if _evo("missile"):  # 연쇄 폭격: 탄두가 진홍빛으로 달아오르고 꼬리 옆으로 불티가 튄다
		RunSprites.disc(ci, head, 5.0, Color(MAGENTA, 0.3))
		for i in 3:
			var at := (pos - dir * (6.0 + i * 3.0) + side * (2.5 if (i + int(_time * 24.0)) % 2 == 0 else -2.5)).round()
			RunSprites.rect(ci, Rect2(at, Vector2.ONE), Color(MAGENTA if i % 2 == 0 else GOLD, 1.0 - i * 0.25))
	match tier:
		0:
			RunSprites.rect(ci, Rect2(head - Vector2.ONE, Vector2(2, 2)), _lift("missile", RED))
		1:
			RunSprites.rect(ci, Rect2(head - Vector2.ONE, Vector2(2, 2)), _lift("missile", GOLD))
		2:
			RunSprites.disc(ci, head, 2.0, EMBER)
			RunSprites.rect(ci, Rect2(head, Vector2.ONE), WHITE)


## 톱날 1단계 작은 회색 / 3단계 청록 날 끝 + 짧은 잔상 호 / 5단계 큰 톱니 + 주황 날 끝 + 긴 잔상 호
## 회전 충각: 도는 속도만큼 길어지는 잔상 호 + 퍼진 동안 불티, 가장 빠를 때 날 끝이 하얗게 달아오름
func _draw_saws(ci: CanvasItem, s: int, p: Dictionary) -> void:
	var tier := _tier("saw")
	var evo := _evo("saw")
	var n := int(SubWeapons.stat("saw", "count", s))
	var orbit := SubWeapons.stat("saw", "orbit", s)
	var tip: Color = _lift("saw", [METAL_LIGHT, TEAL, EMBER][tier])
	var hot := 0.0  # 날 끝이 하얗게 달아오른 정도 (회전 충각이 가장 넓고 빠를 때)
	if evo:
		_draw_saw_trail(ci)
		var from := float(Juice.EVO_FX["saw_hot"])
		hot = clampf((sim.subs.spread_k() - from) / (1.0 - from), 0.0, 1.0)
	else:
		var trail := int(p["saw_trail"][tier])
		for i in n:
			for j in range(trail, 0, -1):  # 잔상 호: 지나온 자리에 옅어지는 점
				var at := sim.player_pos + Vector2.from_angle(sim.subs.saw_angle - j * 0.09 + TAU * i / n) * orbit
				var col: Color = TEAL if tier == 1 else (GOLD if j * 2 > trail else EMBER)
				RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(col, 0.6 * (1.0 - float(j) / (trail + 1))))
	var radius := Balance.EVO_SAW_RADIUS - 1.0 if evo else Balance.SUB_SAW_RADIUS - 1.0 + tier
	var teeth := int(Juice.EVO_FX["saw_teeth"]) if evo else int(p["saw_teeth"][tier])
	for c in sim.subs.saw_points(sim.player_pos, s):
		var center := c.round()
		if hot > 0.0:  # 달아오른 빛
			_soft_disc(ci, center, radius + 4.0, Color(WHITE, 0.35 * hot), 3)
		RunSprites.disc(ci, center, radius, Color(METAL_LIGHT, 0.95))
		RunSprites.disc(ci, center, radius - 2.0, METAL)
		for i in teeth:  # 이가 톱날과 같이 돈다
			var dir := Vector2.from_angle(-sim.subs.saw_angle * 2.0 + TAU * i / teeth)
			RunSprites.rect(ci, Rect2((center + dir * (radius + 1.0)).round() - Vector2.ONE, Vector2(2, 2)), tip.lerp(WHITE, hot))
			if tier == 2:
				var edge: Color = MAGENTA if evo and i % 2 == 0 else GOLD
				RunSprites.rect(ci, Rect2((center + dir * (radius + 2.5)).round(), Vector2.ONE), edge.lerp(WHITE, hot))
		if evo:  # 달아오른 가운데
			RunSprites.disc(ci, center, 4.0, Color(MAGENTA, 0.6 + 0.3 * sim.subs.spread_k()))
		RunSprites.disc(ci, center, 2.0 if tier < 2 else 2.5, ORANGE.lerp(WHITE, hot) if tier == 2 else WHITE)


## 회전 충각 잔상: 톱날마다 지금 도는 속도만큼 뒤로 뻗는 호 (금 → 진홍으로 옅어짐). 빨리 돌수록 길고 굵지만
## 최대 saw_arc_max라 톱날 사이가 비어 원으로 이어지지 않는다. 퍼진 동안엔 호 바깥으로 불티가 튄다
func _draw_saw_trail(ci: CanvasItem) -> void:
	var k := sim.subs.spread_k()
	var span := minf(sim.subs.saw_spin() * float(Juice.EVO_FX["saw_arc_time"]), float(Juice.EVO_FX["saw_arc_max"]))
	var c := sim.player_pos
	var steps := 8
	for p in sim.subs.saw_points(c):
		var r := p.distance_to(c)
		var a0 := (p - c).angle()
		for j in steps:
			var u := float(j) / steps
			var from := c + Vector2.from_angle(a0 - span * u) * r
			var to := c + Vector2.from_angle(a0 - span * (u + 1.0 / steps)) * r
			var col: Color = WHITE.lerp(GOLD, minf(u * 4.0, 1.0)) if k > 0.5 and u < 0.25 else (GOLD if u < 0.35 else (EMBER if u < 0.7 else MAGENTA))
			if k > 0.3:  # 퍼진 동안: 넓게 번지는 빛 띠 (빨리 도는 흐림)
				RunSprites.line(ci, from.round(), to.round(), Color(EMBER, 0.3 * k * (1.0 - u)), 7.0)
			RunSprites.line(ci, from.round(), to.round(), Color(col, 0.8 * (1.0 - u)), 3.0 if k > 0.3 and u < 0.5 else 2.0)
		if k > 0.15:  # 불티: 날 뒤에서 바깥으로 튀어 흩어진다 (점마다 자리를 다시 뽑아 반짝인다)
			for i in 8:
				var life := fposmod(_time * 5.0 + _h(i, 3), 1.0)
				var back := a0 - span * (0.1 + 0.5 * _h(i, int(_time * 5.0 + _h(i, 3))))
				var at := c + Vector2.from_angle(back) * (r + 3.0 + 10.0 * life)
				RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color([WHITE, GOLD, EMBER][i % 3], k * (1.0 - life)))


## 맞은 자리: 톱날 3단계 불꽃 / 5단계 주황 불꽃 + 운석 부스러기, 채굴 펄스 1단계 금 / 3단계 빛나는 광맥 / 5단계 + 금가루
func _draw_hit(ci: CanvasItem, h: Dictionary, p: Dictionary) -> void:
	var k: float = h["t"] / float(h["life"])
	var sd: int = h["seed"]
	var tier: int = h["tier"]
	if h["kind"] == "ram":  # 몸통으로 부숨: 흰·금 불꽃이 앞으로 튄다
		var at0: Vector2 = h["pos"]
		for i in 6:
			var at := at0 + Vector2.from_angle(_h(sd, i) * TAU) * (3.0 + 14.0 * k)
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE * (2.0 if i < 2 else 1.0)), Color([WHITE, GOLD, ORANGE][i % 3], 1.0 - k))
		return
	if h["kind"] == "ice":  # 얼음 조각이 맞은 자리: 청백 조각이 작게 튄다
		var at0: Vector2 = h["pos"]
		for i in 4:
			var at := at0 + Vector2.from_angle(_h(sd, i) * TAU) * (2.0 + 8.0 * k)
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(WHITE if i % 2 == 0 else CYAN, 1.0 - k))
		return
	if h["kind"] == "shatter":  # 공명 파쇄로 터짐 (후보마다 다르게). 연쇄가 길어질수록 밝고 하얘진다
		_draw_res_pop(ci, h, k)
		return
	var target: RunSim.Enemy = h["target"]
	var rock: bool = target.kind == RunSim.ROCK
	if h["kind"] == "saw":
		var pos: Vector2 = h["pos"]
		for i in int(p["saw_chips"][tier]):
			var dir := Vector2.from_angle(_h(sd, i) * TAU)
			var at := pos + dir * (2.0 + 12.0 * k)
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE * (2.0 if i == 0 else 1.0)), Color([WHITE, TEAL][i % 2] if tier == 1 else [WHITE, GOLD, EMBER][i % 3], 1.0 - k))
		if tier == 2 and rock:
			for i in 4:  # 돌 부스러기: 불꽃보다 무겁게 덜 멀리
				var dir := Vector2.from_angle(_h(sd, i + 20) * TAU)
				var at := pos + dir * (2.0 + 9.0 * k)
				RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(CHIP if i % 2 == 0 else CHIP_DARK, 1.0 - k * 0.7))
		return
	var c: Vector2 = (target.pos if target.hp > 0.0 else h["pos"]).round()
	var rr := target.radius
	if not rock:  # 해파리·날벌레는 금빛 점만 잠깐
		for i in 3:
			var at := c + Vector2.from_angle(_h(sd, i) * TAU) * (rr + 3.0 * k)
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(GOLD, 1.0 - k))
		return
	var a := 1.0 - k
	var cracks := 3 if tier == 0 else 4
	for i in cracks:  # 가운데 근처에서 바깥으로 꺾이며 뻗는 금
		var ang := _h(sd, i) * TAU
		var start := c + Vector2.from_angle(ang + 1.3) * rr * 0.15
		var mid := c + Vector2.from_angle(ang) * rr * 0.45 + Vector2.from_angle(ang + PI / 2.0) * 1.5
		var end := c + Vector2.from_angle(ang + 0.3) * rr * (0.8 if tier == 0 else 0.95)
		if tier >= 1:
			RunSprites.line(ci, start.round(), mid.round(), Color(GOLD, 0.4 * a), 3.0)
			RunSprites.line(ci, mid.round(), end.round(), Color(GOLD, 0.4 * a), 3.0)
		var col := WHITE if tier >= 1 else _lift("wave", GOLD)
		RunSprites.line(ci, start.round(), mid.round(), Color(col, a), 1.0)
		RunSprites.line(ci, mid.round(), end.round(), Color(col, a), 1.0)
		if tier >= 1:
			RunSprites.rect(ci, Rect2(mid.round() - Vector2.ONE, Vector2(2, 2)), Color(GOLD, a))
	if tier == 2:
		for i in int(p["dust"]):  # 금가루
			var at := c + Vector2.from_angle(_h(sd, i + 40) * TAU) * (rr * 0.6 + 18.0 * k * (0.5 + _h(sd, i + 60)))
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE * (2.0 if i % 3 == 0 else 1.0)), Color(WHITE if i % 2 == 0 else GOLD, a))


# ── 진화·짝 스킬 그리기 (v0.8.0 5단계) ─────────────────────────────

## 얼음 조각: 마름모 점 (size 1 = 3칸 십자, 2 = 5칸) + 흰 가운데
func _ice(ci: CanvasItem, at: Vector2, size: int, a: float) -> void:
	for d: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		RunSprites.rect(ci, Rect2(at + d * size, Vector2.ONE), Color(CYAN, a))
	RunSprites.rect(ci, Rect2(at, Vector2.ONE), Color(WHITE, a))


## 잔류 분사 궤적: 지나간 자리 불꽃 점. 새것은 금·흰빛으로 크고, 오래될수록 작고 붉게 사라진다
func _draw_trail(ci: CanvasItem) -> void:
	var big := float(Juice.EVO_FX["trail_size"])
	for i in sim.trail.size():
		var pt: Dictionary = sim.trail[i]
		var k: float = pt["t"] / Balance.TRAIL_LIFE
		var flick := _h(i, int(_time * 15.0))
		var at := (pt["pos"] as Vector2 + Vector2(flick - 0.5, -k * 4.0)).round()
		var col: Color = WHITE if k < 0.15 else (GOLD if k < 0.4 else (ORANGE if k < 0.7 else EMBER))
		var sz := maxf(roundf(big * (1.0 - k) + 0.5), 1.0)
		RunSprites.rect(ci, Rect2(at - Vector2.ONE * floorf(sz / 2.0), Vector2.ONE * sz), Color(col, 0.9 * (1.0 - k * 0.6)))


## 연소 기뢰선: 이어진 기뢰 사이 불타는 선 (빛 번짐 3px + 주황 1px 심지) 위로 불티가 선을 따라 흐른다
func _draw_mine_links(ci: CanvasItem) -> void:
	var embers := int(Juice.EVO_FX["fire_embers"])
	var links := sim.subs.mine_links()
	for li in links.size():
		var a := links[li][0].round()
		var b := links[li][1].round()
		var flick := 0.75 + 0.25 * sin(_time * 18.0 + li)
		RunSprites.line(ci, a, b, Color(EMBER, 0.35 * flick), 4.0)
		RunSprites.line(ci, a, b, Color(ORANGE, 0.85 * flick), 2.0)
		RunSprites.line(ci, a, b, Color(GOLD, 0.6 * flick), 1.0)
		for e in embers:
			var u := fposmod(_time * 0.9 + float(e) / embers + _h(li, e), 1.0)
			var at := a.lerp(b, u) + Vector2(0.0, -2.0 - 3.0 * _h(li, e + 7) - sin(_time * 10.0 + e) * 1.5)
			RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(WHITE if e == 0 else GOLD, 0.9))


## 연쇄 폭격: 앞 폭발에서 다음 폭발로 튀는 진홍·금 불줄기 (꺾인 선, 짧게)
func _draw_link(ci: CanvasItem, l: Dictionary) -> void:
	var a: float = 1.0 - l["t"] / float(l["life"])
	var from: Vector2 = l["from"]
	var to: Vector2 = l["to"]
	var side := (to - from).orthogonal().normalized()
	var prev := from.round()
	for i in range(1, 5):
		var at := (from.lerp(to, i / 4.0) + side * ((_h(l["seed"], i) - 0.5) * 8.0 if i < 4 else 0.0)).round()
		RunSprites.line(ci, prev, at, Color(MAGENTA, 0.5 * a), 3.0)
		RunSprites.line(ci, prev, at, Color(GOLD, a), 1.0)
		prev = at


## 정지장 붕괴: 가운데 흰 번쩍 → 얼음 조각이 사방으로 튀고, 청록 서리 안개가 범위만큼 퍼지며 옅어진다 (경계선 없음)
func _draw_freeze(ci: CanvasItem, fz: Dictionary) -> void:
	var k: float = fz["t"] / float(fz["life"])
	var c: Vector2 = (fz["pos"] as Vector2).round()
	var r: float = float(fz["radius"]) * (1.0 - (1.0 - k) * (1.0 - k))
	var sd: int = fz["seed"]
	if k < 0.25:
		RunSprites.disc(ci, c, 8.0 * (1.0 - k / 0.25) + 2.0, WHITE)
	_soft_disc(ci, c, r, Color(CYAN, 0.18 * (1.0 - k)), 4)
	_haze(ci, c, r, 10.0, Color(WHITE, 0.7 * (1.0 - k)), sd)
	for i in int(Juice.EVO_FX["freeze_shards"]):
		var at := c + Vector2.from_angle(_h(sd, i) * TAU) * r * (0.5 + 0.5 * _h(sd, i + 40))
		_ice(ci, at.round(), 2 if i % 3 == 0 else 1, 1.0 - k)


## 광맥 공명기 충격파: 금빛 끊어진 호 + 뒤로 옅어지는 점이 짧게 퍼진다
func _draw_shock(ci: CanvasItem, sh: Dictionary) -> void:
	var k: float = sh["t"] / float(sh["life"])
	var c: Vector2 = (sh["pos"] as Vector2).round()
	var r: float = float(sh["radius"]) * (1.0 - (1.0 - k) * (1.0 - k))
	_arc(ci, c, r, Color(GOLD, 0.8 * (1.0 - k)), sh["seed"])
	_haze(ci, c, r, 6.0, Color(WHITE, 0.6 * (1.0 - k)), sh["seed"] + 3)


## 적 위 표시: 냉각(느려짐) 서리 점, 정지장에 언 적은 얼음 조각, 전하 축적 탄 쌓인 수만큼 청록 점 (적 탄보다 아래 층)
func _draw_enemy_marks(ci: CanvasItem) -> void:
	var dots := int(Juice.EVO_FX["frost_dots"])
	for e in sim.enemies:
		if e.hp <= 0.0:
			continue
		var c := e.pos.round()
		if e.chill > 0.0:
			if e.chill_slow >= 1.0:  # 정지장: 얼어붙음
				for i in 4:
					_ice(ci, (c + Vector2.from_angle(TAU * i / 4.0 + 0.6) * e.radius * 0.8).round(), 1, 0.9)
			else:
				for i in dots:
					var at := c + Vector2.from_angle(TAU * i / dots + _time * 0.7) * (e.radius + 1.0)
					RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(CYAN if i % 2 == 0 else WHITE, 0.85))
		if e.stacks >= 2 and sim.charge_step > 0.0:
			for i in e.stacks:  # 쌓인 전하: 적 위쪽 가로 점 줄
				RunSprites.rect(ci, Rect2(c + Vector2(-e.stacks + i * 2, -e.radius - 4.0), Vector2.ONE), CYAN if i < e.stacks - 1 else WHITE)


## 과충전 방전 충전: 우주선 둘레를 도는 불꽃 점이 전하만큼 늘고, 거의 차면 빨라지며 흰빛
func _draw_coil_charge(ci: CanvasItem) -> void:
	var k := float(sim.subs.coil_charge) / Balance.EVO_COIL_CHARGE
	var n := ceili(k * int(Juice.EVO_FX["charge_sparks"]))
	var c := sim.player_pos.round()
	var spin := 3.0 + 6.0 * k
	for i in n:
		var at := c + Vector2.from_angle(-_time * spin + TAU * i / int(Juice.EVO_FX["charge_sparks"])) * 15.0
		RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(WHITE if k > 0.8 and i % 2 == 0 else CYAN, 0.9))


## 과충전 방전: 우주선에서 맞은 적들로 굵은 번개 여러 갈래 + 가운데 흰 번쩍 + 범위로 퍼지는 청록 점 안개 (경계선 없음)
func _draw_discharge(ci: CanvasItem, d: Dictionary) -> void:
	var k: float = d["t"] / float(d["life"])
	var a := 1.0 - k
	var c: Vector2 = (d["pos"] as Vector2).round()
	if k < 0.2:
		RunSprites.disc(ci, c, 12.0 * (1.0 - k / 0.2) + 3.0, Color(WHITE, 0.9))
	var r: float = float(d["radius"]) * minf(k * 2.5, 1.0)
	_haze(ci, c, r, 16.0, Color(CYAN, 0.7 * a), d["seed"])
	for path: PackedVector2Array in d["paths"]:
		for i in path.size() - 1:
			var p0 := path[i].round()
			var p1 := path[i + 1].round()
			RunSprites.line(ci, p0, p1, Color(TEAL, 0.3 * a), 5.0)
			RunSprites.line(ci, p0, p1, Color(WHITE, a), 2.0)


# ── 5b단계 진화 그리기 (2026-11-13 사용자 결정: 판 흐름이 바뀌는 새 동작) ─────────────

## 연소 기뢰선 도미노: 터진 기뢰에서 다음 기뢰로 선을 따라 달려가는 불길 (흰·금 머리 + 주황 꼬리), 닿은 뒤 짧게 남는다
func _draw_fuse(ci: CanvasItem, fu: Dictionary) -> void:
	var from: Vector2 = fu["from"]
	var to: Vector2 = fu["to"]
	var u := minf(float(fu["t"]) / Balance.EVO_MINE_DOMINO, 1.0)
	var a := 1.0 if u < 1.0 else 1.0 - (float(fu["t"]) - Balance.EVO_MINE_DOMINO) / float(Juice.EVO_FX["fuse_after"])
	var head := from.lerp(to, u)
	RunSprites.line(ci, from.round(), head.round(), Color(EMBER, 0.6 * a), 3.0)
	RunSprites.line(ci, from.round(), head.round(), Color(GOLD, 0.8 * a), 1.0)
	var dir := (to - from).normalized()
	for i in 4:  # 머리 뒤로 튀는 불티
		var at := head - dir * (2.0 + i * 3.0) + dir.orthogonal() * (_h(i, int(_time * 30.0)) - 0.5) * 5.0
		RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color([WHITE, GOLD, ORANGE, EMBER][i], a))
	RunSprites.rect(ci, Rect2(head.round() - Vector2.ONE, Vector2(3, 3)), Color(GOLD, a))
	RunSprites.rect(ci, Rect2(head.round(), Vector2.ONE), Color(WHITE, a))


## 불바다: 바닥에 일렁이는 주황 불꽃. 경계선 없이 옅은 바탕 + 가운데 많고 바깥에 적은 불꽃 기둥(아래 붉고 위 금빛) + 위로 뜨는 불티
func _draw_pool(ci: CanvasItem, pl: Dictionary) -> void:
	var t: float = pl["t"]
	var a := minf(t / 0.15, 1.0) * minf((Balance.EVO_POOL_TIME - t) / 0.5, 1.0)
	var c: Vector2 = pl["pos"]
	var r: float = pl["radius"]
	var sd := int(c.x) * 7 + int(c.y) * 13
	_soft_disc(ci, c.round(), r, Color(EMBER, 0.16 * a), 4)
	var n := int(Juice.EVO_FX["pool_flames"])
	for i in n:
		var d := sqrt(_h(sd, i)) * r * 0.9
		var base := c + Vector2.from_angle(_h(sd, i + 50) * TAU) * d
		var flick := 0.5 + 0.5 * sin(_time * (9.0 + 5.0 * _h(sd, i + 90)) + i * 1.7)
		var tall := roundi((1.0 - d / r) * 4.0 * flick + 1.0)  # 가운데일수록 높게 일렁인다
		for j in tall:
			var col: Color = EMBER if j == 0 else (ORANGE if j < 2 else (GOLD if j < 4 else WHITE))
			RunSprites.rect(ci, Rect2((base + Vector2(0, -j)).round(), Vector2.ONE), Color(col, 0.9 * a))
	for i in 3:  # 불티
		var u := fposmod(_time * 0.9 + _h(sd, i + 200), 1.0)
		var at := c + Vector2((_h(sd, i + 300) - 0.5) * r * 1.2, -u * 12.0)
		RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), Color(GOLD if i % 2 == 0 else ORANGE, a * (1.0 - u)))


## 운석마다 고정된 seed (균열·가시 자리가 프레임마다 바뀌지 않게)
static func _sd(e: RunSim.Enemy) -> int:
	return e.get_instance_id() % 997


## 표시된 지 얼마나 됐는지 0~1 (delay초 뒤부터 grow초 동안)
func _grown(e: RunSim.Enemy, delay: float, grow: float) -> float:
	return clampf((sim.time - e.res_mark_at - delay) / grow, 0.0, 1.0)


## 공명 표시가 붙은 운석 (후보마다): 1 균열이 표면에 쫙 퍼짐 / 2 좌우로 떨며 잔상·떨림 줄 + 점점 금빛으로 달아오름 / 3 금빛 결정 가시가 자라남
func _draw_marks(ci: CanvasItem, sw: Dictionary) -> void:
	var fx := Juice.RES_FX
	for m: Dictionary in sw["marks"]:
		var e: RunSim.Enemy = m["e"]
		var sd := _sd(e)
		var rr := e.radius
		match res_style:
			1:
				var g := _grown(e, 0.0, float(fx["grow"]))
				var c := e.pos.round()
				_soft_disc(ci, c, rr + 2.0, Color(GOLD, 0.25), 3)
				for i in 6:  # 가운데에서 바깥으로 두 번 꺾이며 퍼지는 금
					var ang := TAU * (i + _h(sd, i) * 0.6) / 6.0
					var mid := c + Vector2.from_angle(ang) * rr * 0.5 * g + Vector2.from_angle(ang + PI / 2.0) * (2.0 * _h(sd, i + 10) - 1.0) * 2.0
					var end := c + Vector2.from_angle(ang + 0.35 * (_h(sd, i + 20) - 0.5)) * (rr + 1.0) * g
					for seg: Array in [[c, mid], [mid, end]]:
						RunSprites.line(ci, (seg[0] as Vector2).round(), (seg[1] as Vector2).round(), Color(GOLD, 0.55), 3.0)
						RunSprites.line(ci, (seg[0] as Vector2).round(), (seg[1] as Vector2).round(), WHITE, 1.0)
			2:
				var heat := _grown(e, 0.0, float(fx["heat"]))
				var shake := WorldView.res_shake(e, sim.time)
				var c := (e.pos + shake).round()
				# 잔상: 반대쪽으로 흔들린 자리에 금빛 운석 그림이 옅게 남는다
				RunSprites.draw(ci, RunSprites.rock(e.type, e.golden), WorldView.crack_level(e.hp, e.max_hp), WorldView.rock_dir(e), (e.pos - shake).round(), Color(GOLD, 0.35))
				_soft_disc(ci, c, rr + 2.0, Color(GOLD.lerp(WHITE, 0.3 * heat), 0.3 + 0.6 * heat), 4)
				if heat > 0.6:  # 터지기 직전: 가운데가 하얗게
					RunSprites.disc(ci, c, rr * 0.45, Color(WHITE, (heat - 0.6) * 1.2))
				var flick := 0.6 + 0.4 * signf(sin(_time * 40.0 + sd))
				for sgn: float in [-1.0, 1.0]:  # 떨림 줄 (만화처럼 양옆에 짧은 세로줄 두 겹)
					for j in 2:
						var x := c.x + sgn * (rr + 2.0 + absf(shake.x) + j * 3.0)
						var half := roundf(rr * (0.5 - j * 0.2))
						RunSprites.line(ci, Vector2(x, c.y - half), Vector2(x, c.y + half), Color(GOLD, flick * (0.8 - j * 0.4)), 1.0)
			3:
				var g := _grown(e, float(fx["fly"]), float(fx["grow"]))
				if g <= 0.0:
					continue  # 결정 조각이 아직 날아가는 중
				var c := e.pos.round()
				_soft_disc(ci, c, rr + 2.0, Color(GOLD, 0.2 + 0.2 * g), 3)
				for i in int(fx["spikes"]):  # 표면에서 바깥으로 자라는 결정 가시 (삼각형 + 흰 모서리)
					var dir := Vector2.from_angle(TAU * (i + _h(sd, i) * 0.7) / int(fx["spikes"]))
					var base := c + dir * rr * 0.55
					var tip := (base + dir * (rr * 0.5 + 4.0) * g * (0.7 + 0.3 * _h(sd, i + 40))).round()
					var side := dir.orthogonal() * (1.5 + rr * 0.08)
					ci.draw_colored_polygon(PackedVector2Array([(base + side).round(), tip, (base - side).round()]), GOLD)
					RunSprites.line(ci, (base + side).round(), tip, WHITE, 1.0)
				for i in 3:  # 운석 위 반짝이는 결정 면
					var at := c + Vector2.from_angle(_h(sd, i + 60) * TAU) * rr * 0.35 * _h(sd, i + 70)
					if fposmod(_time * 3.0 + _h(sd, i + 80), 1.0) < 0.5:
						RunSprites.rect(ci, Rect2(at.round(), Vector2.ONE), WHITE)


## 공명 파쇄로 터지는 자리 (후보마다): 1 운석 파편 + 금빛 갈라짐 / 2 흰 번쩍임 + 금빛 파편 / 3 금빛 결정 조각
func _draw_res_pop(ci: CanvasItem, h: Dictionary, k: float) -> void:
	var at0: Vector2 = h["pos"]
	var sd: int = h["seed"]
	var rr0: float = (h["target"] as RunSim.Enemy).radius
	var w := minf(float(h["n"]) / float(Juice.RES_FX["white_at"]), 1.0)
	var bright := GOLD.lerp(WHITE, w)
	var a := 1.0 - k
	match res_style:
		1:
			if k < 0.3:  # 갈라진 금에서 새어 나오는 빛줄기
				for i in 5:
					var dir := Vector2.from_angle(_h(sd, i + 50) * TAU)
					RunSprites.line(ci, at0.round(), (at0 + dir * (rr0 + 6.0)).round(), Color(bright, 1.0 - k / 0.3), 1.0)
			for i in 9:  # 운석 파편: 무거운 2칸 조각과 금빛 부스러기
				var dir := Vector2.from_angle(_h(sd, i) * TAU)
				var at := (at0 + dir * (rr0 * 0.3 + 20.0 * k * (0.5 + _h(sd, i + 30)))).round()
				if i % 3 == 2:
					RunSprites.rect(ci, Rect2(at, Vector2.ONE), Color(bright, a))
				else:
					RunSprites.rect(ci, Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(CHIP if i % 2 == 0 else CHIP_DARK, a))
		2:
			if k < 0.15:
				RunSprites.disc(ci, at0.round(), rr0 * 0.7 * (1.0 + 0.3 * w), Color(WHITE, 0.5 * (1.0 - k / 0.15)))
			_soft_disc(ci, at0.round(), rr0 + 6.0 * k, Color(GOLD, 0.5 * a), 3)
			for i in 8:
				var dir := Vector2.from_angle(_h(sd, i) * TAU)
				var at := (at0 + dir * (rr0 * 0.4 + 22.0 * k * (0.5 + _h(sd, i + 30)))).round()
				RunSprites.rect(ci, Rect2(at, Vector2.ONE * (2.0 if i % 4 == 0 else 1.0)), Color([bright, CHIP, GOLD][i % 3], a))
		3:
			if k < 0.25:
				RunSprites.disc(ci, at0.round(), rr0 * (1.0 - k * 2.0) * (1.0 + 0.4 * w), Color(WHITE, 0.6 + 0.3 * w))
			for i in int(Juice.EVO_FX["shatter_bits"]):
				var dir := Vector2.from_angle(_h(sd, i) * TAU)
				var at := (at0 + dir * (rr0 * 0.4 + 24.0 * k * (0.5 + _h(sd, i + 30)))).round()
				if i % 3 == 0:  # 결정: 마름모 (가운데 흰 점)
					for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
						RunSprites.rect(ci, Rect2(at + d, Vector2.ONE), Color(bright, a))
					RunSprites.rect(ci, Rect2(at, Vector2.ONE), Color(WHITE, a))
				else:
					RunSprites.rect(ci, Rect2(at, Vector2.ONE), Color([bright, GOLD.lerp(WHITE, w * 0.5)][i % 2], a))


## 후보 1 균열: 우주선(또는 터진 운석)에서 다음 운석까지 번개처럼 꺾인 금빛 균열이 vein_grow초 동안 뻗고, 다 뻗으면 잔가지가 갈라진다
func _draw_crack(ci: CanvasItem, cr: Dictionary) -> void:
	var k: float = cr["t"] / float(cr["life"])
	var path: PackedVector2Array = cr["path"]
	var reach := minf(float(cr["t"]) / float(Juice.RES_FX["vein_grow"]), 1.0) * (path.size() - 1)
	for i in path.size() - 1:
		if i >= reach:
			break
		var growing := i + 1 > reach
		var b := path[i].lerp(path[i + 1], reach - i) if growing else path[i + 1]
		RunSprites.line(ci, path[i].round(), b.round(), Color(GOLD, 0.6 * (1.0 - k)), 3.0)
		RunSprites.line(ci, path[i].round(), b.round(), Color(WHITE, 1.0 - k), 1.0)
		if growing:
			RunSprites.rect(ci, Rect2(b.round() - Vector2.ONE, Vector2(2, 2)), WHITE)
	if reach >= path.size() - 1:
		for br: PackedVector2Array in cr["branches"]:
			for i in br.size() - 1:
				RunSprites.line(ci, br[i].round(), br[i + 1].round(), Color(GOLD, 1.0 - k), 1.0)


## 후보 2 진동: 앞에 터진 운석에서 다음 운석으로 이어지는 음파 점선 (점이 물결처럼 옆으로 흔들리며 앞으로 흐른다)
func _draw_sonar(ci: CanvasItem, v: Dictionary) -> void:
	var k: float = v["t"] / float(v["life"])
	var from: Vector2 = v["from"]
	var to: Vector2 = v["to"]
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var dir := (to - from) / length
	var side := dir.orthogonal()
	var gap := float(Juice.RES_FX["dot_gap"])
	var reach := minf(float(v["t"]) / float(Juice.RES_FX["vein_grow"]), 1.0) * length
	var col := GOLD.lerp(WHITE, 0.3 + 0.7 * minf(float(v["n"]) / float(Juice.RES_FX["white_at"]), 1.0))
	var head := fposmod(float(v["t"]) * 3.0, 1.0) * length  # 앞으로 흐르는 밝은 마디
	var d := 0.0
	var i := 0
	while d <= reach:
		var at := from + dir * d + side * roundf(sin(i * 1.3 - float(v["t"]) * 30.0) * 1.5)
		var near := absf(d - head) < gap * 1.5
		RunSprites.rect(ci, Rect2(at.round() - Vector2.ONE, Vector2(2, 2)) if near else Rect2(at.round(), Vector2.ONE * 2.0), Color(WHITE if near else col, 1.0 - k))
		d += gap
		i += 1


## 후보 3 결정화: 터진 운석(또는 우주선)에서 다음 운석으로 날아가 박히는 금빛 결정 조각 (마름모 + 짧은 꼬리)
func _draw_flight(ci: CanvasItem, fl: Dictionary) -> void:
	var target: RunSim.Enemy = fl["target"]
	var from: Vector2 = fl["from"]
	var u := float(fl["t"]) / float(fl["life"])
	var at := from.lerp(target.pos, u).round()
	var dir := (target.pos - from).normalized()
	RunSprites.line(ci, (at - dir * 10.0).round(), at, Color(GOLD, 0.6), 2.0)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		RunSprites.rect(ci, Rect2(at + d, Vector2.ONE), GOLD)
		RunSprites.rect(ci, Rect2(at + d * 2.0, Vector2.ONE), Color(GOLD, 0.6))
	RunSprites.rect(ci, Rect2(at, Vector2.ONE), WHITE)


## 얼음 조각: 날아가는 방향으로 짧은 청백 막대 (흰 머리)
func _draw_shard(ci: CanvasItem, sh: Dictionary) -> void:
	var pos: Vector2 = sh["pos"]
	var dir := (sh["vel"] as Vector2).normalized()
	var a := 1.0 - float(sh["t"]) / Balance.EVO_SHARD_LIFE * 0.5
	RunSprites.line(ci, (pos - dir * 5.0).round(), pos.round(), Color(CYAN, 0.8 * a), 2.0)
	RunSprites.rect(ci, Rect2(pos.round() - Vector2.ONE, Vector2(2, 2)), Color(WHITE, a))
