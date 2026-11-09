# v0.7.0 밸런스 점검 1단계 (점검·측정·계획안, 게임 코드 변경 없음)

| 번호 | 문서 | 자료 |
|---|---|---|
| 1 | [스킬 전수 점검표](1_skill_audit.md) | `tools/stack_check.gd.txt` |
| 2·3 | [난이도 측정과 조정안 (후반 피해 증가 포함)](3_difficulty.md) | `data/table_all.md`, `data/table_late.md`, `data/runs_json.tgz` |
| 4 | [건너뛰기 설계안](4_skip.md) | `skip/*.png` (PC 1280x720, 폰 가로 844x390) |
| 5 | [드론 탄알 크기](5_drone_bullet.md) | `drone_bullet/*.png` |
| 6 | [스킬 확장 계획안](6_skill_expansion.md) | 원칙은 GAME_SPEC.md "스킬 방향과 밸런스 결정" |
| 7 | [광물 줍기 소리](7_pickup_sound.md) | `pickup_sound/late30_*.ogg` (지금/시안 후반 30초) |

- 캡처·녹음·시안 측정은 저장소 밖 작업 사본(git worktree)에서 시안 코드를 넣어 만들었다. 그 변경은 `tools/worktree_mock.diff`, `tools/difficulty_mock.diff`에 남김.
- `.gd.txt`는 Godot가 프로젝트 스크립트로 읽지 않게 확장자를 바꾼 것 (`review/`는 `.gdignore`로 빠져 있음).
