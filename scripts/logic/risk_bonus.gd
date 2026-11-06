class_name RiskBonus
extends RefCounted
## 광물 보너스 표시: 위험도 배율(RunSim.risk_mult)을 "+40%" 같은 보너스로 보여 주기 위한 계산.
## 게임 규칙(배율 자체)은 RunSim에 있고, 여기서는 표시용 값과 "보너스가 올랐는지"만 다룬다.

## 보너스가 이만큼(%) 오를 때마다 글자가 잠깐 커진다 (말풍선은 처음 +1%가 될 때, run.gd).
## 표시는 1% 단위로 계속 오르지만, 3초마다 커지면 산만해서 10% 단위로만 알린다.
const STEP_PERCENT := 10
## 올랐을 때 글자가 커졌다 돌아오는 시간
const PULSE_TIME := 0.45

## 마지막으로 알린 단계 (STEP_PERCENT 몇 번째인지)
var shown_step := 0
## 커졌다 돌아오는 연출의 남은 시간
var pulse := 0.0


## 출격 후 t초의 광물 보너스 (%, 내림): x1.40 → 40
static func percent(t: float) -> int:
	return floori((RunSim.risk_mult(t) - 1.0) * 100.0 + 0.000001)


## 보너스 0(시작) ~ 1(최대) 비율 (색 바꾸기용)
static func ratio(t: float) -> float:
	return clampf((RunSim.risk_mult(t) - 1.0) / maxf(Balance.RISK_MAX - 1.0, 0.001), 0.0, 1.0)


## 보너스를 적용한 가치 (주울 때 떠오르는 숫자): 가치 × 배율 (반올림)
static func applied(value: int, t: float) -> int:
	return roundi(value * RunSim.risk_mult(t))


## 시간 진행. 보너스가 새 단계에 오르면 true (그때 커지는 연출을 시작한다).
func update(delta: float, t: float) -> bool:
	pulse = maxf(pulse - delta, 0.0)
	var step := percent(t) / STEP_PERCENT
	if step <= shown_step:
		return false
	shown_step = step
	pulse = PULSE_TIME
	return true


## 지금 글자 크기 배율: 오른 순간 1 → 1.4 → 1로 부드럽게
func scale() -> float:
	return 1.0 + 0.4 * sin(PI * (1.0 - pulse / PULSE_TIME)) if pulse > 0.0 else 1.0
