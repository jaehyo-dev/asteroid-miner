extends SceneTree
## v0.8.0 5b단계 허수아비 피해 측정 (게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --headless --path . -s $PWD/review/v080_step5b/bot_dummy.gd -- <출력.md>
## 표 A = 5단계 표 4와 같은 방법: 체력이 아주 많은 황금 운석 12개(부서지지 않음)를 우주선 30~110 거리에 두고, 우주선은 반지름 약 50으로 돈다. 20초 피해 합, 시드 1~10 평균.
## 표 B = 운석밭: 3:00 체력의 작은·중간·큰 운석 30개(3:2:1)를 40~150 거리에 두고, 부서지면 같은 범위에 새로 놓는다. 20초 동안 깎은 체력 합(부서진 운석은 최대 체력만큼)과 부순 수.
##   공명 파쇄의 "부서진 운석이 다시 파동"과 회전 충각의 "작은·중간 운석 한 번에"는 부서지는 운석이 있어야 보여서 따로 잰다.
## 적 등장·기본 무기 없음. 탄 피해 1 = 표에서 100.

const SEEDS := 10
const TIME := 20.0
const STEP := 1.0 / 30.0
## 운석밭 운석 체력: 3:00 체력(기본의 3배). 7:00 체력(약 28배)은 그때 쌓였을 공격력 강화 없이 재면 너무 단단해서,
## 공격력이 2~3배 오른 7:00쯤과 비슷한 3:00 체력으로 둔다
const FIELD_AT := 180.0


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "bot_dummy.md"
	var lines: PackedStringArray = []
	for field in [false, true]:
		lines.append("## 표 %s. %s" % ["B" if field else "A", "운석밭 (부서지는 3:00 체력 운석 30개, 깎은 체력 합)" if field else "허수아비 (부서지지 않는 황금 운석 12개, 피해 합)"])
		lines.append("")
		lines.append("| 보조 무기 → 진화 | 5단계 + 짝 스킬 | 진화 | 배율 |" + (" 부순 수 (5단계 → 진화) |" if field else ""))
		lines.append("|---|---|---|---|" + ("---|" if field else ""))
		for id in SubWeapons.ids():
			var dmg := [0.0, 0.0]
			var kills := [0.0, 0.0]
			for evolved in 2:
				for sd in range(1, SEEDS + 1):
					var r := _run(id, evolved == 1, sd, field)
					dmg[evolved] += r[0] / SEEDS
					kills[evolved] += float(r[1]) / SEEDS
			lines.append("| %s → %s | %.0f | %.0f | ×%.2f |" % [SubWeapons.info(id)["name"], SubWeapons.evo_of(id)["name"], dmg[0] * 100.0, dmg[1] * 100.0, dmg[1] / maxf(dmg[0], 0.001)]
				+ (" %.1f → %.1f |" % kills if field else ""))
			print(id, " ", "B" if field else "A", " ×%.2f" % (dmg[1] / maxf(dmg[0], 0.001)))
		lines.append("")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit(0)


func _rock(sim: RunSim, rng: RandomNumberGenerator, field: bool) -> RunSim.Enemy:
	var a := RunSim.Enemy.new()
	if field:
		var roll := rng.randi_range(0, 5)
		a.type = 0 if roll < 3 else (1 if roll < 5 else 2)
		a.max_hp = RunSim.asteroid_hp(float(Balance.ASTEROID_TYPES[a.type]["hp"]), FIELD_AT)
	else:
		a.type = 1
		a.max_hp = 1.0e6
		a.golden = true  # 공명 파쇄·충각이 한 번에 부수지 않게 (피해만 잰다)
	a.radius = Balance.ASTEROID_TYPES[a.type]["radius"]
	a.hp = a.max_hp
	a.pos = Vector2.from_angle(rng.randf() * TAU) * (rng.randf_range(40.0, 150.0) if field else rng.randf_range(30.0, 110.0))
	sim.enemies.append(a)
	return a


## [준 피해 합(탄 피해로 나눈 값), 부순 수]
func _run(id: String, evolved: bool, sd: int, field: bool) -> Array:
	var sim := RunSim.new(sd)
	for t in ["_spawn_timer", "_golden_timer", "_barrage_timer", "_jelly_timer", "_bug_timer", "_guard_timer"]:
		sim.set(t, 1.0e9)
	sim.raid.timer = 1.0e9
	sim.invuln = 1.0e9
	sim.run_during_levelup = true  # 운석밭에서 광물을 주워 레벨업해도 멈추지 않게 (카드는 고르지 않음)
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
	var count := 30 if field else 12
	for i in count:
		_rock(sim, rng, field)
	var done := 0.0
	var kills := 0
	var t := 0.0
	while t < TIME:
		var move := Vector2.from_angle(t * 1.6 + PI / 2.0)  # 반지름 약 50의 원
		sim.update(STEP, move)
		t += STEP
		for a in sim.destroyed:
			done += a.max_hp
			kills += 1
			if field:
				_rock(sim, rng, field)
	for e in sim.enemies:
		done += e.max_hp - maxf(e.hp, 0.0)
	return [done / sim.bullet_damage, kills]
