extends TestCase
## 시작 화면 씬 테스트.

const MainScene := preload("res://scenes/main.tscn")


func test_시작_화면이_열리고_버전을_표시함() -> void:
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	var version := str(ProjectSettings.get_setting("application/config/version"))
	var label: Label = main.get_node("%VersionLabel")
	assert_eq(label.text, "v" + version, "버전 표시")
	var title: Label = main.get_node("%Title")
	assert_eq(title.text, "소행성 광부", "제목")
	main.queue_free()


func test_이전_버전_버튼은_웹에서만_보임() -> void:
	var main: Control = MainScene.instantiate()
	add_child(main)
	await wait_frames()
	var button: Button = main.get_node("%OldVersionsButton")
	# 테스트는 웹이 아닌 환경에서 실행되므로 숨겨져 있어야 한다.
	assert_eq(button.visible, OS.has_feature("web"))
	main.queue_free()
