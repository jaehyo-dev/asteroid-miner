class_name PixelArt
extends RefCounted
## 이 프로젝트에서 직접 만든 픽셀 아트 (외부 에셋 없음): 기지 화면 그림·아이콘, 워프 게이트, 8방향 번호 계산.
## 출격 화면의 우주선·운석·적·광물은 팩 그림(RunSprites)으로 바뀌어 여기서 빠졌다 (v0.7.0).
## 문자 패턴으로 텍스처를 만들고, 한 번 만든 것은 재사용한다.

## 기지 화면 큰 우주선 색. 글자 → 색: # 선체, c 조종석, d 어두운 선체
const SHIP_COLORS := {
	"#": Color("#c9d2e8"),
	"c": Color("#4fd1ff"),
	"d": Color("#6c7894"),
}
## 엔진 불꽃 색 (밝은 → 어두운)
const FLAME_COLORS := [Color("#ffe27a"), Color("#ff9a3c")]

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


## 방향 하나의 각도 (8방향 = 45도)
const DIR_STEP := PI / 4.0
## 방향이 경계 근처에서 깜빡이지 않게, 이전 방향을 이만큼(라디안) 더 붙잡아 둔다
const DIR_HYSTERESIS := 0.1


## 회전 각도(0 = 그림 원래 방향, 시계 방향 +)를 가장 가까운 8방향 번호(0~7)로 바꾼다.
## prev(이전 번호)를 주면 경계를 DIR_HYSTERESIS만큼 넘어야 바뀐다.
static func dir8(angle: float, prev: int = -1) -> int:
	if prev >= 0 and absf(angle_difference(angle, prev * DIR_STEP)) < DIR_STEP / 2.0 + DIR_HYSTERESIS:
		return prev
	return posmod(roundi(angle / DIR_STEP), 8)


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
