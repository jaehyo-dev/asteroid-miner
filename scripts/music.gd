extends Node
## 배경음 (자동 로드: Music). 박이 맞는 곡과 층들을 함께 반복하고(tools/make_music.py), 음량만 바꿔 섞는다.
## 기지: 미리 먹먹하게 만든 층만 작게. 출격: 곡(베이스 포함) + 시간이 지날수록 쌓이는 음 층.
## 필터 대신 미리 만든 층을 쓰는 이유: 웹은 소리를 Sample 방식으로 재생해 버스 효과(저역 필터)가 동작하지 않는다.

const MAIN := "res://assets/music/urgent_loop.ogg"
const BASE := "res://assets/music/urgent_base.ogg"
## 순서는 Juice.MUSIC_STEMS와 같음
const STEMS := ["res://assets/music/pulse_layer.ogg", "res://assets/music/stem_harmony.ogg", "res://assets/music/stem_top.ogg"]

## 지금 향하는 값 (run.gd·main.gd가 정하고, _process가 부드럽게 따라간다)
var target_main_db: float = Juice.MUSIC_SILENT_DB
var target_base_db: float = Juice.MUSIC_BASE_DB
var target_stem_dbs: Array[float] = []
var _main: AudioStreamPlayer
var _base: AudioStreamPlayer
var _stems: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = _make_player(MAIN, target_main_db)
	_base = _make_player(BASE, target_base_db)
	for i in STEMS.size():
		target_stem_dbs.append(MusicMix.run_stem_db(i, 0.0))
		_stems.append(_make_player(STEMS[i], target_stem_dbs[i]))
	for p in players():
		p.play()


func _make_player(path: String, db: float) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = db
	add_child(player)
	return player


## 기지 화면: 먹먹한 층만 작게
func set_base() -> void:
	target_main_db = Juice.MUSIC_SILENT_DB
	target_base_db = Juice.MUSIC_BASE_DB
	_set_stems(0.0)


## 출격 중: 지난 시간에 맞춰 섞는다
func set_run_time(time: float) -> void:
	target_main_db = Juice.MUSIC_RUN_DB
	target_base_db = Juice.MUSIC_SILENT_DB
	_set_stems(time)


func _set_stems(time: float) -> void:
	for i in target_stem_dbs.size():
		target_stem_dbs[i] = MusicMix.run_stem_db(i, time)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-Juice.MUSIC_SMOOTH * delta)
	_main.volume_db = lerpf(_main.volume_db, target_main_db, k)
	_base.volume_db = lerpf(_base.volume_db, target_base_db, k)
	for i in _stems.size():
		_stems[i].volume_db = lerpf(_stems[i].volume_db, target_stem_dbs[i], k)


## 다른 앱·탭으로 가면 멈추고, 돌아오면 이어서 낸다 (게임도 이때 일시 정지한다)
func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		for p in players():
			p.stream_paused = what == NOTIFICATION_APPLICATION_FOCUS_OUT


## 곡, 먹먹한 층, 음 층들 (테스트용)
func players() -> Array[AudioStreamPlayer]:
	var list: Array[AudioStreamPlayer] = [_main, _base]
	list.append_array(_stems)
	return list
