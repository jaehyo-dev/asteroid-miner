extends SceneTree
## 밸런스 비교표 (테스트가 아니라 수치를 바꾸기 전후를 비교하는 도구).
## 실행: godot --headless --path . -s res://tests/balance_report.gd
## 봇 4종(collector·flee·wander·returner) × 시드 100개를 최대 10분까지 돌려 한 판 길이, 사망률(10분 안·2분 안), 광물 획득량, 최종 레벨,
## 귀환율, 귀환 시점(귀환한 판의 평균 시각), 가져간 가치(파괴되면 보존분, 위험도 배율 포함) 평균을 찍는다.

const STYLES := ["collector", "flee", "wander", "returner"]
const MAX_TIME := 600.0


func _init() -> void:
	var seeds := range(1, 101)
	print("| 봇 | 한 판 길이(초) | 사망률(10분 안) | 2분 안 사망률 | 광물 가치 | 최종 레벨 | 귀환율 | 귀환 시점(초) | 가져간 가치 |")
	print("|---|---|---|---|---|---|---|---|---|")
	for style in STYLES:
		var total_time := 0.0
		var deaths := 0
		var value := 0.0
		var early := 0
		var levels := 0.0
		var returns := 0
		var return_time := 0.0
		var home := 0.0
		for s in seeds:
			var r := BalanceBot.play(style, s, MAX_TIME)
			total_time += r["time"]
			value += r["value"]
			levels += r["level"]
			home += r["home"]
			if r["returned"]:
				returns += 1
				return_time += r["time"]
			if not r["alive"]:
				deaths += 1
				if r["time"] < 120.0:
					early += 1
		var n := float(seeds.size())
		var avg_return := "%.1f" % (return_time / returns) if returns > 0 else "-"
		print("| %s | %.1f | %d%% | %d%% | %.0f | %.1f | %d%% | %s | %.0f |" % [style, total_time / n, roundi(deaths * 100.0 / n), roundi(early * 100.0 / n), value / n, levels / n, roundi(returns * 100.0 / n), avg_return, home / n])
	# 레벨업 속도 테스트(test_balance.gd)와 같은 24판: 4분까지 살아남은 판 수와 2분·4분 평균 레벨
	var level_seeds := range(1000, 1024)
	var alive := 0
	for s in level_seeds:
		if BalanceBot.play("collector", s, 240.0)["alive"]:
			alive += 1
	var lv := BalanceBot.average_levels("collector", level_seeds, [120.0, 240.0])
	print("collector 4분 생존 %d/24, 평균 레벨 2분 %.1f · 4분 %.1f" % [alive, lv[0], lv[1]])
	quit(0)
