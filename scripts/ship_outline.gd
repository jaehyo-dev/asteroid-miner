class_name ShipOutline
extends RefCounted
## 우주선 그림 윤곽: 편향 실드의 금빛 테두리에 쓴다 (GAME_SPEC 11번 "편향 실드 표현").
## 8방향마다 몸·엔진·포를 합친 그림 바로 바깥 픽셀(윤곽)과 그 바깥 한 칸(은은한 빛)을 구해 둔다.
## 윤곽은 가운데를 도는 각도 순서라 빛줄기가 차례로 흐를 수 있다.

static var _cache := {}


## 그림(알파 > 0인 곳)의 윤곽과 바깥 빛. 좌표는 칸 가운데 기준. {"line": 윤곽, "glow": 바깥 빛}
static func trace(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var solid := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < w and y < h and img.get_pixel(x, y).a > 0.0
	var line: Array[Vector2i] = []
	var seen := {}
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			if not solid.call(x, y) and (solid.call(x - 1, y) or solid.call(x + 1, y) or solid.call(x, y - 1) or solid.call(x, y + 1)):
				line.append(Vector2i(x, y))
				seen[Vector2i(x, y)] = true
	var glow := PackedVector2Array()
	var half := Vector2(w / 2, h / 2)
	var added := {}
	for p in line:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if not seen.has(q) and not added.has(q) and not solid.call(q.x, q.y):
				added[q] = true
				glow.append(Vector2(q) - half)
	line.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) - half).angle() < (Vector2(b) - half).angle())
	var ordered := PackedVector2Array()
	for p in line:
		ordered.append(Vector2(p) - half)
	return {"line": ordered, "glow": glow}


## 방향별 윤곽. 처음 쓸 때 8방향을 한 번에 계산한다 (방향마다 아틀라스를 다시 읽으면 전투 중 끊긴다)
static func of_dir(dir: int) -> Dictionary:
	if _cache.is_empty():
		var atlas := RunSprites.atlas(0).get_image()
		atlas.convert(Image.FORMAT_RGBA8)
		var c: int = RunSprites.CELL["ship"]
		for d in 8:
			var merged := Image.create(c, c, false, Image.FORMAT_RGBA8)
			for part in ["ship", "ship_engine", "ship_cannon"]:
				var r := RunSprites.region(part, 0, d)
				var e: Array = RunAtlas.ENTRIES[part]
				r.position += Vector2(e[1], e[2])
				merged.blend_rect(atlas, Rect2i(r), Vector2i.ZERO)
			_cache[d] = trace(merged)
	return _cache[posmod(dir, 8)]
