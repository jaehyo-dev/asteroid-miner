class_name BaseLayout
extends RefCounted
## 기지 화면 배치: 화면 크기(가로/세로)에 맞춰 우주선 착륙장과 건물 5채의 자리를 정한다.
## 그림 크기는 고정(픽셀 아트가 깨지지 않게)하고, 가운데 위치만 화면 비율로 정한다.
## 가로는 콘셉트 그림 1(가운데 착륙장, 위 3채, 아래 2채), 세로는 그림 2(위 2채, 가운데 착륙장, 아래 2채, 맨 아래 1채)를 따른다.

## 우주선 착륙장과 건물 id (그리는 순서)
const IDS := ["ship", "research", "hangar", "drone", "storage", "museum"]
## 건물 이름표
const NAMES := {"ship": "출격", "research": "연구소", "hangar": "격납고", "storage": "광물 창고", "museum": "전시관", "drone": "드론 공장"}
## 그림 크기 (건물, 착륙장)
const BUILDING_SIZE := Vector2(96, 64)
const PAD_SIZE := Vector2(104, 56)
## 위쪽 보유 광물 줄 높이 (건물이 들어가면 안 되는 곳)
const TOP_BAR := 26.0
## 이름표 높이 (건물 위, 착륙장은 아래)
const LABEL_HEIGHT := 14.0

## 가운데 위치 (화면 비율)
const LANDSCAPE := {
	"research": Vector2(0.17, 0.38), "hangar": Vector2(0.5, 0.3), "drone": Vector2(0.83, 0.38),
	"ship": Vector2(0.5, 0.66), "storage": Vector2(0.2, 0.79), "museum": Vector2(0.8, 0.79),
}
const PORTRAIT := {
	"research": Vector2(0.27, 0.25), "hangar": Vector2(0.73, 0.25), "ship": Vector2(0.5, 0.45),
	"storage": Vector2(0.27, 0.65), "museum": Vector2(0.73, 0.65), "drone": Vector2(0.5, 0.84),
}


static func is_portrait(size: Vector2) -> bool:
	return size.y > size.x


## id → 그림 자리 Rect2 (정수 픽셀)
static func rects(size: Vector2) -> Dictionary:
	var centers: Dictionary = PORTRAIT if is_portrait(size) else LANDSCAPE
	var result := {}
	for id in IDS:
		var s := PAD_SIZE if id == "ship" else BUILDING_SIZE
		result[id] = Rect2(((centers[id] * size) - s / 2.0).round(), s)
	return result


## 이름표 자리: 건물은 위, 착륙장은 아래
static func label_rect(id: String, rect: Rect2) -> Rect2:
	var y := rect.end.y + 2.0 if id == "ship" else rect.position.y - LABEL_HEIGHT - 2.0
	return Rect2(rect.position.x, y, rect.size.x, LABEL_HEIGHT)


## 누르는 자리: 그림 + 이름표 (손가락으로 누르기 쉽게)
static func touch_rect(id: String, rect: Rect2) -> Rect2:
	return rect.merge(label_rect(id, rect))
