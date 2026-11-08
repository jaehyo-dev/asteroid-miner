extends Node
## 배경음 (자동 로드: Music). 곡 하나를 계속 반복하고, 기지에서는 작고 먹먹하게, 출격 중에는 시간이 지날수록 긴장되게 섞는다.
## 곡과 리듬 층은 길이가 같아(tools/make_sfx.py) 함께 시작하면 박이 어긋나지 않는다.

const MAIN := "res://assets/music/srg774_dark_scifi/urgent.ogg"
const LAYER := "res://assets/music/pulse_layer.ogg"

## 지금 향하는 값 (run.gd·main.gd가 정하고, _process가 부드럽게 따라간다)
var target_cutoff: float = Juice.MUSIC_BASE_CUTOFF
var target_main_db: float = Juice.MUSIC_BASE_DB
var target_layer_db: float = MusicMix.run_layer_db(0.0)
var _main: AudioStreamPlayer
var _layer: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_filter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
	_filter.cutoff_hz = target_cutoff
	_main = _make_player(MAIN, target_main_db)
	_layer = _make_player(LAYER, target_layer_db)
	_main.play()
	_layer.play()


func _make_player(path: String, db: float) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = db
	add_child(player)
	return player


## 기지 화면: 같은 곡을 작고 먹먹하게
func set_base() -> void:
	target_cutoff = Juice.MUSIC_BASE_CUTOFF
	target_main_db = Juice.MUSIC_BASE_DB
	target_layer_db = MusicMix.run_layer_db(0.0)


## 출격 중: 지난 시간에 맞춰 섞는다
func set_run_time(time: float) -> void:
	target_cutoff = MusicMix.run_cutoff(time)
	target_main_db = Juice.MUSIC_RUN_DB
	target_layer_db = MusicMix.run_layer_db(time)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-Juice.MUSIC_SMOOTH * delta)
	_filter.cutoff_hz = lerpf(_filter.cutoff_hz, target_cutoff, k)
	_main.volume_db = lerpf(_main.volume_db, target_main_db, k)
	_layer.volume_db = lerpf(_layer.volume_db, target_layer_db, k)


## 다른 앱·탭으로 가면 멈추고, 돌아오면 이어서 낸다 (게임도 이때 일시 정지한다)
func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		for p in players():
			p.stream_paused = what == NOTIFICATION_APPLICATION_FOCUS_OUT


## 곡과 리듬 층 (테스트용)
func players() -> Array[AudioStreamPlayer]:
	return [_main, _layer]
