// 워프 게이트 안쪽 소용돌이.
// 화면이 커져도 게임 픽셀(640x360 기준) 격자에 맞춰 각지게 그리고, 색도 4단계로 끊어 픽셀 아트처럼 보이게 한다.
shader_type canvas_item;

// 지름의 게임 픽셀 수 (사각형 크기와 같게)
uniform float grid = 44.0;
// 회전 각 (스크립트가 누적해서 넘김: 충전할수록 빨라짐)
uniform float spin = 0.0;
// 0 보라·청록 → 1 붉은색 (닫히기 직전)
uniform float heat : hint_range(0.0, 1.0) = 0.0;
// 열린 정도 (반지름 비율, 등장·닫힘 연출)
uniform float open : hint_range(0.0, 1.0) = 1.0;
// 충전 밝기
uniform float glow : hint_range(0.0, 1.0) = 0.0;

// 어두운 → 밝은 4단계
const vec3 COOL[4] = vec3[4](vec3(0.08, 0.04, 0.20), vec3(0.33, 0.12, 0.62), vec3(0.55, 0.24, 0.88), vec3(0.18, 0.88, 0.82));
const vec3 WARM[4] = vec3[4](vec3(0.18, 0.02, 0.05), vec3(0.55, 0.06, 0.10), vec3(0.88, 0.18, 0.18), vec3(1.00, 0.55, 0.35));

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * grid);
	vec2 p = (cell + 0.5) / grid * 2.0 - 1.0;
	float r = length(p);
	if (r > open) {
		COLOR = vec4(0.0);
	} else {
		float a = atan(p.y, p.x);
		// 나선 팔 3개: 바깥쪽일수록 더 휘어 안쪽으로 감겨 드는 모양
		float arms = sin(a * 3.0 + r * 7.0 - spin);
		float v = (arms * 0.5 + 0.5) * (1.0 - r * 0.55) + (1.0 - r) * 0.3 + glow * 0.25;
		int level = int(floor(clamp(v, 0.0, 0.999) * 4.0));
		vec3 col = mix(COOL[level], WARM[level], heat);
		// 반짝이는 별 알갱이 (자리가 조금씩 바뀜)
		if (hash(cell + floor(spin * 1.5)) > 0.975) {
			col = mix(vec3(0.85, 1.0, 1.0), vec3(1.0, 0.8, 0.6), heat);
		}
		// 가운데 밝은 핵 (충전할수록 커짐)
		if (r < 0.12 + glow * 0.12) {
			col = mix(col, vec3(1.0), 0.55 + glow * 0.45);
		}
		// 가장자리 한 칸은 어둡게 (고리 안쪽 그림자)
		if (r > open - 2.0 / grid) {
			col *= 0.5;
		}
		COLOR = vec4(col, 1.0);
	}
}
