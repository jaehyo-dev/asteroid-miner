# 5단계 3부 자료

| 파일 | 내용 |
|---|---|
| `card_size_before_after.png` | 카드 크기 전(왼쪽)·후(오른쪽), PC |
| `card_pc_1280x720.png`, `card_phone_844x390.png` | 지금 카드. 폰은 웹 빌드 터치 에뮬레이션 캡처 |
| `reveal_normal.gif`, `reveal_legendary.gif`, `reveal_skip.gif` | 등장 연출: 유니크까지, 레전드리, 건너뛰기 |
| `fx_*.gif` | 관통, 튕김, 폭발, 치명타, 드론, 채굴 레이저, 레전드리 4종, 실드 |
| `shield_stages.png` | 실드 단계 (충전 → 완충 광택 → 막음 → 조각 → 다시 충전). 캡처 때만 간격을 3초로 줄임 |
| `touch_skip_log.txt` | 터치 건너뛰기 로그 (상태 1 등장 → SKIP → 2 잠금 → 3 선택 가능) |

다시 만들기: `tools/capture_cards.gd`, `tools/capture_effects.gd` (머리 주석 참고), `tests/balance_report.gd`.
