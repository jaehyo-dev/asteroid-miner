extends Node
## 방법 (a): 우주선 스프라이트에 두께를 줘서 복셀 모형으로 만들고, 저해상도 SubViewport에 찍어 nearest로 키운다.
## 모형을 받침 면과 나란히 눕혀 세로축으로 돌리고, 카메라는 ELEV도로 비스듬히 내려다본다. 진열대 위 장난감 비행기처럼 보이게.
## 인자: -- 카메라각도 코들기각도 동체높이 (bake.py가 넘긴다)
## 빛 계산을 쓰지 않고 면 방향별 밝기를 칸 색에 미리 구워서, 화면의 모든 칸이 void32 색 그대로다.

const VIEW := Vector2i(64, 56)  # 찍는 해상도. 화면에는 정수배로 키운다
const MAX_HALF := 4  # 가장자리에서 안쪽으로 세는 칸 수
const PERIOD := 6.0  # 한 바퀴 초
const PAL: Array[Color] = [Color("#000000"), Color("#14111c"), Color("#2b1925"), Color("#3c3544"), Color("#5c5164"), Color("#70525e"), Color("#917487"), Color("#a5b29d"), Color("#fef8e5")]  # 그늘 색. 보라·자홍으로 번지지 않게 무채색 쪽만

var pivot: Node3D
var elev := 35.0  # 카메라가 내려다보는 각도
var nose := 6.0  # 코를 살짝 든 각도. 거치대에 얹은 모형처럼
var body := 6.0  # 동체 윗면 높이(칸). 옆에서 볼 때 얇아지지 않게. 날개는 2칸

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 3:
		elev = a[0].to_float()
		nose = a[1].to_float()
		body = a[2].to_float()
	var bg := ColorRect.new()
	bg.color = Color("#ff00ff") if not OS.has_feature("web") else Color("#14111c")  # 캡처 때 마젠타를 빼서 시안에 합성
	bg.size = Vector2(VIEW) * display_scale()
	add_child(bg)
	var sv := SubViewport.new()
	sv.size = VIEW
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	pivot = Node3D.new()
	sv.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh(load("res://ship.png").get_image())
	mi.rotation.x = deg_to_rad(nose)
	pivot.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW.y  # 세로 VIEW.y칸 = 복셀 한 칸이 정면에서 1픽셀
	cam.position = Vector3(0, sin(deg_to_rad(elev)), cos(deg_to_rad(elev))) * 60.0
	sv.add_child(cam)
	cam.look_at(Vector3.ZERO)
	var tr := TextureRect.new()
	tr.texture = sv.get_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size = Vector2(VIEW) * display_scale()
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)

func display_scale() -> int:
	return 6  # 정수 배율. macOS는 아주 작은 창을 못 만들어 캡처도 6배로 찍고 bake.py가 원래 격자로 되돌린다

func _process(_d: float) -> void:
	var t := Engine.get_process_frames() / float(Engine.max_fps if Engine.max_fps > 0 else 20)
	if OS.has_feature("web"):
		t = Time.get_ticks_msec() / 1000.0
	pivot.rotation.y = t / PERIOD * TAU

func nearest(c: Color) -> Color:
	var best := PAL[0]
	var bd := 1e9
	for p in PAL:
		var d := (c.r - p.r) ** 2 + (c.g - p.g) ** 2 + (c.b - p.b) ** 2
		if d < bd:
			bd = d
			best = p
	return best

func build_mesh(img: Image) -> ArrayMesh:
	var w := img.get_width()
	var h := img.get_height()
	# 가장자리에서 얼마나 안쪽인가 = 두께. 날개 끝은 얇고 동체는 두껍다
	var depth := {}
	var cells := {}
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				cells[Vector2i(x, y)] = img.get_pixel(x, y)
				depth[Vector2i(x, y)] = 1
	var nb: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in MAX_HALF:
		var nxt := depth.duplicate()
		for p: Vector2i in depth:
			if nb.all(func(n): return depth.has(p + n) and depth[p + n] == depth[p]):
				nxt[p] = depth[p] + 1
		depth = nxt
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for p: Vector2i in cells:
		var top_col: Color = cells[p]
		var side := body_color(p, cells)
		var x0 := p.x - w / 2.0
		var z0 := p.y - h / 2.0
		var up := cell_up(p, depth, w)  # 윗면 높이
		var down := -ceilf(up * 0.5)
		quad(st, Vector3(x0, up, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), top_col)
		quad(st, Vector3(x0, down, z0), Vector3(0, 0, 1), Vector3(1, 0, 0), nearest(side * 0.4))
		quads += 2
		# 옆면은 이웃보다 높은 만큼만. 방향마다 밝기가 달라 돌 때 입체가 읽힌다
		for n: Vector2i in nb:
			var other_up := float(depth.get(p + n, -99))
			var other_dn := -ceilf(other_up * 0.5) if depth.has(p + n) else 99.0
			var shade: float = {Vector2i(1, 0): 0.8, Vector2i(-1, 0): 0.55, Vector2i(0, 1): 0.45, Vector2i(0, -1): 0.95}[n]
			var col := nearest(side * shade)
			if other_up < up:
				side_quad(st, p, n, w, h, maxf(other_up, down), up, col)
				quads += 1
			if other_dn > down and depth.has(p + n):
				side_quad(st, p, n, w, h, down, minf(other_dn, up), col)
				quads += 1
	print("칸 ", cells.size(), " 면 ", quads, " 삼각형 ", quads * 2)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()

## 가운데 동체는 높고 날개는 낮다. 가장자리는 깊이만큼 줄여 코와 날개 끝을 뾰족하게
func cell_up(p: Vector2i, depth: Dictionary, w: int) -> float:
	var dx := absf(p.x + 0.5 - w / 2.0)
	var h := body if dx <= 3.0 else (body - 2.0 if dx <= 5.0 else 2.0)
	return minf(h, depth[p] * 2.0)

## 윤곽선 칸(거의 검정)의 옆면은 안쪽 몸통 색으로 칠한다. 안 그러면 두께가 전부 검게 보인다
func body_color(p: Vector2i, cells: Dictionary) -> Color:
	var c: Color = cells[p]
	if c.get_luminance() > 0.15:
		return c
	for r in range(1, 5):
		for d: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			if cells.has(p + d) and (cells[p + d] as Color).get_luminance() > 0.15:
				return cells[p + d]
	return Color("#5c5164")

func side_quad(st: SurfaceTool, p: Vector2i, n: Vector2i, w: int, h: int, y0: float, y1: float, col: Color) -> void:
	var x := p.x - w / 2.0 + (1.0 if n.x > 0 else 0.0)
	var z := p.y - h / 2.0 + (1.0 if n.y > 0 else 0.0)
	var along := Vector3(0, 0, 1) if n.x != 0 else Vector3(1, 0, 0)
	quad(st, Vector3(x, y0, z), along, Vector3(0, y1 - y0, 0), col)

func quad(st: SurfaceTool, o: Vector3, a: Vector3, b: Vector3, col: Color) -> void:
	for v: Vector3 in [o, o + a, o + a + b, o, o + a + b, o + b]:
		st.set_color(col)
		st.add_vertex(v)
