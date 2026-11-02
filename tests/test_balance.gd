extends TestCase
## 밸런스 시뮬레이션 테스트: 봇이 무작위 강화로 플레이했을 때 한 판 길이 확인.
## GAME_SPEC "한 판 길이 3~5분"을 기준으로, 수치를 바꿔도 크게 벗어나지 않게 지킨다.
## (봇: 가만히 / 돌아다님 / 운석 피하기, 각각 8판)

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007]
## 이 시간 안에는 어떤 봇도 반드시 끝나야 한다 (강화를 쌓아도 끝없이 버틸 수 없음)
const HARD_LIMIT := 600.0
## 중앙값 허용 범위 (2분 30초 ~ 6분)
const MEDIAN_MIN := 150.0
const MEDIAN_MAX := 360.0
## 처음 2분 안에 끝나면 너무 어렵다
const EARLIEST_END := 120.0


func test_어떤_플레이도_한_판이_끝나고_길이가_알맞음() -> void:
	for style in ["still", "wander", "flee"]:
		var st := BalanceBot.survival_stats(style, SEEDS, HARD_LIMIT + 1.0)
		assert_true(st[2] <= HARD_LIMIT, "%s 최대 %.0f초 (10분 안에 끝나야 함)" % [style, st[2]])
		assert_true(st[1] >= MEDIAN_MIN and st[1] <= MEDIAN_MAX, "%s 중앙값 %.0f초" % [style, st[1]])
		assert_true(st[0] >= EARLIEST_END, "%s 최소 %.0f초 (너무 빨리 끝남)" % [style, st[0]])
