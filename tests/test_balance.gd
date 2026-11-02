extends TestCase
## 밸런스 시뮬레이션 테스트: 봇이 무작위 강화로 플레이했을 때 한 판 길이와 레벨업 속도 확인.
## GAME_SPEC "한 판 길이 3~5분"을 기준으로, 수치를 바꿔도 크게 벗어나지 않게 지킨다.
## 경험치는 광물을 주워야 얻으므로, 광물을 줍는 봇(collector)이 기준이다.

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007]
## 이 시간 안에는 어떤 봇도 반드시 끝나야 한다 (강화를 쌓아도 끝없이 버틸 수 없음)
const HARD_LIMIT := 600.0
## 움직이는 봇의 한 판 길이 중앙값 허용 범위 (2분 30초 ~ 6분)
const MEDIAN_MIN := 150.0
const MEDIAN_MAX := 360.0
## 이보다 빨리 끝나면 너무 어렵다
const EARLIEST_END := 100.0
## 광물을 줍는 봇의 평균 레벨 허용 범위: 2분, 4분 시점 (v0.1.2 기준 약 7.1, 10.6)
const LEVEL_AT_120 := [6.0, 9.0]
const LEVEL_AT_240 := [9.5, 13.5]


func test_움직이는_플레이는_한_판_길이가_알맞음() -> void:
	for style in ["collector", "flee", "wander"]:
		var st := BalanceBot.survival_stats(style, SEEDS, HARD_LIMIT + 1.0)
		assert_true(st[2] <= HARD_LIMIT, "%s 최대 %.0f초 (10분 안에 끝나야 함)" % [style, st[2]])
		assert_true(st[1] >= MEDIAN_MIN and st[1] <= MEDIAN_MAX, "%s 중앙값 %.0f초" % [style, st[1]])
		assert_true(st[0] >= EARLIEST_END, "%s 최소 %.0f초 (너무 빨리 끝남)" % [style, st[0]])


func test_가만히_있으면_강해지지_못해_일찍_끝나지만_바로_죽지는_않음() -> void:
	var st := BalanceBot.survival_stats("still", SEEDS, HARD_LIMIT + 1.0)
	assert_true(st[2] <= HARD_LIMIT, "최대 %.0f초" % st[2])
	assert_true(st[0] >= EARLIEST_END, "최소 %.0f초" % st[0])
	# 자석 범위 안에 떨어진 광물만 주우므로, 광물을 주우러 다니는 플레이보다 확실히 느리게 성장한다.
	var still_level: int = BalanceBot.play("still", SEEDS[0], 120.0)["level"]
	assert_true(still_level < LEVEL_AT_120[0], "가만히 있으면 2분 레벨 %d" % still_level)


func test_광물을_주우면_레벨업_속도가_알맞음() -> void:
	var levels := BalanceBot.average_levels("collector", SEEDS.slice(0, 6), [120.0, 240.0])
	assert_true(levels[0] >= LEVEL_AT_120[0] and levels[0] <= LEVEL_AT_120[1], "2분 평균 레벨 %.1f" % levels[0])
	assert_true(levels[1] >= LEVEL_AT_240[0] and levels[1] <= LEVEL_AT_240[1], "4분 평균 레벨 %.1f" % levels[1])
