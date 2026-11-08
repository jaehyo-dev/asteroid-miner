extends SceneTree
## 레벨업 카드 확인용 캡처 도구 (게임에는 쓰지 않음). 진짜 출격 화면 위에 정해 둔 카드를 띄운다.
## 창을 띄워 실행하고 Godot 무비 모드로 프레임을 PNG로 저장한다.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <폴더>/f.png -s res://tools/capture_cards.gd -- normal
##   장면: normal(수치 카드), five(다섯 등급, 창 1400x390), zero(다시 뽑기 0회), reveal(등장 연출: 레전드리), reveal_low(등장 연출: 유니크까지), skip(0.3초에 건너뜀), long(가장 긴 문구)

const SCENES := {
	"normal": [{"id": "fire_rate", "grade": 1}, {"id": "multishot", "grade": 2}, {"id": "magnet", "grade": 0}],
	"five": [{"id": "fire_rate", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "pierce", "grade": 2}, {"id": "drone", "grade": 3}, {"id": "orbit_pierce", "grade": 4}],
	"zero": [{"id": "speed", "grade": 3}, {"id": "range", "grade": 0}, {"id": "max_hp", "grade": 1}],
	"reveal": [{"id": "fire_rate", "grade": 1}, {"id": "pierce", "grade": 2}, {"id": "chain_matrix", "grade": 4}],
	"reveal_low": [{"id": "fire_rate", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "magnet", "grade": 3}],
	"skip": [{"id": "fire_rate", "grade": 0}, {"id": "orbit_pierce", "grade": 4}, {"id": "magnet", "grade": 1}],
	"long": [{"id": "speed", "grade": 3}, {"id": "chain_matrix", "grade": 4}, {"id": "multishot", "grade": 2}],
}
## 카드를 띄우기 전 전투가 흐르는 프레임 수
const WARMUP := 90

var run: Node
var scene := ""
var frame := 0
var opened_at := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	scene = args[0] if args.size() > 0 else "normal"


func _process(_delta: float) -> bool:
	frame += 1
	RenderingServer.force_draw(false)  # 창이 다른 창에 가려져도 프레임을 그린다 (macOS는 가려진 창을 안 그림)
	if frame == 1:
		run = load("res://scenes/run.tscn").instantiate()
		root.add_child(run)
	elif frame == 2:
		run.sim.rng.seed = 4242
		run.sim.max_hp = 1.0e6  # 무적은 깜빡임이 보여서 체력만 크게
		run.sim.hp = 1.0e6
		run.sim.set("_spawn_timer", 0.1)
	elif frame > 2:
		if run.current_menu == run.Menu.PAUSE:
			run._close_menu()  # 캡처 창이 포커스를 잃으면 게임이 스스로 멈추므로 바로 닫는다
		if frame == WARMUP:
			var cards: Array = SCENES[scene]
			run.sim.choices = cards
			run.sim.pending_levelups = 1
			run.sim.upgrade_levels = {"fire_rate": 1, "multishot": 2, "speed": 3, "range": 2}
			run.sim.rerolls_left = 0 if scene == "zero" else 2
			run.slowmo = 0.0
			run._show_level_up()
			opened_at = frame
		if opened_at > 0:
			var hold := 90 if scene.begins_with("reveal") or scene == "skip" else 60
			if scene == "skip" and frame == opened_at + 9:
				run.cards.skip()
			elif scene != "skip" and not scene.begins_with("reveal") and frame == opened_at + 1:
				run.cards.skip()
			return frame > opened_at + hold
	return false
