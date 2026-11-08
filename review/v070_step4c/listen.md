# 4c 들어 볼 후보

모두 `review/v070_step4c/listen/`에 있어요. 고른 것을 알려 주면 `tools/make_sfx.py`의 `CHOICE`(배경음은 `scripts/music.gd`의 `MAIN`)만 바꾸면 돼요.
**게임에는 ★ 후보가 들어가 있어요.** 저는 귀로 듣지 못해서, 길이·밝기 같은 숫자와 설명으로 골랐어요.

## 포격 (예고 → 0.3초 쉼 → 발사)

원래 발사음 laserLarge_000은 3kHz 넘는 높은 소리가 15.6%였어요. 세 후보 모두 0.0%예요. 게임 음량은 예고 -14dB, 발사 -10dB로 낮췄어요(예전 -10, -3).

| 파일 | 만든 방법 | 음 높이 | 필터 |
|---|---|---|---|
| ★ `barrage_a.ogg` | Kenney forceField_002 → laserLarge_000 | 0.65배 / 0.55배 | 높은 음 깎기 900Hz / 1200Hz (2번씩) |
| `barrage_b.ogg` | Kenney spaceEngineLow_001 → lowFrequency_explosion_000 | 1.0배 / 1.25배 | 700Hz / 1500Hz |
| `barrage_c.ogg` | 직접 합성: 90→140Hz 웅웅 + 220→55Hz "뿌웅" + 낮은 잡음 | - | 잡음만 700Hz (2번) |

## 레벨업 (같은 소리를 두 번)

| 파일 | 만든 방법 | 음 높이 | 필터 |
|---|---|---|---|
| `levelup_a.ogg` | Kenney confirmation_002 | 그대로 | 6000Hz |
| ★ `levelup_b.ogg` | 직접 합성: 종소리 도-미-솔-도(C6 E6 G6 C7), 60ms 간격 | - | 7000Hz |
| `levelup_c.ogg` | 직접 합성: 부드러운 삼각파 솔-시-레-솔(G5 B5 D6 G6), 45ms 간격 | - | 5000Hz |

## 광물 줍기 (일반 → 희귀 → 영웅 → 전설, 이어서 일반을 1반음씩 올리며 6번)

등급별 음색 차이와 연속 줍기 음 상승(최대 +12반음)은 그대로예요.

| 파일 | 만든 방법 | 음 높이 | 필터 |
|---|---|---|---|
| `pickup_a.ogg` | 지금 Kenney 소리 4개 (drop_002, glass_002, pluck_001, confirmation_003) | +2반음 | 고음 +5dB (3kHz) |
| `pickup_b.ogg` | 일반만 직접 합성한 "띵"(E6), 나머지는 지금 Kenney 소리 | 나머지 +3반음 | 없음 |
| ★ `pickup_c.ogg` | 모두 직접 합성한 종소리 "띠링": 일반 B5-E6, 희귀 E6-B6, 영웅 E6-G#6-B6, 전설 E6-G#6-B6-E7 (높은 등급일수록 배음이 밝음) | - | 없음 |

## 운석 깨짐 (`break_before_after.ogg`: 지금 3개 → 0.6초 쉼 → 줄인 3개, 작음·중간·큼 순서)

| 크기 | 원본 | 전 | 후 (음 높이까지 반영한 실제 길이) |
|---|---|---|---|
| 작음 | Kenney explosionCrunch_000 | 약 0.6초 | 약 0.25초 |
| 중간 | Kenney explosionCrunch_002 | 약 1.26초 | 0.3초 |
| 큼·황금 | Kenney lowFrequency_explosion_001 | 약 1.18초 | 약 0.53초 |

0.5초 안에 앞서 난 소리 하나마다 5dB씩 작게, 4개째부터는 내지 않아요 (`juice.gd`의 `BREAK_SOUND_*`). 큰·황금 운석만 몰려도 제 크기로 내요. 작은·중간 운석의 동시 재생 수도 3 → 2로 줄였어요. 적 파괴음(explosionCrunch_003, 1.55초)은 요청 범위가 아니라 그대로 뒀어요.

## 배경음 (앞 30초, 비교하기 쉽게 크기를 -20 LUFS로 맞춘 파일)

| 파일 | 제목 | 만든 사람 | 라이선스 | 링크 | 설명 |
|---|---|---|---|---|---|
| ★ `bgm_a.ogg` | Urgent (Dark Sci-Fi Audio Pack) | SRG774 | CC0 1.0 | https://opengameart.org/content/dark-sci-fi-audio-pack | 만든 사람 설명: 몰아가는 맥박, 게임을 덮지 않고 긴장을 올림. 약 57초 반복, 약 108 BPM |
| `bgm_b.ogg` | Pulse (같은 팩) | SRG774 | CC0 1.0 | 위와 같음 | 만든 사람 설명: 외계 심장 박동 같은 낮은 맥박. 약 71초 반복. 낮은 음 비중이 가장 큼 |
| `bgm_c.ogg` | Space Battle | MintoDog | CC0 | https://opengameart.org/content/space-battle | 130 BPM 전투 곡, 반복 가능. 셋 중 가장 밝고 빠름 |

라이선스는 세 곡 모두 OpenGameArt 공식 페이지의 License 칸에서 직접 확인했어요.
찾았지만 뺀 곡: Space-ish Suspense(GPL·CC-BY-SA), Tension Theme(CC0이지만 Apple Loops로 만들어 출처가 애매함), Space Graveyard(CC0이지만 5분짜리 27MB).

게임의 섞기: 기지 = 필터 450Hz, -24dB. 출격 = -15dB, 필터가 900Hz에서 3분 동안 12kHz까지 열림. 2분부터 10초 동안 직접 합성한 낮은 "둥" 리듬 층이 들어옴(곡과 길이가 같고 박에 맞춤, `assets/music/pulse_layer.ogg`).
다른 곡을 고르면 리듬 층 박자도 그 곡에 맞춰 다시 만들어야 해요.

Kenney Music Jingles 같은 다른 팩은 필요 없었어요. 합성한 레벨업이 마음에 안 들면 https://kenney.nl/assets/music-jingles 를 받아 주면 후보를 더 만들 수 있어요.
