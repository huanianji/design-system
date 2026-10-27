extends "res://adapters/godot/observe_management_states.gd"

var checks:Array=[]
func click(id:String) -> void:await pointer(app.find_child(id,true,false).get_global_rect().get_center())
func record(id:String,passed:bool,observed:Dictionary,actions:Array) -> void:
	RenderingServer.force_draw()
	var path:="evidence/input-extra-"+id+"-godot.png";root.get_texture().get_image().save_png("res://"+path)
	checks.append({"id":id,"passed":passed,"observed":observed,"actions":actions,"screenshot":path});print("PASS " if passed else "FAIL ",id)

func run() -> void:
	root.size=Vector2i(1280,960);app=load("res://sample/inputs.tscn").instantiate();root.add_child(app);root.grab_focus();await wait(0.4)
	if not is_instance_valid(app.note_field):quit(2);return
	await input_text(app.note,"今晚新歌");await click("SaveNote");await click("Mode");await wait(0.8)
	record("pending-theme",app.mode=="dark" and app.note.text=="今晚新歌" and app.note_field.status=="success",{"mode":app.mode,"note":app.note.text,"status":app.note_field.status},["input:note","pointer:save-note","pointer:mode-during-busy","wait:result"])
	await click("Clear")
	for character in "123456":
		var event:=InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
	await click("ReadOnly");await pointer(app.otp.fields[0].get_global_rect().get_center());await key(KEY_BACKSPACE)
	record("otp-readonly",app.otp.value()=="123456" and app.otp.fields[0].has_focus(),{"value":app.otp.value(),"focused":app.otp.focused},["input:123456","pointer:readonly","pointer:digit0","key:Backspace"])
	await click("ReadOnly");await click("Verify");await click("Verify");await wait(0.8)
	record("repeat-blocked",app.otp.status=="success" and not app.otp_busy and app.verify_button.get_node("ButtonFeedback").generation==1,{"generation":app.verify_button.get_node("ButtonFeedback").generation,"status":app.otp.status},["pointer:editable","pointer:verify","pointer:verify-during-busy","wait:result"])
	await click("Verify")
	var old:Control=app;root.remove_child(old);app=load("res://sample/inputs.tscn").instantiate();root.add_child(app);await wait(0.85)
	record("scene-cancels",app.otp_message.text.is_empty() and not app.otp_busy,{"message":app.otp_message.text,"busy":app.otp_busy},["pointer:verify","scene:replace-during-busy","wait:old-result-window"])
	old.queue_free()
	var file:=FileAccess.open("res://evidence/input-extras-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","not_run":[{"scope":"system IME candidate UI","reason":"committed Unicode and shortcut probes do not prove native candidate selection"}],"checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free();await process_frame;quit(0 if checks.all(func(c):return c.passed) else 1)
