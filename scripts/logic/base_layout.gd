class_name BaseLayout
extends RefCounted
## 기지 화면 배치 (1280x720 기준, 세로는 720x1280 이상).
## 모든 그림은 tools/pixelate.py로 정리한 픽셀 아트이고, 그림 1픽셀 = 화면 PIXEL픽셀로 그린다.
## 건물 크기는 그림 파일 크기에서 읽고(따로 적어 두지 않음), 가운데 위치만 화면 비율로 정한다.
## 가로는 콘셉트 그림 1(위 3채, 가운데 착륙장, 아래 2채), 세로는 그림 2(위 2채, 착륙장, 아래 2채, 맨 아래 1채)를 따른다.

## 그림 1픽셀 = 화면 몇 픽셀 (글자도 픽셀 글꼴 12px의 3배인 36px)
const PIXEL := 3
## 픽셀 글꼴 크기 (Galmuri11 기본 12px × PIXEL)
const FONT_SIZE := 12 * PIXEL
## 그림 폴더
const SPRITE_DIR := "res://assets/sprites/base/"

## 우주선 착륙장과 건물 id (그리는 순서: 위쪽 건물부터)
const IDS := ["research", "hangar", "drone", "ship", "storage", "museum"]
## 건물 이름표
const NAMES := {"ship": "출격", "research": "연구소", "hangar": "격납고", "storage": "광물 창고", "museum": "전시관", "drone": "드론 공장"}
## id → 그림 파일 (착륙장 자리는 착륙장 그림 크기)
const SPRITES := {"ship": "pad", "research": "research", "hangar": "hangar", "storage": "storage", "museum": "museum", "drone": "drone_factory"}
## 위쪽 보유 광물 줄 높이, 아래쪽 버전 글자 줄 높이
const TOP_BAR := 54.0
const BOTTOM_BAR := 48.0
## 이름표 높이 (글자 36 + 위아래 여백)
const LABEL_HEIGHT := 48.0

## 줄 배치: 줄마다 건물을 왼쪽부터 같은 간격으로 놓고, 남는 높이는 줄 사이에 고르게 나눈다.
## 가로는 콘셉트 그림 1(위 3채, 아래 창고·착륙장·전시관), 세로는 그림 2(위 2채, 착륙장, 아래 2채, 맨 아래 1채)를 따른다.
## (기준 해상도가 화면 비율에 맞춰 늘어나므로(expand) 가로는 폭 1280 이상, 세로는 높이 1280 이상이 보장된다)
const LANDSCAPE_ROWS := [["research", "hangar", "drone"], ["storage", "ship", "museum"]]
const PORTRAIT_ROWS := [["research", "hangar"], ["ship"], ["storage", "museum"], ["drone"]]
## 이름표가 그림 밖으로 나오는 높이 (이름표 높이 - 그림에 걸치는 만큼)
const LABEL_OUT := LABEL_HEIGHT - PIXEL * 4

static var _sizes: Dictionary = {}


static func is_portrait(size: Vector2) -> bool:
	return size.y > size.x


## 그림 크기 (그림 픽셀 단위)
static func sprite_size(name: String) -> Vector2:
	if not _sizes.has(name):
		var tex: Texture2D = load(SPRITE_DIR + name + ".png")
		_sizes[name] = tex.get_size()
	return _sizes[name]


## 화면 픽셀 값을 그림 격자(PIXEL의 배수)에 맞춘다
static func snap(v: Vector2) -> Vector2:
	return (v / PIXEL).round() * PIXEL


## id → 그림 자리 Rect2 (화면 픽셀, 격자에 맞춤)
## 줄마다 누르는 자리(그림 + 이름표)의 아래쪽을 맞추고, 남는 높이를 위·사이·아래 틈에 고르게 나눈다.
static func rects(size: Vector2) -> Dictionary:
	var rows: Array = PORTRAIT_ROWS if is_portrait(size) else LANDSCAPE_ROWS
	var heights: Array[float] = []
	var total := 0.0
	for row in rows:
		var h := 0.0
		for id in row:
			h = maxf(h, sprite_size(SPRITES[id]).y * PIXEL + LABEL_OUT)
		heights.append(h)
		total += h
	var gap := maxf(size.y - TOP_BAR - BOTTOM_BAR - total, 0.0) / (rows.size() + 1)
	var result := {}
	var y := TOP_BAR + gap
	for r in rows.size():
		var row: Array = rows[r]
		var bottom: float = y + heights[r]
		for i in row.size():
			var id: String = row[i]
			var s := sprite_size(SPRITES[id]) * PIXEL
			var cx := size.x * (i + 0.5) / row.size()
			# 착륙장은 이름표가 아래에 있으므로 그만큼 위로
			var foot := bottom - (LABEL_OUT if id == "ship" else 0.0)
			result[id] = Rect2(snap(Vector2(cx - s.x / 2.0, foot - s.y)), s)
		y = bottom + gap
	return result


## 이름표 자리: 건물은 위, 착륙장은 아래 (그림 위에 살짝 걸침)
static func label_rect(id: String, rect: Rect2) -> Rect2:
	var y := rect.end.y - PIXEL * 4 if id == "ship" else rect.position.y - LABEL_HEIGHT + PIXEL * 4
	return Rect2(rect.position.x, y, rect.size.x, LABEL_HEIGHT)


## 누르는 자리: 그림 + 이름표 (손가락으로 누르기 쉽게)
static func touch_rect(id: String, rect: Rect2) -> Rect2:
	return rect.merge(label_rect(id, rect))
