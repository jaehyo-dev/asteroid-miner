class_name BaseLayout
extends RefCounted
## 기지 화면 배치 (가로 고정, 1280x720 기준. 폰도 같은 가로 배치를 쓴다: v0.6.6에서 세로 전용 배치를 없앰).
## 모든 그림은 tools/pixelate.py로 정리한 픽셀 아트이고, 그림 1픽셀 = 화면 PIXEL픽셀로 그린다.
## 건물 폭은 화면 폭의 12~13% (2픽셀 격자, 그림 폭 78~83). 크기는 그림 파일 크기에서 읽고, 가운데 위치만 화면 비율로 정한다.
## 배치는 콘셉트 그림 1(위 3채, 가운데 착륙장, 아래 2채)을 따른다.

## 그림 1픽셀 = 화면 몇 픽셀 (글자도 픽셀 글꼴 12px의 2배인 24px)
const PIXEL := 2
## 픽셀 글꼴 크기 (Galmuri11 기본 12px × PIXEL)
const FONT_SIZE := 12 * PIXEL
## 건물 안 화면(BasePanel)과 안내 문구는 읽기 편하게 따로 3배 격자 (풍경 그림과는 따로 놓인 화면)
const UI_PIXEL := 3
const UI_FONT_SIZE := 12 * UI_PIXEL
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
## 이름표 높이 (글자 24 + 위아래 여백)
const LABEL_HEIGHT := 32.0
## 이름표와 건물 그림 사이 틈
const LABEL_GAP := 2.0
## "곧 개방" 표지와 건물 그림 사이 틈
const SIGN_GAP := 6.0

## 가로 화면 배치 (승인된 콘셉트 v0.6.3, 1280x720 무대 기준): id → [가운데 x, 그림 아래 y]
## 무대는 화면 가운데에 놓이고, 더 큰 화면은 별 배경이 채운다. 소행성이 화면의 약 75%로 줄어든 만큼 콘셉트 배치(건물 사이 비율)를 같은 비율로 소행성 중심에 모았다.
const STAGE := Vector2(1280, 720)
const LANDSCAPE_POS := {
	"research": [382, 330], "hangar": [620, 271], "drone": [879, 307],
	"ship": [623, 426], "storage": [366, 507], "museum": [874, 512],
}

static var _sizes: Dictionary = {}


## 그림 크기 (그림 픽셀 단위)
static func sprite_size(name: String) -> Vector2:
	if not _sizes.has(name):
		var tex: Texture2D = load(SPRITE_DIR + name + ".png")
		_sizes[name] = tex.get_size()
	return _sizes[name]


## 화면 픽셀 값을 그림 격자(PIXEL의 배수)에 맞춘다
static func snap(v: Vector2) -> Vector2:
	return (v / PIXEL).round() * PIXEL


## id → 그림 자리 Rect2 (화면 픽셀, 격자에 맞춤). 무대(1280x720)를 화면 가운데에 놓는다.
static func rects(size: Vector2) -> Dictionary:
	var off := (size - STAGE) / 2.0
	var out := {}
	for id in IDS:
		var pos: Array = LANDSCAPE_POS[id]
		var s := sprite_size(SPRITES[id]) * PIXEL
		out[id] = Rect2(snap(off + Vector2(pos[0] - s.x / 2.0, pos[1] - s.y)), s)
	return out


## 이름표 자리: 건물 바로 위 (착륙장은 바로 아래). 건물 그림에 걸치지 않는다.
static func label_rect(id: String, rect: Rect2) -> Rect2:
	var y := rect.end.y + LABEL_GAP if id == "ship" else rect.position.y - LABEL_HEIGHT - LABEL_GAP
	return Rect2(rect.position.x, y, rect.size.x, LABEL_HEIGHT)


## 누르는 자리: 그림 + 이름표 (손가락으로 누르기 쉽게)
static func touch_rect(id: String, rect: Rect2) -> Rect2:
	return rect.merge(label_rect(id, rect))


## 드론 공장 "곧 개방" 표지: 건물 그림 바로 아래 오른쪽 끝 (건물·이름표·길과 겹치지 않음)
static func sign_rect(rect: Rect2, text_width: float) -> Rect2:
	var w := text_width + PIXEL * 4.0
	return Rect2(snap(Vector2(rect.end.x - w, rect.end.y + SIGN_GAP)), snap(Vector2(w, PIXEL * 14.0)))
