extends SceneTree
## v0.8.0 2단계 무기별 봇 측정 (게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --headless --path . -s $PWD/review/v080_step2/bot_weapons.gd -- <출력.md>
## collector 봇(가까운 운석 피하고 가장 가까운 광물 주우러 감, 귀환 안 함), 카드는 무작위, 시드 1~30, 최대 10분, 지금(5분 판) 곡선 그대로.
## 기지 업그레이드 없음 (모든 무기 같은 조건). 무기 수치는 Balance.WEAPONS.

const SEEDS := 30
const MAX_TIME := 600.0


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var rows := []
	for id in Weapons.ids():
		var t := 0.0
		var deaths := 0
		var kills := 0.0
		var count := 0.0
		var value := 0.0
		var home := 0.0
		var level := 0.0
		var t0 := Time.get_ticks_msec()
		for s in range(1, SEEDS + 1):
			var r := BalanceBot.play("collector", s, MAX_TIME, {}, "random", id)
			t += r["time"]
			deaths += 0 if r["alive"] else 1
			kills += r["kills"]
			for c in r["collected"]:
				count += c
			value += r["value"]
			home += r["home"]
			level += r["level"]
		var n := float(SEEDS)
		rows.append({"id": id, "name": Weapons.info(id)["name"], "time": t / n, "death": deaths / n, "kills": kills / n, "count": count / n, "value": value / n, "home": home / n, "level": level / n})
		print("%s %.1f초 (%d ms)" % [id, t / n, Time.get_ticks_msec() - t0])
	var lines := PackedStringArray()
	lines.append("| 무기 | 평균 생존(초) | 사망률 | 처치 수 | 주운 광물(개) | 광물 가치 | 가져간 가치(사망 보존) | 최종 레벨 |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for r in rows:
		lines.append("| %s | %.1f | %d%% | %.0f | %.1f | %.0f | %.0f | %.1f |" % [r["name"], r["time"], roundi(r["death"] * 100.0), r["kills"], r["count"], r["value"], r["home"], r["level"]])
	# 다른 무기 평균보다 15% 넘게 좋거나 나쁜 칸 (같은 무기를 뺀 4개 평균과 비교)
	lines.append("")
	lines.append("15% 넘게 벗어난 값 (그 무기를 뺀 나머지 4개 평균 대비):")
	for key in ["time", "kills", "count", "home"]:
		for r in rows:
			var others := 0.0
			for o in rows:
				if o != r:
					others += o[key]
			others /= rows.size() - 1
			var diff: float = (r[key] - others) / maxf(others, 0.001)
			if absf(diff) > 0.15:
				lines.append("- %s %s: %+.0f%%" % [r["name"], {"time": "생존", "kills": "처치", "count": "주운 광물", "home": "가져간 가치"}[key], diff * 100.0])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit(0)
