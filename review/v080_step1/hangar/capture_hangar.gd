extends SceneTree
## 격납고 창 바탕 캡처 (시안용, 게임에는 쓰지 않음). 저장소 맨 위에서:
##   godot --path . --resolution 1280x720 -s $PWD/review/v080_step1/hangar/capture_hangar.gd -- <출력.png> [noship]
## noship: 우주선·그림자 그림을 빈 그림으로 바꿔 받침과 빛기둥만 찍는다 (시안 C 바탕)
## review/는 .gdignore라서 res:// 대신 파일 경로로 넘긴다.

var f := 0
var out := ""
var noship := false


func _initialize() -> void:
	SaveData.path = "user://capture_hangar_save.json"  # 실제 저장을 건드리지 않게
	var s := SaveData.new()
	s.credits = 780
	s.save_file()
	var a := OS.get_cmdline_user_args()
	out = a[0]
	noship = a.size() > 1 and a[1] == "noship"


func _process(_d: float) -> bool:
	f += 1
	RenderingServer.force_draw(false)
	if f == 1:
		change_scene_to_file("res://scenes/main.tscn")
	if f == 10:
		if noship:  # 그림 캐시에 빈 그림을 먼저 넣어 두면 창이 그것을 쓴다
			var empty := ImageTexture.create_from_image(Image.create(512, 280, false, Image.FORMAT_RGBA8))
			WindowArt._tex["spin"] = empty
			WindowArt._tex["spin_shadow"] = empty
		root.get_node("Main").panel.open("hangar")
	if f == 40:
		root.get_texture().get_image().save_png(out)
		return true
	return false
