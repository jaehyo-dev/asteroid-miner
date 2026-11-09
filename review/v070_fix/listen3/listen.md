# 창 소리 3차 후보 (게임에서 골라 보는 시험용)

**저는 귀로 듣지 못해요.** 파형과 숫자(`measure.md`)로만 확인했어요. 고르는 건 게임에서 창을 여닫으며 해 주세요. 파일로는 `window_N_pair.ogg`(열기-닫기 2번)를 먼저 들으면 돼요.

| 후보 | 열기 | 닫기 | 재료 |
|---|---|---|---|
| 1 홀로그램 화면 켜짐 | 짧은 상승음 → 0.18초에 반짝 | 내려가는 음 | 합성 |
| 2 공기압 슉 + 딸깍 | 공기 잡음 → 0.18초에 딸깍 | 짧고 낮은 슉 → 딸깍 | 합성 잡음 + Kenney RPG Audio `metalClick` |
| 3 금속 패널 스륵-탁 | 좁은 잡음 띠 스륵 → 0.18초에 탁 | 짧고 낮은 스륵-탁 | 합성 잡음 + Kenney Impact `impactPlate_light_001` |
| 4 단말기 삐빅 | 부드러운 두 음 (올라감) | 낮은 두 음 (내려감) | 합성 |
| 5 클릭 + 은은한 울림 | 클릭 + 660·990Hz 울림 | 낮은 클릭 + 440Hz 울림 | Kenney Interface `click_002` + 합성 |

## 맞춘 기준 (스크립트 assert)
- 열기 0.25초 안쪽, 닫기 0.16초 안쪽이고 열기보다 짧고 낮음(무게중심).
- 크기: 게임에서 -12dB로 틀고, 가장 큰 50ms 구간이 카드 등장 A보다 3dB 작게 파일을 맞춤. 닫기는 2dB 더 작게. door2 A는 시험에서 전과 같은 -5dB로 틀어요.
- 고음: 9kHz 위 3% 미만.
- 카드 등장 A의 재료(칼 뽑는 소리, 카드 미끄러짐, `impactMetal_light_004`), e3(권총 녹음)와 겹치는 파일이 없어요.
- 숫자: `measure.md`.

## 게임에서 비교하기 (끝남: 2번 확정, `?doortest`는 지움)
`bash tools/serve_web.sh`로 띄운 뒤 주소 끝에 `?doortest`. 기지 오른쪽 아래 작은 버튼을 누를 때마다 1 → 2 → 3 → 4 → 5 → door2 A로 바뀌고 이름이 잠깐 떠요. 그다음 건물을 열고 닫아 보세요.

## 다시 만들기, 출처
`python3 review/v070_fix/listen3/make_listen3.py` (저장소 맨 위에서)

| 재료 | 만든 사람 | 라이선스 | 출처 |
|---|---|---|---|
| RPG Audio, Impact Sounds, Interface Sounds | Kenney | CC0 | https://kenney.nl/assets (`review/v070_fix/listen/src/*/LICENSE.txt`, `assets/sfx/kenney_interface/LICENSE.txt`, CREDITS.md) |
| 잡음·사인파 | 직접 합성 (numpy) | 직접 만듦 | `make_listen3.py` |
