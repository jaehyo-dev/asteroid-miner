# 크레딧과 라이선스

이 게임에 쓰인 외부 오픈소스·에셋의 출처와 라이선스입니다.
새로 추가하거나 버전을 바꿀 때마다 이 파일을 함께 고칩니다 (규칙: [CLAUDE.md](CLAUDE.md)의 "오픈소스 사용 규칙").

배포된 게임에서는 [`licenses/`](https://jaehyo-dev.github.io/asteroid-miner/licenses/CREDITS.md) 경로에 이 파일과 라이선스 전문이 함께 올라갑니다.

## 게임에 포함된 것

| 이름 | 버전 | 만든 사람 | 라이선스 | 출처 | 쓰는 곳 | 수정 |
|---|---|---|---|---|---|---|
| Godot Engine | 4.7.2-stable | Godot Engine contributors, Juan Linietsky, Ariel Manzur | MIT (엔진에 포함된 서드파티 구성 요소는 각자의 라이선스) | https://godotengine.org | 게임 엔진, 웹 내보내기 템플릿 | 없음 |
| Galmuri11 (갈무리) | v2.40.4 | Lee Minseo (quiple) | SIL Open Font License 1.1 | https://github.com/quiple/galmuri | 게임 전체 글꼴 `assets/fonts/galmuri/Galmuri11.ttf` | 없음 |

- Godot 엔진과 엔진 구성 요소의 라이선스 전문은 배포할 때 `licenses/godot.txt`로 자동 생성합니다 (`tools/export_licenses.gd`).
- Galmuri 라이선스 전문: [`assets/fonts/galmuri/LICENSE.txt`](assets/fonts/galmuri/LICENSE.txt)

## 개발·배포에만 쓰는 것 (게임에는 포함되지 않음)

| 이름 | 라이선스 | 쓰는 곳 |
|---|---|---|
| GitHub Actions: actions/checkout, actions/cache, actions/configure-pages, actions/upload-pages-artifact, actions/deploy-pages | MIT | `.github/` 자동 테스트·배포 |
| Python 3 표준 라이브러리 | PSF License | `tools/` 변경 기록·버전 도구 |

## 직접 만든 것

- 프로젝트 아이콘 `icon.svg`, 시작 화면의 별 배경: 이 프로젝트에서 직접 만듦
