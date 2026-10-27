extends SceneTree

var app
var checks: Array = []
var expected_body := 17

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-body="): expected_body = int(arg.trim_prefix("--expected-body="))
	call_deferred("run")

func wait(seconds: float = 0.08) -> void:
	await create_timer(seconds).timeout
	await process_frame

func check(name: String, value: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":value,"detail":detail})
	print("CHECK ",name,": ",value)

func mouse(button: Button, down: bool) -> void:
	var point := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	Input.parse_input_event(move)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,960)
	app = load("res://sample/main.tscn").instantiate()
	root.add_child(app)
	await wait(0.2)
	check("shared_source_loaded",app.get_node("%Card").visible and not app.bundle.is_empty())
	check("generated_font_size_consumed",app.theme.default_font_size==expected_body,app.theme.default_font_size)
	var font := app.theme.default_font as FontVariation
	var axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	check("actual_font_weight",font.variation_opentype[axis]==400 and (app.get_node("%Title").get_theme_font("font") as FontVariation).variation_opentype[axis]==600)
	var sample: String = app.bundle.content.Title+app.bundle.content.Subtitle+"Aa 0123456789%·，。"
	check("main_font_covers_sample",sample.to_utf32_buffer().size()>0 and Array(sample.split("")).all(func(c):return font.base_font.has_char(c.unicode_at(0))))
	await app.capture("godot-light")
	app.get_node("%TopicInput").text = "跨端共同源，保留草稿"
	app.get_node("%TopicInput").grab_focus()
	app.get_node("%ReadyCheck").set_pressed_no_signal(false)
	app.get_node("%CheckArt").progress = 0
	app.select_tab(2)
	app.set_expanded(true)
	app.get_node("%Brightness").value = 42
	await wait(0.5)
	app.set_mode("dark")
	app.set_profile("jade-demo")
	await wait()
	check("theme_preserves_input_selection_and_expansion",app.get_node("%TopicInput").text=="跨端共同源，保留草稿" and not app.get_node("%ReadyCheck").button_pressed and app.selected==2 and app.expanded and app.get_node("%Brightness").value==42)
	check("theme_preserves_focus",root.gui_get_focus_owner()==app.get_node("%TopicInput"))
	check("product_accent_consumed",app.get_node("%SceneLabel").get_theme_color("font_color")==Color(app.roles.palette.dark.accent))
	await app.capture("godot-dark-jade")
	app.set_expanded(false)
	await wait(0.5)
	var action := app.get_node("%Action") as Button
	var rect := action.get_global_rect()
	await mouse(action,true)
	await wait(0.13)
	var down: float = action.offset_transform_scale.x
	await mouse(action,false)
	var peak := 1.0
	var start := Time.get_ticks_msec()
	var stable := true
	while Time.get_ticks_msec()-start<520:
		peak = maxf(peak,action.offset_transform_scale.x)
		stable = stable and rect.is_equal_approx(action.get_global_rect())
		await process_frame
	check("approved_rebound_and_hit_area",down<0.96 and peak>1.04 and stable and action.offset_transform_scale.is_equal_approx(Vector2.ONE),{"down":down,"peak":peak})
	check("native_click_activates_once",app.clicks==1)
	app.set_expanded(true)
	await wait(0.1)
	var height: float = app.get_node("%Reveal").custom_minimum_size.y
	app.set_expanded(false)
	check("disclosure_reversal_continuous",is_equal_approx(height,app.get_node("%Reveal").custom_minimum_size.y))
	app.set_reduced(true)
	check("reduced_motion_settles",is_zero_approx(app.get_node("%Reveal").custom_minimum_size.y) and app.button_feedback.values().all(func(f):return f.visual_scale.is_equal_approx(Vector2.ONE)))
	app.set_reduced(false)
	app.set_profile("baseline")
	app.set_mode("light")
	root.size = Vector2i(800,640)
	app.toggle_text_scale()
	await wait(0.2)
	app.set_expanded(true)
	await wait(0.5)
	check("compact_and_125_percent_fit",app.get_node("%Card").get_global_rect().end.x<=780 and app.get_node("%Body").size.x<=app.get_node("%Card").size.x)
	await app.capture("godot-compact-125")
	var file := FileAccess.open("res://evidence/godot-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"build_id":app.manifest.build_id,"checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
