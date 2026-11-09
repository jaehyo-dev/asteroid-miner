class_name BaseLayout
extends RefCounted
## 기지 정거장 배치: 네모 격자 칸 ↔ 건물, 칸 → 좌표, 지도 끝, 끌어서 둘러보기 범위. 화면·노드와 분리된 계산만 둔다.
## 단위는 "그림 픽셀": 화면은 정수 배율(PC 2배, 폰 1배)로 키우고 그림 1픽셀 = 격자 1칸이다 (App.base_pixel_scale).
## PC와 폰이 같은 칸 배치를 쓴다 (건물 이름 글자도 같은 12px이라 칸 안 자리가 화면 크기에 따라 달라지지 않는다).
## 좌표계: 착륙장 가운데가 원점인 지도 좌표. BaseView가 그리고, 버튼도 같은 좌표에 놓는다.

## 건물 안 화면(BasePanel)과 안내 문구는 읽기 편하게 따로 3배 격자 (풍경과 따로 놓인 화면)
const UI_PIXEL := 3
const UI_FONT_SIZE := 12 * UI_PIXEL
const SPRITE_DIR := "res://assets/sprites/station/"
## 연구소 부품·광물 더미·조종사 그림 (v0.6 그림을 그대로 씀)
const OLD_SPRITE_DIR := "res://assets/sprites/base/"

## 우주선 착륙장과 건물 id
const IDS := ["research", "hangar", "drone", "ship", "storage", "museum"]
## 건물 이름표
const NAMES := {"ship": "착륙장", "research": "연구소", "hangar": "격납고", "storage": "광물 금고", "museum": "전시관", "drone": "드론 공장"}
## 건물 ↔ 칸 (열, 행). 착륙장은 0열 위아래 3칸을 차지한다
const CELLS := {"research": Vector2i(-1, -1), "hangar": Vector2i(1, -1), "drone": Vector2i(-1, 0), "museum": Vector2i(1, 0), "storage": Vector2i(-1, 1)}
const PAD_ROWS := [-1, 0, 1]
## 건물이 늘어날 때 채우는 칸 순서 (앞쪽 빈 칸 EMPTY_SHOWN개만 "건설 예정"으로 보인다).
## 1칸만 보여야 건물 5채일 때 정거장이 가운데 3열에 들어와 한 화면에 다 보인다 (계획서 34번 1, 32번 규칙 4)
const NEXT_SLOTS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(2, -1), Vector2i(-2, -1), Vector2i(2, 1), Vector2i(-2, 1)]
const EMPTY_SHOWN := 1
## 임시 건물 5채를 더한 디버그 모습 (App.base_debug_busy, 웹 주소 ?base10). 8종뿐이라 2채는 연구소·창고 그림을 다시 쓴다
const DEBUG_EXTRA := {"weapon": Vector2i(1, 1), "planet": Vector2i(2, -1), "evolve": Vector2i(2, 0), "research": Vector2i(-2, -1), "storage": Vector2i(-2, 0)}
const DEBUG_NAMES := {"weapon": "보조 무기 연구소", "planet": "행성 관제소", "evolve": "진화 도감 실험실", "research": "연구소", "storage": "광물 금고"}

## 칸 간격: 착륙장 + 둘레 6칸 + 양옆 소행성 가장자리가 640x360 한 화면에 들어온다
const PITCH := Vector2i(148, 105)
## 갑판 크기 (tools/bake_base.py가 구운 크기)
const PLATE := Vector2i(128, 88)
## 건물 그림이 칸 가운데보다 아래로 내려오는 양. 그 아래가 이름 글자를 놓는 갑판 앞 턱이다
const BUILD_FOOT := 22
## 건물 이름 글자 크기, 글자 테두리 두께, 글자 칸과 갑판 아래 끝 사이 (앞 턱 맨 아래 어두운 줄을 피함)
const NAME_FONT_SIZE := 12
const NAME_OUTLINE := 2
const NAME_BOTTOM_GAP := 3
## 착륙장 고리 누르는 자리 (착륙장 전체를 누르면 실수로 출격하기 쉬워 가운데만)
const RING_TOUCH := Vector2i(96, 96)
## 지도 끝 여유: 둘레 띠 바깥으로 돌과 꾸밈이 보이는 폭 (꾸밈 그림까지 들어오는 최소값)
const MAP_MARGIN := Vector2i(50, 12)
## 땅 그림 크기 (tools/bake_base.py): 가운데 3열이면 가장자리가 보이는 작은 소행성, 더 넓으면 큰 소행성
const GROUND_SMALL := Vector2i(620, 480)
## 첫 화면에서 착륙장을 아래로 내리는 양 (위쪽 바 몫)
const CENTER_DROP := 8


## 칸 가운데 (지도 좌표)
static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * PITCH)


## 가운데 3열 안의 정거장이면 작은 소행성 위에 놓인다
static func fits_small_ground(cells: Array[Vector2i]) -> bool:
	return cells.all(func(c: Vector2i) -> bool: return absi(c.x) <= 1)


## 건설 예정 칸: 건물이 없는 NEXT_SLOTS 앞쪽 count개
static func next_slots(built: Array, count: int = EMPTY_SHOWN) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for s in NEXT_SLOTS:
		if not built.has(s) and out.size() < count:
			out.append(s)
	return out


## 정거장 칸 전체: 건물 + 임시 건물 + 건설 예정 + 착륙장 3칸
static func station_cells(busy: bool) -> Array[Vector2i]:
	var built: Array = CELLS.values()
	if busy:
		built.append_array(DEBUG_EXTRA.values())
	var out: Array[Vector2i] = []
	for c in built:
		out.append(c)
	out.append_array(next_slots(built))
	for r in PAD_ROWS:
		out.append(Vector2i(0, r))
	return out


## 칸 하나가 차지하는 둘레 사각형 (이웃 칸과 빈틈없이 닿는다)
static func cell_block(cell: Vector2i) -> Rect2:
	var p := Vector2(PITCH)
	return Rect2(cell_center(cell) - p / 2.0, p)


## 정거장 맨 바깥 둘레 선분: 이웃이 없는 칸 변만. [시작, 끝, 변 방향(Vector2i: 위 (0,-1) 등)]
static func outline(cells: Array[Vector2i]) -> Array:
	var out := []
	for c in cells:
		var r := cell_block(c)
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if cells.has(c + d):
				continue
			match d:
				Vector2i.UP:
					out.append([r.position, Vector2(r.end.x, r.position.y), d])
				Vector2i.DOWN:
					out.append([Vector2(r.position.x, r.end.y), r.end, d])
				Vector2i.LEFT:
					out.append([r.position, Vector2(r.position.x, r.end.y), d])
				Vector2i.RIGHT:
					out.append([Vector2(r.end.x, r.position.y), r.end, d])
	return out


## 지도 전체 사각형: 둘레 + 여유
static func map_rect(cells: Array[Vector2i]) -> Rect2:
	var r := cell_block(cells[0])
	for c in cells:
		r = r.merge(cell_block(c))
	return r.grow_individual(MAP_MARGIN.x, MAP_MARGIN.y, MAP_MARGIN.x, MAP_MARGIN.y)


## 건물 그림 자리. 그림 아래 가운데가 칸 가운데 + BUILD_FOOT
static func building_rect(cell: Vector2i, sprite: Vector2) -> Rect2:
	var foot := cell_center(cell) + Vector2(0, BUILD_FOOT)
	return Rect2((foot - Vector2(sprite.x / 2.0, sprite.y)).round(), sprite)


## 갑판 자리
static func plate_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_center(cell) - Vector2(PLATE) / 2.0, PLATE)


## 이름 글자 자리: 갑판 앞 턱 가운데. text는 글자 테두리까지 포함한 크기
static func name_rect(cell: Vector2i, text: Vector2) -> Rect2:
	var p := plate_rect(cell)
	return Rect2(((p.position + p.end) / 2.0).x - text.x / 2.0, p.end.y - NAME_BOTTOM_GAP - text.y, text.x, text.y)


## 누르는 자리 (지도 좌표)
static func touch_rect(id: String) -> Rect2:
	if id == "ship":
		return Rect2(-Vector2(RING_TOUCH) / 2.0, RING_TOUCH)
	var p := plate_rect(CELLS[id])
	var h := float(PITCH.y)  # 건물 지붕까지 누를 수 있게 위로 늘리되 윗칸과 겹치지 않게
	return Rect2(p.position.x, p.end.y - h, p.size.x, h)


## 화면 가운데에 착륙장을 둘 때 지도 원점의 화면 위치
static func center_origin(view: Vector2) -> Vector2:
	return (view / 2.0).floor() + Vector2(0, CENTER_DROP)


## 끌기 범위: cam은 첫 화면에서 옮긴 양. 지도 끝이 화면 끝에 닿으면 멈춘다. 지도가 화면보다 작은 쪽은 0 (착륙장이 가운데인 채로).
static func clamp_cam(cam: Vector2, map: Rect2, view: Vector2) -> Vector2:
	var o := center_origin(view)
	var lo := Vector2(minf(view.x - o.x - map.end.x, 0.0), minf(view.y - o.y - map.end.y, 0.0))
	var hi := Vector2(maxf(-o.x - map.position.x, 0.0), maxf(-o.y - map.position.y, 0.0))
	return Vector2(clampf(cam.x, lo.x, hi.x), clampf(cam.y, lo.y, hi.y)).round()


## 끌어서 볼 곳이 있는지 (안내를 띄울지)
static func can_pan(map: Rect2, view: Vector2) -> bool:
	var big := Vector2(1e6, 1e6)
	return clamp_cam(big, map, view) != Vector2.ZERO or clamp_cam(-big, map, view) != Vector2.ZERO


## rect(지도 좌표)가 화면에 보이도록 cam을 최소한으로 옮긴다 (키보드로 화면 밖 건물을 고를 때)
static func reveal_cam(cam: Vector2, rect: Rect2, map: Rect2, view: Vector2, top: float, bottom: float) -> Vector2:
	var o := center_origin(view) + cam
	var c := cam
	c.x += maxf(-(o.x + rect.position.x), 0.0) + minf(view.x - (o.x + rect.end.x), 0.0)
	c.y += maxf(top - (o.y + rect.position.y), 0.0) + minf(view.y - bottom - (o.y + rect.end.y), 0.0)
	return clamp_cam(c, map, view)


## 출격 버튼 자리: 착륙장 앞(anchor)을 따라다니되 화면 안(위아래 바 사이)에 남는다
static func sortie_pos(anchor: Vector2, button: Vector2, view: Vector2, top: float, bottom: float) -> Vector2:
	return Vector2(clampf(anchor.x - button.x / 2.0, 4.0, view.x - button.x - 4.0), clampf(anchor.y - button.y, top, view.y - bottom - button.y)).round()
