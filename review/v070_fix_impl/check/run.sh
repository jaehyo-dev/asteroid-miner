#!/usr/bin/env bash
# 캡처 실행: bash review/v070_fix_impl/check/run.sh <pc|phone> [return]  (창이 뜨고, 400초 넘으면 끔)
cd "$(dirname "$0")/../../.."
res=$([ "$1" = phone ] && echo 844x390 || echo 1280x720)
godot --path . --resolution "$res" --fixed-fps 25 -s res://review/v070_fix_impl/check/capture.gd -- "$@" &
pid=$!
for i in $(seq 1 400); do kill -0 $pid 2>/dev/null || break; sleep 1; done
kill $pid 2>/dev/null
wait $pid
