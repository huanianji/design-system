extends "res://adapters/godot/observe_management_states.gd"

var checks:Array=[]
var clipboard_backup:String

func observe() -> Dictionary:
	var owner:=root.gui_get_focus_owner()
	return {"viewport":[root.size.x,root.size.y],"note":app.note.text,"note_status":app.note_field.status,"note_message":app.note_message.text,"note_editable":app.note.editable,"note_busy":app.note_busy,"otp":app.otp.value(),"slots":app.otp.slots.duplicate(),"otp_status":app.otp.status,"otp_message":app.otp_message.text,"otp_busy":app.otp_busy,"focused_digit":app.otp.focused,"focus":str(owner.name) if owner else "","mode":app.mode,"enlarged":app.enlarged,"reduced":app.reduced,"code_gap":app.otp.track.get_theme_constant("separation"),"cell_height":app.otp.fields[0].size.y,"code_width":app.otp.size.x,"track_width":app.otp.track.size.x,"last_slot_right":app.otp.boxes[-1].get_global_rect().end.x,"group_right":app.otp.get_global_rect().end.x,"plate_x":app.otp.plate.position.x,"plate_target":app.otp.boxes[maxi(0,app.otp.focused)].position.x}

func record(id:String,passed:bool,actions:Array) -> void:
	RenderingServer.force_draw()
	var path:="evidence/inputs-"+id+"-godot.png"
	root.get_texture().get_image().save_png("res://"+path)
	checks.append({"id":id,"passed":passed,"actions":actions,"observed":observe(),"screenshot":path})
	print("PASS " if passed else "FAIL ",id)

func click(id:String) -> void:await pointer(app.find_child(id,true,false).get_global_rect().get_center())

func shortcut(code:Key) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed
		event.meta_pressed=OS.get_name()=="macOS";event.ctrl_pressed=OS.get_name()!="macOS"
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func paste(control:Control,text:String) -> void:
	await pointer(control.get_global_rect().get_center())
	DisplayServer.clipboard_set(text)
	await shortcut(KEY_V)
	await wait(0.1)

func multiline(control:Control,text:String) -> void:
	await pointer(control.get_global_rect().get_center());await shortcut(KEY_A);await key(KEY_BACKSPACE)
	for character in text:
		if character=="\n":await key(KEY_ENTER)
		else:
			var event:=InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true
			Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/inputs.tscn").instantiate();root.add_child(app);root.grab_focus()
	await wait(0.4)
	if not is_instance_valid(app.note_field) or not is_instance_valid(app.otp):quit(2);return
	clipboard_backup=DisplayServer.clipboard_get()
	await click("SaveNote")
	record("note-required",app.note_field.status=="error" and app.note.has_focus(),["pointer:save-empty-note"])
	await multiline(app.note,"今晚聊新歌\n保留中文和空格")
	await key(KEY_TAB)
	record("note-edit-and-tab",app.note.text=="今晚聊新歌\n保留中文和空格" and app.note_field.status=="idle" and root.gui_get_focus_owner()==app.save_button,["input:chinese-multiline","key:Tab"])
	await click("FailNext");await click("SaveNote");await wait(0.8)
	record("note-failure-preserves",app.note_field.status=="error" and app.note.text=="今晚聊新歌\n保留中文和空格" and app.note.editable,["pointer:fail-next","pointer:save-note","wait:result"])
	await click("FailNext");await click("SaveNote");await wait(0.8)
	record("note-retry",app.note_field.status=="success",["pointer:allow-success","pointer:save-note","wait:result"])
	await click("ReadOnly");await pointer(app.note.get_global_rect().get_center());await key(KEY_BACKSPACE)
	record("readonly-preserves",not app.note.editable and app.note.text=="今晚聊新歌\n保留中文和空格" and app.note.has_focus(),["pointer:readonly","pointer:note","key:Backspace"])
	await click("ReadOnly");await click("Disabled");await pointer(app.note.get_global_rect().get_center())
	record("disabled-skips-input",not app.note.editable and not app.note.has_focus(),["pointer:editable","pointer:disabled","pointer:note"])
	await click("Disabled");await click("Clear")
	for character in "123":
		var event:=InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events();await wait(0.03)
	record("otp-sequential",app.otp.slots.slice(0,3)==["1","2","3"] and app.otp.focused==3 and app.otp.track.size.x<=app.otp.size.x+1 and not is_equal_approx(app.otp.plate.position.x,app.otp.boxes[3].position.x),["pointer:enable","pointer:clear","input:123"])
	await click("Clear");await paste(app.otp.fields[0],"０１２３４５")
	record("otp-paste-leading-zero",app.otp.value()=="012345" and app.otp.focused==5,["pointer:clear","paste:fullwidth-012345"])
	await paste(app.otp.fields[2],"98")
	record("otp-partial-paste",app.otp.value()=="019845" and app.otp.focused==4,["pointer:digit2","paste:98"])
	await key(KEY_BACKSPACE);await key(KEY_BACKSPACE)
	record("otp-backspace",app.otp.slots==["0","1","9","8","","5"] and app.otp.focused==3,["key:Backspace","key:Backspace"])
	await key(KEY_HOME);await key(KEY_END);await key(KEY_LEFT);await key(KEY_DELETE)
	record("otp-navigation-delete",app.otp.focused==4 and app.otp.slots[4]=="",["key:Home","key:End","key:ArrowLeft","key:Delete"])
	await click("Verify")
	record("otp-incomplete",app.otp.status=="error" and app.otp.focused==4,["pointer:verify-incomplete"])
	await click("Clear");await paste(app.otp.fields[0],"654321");await click("Verify");await wait(0.8)
	record("otp-mismatch",app.otp.status=="error" and app.otp.value()=="654321",["pointer:clear","paste:654321","pointer:verify","wait:result"])
	await paste(app.otp.fields[0],"123456");await click("FailNext");await click("Verify");await wait(0.8)
	record("otp-request-failure",app.otp.status=="error" and app.otp.value()=="123456",["paste:123456","pointer:fail-next","pointer:verify","wait:result"])
	await click("FailNext");await click("Verify");await wait(0.8)
	record("otp-retry-success",app.otp.status=="success" and not app.otp_busy,["pointer:allow-success","pointer:verify","wait:result"])
	await click("Mode");await click("Scale");await wait(0.2)
	record("theme-scale-preserve",app.mode=="dark" and app.enlarged and app.otp.value()=="123456" and app.note.text=="今晚聊新歌\n保留中文和空格",["pointer:mode","pointer:scale"])
	await click("Clear");await paste(app.otp.fields[0],"12");await click("Reduce");await wait(0.1)
	var settled:bool=app.otp.labels.all(func(item):return item.offset_transform_position==Vector2.ZERO and is_equal_approx(item.modulate.a,1))
	record("reduce-settles",app.reduced and settled and app.otp.value()=="12",["pointer:clear","paste:12","pointer:reduce"])
	root.size=Vector2i(800,720);await wait(0.3)
	record("compact-125",app.card.get_global_rect().end.x<=780 and app.otp.get_global_rect().end.x<=780 and app.otp.boxes[-1].get_global_rect().end.x<=app.otp.get_global_rect().end.x+1,["window:800x720"])
	DisplayServer.clipboard_set(clipboard_backup)
	var sources:Dictionary={}
	for path in ["components/godot/input_field.gd","components/godot/otp_input.gd","sample/inputs_lab.gd","adapters/godot/verify_inputs.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open("res://evidence/inputs-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","source_files":sources,"input_driver":"Input.parse_input_event; clipboard paste; committed Unicode is not system IME evidence","checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free();await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
