extends Control

const Action=preload("res://components/godot/action_button.gd")
const InputField=preload("res://components/godot/input_field.gd")
const Otp=preload("res://components/godot/otp_input.gd")
var manifest:Dictionary
var roles:Dictionary
var mode:="light"
var enlarged:=false
var reduced:=false
var disabled:=false
var read_only:=false
var fail_next:=false
var note_busy:=false
var otp_busy:=false
var feedbacks:Array=[]
var note:TextEdit
var note_field:Node
var otp:Control
var note_message:Label
var otp_message:Label
var save_button:Button
var verify_button:Button
var clear_button:Button
var background:ColorRect
var card:PanelContainer

func label(text:String,parent:Node,variation:String="") -> Label:
	var item:=Label.new();item.text=text;item.theme_type_variation=variation
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func button(text:String,parent:Node,id:String,toggle:bool=false) -> Button:
	var item:=Button.new();item.name=id;item.text=text;item.toggle_mode=toggle
	parent.add_child(item);feedbacks.append(Action.attach(item,roles.motion))
	return item

func row(parent:Node) -> HFlowContainer:
	var item:=HFlowContainer.new()
	item.add_theme_constant_override("h_separation",12);item.add_theme_constant_override("v_separation",12)
	parent.add_child(item)
	return item

func _ready() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://generated/manifest.json"))
	var bundle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+manifest.bundle+"/profiles.json"))
	roles=bundle.profiles.management.godot
	get_window().title="华年集 · 输入与验证码"
	background=ColorRect.new();background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,40 if side in ["left","right"] else 20)
	add_child(margin)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;margin.add_child(scroll)
	var stack:=VBoxContainer.new();stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stack.add_theme_constant_override("separation",16);scroll.add_child(stack)
	var toolbar:=row(stack)
	label("Godot · "+str(manifest.build_id).left(8),toolbar,"Muted").autowrap_mode=TextServer.AUTOWRAP_OFF
	var mode_button:=button("切换深色",toolbar,"Mode")
	mode_button.pressed.connect(func():mode="dark" if mode=="light" else "light";mode_button.text="切换浅色" if mode=="dark" else "切换深色";apply_theme())
	var scale_button:=button("字号 125%",toolbar,"Scale")
	scale_button.pressed.connect(func():enlarged=not enlarged;scale_button.text="字号 100%" if enlarged else "字号 125%";apply_theme())
	button("减少动态",toolbar,"Reduce",true).toggled.connect(func(value):reduced=value;otp.set_reduced(value);for action in feedbacks:action.set_reduced(value))
	var center:=CenterContainer.new();stack.add_child(center)
	card=PanelContainer.new();center.add_child(card)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",24);card.add_child(body)
	label("输入与验证码",body,"Heading")
	label("文字留在原位，反馈跟随操作。两组示例均为本地模拟。",body,"Muted")
	var conditions:=row(body)
	button("禁用输入",conditions,"Disabled",true).toggled.connect(func(value):disabled=value;availability())
	button("只读输入",conditions,"ReadOnly",true).toggled.connect(func(value):read_only=value;availability())
	button("模拟请求失败",conditions,"FailNext",true).toggled.connect(func(value):fail_next=value)
	var ordinary:=VBoxContainer.new();ordinary.add_theme_constant_override("separation",16);body.add_child(ordinary)
	label("普通输入",ordinary,"Section")
	label("开播备注",ordinary)
	note=TextEdit.new();note.name="Note";note.custom_minimum_size.y=96;note.placeholder_text="例如：今晚先聊新歌，再和大家玩点歌。";note.accessibility_name="开播备注";ordinary.add_child(note)
	var note_actions:=row(ordinary)
	save_button=button("本地保存备注",note_actions,"SaveNote")
	save_button.theme_type_variation="Action"
	label("保存失败时保留输入，可直接重试。",note_actions,"Muted").autowrap_mode=TextServer.AUTOWRAP_OFF
	note_message=label("",ordinary,"Muted");note_message.custom_minimum_size.y=24
	note_field=InputField.attach(note,roles.palette.light,note_message)
	save_button.pressed.connect(save_note)
	var separator:=HSeparator.new();body.add_child(separator)
	var codes:=VBoxContainer.new();codes.add_theme_constant_override("separation",16);body.add_child(codes)
	label("验证码 · 独立示例",codes,"Section")
	label("演示码 123456。可逐位输入或粘贴整段，不发送短信。",codes,"Muted")
	otp=Otp.new();otp.name="Otp";otp.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;codes.add_child(otp)
	var otp_actions:=row(codes)
	verify_button=button("本地验证",otp_actions,"Verify")
	verify_button.theme_type_variation="Action"
	clear_button=button("清空验证码",otp_actions,"Clear")
	otp_message=label("",codes,"Muted");otp_message.custom_minimum_size.y=24
	otp.bind(roles,roles.palette.light,otp_message)
	verify_button.pressed.connect(verify_code)
	clear_button.pressed.connect(func():otp.clear();otp.focus(0))
	label("华年集出品 · 公共输入行为",body,"Muted")
	get_window().size_changed.connect(refresh_layout)
	apply_theme();availability()
	call_deferred("refresh_layout")

func refresh_layout() -> void:
	card.custom_minimum_size.x=minf(880,get_viewport_rect().size.x-80)
	otp.custom_minimum_size.x=minf(430,card.custom_minimum_size.x-64)

func apply_theme() -> void:
	var source:Theme=load("res://%s/themes/management_%s.tres" % [manifest.bundle,mode])
	theme=source.duplicate(true) if enlarged else source
	if enlarged:
		theme.default_font_size=roundi(source.default_font_size*1.25)
		for type_name in theme.get_type_list():
			for key in theme.get_font_size_list(type_name):theme.set_font_size(key,type_name,roundi(source.get_font_size(key,type_name)*1.25))
	background.color=Color(roles.palette[mode].page)
	note_field.refresh(roles.palette[mode])
	otp.refresh(roles,roles.palette[mode])
	call_deferred("refresh_layout")

func availability() -> void:
	note_field.set_disabled(disabled or note_busy);note_field.set_read_only(read_only)
	otp.set_disabled(disabled or otp_busy);otp.set_read_only(read_only)
	save_button.get_node("ButtonFeedback").set_disabled(disabled or read_only)
	verify_button.get_node("ButtonFeedback").set_disabled(disabled or read_only)
	clear_button.get_node("ButtonFeedback").set_disabled(disabled or read_only or otp_busy)

func save_note() -> void:
	if not DisplayServer.ime_get_text().is_empty():return
	if note.text.strip_edges().is_empty():note_field.set_status("error","请先写一条开播备注。");note.grab_focus();return
	var action:Node=save_button.get_node("ButtonFeedback")
	var token:int=action.begin()
	if token==0:return
	var should_fail:=fail_next
	note_busy=true;availability();note_field.set_status("pending","正在本地模拟保存…")
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():return
	note_busy=false;availability()
	note_field.set_status("error" if should_fail else "success","本地模拟保存失败，输入已保留，可重试。" if should_fail else "本地模拟保存完成。")
	action.finish(token,{"ok":not should_fail})

func verify_code() -> void:
	if not otp.complete():otp.set_status("error","请补齐六位验证码。");otp.focus(otp.slots.find(""));return
	var action:Node=verify_button.get_node("ButtonFeedback")
	var token:int=action.begin()
	if token==0:return
	var value:String=otp.value()
	var should_fail:=fail_next
	otp_busy=true;availability();otp.set_status("pending","正在本地模拟验证…")
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():return
	otp_busy=false;availability()
	var ok:=not should_fail and value=="123456"
	otp.set_status("success" if ok else "error","本地模拟验证通过。" if ok else "本地模拟请求失败，验证码已保留，可重试。" if should_fail else "验证码不匹配，请更正后重试。")
	action.finish(token,{"ok":ok})
