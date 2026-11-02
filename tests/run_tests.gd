extends SceneTree
## 자동 테스트 실행기.
## 실행: godot --headless --path . -s res://tests/run_tests.gd
## tests/ 폴더의 test_*.gd 파일을 모두 찾아 test_ 로 시작하는 함수를 실행하고,
## 하나라도 실패하면 종료 코드 1로 끝난다 (GitHub Actions가 실패로 처리).

const TEST_DIR := "res://tests"


## 테스트 중에 난 엔진·스크립트 오류를 모은다.
## GDScript는 실행 중 오류(null 접근 등)가 나면 그 함수만 멈추고 계속 진행하므로,
## 오류를 따로 잡지 않으면 실패한 테스트가 통과로 보일 수 있다.
class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var message := rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("%s:%d (%s) %s" % [file, line, function, message])
		_mutex.unlock()

	## 지금까지 모인 오류를 꺼내고 비운다.
	func take() -> PackedStringArray:
		_mutex.lock()
		var result := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return result

var _catcher := ErrorCatcher.new()


func _initialize() -> void:
	OS.add_logger(_catcher)
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	var files := _test_files()
	if files.is_empty():
		printerr("테스트 파일을 찾지 못했습니다: %s/test_*.gd" % TEST_DIR)
		quit(1)
		return

	for file in files:
		var script: GDScript = load(file)
		if script == null or not script.can_instantiate():
			printerr("실패  %s - 스크립트를 불러올 수 없음 (문법 오류 확인)" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			# 테스트 함수마다 새 인스턴스를 만들어 서로 영향을 주지 않게 한다.
			var test: TestCase = script.new()
			root.add_child(test)
			_catcher.take()
			await test.call(name)
			for error in _catcher.take():
				test.failures.append("실행 중 오류: " + error)
			if test.failures.is_empty():
				print("통과  %s :: %s" % [file.get_file(), name])
				passed += 1
			else:
				printerr("실패  %s :: %s" % [file.get_file(), name])
				for message in test.failures:
					printerr("      - " + message)
				failed += 1
			test.queue_free()
			await process_frame

	print("\n결과: 통과 %d, 실패 %d" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)


## tests/ 폴더에서 test_*.gd 파일 목록 (이름순)
func _test_files() -> PackedStringArray:
	var result: PackedStringArray = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			result.append(TEST_DIR.path_join(file))
	result.sort()
	return result
