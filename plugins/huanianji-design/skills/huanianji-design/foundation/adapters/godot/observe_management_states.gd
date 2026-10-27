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
	move.global_position=point
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func key(code: Key, shift: bool=false) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.shift_pressed=shift
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func input_text(control: Control, value: String) -> void:
	await pointer(control.get_global_rect().get_center())
	# 走平台全选快捷键和字符输入，未直接赋值 .text；不代表系统中文输入法验收。
	for pressed in [true,false]:
		var select_all:=InputEventKey.new()
		select_all.keycode=KEY_A
		select_all.meta_pressed=OS.get_name()=="macOS"
		select_all.ctrl_pressed=OS.get_name()!="macOS"
		select_all.pressed=pressed
		Input.parse_input_event(select_all)
		Input.flush_buffered_events()
		await process_frame
	await key(KEY_BACKSPACE)
	for character in value:
		var event:=InputEventKey.new()
		event.unicode=character.unicode_at(0)
		event.pressed=true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func observation() -> Dictionary:
	var rows:Array=[]
	for id in app.tree_items:
		var item:TreeItem=app.tree_items[id]
		var lines:=str(item.get_meta("identity",item.get_text(0))).split("\n")
		rows.append({"id":id,"name":lines[0],"topic":lines[1] if lines.size()>1 else null,"slot":item.get_text(1),"status":item.get_text(2),"ready":item.get_text(3)})
	var visible:bool=app.get_node("%DetailContent").is_visible_in_tree()
	var slot:String=app.get_node("%DetailSlot").text
	var topic:String=app.get_node("%DetailTopic").text
	var labels:Array=[]
	if slot.begins_with("时段  "):labels.append("时段")
	if topic.begins_with("内容  "):labels.append("内容")
	var checks:Array=[]
	for i in range(3):
		if visible:checks.append(app.get_node("%Task"+str(i)).button_pressed)
	var selected_item:TreeItem=app.get_node("%Roster").get_selected()
	var focus:Control=root.gui_get_focus_owner()
	var focus_id:Variant=null
	if focus:
		focus_id={"Note":"note","NoteToggle":"note-toggle","Query":"query","Task0":"task-0","Task1":"task-1","Task2":"task-2"}.get(str(focus.name),str(focus.name))
	var detail:Control=app.get_node("%DetailContent")
	var reveal:Control=app.get_node("%NoteReveal")
	return {"rows":rows,"selected":str(selected_item.get_metadata(0)) if selected_item else null,"result_count":app.get_node("%ResultCount").text,
		"detail_visible":visible,"empty_visible":app.get_node("%RosterEmpty").is_visible_in_tree(),
		"detail":{"name":app.get_node("%DetailName").text,"slot":slot.trim_prefix("时段  "),"topic":topic.trim_prefix("内容  "),"labels":labels,"status":app.get_node("%DetailStatus").text} if visible else null,
		"checks":checks,"note":app.get_node("%Note").text if visible else null,
		"note_open":visible and reveal.size.y>0,"note_focusable":visible and app.get_node("%Note").focus_mode!=Control.FOCUS_NONE,
		"detail_settled":detail.offset_transform_scale.is_equal_approx(Vector2.ONE) and detail.offset_transform_position.is_zero_approx(),"focus":focus_id,"focus_visible":focus.has_focus(true) if focus else false,
		"raw":{"detail_scale":detail.offset_transform_scale.x,"detail_y":detail.offset_transform_position.y,"detail_alpha":detail.modulate.a,"arrow_rotation":app.get_node("%NoteArrow").rotation,"note_height":reveal.size.y}}

func action(value: String) -> void:
	var parts:=value.split(":")
	if parts[0]=="key":await key(KEY_TAB if parts[1] in ["Tab","ShiftTab"] else (KEY_ENTER if parts[1]=="Enter" else KEY_SPACE),parts[1]=="ShiftTab")
	elif parts[0]=="text":
		var prefix:=parts[0]+":"+parts[1]+":"
		await input_text(app.get_node("%Query" if parts[1]=="query" else "%Note"),value.trim_prefix(prefix))
	elif parts[1]=="person":
		var tree:Tree=app.get_node("%Roster")
		var item:TreeItem=app.tree_items[parts[2]]
		tree.scroll_to_item(item)
		await process_frame
		await pointer(tree.global_position+tree.get_item_area_rect(item,0).get_center())
	else:
		var names:={"mode":"Mode","reduce":"Reduce","note-toggle":"NoteToggle","note":"Note"}
		var name:String=names.get(parts[1],"")
		if parts[1]=="task":name="Task"+parts[2]
		if parts[1]=="filter":name={"all":"AllFilter","attention":"AttentionFilter","live":"LiveFilter","scheduled":"ScheduledFilter"}[parts[2]]
		await pointer(app.get_node("%"+name).get_global_rect().get_center())

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/fragments.tscn").instantiate()
	root.add_child(app)
	root.grab_focus()
	await wait(0.5)
	if not app.initialized:quit(1);return
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://sample/management-review.json"))
	for scenario in contract.cases:
		for value in scenario.actions:await action(value)
		await wait(0.55)
		var screenshot:String="evidence/management-"+phase+"-godot-"+scenario.id+".png"
		# 静止或后台窗口未必再发绘制信号；主动绘制当前视口后读取真实像素。
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://"+screenshot)
		cases.append({"id":scenario.id,"actions":scenario.actions,"context":{"build_id":app.manifest.build_id,"fixture":app.manifest.inputs["sample/fragments.json"],"viewport":[root.size.x,root.size.y],"text_scale":1,"theme":app.mode,"reduced":app.reduced},"observed":observation(),"screenshot":screenshot})
	var file:=FileAccess.open("res://evidence/management-"+phase+"-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","evidence_root":"..","input_driver":"Input.parse_input_event (pointer, keyboard shortcut, Unicode characters)","implementation_sha256":FileAccess.get_sha256("res://adapters/godot/fragments.gd"),"adapter_sha256":FileAccess.get_sha256("res://adapters/godot/observe_management_states.gd"),"cases":cases},"\t"))
	print("OBSERVED ",cases.size()," management input checkpoints")
	app.queue_free()
	await process_frame
	quit()
