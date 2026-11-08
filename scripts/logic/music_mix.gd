class_name MusicMix
extends RefCounted
## 배경음 섞기 계산 (수치는 juice.gd): 출격 시간이 지날수록 층이 쌓인다 (곡 + 베이스 → 리듬 → 화음·아르페지오 → 빠른 리듬 + 멜로디).


## 출격 시간(초) → i번 층 음량(dB): 시작 전에는 안 들리다가 정해진 시간에 걸쳐 커진다
static func run_stem_db(i: int, time: float) -> float:
	var stem: Array = Juice.MUSIC_STEMS[i]
	var k := clampf((time - float(stem[0])) / float(stem[1]), 0.0, 1.0)
	return linear_to_db(maxf(k, 0.001)) + float(stem[2])
