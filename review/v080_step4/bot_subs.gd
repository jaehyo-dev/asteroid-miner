extends SceneTree
## v0.8.0 4단계 보조 무기별 봇 측정 (게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --headless --path . -s $PWD/review/v080_step4/bot_subs.gd -- <출력.md>
## collector 봇(가까운 운석 피하고 가장 가까운 광물 주우러 감, 귀환 안 함), 기본 무기 펄스 연사포, 시드 1~30, 최대 10분, 지금 곡선 그대로.
## "보조 무기 우선": 그 보조 무기 카드가 나오면 항상 고르고, 없으면 보조 무기가 아닌 카드 중 무작위 (BalanceBot.sub_choice).
## 비교 기준으로 "보조 무기 안 고름"(nosub) 줄도 잰다. 기지 업그레이드 없음.

const SEEDS := 30
const MAX_TIME := 600.0


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var rows := []
	var picks: Array[String] = ["nosub"]
	for id in SubWeapons.ids():
		picks.append("sub:" + id)
	for pick in picks:
		var sum := {"time": 0.0, "death": 0.0, "kills": 0.0, "count": 0.0, "home": 0.0, "level": 0.0, "stage": 0.0, "got": 0.0}
		var t0 := Time.get_ticks_msec()
		for s in range(1, SEEDS + 1):
			var r := BalanceBot.play("collector", s, MAX_TIME, {}, pick, "pulse")
			sum["time"] += r["time"]
			sum["death"] += 0.0 if r["alive"] else 1.0
			sum["kills"] += r["kills"]
			for c in r["collected"]:
				sum["count"] += c
			sum["home"] += r["home"]
			sum["level"] += r["level"]
			if pick != "nosub":
				var st := int(r["picks"].get(pick.substr(4), 0))
				sum["stage"] += st
				sum["got"] += 1.0 if st > 0 else 0.0
		for k in sum:
			sum[k] /= float(SEEDS)
		sum["pick"] = pick
		sum["name"] = "보조 무기 안 고름 (기준)" if pick == "nosub" else SubWeapons.info(pick.substr(4))["name"]
		rows.append(sum)
		print("%s %.1f초 (%d ms)" % [pick, sum["time"], Time.get_ticks_msec() - t0])
	var lines := PackedStringArray()
	lines.append("| 보조 무기 우선 | 얻은 판 | 평균 최종 단계 | 평균 생존(초) | 사망률 | 처치 수 | 주운 광물(개) | 가져간 가치(사망 보존) | 최종 레벨 |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for r in rows:
		var got := "-" if r["pick"] == "nosub" else "%d%%" % roundi(r["got"] * 100.0)
		var stage := "-" if r["pick"] == "nosub" else "%.1f" % r["stage"]
		lines.append("| %s | %s | %s | %.1f | %d%% | %.0f | %.1f | %.0f | %.1f |" % [r["name"], got, stage, r["time"], roundi(r["death"] * 100.0), r["kills"], r["count"], r["home"], r["level"]])
	# 보조 무기 6종끼리 비교: 그 무기를 뺀 나머지 5개 평균보다 15% 넘게 좋거나 나쁜 칸 (기준 줄은 비교에서 뺌)
	lines.append("")
	lines.append("15% 넘게 벗어난 값 (그 보조 무기를 뺀 나머지 5개 평균 대비):")
	var subs := rows.slice(1)
	var any := false
	for key in ["kills", "count", "time"]:
		for r in subs:
			var others := 0.0
			for o in subs:
				if o != r:
					others += o[key]
			others /= subs.size() - 1
			var diff: float = (r[key] - others) / maxf(others, 0.001)
			if absf(diff) > 0.15:
				any = true
				lines.append("- %s %s: %+.0f%%" % [r["name"], {"time": "생존", "kills": "처치", "count": "주운 광물"}[key], diff * 100.0])
	if not any:
		lines.append("- 없음")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit(0)
