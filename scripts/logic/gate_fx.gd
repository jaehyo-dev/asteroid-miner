class_name GateFx
extends RefCounted
## 워프 게이트 연출의 시간 흐름 (그리기와 분리해 자동 테스트할 수 있게 함). 게임 규칙은 바꾸지 않는다.
## 등장: 흩어진 조각이 모여 맞물림(ASSEMBLE_TIME) → 섬광과 함께 소용돌이가 열림(OPEN_TIME)
## 닫히기 직전(CLOSING_TIME 남음): 붉게 변하고 떨림 / 닫힘: 조각이 흩어지며 사라짐(COLLAPSE_TIME)
## 귀환 성공: 우주선이 잔상을 남기며 빨려 들어감(SUCK_TIME) → 화면이 하얗게 번쩍임 → 결과 화면(WARP_TOTAL)

const ASSEMBLE_TIME := 0.6
const OPEN_TIME := 0.3
const FLASH_TIME := 0.25
const CLOSING_TIME := 3.0
const COLLAPSE_TIME := 0.5
const SUCK_TIME := 0.7
const WHITE_TIME := 0.45
const WARP_TOTAL := SUCK_TIME + WHITE_TIME
## 소용돌이 회전 빠르기 (라디안/초): 평소 → 충전이 끝날 때
const SPIN_SPEED := 1.2
const SPIN_SPEED_CHARGED := 9.0

## 게이트가 열린 뒤 지난 시간 (-1이면 등장 연출 없음)
var appear := -1.0
## 게이트가 닫힌 뒤 지난 시간 (-1이면 닫힘 연출 없음)
var collapse := -1.0
## 귀환한 뒤 지난 시간 (-1이면 아직)
var warp := -1.0
## 소용돌이 회전 각 (빠르기가 바뀌어도 끊기지 않게 누적)
var spin := 0.0
var _closing_announced := false


## 시간을 진행한다. 게임 이벤트(RunSim.events)를 받아 연출을 시작하고,
## 연출 이벤트 "gate_locked"(조각이 맞물림), "gate_closing"(닫히기 직전 시작)을 돌려준다.
func step(delta: float, gate: WarpGate, events: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	if events.has("gate_open"):
		appear = 0.0
		collapse = -1.0
		_closing_announced = false
	elif appear >= 0.0:
		var before := appear
		appear += delta
		if before < ASSEMBLE_TIME and appear >= ASSEMBLE_TIME:
			out.append("gate_locked")
	if events.has("gate_close"):
		collapse = 0.0
		appear = -1.0
	elif collapse >= 0.0:
		collapse += delta
		if collapse >= COLLAPSE_TIME:
			collapse = -1.0
	if events.has("warp_done"):
		warp = 0.0
	elif warp >= 0.0:
		warp += delta
	if gate.state == WarpGate.State.OPEN and heat(gate) > 0.0 and not _closing_announced:
		_closing_announced = true
		out.append("gate_closing")
	if gate.charge >= 0.0:
		_closing_announced = false  # 충전하다 나가서 다시 닫히기 직전이 되면 다시 알린다
	spin += lerpf(SPIN_SPEED, SPIN_SPEED_CHARGED, gate.charge_progress()) * delta
	return out


## 조각이 모인 정도 0(흩어짐) ~ 1(맞물림). 처음엔 빠르고 끝에 천천히 (맞물리는 느낌).
func assembled() -> float:
	if appear < 0.0:
		return 1.0
	var k := clampf(appear / ASSEMBLE_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


## 소용돌이가 열린 정도 0~1 (조각이 맞물린 뒤 열리고, 닫힐 때 오므라든다)
func vortex_open() -> float:
	if collapse >= 0.0:
		return clampf(1.0 - collapse / (COLLAPSE_TIME * 0.5), 0.0, 1.0)
	if appear < 0.0:
		return 1.0
	return clampf((appear - ASSEMBLE_TIME) / OPEN_TIME, 0.0, 1.0)


## 맞물리는 순간의 섬광 세기 0~1
func lock_flash() -> float:
	if appear < ASSEMBLE_TIME:
		return 0.0
	return clampf(1.0 - (appear - ASSEMBLE_TIME) / FLASH_TIME, 0.0, 1.0)


## 닫힐 때 조각이 흩어진 정도 0~1 (닫힘 연출이 없으면 -1)
func scatter() -> float:
	return clampf(collapse / COLLAPSE_TIME, 0.0, 1.0) if collapse >= 0.0 else -1.0


## 우주선이 빨려 들어간 정도 0~1
func suck() -> float:
	return clampf(warp / SUCK_TIME, 0.0, 1.0) if warp >= 0.0 else 0.0


## 화면 하얀 번쩍임 0~1: 빨려 들어가는 끝 무렵 확 밝아졌다가 사라진다
func white_flash() -> float:
	if warp < 0.0:
		return 0.0
	var t := warp - SUCK_TIME * 0.8
	if t < 0.0:
		return 0.0
	var rise := SUCK_TIME * 0.2
	return clampf(t / rise, 0.0, 1.0) if t < rise else clampf(1.0 - (t - rise) / WHITE_TIME, 0.0, 1.0)


## 귀환 연출이 끝났는지 (끝나면 결과 화면을 띄운다)
func warp_finished() -> bool:
	return warp >= WARP_TOTAL


## 닫히기 직전 붉은 정도 0~1: 충전 중이 아니고 CLOSING_TIME 안쪽으로 남았을 때 점점 붉어진다
static func heat(gate: WarpGate) -> float:
	if gate.state != WarpGate.State.OPEN or gate.charge >= 0.0:
		return 0.0
	return clampf(1.0 - gate.timer / CLOSING_TIME, 0.0, 1.0) if gate.timer < CLOSING_TIME else 0.0


## 고리 둘레 원형 게이지 0~1: 충전 중이면 충전량, 아니면 닫힐 때까지 남은 시간
static func gauge(gate: WarpGate) -> float:
	if gate.charge >= 0.0:
		return gate.charge_progress()
	return clampf(gate.timer / Balance.GATE_OPEN_TIME, 0.0, 1.0)
