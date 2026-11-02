extends Control
## 시작 화면: 제목, 출격 버튼, 버전, 이전 버전 링크.

const RUN_SCENE := "res://scenes/run.tscn"

## 이전 버전 목록 페이지로 이동하는 자바스크립트.
## 보관된 이전 버전(.../versions/v0.0.1/)에서 눌러도 같은 목록(.../versions/)으로 가도록
## 현재 주소에 '/versions/'가 있으면 그 앞부분을 기준으로 삼는다.
const OPEN_OLD_VERSIONS_JS := """
(function () {
	var path = window.location.pathname;
	var i = path.indexOf('/versions/');
	var base = i >= 0 ? path.slice(0, i + 1) : path.slice(0, path.lastIndexOf('/') + 1);
	window.location.href = base + 'versions/';
})();
"""

@onready var version_label: Label = %VersionLabel
@onready var old_versions_button: Button = %OldVersionsButton
@onready var start_button: Button = %StartButton


func _ready() -> void:
	version_label.text = "v" + game_version()
	# 이전 버전 링크는 웹(GitHub Pages)에서만 의미가 있으므로 웹에서만 보여 준다.
	old_versions_button.visible = OS.has_feature("web")
	old_versions_button.pressed.connect(_on_old_versions_pressed)
	start_button.pressed.connect(start_run)
	# 포커스를 주면 Enter/Space로 바로 출격할 수 있다.
	start_button.grab_focus()


## 게임 버전 (project.godot의 application/config/version)
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func start_run() -> void:
	get_tree().change_scene_to_file(RUN_SCENE)


## 웹에서 같은 탭으로 이전 버전 목록을 연다.
func _on_old_versions_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(OPEN_OLD_VERSIONS_JS)
