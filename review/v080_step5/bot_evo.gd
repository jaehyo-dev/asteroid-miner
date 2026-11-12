extends SceneTree
## v0.8.0 5단계 진화 봇 측정 (게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --headless --path . -s $PWD/review/v080_step5/bot_evo.gd -- <출력.md>
## collector 봇(귀환 안 함), 펄스 연사포, 시드 1~30, 기지 업그레이드 없음, 지금 곡선 그대로. 수치는 바꾸지 않고 재기만 한다.
## 표 1 (10분까지): "sub:<무기>" 그 보조 무기만 우선 vs "evo:<무기>" 진화 카드 → 보조 무기 → 짝 스킬 우선.
## 표 2 (3분, ?fxtest처럼 처음부터): 보조 무기 5단계 + 짝 스킬(진화 안 함) vs 진화. 나머지 카드는 보조 무기가 아닌 것 중 무작위.

const SEEDS := 30


func _row(pick: String, max_time: float, setup := Callable()) -> Dictionary:
	var sum := {"time": 0.0, "death": 0.0, "kills": 0.0, "count": 0.0, "evo": 0.0, "evo_at": 0.0, "stage": 0.0}
	for s in range(1, SEEDS + 1):
		var r := BalanceBot.play("collector", s, max_time, {}, pick, "pulse", setup)
		sum["time"] += r["time"]
		sum["death"] += 0.0 if r["alive"] else 1.0
		sum["kills"] += r["kills"]
		for c in r["collected"]:
			sum["count"] += c
		if float(r["evolved_at"]) >= 0.0:
			sum["evo"] += 1.0
			sum["evo_at"] += r["evolved_at"]
		sum["stage"] += int(r["picks"].get(pick.substr(4), 0))
	sum["evo_at"] = sum["evo_at"] / sum["evo"] if sum["evo"] > 0.0 else -1.0
	for k in ["time", "death", "kills", "count", "evo", "stage"]:
		sum[k] /= float(SEEDS)
	return sum


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var lines := PackedStringArray()
	lines.append("## 표 1. 진화를 만드는 판 (최대 10분, 30판)")
	lines.append("")
	lines.append("| 보조 무기 | 고르는 방식 | 진화한 판 | 평균 진화 시각 | 평균 최종 단계 | 평균 생존(초) | 사망률 | 처치 | 주운 광물 |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for id in SubWeapons.ids():
		for pick in ["sub:" + id, "evo:" + id]:
			var t0 := Time.get_ticks_msec()
			var r := _row(pick, 600.0)
			var at := "-" if r["evo_at"] < 0.0 else "%d:%02d" % [int(r["evo_at"]) / 60, int(r["evo_at"]) % 60]
			lines.append("| %s | %s | %d%% | %s | %.1f | %.1f | %d%% | %.0f | %.1f |" % [SubWeapons.info(id)["name"], "보조 무기만" if pick.begins_with("sub") else "진화 우선 (+ 짝 스킬)", roundi(r["evo"] * 100.0), at, r["stage"], r["time"], roundi(r["death"] * 100.0), r["kills"], r["count"]])
			print(pick, " ", Time.get_ticks_msec() - t0, "ms")
	lines.append("")
	lines.append("## 표 2. 처음부터 5단계 + 짝 스킬 vs 진화 (3분, 30판)")
	lines.append("")
	lines.append("| 보조 무기 → 진화 | 5단계 처치 | 진화 처치 | 처치 변화 | 5단계 광물 | 진화 광물 | 광물 변화 | 5단계 사망률 | 진화 사망률 |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for id in SubWeapons.ids():
		var e := SubWeapons.evo_of(id)
		var five := func(sim: RunSim) -> void:
			for i in 5:
				sim.apply_pick(id, 0)
			sim.apply_pick(e["skill"], Upgrades.EPIC)
		var evo := func(sim: RunSim) -> void:
			sim.fx_evolve(id)
		var a := _row("nosub", 180.0, five)
		var b := _row("nosub", 180.0, evo)
		lines.append("| %s → %s | %.0f | %.0f | %+.0f%% | %.1f | %.1f | %+.0f%% | %d%% | %d%% |" % [SubWeapons.info(id)["name"], e["name"], a["kills"], b["kills"], (b["kills"] / maxf(a["kills"], 1.0) - 1.0) * 100.0, a["count"], b["count"], (b["count"] / maxf(a["count"], 1.0) - 1.0) * 100.0, roundi(a["death"] * 100.0), roundi(b["death"] * 100.0)])
		print(id, " 3분")
	lines.append("")
	lines.append("## 표 3. 표 2와 같은데 기본 무기를 끈 판 (보조 무기만 싸움, 3분, 30판)")
	lines.append("")
	lines.append("| 보조 무기 → 진화 | 5단계 처치 | 진화 처치 | 처치 변화 | 5단계 생존(초) | 진화 생존(초) | 5단계 사망률 | 진화 사망률 |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for id in SubWeapons.ids():
		var e := SubWeapons.evo_of(id)
		var off := func(sim: RunSim) -> void:  # 기본 무기 사거리 0: 쏘지 않는다
			sim.weapon = sim.weapon.duplicate()
			sim.weapon["range"] = 0.0
		var five := func(sim: RunSim) -> void:
			off.call(sim)
			for i in 5:
				sim.apply_pick(id, 0)
			sim.apply_pick(e["skill"], Upgrades.EPIC)
		var evo := func(sim: RunSim) -> void:
			off.call(sim)
			sim.fx_evolve(id)
		var a := _row("nosub", 180.0, five)
		var b := _row("nosub", 180.0, evo)
		lines.append("| %s → %s | %.0f | %.0f | %+.0f%% | %.0f | %.0f | %d%% | %d%% |" % [SubWeapons.info(id)["name"], e["name"], a["kills"], b["kills"], (b["kills"] / maxf(a["kills"], 1.0) - 1.0) * 100.0, a["time"], b["time"], roundi(a["death"] * 100.0), roundi(b["death"] * 100.0)])
		print(id, " 기본 무기 없이")
	lines.append("")
	lines.append("## 표 4. 허수아비 피해 측정 (20초, 시드 1~10 평균): 체력이 아주 많은 운석 12개를 우주선 30~110 거리에 두고 우주선은 반지름 50으로 돈다. 적 등장·기본 무기 없음")
	lines.append("")
	lines.append("| 보조 무기 → 진화 | 5단계 + 짝 스킬 피해 | 진화 피해 | 배율 |")
	lines.append("|---|---|---|---|")
	for id in SubWeapons.ids():
		var dmg := [0.0, 0.0]
		for evolved in 2:
			for sd in range(1, 11):
				dmg[evolved] += _dummy(id, evolved == 1, sd) / 10.0
		lines.append("| %s → %s | %.0f | %.0f | ×%.2f |" % [SubWeapons.info(id)["name"], SubWeapons.evo_of(id)["name"], dmg[0] * 100.0, dmg[1] * 100.0, dmg[1] / maxf(dmg[0], 0.001)])
		print(id, " 허수아비")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit(0)


## 허수아비 판: 준 피해 합 (탄 피해 1 = 표에서 100)
func _dummy(id: String, evolved: bool, sd: int) -> float:
	var sim := RunSim.new(sd)
	for t in ["_spawn_timer", "_golden_timer", "_barrage_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
		sim.set(t, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.invuln = 1.0e9
	sim.weapon = sim.weapon.duplicate()
	sim.weapon["range"] = 0.0
	sim.apply_upgrades()
	if evolved:
		sim.fx_evolve(id)
	else:
		for i in 5:
			sim.apply_pick(id, 0)
		sim.apply_pick(SubWeapons.evo_of(id)["skill"], Upgrades.EPIC)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var total := 12.0e6
	for i in 12:
		var a := RunSim.Enemy.new()
		a.type = 1
		a.radius = Balance.ASTEROID_TYPES[1]["radius"]
		a.max_hp = 1.0e6
		a.hp = 1.0e6
		a.golden = true  # 공명 파쇄·충각이 한 번에 부수지 않게 (피해만 잰다)
		a.pos = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 110.0)
		sim.enemies.append(a)
	var t := 0.0
	while t < 20.0:
		var move := Vector2.from_angle(t * 1.6 + PI / 2.0)  # 반지름 약 50의 원
		sim.update(1.0 / 30.0, move)
		t += 1.0 / 30.0
	var left := 0.0
	for e in sim.enemies:
		left += e.hp
	return (total - left - (12 - sim.enemies.size()) * 0.0) / sim.bullet_damage
