extends Node
## 효과음 (자동 로드: Sfx). 게임 행동 소리는 assets/sfx/game/의 wav(tools/make_sfx.py)를 play(이름)으로 낸다.
## 게이트·워프·이륙·경고음은 6단계 연출과 함께 다듬을 때까지 코드로 만든 8비트 소리(synth)를 쓴다.

const MIX_RATE := 22050
## 코드로 만든 소리의 음량 (데시벨). Kenney 소리와 크기를 맞춘 값
const VOLUME_DB := -7.0
## 코드로 만든 소리가 동시에 겹쳐 날 수 있는 최대 수
const MAX_POLYPHONY := 4
const SFX_DIR := "res://assets/sfx/game/"

## 효과음 표: 이름 → files(여러 개면 무작위 하나, assets/sfx/game/*.wav), db(음량), pitch(기본 음 높이), jitter(음 높이 랜덤 ±비율), max(동시 재생 수)
## 파일은 tools/make_sfx.py가 Kenney 효과음 팩(CC0)을 다듬거나 직접 합성해 만든다 (wav: 웹에서 ogg보다 재생 시작이 싸다).
## 크기: 자주 나는 발사·맞음은 작게, 큰 운석·피격·레벨업은 크게. 바꾼 소리는 예전 소리와 비슷한 크기(평균 크기 기준)로 맞춤
const SOUNDS := {
	"shoot": {"files": ["shoot_0", "shoot_1"], "db": -14.0, "pitch": 1.0, "jitter": 0.05, "max": 3},
	"hit_rock": {"files": ["hit_rock_0", "hit_rock_1"], "db": -9.0, "pitch": 1.0, "jitter": 0.05, "max": 3},
	# 적이 맞음: 경비선은 금속, 해파리는 둔한 "퉁", 날벌레는 가장 짧고 작은 "틱". 몰리면 run.gd가 작게·적게 낸다
	"hit_guard": {"files": ["hit_guard_0", "hit_guard_1"], "db": -9.0, "pitch": 1.0, "jitter": 0.05, "max": 3},
	"hit_jelly": {"files": ["hit_jelly"], "db": -14.0, "pitch": 1.0, "jitter": 0.05, "max": 2},
	"hit_bug": {"files": ["hit_bug"], "db": -18.0, "pitch": 1.0, "jitter": 0.08, "max": 2},
	# 운석 깨짐: 클수록 낮고 묵직하게 (작음 → 중간 → 큼). 꼬리를 잘라 약 0.3초(큰 것 약 0.5초), 몰리면 run.gd가 작게·적게 낸다
	"break_small": {"files": ["break_small"], "db": -15.0, "pitch": 1.3, "jitter": 0.05, "max": 2},
	"break_mid": {"files": ["break_mid"], "db": -10.0, "pitch": 1.0, "jitter": 0.05, "max": 2},
	"break_big": {"files": ["break_big"], "db": -4.0, "pitch": 0.85, "jitter": 0.03, "max": 2},
	# 적 파괴: 경비선은 묵직한 금속 0.5초, 해파리는 물방울 "뽁", 날벌레는 바삭한 "지직". 몰리면 run.gd가 작게·적게 낸다
	"destroy_guard": {"files": ["destroy_guard"], "db": -10.0, "pitch": 0.9, "jitter": 0.05, "max": 2},
	"destroy_jelly": {"files": ["destroy_jelly"], "db": -14.0, "pitch": 1.0, "jitter": 0.05, "max": 2},
	"destroy_bug": {"files": ["destroy_bug"], "db": -12.0, "pitch": 1.0, "jitter": 0.08, "max": 2},
	# 광물 줍기: 등급마다 음이 다른 종소리 "띠링", 연속으로 주우면 음이 올라가므로 랜덤은 없음
	"pickup_0": {"files": ["pickup_0"], "db": -16.0, "pitch": 1.0, "jitter": 0.0, "max": 2},
	"pickup_1": {"files": ["pickup_1"], "db": -12.0, "pitch": 1.0, "jitter": 0.0, "max": 2},
	"pickup_2": {"files": ["pickup_2"], "db": -11.0, "pitch": 1.0, "jitter": 0.0, "max": 2},
	"pickup_3": {"files": ["pickup_3"], "db": -7.0, "pitch": 1.0, "jitter": 0.0, "max": 2},
	"player_hit": {"files": ["player_hit"], "db": 0.0, "pitch": 1.0, "jitter": 0.05, "max": 1},
	# 실드가 막음
	"shield_block": {"files": ["shield_block"], "db": -12.0, "pitch": 1.0, "jitter": 0.05, "max": 2},
	# 레벨업: 마림바 도-미-솔-도, 마지막 음은 첫 음으로 돌아와 작게 줄어듦
	"levelup": {"files": ["levelup"], "db": -9.5, "pitch": 1.0, "jitter": 0.0, "max": 1},
	# 카드 전용 소리 (tools/make_sfx.py의 CARD_SOUND_DB와 같은 크기)
	"card_flip": {"files": ["card_flip"], "db": -13.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_rare": {"files": ["card_rare"], "db": -14.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_epic": {"files": ["card_epic"], "db": -12.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_unique": {"files": ["card_unique"], "db": -9.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_swell": {"files": ["card_swell"], "db": -13.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_gather": {"files": ["card_gather"], "db": -13.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_legendary": {"files": ["card_legendary"], "db": -8.0, "pitch": 1.0, "jitter": 0.0, "max": 3},
	"card_pick": {"files": ["card_pick"], "db": -10.0, "pitch": 1.0, "jitter": 0.0, "max": 1},
	"click": {"files": ["click"], "db": -8.0, "pitch": 1.0, "jitter": 0.05, "max": 2},
	"open": {"files": ["card_show"], "db": -14.0, "pitch": 1.15, "jitter": 0.0, "max": 1},
	"cargo_heavy": {"files": ["cargo_heavy"], "db": -5.0, "pitch": 0.9, "jitter": 0.0, "max": 1},
	# 심연의 포격: 예고(붉은 조준선이 보일 때, 낮게 웅웅) → 에너지 구체 발사. 높은 소리를 깎아 낮고 둔탁하게, 예전보다 작게
	# 전역 견인 비콘: 레벨업 카드 소리를 낮게
	"beacon": {"files": ["card_show"], "db": -10.0, "pitch": 0.7, "jitter": 0.0, "max": 1},
	"barrage_warn": {"files": ["barrage_warn"], "db": -14.0, "pitch": 1.0, "jitter": 0.0, "max": 2},
	"barrage_fire": {"files": ["barrage_fire"], "db": -10.0, "pitch": 1.0, "jitter": 0.05, "max": 3},
}

## 체력 낮음 경고음: 높낮이를 두 번 오가는 경보
const WARNING_SOUND := {"wave": "square", "notes": [[880.0, 0.09], [620.0, 0.09], [880.0, 0.09], [620.0, 0.12]], "volume": 0.3}

## 습격 경고: 낮게 울리는 경적 두 번
const RAID_SOUND := {"wave": "square", "notes": [[220.0, 0.22], [165.0, 0.22], [220.0, 0.22], [165.0, 0.3]], "volume": 0.3}

## 고대 경비선 발사음: 낮고 짧은 "퉁" (포격보다 작게)
const GUARD_SOUND := {"wave": "triangle", "notes": [[330.0, 0.04], [220.0, 0.06]], "volume": 0.35}
## 워프 게이트·워프 점프 소리 (assets/sfx/game/, tools/make_sfx.py의 gate_sounds): 이름 → 크기(dB)
const WARP_SOUND_DB := {"gate_assemble": -12.0, "gate_lock": -12.0, "gate_hum": -22.0, "gate_alarm": -16.0, "gate_collapse": -11.0,
	"warp_charge": -15.0, "warp_done": -11.0, "takeoff": -11.0, "warp_launch": -13.0, "warp_arrive": -8.0, "landing": -11.0}

## 음 높이 랜덤용 (테스트에서 seed로 고정할 수 있음)
var rng := RandomNumberGenerator.new()
## Kenney 소리 이름 → 불러온 소리 목록 / 재생기 묶음(동시 재생 수만큼)
var _streams := {}
var _pools := {}
var _takeoff_player: AudioStreamPlayer
var _warp_launch_player: AudioStreamPlayer
var _warp_arrive_player: AudioStreamPlayer
var _landing_player: AudioStreamPlayer
var _guard_player: AudioStreamPlayer
var _gate_assemble_player: AudioStreamPlayer
var _gate_lock_player: AudioStreamPlayer
var _gate_hum_player: AudioStreamPlayer
var _gate_alarm_player: AudioStreamPlayer
var _gate_collapse_player: AudioStreamPlayer
var _warp_charge_player: AudioStreamPlayer
var _warp_done_player: AudioStreamPlayer
var _raid_player: AudioStreamPlayer
var _warning_player: AudioStreamPlayer


func _ready() -> void:
	for sound_name in SOUNDS:
		var sound: Dictionary = SOUNDS[sound_name]
		var list: Array[AudioStream] = []
		for f in sound["files"]:
			list.append(load(SFX_DIR + f + ".wav"))
		_streams[sound_name] = list
		var pool: Array[AudioStreamPlayer] = []
		for i in int(sound["max"]):
			var player := AudioStreamPlayer.new()
			player.volume_db = sound["db"]
			add_child(player)
			pool.append(player)
		_pools[sound_name] = pool
	_warning_player = _make_player(WARNING_SOUND)
	_guard_player = _make_player(GUARD_SOUND)
	_gate_assemble_player = _wav_player("gate_assemble")
	_gate_lock_player = _wav_player("gate_lock")
	_gate_hum_player = _wav_player("gate_hum")
	var hum := _gate_hum_player.stream as AudioStreamWAV
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_begin = 0
	hum.loop_end = int(hum.get_length() * hum.mix_rate)  # 압축돼 있을 수 있어 바이트 수로 세지 않는다
	_gate_alarm_player = _wav_player("gate_alarm")
	_gate_collapse_player = _wav_player("gate_collapse")
	_warp_charge_player = _wav_player("warp_charge")
	_warp_done_player = _wav_player("warp_done")
	_takeoff_player = _wav_player("takeoff")
	_warp_launch_player = _wav_player("warp_launch")
	_warp_arrive_player = _wav_player("warp_arrive")
	_landing_player = _wav_player("landing")
	_raid_player = _make_player(RAID_SOUND)
	for child in get_children():
		(child as AudioStreamPlayer).bus = &"SFX"  # 효과음은 모두 효과음 버스로 (설정의 크기 조절)


func _wav_player(sound_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(SFX_DIR + sound_name + ".wav")
	player.volume_db = WARP_SOUND_DB[sound_name]
	player.max_polyphony = MAX_POLYPHONY
	add_child(player)
	return player


func _make_player(sound: Dictionary) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = synth(sound["notes"], sound["wave"], sound["volume"])
	player.volume_db = VOLUME_DB
	player.max_polyphony = MAX_POLYPHONY
	add_child(player)
	return player


## 효과음을 낸다. pitch_jitter: 음 높이 랜덤 ±비율 (음수면 표의 값), pitch: 표의 음 높이에 곱할 배율, db: 표의 음량에 더할 값.
## 같은 소리가 이미 max개 나고 있으면 내지 않고 false를 돌려준다 (한꺼번에 너무 겹치지 않게).
func play(sound_name: String, pitch_jitter: float = -1.0, pitch: float = 1.0, db: float = 0.0) -> bool:
	var sound: Dictionary = SOUNDS[sound_name]
	var jitter: float = sound["jitter"] if pitch_jitter < 0.0 else pitch_jitter
	for player: AudioStreamPlayer in _pools[sound_name]:
		if not player.playing:
			var list: Array = _streams[sound_name]
			player.stream = list[rng.randi() % list.size()]
			player.volume_db = float(sound["db"]) + db
			player.pitch_scale = float(sound["pitch"]) * pitch * (1.0 + rng.randf_range(-jitter, jitter))
			player.play()
			return true
	return false


## 소리 이름의 재생기 묶음 (테스트용)
func pool(sound_name: String) -> Array:
	return _pools[sound_name]


## 레전드리 카드에 빛이 모이는 소리
func play_card_gather() -> void:
	play("card_gather")


## 실드가 공격을 막았을 때
func play_shield_block() -> void:
	play("shield_block")


## 고대 경비선 발사음
func play_guard() -> void:
	_guard_player.play()


func guard_stream() -> AudioStreamWAV:
	return _guard_player.stream


## 워프 게이트 상태별 소리. 웅웅거림과 충전음은 게이트가 닫히거나 판이 끝나면 멈춘다.
func play_gate_assemble() -> void:
	_gate_assemble_player.play()


func play_gate_lock() -> void:
	_gate_lock_player.play()


func start_gate_hum() -> void:
	_gate_hum_player.stream_paused = false
	_gate_hum_player.play()


func stop_gate_hum() -> void:
	_gate_hum_player.stop()


func play_gate_alarm() -> void:
	_gate_alarm_player.play()


func play_gate_collapse() -> void:
	_gate_collapse_player.play()


func play_warp_charge() -> void:
	_warp_charge_player.stream_paused = false
	_warp_charge_player.play()


func stop_warp_charge() -> void:
	_warp_charge_player.stop()


## 메뉴가 떠 있는 동안 충전음·웅웅거림을 잠깐 멈췄다가, 닫으면 멈춘 곳부터 이어서 낸다 (충전 진행과 맞게).
func pause_gate_sounds(paused: bool) -> void:
	_warp_charge_player.stream_paused = paused
	_gate_hum_player.stream_paused = paused


## 게이트 웅웅거림이 들리고 있는지 (테스트용)
func gate_hum_audible() -> bool:
	return _gate_hum_player.playing and not _gate_hum_player.stream_paused


## 충전음이 들리고 있는지 (테스트용)
func warp_charge_audible() -> bool:
	return _warp_charge_player.playing and not _warp_charge_player.stream_paused


func play_warp_done() -> void:
	_warp_charge_player.stop()
	_warp_done_player.play()


## 워프 소리 (테스트용)
func warp_streams() -> Array[AudioStreamWAV]:
	return [_gate_assemble_player.stream, _gate_lock_player.stream, _gate_hum_player.stream, _gate_alarm_player.stream,
		_gate_collapse_player.stream, _warp_charge_player.stream, _warp_done_player.stream]


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


## 음표 목록으로 16비트 모노 소리를 만든다. 음표마다 짧게 커졌다 줄어드는 음량(엔벨로프)을 준다.
## 음표: [주파수, 길이] 또는 [시작 주파수, 길이, 끝 주파수](미끄러짐). 주파수 0은 쉼.
## wave: "square", "triangle", "noise"(주파수만큼 자주 바뀌는 잡음: 높을수록 "치익", 낮을수록 "우르르")
static func synth(notes: Array, wave: String, volume: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var noise := RandomNumberGenerator.new()
	noise.seed = 12345  # 잡음도 매번 같은 소리
	for note in notes:
		var freq: float = note[0]
		var end_freq: float = note[2] if note.size() > 2 else freq
		var length := int(MIX_RATE * float(note[1]))
		var phase := 0.0
		var held := 0.0
		for i in length:
			var f := lerpf(freq, end_freq, float(i) / maxf(length, 1))
			var last_phase := phase
			phase = fposmod(phase + f / MIX_RATE, 1.0)
			var sample := 0.0
			if f <= 0.0:
				sample = 0.0
			elif wave == "noise":
				if phase < last_phase or i == 0:
					held = noise.randf_range(-1.0, 1.0)  # 한 주기마다 새 값
				sample = held
			elif wave == "triangle":
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


## 기지 이륙 소리
func play_takeoff() -> void:
	_takeoff_player.play()


## 워프 점프: 충전(소리가 점점 높아짐), 도착 충격, 기지 착륙. 건너뛰면 멈춘다
func play_warp_launch() -> void:
	_warp_launch_player.play()


func play_warp_arrive() -> void:
	_warp_arrive_player.play()


func play_landing() -> void:
	_landing_player.play()


func stop_launch_sounds() -> void:
	_takeoff_player.stop()
	_warp_launch_player.stop()


## 워프 점프 소리 (테스트용)
func jump_streams() -> Array[AudioStreamWAV]:
	return [_takeoff_player.stream, _warp_launch_player.stream, _warp_arrive_player.stream, _landing_player.stream]
