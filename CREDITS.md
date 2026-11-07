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
| Pillow 10.4.0 (Jeffrey A. Clark and contributors) | MIT-CMU (HPND) | `tools/pixelate.py` 그림 정리 도구와 그 테스트 (https://github.com/python-pillow/Pillow, CI에서 pip로 설치) |
| rembg (Daniel Gatis), isnet-general-use 모델 | MIT, 모델 Apache-2.0 | `tools/pixelate.py --rembg` 배경 지우기 (개발 PC에만 설치, 필요할 때만) |
| GitHub Actions: actions/checkout, actions/setup-python, actions/cache, actions/configure-pages, actions/upload-pages-artifact, actions/deploy-pages | MIT | `.github/` 자동 테스트·배포 |
| Python 3 표준 라이브러리 | PSF License | `tools/` 변경 기록·버전 도구 |

## 직접 만든 것

- 프로젝트 아이콘 `icon.svg`, 별 배경: 이 프로젝트에서 직접 만듦
- 우주선·운석·황금 운석·우주 해파리·날벌레·고대 경비선(선체·충전 빛·에너지탄)·탄·파편·광물·심연의 포격(조준선·에너지탄) 픽셀 아트와 모션(운석 회전·튕김·금 감, 우주선 기울기) (`scripts/pixel_art.gd`, `scripts/world_view.gd`에서 코드로 그림): 이 프로젝트에서 직접 만듦
- 광물 줍기 효과음, 체력 낮음 경고음, 습격 경고음, 포격 충전·발사음, 고대 경비선 발사음 (`scripts/sfx.gd`에서 코드로 합성한 8비트 소리): 이 프로젝트에서 직접 만듦
- 워프 게이트 기계식 고리·표시등 픽셀 아트(`scripts/pixel_art.gd`), 소용돌이 셰이더(`scripts/gate_vortex.gdshader`), 게이트 연출(`scripts/gate_view.gd`), 게이트 맞물림·웅웅거림·경보·붕괴·귀환 효과음(`scripts/sfx.gd`): 이 프로젝트에서 직접 만듦
- 기지 그림 12장(v0.6.3에서 건물 5채·착륙장·바닥 가로·세로를 승인된 콘셉트 `base_concept_v063.png` 기준으로 다시 만듦. 건물은 콘셉트에서 잘라 rembg로 배경을 지우고 정리, 바닥은 콘셉트에서 건물을 지운 그림. 바닥 배경 가로·세로, 연구소·부품, 격납고, 광물 창고·광물 더미 5단계, 전시관, 드론 공장, 착륙장, 우주선, 조종사) `assets/sprites/base/`: Codex(ChatGPT 구독) 내장 이미지 생성으로 만든 AI 그림(원본 `assets/raw/base/`, 빌드 제외), 2026-11-07. `tools/pixelate.py`로 배경 빼기·색 줄이기·픽셀 격자 맞추기를 해서 씀 (수정함). 요청문: [ASSET_PROMPTS.md](ASSET_PROMPTS.md). v0.6.3 수정에서 건물·착륙장·우주선·부품을 2픽셀 격자 크기(약 0.8배)로 다시 정리하고, 바닥은 소행성 전체가 보이도록 Codex로 다시 만들어 우주 배경을 지워 씀 (`ground_v063b_*`)
- 기지 길·가로등·드론·운석·이름표·이륙 불꽃(`scripts/ui/base_view.gd`, 3픽셀 격자), 업그레이드·자물쇠·포격 아이콘(`scripts/pixel_art.gd`), 건물 열기·이륙·버튼 효과음(`scripts/sfx.gd`): 이 프로젝트에서 직접 만듦
- 기지 콘셉트 그림 3장 `assets/raw/base_concept_v063.png`(v0.6.3 승인본) 과 `assets/raw/base_concept_overview.png`, `assets/raw/base_concept_portrait.png`: Codex(ChatGPT 구독) 내장 이미지 생성으로 만든 AI 그림, 2026-11-07. 기지 픽셀 아트와 가로·세로 배치의 참고용으로만 쓰고 게임 빌드에는 들어가지 않음 (`.gdignore`), 수정 없음. 요청문: [ASSET_PROMPTS.md](ASSET_PROMPTS.md)
- 워프 게이트 콘셉트 그림 2장 `assets/raw/gate_concept_design.png`, `assets/raw/gate_concept_states.png`: Codex(ChatGPT 구독) 내장 이미지 생성으로 만든 AI 그림, 2026-11-06. 게이트 픽셀 아트의 참고용으로만 쓰고 게임 빌드에는 들어가지 않음 (`.gdignore`), 수정 없음. 요청문: [ASSET_PROMPTS.md](ASSET_PROMPTS.md)
