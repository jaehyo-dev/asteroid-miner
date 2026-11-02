class_name DangerAlert
extends RefCounted
## 피격·위험 표시 상태 (화면 흔들림, 붉은 번쩍임, 체력 낮음 경고).
## 화면 그리기와 분리해서 "언제 무엇을 보여 주고 경고음을 낼지"를 자동 테스트한다.
## 체력 낮음 경고는 거슬리지 않게 일시적으로만:
## - 처음 LOW_HP_RATIO 밑으로 떨어지면 테두리가 LOW_HP_BORDER_TIME 동안 맥박치고 경고음 한 번
## - 그 뒤에는 체력 막대만 깜빡임 (low 상태)
## - 낮은 체력에서 또 맞으면 테두리가 짧게 다시 붉어지고, 경고음은 LOW_HP_SOUND_COOLDOWN에 한 번만
## - 체력이 LOW_HP_RATIO 위로 회복되면 경고 상태 초기화

## 남은 화면 흔들림 시간
var shake := 0.0
## 남은 붉은 번쩍임 시간
var flash := 0.0
## 남은 테두리 맥박 시간과, 이번 맥박의 전체 길이 (그리기에서 서서히 사라지게)
var border := 0.0
var border_total := 0.0
## 체력 낮음 경고 상태 (체력 막대 깜빡임)
var low := false

var _sound_cooldown := 0.0


## 한 프레임 갱신. hit: 이번 프레임에 맞았는지, hp_ratio: 현재 체력 / 최대 체력.
## 이번 프레임에 경고음을 내야 하면 true.
func update(delta: float, hit: bool, hp_ratio: float) -> bool:
	shake = maxf(shake - delta, 0.0)
	flash = maxf(flash - delta, 0.0)
	border = maxf(border - delta, 0.0)
	_sound_cooldown = maxf(_sound_cooldown - delta, 0.0)
	if hit:
		shake = Balance.HIT_SHAKE_TIME
		flash = Balance.HIT_FLASH_TIME
	if hp_ratio > Balance.LOW_HP_RATIO:
		# 회복되면 경고 상태 초기화 (다음에 떨어지면 다시 "처음"으로 친다)
		low = false
		_sound_cooldown = 0.0
		return false
	if hp_ratio <= 0.0:
		return false  # 파괴되면 경고하지 않는다
	if not low:
		low = true
		_start_border(Balance.LOW_HP_BORDER_TIME)
		_sound_cooldown = Balance.LOW_HP_SOUND_COOLDOWN
		return true
	if hit:
		if border < Balance.LOW_HP_REHIT_BORDER_TIME:
			_start_border(Balance.LOW_HP_REHIT_BORDER_TIME)
		if _sound_cooldown <= 0.0:
			_sound_cooldown = Balance.LOW_HP_SOUND_COOLDOWN
			return true
	return false


## 화면 흔들림 위치: 남은 시간에 비례해 약해진다.
func shake_offset(random: RandomNumberGenerator) -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var strength := Balance.HIT_SHAKE_STRENGTH * shake / Balance.HIT_SHAKE_TIME
	return Vector2(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0)).round() * ceilf(strength)


## 붉은 번쩍임 세기 (0~1)
func flash_strength() -> float:
	return flash / Balance.HIT_FLASH_TIME


## 테두리 맥박 세기 (0~1): 빠르게 맥박치며 끝으로 갈수록 사라진다.
func border_strength(time: float) -> float:
	if border <= 0.0 or border_total <= 0.0:
		return 0.0
	var fade := border / border_total
	return fade * (0.55 + 0.45 * sin(time * TAU * 2.5))


func _start_border(duration: float) -> void:
	border = duration
	border_total = duration
