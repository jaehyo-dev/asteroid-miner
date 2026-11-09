extends SceneTree
## 격납고 빛기둥 GIF 프레임: godot --path . --resolution 1280x720 -s res://review/v070_fix_impl/holo/shoot_holo.gd -- pc [진하기 0~2]
## 시간을 직접 넘겨 프레임을 고정한다. user://holo/<태그>/ 에 PNG

const STEP := 1.0 / 13.33
const FRAMES := 80  # 6초: 2바퀴, 주사선 1주기


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var style := int(args[1]) if args.size() > 1 else 1
	var tag: String = "%s_s%d" % [args[0], style]
	DirAccess.make_dir_recursive_absolute("user://holo/" + tag)
	load("res://scripts/logic/save_data.gd").path = "user://shoot_save.json"
	root.get_node("App").set_base_mode(true)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.panel.open("hangar")
	await create_timer(0.4).timeout
	var v: Control = main.panel.view
	v.set_process(false)
	v.beam_style = style
	for f in FRAMES:
		v._t = f * STEP
		v.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://holo/%s/%03d.png" % [tag, f])
	quit()
