# 4c 2차 후보 (사용자 의견 반영)

모두 `review/v070_step4c/listen/`에 있어요. **게임에는 ★ 후보가 들어가 있어요.** 저는 귀로 듣지 못해서 길이·높이·크기 같은 숫자와 합성 방식으로 골랐어요. 다른 것을 고르면 `tools/make_sfx.py`의 `CHOICE`만 바꾸면 돼요 (배경음은 `scripts/music.gd`의 `MAIN`과 리듬 층).

## 적 소리 (맞음 → 0.2초 쉼 → 파괴를 두 번)

| 파일 | 맞음 | 파괴 | 길이 (맞음/파괴) |
|---|---|---|---|
| ★ `enemy_jelly_a.ogg` | 190→85Hz 둔한 탄력음 "퉁" | 물방울이 올라가는 "뽁" 2번 | 0.15 / 0.16초 |
| `enemy_jelly_b.ogg` | Kenney impactSoft + 낮은 "퉁" | 젤리가 터지는 "퍽" + 작은 방울 2개 | 0.18 / 0.21초 |
| `enemy_bug_a.ogg` | 2.6kHz 짧은 "틱" | 음이 떨어지는 "찍" | 0.04 / 0.10초 |
| ★ `enemy_bug_b.ogg` | 1.8kHz 더 낮은 "틱" | 바삭한 "지직" | 0.03 / 0.14초 |

날벌레는 많이 잡으니 음이 또렷한 "찍"보다 덜 귀에 남을 "지직"을 골랐어요(내 판단, 귀로는 확인 못 함). 경비선은 지금 금속 소리 그대로이고 맞음을 0.3초, 파괴를 약 0.5초(1.55초에서)로 잘랐어요.
몰림: 종류마다 따로 세어 앞서 난 소리 하나마다 5dB 작게, 4개째부터 안 냄 (파괴 0.5초 창, 맞음 0.25초 창). 평균 크기(파일 + 게임 음량): 해파리 맞음 -26 / 파괴 -25dB, 날벌레 -32 / -32dB, 경비선 -28 / -23dB.

## 레벨업 (같은 소리를 두 번)

공통: 길이 0.395초, 4kHz 위를 깎음(4kHz 위 에너지 0.01% 미만), 마지막 음은 앞 음 최고점의 약 0.4~0.6배, 짧고 끝이 코사인 곡선으로 0까지 줄어듦.

| 파일 | 음 | 음색 | 마지막 음 |
|---|---|---|---|
| ★ `levelup2_a.ogg` | C5-E5-G5-C5 (도미솔도) | 마림바 | 첫 음으로 돌아옴 |
| `levelup2_b.ogg` | C5-E5-G5-E5 (도미솔미) | 부드러운 신스 플럭 | 첫 음보다 장3도 위, 가장 높은 음 아래 |
| `levelup2_c.ogg` | G4-C5-E5-C5 (솔도미도) | 둥근 삼각파 | 첫 음보다 완전4도 위, 가장 높은 음 아래 |

게임 평균 크기는 지금 소리보다 -3dB (-17.6 → -20.6dB).

## 배경음 (게임에서 섞는 그대로)

`_start` = 출격 시작부터 45초 (0초에 기지의 먹먹한 소리에서 열리고, 30~40초에 리듬 층이 들어옴). `_1min` = 게임 1분부터 80초 (2분~2분 10초에 두 번째 층이 들어옴).

| 파일 | 곡 | 만든 사람 | 라이선스 | 설명 |
|---|---|---|---|---|
| ★ `bgm2_urgent_start.ogg`, `bgm2_urgent_1min.ogg` | Urgent | SRG774 | CC0 1.0 | 지금 곡, 135 BPM, 57초 반복 |
| `bgm2_spacebattle_start.ogg`, `bgm2_spacebattle_1min.ogg` | [Space Battle](https://opengameart.org/content/space-battle) (bgm_c) | MintoDog | CC0 | 130 BPM, 88.6초 반복 |
| `bgm2_fastfight_start.ogg`, `bgm2_fastfight_1min.ogg` | [Fast fight / battle music (looped)](https://opengameart.org/content/fast-fight-battle-music-looped) | Ville Nousiainen (반복 편집 XCVG) | CC0 | 155 BPM, 치프튠 느낌의 빠른 전투곡. 24.8초로 짧아 금방 되풀이됨 |
| `bgm2_orbital_start.ogg`, `bgm2_orbital_1min.ogg` | [Orbital Colossus](https://opengameart.org/content/space-boss-battle-theme) | Matthew Pablo | CC-BY 3.0 (저작자 표시 필요) | 164 BPM, 우주 슈팅 보스용 전자음악. 2분 31초. 만든 사람이 "그대로는 반복이 안 된다"고 적어 둠: 고르면 반복 편집이 필요함 |

라이선스는 2026-11-08에 OpenGameArt 공식 페이지의 License 칸에서 직접 확인했어요.
비교를 위해 네 곡의 평균 크기를 Urgent에 맞췄어요 (원래 Fast fight는 Urgent보다 약 12dB 큼). 이 비교 파일에는 효과음이 없어요.

게임의 섞기: 출격 -11.5dB(+3.5dB), 필터 4kHz에서 3분 동안 12kHz까지 열림, 30초부터 10초 동안 낮은 "둥" 층, 2분부터 10초 동안 반 박마다 높은 "칫" + 엇박 "둥" 층. 기지는 그대로(450Hz, -24dB).
파일은 Godot와 같은 필터 식과 값을 코드로 옮겨 만든 것이라 실제 게임과 아주 조금 다를 수 있어요. 박 맞춤은 숫자로 찾았고 귀로는 확인하지 못했어요 (Orbital은 반복 곡이 아니어서 곡이 끝날 때까지 최대 0.05초쯤 어긋날 수 있음).

참고: 이전 리듬 층은 Urgent를 약 108 BPM으로 잘못 재서 곡과 박이 어긋났어요. 56.895초 = 135 BPM의 128박으로 딱 맞아, 135 BPM으로 고쳤어요.

---

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
