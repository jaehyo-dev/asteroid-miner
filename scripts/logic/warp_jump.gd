class_name WarpJump
extends RefCounted
## 워프 점프 연출의 시간표 (그리기와 분리해 자동 테스트). 수치는 Juice.WARP_*.
## 기지: 이륙 → 충전 → 점프 / 출격 화면: 터널 → 도착. 합쳐서 3~4초.

enum Phase { TAKEOFF, CHARGE, JUMP, DONE }

const BASE_TIME := Juice.WARP_TAKEOFF_TIME + Juice.WARP_CHARGE_TIME + Juice.WARP_JUMP_TIME
const RUN_TIME := Juice.WARP_TUNNEL_TIME + Juice.WARP_ARRIVE_TIME
const TOTAL_TIME := BASE_TIME + RUN_TIME


static func phase(t: float) -> Phase:
	if t < Juice.WARP_TAKEOFF_TIME:
		return Phase.TAKEOFF
	if t < Juice.WARP_TAKEOFF_TIME + Juice.WARP_CHARGE_TIME:
		return Phase.CHARGE
	return Phase.JUMP if t < BASE_TIME else Phase.DONE


## 떠오른 정도 0~1 (탑승 뒤 시작, 처음엔 빠르고 멈추듯 감속)
static func lift(t: float) -> float:
	var k := clampf((t - Juice.WARP_BOARD_TIME) / (Juice.WARP_TAKEOFF_TIME - Juice.WARP_BOARD_TIME), 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


## 충전 진행 0~1
static func charge(t: float) -> float:
	return clampf((t - Juice.WARP_TAKEOFF_TIME) / Juice.WARP_CHARGE_TIME, 0.0, 1.0)


## 점프 진행 0~1
static func jump(t: float) -> float:
	return clampf((t - Juice.WARP_TAKEOFF_TIME - Juice.WARP_CHARGE_TIME) / Juice.WARP_JUMP_TIME, 0.0, 1.0)


## 점프로 솟구친 정도 0~1: 점점 빨라진다
static func jump_rise(j: float) -> float:
	return clampf(j, 0.0, 1.0) ** 2.0


## i번째(1부터) 잔상의 진행: 본체보다 i칸만큼 뒤처진다. 0 이하면 아직 출발 전
static func ghost_progress(j: float, i: int) -> float:
	return j - i * Juice.WARP_GHOST_LAG


## i번째 잔상의 진하기: 뒤로 갈수록 옅고, 출발 전이면 0
static func ghost_alpha(j: float, i: int) -> float:
	if ghost_progress(j, i) <= 0.0:
		return 0.0
	return Juice.WARP_GHOST_ALPHA * (1.0 - float(i - 1) / Juice.WARP_GHOSTS)


## 화면 속도선 세기 0~1
static func speed_lines(j: float) -> float:
	return smoothstep(0.0, 0.5, j)


## 기지 화면 흔들림 세기(그림 칸): 떠오를 때 조금, 충전할수록 커짐
static func shake_cells(t: float) -> float:
	if t < Juice.WARP_BOARD_TIME:
		return 0.0
	return (0.25 + charge(t) * charge(t) * 0.75) * Juice.WARP_SHAKE_CELLS


## 기지 화면을 덮는 흰색: 점프 후반에 다 덮는다 (출격 화면의 흰색으로 이어짐)
static func base_white(t: float) -> float:
	return smoothstep(0.3, 1.0, jump(t))


## 출격 화면 쪽 시간 t: 흰색이 빠지고, 도착 순간 다시 잠깐 번쩍인다
static func run_white(t: float) -> float:
	var fade := clampf(1.0 - t / Juice.WARP_WHITE_FADE, 0.0, 1.0)
	var flash := 0.0
	if t >= Juice.WARP_TUNNEL_TIME:
		flash = 0.7 * clampf(1.0 - (t - Juice.WARP_TUNNEL_TIME) / (Juice.WARP_ARRIVE_TIME * 0.4), 0.0, 1.0)
	return maxf(fade, flash)


## 터널 세기 1(빛줄기) → 0(보통 우주): 도착하며 빠르게 사라진다
static func tunnel_strength(t: float) -> float:
	return clampf(1.0 - (t - Juice.WARP_TUNNEL_TIME) / (Juice.WARP_ARRIVE_TIME * 0.5), 0.0, 1.0)


## 도착 진행 0~1
static func arrive(t: float) -> float:
	return clampf((t - Juice.WARP_TUNNEL_TIME) / Juice.WARP_ARRIVE_TIME, 0.0, 1.0)


## 우주선이 앞(위)에서 감속하며 제자리로 돌아오는 그림 오프셋 (y, 픽셀). 터널 동안은 0
static func arrive_slide(t: float) -> float:
	if t < Juice.WARP_TUNNEL_TIME:
		return 0.0
	var left := 1.0 - arrive(t)
	return -roundf(left * left * Juice.WARP_ARRIVE_SLIDE)


## HUD가 밀려 들어온 정도 0~1
static func hud_in(t: float) -> float:
	var left := 1.0 - arrive(t)
	return 1.0 - left * left * left


## 착륙 시작의 흰색이 빠지는 정도
static func land_white(t: float) -> float:
	return clampf(1.0 - t / Juice.WARP_LAND_WHITE, 0.0, 1.0)


## 건너뛰기로 치는 누름: 터치, 마우스, 키 (키 반복은 제외)
static func is_skip_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
