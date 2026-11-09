#!/usr/bin/env bash
# 캡처 프레임 → GIF·PNG를 review/v070_fix_impl/check/<태그>/로 (팔레트 생성, 디더 없음: 픽셀 아트 그대로)
cd "$(dirname "$0")"
D="$HOME/Library/Application Support/Godot/app_userdata/소행성 광부/check"
for tag in pc phone; do
	mkdir -p "$tag"
	cp "$D/$tag"/*.png "$tag/"
	for c in "$D/$tag"/*/; do
		name=$(basename "$c")
		ffmpeg -y -loglevel error -framerate 25 -i "$c%04d.png" -vf "split[a][b];[a]palettegen=max_colors=128:stats_mode=full[p];[b][p]paletteuse=dither=none" "$tag/$name.gif"
	done
done
