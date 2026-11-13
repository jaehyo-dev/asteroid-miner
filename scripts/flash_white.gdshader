shader_type canvas_item;
// 맞은 적·운석 번쩍임: 그림 모양(알파)은 그대로 두고 색만 modulate 색(흰색, 공명 파쇄는 금빛)으로 칠한다.
// 원래 그림 위에 겹쳐 그리고, 그릴 때 modulate 알파(0~1)가 색을 섞는 정도가 된다.

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
