extends SceneTree

var app
var checks: Array = []
const Inspect=preload("res://adapters/godot/typography_inspect.gd")

func has_font_role(node: Control, size: int, weight: int) -> bool:
	var font:Font=node.get_theme_font("font")
	var glyphs:Array=Inspect.shape("华年集 19",font,node.get_theme_font_size("font_size")).glyphs
	return node.get_theme_font_size("font_size")==size and glyphs.all(func(g):return float(g.axes.get(str(2003265652),g.axes.get(2003265652,0)))==float(weight))

func roster_cells_fit() -> Dictionary:
	var tree:Tree=app.get_node("%Roster")
	var font:Font=tree.get_theme_font("font")
	var size:int=tree.get_theme_font_size("font_size")
	var padding:int=tree.get_theme_constant("h_separation")*2
	var cells:Array=[]
	for item in app.tree_items.values():
		for column in [1,2,3]:
			var text_width:float=font.get_string_size(item.get_text(column),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			var width:float=tree.get_item_area_rect(item,column).size.x-padding
			cells.append({"column":column,"text":item.get_text(column),"text_width":text_width,"available":width,"fits":text_width<=width})
	return {"passed":cells.all(func(c):return c.fits),"cells":cells}

func _initialize() -> void:
	call_deferred("run")

func _process(_delta: float) -> bool:
	# 测试中的截图等待需要确定的绘制帧；不改变正式工程的渲染配置。
	RenderingServer.force_draw()
	return false

func wait(seconds: float = 0.12) -> void:
	await create_timer(seconds).timeout
	await process_frame

func check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	print("CHECK ",name,": ",passed)

func pointer(button: Button, pressed: bool) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,960)
	app = load("res://sample/fragments.tscn").instantiate()
	root.add_child(app)
	await wait(0.4)
	if not app.initialized:
		check("source_loaded",false)
		quit(1)
		return
	check("source_loaded",not app.bundle.is_empty() and app.get_node("%Workspace").visible,app.manifest.build_id)
	check("small_font_and_shared_shape",app.theme.default_font_size==17 and app.roles.optical.check_x==-1.5)
	check("management_default_count",app.filtered_people().size()==6 and app.selected=="linxi")
	check("compact_labels_do_not_wrap",app.get_node("%ReadyCount").size.x>=app.get_node("%ReadyCount").get_minimum_size().x and app.get_node("%DetailStatus").get_line_count()==1)
	check("fragment_filter_role",has_font_role(app.get_node("%AllFilter"),14,400))
	check("fragment_local_heading_roles",has_font_role(app.get_node("%ChecksTitle"),17,600) and has_font_role(app.get_node("%LibraryLabel"),17,600))
	check("fragment_asset_name_and_caption_roles",has_font_role(app.asset_tiles.starlight.label,17,400) and has_font_role(app.get_node("%CreativeCaption"),14,400))
	check("fragment_category_role",has_font_role(app.get_node("%CategoryAll"),14,400))
	var normal_cells:=roster_cells_fit()
	check("roster_values_complete_100",normal_cells.passed,normal_cells.cells)
	await app.capture("fragments-godot-management-light")
	app.get_node("%Query").text="棠梨"
	app.rebuild_roster()
	check("search_selects_visible_person",app.filtered_people().size()==1 and app.selected=="tangli")
	app.get_node("%Query").text="不存在的主播"
	app.rebuild_roster()
	check("empty_result_has_no_stale_detail",app.selected.is_empty() and app.get_node("%DetailEmpty").visible)
	app.get_node("%Query").text=""
	app.set_filter("attention")
	check("status_filter",app.filtered_people().size()==2 and app.selected=="linxi")
	app.get_node("%Task2").button_pressed=true
	await wait(0.4)
	check("check_updates_person_and_roster",app.people.linxi.checks[2] and app.tree_items.linxi.get_text(3)=="3 / 3")
	app.set_note_open(true)
	await wait(0.5)
	app.get_node("%Note").text="跨主题保留的开播备注"
	app.get_node("%Note").text_changed.emit()
	app.get_node("%Note").grab_focus()
	app.set_mode("dark")
	await wait()
	check("management_theme_preserves_state_and_focus",app.people.linxi.note=="跨主题保留的开播备注" and app.note_open and app.status_filter=="attention" and root.gui_get_focus_owner()==app.get_node("%Note"))
	await app.capture("fragments-godot-management-dark")
	app.set_note_open(false)
	check("collapse_returns_hidden_input_focus",root.gui_get_focus_owner()==app.get_node("%NoteToggle") and app.get_node("%Note").focus_mode==Control.FOCUS_NONE)
	await wait(0.5)
	app.set_note_open(true)
	await wait(0.08)
	var height: float=app.get_node("%NoteReveal").custom_minimum_size.y
	app.set_note_open(false)
	check("disclosure_interrupt_is_continuous",is_equal_approx(height,app.get_node("%NoteReveal").custom_minimum_size.y))
	app.set_reduced(true)
	check("reduced_motion_settles",is_zero_approx(app.get_node("%NoteReveal").custom_minimum_size.y) and app.feedbacks.values().all(func(f):return f.visual_scale.is_equal_approx(Vector2.ONE)))
	app.set_reduced(false)
	var action: Button=app.get_node("%AttentionAction")
	var rect:=action.get_global_rect()
	await pointer(action,true)
	await wait(0.2)
	var down:float=action.offset_transform_scale.x
	await wait(0.3)
	check("long_press_holds",down<0.96 and action.offset_transform_scale.x<0.96,down)
	await pointer(action,false)
	var peak:=1.0
	var started:=Time.get_ticks_msec()
	var stable:=true
	while Time.get_ticks_msec()-started<520:
		peak=maxf(peak,action.offset_transform_scale.x)
		stable=stable and rect.is_equal_approx(action.get_global_rect())
		await process_frame
	check("daily_rebound_and_stable_hit_area",peak>1.04 and stable and action.offset_transform_scale.is_equal_approx(Vector2.ONE),peak)
	app.set_view("creative")
	app.set_mode("light")
	await wait()
	check("creative_uses_distinct_accent_shared_font",app.roles.palette.light.accent==app.bundle.profiles.creative.godot.palette.light.accent and app.theme.default_font_size==17 and app.roles.space.group==20)
	await app.capture("fragments-godot-creative-light")
	var canvas=app.get_node("%Canvas")
	var original:Vector2=canvas.art_rect().size
	app.get_node("%Zoom").value=130
	app.get_node("%Opacity").value=40
	await wait()
	check("continuous_controls_change_actual_canvas",canvas.art_rect().size.x>original.x*1.29 and canvas.opacity==40 and app.previews.starlight.zoom==130,{"before":original,"after":canvas.art_rect().size,"opacity":canvas.opacity})
	await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image().get_region(Rect2i(canvas.get_global_rect()))
	app.set_mode("dark")
	await wait()
	await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image().get_region(Rect2i(canvas.get_global_rect()))
	check("theme_preserves_preview_pixels_and_values",before.get_data()==after.get_data() and canvas.zoom==130 and canvas.opacity==40)
	await app.capture("fragments-godot-creative-dark")
	app.select_asset("warmframe")
	app.get_node("%Zoom").value=80
	app.select_asset("starlight")
	check("parameters_are_per_asset",canvas.zoom==130 and canvas.opacity==40 and app.previews.warmframe.zoom==80)
	app.set_category("scene")
	check("category_filters_actual_assets",app.asset_id=="window" and not app.asset_tiles.starlight.panel.visible and app.asset_tiles.window.panel.visible)
	app.set_category("all")
	app.select_asset("starlight")
	app.reset_preview()
	check("reset_changes_actual_canvas",canvas.zoom==100 and canvas.opacity==100 and app.get_node("%ResetPreview").disabled)
	app.set_view("management")
	check("view_switch_preserves_management",app.people.linxi.checks[2] and app.people.linxi.note=="跨主题保留的开播备注" and app.selected=="linxi" and app.status_filter=="attention")
	root.size=Vector2i(800,720)
	app.enlarged=true
	app.apply_theme()
	await wait(0.3)
	check("management_compact_125_fits",app.get_node("%Workspace").get_global_rect().end.x<=780 and app.get_node("%ManagementGrid").columns==1)
	var large_cells:=roster_cells_fit()
	check("roster_values_complete_125",large_cells.passed,large_cells.cells)
	check("fragment_local_heading_roles_125",has_font_role(app.get_node("%ChecksTitle"),21,600) and has_font_role(app.get_node("%LibraryLabel"),21,600))
	await app.capture("fragments-godot-management-compact-125")
	app.set_view("creative")
	await wait(0.3)
	check("creative_compact_125_fits",app.get_node("%Workspace").get_global_rect().end.x<=780 and app.get_node("%CreativeGrid").columns==1)
	await app.capture("fragments-godot-creative-compact-125")
	for target in [app.get_node("%ManagementView"),app.get_node("%TextScale")]:
		await pointer(target,true)
		await pointer(target,false)
	await wait(0.3)
	var reset_cells:=roster_cells_fit()
	check("roster_125_to_100_resets",not app.enlarged and app.get_node("%Roster").get_theme_font_size("font_size")==17 and reset_cells.passed and is_equal_approx(reset_cells.cells[0].available,normal_cells.cells[0].available),reset_cells.cells)
	await pointer(app.get_node("%TextScale"),true)
	await pointer(app.get_node("%TextScale"),false)
	await wait(0.3)
	var repeated_cells:=roster_cells_fit()
	check("roster_repeated_125_complete",app.enlarged and repeated_cells.passed,repeated_cells.cells)
	var file:=FileAccess.open("res://evidence/fragments-godot-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"build_id":app.manifest.build_id,"checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
