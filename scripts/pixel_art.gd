class_name PixelArt
extends RefCounted
## 이 프로젝트에서 직접 만든 픽셀 아트 (외부 에셋 없음).
## 문자 패턴과 시드를 고정한 절차 생성으로 텍스처를 만들고, 한 번 만든 것은 재사용한다.

## 우주선 (위쪽을 바라봄). 글자 → 색: # 선체, c 조종석, d 어두운 선체
const SHIP_PATTERN := [
	"....#....",
	"...#c#...",
	"...#c#...",
	"..##d##..",
	".#######.",
	"##d###d##",
	"#..#.#..#",
]
const SHIP_COLORS := {
	"#": Color("#c9d2e8"),
	"c": Color("#4fd1ff"),
	"d": Color("#6c7894"),
}
## 엔진 불꽃 색 (밝은 → 어두운)
const FLAME_COLORS := [Color("#ffe27a"), Color("#ff9a3c")]

## 탄 색 (가운데, 테두리)
const BULLET_COLORS := [Color("#ffffff"), Color("#7fe8ff")]
## 부서질 때 파편 색
const DEBRIS_COLOR := Color("#c8b49c")

## 광물 등급별 색 (일반, 희귀, 영웅, 전설): [밝은 면, 기본, 어두운 면]
const MINERAL_COLORS := [
	[Color("#eef3f8"), Color("#b8c4d0"), Color("#7b8794")],
	[Color("#c8f4ff"), Color("#4fd1ff"), Color("#2a86b0")],
	[Color("#ecd2ff"), Color("#c77dff"), Color("#7d3cb5")],
	[Color("#fff6c4"), Color("#ffd34f"), Color("#c48a1c")],
]
## 등급별 광물 모양. 글자 → 색: h 밝은 면, m 기본, s 어두운 면, w 반짝이는 흰 점
## 등급이 높을수록 크고 화려하다 (경험치 구슬이 아니라 보물처럼 보이게).
const MINERAL_PATTERNS := [
	# 일반: 울퉁불퉁한 회색 돌 조각 (작음, 4x4)
	[
		".hm.",
		"hmms",
		"mms.",
		".s..",
	],
	# 희귀: 뾰족한 푸른 결정 (중간, 5x7)
	[
		"..h..",
		".hh..",
		".hmm.",
		"hmmms",
		".mms.",
		".ms..",
		"..s..",
	],
	# 영웅: 육각형 보라 보석 (큼, 7x7)
	[
		"..hhh..",
		".hhmmm.",
		"hhmwmms",
		"hmwmmms",
		"hmmmmss",
		".mmmss.",
		"..sss..",
	],
	# 전설: 빛나는 금괴 (가장 큼, 9x6)
	[
		"..hhhhh..",
		".hhwhhhm.",
		"hhmmmmmms",
		"mmmmmmmss",
		"smmmmmsss",
		".sssssss.",
	],
]

## 우주 해파리 색: 몸 밝은 면, 몸, 촉수, 빛나는 핵
const JELLY_COLORS := [Color("#ffc8f0"), Color("#ff7ad9"), Color("#c04aa8"), Color("#fff0fb")]
## 우주 해파리 몸통(종 모양) 9x6. 글자 → 색: h 밝은 면, m 몸, c 핵
const JELLY_BELL := [
	"..hhhhh..",
	".hhmmmmh.",
	"hhmmcmmmm",
	"hmmcccmmm",
	"mmmmcmmmm",
	"m.m.m.m.m",
]
## 날벌레 색: 몸, 눈, 날개
const BUG_COLORS := [Color("#9dff6a"), Color("#ff4d4d"), Color("#e8ffd8")]
## 날벌레 2프레임 (위쪽을 바라봄). b 몸, e 눈, w 날개. 날갯짓: 0 펼침 / 1 접음
const BUG_FRAMES := [
	[
		"w.e.w",
		"wwbww",
		"wwbww",
		"..b..",
	],
	[
		"..e..",
		".wbw.",
		"..b..",
		"..b..",
	],
]

## 고대 경비선 색: 앞쪽 뿔(밝은 청동), 선체, 어두운 선체, 핵(주황빛)
const GUARD_COLORS := [Color("#e0c88e"), Color("#9a7c50"), Color("#55402a"), Color("#ffb347")]
## 고대 경비선 (위쪽을 바라봄, 13x10). 글자 → 색: g 뿔, # 선체, d 어두운 선체, c 핵
## 우주선(날렵한 은색)과 달리 뭉툭한 청동 선체에 뿔 두 개가 앞으로 뻗은 오래된 함선
const GUARD_PATTERN := [
	"..g.......g..",
	"..g.......g..",
	".gdg.....gdg.",
	".gdg..c..gdg.",
	".gdd#ccc#ddg.",
	"gddd#ccc#dddg",
	"gdd###c###ddg",
	".dd#######dd.",
	"..dd#####dd..",
	"...dd...dd...",
]

## 운석 색: 밝은 면, 기본, 그늘, 구멍
const ROCK_COLORS := [Color("#a8957f"), Color("#7a6a5a"), Color("#54483d"), Color("#3e352d")]
## 황금 운석 색: 밝은 면, 기본, 그늘, 구멍 (멀리서도 눈에 띄게 밝은 금색)
const GOLD_ROCK_COLORS := [Color("#fff3a0"), Color("#ffcc33"), Color("#c98a12"), Color("#8a5a0a")]

static var _cache: Dictionary = {}


## 문자 패턴을 텍스처로 만든다.
static func from_pattern(rows: Array, colors: Dictionary) -> ImageTexture:
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if colors.has(ch):
				img.set_pixel(x, y, colors[ch])
	return ImageTexture.create_from_image(img)


static func ship() -> ImageTexture:
	if not _cache.has("ship"):
		_cache["ship"] = from_pattern(SHIP_PATTERN, SHIP_COLORS)
	return _cache["ship"]


## 울퉁불퉁한 운석. 같은 (반지름, 변형 번호)는 항상 같은 모양이다.
static func asteroid(radius: float, variant: int, golden: bool = false) -> ImageTexture:
	var key := "rock_%d_%d_%s" % [int(radius), variant, golden]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius) * 7919 + variant * 104729 + 1
	# 테두리 울퉁불퉁함: 8방향의 반지름 비율
	var bumps: Array[float] = []
	for i in 8:
		bumps.append(rng.randf_range(0.8, 1.05))
	var size := int(ceil(radius)) * 2 + 2
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	var palette: Array = GOLD_ROCK_COLORS if golden else ROCK_COLORS
	var craters: Array[Vector3] = []  # x, y, 반지름
	for i in maxi(1, int(radius / 4.0)):
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, radius * 0.5)
		craters.append(Vector3(p.x, p.y, rng.randf_range(1.0, maxf(1.2, radius * 0.3))))
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5) - center
			var angle := fposmod(d.angle(), TAU) / TAU * 8.0
			var i0 := int(angle) % 8
			var edge := radius * lerpf(bumps[i0], bumps[(i0 + 1) % 8], angle - floorf(angle))
			if d.length() > edge:
				continue
			var color: Color = palette[1]
			# 왼쪽 위는 밝게, 오른쪽 아래 가장자리는 그늘
			var light := d.dot(Vector2(-1, -1).normalized()) / maxf(edge, 1.0)
			if light > 0.45:
				color = palette[0]
			elif light < -0.35 and d.length() > edge - 2.0:
				color = palette[2]
			for c in craters:
				if d.distance_to(Vector2(c.x, c.y)) < c.z:
					color = palette[3]
			img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 탄에 맞았을 때 잠깐 보여 주는 흰 실루엣 (같은 모양)
static func asteroid_flash(radius: float, variant: int, golden: bool = false) -> ImageTexture:
	var key := "rock_flash_%d_%d_%s" % [int(radius), variant, golden]
	if not _cache.has(key):
		var img := asteroid(radius, variant, golden).get_image()
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color.WHITE)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## 등급별 광물 그림 (등급마다 모양과 크기가 다름)
static func mineral(grade: int) -> ImageTexture:
	grade = clampi(grade, 0, MINERAL_COLORS.size() - 1)
	var key := "mineral_%d" % grade
	if not _cache.has(key):
		var c: Array = MINERAL_COLORS[grade]
		_cache[key] = from_pattern(MINERAL_PATTERNS[grade], {"h": c[0], "m": c[1], "s": c[2], "w": Color.WHITE})
	return _cache[key]


## 고대 경비선 (맞으면 흰색)
static func guard(white: bool = false) -> ImageTexture:
	var key := "guard_%s" % white
	if not _cache.has(key):
		var c: Array = GUARD_COLORS
		var colors := {"g": c[0], "#": c[1], "d": c[2], "c": c[3]}
		if white:
			colors = {"g": Color.WHITE, "#": Color.WHITE, "d": Color.WHITE, "c": Color.WHITE}
		_cache[key] = from_pattern(GUARD_PATTERN, colors)
	return _cache[key]


## 우주 해파리 몸통 (맞으면 흰색)
static func jelly_bell(white: bool = false) -> ImageTexture:
	var key := "jelly_%s" % white
	if not _cache.has(key):
		var c: Array = JELLY_COLORS
		var colors := {"h": c[0], "m": c[1], "c": c[3]}
		if white:
			colors = {"h": Color.WHITE, "m": Color.WHITE, "c": Color.WHITE}
		_cache[key] = from_pattern(JELLY_BELL, colors)
	return _cache[key]


## 날벌레 프레임 (0 날개 펼침, 1 접음)
static func bug(frame: int, white: bool = false) -> ImageTexture:
	var key := "bug_%d_%s" % [frame, white]
	if not _cache.has(key):
		var colors := {"b": BUG_COLORS[0], "e": BUG_COLORS[1], "w": BUG_COLORS[2]}
		if white:
			colors = {"b": Color.WHITE, "e": Color.WHITE, "w": Color.WHITE}
		_cache[key] = from_pattern(BUG_FRAMES[frame % 2], colors)
	return _cache[key]


# ── 워프 게이트 (광부 조합이 설치한 기계식 고리) ───────
## 고리는 45도마다 한 조각씩 8조각. 0·90·180·270도(짝수 번호)는 노랑·검정 경고 줄무늬가 있는 두꺼운 집게,
## 나머지는 리벳과 통풍구가 있는 장갑판. 조각마다 따로 그려서 모여 맞물리고 떨어져 나가는 연출에 쓴다.
## 그림 크기(정사각형 한 변), 고리 안쪽·바깥쪽 반지름, 집게 바깥쪽 반지름 (픽셀)
const GATE_TEX_SIZE := 68
const GATE_RING_IN := 22.0
const GATE_RING_OUT := 30.0
const GATE_CLAMP_OUT := 33.0
const GATE_SEGMENTS := 8
## 금속 색: 밝은 면, 기본, 어두운 면, 윤곽
const GATE_METAL := [Color("#a3a9bd"), Color("#6f748a"), Color("#4a4e63"), Color("#202234")]
## 경고 줄무늬 (노랑, 검정)
const GATE_HAZARD := [Color("#f2b630"), Color("#2b2b38")]


## 고리 조각 하나 (index 0 = 오른쪽, 시계 방향으로 45도씩). 게이트 가운데가 그림 가운데다.
static func gate_segment(index: int) -> ImageTexture:
	var key := "gate_%d" % index
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(GATE_TEX_SIZE, GATE_TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(GATE_TEX_SIZE, GATE_TEX_SIZE) / 2.0
	var step := TAU / GATE_SEGMENTS
	var is_clamp := index % 2 == 0
	for y in GATE_TEX_SIZE:
		for x in GATE_TEX_SIZE:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var r := p.length()
			var a := p.angle()
			if posmod(roundi(a / step), GATE_SEGMENTS) != index:
				continue
			var d := wrapf(a - index * step, -PI, PI)  # 조각 가운데에서 벗어난 각도
			var arc := absf(d) * r  # 조각 가운데에서 둘레를 따라 떨어진 거리
			var half := step / 2.0 * r
			if arc > half - 0.8:
				continue  # 조각 사이 이음새 틈
			var wide := is_clamp and absf(d) < deg_to_rad(13.0)
			var outer := GATE_CLAMP_OUT if wide else GATE_RING_OUT
			if r < GATE_RING_IN or r > outer:
				continue
			var c: Color
			if r < GATE_RING_IN + 1.0 or r > outer - 1.0 or arc > half - 1.8:
				c = GATE_METAL[3]  # 윤곽
			else:
				# 왼쪽 위에서 빛이 온다: 바깥쪽 가장자리가 밝고 안쪽이 어둡다
				var lit := p.normalized().dot(Vector2(-0.6, -0.8))
				c = GATE_METAL[1]
				if r > outer - 2.5 and lit > -0.3:
					c = GATE_METAL[0]
				elif r < GATE_RING_IN + 1.8 or lit < -0.75:
					c = GATE_METAL[2]
				if wide and r > GATE_RING_OUT - 4.0 and r < outer - 1.5 and absf(d) < deg_to_rad(10.0):
					c = GATE_HAZARD[(floori((x + y) / 2.0)) % 2]  # 경고 줄무늬
				elif not is_clamp and absf(r - 26.0) < 0.8 and absf(arc - 12.0 * r * PI / 180.0) < 0.9:
					c = GATE_METAL[0]  # 리벳
				elif not is_clamp and r > 23.5 and r < 25.5 and absf(d) < deg_to_rad(9.0) and int(arc) % 2 == 0:
					c = GATE_METAL[3]  # 통풍구
			img.set_pixel(x, y, c)
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## 고리 표시등 자리 [{pos(게이트 가운데 기준), clamp(집게 표시등인지)}]: 장갑판마다 청록 1개, 집게마다 주황 2개
static func gate_lights() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var step := TAU / GATE_SEGMENTS
	for i in GATE_SEGMENTS:
		if i % 2 == 0:
			for side in [-1.0, 1.0]:
				result.append({"pos": Vector2.from_angle(i * step + side * deg_to_rad(18.0)) * 26.0, "clamp": true, "segment": i})
		else:
			result.append({"pos": Vector2.from_angle(i * step) * 27.5, "clamp": false, "segment": i})
	return result


# ── 기지 화면 (v0.6.0) ───────────────────────────────
## 착륙해 있는 우주선 (출격 화면 우주선과 같은 모양을 크게 다시 그림). 글자 → 색: SHIP_COLORS + w 하이라이트
const SHIP_LARGE_PATTERN := [
	"...........#...........",
	"..........###..........",
	"..........#c#..........",
	".........##c##.........",
	".........#ccc#.........",
	".........#cwc#.........",
	".........#ddd#.........",
	"........##ddd##........",
	"........#ddddd#........",
	".......##ddddd##.......",
	".....#####ddd#####.....",
	"...####w##ddd##w####...",
	".######d##ddd##d######.",
	"##..###d#ddddd#d###..##",
	"#....##d#.ddd.#d##....#",
	".....#d#...d...#d#.....",
	"....##...........##....",
]
## 우주복 조종사 (5x8). 글자 → 색: s 우주복, v 헬멧 창, d 어두운 부분, o 등 뒤 산소통
const PILOT_PATTERN := [
	".sss.",
	"svvvs",
	"svvvs",
	".sss.",
	"osssd",
	"osssd",
	".s.s.",
	".d.d.",
]
const PILOT_COLORS := {"s": Color("#e8ecf6"), "v": Color("#4fd1ff"), "d": Color("#8a90a8"), "o": Color("#ff9a2e")}
## 연구소 카드 아이콘 (9x9). 글자 → 색: a 밝은, b 기본, c 어두운
const UPGRADE_ICON_PATTERNS := {
	"damage": [  # 탄환
		"....a....", "...aab...", "...abb...", "...abb...", "...abb...",
		"...abb...", "..ccccc..", "..cbbbc..", "..ccccc..",
	],
	"max_hp": [  # 하트
		".........", ".aa...bb.", "aabb.bbbc", "abbbbbbbc", "bbbbbbbbc",
		".bbbbbbc.", "..bbbbc..", "...bbc...", "....c....",
	],
	"speed": [  # 겹친 화살표
		".........", "a...a....", ".a...a...", "..a...a..", "...b...b.",
		"..b...b..", ".c...c...", "c...c....", ".........",
	],
	"cargo": [  # 상자
		".........", "aaaaaaaaa", "abbbbbbbc", "abcbbbcbc", "abbcbcbbc",
		"abbbcbbbc", "abbcbcbbc", "abcbbbcbc", "ccccccccc",
	],
	"insurance": [  # 방패
		"aaaaaaaab", "abbbbbbbc", "abbbabbbc", "abbaaabbc", "abbbabbbc",
		".abbbbbc.", ".abbbbbc.", "..abbbc..", "....c....",
	],
	"magnet": [  # 말굽 자석
		".bbbbbbb.", "bbbbbbbbb", "bbc...cbb", "bb.....bb", "bb.....bb",
		"bb.....bb", "aa.....aa", "aa.....aa", ".........",
	],
}
const UPGRADE_ICON_COLORS := {
	"damage": [Color("#ffffff"), Color("#7fe8ff"), Color("#5a6a8a")],
	"max_hp": [Color("#ffd0d0"), Color("#ff5a5a"), Color("#a83232")],
	"speed": [Color("#e8ffd8"), Color("#9dff6a"), Color("#4f9a2e")],
	"cargo": [Color("#ffe6a8"), Color("#c98a3c"), Color("#7a4f1e")],
	"insurance": [Color("#d8f4ff"), Color("#4fa8ff"), Color("#2a5aa8")],
	"magnet": [Color("#e8ecf6"), Color("#ff4d4d"), Color("#a82a2a")],
}
## 자물쇠 (격납고 잠긴 칸, 7x8)
const LOCK_PATTERN := [
	"..aaa..", ".a...a.", ".a...a.", "bbbbbbb", "bbbcbbb", "bbbcbbb", "bbbbbbb", "ccccccc",
]
## ??? 의 포격 (도감 아이콘: 붉은 에너지탄, 7x7)
const BARRAGE_ICON_PATTERN := [
	"..bbb..", ".baaab.", "baaaaab", "baaaaab", "baaaaab", ".baaab.", "..bbb..",
]


static func ship_large() -> ImageTexture:
	if not _cache.has("ship_large"):
		_cache["ship_large"] = from_pattern(SHIP_LARGE_PATTERN, SHIP_COLORS.merged({"w": Color.WHITE}))
	return _cache["ship_large"]


static func pilot() -> ImageTexture:
	if not _cache.has("pilot"):
		_cache["pilot"] = from_pattern(PILOT_PATTERN, PILOT_COLORS)
	return _cache["pilot"]


static func upgrade_icon(id: String) -> ImageTexture:
	var key := "up_" + id
	if not _cache.has(key):
		var c: Array = UPGRADE_ICON_COLORS[id]
		_cache[key] = from_pattern(UPGRADE_ICON_PATTERNS[id], {"a": c[0], "b": c[1], "c": c[2]})
	return _cache[key]


static func lock() -> ImageTexture:
	if not _cache.has("lock"):
		_cache["lock"] = from_pattern(LOCK_PATTERN, {"a": Color("#c8cde0"), "b": Color("#ffcc33"), "c": Color("#8a5a0a")})
	return _cache["lock"]


static func barrage_icon() -> ImageTexture:
	if not _cache.has("barrage_icon"):
		_cache["barrage_icon"] = from_pattern(BARRAGE_ICON_PATTERN, {"a": Color("#ffd0e8"), "b": Color("#ff6aa8")})
	return _cache["barrage_icon"]


## 도감 아이콘 (Discovery.ENTRIES의 id)
static func discovery_icon(id: String) -> Texture2D:
	if id.begins_with("mineral_"):
		return mineral(int(id.substr(8)))
	if id.begins_with("rock_"):
		return asteroid(Balance.ASTEROID_TYPES[int(id.substr(5))]["radius"], 0)
	match id:
		"golden":
			return asteroid(Balance.GOLDEN["radius"], 0, true)
		"jelly":
			return jelly_bell()
		"bug":
			return bug(0)
		"guard":
			return guard()
	return barrage_icon()
