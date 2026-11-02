class_name Offscreen
extends RefCounted
## 화면 밖에 있는 대상의 방향 표시 위치 계산 (황금 운석 등).


## 대상이 화면(카메라 중심 center, 크기 view) 밖에 있으면 화면 가장자리 안쪽(margin)의 표시 위치를
## 화면 좌표(왼쪽 위 0,0)로 돌려준다. 화면 안에 보이면 null.
## target_radius만큼은 화면 밖으로 나가도 일부가 보이는 것으로 친다.
static func edge_marker(center: Vector2, target: Vector2, view: Vector2, margin: float, target_radius: float = 0.0) -> Variant:
	var half := view / 2.0
	var rel := target - center
	if absf(rel.x) <= half.x + target_radius and absf(rel.y) <= half.y + target_radius:
		return null  # 화면 안에 보임
	# 화면 가운데에서 대상 방향으로 직선을 그어, 가장자리(여백 안쪽)에 닿는 지점
	var limit := half - Vector2(margin, margin)
	var scale := INF
	if not is_zero_approx(rel.x):
		scale = minf(scale, limit.x / absf(rel.x))
	if not is_zero_approx(rel.y):
		scale = minf(scale, limit.y / absf(rel.y))
	return half + rel * scale
