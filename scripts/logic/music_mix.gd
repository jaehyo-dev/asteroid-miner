class_name MusicMix
extends RefCounted
## 배경음 섞기 계산 (수치는 juice.gd): 출격 중 시간이 지날수록 높은 음을 깎는 필터가 열리고, 2분 뒤 리듬 층이 들어온다.


## 출격 시간(초) → 필터가 통과시키는 최고 주파수(Hz). 귀가 음 높이를 비율로 듣기 때문에 비율로 올린다
static func run_cutoff(time: float) -> float:
	var k := clampf(time / Juice.MUSIC_CUTOFF_RAMP, 0.0, 1.0)
	return Juice.MUSIC_CUTOFF_START * pow(Juice.MUSIC_CUTOFF_END / Juice.MUSIC_CUTOFF_START, k)


## 출격 시간(초) → 리듬 층 음량(dB): LAYER_TIME까지 안 들리다가 LAYER_FADE초에 걸쳐 커진다
static func run_layer_db(time: float) -> float:
	var k := clampf((time - Juice.MUSIC_LAYER_TIME) / Juice.MUSIC_LAYER_FADE, 0.0, 1.0)
	return linear_to_db(maxf(k, 0.001)) + Juice.MUSIC_LAYER_DB
