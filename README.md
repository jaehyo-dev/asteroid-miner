# 소행성 광부 (asteroid-miner)

Pixel-art roguelite mining shooter (Godot 4)

소행성 지대로 출격해 자동 공격으로 버티며 광물을 캐고, 언제 귀환할지 고민하며 기지를 키워 나가는 픽셀 아트 로그라이트 채굴 슈터.

- 플레이: https://jaehyo-dev.github.io/asteroid-miner/
- 이전 버전: https://jaehyo-dev.github.io/asteroid-miner/versions/
- 설계서: [GAME_SPEC.md](GAME_SPEC.md) · 변경 기록: [CHANGELOG.md](CHANGELOG.md) · 크레딧: [CREDITS.md](CREDITS.md)

## 개발

Godot 4.7.2로 엽니다. 테스트 명령과 작업 규칙은 [CLAUDE.md](CLAUDE.md)를 봐 주세요.

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
python3 -m unittest discover -s tools -p "test_*.py" -v
```
