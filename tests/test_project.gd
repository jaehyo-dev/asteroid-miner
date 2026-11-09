extends TestCase
## 프로젝트 기본 구조와 웹 내보내기 설정 테스트.


func test_게임_버전은_메이저_마이너_패치_형식() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var regex := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_not_null(regex.search(version), "버전 '%s'" % version)


func test_웹에서_동작하는_렌더러를_사용() -> void:
	# 웹 내보내기는 Compatibility(OpenGL) 렌더러만 지원한다.
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_픽셀_아트용_최근접_필터() -> void:
	# 0 = Nearest. 픽셀 아트가 흐릿하게 보이지 않게 한다.
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_웹_내보내기는_스레드_없이_설정됨() -> void:
	# 스레드 지원을 켜면 GitHub Pages(COOP/COEP 헤더 없음)에서 실행되지 않는다.
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK, "export_presets.cfg 읽기")
	var web_section := ""
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Web":
			web_section = section
	assert_eq(web_section, "preset.0", "Web 프리셋")
	assert_eq(presets.get_value(web_section, "name", ""), "Web", "프리셋 이름 (배포 워크플로가 이 이름을 씀)")
	assert_eq(presets.get_value(web_section + ".options", "variant/thread_support", true), false, "스레드 지원 끔")
	assert_eq(presets.get_value(web_section, "export_path", ""), "build/web/index.html", "내보내기 위치")
	var excluded := str(presets.get_value(web_section, "exclude_filter", ""))
	for folder in ["tests/*", "tools/*", "build/*", "_site/*"]:
		assert_true(excluded.contains(folder), "내보내기 제외: " + folder)
	# 효과음: 쓰는 파일은 빠지지 않고, assets/sfx/game의 안 쓰는 옛 파일은 모두 빠짐
	var used := {}
	for sound: Dictionary in Sfx.SOUNDS.values():
		for f: String in sound["files"]:
			used[f] = true
	for f: String in Sfx.WARP_SOUND_DB:
		used[f] = true
	for file in DirAccess.get_files_at(Sfx.SFX_DIR):
		if file.ends_with(".wav"):
			var name := file.get_basename()
			assert_eq(excluded.contains("assets/sfx/game/" + file), not used.has(name), "내보내기 제외 여부: " + name)


func test_웹_페이지는_노치와_홈_바_안쪽에만_그림() -> void:
	# viewport-fit=cover를 켜면 페이지가 노치·홈 바 밑까지 퍼져 HUD가 가려진다. 끄면(기본값) 브라우저가 안전 영역 안에만 그린다.
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	assert_false(str(presets.get_value("preset.0.options", "html/head_include", "")).contains("viewport-fit"), "head_include")
	assert_false(str(presets.get_value("preset.0.options", "html/custom_html_shell", "")).contains("viewport-fit"), "custom_html_shell")


func test_소수_DPR_폰에서_캔버스가_흐려지지_않게_함() -> void:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	assert_true(str(presets.get_value("preset.0.options", "html/head_include", "")).contains("image-rendering:pixelated"))


func test_내보내기_결과물_폴더는_리소스로_가져오지_않음() -> void:
	# build/ 안의 이전 빌드(그림 등)가 다음 빌드에 섞여 들어가지 않게 한다.
	assert_true(FileAccess.file_exists("res://build/.gdignore"), "build/.gdignore")


func test_시작_씬이_존재함() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_eq(main_scene, "res://scenes/main.tscn")
	assert_true(ResourceLoader.exists(main_scene), "시작 씬 파일")


func test_한글_글꼴이_기본_글꼴로_설정됨() -> void:
	# 웹에서는 시스템 글꼴을 쓸 수 없으므로 한글 글꼴을 직접 넣어야 한다.
	var font: Font = load(str(ProjectSettings.get_setting("gui/theme/custom_font", "")))
	assert_not_null(font, "기본 글꼴")
	if font:
		assert_true(font.has_char("광".unicode_at(0)), "한글 글자 포함")
