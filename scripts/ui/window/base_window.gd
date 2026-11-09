class_name BaseWindow
extends Control
## 건물 창 공통 틀: 금속 틀, 머리줄(건물 아이콘·이름, 보유 광물, 닫기), 열고 닫는 움직임과 소리, 픽셀 격자.
## 창 안은 SubViewport 하나에 논리 픽셀로 그리고 정수 배율로 키운다. 기지 화면이 소수 배율이어도 창의 픽셀과 글자는 고르게 보인다.
## 건물은 _build의 표에 한 줄과 내용 Control만 더한다.

signal closed
## 연구소에서 무언가를 샀을 때
signal bought(id: String)
## 위쪽 띠가 보이는 비율 (창이 열리면 위로 들어간다)
signal band_changed(ratio: float)

const OPEN_TIME := 0.18
const CLOSE_TIME := 0.14
const FRAME_MARGIN := 26
const INSET := 15
## 이 논리 크기보다 작으면 폰 배치: 틀을 줄이고 설명은 아래 띠로
const COMPACT_BELOW := Vector2i(560, 300)

var save: SaveData
## 지금 열린 화면 (닫혀 있으면 "")
var kind := ""
var close_button: Button
## 지금 내용 (테스트용)
var view: WindowView
var compact := false
## 창 논리 크기, 물리 픽셀 배율
var logical := Vector2i(640, 360)
var pixel_k := 2

var _dim: ColorRect
var _box: SubViewportContainer
var _sub: SubViewport
var _root: Control
var _frame: Control
var _t := 0.0
var _closing := false
var _scale := 1.0


## 물리 창 크기와 기기 픽셀 비율로 정수 배율을 고른다: CSS 픽셀 기준 2배 이상, 논리 640x360이 들어오는 만큼
static func scale_for(physical: Vector2i, dpr: float) -> int:
	var css := Vector2(physical) / maxf(dpr, 1.0)
	var k_css := maxi(2, floori(minf(css.x / 640.0, css.y / 360.0)))
	return maxi(1, roundi(k_css * maxf(dpr, 1.0)))


static func is_compact(size_logical: Vector2i) -> bool:
	return size_logical.x < COMPACT_BELOW.x or size_logical.y < COMPACT_BELOW.y


## 틀 사각형 (창 논리 좌표). 폰은 틀 일부를 화면 밖으로 밀어 내용을 넓힌다
static func frame_rect(size_logical: Vector2i, is_small: bool) -> Rect2i:
	return Rect2i(-6, -7, size_logical.x + 12, size_logical.y + 14) if is_small else Rect2i(6, 6, size_logical.x - 12, size_logical.y - 12)


static func head_h(is_small: bool) -> int:
	return 22 if is_small else 28


## 내용 사각형
static func body_rect(size_logical: Vector2i, is_small: bool) -> Rect2i:
	var f := frame_rect(size_logical, is_small)
	var top := f.position.y + INSET - 4 + head_h(is_small) + 2
	return Rect2i(f.position.x + INSET, top, f.size.x - 2 * INSET, f.end.y - INSET - top)


## 머리줄과 틀을 그린다
class Frame extends Control:
	var win: BaseWindow

	func _draw() -> void:
		var f := BaseWindow.frame_rect(win.logical, win.compact)
		WindowArt.plate(self, "frame", Rect2(f), BaseWindow.FRAME_MARGIN, BaseWindow.FRAME_MARGIN)
		var h := BaseWindow.head_h(win.compact)
		var head := Rect2i(f.position.x + BaseWindow.INSET - 3, f.position.y + BaseWindow.INSET - 4, f.size.x - 2 * (BaseWindow.INSET - 3), h)
		WindowArt.plate(self, "head", Rect2(head))
		if win.kind.is_empty():
			return
		var icon := WindowArt.tex("build_" + win.kind)
		draw_texture(icon, Vector2(head.position.x + 12, head.position.y + (h - icon.get_height()) / 2))
		var ty := head.position.y + (h - WindowArt.FONT_SIZE) / 2 - 1
		WindowArt.text(self, Vector2i(head.position.x + 12 + icon.get_width() + 6, ty), BaseLayout.NAMES[win.kind], WindowArt.TEAL2)
		var money := Hud.thousands(win.save.credits)
		var right := int(win.close_button.position.x) - 8
		WindowArt.text(self, Vector2i(right, ty), money, WindowArt.GOLD, 1)
		var ore := RunSprites.mineral(3)
		draw_texture(ore, Vector2(right - WindowArt.width(money) - ore.get_width() - 4, head.position.y + (h - ore.get_height()) / 2))


## 닫기 버튼: 빨간 판 + X
class CloseButton extends Button:
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var t := WindowArt.tex("close")
		draw_texture(t, Vector2(0, 1 if is_pressed() else 0), WindowArt.MUTED if is_hovered() and not is_pressed() else Color.WHITE)
		var mid := t.get_size() / 2.0 + Vector2(0, 1 if is_pressed() else 0)
		for i in range(-4, 5):
			draw_rect(Rect2(mid + Vector2(i, i) - Vector2.ONE, Vector2(2, 2)), WindowArt.INK)
			draw_rect(Rect2(mid + Vector2(i, -i) - Vector2.ONE, Vector2(2, 2)), WindowArt.INK)
		WindowArt.focus_mark(self)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 열려 있으면 뒤쪽 기지를 누를 수 없다
	_dim = ColorRect.new()
	_dim.color = Color(8.0 / 255.0, 6.0 / 255.0, 14.0 / 255.0, 190.0 / 255.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_box = SubViewportContainer.new()
	_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_box)
	_sub = SubViewport.new()
	_sub.transparent_bg = true
	_sub.disable_3d = true
	_sub.handle_input_locally = true
	_sub.oversampling = false  # 글자를 언제나 12칸으로 만들어 정수 배율로 키운다
	_sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_box.add_child(_sub)
	_root = Control.new()
	_sub.add_child(_root)
	_frame = Frame.new()
	_frame.win = self
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)
	close_button = CloseButton.new()
	close_button.pressed.connect(close)
	_root.add_child(close_button)
	hide()
	set_process(false)
	get_tree().root.size_changed.connect(_on_resized)


func _on_resized() -> void:
	if visible and is_inside_tree() and not kind.is_empty():
		_fit()
		_build()


## 창 크기에 맞춰 논리 크기·배율을 정한다
func _fit() -> void:
	var physical := get_window().size
	# 웹만 창 크기가 실제 기기 픽셀이다 (데스크톱은 hidpi를 안 켜서 창 크기가 이미 CSS 픽셀 기준)
	pixel_k = scale_for(physical, DisplayServer.screen_get_scale() if OS.has_feature("web") else 1.0)
	logical = Vector2i(maxi(physical.x / pixel_k, 1), maxi(physical.y / pixel_k, 1))
	compact = is_compact(logical)
	_sub.size = logical
	_box.size = Vector2(logical)
	_scale = pixel_k * get_viewport_rect().size.x / maxf(physical.x, 1.0)  # 기지 화면 좌표 1칸 → 물리 픽셀 환산
	_box.scale = Vector2(_scale, _scale)
	_root.size = Vector2(logical)
	_frame.size = Vector2(logical)
	var f := frame_rect(logical, compact)
	var h := head_h(compact)
	var cs := WindowArt.tex("close").get_size()
	close_button.size = cs
	close_button.position = Vector2(f.end.x - INSET + 3 - cs.x - 8, f.position.y + INSET - 4 + (h - cs.y) / 2)
	_frame.queue_redraw()


func _build() -> void:
	if view != null:
		_root.remove_child(view)
		view.queue_free()
		view = null
	match kind:  # 건물 하나에 한 줄
		"research":
			view = ResearchView.new()
		"hangar":
			view = HangarView.new()
		"storage":
			view = StorageView.new()
		"museum":
			view = MuseumView.new()
		"drone":
			view = DroneView.new()
	view.win = self
	var body := body_rect(logical, compact)
	view.position = Vector2(body.position)
	view.size = Vector2(body.size)
	_root.add_child(view)
	_root.move_child(view, 1)
	view.setup()


## 건물 창을 연다.
func open(new_kind: String) -> void:
	kind = new_kind
	_fit()
	_build()
	_closing = false
	_t = 0.0
	Sfx.play("open")
	show()
	set_process(true)
	_apply(0.0)
	close_button.grab_focus(true)  # 표시는 키보드로 움직일 때만


## 위쪽 띠·어둡기·창 위치. ratio 0 = 닫힘, 1 = 열림
func _apply(ratio: float) -> void:
	_dim.modulate.a = ratio
	_box.position.y = roundf((1.0 - ratio) * logical.y) * _scale
	band_changed.emit(1.0 - ratio)


func _process(delta: float) -> void:
	_t += delta
	if _closing:
		var k := minf(_t / CLOSE_TIME, 1.0)
		_apply(1.0 - k * k)
		if k >= 1.0:
			_finish_close()
	else:
		var k := minf(_t / OPEN_TIME, 1.0)
		_apply(1.0 - (1.0 - k) * (1.0 - k))
		if k >= 1.0:
			set_process(false)


## 닫는다 (소리와 움직임 포함)
func close() -> void:
	if not visible or _closing:
		return
	Sfx.play("close")
	_closing = true
	_t = 0.0
	set_process(true)


func _finish_close() -> void:
	set_process(false)
	_closing = false
	kind = ""
	hide()
	if view != null:
		_root.remove_child(view)
		view.queue_free()
		view = null
	band_changed.emit(1.0)
	closed.emit()


## 머리줄(보유 광물)을 다시 그린다
func refresh_head() -> void:
	_frame.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
