extends TestCase
## 출격 화면 팩 그림 시트(RunSprites)와 그림 선택 규칙, 지운 문자 패턴이 남지 않았는지.

## v0.7.0 3단계에서 pixel_art.gd에서 지운 이름 (팩 그림으로 바뀜). 코드 어디에도 남으면 안 된다.
const REMOVED := [
	"SHIP_PATTERN", "BULLET_COLORS", "PixelArt.DEBRIS_COLOR", "MINERAL_COLORS", "MINERAL_PATTERNS",
	"JELLY_COLORS", "JELLY_BELL", "BUG_COLORS", "BUG_FRAMES", "GUARD_COLORS", "GUARD_PATTERN",
	"ROCK_COLORS", "GOLD_ROCK_COLORS", "PixelArt.ship(", "PixelArt.asteroid", "PixelArt.mineral(",
	"PixelArt.guard(", "PixelArt.jelly_bell(", "PixelArt.bug(", "PixelArt.rotated(", "PixelArt.discovery_icon(",
	"crack_lines",
]


func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out


func test_지운_문자_패턴과_함수가_코드에_남지_않음() -> void:
	var files := _gd_files("res://scripts")
	files.append_array(_gd_files("res://tests"))
	assert_true(files.size() > 20, "스크립트를 찾음 %d" % files.size())
	for path in files:
		if path.ends_with("test_run_sprites.gd"):
			continue  # 이 파일은 목록을 들고 있음
		var text := FileAccess.get_file_as_string(path)
		for name in REMOVED:
			assert_false(text.contains(name), "%s에 %s가 남음" % [path, name])
	var consts := (load("res://scripts/pixel_art.gd") as Script).get_script_constant_map()
	for name in ["SHIP_PATTERN", "MINERAL_PATTERNS", "JELLY_BELL", "BUG_FRAMES", "GUARD_PATTERN"]:
		assert_false(consts.has(name), "PixelArt." + name)


func test_모든_시트가_있고_돌아가는_시트는_8방향() -> void:
	for name in RunSprites.CELL:
		var tex := RunSprites.tex(name)
		var cell: int = RunSprites.CELL[name]
		assert_not_null(tex, name)
		assert_eq(tex.get_width() % cell, 0, name + " 가로가 칸의 배수")
		var rows := tex.get_height() / cell
		if name.begins_with("rock_") and name.ends_with("_boom"):
			assert_eq(rows, 1, name + " 깨지는 운석은 돌리지 않음")
		elif name == "barrage_shot":
			assert_eq(rows, 1, name + " 둥근 에너지 구체는 돌리지 않음")
		else:
			assert_eq(rows, 8, name + " 8방향")
	assert_eq(RunSprites.frames("ship"), 4, "피해 4단계")
	assert_eq(RunSprites.frames("ship_cannon"), 7, "자동 포 7프레임")
	assert_eq(RunSprites.frames("ship_flame_idle"), 3)
	assert_eq(RunSprites.frames("ship_flame_power"), 4)
	# 우주선은 팩 원본의 60% (보이는 몸 약 20x16, PLAN 15번). 피해 단계가 달라도 몸 크기는 같다
	for f in 4:
		assert_eq(RunSprites.icon("ship", f).get_size(), Vector2(20, 16), "60퍼센트 우주선 몸 %d" % f)
	for i in 3:
		assert_eq(RunSprites.frames("rock_%d" % i), 3, "운석: 멀쩡·금 1·금 2")
		assert_eq(RunSprites.frames("rock_%d_boom" % i), 8, "운석 깨짐 8프레임")


func test_맞으면_흰색_섞는_셰이더로_번쩍임() -> void:
	var sim := RunSim.new(3)
	var view := WorldView.new()
	view.sim = sim
	add_child(view)
	var flash: Node2D = view.get_node("Flash")
	assert_true(flash.material is ShaderMaterial and (flash.material as ShaderMaterial).shader == WorldView.FLASH_SHADER, "흰색 섞는 셰이더")
	assert_eq(Juice.ENEMY_FLASH_TIME, 0.05, "약 50ms")
	view.queue_free()


func test_칸_영역은_프레임과_방향으로_정해짐() -> void:
	assert_eq(RunSprites.region("ship", 2, 3), Rect2(96, 144, 48, 48))
	assert_eq(RunSprites.region("ship", 6, 9), Rect2(96, 48, 48, 48), "넘치면 감싸 돎")


func test_운석_크기는_약_1대_16대_25이고_광물은_8에서_12픽셀() -> void:
	var widths: Array[float] = []
	for i in 3:
		widths.append(RunSprites.icon("rock_%d" % i).get_width())
	assert_true(widths[1] / widths[0] > 1.4 and widths[1] / widths[0] < 1.8, "중간/작은 %s" % str(widths))
	assert_true(widths[2] / widths[0] > 2.2 and widths[2] / widths[0] < 2.8, "큰/작은 %s" % str(widths))
	for g in 4:
		var s := RunSprites.mineral(g).get_size()
		assert_true(maxf(s.x, s.y) >= 8 and maxf(s.x, s.y) <= 12, "광물 %d: %s" % [g, str(s)])


func test_충돌_반지름은_보이는_몸보다_작음() -> void:
	# 보이는 몸 반지름(폭·높이 평균의 절반)보다 작아야 "스쳤는데 맞음"이 없다
	var body := func(name: String) -> float:
		var s := RunSprites.icon(name).get_size()
		return (s.x + s.y) / 4.0
	assert_true(Balance.SHIP_RADIUS < body.call("ship"), "우주선")
	for i in 3:
		assert_true(Balance.ASTEROID_TYPES[i]["radius"] < body.call("rock_%d" % i), "운석 %d" % i)
	assert_true(Balance.GOLDEN["radius"] < body.call("rock_gold"), "황금 운석")
	assert_true(Balance.CREATURES["jelly"]["radius"] < body.call("jelly"), "해파리")
	assert_true(Balance.CREATURES["bug"]["radius"] < body.call("bug"), "날벌레")
	assert_true(Balance.GUARD["radius"] < body.call("guard"), "경비선")


func test_체력이_줄면_우주선_피해_그림이_바뀜() -> void:
	assert_eq(WorldView.damage_stage(100.0, 100.0), 0)
	assert_eq(WorldView.damage_stage(70.0, 100.0), 1)
	assert_eq(WorldView.damage_stage(40.0, 100.0), 2)
	assert_eq(WorldView.damage_stage(10.0, 100.0), 3)


func test_쏘면_자동_포가_불꽃_프레임을_재생하고_쉼으로_돌아감() -> void:
	assert_eq(WorldView.cannon_frame(0.0), 1, "쏜 순간 불꽃")
	assert_eq(WorldView.cannon_frame(10.0), 0, "오래 지나면 쉼")
	var last := 0
	for i in 20:
		var f := WorldView.cannon_frame(i * 0.01)
		assert_true(f == 0 or f >= last, "앞으로만 진행")
		last = f


func test_적마다_자기_팩_파괴_시트() -> void:
	var e := RunSim.Enemy.new()
	e.type = 2
	assert_eq(WorldView.boom_sheet(e), "rock_2_boom")
	e.golden = true
	assert_eq(WorldView.boom_sheet(e), "rock_gold_boom")
	e.golden = false
	e.kind = "bug"
	assert_eq(WorldView.boom_sheet(e), "bug_boom")
	e.kind = RunSim.GUARD
	assert_eq(WorldView.boom_sheet(e), "guard_boom")


func test_부서지면_파괴_애니메이션과_파편이_생기고_끝나면_사라짐() -> void:
	var sim := RunSim.new(7)
	var view := WorldView.new()
	view.sim = sim
	add_child(view)
	var e := RunSim.Enemy.new()
	e.type = 1
	e.radius = 10.0
	sim.destroyed.append(e)
	view.step(0.01)
	assert_eq(view._booms.size(), 1)
	assert_true(view._debris.size() > 0, "파편 파티클")
	sim.destroyed.clear()
	for i in 120:
		view.step(1.0 / 60.0)
	assert_eq(view._booms.size(), 0, "애니메이션이 끝나면 사라짐")
	view.queue_free()


func test_파편은_총량_상한을_넘지_않고_다_쓴_것을_다시_씀() -> void:
	var sim := RunSim.new(7)
	var view := WorldView.new()
	view.sim = sim
	add_child(view)
	for i in 20:  # 황금 운석 20개 = 파편 480개 요청
		var e := RunSim.Enemy.new()
		e.golden = true
		e.radius = 20.0
		sim.destroyed.append(e)
	view.step(0.01)
	assert_eq(view._debris.size(), Juice.PARTICLE_MAX, "상한까지만")
	sim.destroyed.clear()
	for i in 120:
		view.step(1.0 / 60.0)
	assert_eq(view._debris.size(), 0, "시간이 지나면 모두 사라짐")
	assert_eq(view._debris_pool.size(), Juice.PARTICLE_MAX, "버리지 않고 풀에 모아 둠")
	var pooled: Array = view._debris_pool.back()
	var e2 := RunSim.Enemy.new()
	e2.radius = 4.0
	sim.destroyed.append(e2)
	view.step(0.01)
	assert_true(view._debris.any(func(d: Array) -> bool: return is_same(d, pooled)), "풀의 파편을 다시 씀")
	assert_eq(view._debris.size() + view._debris_pool.size(), Juice.PARTICLE_MAX, "새로 만들지 않음")
	view.queue_free()


func test_HUD_숫자는_목표까지_빠르게_카운트업() -> void:
	var v := 0.0
	var frames := 0
	while v < 100.0 and frames < 600:
		v = Hud.count_toward(v, 100.0, 1.0 / 60.0)
		frames += 1
	assert_eq(v, 100.0, "목표에 정확히 붙음")
	assert_true(frames > 3 and frames < 60, "1초 안에 빠르게 (%d프레임)" % frames)
	assert_true(Hud.count_toward(0.0, 1.0, 1.0 / 60.0) > 0.0, "작은 차이도 움직임")
	assert_true(Hud.count_toward(50.0, 40.0, 1.0 / 60.0) < 50.0, "줄어들 때도 따라감")


func test_쏘면_뒤로_밀렸다_돌아옴() -> void:
	var back := WorldView.recoil_offset(0.0, -PI / 2.0)  # 위를 볼 때 쏘면 아래로
	assert_true(back.y > 0.0 and back.length() <= Juice.RECOIL_PX + 0.01, "뒤로 %s" % back)
	assert_eq(WorldView.recoil_offset(Juice.RECOIL_TIME, 0.0), Vector2.ZERO, "%.2f초 뒤 제자리" % Juice.RECOIL_TIME)


func test_클수록_깨지는_애니메이션이_느림() -> void:
	var e := RunSim.Enemy.new()
	var fps: Array[float] = []
	for t in 3:
		e.type = t
		fps.append(WorldView.boom_fps(e))
	assert_true(fps[0] > fps[1] and fps[1] > fps[2], "작음 > 중간 > 큼: %s" % [fps])
