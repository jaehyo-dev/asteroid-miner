class_name BalanceBot
extends RefCounted
## 밸런스 확인용 자동 플레이 봇 (테스트 전용, 게임에는 포함되지 않음).
## 강화는 무작위로 고르고, 움직이는 방식만 다르다.
##   still: 가만히 있음 / wander: 2초마다 무작위 방향으로 돌아다님 / flee: 가까운 운석 반대로 피함
##   collector: 가까운 운석은 피하고, 아니면 가장 가까운 광물을 주우러 감 (보통 플레이어에 가장 가까움)

const STEP := 1.0 / 30.0


## 한 판을 끝까지(또는 max_time까지) 돌리고 {time, level, value, alive}를 돌려준다.
static func play(style: String, seed_value: int, max_time: float) -> Dictionary:
	var sim := RunSim.new(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var move := Vector2.ZERO
	var turn := 0.0
	while sim.alive and sim.time < max_time:
		if not sim.choices.is_empty():
			sim.choose(rng.randi_range(0, sim.choices.size() - 1))
			continue
		match style:
			"wander":
				turn -= STEP
				if turn <= 0.0:
					turn = 2.0
					move = Vector2.from_angle(rng.randf() * TAU)
			"collector":
				var danger := RunSim.nearest_asteroid(sim.player_pos, sim.asteroids, 45.0)
				if danger != null:
					move = (sim.player_pos - danger.pos).normalized()
				else:
					move = Vector2.ZERO
					var best := 260.0
					for m in sim.minerals:
						var d := m.pos.distance_to(sim.player_pos)
						if d < best:
							best = d
							move = (m.pos - sim.player_pos).normalized()
			"flee":
				var near := RunSim.nearest_asteroid(sim.player_pos, sim.asteroids, 80.0)
				move = (sim.player_pos - near.pos).normalized() if near != null else Vector2.ZERO
			_:
				move = Vector2.ZERO
		sim.update(STEP, move)
	return {"time": sim.time, "level": sim.level, "value": sim.mineral_value, "alive": sim.alive}


## 정해진 시각마다의 평균 레벨 (레벨업 속도 확인용).
## 그 시각까지 살아 있는 판만 평균한다 (일찍 끝난 판의 레벨이 섞이면 속도가 아니라 생존을 재게 됨).
## 살아 있는 판이 절반보다 적으면 그 시각은 -1.
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
		result.append(total / alive if alive * 2 >= seeds.size() else -1.0)
	return result
## 여러 판의 생존 시간 [최소, 중앙값, 최대]
static func survival_stats(style: String, seeds: Array, max_time: float) -> Array[float]:
	var times: Array[float] = []
	for s in seeds:
		times.append(float(play(style, s, max_time)["time"]))
	times.sort()
	return [times[0], times[times.size() / 2], times[times.size() - 1]]
