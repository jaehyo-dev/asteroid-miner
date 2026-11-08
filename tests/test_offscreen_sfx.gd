extends TestCase
## 화면 밖 방향 표시 위치와 효과음 테스트.

const VIEW := Vector2(640, 360)


func test_화면_안에_있으면_표시_없음() -> void:
	assert_eq(Offscreen.edge_marker(Vector2.ZERO, Vector2(100, 50), VIEW, 12.0), null)
	# 중심은 밖이어도 몸 일부가 보이면 표시하지 않음
	assert_eq(Offscreen.edge_marker(Vector2.ZERO, Vector2(325, 0), VIEW, 12.0, 10.0), null)


func test_오른쪽_밖이면_오른쪽_가장자리에_표시() -> void:
	var m: Vector2 = Offscreen.edge_marker(Vector2.ZERO, Vector2(1000, 0), VIEW, 12.0)
	assert_true(m.is_equal_approx(Vector2(640 - 12, 180)), "%s" % m)


func test_위쪽_밖이면_위쪽_가장자리에_표시() -> void:
	var m: Vector2 = Offscreen.edge_marker(Vector2(50, 50), Vector2(50, -900), VIEW, 12.0)
	assert_true(m.is_equal_approx(Vector2(320, 12)), "%s" % m)


func test_대각선_밖이면_방향을_유지하며_화면_안쪽에() -> void:
	var center := Vector2(200, -100)
	var target := center + Vector2(-2000, 1500)
	var m: Vector2 = Offscreen.edge_marker(center, target, VIEW, 12.0)
	assert_true(m.x >= 12.0 - 0.01 and m.x <= VIEW.x - 12.0 + 0.01 and m.y >= 12.0 - 0.01 and m.y <= VIEW.y - 12.0 + 0.01, "화면 안 %s" % m)
	var dir := (m - VIEW / 2.0).normalized()
	assert_true(dir.is_equal_approx((target - center).normalized()), "방향 유지")


func test_소리_만들기는_16비트_모노() -> void:
	var s := Sfx.synth([[440.0, 0.1]], "square", 0.5)
	assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(s.stereo)
	assert_eq(s.data.size(), int(Sfx.MIX_RATE * 0.1) * 2)


func test_방향_화살표는_길고_뾰족해서_방향이_분명함() -> void:
	for dir in [Vector2.RIGHT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-0.6, 0.8)]:
		var p := Hud.arrow_points(Vector2(100, 100), dir)
		var tip := p[0]
		var base_mid := (p[1] + p[2]) / 2.0
		var height := tip.distance_to(base_mid)
		var width := p[1].distance_to(p[2])
		assert_true(height >= width * 1.5, "높이 %f, 밑변 %f (뾰족해야 함)" % [height, width])
		assert_true((tip - base_mid).normalized().is_equal_approx(dir), "끝이 대상 쪽을 가리킴")
		# 끝은 표시 위치보다 대상 쪽, 밑변은 화면 안쪽
		assert_true((tip - Vector2(100, 100)).dot(dir) > 0.0 and (base_mid - Vector2(100, 100)).dot(dir) < 0.0)
