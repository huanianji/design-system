extends "res://adapters/godot/observe_management_states.gd"

var checks:Array=[]
var traces:Array=[]
var active:Dictionary={}
var started:int
var observed_build:String
var input_delivery:Array=[]

func click(name:String) -> void:
	var control:Control=app.get_node("%"+name)
	if app.get_node("%Scroll").is_ancestor_of(control):app.get_node("%Scroll").ensure_control_visible(control)
	await process_frame
	var delivered:Dictionary={"target":name,"pressed":false,"disabled":control.disabled if control is Button else false,"rect":str(control.get_global_rect())}
	var listener:Callable=func():delivered.pressed=true
	if control is Button:control.pressed.connect(listener)
	await pointer(control.get_global_rect().get_center())
	await process_frame
	if control is Button:
		control.pressed.disconnect(listener)
		if not delivered.disabled and not delivered.pressed:push_error("真实指针未触发按钮："+name)
	input_delivery.append(delivered)

func person(id:String) -> void:
	var tree:Tree=app.get_node("%Roster")
	app.get_node("%Scroll").ensure_control_visible(tree)
	await process_frame
	await pointer(tree.global_position+tree.get_item_area_rect(app.tree_items[id],0).get_center())

func asset(id:String, title:bool=false) -> void:
	var entry:Dictionary=app.asset_tiles[id]
	app.get_node("%Scroll").ensure_control_visible(entry.button)
	await process_frame
	var rect:Rect2=entry.label.get_global_rect() if title else entry.button.get_global_rect()
	await pointer(rect.get_center()-Vector2(0,0 if title else 20))

func observe() -> Dictionary:
	var snap:Dictionary=app.snapshot()
	var local:Dictionary=app.people.get(app.selected,{})
	var focus:Control=root.gui_get_focus_owner()
	var values:Dictionary=app.previews.get(app.asset_id,{})
	var mic:Control=app.get_node("%Microphone")
	var note:Control=app.get_node("%Note")
	var save:Button=app.get_node("%NoteSave")
	return {"view":snap.view,"mode":snap.mode,"enlarged":snap.enlarged,"reduced":snap.reduced,"selected":null if app.selected.is_empty() else app.selected,"visible":snap.visible,"checks":local.get("checks",[]).duplicate(true),"note":local.get("note",""),"saved":local.get("savedNote",""),"status":local.get("noteStatus",""),"message":app.get_node("%NoteMessage").text,"busy":not app.pending_note.is_empty(),"note_disabled":not note.editable,"mic":local.get("mic",true),"mic_label":mic.text,"open":app.note_open,"asset":app.asset_id,"category":app.category,"zoom":values.get("zoom",0),"opacity":values.get("opacity",0),"reset_disabled":app.get_node("%ResetPreview").disabled,"focus":str(focus.name) if focus else "","focus_visible":focus.has_focus(true) if focus else false,"note_role":note.get_theme_font_size("font_size"),"save_focusable":save.focus_mode!=Control.FOCUS_NONE and not save.disabled,"fits":app.get_node("%Workspace").get_global_rect().end.x<=root.size.x and app.get_node("%Inspector").get_global_rect().end.x<=root.size.x,"mic_hover_color":mic.get_theme_color("font_hover_pressed_color").to_html(false),"accent":app.palette().accent,"viewport":[root.size.x,root.size.y]}

func record(id:String, actions:Array) -> void:
	await wait(0.05 if id=="note-pending" else 0.55)
	var screenshot:="evidence/combined-"+id+"-godot.png"
	RenderingServer.force_draw();root.get_texture().get_image().save_png("res://"+screenshot)
	checks.append({"id":id,"actions":actions,"observed":observe(),"screenshot":screenshot})

func sample_frame() -> Dictionary:
	var save:Button=app.get_node("%NoteSave")
	var rect:Rect2=save.get_global_rect()
	return {"ms":(Time.get_ticks_usec()-started)/1000.0,"bell":app.icons.bell.target.rotation_degrees,"mic":app.icons.microphone.progress,"mic_scale":app.icons.microphone.target.scale.x,"arrow":app.icons.direction.target.rotation_degrees,"height":app.get_node("%NoteReveal").size.y,"target_height":app.get_node("%NoteInner").get_combined_minimum_size().y,"asset":app.get_node("%Canvas").art_alpha*float(app.previews[app.asset_id].opacity)/100.0,"save_scale":save.offset_transform_scale.x,"busy":not app.pending_note.is_empty(),"mic_enabled":app.people[app.selected].mic,"open":app.note_open,"mode":app.mode,"reduced":app.reduced,"save_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}

func _process(_delta:float) -> bool:
	if not active.is_empty():active.frames.append(sample_frame())
	return false

func press_control(name:String, down:bool) -> void:
	var control:Control=app.get_node("%"+name)
	var move:=InputEventMouseMotion.new();move.position=control.get_global_rect().get_center();Input.parse_input_event(move)
	var event:=InputEventMouseButton.new();event.position=move.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func trace_event(kind:String, target:String) -> void:
	if not active.is_empty():active.events.append({"type":kind,"key":target,"ms":(Time.get_ticks_usec()-started)/1000.0})

func fresh() -> void:
	if is_instance_valid(app):app.queue_free();await process_frame
	app=load("res://sample/fragments.tscn").instantiate();root.add_child(app);root.grab_focus();await wait(0.3)
	observed_build=app.manifest.build_id

func trace_case(id:String) -> void:
	await fresh()
	if id.begins_with("asset"):
		await click("CreativeView")
	elif id.begins_with("save"):
		await click("NoteToggle");await wait(0.5)
		app.get_node("%Scroll").ensure_control_visible(app.get_node("%NoteSave"));await process_frame
		if id=="save-failure":await click("SimulateFailure")
	if id.ends_with("reduced"):await click("Reduce")
	var node_name:String="AttentionAction" if id.begins_with("bell") else "Microphone" if id.begins_with("mic") else "NoteToggle" if id.begins_with("arrow") else "NoteSave"
	if id.begins_with("asset"):node_name="Asset_warmframe"
	var control:Button=app.find_child(node_name,true,false)
	app.get_node("%Scroll").ensure_control_visible(control);await process_frame
	for sig in ["button_down","button_up","pressed"]:control.connect(sig,trace_event.bind(sig,node_name))
	if id=="mic-keyboard":
		await click("Microphone");await key(KEY_TAB);await key(KEY_TAB,true);await wait(0.55)
		# 上一步鼠标切为静音；从当前真实键盘焦点激活为开启。
	started=Time.get_ticks_usec();active={"id":id,"frames":[],"events":[]}
	if id=="mic-keyboard":await key(KEY_SPACE)
	elif id.begins_with("asset"):await asset("warmframe")
	elif id.begins_with("save"):
		await press_control(node_name,true);await wait(0.16);await press_control(node_name,false)
	else:await click(node_name)
	if id in ["bell-repeat","mic-reverse","arrow-reverse"]:
		await wait(0.12);await click(node_name)
	elif id=="mic-theme":await wait(0.12);await click("Mode")
	elif id=="mic-reduce-mid":await wait(0.12);await click("Reduce")
	elif id=="mic-hide":await wait(0.12);await click("CreativeView");await click("ManagementView")
	await wait(1.3)
	traces.append(active);active={}

func run() -> void:
	root.size=Vector2i(1280,960)
	await fresh();await record("management-initial",[])
	await click("Microphone");await record("mic-off",["pointer:microphone"])
	await click("Task2");await record("task-toggle",["pointer:task2"])
	await click("NoteToggle");await wait(0.5)
	await input_text(app.get_node("%Note"),"今晚先聊新歌。")
	await record("note-draft",["pointer:note-toggle","input:note"])
	await click("SimulateFailure");await click("NoteSave");await record("note-pending",["pointer:simulate-failure","pointer:save-note"])
	await wait(0.3);await record("note-failure",["wait:result"])
	await click("SimulateFailure");await click("NoteSave");await wait(0.75);await record("note-success",["pointer:allow-success","pointer:save-note"])
	await person("tangli");await record("switch-person",["pointer:tangli"])
	await person("linxi");await record("return-person",["pointer:linxi"])
	await input_text(app.get_node("%Note"),"尚未提交的草稿")
	await click("NoteSave");await person("tangli");await wait(0.75);await record("cancel-owner",["input:draft","pointer:save-note","pointer:tangli"])
	await person("linxi");await record("cancel-preserves-draft",["pointer:linxi"])
	await input_text(app.get_node("%Query"),"不存在的主播");await record("empty-results",["input:query-no-match"])
	await input_text(app.get_node("%Query"),"");await record("recover-results",["clear:query"])
	await click("Mode");await record("dark-preserve",["pointer:mode"])
	await click("TextScale");await record("enlarged-preserve",["pointer:text-scale"])
	await click("CreativeView");await record("creative-initial",["pointer:creative"])
	await asset("warmframe");await record("asset-image",["pointer:warmframe-image"])
	await asset("window",true);await record("asset-title",["pointer:window-title"])
	await click("Zoom");await key(KEY_END)
	for i in 20:await key(KEY_LEFT)
	await click("Opacity");await key(KEY_END)
	for i in 35:await key(KEY_LEFT)
	await record("preview-adjust",["key:zoom-120","key:opacity-65"])
	await asset("starlight");await asset("window");await record("preview-return",["pointer:starlight","pointer:window"])
	await click("ResetPreview");await record("preview-reset",["pointer:reset-preview"])
	await click("CategoryFrame");await record("creative-category",["pointer:category-frame"])
	await click("Mode");await record("creative-light",["pointer:mode"])
	root.size=Vector2i(800,720);await record("compact-125",["window:800x720"])
	root.size=Vector2i(1280,960)
	for id in ["bell-once","bell-repeat","bell-reduced","mic-off","mic-reverse","mic-keyboard","mic-theme","mic-reduce-mid","mic-hide","arrow-open","arrow-reverse","arrow-reduced","asset-switch","asset-reduced","save-busy","save-failure"]:await trace_case(id)
	var sources:Dictionary={}
	for path in ["adapters/godot/fragments.gd","adapters/godot/canvas_preview.gd","adapters/godot/verify_combined.gd","sample/fragments.tscn","components/godot/dynamic_icon.gd","components/godot/action_button.gd","components/godot/disclosure.gd","components/godot/input_field.gd","components/godot/input_focus.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open("res://evidence/combined-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","build_id":observed_build,"source_files":sources,"checks":checks,"traces":traces,"input_delivery":input_delivery,"input_driver":"Input.parse_input_event; native Control hit testing, keys and text; frame samples"},"\t"));quit()
