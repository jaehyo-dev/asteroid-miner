extends Node
## 효과음 (자동 로드: Sfx). 외부 음원 없이 코드로 8비트 소리를 만들어 쓴다.
## 광물을 주울 때의 등급별 효과음, 체력 낮음 경고음, 습격 경고음, 심연의 포격 충전·발사음이 있다.

const MIX_RATE := 22050
## 효과음 음량 (데시벨)
const VOLUME_DB := -10.0
## 한 소리가 동시에 겹쳐 날 수 있는 최대 수
const MAX_POLYPHONY := 4

## 등급별 줍기 소리: [주파수(Hz), 길이(초)] 음표 목록과 파형
## 일반: 짧고 낮은 딸깍 / 희귀: 맑은 두 음 / 영웅: 올라가는 세 음 / 전설: 화려한 팡파르
const PICKUP_SOUNDS := [
	{"wave": "square", "notes": [[330.0, 0.04]], "volume": 0.25},
	{"wave": "triangle", "notes": [[880.0, 0.05], [1320.0, 0.08]], "volume": 0.5},
	{"wave": "square", "notes": [[660.0, 0.05], [880.0, 0.05], [1175.0, 0.1]], "volume": 0.35},
	{"wave": "square", "notes": [[523.0, 0.07], [659.0, 0.07], [784.0, 0.07], [1047.0, 0.07], [1568.0, 0.3]], "volume": 0.35},
]

## 체력 낮음 경고음: 높낮이를 두 번 오가는 경보
const WARNING_SOUND := {"wave": "square", "notes": [[880.0, 0.09], [620.0, 0.09], [880.0, 0.09], [620.0, 0.12]], "volume": 0.3}

## 습격 경고: 낮게 울리는 경적 두 번
const RAID_SOUND := {"wave": "square", "notes": [[220.0, 0.22], [165.0, 0.22], [220.0, 0.22], [165.0, 0.3]], "volume": 0.3}

## 심연의 포격: 충전(점점 높아지는 웅웅거림, 충전 시간과 같은 길이), 발사(내려가는 짧은 쇳소리)
const CHARGE_SOUND := {"wave": "square", "notes": [[110.0, 0.1], [131.0, 0.1], [156.0, 0.1], [185.0, 0.1], [220.0, 0.1]], "volume": 0.3}
const FIRE_SOUND := {"wave": "square", "notes": [[988.0, 0.03], [740.0, 0.03], [494.0, 0.05]], "volume": 0.25}
## 고대 경비선 발사음: 낮고 짧은 "퉁" (포격보다 작게)
const GUARD_SOUND := {"wave": "triangle", "notes": [[330.0, 0.04], [220.0, 0.06]], "volume": 0.35}

var _pickup_players: Array[AudioStreamPlayer] = []
var _charge_player: AudioStreamPlayer
var _fire_player: AudioStreamPlayer
var _guard_player: AudioStreamPlayer
var _raid_player: AudioStreamPlayer
var _warning_player: AudioStreamPlayer


func _ready() -> void:
	for sound in PICKUP_SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = synth(sound["notes"], sound["wave"], sound["volume"])
		player.volume_db = VOLUME_DB
		player.max_polyphony = MAX_POLYPHONY
		add_child(player)
		_pickup_players.append(player)
	_warning_player = AudioStreamPlayer.new()
	_warning_player.stream = synth(WARNING_SOUND["notes"], WARNING_SOUND["wave"], WARNING_SOUND["volume"])
	_warning_player.volume_db = VOLUME_DB
	add_child(_warning_player)
	_charge_player = _make_player(CHARGE_SOUND)
	_fire_player = _make_player(FIRE_SOUND)
	_guard_player = _make_player(GUARD_SOUND)
	_raid_player = AudioStreamPlayer.new()
	_raid_player.stream = synth(RAID_SOUND["notes"], RAID_SOUND["wave"], RAID_SOUND["volume"])
	_raid_player.volume_db = VOLUME_DB
	add_child(_raid_player)


func _make_player(sound: Dictionary) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = synth(sound["notes"], sound["wave"], sound["volume"])
	player.volume_db = VOLUME_DB
	player.max_polyphony = MAX_POLYPHONY
	add_child(player)
	return player


## 심연의 포격 충전음·발사음
func play_charge() -> void:
	_charge_player.play()


func play_fire() -> void:
	_fire_player.play()


## 고대 경비선 발사음
func play_guard() -> void:
	_guard_player.play()


func guard_stream() -> AudioStreamWAV:
	return _guard_player.stream


## 포격 소리 (테스트용)
func charge_stream() -> AudioStreamWAV:
	return _charge_player.stream


func fire_stream() -> AudioStreamWAV:
	return _fire_player.stream


## 습격 경고음
func play_raid() -> void:
	_raid_player.play()


## 습격 경고음 (테스트용)
func raid_stream() -> AudioStreamWAV:
	return _raid_player.stream


## 체력 낮음 경고음
func play_warning() -> void:
	_warning_player.play()


## 경고음 (테스트용)
func warning_stream() -> AudioStreamWAV:
	return _warning_player.stream


## 광물 등급별 줍기 소리
func play_pickup(grade: int) -> void:
	if grade >= 0 and grade < _pickup_players.size():
		_pickup_players[grade].play()


## 줍기 소리 (테스트용)
func pickup_stream(grade: int) -> AudioStreamWAV:
	return _pickup_players[grade].stream


## 음표 목록으로 16비트 모노 소리를 만든다. 음표마다 짧게 커졌다 줄어드는 음량(엔벨로프)을 준다.
static func synth(notes: Array, wave: String, volume: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for note in notes:
		var freq: float = note[0]
		var length := int(MIX_RATE * float(note[1]))
		for i in length:
			var t := float(i) / MIX_RATE
			var phase := fposmod(t * freq, 1.0)
			var sample := 0.0
			if wave == "triangle":
				sample = 4.0 * absf(phase - 0.5) - 1.0
			else:
				sample = 1.0 if phase < 0.5 else -1.0
			# 앞 5%에서 커지고 뒤로 갈수록 줄어든다 (딸깍 소리 방지)
			var k := float(i) / maxf(length, 1)
			var env := minf(k / 0.05, 1.0) * (1.0 - k)
			var value := int(clampf(sample * env * volume, -1.0, 1.0) * 32767.0)
			data.append(value & 0xFF)
			data.append((value >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
