extends Control
## 시작 화면 (0단계: 프로젝트 기본 구조).
## 아직 게임 플레이는 없고, 제목·버전·이전 버전 링크만 보여 준다.

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

## 별 개수와 별 배치에 쓰는 고정 시드 (매번 같은 배경)
const STAR_COUNT := 90
const STAR_SEED := 20261102

@onready var version_label: Label = %VersionLabel
@onready var old_versions_button: Button = %OldVersionsButton

var _stars: Array[Vector2] = []


func _ready() -> void:
	version_label.text = "v" + game_version()
	# 이전 버전 링크는 웹(GitHub Pages)에서만 의미가 있으므로 웹에서만 보여 준다.
	old_versions_button.visible = OS.has_feature("web")
	old_versions_button.pressed.connect(_on_old_versions_pressed)
	resized.connect(_make_stars)
	_make_stars()


## 게임 버전 (project.godot의 application/config/version)
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## 화면 크기에 맞춰 별 위치를 다시 만든다.
func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	_stars.clear()
	for i in STAR_COUNT:
		_stars.append(Vector2(rng.randf() * size.x, rng.randf() * size.y).floor())
	queue_redraw()


## 배경 별 그리기 (1픽셀 점)
func _draw() -> void:
	for i in _stars.size():
		var bright := 0.35 + 0.65 * float(i % 3) / 2.0
		draw_rect(Rect2(_stars[i], Vector2.ONE), Color(bright, bright, bright + 0.1))


## 웹에서 같은 탭으로 이전 버전 목록을 연다.
func _on_old_versions_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(OPEN_OLD_VERSIONS_JS)
