#!/usr/bin/env bash
# 지금 브랜치를 웹으로 내보내고, 같은 와이파이의 폰에서도 열 수 있게 HTTPS로 띄운다 (main 배포·Pages와 무관).
# 사용: bash tools/serve_web.sh   (멈추려면 Ctrl+C, 포트는 PORT=8443 처럼 바꿀 수 있음)
#
# 왜 HTTPS인가: Godot 웹 엔진은 보안 컨텍스트(HTTPS 또는 localhost)가 아니면 시작하지 않는다
# ("Secure Context" 오류). 폰은 맥의 주소(192.168.x.x)로 열어서 localhost가 아니므로 HTTPS가 필요하다.
# 인증서는 이 맥에서 만든 자체 서명 인증서(build/serve/, 저장소에 안 올라감)라 폰에 경고가 한 번 뜬다.
# 스레드 없는 내보내기라 COOP/COEP 헤더는 필요 없다.
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=${PORT:-8443}
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
mkdir -p build/web build/serve
bash tools/export_web.sh "$PWD" "$PWD/build/web" "$version" > /dev/null
ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
cert=build/serve/cert.pem
key=build/serve/key.pem
# 맥 주소가 바뀌면(다른 와이파이) 인증서를 다시 만든다
if [ ! -f "$cert" ] || [ "$(cat build/serve/ip 2>/dev/null)" != "$ip" ]; then
	openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=asteroid-miner-local" \
		-addext "subjectAltName=IP:$ip,IP:127.0.0.1,DNS:localhost" -keyout "$key" -out "$cert" 2> /dev/null
	echo "$ip" > build/serve/ip
fi
echo "게임 버전 $version (브랜치 $(git branch --show-current), 커밋 $(git rev-parse --short HEAD))"
echo "맥:  https://localhost:$PORT/"
echo "폰:  https://$ip:$PORT/   (같은 와이파이, 경고가 뜨면 '고급' → '계속' / 아이폰은 '세부사항 보기' → '이 웹 사이트 방문')"
exec python3 - "$PORT" "$cert" "$key" <<'PY'
import http.server, ssl, sys, functools
port, cert, key = int(sys.argv[1]), sys.argv[2], sys.argv[3]
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory="build/web")
handler.func.extensions_map[".wasm"] = "application/wasm"
server = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(cert, key)
server.socket = ctx.wrap_socket(server.socket, server_side=True)
server.serve_forever()
PY
