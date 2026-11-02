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

## 운석 색: 밝은 면, 기본, 그늘, 구멍
const ROCK_COLORS := [Color("#a8957f"), Color("#7a6a5a"), Color("#54483d"), Color("#3e352d")]

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
static func asteroid(radius: float, variant: int) -> ImageTexture:
	var key := "rock_%d_%d" % [int(radius), variant]
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
			var color: Color = ROCK_COLORS[1]
			# 왼쪽 위는 밝게, 오른쪽 아래 가장자리는 그늘
			var light := d.dot(Vector2(-1, -1).normalized()) / maxf(edge, 1.0)
			if light > 0.45:
				color = ROCK_COLORS[0]
			elif light < -0.35 and d.length() > edge - 2.0:
				color = ROCK_COLORS[2]
			for c in craters:
				if d.distance_to(Vector2(c.x, c.y)) < c.z:
					color = ROCK_COLORS[3]
			img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 탄에 맞았을 때 잠깐 보여 주는 흰 실루엣 (같은 모양)
static func asteroid_flash(radius: float, variant: int) -> ImageTexture:
	var key := "rock_flash_%d_%d" % [int(radius), variant]
	if not _cache.has(key):
		var img := asteroid(radius, variant).get_image()
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color.WHITE)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
