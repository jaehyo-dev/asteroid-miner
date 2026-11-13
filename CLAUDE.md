# 프로젝트 규칙

소행성 광부: Godot 4 (GDScript)로 만드는 픽셀 아트 로그라이트 채굴 슈터. 게임 설계는 [GAME_SPEC.md](GAME_SPEC.md)를 따른다.

- 공통 규칙(한국어·주석, 판단 기준, 단계 진행, 리뷰·최종 검토, Git, 버전, Codex, 오픈소스)은 전역 `~/.claude/CLAUDE.md`를 따른다. 전역 파일을 못 읽는 클라우드 세션은 [docs/CLAUDE_REFERENCE.md](docs/CLAUDE_REFERENCE.md)의 사본을 읽는다.
- 기본 브랜치는 `main`. 저장소: https://github.com/jaehyo-dev/asteroid-miner · 게임: https://jaehyo-dev.github.io/asteroid-miner/ (단계 보고와 푸시 뒤 보고에 둘 다 적는다)
- 최종 검토자: `.claude/agents/final-reviewer.md`

## 단계

다음 단계는 내가 "다음"이라고 할 때 시작한다 (자동 진행을 허락한 경우만 예외).

| 단계 | 내용 | 배포 버전 |
|---|---|---|
| 0~7 | 끝남 (단계별 내용·버전: [참고 문서](docs/CLAUDE_REFERENCE.md#단계-표)) | v0.0.1~v0.7.0 |
| 8~ | 이후는 GAME_SPEC.md "출시 단계" 순서 (채굴 드론 → 클라우드 저장 → 주간 랭킹 → v1.0.0) | GAME_SPEC 표 |

- 버전은 위 표를 따르되 실제로 배포된 상태가 우선이다 (예: 한 단계 안에서 버그 수정을 따로 배포하면 패치 번호를 올림). v0.1.0 전(1~4단계)은 표의 버전을 따른다.

## 테스트

Godot 4.7.2 (`.github/workflows/deploy.yml`의 `GODOT_VERSION`과 같은 버전). `godot`은 실행 파일 경로로 바꿔도 된다. 순서대로 실행하고 종료 코드까지 확인한다 (실패하면 1).

```bash
# 1) 리소스 가져오기 (반드시 먼저: 새로 받은 저장소, .godot/를 지운 뒤, 에셋·class_name 추가·변경 뒤)
godot --headless --path . --import
# 2) 게임 자동 테스트 (tests/test_*.gd). Godot 경로가 다르면 GODOT=경로 bash tests/run_tests.sh
bash tests/run_tests.sh
# 3) 도구·버전 자동 테스트 (tools/test_*.py)
python3 -m unittest discover -s tools -p "test_*.py" -v
# 4) 웹 내보내기 확인 (웹 내보내기 템플릿 필요, build/는 .gdignore로 빠져 있음)
mkdir -p build/web
godot --headless --path . --export-release "Web" "$PWD/build/web/index.html"
```

- 게임 테스트는 `-s res://tests/run_tests.gd`로 직접 부르지 말고 `tests/run_tests.sh`로 실행한다 (이유와 테스트 작성법: [참고 문서](docs/CLAUDE_REFERENCE.md#테스트-보충)).
- GitHub Actions가 모든 브랜치 푸시마다 1~4를 실행한다. 작업 브랜치에 푸시한 뒤 Actions 결과도 확인한다.
- 게임 로직(데미지, 경험치, 귀환, 보존 비율, 배율, 비용 등)은 `scripts/logic/`에 두고 직접 호출해 테스트한다. 무작위 값은 시드를 받는다. GAME_SPEC.md "9. 테스트할 로직"은 그 기능을 만드는 단계에서 자동 테스트로 만든다.
- 게임 플레이 수치(조작감·속도·난이도)는 `scripts/balance.gd` 한곳에 둔다 (색·여백 같은 화면 꾸밈 값은 각 화면 파일에 둬도 됨). 손맛(반동, 번쩍임, 히트스톱, 흔들림, 광물 튕김·자석 가속, 슬로모션, 카운트업 등) 수치는 `scripts/juice.gd` 한곳에 둔다.
- 선택 표시로 테두리 선을 쓰지 않는다 (버튼·탭·카드를 고르면 생기는 노란·빨간 등 테두리 금지, 2026-11-12 사용자 결정). 고른 상태는 바탕·글자를 밝혀서 보인다. 자세한 건 ART_BIBLE.md 8장, 자동 검사는 `tests/test_no_select_border.gd`·`tools/test_ui_rules.py`.
- 화면 확인: 웹 빌드를 로컬 서버 + Playwright(Chromium)로 PC 1280x720·폰 390x844 캡처, 콘솔 오류 없어야 함.
- **맥: Godot 창 띄우기 금지, 캡처는 웹 빌드 + Playwright headless** (2026-11-12 사용자 결정). 맥에서는 Godot 에디터·게임·캡처 스크립트 창을 화면에 띄우지 않는다(`open -g`로 뒤에 띄우는 것도 안 됨). 캡처·GIF는 웹 빌드를 Playwright headless로 열어 찍는다(PC 1280x720, 폰 844x390, 필요하면 `?fxtest`). 테스트와 봇은 `godot --headless`. 웹 빌드로 못 찍는 장면은 창을 띄우지 말고 목록으로 남겨 윈도우(WSL `xvfb-run`)에서 찍는다.
- PROGRESS.md에는 단계마다 만든 것, 내가 판단한 것, 검토 결과, 플레이하며 확인할 부분을 짧게 적는다. 지난 기록은 [docs/PROGRESS_ARCHIVE.md](docs/PROGRESS_ARCHIVE.md).
- 앞으로 review/에는 최종 비교 그림과 GIF만 커밋한다.

## 버전과 배포

- 버전 번호는 `project.godot`의 `config/version` 한 곳에만 두고 게임 화면은 이 값을 읽는다. CHANGELOG.md를 먼저 쓰고 두 버전을 맞춘 상태로 main에 푸시한다 (다르면 워크플로가 실패하고 태그·배포를 하지 않음).
- 태그(`v메이저.마이너.패치`)·Release는 직접 만들지 않는다. main 푸시 때 `.github/workflows/deploy.yml`이 만들고 GitHub Pages에 배포하며, 태그마다 다시 빌드해 `versions/v버전/`에 올린다. 그러니 버전 태그는 지우거나 옮기지 않는다.
- 배포가 느리거나 옛 버전이 보이면 [배포 워크플로 4가지 규칙](docs/CLAUDE_REFERENCE.md#배포-워크플로-규칙)을 먼저 확인한다. 웹 내보내기는 항상 `bash tools/export_web.sh <프로젝트> <출력> <버전>`으로 한다.
- Godot 버전을 올릴 때 함께 바꿀 것: [참고 문서](docs/CLAUDE_REFERENCE.md#버전-관리-보충).

## 에셋·그림

- 그림·효과·소리·음악·글꼴·셰이더·애드온·라이브러리는 만들기 전에 먼저 찾고, 어울리면 쓰고, 후보 2~4개를 게임 화면 안 시안으로 사용자에게 보여 준 뒤 확정한다. 이미 만든 것은 갈아엎지 않는다.
- 라이선스: MIT·BSD·Apache-2.0·zlib·CC0·CC-BY 3.0/4.0(저작자 표시)·SIL OFL 1.1(글꼴)은 쓴다. CC-BY-SA·MPL-2.0·LGPL·그 밖의 라이선스는 먼저 묻는다. **GPL·AGPL, CC-BY-NC·CC-BY-ND, 라이선스가 없거나 "무료"라고만 된 것·출처 불명, 다른 게임·영화 추출 에셋, 상표·캐릭터는 쓰지 않는다.**
- 외부 에셋은 `assets/종류/이름/`에 두고 라이선스 전문(`LICENSE.txt` 또는 원래 이름)을 옆에 둔다. CREDITS.md 표(이름, 버전, 만든 사람, 라이선스, 출처, 쓰는 곳, 수정 여부)에 적는다. 직접 만든 것·Codex AI 그림은 "직접 만든 것"에, 개발·배포 도구(GitHub Actions 등)는 아래쪽 표에 적는다.
- 그림은 먼저 쓸 수 있는 에셋을 찾고, 어울리는 게 없을 때 Codex의 내장 이미지 생성을 쓴다 (API 키는 쓰지 않음, 방법은 전역 규칙).
- 게임에 넣는 그림은 모두 `tools/pixelate.py`로 정리한다 (`assets/raw/` → `assets/sprites/`): 마젠타(#FF00FF) 배경 빼기(깔끔하지 않으면 `--rembg`, rembg는 `~/.local/venvs/rembg`의 isnet-general-use), 디더링 없이 색 줄이기, nearest로 픽셀 격자 맞추기, 투명도 0/255.
- 한 화면 안에서는 정수 배율 하나로만 그리고(기지 화면은 그림 3배), 코드로 그리는 도형과 글자(Galmuri11 12px의 같은 배수, 기지 화면 36px)도 같은 격자에 맞춘다.
- 콘셉트 그림과 완성 화면 캡처를 나란히 붙인 비교 이미지를 만들어 직접 보고, 차이가 큰 부분을 고친 뒤 보고한다.
- 소리·음악을 코드로 만드는 도구(tools/make_sfx.py, make_music.py): 이미 만든 것은 유지, 새 소리·음악은 먼저 찾는다.
- codex나 /ponytail-review를 쓸 수 없는 환경이면 건너뛰고 보고에 적는다.

## 구조

```
project.godot       설정 (게임 버전 config/version)
export_presets.cfg  웹 내보내기 (스레드 없음: GitHub Pages용)
scenes/ scripts/    씬, 스크립트 (수치 balance.gd, 손맛 juice.gd, 로직 logic/, 화면 부품 ui/)
assets/             에셋 (폴더마다 라이선스 파일)
tests/ tools/       게임 테스트(run_tests.sh), 도구와 그 테스트
docs/               보관 기록, 참고 문서
GAME_SPEC.md CHANGELOG.md CREDITS.md PROGRESS.md
```

- Godot가 만드는 `*.import`, `*.uid`는 커밋하고, `.godot/`, `build/`는 커밋하지 않는다.
- 웹 내보내기는 Compatibility 렌더러, 스레드 없음 설정을 유지한다 (자동 테스트가 확인).
