class_name BaseLayout
extends RefCounted
## 기지 화면 배치 (1280x720 기준, 세로는 720x1280 이상).
## 모든 그림은 tools/pixelate.py로 정리한 픽셀 아트이고, 그림 1픽셀 = 화면 PIXEL픽셀로 그린다.
## (v0.6.3 수정: 건물을 화면 폭의 약 10%로 줄이면서 3픽셀 격자 → 2픽셀 격자. 3배로 두면 건물이 크거나, 줄이면 그림 픽셀이 뭉개짐)
## 건물 크기는 그림 파일 크기에서 읽고(따로 적어 두지 않음), 가운데 위치만 화면 비율로 정한다.
## 가로는 콘셉트 그림 1(위 3채, 가운데 착륙장, 아래 2채)을 따른다.
## 세로는 소행성(3:4 둥근 모양) 가운데에 착륙장 중심으로 모아 놓는다: 위 2채, 가운데 줄(드론 공장·착륙장·광물 창고), 아래 전시관.

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
## 세로 화면 이름표는 건물을 덜 가리게 더 낮고, 전시관만 건물 아래에 둔다 (착륙장 이름표는 위: 아래에는 길이 지나감)
const PORTRAIT_LABEL_HEIGHT := 28.0
const PORTRAIT_LABEL_BELOW := ["museum"]

## 세로 화면은 줄 배치 (소행성 가운데에 모음): 줄마다 건물을 가운데 기준으로 놓는다.
## 위 줄 2채는 착륙장 위로 길이 올라가고, 가운데 줄은 착륙장 양옆, 맨 아래 전시관은 착륙장 아래로 길이 내려간다.
## (기준 해상도가 화면 비율에 맞춰 늘어나므로(expand) 가로는 폭 720 이상, 세로는 높이 1280 이상이 보장된다)
const PORTRAIT_ROWS := [["research", "hangar"], ["drone", "ship", "storage"], ["museum"]]
## 같은 줄 건물 사이 간격 (가운데 줄은 착륙장과 건물 사이: 길·가로등이 들어갈 만큼)
const PORTRAIT_SIDE_GAP := 36.0
const PORTRAIT_TOP_ROW_GAP := 40.0
## 줄 사이 간격: 위 줄 아래 → 가운데 줄에서 가장 높은 건물, 가운데 줄 아래 → 전시관 위
const PORTRAIT_ROW_GAPS := [76.0, 64.0]
## 건물 덩어리의 세로 중심을 화면 중심에서 아래로 내리는 양 (소행성이 아래쪽이 더 넓음)
const PORTRAIT_SHIFT_Y := 24.0

## 가로 화면 배치 (승인된 콘셉트 v0.6.3, 1280x720 무대 기준): id → [가운데 x, 그림 아래 y]
## 무대는 화면 가운데에 놓이고, 더 큰 화면은 별 배경이 채운다. 소행성이 화면의 약 75%로 줄어든 만큼 콘셉트 배치(건물 사이 비율)를 같은 비율로 소행성 중심에 모았다.
const STAGE := Vector2(1280, 720)
const LANDSCAPE_POS := {
	"research": [370, 305], "hangar": [620, 271], "drone": [879, 307],
	"ship": [623, 426], "storage": [366, 507], "museum": [874, 512],
}

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
	if not is_portrait(size):
		var off := (size - STAGE) / 2.0
		var out := {}
		for id in IDS:
			var pos: Array = LANDSCAPE_POS[id]
			var s := sprite_size(SPRITES[id]) * PIXEL
			out[id] = Rect2(snap(off + Vector2(pos[0] - s.x / 2.0, pos[1] - s.y)), s)
		return out
	return _portrait_rects(size)


## 세로 배치: 위 줄 / 가운데 줄(드론 공장·착륙장·광물 창고) / 전시관을 화면 가운데에 모아 놓는다.
static func _portrait_rects(size: Vector2) -> Dictionary:
	var out_top := PORTRAIT_LABEL_HEIGHT - PIXEL * 4  # 이름표가 그림 위로 나오는 높이
	var heights: Array[float] = []
	for row in PORTRAIT_ROWS:
		var h := 0.0
		for id in row:
			h = maxf(h, sprite_size(SPRITES[id]).y * PIXEL)
		heights.append(h)
	var total := out_top + heights[0] + PORTRAIT_ROW_GAPS[0] + heights[1] + PORTRAIT_ROW_GAPS[1] + heights[2] + out_top
	var cx := size.x / 2.0
	var pad_w := sprite_size(SPRITES["ship"]).x * PIXEL
	var y := size.y / 2.0 + PORTRAIT_SHIFT_Y - total / 2.0 + out_top  # 위 줄 그림의 윗면
	var result := {}
	for r in PORTRAIT_ROWS.size():
		var row: Array = PORTRAIT_ROWS[r]
		var bottom := y + heights[r]
		for id in row:
			var s := sprite_size(SPRITES[id]) * PIXEL
			var x := cx
			if r == 0:
				# 위 줄: 가운데 틈을 두고 양옆으로
				x += (-1.0 if id == row[0] else 1.0) * (PORTRAIT_TOP_ROW_GAP / 2.0 + s.x / 2.0)
			elif id != "ship" and r == 1:
				x += (-1.0 if id == row[0] else 1.0) * (pad_w / 2.0 + PORTRAIT_SIDE_GAP + s.x / 2.0)
			result[id] = Rect2(snap(Vector2(x - s.x / 2.0, bottom - s.y)), s)
		if r < PORTRAIT_ROW_GAPS.size():
			y = bottom + PORTRAIT_ROW_GAPS[r]
	return result


## 이름표 자리: 가로는 건물 위, 착륙장은 아래 (그림에 살짝 걸침).
## 세로는 모두 위, 전시관만 아래 (착륙장 아래로는 길이 지나가서). 세로 이름표는 더 낮다.
static func label_rect(id: String, rect: Rect2, portrait: bool = false) -> Rect2:
	var h := PORTRAIT_LABEL_HEIGHT if portrait else LABEL_HEIGHT
	var below: bool = id in PORTRAIT_LABEL_BELOW if portrait else id == "ship"
	var y := rect.end.y - PIXEL * 4 if below else rect.position.y - h + PIXEL * 4
	return Rect2(rect.position.x, y, rect.size.x, h)


## 누르는 자리: 그림 + 이름표 (손가락으로 누르기 쉽게)
static func touch_rect(id: String, rect: Rect2, portrait: bool = false) -> Rect2:
	return rect.merge(label_rect(id, rect, portrait))
