shader_type canvas_item;
// 레벨업 카드 부품의 등급 색 바꾸기. 원본 색(src)을 등급 색(dst)으로 바꾼다.
// dst의 알파가 0이면 대각선 무지개가 흐르는 자리(레전드리)이고, 값은 띠 폭(픽셀) / 100이다.
// rainbow_all이 켜지면 모든 픽셀을 무지개로 칠한다 (레전드리 이름과 바깥 빛).

const int MAX_COLORS = 16;
const float MATCH = 0.02;
const float FLOW_SPEED = 40.0;  // 초당 흐르는 픽셀

uniform int color_count = 0;
uniform vec3 src[MAX_COLORS];
uniform vec4 dst[MAX_COLORS];
uniform bool rainbow_all = false;

varying vec2 local_pos;
varying vec4 tint;  // 노드의 modulate. 색을 비교할 때는 빼고 봐야 눌림·꺼짐 상태에서도 등급 색이 유지된다

vec3 rainbow(float band_width) {
	const vec3 COLORS[7] = vec3[7](
		vec3(0.949, 0.361, 0.463), vec3(0.973, 0.580, 0.098), vec3(0.965, 0.808, 0.314),
		vec3(0.647, 0.800, 0.373), vec3(0.188, 0.882, 0.725), vec3(0.600, 0.914, 0.902), vec3(0.659, 0.518, 0.953));
	// 픽셀 격자를 벗어나지 않게 좌표와 시간을 모두 정수로 내려서 쓴다
	float n = floor((floor(local_pos.x) + floor(local_pos.y) + floor(TIME * FLOW_SPEED)) / band_width);
	return COLORS[int(mod(n, 7.0))];
}

void vertex() {
	local_pos = VERTEX;
	tint = COLOR;
}

void fragment() {
	vec4 c = COLOR;
	if (rainbow_all) {
		c.rgb = rainbow(10.0) * tint.rgb;
	} else {
		vec3 art = texture(TEXTURE, UV).rgb;
		for (int i = 0; i < color_count; i++) {
			if (distance(art, src[i]) < MATCH) {
				c.rgb = (dst[i].a > 0.5 ? dst[i].rgb : rainbow(dst[i].r * 100.0)) * tint.rgb;
				break;
			}
		}
	}
	COLOR = c;
}
