extends Control
## 기지 화면 (시작 화면): 보유 광물, 공용 업그레이드 구매, 출격 버튼, 버전, 이전 버전 링크.
## 업그레이드 규칙은 BaseUpgrades, 저장은 SaveData에 있다.

const RUN_SCENE := "res://scenes/run.tscn"

const COLOR_TEXT := Color("#c8cde0")
const COLOR_DIM := Color("#8a90a8")
const COLOR_MAX := Color("#7cf0ff")

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
@onready var credits_label: Label = %CreditsLabel
@onready var upgrade_list: VBoxContainer = %UpgradeList

var save: SaveData
## 업그레이드 id → 구매 버튼
var buy_buttons: Dictionary = {}
## 업그레이드 id → 이름·단계 글자
var _level_labels: Dictionary = {}


func _ready() -> void:
	version_label.text = "v" + game_version()
	save = SaveData.load_file()
	_build_upgrades()
	refresh()
	# 이전 버전 링크는 웹(GitHub Pages)에서만 의미가 있으므로 웹에서만 보여 준다.
	old_versions_button.visible = OS.has_feature("web")
	old_versions_button.pressed.connect(_on_old_versions_pressed)
	start_button.pressed.connect(start_run)
	# 포커스를 주면 Enter/Space로 바로 출격할 수 있다.
	start_button.grab_focus()


## 게임 버전 (project.godot의 application/config/version)
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## 업그레이드 한 줄씩: "이름 Lv n/최대" · 효과 · 구매 버튼
func _build_upgrades() -> void:
	for u in Balance.BASE_UPGRADES:
		var id: String = u["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_label := _label(COLOR_TEXT, 92)
		var desc := _label(COLOR_DIM, 96)
		desc.text = BaseUpgrades.describe(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(88, 22)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(buy.bind(id))
		row.add_child(name_label)
		row.add_child(desc)
		row.add_child(button)
		upgrade_list.add_child(row)
		buy_buttons[id] = button
		_level_labels[id] = name_label


func _label(color: Color, width: float) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	return label


## 보유 광물과 업그레이드 단계·비용·버튼 상태를 저장 내용에 맞춘다.
func refresh() -> void:
	credits_label.text = "보유 광물 %d" % save.credits
	for id in buy_buttons:
		var lv := save.level_of(id)
		var top := BaseUpgrades.max_level(id)
		var label: Label = _level_labels[id]
		label.text = "%s Lv%d/%d" % [BaseUpgrades.info(id)["name"], lv, top]
		var button: Button = buy_buttons[id]
		if lv >= top:
			button.text = "최대"
			button.add_theme_color_override("font_disabled_color", COLOR_MAX)
		else:
			button.text = "강화 %d" % BaseUpgrades.cost(id, lv)
		button.disabled = not BaseUpgrades.can_buy(save, id)


## 업그레이드를 한 단계 사고 바로 저장한다.
func buy(id: String) -> void:
	if not BaseUpgrades.buy(save, id):
		return
	save.save_file()
	Sfx.play_pickup(2)
	refresh()
	# 최대 단계가 되거나 광물이 모자라 버튼이 막히면 키보드 포커스를 출격 버튼으로 옮긴다
	if buy_buttons[id].disabled:
		start_button.grab_focus()


func start_run() -> void:
	get_tree().change_scene_to_file(RUN_SCENE)


## 웹에서 같은 탭으로 이전 버전 목록을 연다.
func _on_old_versions_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(OPEN_OLD_VERSIONS_JS)
