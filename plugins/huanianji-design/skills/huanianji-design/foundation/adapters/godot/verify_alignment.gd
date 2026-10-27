extends SceneTree

var app
var checks: Array = []

func _initialize() -> void:
	call_deferred("run")

func wait(seconds: float = 0.08) -> void:
	await create_timer(seconds).timeout
	await process_frame

func check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	print("CHECK ",name,": ",passed)

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/fragments.tscn").instantiate()
	root.add_child(app)
	await wait(0.3)
	if not app.initialized:
		quit(1)
		return
	var panel: Control=app.get_node("%DetailContent")
	var roster_rect: Rect2=app.get_node("%Roster").get_global_rect()
	app.tree_items.tangli.select(0)
	var start:float=panel.offset_transform_scale.x
	var peak:=1.0
	var minimum_y:=0.0
	var stable:=true
	var time:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-time<550:
		peak=maxf(peak,panel.offset_transform_scale.x)
		minimum_y=minf(minimum_y,panel.offset_transform_position.y)
		stable=stable and roster_rect.is_equal_approx(app.get_node("%Roster").get_global_rect())
		await process_frame
	check("detail_selection_has_visible_rebound",start<0.98 and peak>1.01 and minimum_y< -3 and app.selected=="tangli",{"start":start,"peak":peak,"minimum_y":minimum_y})
	check("detail_motion_keeps_roster_layout",stable)
	check("detail_motion_settles",panel.offset_transform_scale.is_equal_approx(Vector2.ONE) and panel.offset_transform_position.is_zero_approx() and is_equal_approx(panel.modulate.a,1.0))
	app.tree_items.qianyu.select(0)
	await wait(0.08)
	var from_scale:Vector2=panel.offset_transform_scale
	var from_position:Vector2=panel.offset_transform_position
	app.tree_items.xiaocheng.select(0)
	check("rapid_selection_continues_current_visual_state",from_scale.is_equal_approx(panel.offset_transform_scale) and from_position.is_equal_approx(panel.offset_transform_position))
	await wait(0.1)
	app.set_mode("dark")
	await wait(0.5)
	check("rapid_selection_and_theme_keep_latest_detail",app.selected=="xiaocheng" and app.get_node("%DetailName").text=="小澄" and panel.offset_transform_scale.is_equal_approx(Vector2.ONE))
	app.tree_items.linxi.select(0)
	await wait(0.06)
	app.set_reduced(true)
	check("reduce_during_detail_motion_settles",panel.offset_transform_scale.is_equal_approx(Vector2.ONE) and panel.offset_transform_position.is_zero_approx() and is_equal_approx(panel.modulate.a,1.0))
	app.tree_items.tangli.select(0)
	check("reduced_selection_is_immediate",app.get_node("%DetailName").text=="棠梨" and panel.offset_transform_scale.is_equal_approx(Vector2.ONE))
	app.set_reduced(false)
	app.set_mode("light")
	app.tree_items.linxi.select(0)
	await wait(0.5)
	await app.capture("alignment-godot-management-light")
	var rows: Array=[]
	for person in app.fixture.streamers:
		var item:TreeItem=app.tree_items[person.id]
		rows.append({"id":person.id,"name":item.get_text(0),"topic_tooltip":item.get_tooltip_text(0),"slot":item.get_text(1),"status":item.get_text(2),"ready":item.get_text(3)})
	var audit:Dictionary={"roster":rows,"detail_topic":app.get_node("%DetailTopic").text,"list_height":app.get_node("%Roster").size.y,"preview_height":app.get_node("%Canvas").custom_minimum_size.y,"category_style":app.get_node("%CategoryAll").theme_type_variation,"filter_labels":[app.get_node("%AllFilter").text,app.get_node("%AttentionFilter").text,app.get_node("%LiveFilter").text,app.get_node("%ScheduledFilter").text]}
	app.set_view("creative")
	await wait(0.2)
	await app.capture("alignment-godot-creative-light")
	var file:=FileAccess.open("res://evidence/alignment-godot-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"build_id":app.manifest.build_id,"checks":checks,"failed":checks.filter(func(c):return not c.passed),"audit":audit},"\t"))
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
