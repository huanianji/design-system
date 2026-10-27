extends "res://adapters/godot/observe_management_states.gd"

var checks:Array=[]
func record(id:String,passed:bool,actions:Array) -> void:
	RenderingServer.force_draw()
	var path:="evidence/input-consumption-"+id+"-godot.png"
	root.get_texture().get_image().save_png("res://"+path)
	checks.append({"id":id,"passed":passed,"actions":actions,"observed":{"selected":app.selected,"note":app.get_node("%Note").text,"bound":app.get_node("%Note").has_meta("hj_input_field"),"open":app.note_open,"mode":app.mode,"font":app.get_node("%Note").get_theme_font_size("font_size")},"screenshot":path})
	print("PASS " if passed else "FAIL ",id)

func run() -> void:
	root.size=Vector2i(1280,960);app=load("res://sample/fragments.tscn").instantiate();root.add_child(app);root.grab_focus();await wait(0.5)
	if not app.initialized:quit(2);return
	await pointer(app.get_node("%NoteToggle").get_global_rect().get_center());await wait(0.5)
	await input_text(app.get_node("%Note"),"复用输入：今晚先聊新歌")
	record("note-actual-consumer",app.get_node("%Note").has_meta("hj_input_field") and app.people.linxi.note=="复用输入：今晚先聊新歌" and app.get_node("%Note").get_theme_font_size("font_size")==14,["pointer:expand-note","input:chinese-note"])
	await key(KEY_ESCAPE);await wait(0.5)
	record("note-escape-focus",not app.note_open and root.gui_get_focus_owner()==app.get_node("%NoteToggle"),["key:Escape"])
	await pointer(app.get_node("%Mode").get_global_rect().get_center());await pointer(app.get_node("%NoteToggle").get_global_rect().get_center());await wait(0.5)
	record("note-theme-preserves",app.mode=="dark" and app.get_node("%Note").text=="复用输入：今晚先聊新歌",["pointer:mode","pointer:expand-note"])
	await pointer(app.get_node("%Note").get_global_rect().get_center());await key(KEY_TAB)
	record("note-tab-exits",root.gui_get_focus_owner()!=app.get_node("%Note") and not app.people.linxi.note.contains("\t"),["pointer:note","key:Tab"])
	var file:=FileAccess.open("res://evidence/input-consumption-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free();await process_frame;quit(0 if checks.all(func(c):return c.passed) else 1)
