#!/usr/bin/env bash
# 웹 내보내기 + 게임 파일 이름에 버전을 붙인다 (game-<버전>.js/.wasm/.pck).
# 버전이 바뀌면 파일 주소가 바뀌어서, 브라우저가 옛 파일(캐시)을 쓰지 않는다. 진입 파일은 index.html 그대로.
# 사용: bash tools/export_web.sh <프로젝트 폴더> <출력 폴더> <버전>
# (출력 폴더가 프로젝트 안이면 미리 .gdignore를 넣어 둘 것: Godot가 결과물을 리소스로 가져오지 않게)
set -euo pipefail
project=$1
out=$2
name="game-$3"
mkdir -p "$out"
godot --headless --path "$project" --import
godot --headless --path "$project" --export-release "Web" "$out/$name.html"
for ext in js wasm pck; do
	test -s "$out/$name.$ext"
done
mv "$out/$name.html" "$out/index.html"
