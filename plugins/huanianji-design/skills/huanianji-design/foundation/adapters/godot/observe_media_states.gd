extends SceneTree

var app
var phase := "before"
var cases: Array=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
	call_deferred("run")

func wait(seconds: float=0.08) -> void:
	await create_timer(seconds).timeout
	await process_frame

func pointer(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new()
	move.position=point
	Input.parse_input_event(move)
	await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame

func key(name: String) -> void:
	var code:Key=KEY_TAB if name=="Tab" else (KEY_ENTER if name=="Enter" else KEY_SPACE)
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame

func observation() -> Dictionary:
	var focus:Control=root.gui_get_focus_owner()
	var item_id:Variant=null
	var region:Variant=null
	var visible:=false
	var nested:=0
	var extra:=false
	var raw:Dictionary={}
	for id in app.asset_tiles:
		var panel:Control=app.asset_tiles[id].panel
		var button:Button=app.asset_tiles[id].button
		nested+=panel.find_children("*","BaseButton",true,false).size()
		if focus==button:
			item_id=id
			var whole:=panel.get_global_rect()
			var inner:=button.get_global_rect()
			region="whole_item" if whole.is_equal_approx(inner) else "inner_label"
			var box:=button.get_theme_stylebox("focus")
			visible=box is StyleBoxFlat and box.border_color.a>0 and box.get_border_width(SIDE_LEFT)>0
			extra=visible and region!="whole_item"
			raw={"focus_rect":[inner.position.x,inner.position.y,inner.size.x,inner.size.y],"item_rect":[whole.position.x,whole.position.y,whole.size.x,whole.size.y],"focus_style":box.get_class(),"variation":button.theme_type_variation}
	return {"selected":app.asset_id,"visible_focus_item":item_id if visible else null,"visible_focus_region":region if visible else null,"focus_visible":visible,"inner_action_controls":nested,"extra_inner_indicator":extra,"raw":raw}

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/fragments.tscn").instantiate()
	root.add_child(app)
	await wait(0.3)
	if not app.initialized:
		quit(1)
		return
	app.set_view("creative")
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://sample/media-review.json"))
	var current_mode:=""
	for scenario in contract.cases:
		var mode:String=scenario.id.get_slice("/",0)
		if mode!=current_mode:
			app.set_mode(mode)
			app.select_asset("starlight")
			if root.gui_get_focus_owner():root.gui_get_focus_owner().release_focus()
			current_mode=mode
			await wait(0.5)
		for action in scenario.actions:
			var parts:PackedStringArray=action.split(":")
			if parts[0]=="key":await key(parts[1])
			elif parts[1]=="canvas":await pointer(app.get_node("%Canvas").get_global_rect().get_center())
			else:
				var panel:Control=app.asset_tiles[parts[1]].panel
				var captions:=panel.find_children("*","Label",true,false)
				var target:Control=panel.find_children("*","TextureRect",true,false)[0] if parts[2]=="image" else (captions[0] if not captions.is_empty() else app.asset_tiles[parts[1]].button)
				await pointer(target.get_global_rect().get_center())
		await wait(0.5)
		var screenshot:String="evidence/media-"+phase+"-godot-"+scenario.id.replace("/","-")+".png"
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://"+screenshot)
		cases.append({"id":scenario.id,"actions":scenario.actions,"context":{"build_id":app.manifest.build_id,"fixture":app.manifest.inputs["sample/fragments.json"],"viewport":[root.size.x,root.size.y],"text_scale":1,"theme":app.mode,"reduced":app.reduced},"observed":observation(),"screenshot":screenshot})
	var file:=FileAccess.open("res://evidence/media-"+phase+"-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","evidence_root":"..","input_driver":"Input.parse_input_event","implementation_sha256":FileAccess.get_sha256("res://adapters/godot/fragments.gd"),"adapter_sha256":FileAccess.get_sha256("res://adapters/godot/observe_media_states.gd"),"cases":cases},"\t"))
	print("OBSERVED ",cases.size()," actual input checkpoints")
	app.queue_free()
	await process_frame
	quit()
