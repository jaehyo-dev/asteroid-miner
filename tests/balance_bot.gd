class_name BalanceBot
extends RefCounted
## 밸런스 확인용 자동 플레이 봇 (테스트 전용, 게임에는 포함되지 않음).
## 강화는 무작위 또는 "가장 좋아 보이는 것"(pick = "best": 등급이 높은 것, 같으면 레전드리·효과 > 수치)으로 고르고, 움직이는 방식만 다르다.
##   still: 가만히 있음 / wander: 2초마다 무작위 방향으로 돌아다님 / flee: 가까운 운석 반대로 피함
##   collector: 가까운 운석은 피하고, 아니면 가장 가까운 광물을 주우러 감 (보통 플레이어에 가장 가까움)
##   returner: collector처럼 줍다가 화물칸이 RETURN_CARGO_RATIO 이상 차거나 체력이 RETURN_HP_RATIO 아래면
##             열린 게이트로 가서 귀환한다 (포격은 계속 피함). 화물 무게 같은 귀환 판단 변화를 잴 때 씀.

const STEP := 1.0 / 30.0
## 심연의 포격 조준선에서 이만큼 안이면 옆으로 피한다 (collector·flee 봇: 예고를 보고 피하는 플레이)
const BARRAGE_DODGE_MARGIN := 16.0
## 적 가운데까지 이 거리 안이면 피한다 (collector / flee). v0.7.0에서 그림·판정이 커진 만큼(반지름 합 약 +7)
## 늘려, 가장자리 사이 거리 기준으로는 예전과 같은 때 피하게 한다 (사람은 그림 가장자리를 보고 피함).
const COLLECTOR_DANGER := 52.0
const FLEE_DANGER := 87.0
## returner 봇이 귀환하기로 하는 화물칸 비율·체력 비율
const RETURN_CARGO_RATIO := 0.6
const RETURN_HP_RATIO := 0.35


## 한 판을 끝까지(또는 max_time까지) 돌리고 {time, level, value, alive}를 돌려준다.
## base: 기지 공용 업그레이드 단계 (id → 단계), weapon: 기본 무기 id (Balance.WEAPONS)
## setup: 판을 시작하기 전에 sim을 바꾸는 함수 (예: 처음부터 진화한 보조 무기, v0.8.0 5단계 봇)
static func play(style: String, seed_value: int, max_time: float, base: Dictionary = {}, pick := "random", weapon := "pulse", setup := Callable()) -> Dictionary:
	var sim := RunSim.new(seed_value)
	sim.apply_base(base)
	sim.set_weapon(weapon)
	if setup.is_valid():
		setup.call(sim)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var move := Vector2.ZERO
	var turn := 0.0
	var levelup_times: Array[float] = []  # 레벨업 강화를 고른 시각 (등급 확률 추정용)
	var evolved_at := -1.0  # 처음 진화한 시각 (-1이면 진화 못 함, 처음부터 진화한 판은 0)
	if not sim.subs.evolved.is_empty():
		evolved_at = 0.0
	while not sim.is_over() and sim.time < max_time:  # 귀환해도 판이 끝난다
		if sim.choosing():
			levelup_times.append(sim.time)
			if sim.choices.is_empty():
				sim.skip()  # 고를 카드가 없으면 건너뛰기 (광물은 금고로)
			else:
				sim.choose(best_choice(sim.choices) if pick == "best" else sub_choice(sim.choices, pick, rng) if pick.begins_with("sub:") or pick.begins_with("evo:") or pick == "nosub" else rng.randi_range(0, sim.choices.size() - 1))
			if evolved_at < 0.0 and not sim.subs.evolved.is_empty():
				evolved_at = sim.time
			continue
		match style:
			"wander":
				turn -= STEP
				if turn <= 0.0:
					turn = 2.0
					move = Vector2.from_angle(rng.randf() * TAU)
			"collector", "returner":
				var heading_home := style == "returner" and sim.gate.state == WarpGate.State.OPEN \
					and (sim.cargo.size() >= sim.cargo.capacity * RETURN_CARGO_RATIO or sim.hp < sim.max_hp * RETURN_HP_RATIO)
				var danger := RunSim.nearest_enemy(sim.player_pos, sim.enemies, COLLECTOR_DANGER)
				var escape := sim.barrage_escape(sim.player_pos, BARRAGE_DODGE_MARGIN)
				if escape != Vector2.ZERO:
					move = escape
				elif danger != null:
					move = (sim.player_pos - danger.pos).normalized()
				elif heading_home:
					move = (sim.gate.pos - sim.player_pos).limit_length(1.0)  # 게이트 안에서는 멈춰 충전
				else:
					move = Vector2.ZERO
					var best := 260.0
					for m in sim.minerals:
						var d := m.pos.distance_to(sim.player_pos)
						if d < best:
							best = d
							move = (m.pos - sim.player_pos).normalized()
			"flee":
				var near := RunSim.nearest_enemy(sim.player_pos, sim.enemies, FLEE_DANGER)
				var escape := sim.barrage_escape(sim.player_pos, BARRAGE_DODGE_MARGIN)
				if escape != Vector2.ZERO:
					move = escape
				else:
					move = (sim.player_pos - near.pos).normalized() if near != null else Vector2.ZERO
			_:
				move = Vector2.ZERO
		sim.update(STEP, move)
	return {"time": sim.time, "level": sim.level, "value": sim.mineral_value, "alive": sim.alive, "returned": sim.returned, "home": sim.final_value(), "levelup_times": levelup_times, "picks": sim.upgrade_levels, "kills": sim.kills, "collected": Array(sim.collected), "evolved_at": evolved_at}


## 보조 무기 측정용 카드 고르기 (v0.8.0 4단계). "sub:<id>": 그 보조 무기 카드가 있으면 그것, 없으면 보조 무기가 아닌 카드 중 무작위
## (다른 보조 무기로 칸을 채우지 않게). "nosub": 보조 무기를 고르지 않음(비교 기준). 고를 것이 없으면 무작위
## "evo:<보조 무기>"는 진화 카드 → 그 보조 무기 → 짝 스킬 순으로 먼저 고른다 (진화를 만드는 판)
static func sub_choice(choices: Array, pick: String, rng: RandomNumberGenerator) -> int:
	var others: Array[int] = []
	var want: Array = []
	if pick.begins_with("sub:"):
		want = [pick.substr(4)]
	elif pick.begins_with("evo:"):
		var e := SubWeapons.evo_of(pick.substr(4))
		want = [e["id"], e["sub"], e["skill"]]
	for id in want:
		for i in choices.size():
			if choices[i]["id"] == id:
				return i
	for i in choices.size():
		if not SubWeapons.is_sub(choices[i]["id"]) and not choices[i].get("evo", false):
			others.append(i)
	if others.is_empty():
		return rng.randi_range(0, choices.size() - 1)
	return others[rng.randi_range(0, others.size() - 1)]


## "가장 좋아 보이는" 카드 번호: 등급이 높은 것, 같으면 효과·레전드리가 수치보다 먼저 (사람이 눈에 띄는 카드를 고르는 플레이)
static func best_choice(choices: Array) -> int:
	var best := 0
	var best_score := -1.0
	for i in choices.size():
		var c: Dictionary = choices[i]
		var score := float(c["grade"]) * 2.0 + (1.0 if Upgrades.is_effect(c["id"]) else 0.0)
		if score > best_score:
			best = i
			best_score = score
	return best


## 정해진 시각마다의 평균 레벨 (레벨업 속도 확인용).
## 그 시각까지 살아 있는 판만 평균한다 (일찍 끝난 판의 레벨이 섞이면 속도가 아니라 생존을 재게 됨).
## 살아 있는 판이 4분의 1보다 적으면 그 시각은 -1 (표본이 너무 적음).
## 귀환하지 않는 collector 봇은 4분에 약 3분의 1만 살아 있다. 기준이 3분의 1이면 맥(8/24)은 통과하고 CI(리눅스, 실수 계산이 조금 달라 7/24)는 떨어져서 4분의 1로 낮춤.
static func average_levels(style: String, seeds: Array, marks: Array) -> Array[float]:
	var result: Array[float] = []
	for t in marks:
		var total := 0.0
		var alive := 0
		for s in seeds:
			var r := play(style, s, t)
			if r["alive"]:
				total += r["level"]
				alive += 1
		result.append(total / alive if alive * 4 >= seeds.size() else -1.0)
	return result


## 여러 판의 생존 시간 [최소, 중앙값, 최대]
static func survival_stats(style: String, seeds: Array, max_time: float, base: Dictionary = {}, pick := "random") -> Array[float]:
	var times: Array[float] = []
	for s in seeds:
		times.append(float(play(style, s, max_time, base, pick)["time"]))
	times.sort()
	return [times[0], times[times.size() / 2], times[times.size() - 1]]
