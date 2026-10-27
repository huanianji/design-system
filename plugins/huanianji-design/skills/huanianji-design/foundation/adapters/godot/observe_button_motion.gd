extends "res://adapters/godot/observe_management_states.gd"

var records:Array=[]
var active:Dictionary={}
var target:Button
var observed_build:String
var started:int
var capture_key:Key=KEY_SPACE

func sample() -> Dictionary:
	var action:Node=target.get_node("ButtonFeedback")
	var background:Color=target.get_theme_stylebox("disabled" if target.disabled else "pressed" if target.is_pressed() else "hover" if target.is_hovered() else "normal").bg_color
	return {"ms":(Time.get_ticks_usec()-started)/1000.0,"scale":target.offset_transform_scale.x,"disabled":target.disabled,"busy":action.busy,"background":background.to_html(false),"rect":[target.get_global_rect().position.x,target.get_global_rect().position.y,target.size.x,target.size.y]}

func _process(_delta:float) -> bool:
	if not active.is_empty():active.frames.append(sample())
	return false

func event(kind:String) -> void:
	if active.is_empty():return
	var data:=sample();data.type=kind;active.events.append(data)

func mouse(down:bool) -> void:
	var point:=target.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new();move.position=point;Input.parse_input_event(move)
	var input:=InputEventMouseButton.new();input.position=point;input.button_index=MOUSE_BUTTON_LEFT;input.pressed=down
	Input.parse_input_event(input);Input.flush_buffered_events();await process_frame

func key_state(down:bool) -> void:
	var input:=InputEventKey.new();input.keycode=capture_key;input.pressed=down
	Input.parse_input_event(input);Input.flush_buffered_events();await process_frame

func run() -> void:
	root.size=Vector2i(1280,960)
	for kind in ["note","code"]:
		for scenario in ["invalid","busy","keyboard","enter","reduced"]:
			app=load("res://sample/inputs.tscn").instantiate();root.add_child(app);root.grab_focus();await wait(0.25)
			if not is_instance_valid(app.note_field):quit(2);return
			observed_build=app.manifest.build_id
			if scenario!="invalid":
				if kind=="note":await input_text(app.note,"真实按压过程")
				else:
					await pointer(app.clear_button.get_global_rect().get_center())
					for c in "123456":
						var input:=InputEventKey.new();input.unicode=c.unicode_at(0);input.pressed=true;Input.parse_input_event(input);Input.flush_buffered_events();await process_frame
			if scenario=="reduced":await pointer(app.find_child("Reduce",true,false).get_global_rect().get_center())
			target=app.save_button if kind=="note" else app.verify_button
			if scenario in ["keyboard","enter"]:
				# 从当前输入经Tab到真实提交入口，未调用grab_focus来冒充键盘导航。
				await key(KEY_TAB)
			for signal_name in ["button_down","button_up","pressed","focus_exited"]:target.connect(signal_name,event.bind(signal_name))
			capture_key=KEY_ENTER if scenario=="enter" else KEY_SPACE
			started=Time.get_ticks_usec();active={"id":kind+"-"+scenario,"input":"Space" if scenario=="keyboard" else "Enter" if scenario=="enter" else "pointer","frames":[],"events":[]}
			if scenario in ["keyboard","enter"]:await key_state(true)
			else:await mouse(true)
			await wait(0.16)
			active.release_ms=(Time.get_ticks_usec()-started)/1000.0
			if scenario in ["keyboard","enter"]:await key_state(false)
			else:await mouse(false)
			await wait(0.9)
			var path:="evidence/action-motion-"+phase+"-"+str(active.id)+"-godot.png"
			RenderingServer.force_draw();root.get_texture().get_image().save_png("res://"+path);active.screenshot=path
			active.physical_release_ms=active.release_ms
			for item in active.events:
				if item.type=="button_up":active.release_ms=item.ms;break
			records.append(active);active={};app.queue_free();await process_frame
	var sources:Dictionary={}
	for path in ["components/godot/action_button.gd","components/godot/input_focus.gd","components/godot/input_field.gd","components/godot/otp_input.gd","sample/inputs_lab.gd","sample/inputs.tscn","adapters/godot/observe_button_motion.gd","adapters/godot/observe_management_states.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open("res://evidence/action-motion-"+phase+"-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"build_id":observed_build,"platform":"godot","source_files":sources,"input_driver":"Input.parse_input_event; pointer/Space 160ms hold; frame sampling","records":records},"\t"));quit()
