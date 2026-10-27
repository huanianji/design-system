extends "res://adapters/godot/observe_management_states.gd"

var checks:Array=[]

func check(name: String, passed: bool, detail: Variant=null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	print("PASS " if passed else "FAIL ",name)

func save_image(name: String) -> String:
	RenderingServer.force_draw()
	var path:="evidence/management-motion-"+phase+"-godot-"+name+".png"
	root.get_texture().get_image().save_png("res://"+path)
	return path

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/fragments.tscn").instantiate()
	root.add_child(app)
	root.grab_focus()
	await wait(0.5)
	if not app.initialized:quit(1);return
	await action("pointer:task:2")
	await action("pointer:person:xiaocheng")
	await wait(0.55)
	var glyph:float=app.get_node("%TaskArt2").progress
	check("check_motion_belongs_to_current_person",is_zero_approx(glyph) and not app.get_node("%Task2").button_pressed,{"glyph_progress":glyph,"checked":app.get_node("%Task2").button_pressed,"screenshot":await save_image("person-check")})
	await action("pointer:person:linxi")
	await input_text(app.get_node("%Query"),"绘画")
	check("filter_cancels_previous_detail_motion",app.selected=="yuehe" and app.get_node("%DetailContent").offset_transform_scale.is_equal_approx(Vector2.ONE),observation())
	await wait(0.5)
	await action("pointer:note-toggle")
	await wait(0.06)
	var arrow:float=app.get_node("%NoteArrow").rotation
	check("arrow_moves_with_disclosure",arrow>0 and arrow<PI,{"angle":arrow,"height":app.get_node("%NoteReveal").size.y})
	await action("pointer:note-toggle")
	await wait(0.06)
	var reverse_angle:float=app.get_node("%NoteArrow").rotation
	check("reverse_keeps_intermediate_angle",reverse_angle>0 and reverse_angle<PI,{"angle":reverse_angle})
	await action("pointer:mode")
	await wait(0.55)
	check("theme_during_collapse_preserves_target",app.mode=="dark" and not app.note_open and is_zero_approx(app.get_node("%NoteReveal").size.y) and is_zero_approx(app.get_node("%NoteArrow").rotation),observation())
	await action("pointer:note-toggle")
	await wait(0.04)
	await action("pointer:reduce")
	check("reduce_during_disclosure_settles",app.reduced and is_equal_approx(app.get_node("%NoteArrow").rotation,PI) and is_equal_approx(app.get_node("%NoteReveal").custom_minimum_size.y,app.note_target),observation())
	await input_text(app.get_node("%Query"),"")
	await action("pointer:person:xiaocheng")
	await key(KEY_UP)
	check("tree_keyboard_selection_survives_custom_first_column",app.selected=="qianyu",observation())
	# 视口 / 字号是场景条件，目标操作仍走输入。
	root.size=Vector2i(900,960)
	await wait(0.2)
	await pointer(app.get_node("%TextScale").get_global_rect().get_center())
	await wait(0.3)
	var workspace:Control=app.get_node("%Workspace")
	check("compact_125_layout",app.enlarged and app.get_node("%ManagementGrid").columns==1 and workspace.get_global_rect().end.x<=900,{"workspace":str(workspace.get_global_rect()),"screenshot":await save_image("compact-125")})
	var file:=FileAccess.open("res://evidence/management-motion-"+phase+"-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"build_id":app.manifest.build_id,"implementation_sha256":FileAccess.get_sha256("res://adapters/godot/fragments.gd"),"input_driver":"Input.parse_input_event","checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
