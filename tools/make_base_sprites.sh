#!/usr/bin/env bash
# 기지 건물·부품 그림을 다시 만든다 (v0.6.6: 건물 폭을 화면의 12~13%로 키움, 2픽셀 격자 유지).
# 원본은 assets/raw/base/ (crop063은 승인된 콘셉트에서 잘라 온 것). rembg가 필요하다 (~/.local/venvs/rembg).
# 사용: bash tools/make_base_sprites.sh
set -euo pipefail
cd "$(dirname "$0")/.."
raw=assets/raw/base
out=assets/sprites/base
px="python3 tools/pixelate.py"
# 건물 폭(그림 픽셀): 2픽셀 격자라 화면 폭 1280의 12.2~13.0%
$px $raw/crop063/research.png $out/research.png --width 78 --rembg --main-only --colors 40
$px $raw/pad.png $out/pad.png --width 78 --colors 40
$px $raw/crop063/drone_factory.png $out/drone_factory.png --width 80 --rembg --colors 40
$px $raw/crop063/hangar.png $out/hangar.png --width 82 --rembg --colors 40
$px $raw/crop063/storage.png $out/storage.png --width 82 --rembg --colors 40
$px $raw/crop063/museum.png $out/museum.png --width 83 --rembg --colors 40
# 우주선·조종사·부품·광물 더미는 각자 놓이는 건물이 커진 비율(연구소·착륙장 1.35배, 창고 1.19배)로 키움
$px $raw/ship.png $out/ship.png --width 28 --colors 40
$px $raw/pilot.png $out/pilot.png --width 5 --colors 40
$px $raw/research_parts.png $out/research_parts.png --scale 0.0535 --split --colors 40
$px $raw/piles.png $out/pile.png --scale 0.056 --split --colors 40
