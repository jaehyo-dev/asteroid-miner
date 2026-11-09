class_name WarpTunnel
extends Control
## 워프 터널 (출격 화면 배경 위, 월드 아래): 별이 세로 빛줄기로 지나가고, 도착하면 충격파 고리가 퍼진다. 코드 효과, 1픽셀 사각형으로 그림.

const COLORS: Array[Color] = [Color("#fef8e5"), Color("#99e9e6"), Color("#30e1b9"), Color("#a884f3")]
const BACK := Color("#070a17")

## 출격 화면에서 지난 시간 (run.gd가 정함)
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var strength := WarpJump.tunnel_strength(t)
	if strength > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(BACK, strength))
		draw_streaks(self, size, t, strength)
	var k := WarpJump.arrive(t)
	if k > 0.0 and k < 1.0:
		var center := (size / 2.0).round()
		var eased := 1.0 - (1.0 - k) * (1.0 - k)
		draw_arc(center, Juice.WARP_RING_RADIUS * eased, 0.0, TAU, 64, Color(COLORS[1], 1.0 - k), 2.0)
		draw_arc(center, Juice.WARP_RING_RADIUS * eased * 0.7, 0.0, TAU, 64, Color(COLORS[0], 0.7 * (1.0 - k)), 1.0)


## 세로 빛줄기 (기지 쪽 점프 속도선도 같은 것을 써서 터널로 이어진다)
static func draw_streaks(ci: CanvasItem, area: Vector2, time: float, strength: float) -> void:
	for i in Juice.WARP_STREAKS:
		# 줄마다 고정된 무작위 값 (i로 계산해 상태가 없음)
		var a := absi(hash(i * 7919))
		var x := float(a % 10000) / 10000.0 * area.x
		var speed := Juice.WARP_STREAK_SPEED * (0.6 + float(a % 97) / 97.0 * 0.8)
		var length := Juice.WARP_STREAK_LEN * (0.4 + float(a % 89) / 89.0) * strength
		var y := fposmod(float(a % 1000) + time * speed, area.y + length) - length
		ci.draw_rect(Rect2(Vector2(x, y).round(), Vector2(1, roundf(length))), Color(COLORS[a % COLORS.size()], (0.35 + float(a % 83) / 83.0 * 0.65) * strength))
