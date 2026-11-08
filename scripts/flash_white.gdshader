shader_type canvas_item;
// 맞은 적·운석 흰색 번쩍임: 그림 모양(알파)은 그대로 두고 색만 흰색으로 칠한다.
// 원래 그림 위에 겹쳐 그리고, 그릴 때 modulate 알파(0~1)가 흰색을 섞는 정도가 된다.

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a);
}
