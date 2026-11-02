extends TestCase
## 이동 입력 계산 테스트.


func test_키보드_한_방향() -> void:
	assert_eq(MoveInput.keyboard_vector(false, true, false, false), Vector2.RIGHT)
	assert_eq(MoveInput.keyboard_vector(false, false, true, false), Vector2.UP)


func test_키보드_대각선도_같은_속도() -> void:
	var v := MoveInput.keyboard_vector(true, false, false, true)
	assert_true(is_equal_approx(v.length(), 1.0), "길이 1")
	assert_true(v.x < 0.0 and v.y > 0.0, "왼쪽 아래")


func test_키보드_반대_방향은_상쇄() -> void:
	assert_eq(MoveInput.keyboard_vector(true, true, false, false), Vector2.ZERO)
	assert_eq(MoveInput.keyboard_vector(false, false, false, false), Vector2.ZERO)


func test_조이스틱_데드존_안은_0() -> void:
	assert_eq(MoveInput.joystick_vector(Vector2(100, 100), Vector2(103, 100), 28.0, 0.15), Vector2.ZERO)


func test_조이스틱_반지름_이상이면_최고_속도() -> void:
	var v := MoveInput.joystick_vector(Vector2.ZERO, Vector2(0, -100), 28.0, 0.15)
	assert_true(v.is_equal_approx(Vector2(0, -1)), "위쪽 최고 속도: %s" % v)


func test_조이스틱_중간은_비례() -> void:
	var v := MoveInput.joystick_vector(Vector2.ZERO, Vector2(14, 0), 28.0, 0.0)
	assert_true(is_equal_approx(v.x, 0.5), "절반: %s" % v)


func test_조이스틱_반지름_0이면_0() -> void:
	assert_eq(MoveInput.joystick_vector(Vector2.ZERO, Vector2(10, 0), 0.0, 0.1), Vector2.ZERO)


func test_조이스틱_중심이_손가락을_따라옴() -> void:
	assert_eq(MoveInput.follow_base(Vector2.ZERO, Vector2(20, 0), 28.0), Vector2.ZERO, "반지름 안이면 그대로")
	var base := MoveInput.follow_base(Vector2.ZERO, Vector2(100, 0), 28.0)
	assert_true(base.is_equal_approx(Vector2(72, 0)), "반지름만큼 뒤로: %s" % base)


func test_키보드와_조이스틱_합치면_길이_1_이하() -> void:
	var v := MoveInput.combine(Vector2.RIGHT, Vector2.UP)
	assert_true(v.length() <= 1.0001, "길이 %f" % v.length())
