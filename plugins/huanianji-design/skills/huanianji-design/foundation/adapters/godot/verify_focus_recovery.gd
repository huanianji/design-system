extends "res://adapters/godot/observe_management_states.gd"

var checks: Array=[]

func observe() -> Dictionary:
	var action_button:Button=app.parts.action.target
	var focus:Control=root.gui_get_focus_owner()
	return {"viewport":[root.size.x,root.size.y],"logical_focus":action_button.has_focus(),"focus_visible":action_button.has_focus(true),"focus":str(focus.name) if focus else "","focus_owner_visible":focus.has_focus(true) if focus else false,"action_selected":action_button.button_pressed,"action_toggle":action_button.toggle_mode,"busy":app.parts.action.busy,"result":app.result.text}

func record(id: String, passed: bool, actions: Array) -> void:
	RenderingServer.force_draw()
	var path:="evidence/focus-"+phase+"-"+id+"-godot.png"
	root.get_texture().get_image().save_png("res://"+path)
	var state:=observe()
	checks.append({"id":id,"passed":passed,"actions":actions,"observed":state,"screenshot":path})
	print("PASS " if passed else "FAIL ",id," ",JSON.stringify(state))

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/controls.tscn").instantiate()
	root.add_child(app)
	root.grab_focus()
	await wait(0.4)
	if not app.get("parts") is Dictionary or app.get("parts").is_empty():quit(2);return
	var action_button:Button=app.parts.action.target
	await pointer(app.fail_next.get_global_rect().get_center())
	await pointer(action_button.get_global_rect().get_center())
	await wait(0.75)
	var s:=observe()
	record("pointer-failure",s.logical_focus and not s.focus_visible and not s.action_selected and s.result=="本地模拟失败，可重试",["pointer:fail-next","pointer:action","wait:result"])
	var peer:Button=app.group.find_child("ButtonOne",true,false)
	await pointer(peer.get_global_rect().get_center())
	s=observe()
	record("pointer-peer",s.focus=="ButtonOne" and not s.focus_owner_visible,["pointer:button-one"])
	await key(KEY_TAB,true)
	await key(KEY_SPACE)
	await wait(0.75)
	s=observe()
	record("keyboard-failure",s.logical_focus and s.focus_visible and s.result=="本地模拟失败，可重试",["key:Shift+Tab","key:Space","wait:result"])
	await key(KEY_SPACE)
	var heading:Label
	for item in app.find_children("*","Label",true,false):
		if item.text=="公共交互检查台":heading=item
	await pointer(heading.get_global_rect().get_center())
	await wait(0.75)
	s=observe()
	record("keyboard-then-pointer",s.logical_focus and not s.focus_visible,["key:Space","pointer:heading-during-busy","wait:result"])
	await pointer(action_button.get_global_rect().get_center())
	await key(KEY_TAB)
	await wait(0.75)
	s=observe()
	record("pending-navigation",not s.logical_focus and s.focus!="" and s.focus_owner_visible,["pointer:action","key:Tab-during-busy","wait:result"])
	var sources:Dictionary={}
	for path in ["components/godot/action_button.gd","sample/controls_lab.gd","adapters/godot/verify_focus_recovery.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if FileAccess.file_exists("res://components/godot/input_focus.gd"):sources["components/godot/input_focus.gd"]=FileAccess.get_sha256("res://components/godot/input_focus.gd")
	var file:=FileAccess.open("res://evidence/focus-"+phase+"-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","build_id":app.manifest.build_id,"source_files":sources,"input_driver":"Input.parse_input_event; actual pointer/keyboard","checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
