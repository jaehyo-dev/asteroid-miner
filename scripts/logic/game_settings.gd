class_name GameSettings
extends RefCounted
## 플레이어 설정 (화면 흔들림, 효과음·배경음 크기, 숨은 FPS 표시). user://settings.cfg에 따로 저장해 세이브 데이터(save.json) 형식은 건드리지 않는다.

static var path := "user://settings.cfg"

## 효과음 크기 단계 수 (0 = 끄기, SFX_LEVELS = 최대)
const SFX_LEVELS := 4

var shake := true
var sfx_level := SFX_LEVELS
## 배경음 크기 단계 (효과음과 같은 방식)
var music_level := SFX_LEVELS
## 숨은 FPS 표시 (일시 정지 화면 제목을 5번 누르면 켜고 끔)
var show_fps := false


static func load_file() -> GameSettings:
	var s := GameSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		s.shake = bool(cfg.get_value("screen", "shake", true))
		s.sfx_level = clampi(int(cfg.get_value("sound", "sfx_level", SFX_LEVELS)), 0, SFX_LEVELS)
		s.music_level = clampi(int(cfg.get_value("sound", "music_level", SFX_LEVELS)), 0, SFX_LEVELS)
		s.show_fps = bool(cfg.get_value("screen", "show_fps", false))
	return s


func save_file() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "shake", shake)
	cfg.set_value("sound", "sfx_level", sfx_level)
	cfg.set_value("sound", "music_level", music_level)
	cfg.set_value("screen", "show_fps", show_fps)
	var err := cfg.save(path)
	if err != OK:
		push_warning("설정 저장 실패: %s (%s)" % [path, error_string(err)])
	return err == OK


## 효과음 크기를 한 단계 올린다. 최대에서 누르면 끄기(0)로 돌아간다.
func cycle_sfx() -> void:
	sfx_level = (sfx_level + 1) % (SFX_LEVELS + 1)


func cycle_music() -> void:
	music_level = (music_level + 1) % (SFX_LEVELS + 1)


## 배경음 버스 음량(데시벨). 0단계는 음소거로 처리하므로 여기 값은 쓰지 않는다.
func music_db() -> float:
	return linear_to_db(float(music_level) / SFX_LEVELS)


## 효과음 버스 음량(데시벨). 0단계는 음소거로 처리하므로 여기 값은 쓰지 않는다.
func sfx_db() -> float:
	return linear_to_db(float(sfx_level) / SFX_LEVELS)


## 일시 정지 메뉴 버튼 글자
func shake_label() -> String:
	return "화면 흔들림: %s" % ("켜짐" if shake else "꺼짐")


func music_label() -> String:
	if music_level == 0:
		return "배경음: 끄기"
	return "배경음: %d%%" % (music_level * 100 / SFX_LEVELS)


func sfx_label() -> String:
	if sfx_level == 0:
		return "효과음: 끄기"
	return "효과음: %d%%" % (sfx_level * 100 / SFX_LEVELS)
