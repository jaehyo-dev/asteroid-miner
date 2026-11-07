extends TestCase
## 게임 전체 설정(App 자동 로드) 테스트.


func test_세로_화면이면_세로_기준_해상도() -> void:
	assert_eq(App.base_size_for(Vector2i(390, 844)), Balance.BASE_PORTRAIT)
	assert_eq(App.base_size_for(Vector2i(1280, 720)), Balance.BASE_LANDSCAPE)
	assert_eq(App.base_size_for(Vector2i(844, 390)), Balance.BASE_LANDSCAPE)


func test_세로_기준도_짧은_쪽이_같음() -> void:
	# 가로·세로 어느 쪽이든 짧은 변 길이가 같아야 글자 크기가 비슷하게 보인다.
	assert_eq(mini(Balance.BASE_PORTRAIT.x, Balance.BASE_PORTRAIT.y), mini(Balance.BASE_LANDSCAPE.x, Balance.BASE_LANDSCAPE.y))


func test_이동과_일시_정지_키가_등록됨() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "pause"]:
		assert_true(InputMap.has_action(action), action)
		assert_true(InputMap.action_get_events(action).size() >= 1, action + " 키")


func test_자동_로드로_실행됨() -> void:
	assert_not_null(get_tree().root.get_node_or_null("App"), "App 노드")


func test_기지_화면은_2배_기준_해상도() -> void:
	assert_eq(App.base_size_for(Vector2i(1280, 720), true), Vector2i(1280, 720))
	assert_eq(App.base_size_for(Vector2i(390, 844), true), Vector2i(720, 1280))
	App.set_base_mode(true)
	assert_eq(get_tree().root.content_scale_size, App.base_size_for(get_tree().root.size, true))
	App.set_base_mode(false)
	assert_eq(get_tree().root.content_scale_size, App.base_size_for(get_tree().root.size))
