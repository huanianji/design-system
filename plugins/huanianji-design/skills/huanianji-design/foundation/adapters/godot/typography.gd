extends Control

const Feedback=preload("res://adapters/godot/button_feedback.gd")
const Inspect=preload("res://adapters/godot/typography_inspect.gd")
var manifest:Dictionary
var roles:Dictionary
var fixture:Dictionary
var group:="daily"
var mode:="light"
var enlarged:=false
var fallback_only:=false
var missing_primary:=false
var case_nodes:Dictionary={}
var group_buttons:Dictionary={}
var fonts:Array[Font]=[]
var system_fonts:Array[Font]=[]
var system_data_font:SystemFont
var root_stack:VBoxContainer
var background:ColorRect
var workspace:PanelContainer
var content:VBoxContainer
var source:Label
var status:Label
var mode_button:Button
var scale_button:Button
var fallback_button:Button
var input:TextEdit
var numeric:VBoxContainer
var digits:Array[Label]=[]
var data_values:Array[Label]=[]
var feedbacks:Array=[]
var initialized:=false

func label(text: String, parent: Node, variation: String="") -> Label:
	var value:=Label.new()
	value.text=text
	value.theme_type_variation=variation
	parent.add_child(value)
	return value

func button(text: String, parent: Node, name_value: String) -> Button:
	var value:=Button.new()
	value.name=name_value
	value.text=text
	value.custom_minimum_size.y=40
	parent.add_child(value)
	return value

func _ready() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://generated/manifest.json"))
	var bundle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+manifest.bundle+"/profiles.json"))
	roles=bundle.profiles.management.godot
	fixture=JSON.parse_string(FileAccess.get_file_as_string("res://sample/typography.json"))
	if FileAccess.get_sha256(roles.font.file)!=manifest.assets[roles.font.file.trim_prefix("res://")]:
		var error:=Label.new()
		error.text="字库与当前设计源不一致，请重新生成后再检查。"
		add_child(error)
		return
	for arg in OS.get_cmdline_user_args():
		if arg=="--missing-font":
			missing_primary=FileAccess.open("res://assets/fonts/typography-intentionally-missing.otf",FileAccess.READ)==null
	var original:Theme=load("res://"+manifest.bundle+"/themes/management_light.tres")
	fonts.assign([original.default_font,original.get_font("font","Heading")])
	for weight in [400,600]:
		var sys:=SystemFont.new()
		sys.font_names=PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC","Noto Sans"])
		sys.font_weight=weight
		system_fonts.append(sys)
	system_data_font=SystemFont.new()
	system_data_font.font_names=PackedStringArray(["Menlo","Consolas","DejaVu Sans Mono","Liberation Mono"])
	background=ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shell:=MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:shell.add_theme_constant_override("margin_"+side,40)
	for side in ["top","bottom"]:shell.add_theme_constant_override("margin_"+side,20)
	add_child(shell)
	root_stack=VBoxContainer.new()
	shell.add_child(root_stack)
	var bar:=HFlowContainer.new()
	root_stack.add_child(bar)
	source=label("Godot · "+str(manifest.build_id).left(8),bar,"Muted")
	source.custom_minimum_size=Vector2(150,40)
	source.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	for id in fixture.groups:
		var value:=button(fixture.groups[id],bar,"Group_"+id)
		value.toggle_mode=true
		value.pressed.connect(func():group=id;apply_view())
		group_buttons[id]=value
	mode_button=button("切换深色",bar,"Mode")
	mode_button.pressed.connect(func():mode="dark" if mode=="light" else "light";apply_view())
	scale_button=button("字号 125%",bar,"Scale")
	scale_button.pressed.connect(func():enlarged=not enlarged;apply_view())
	fallback_button=button("系统回退对照",bar,"Fallback")
	fallback_button.toggle_mode=true
	fallback_button.pressed.connect(func():fallback_only=not fallback_only;apply_view())
	var scroll:=ScrollContainer.new()
	scroll.name="PageScroll"
	scroll.follow_focus=true
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root_stack.add_child(scroll)
	workspace=PanelContainer.new()
	workspace.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(workspace)
	content=VBoxContainer.new()
	workspace.add_child(content)
	label("字体与阅读检查",content,"Heading")
	var intro:=label("同一组文字，比较阅读、换行、回退和放大后的表现。",content,"Muted")
	intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=label("正在加载主字库。",content,"Muted")
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for c in fixture.cases:
		var section:=VBoxContainer.new()
		section.name="Case_"+c.id
		section.add_theme_constant_override("separation",8)
		content.add_child(section)
		label(c.label,section,"Muted")
		var text:=label(c.text,section)
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if c.has("note"):
			var note:=label(c.note,section,"Muted")
			note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		case_nodes[c.id]={"section":section,"text":text,"case":c}
	numeric=VBoxContainer.new()
	content.add_child(numeric)
	label("稳定对齐的数据",numeric,"Section")
	for pair in [["开播时段","19:30—22:00"],["连续数字","0123456789"]]:
		var row:=HBoxContainer.new()
		numeric.add_child(row)
		var left:=label(pair[0],row)
		left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		data_values.append(label(pair[1],row))
	var number_row:=HBoxContainer.new()
	numeric.add_child(number_row)
	var caption:=label("单个数字",number_row)
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var numbers:=HBoxContainer.new()
	numbers.add_theme_constant_override("separation",0)
	number_row.add_child(numbers)
	for digit in "0123456789":digits.append(label(digit,numbers))
	label("试着输入或粘贴一段文字",content)
	input=TextEdit.new()
	input.name="Draft"
	input.custom_minimum_size.y=90
	input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	input.text=fixture.input
	content.add_child(input)
	input.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_TAB:
			var next:Control=input.find_prev_valid_focus() if event.shift_pressed else input.find_next_valid_focus()
			if next:next.grab_focus()
			input.accept_event())
	var hint:=label("切换内容、主题、字号和回退对照时，保留这里的文字。",content,"Muted")
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label("华年集出品 · 字体检查样本",content,"Muted")
	for value in find_children("*","Button",true,false):
		var feedback:=Feedback.new()
		feedback.bind(value,roles.motion)
		feedbacks.append(feedback)
	initialized=true
	apply_view()
	get_window().title="华年集 · 字体与阅读检查"
	get_window().size_changed.connect(func():
		var margin:int=24 if get_viewport_rect().size.x<1000 else 40
		for side in ["left","right"]:shell.add_theme_constant_override("margin_"+side,margin))

func apply_view() -> void:
	var original:Theme=load("res://"+manifest.bundle+"/themes/management_"+mode+".tres")
	theme=original.duplicate(true)
	var factor:=1.25 if enlarged else 1.0
	if enlarged:
		theme.default_font_size=roundi(original.default_font_size*factor)
		for type_name in theme.get_type_list():
			for key in theme.get_font_size_list(type_name):theme.set_font_size(key,type_name,roundi(original.get_font_size(key,type_name)*factor))
	var pair:Array[Font]=system_fonts if fallback_only or missing_primary else fonts
	theme.default_font=pair[0]
	for type_name in ["Heading","Section","Action"]:theme.set_font("font",type_name,pair[1])
	background.color=Color(roles.palette[mode].page)
	status.text="主字库未加载，当前显示系统回退。" if missing_primary else ("系统回退对照：字形可能随设备变化。" if fallback_only else "主字库已加载：资源圆体 1.910，正文 400 / 标题 600。")
	mode_button.text="切换浅色" if mode=="dark" else "切换深色"
	scale_button.text="字号 100%" if enlarged else "字号 125%"
	fallback_button.set_pressed_no_signal(fallback_only)
	for id in group_buttons:group_buttons[id].set_pressed_no_signal(id==group)
	for entry in case_nodes.values():
		entry.section.visible=entry.case.group==group
		entry.text.add_theme_font_override("font",pair[1] if entry.case.weight==600 else pair[0])
		entry.text.add_theme_font_size_override("font_size",roundi(float(roles.font[entry.case.role])*factor))
	numeric.visible=group=="mixed"
	var data_font:FontVariation
	if fallback_only or missing_primary:
		data_font=FontVariation.new()
		data_font.base_font=system_data_font
	else:
		# 在已有变体上保留字重和回退；再包一层会回到字库默认的 200。
		data_font=pair[0].duplicate() as FontVariation
	var features:=data_font.opentype_features.duplicate()
	features[TextServerManager.get_primary_interface().name_to_tag("tnum")]=1
	data_font.opentype_features=features
	for value in digits+data_values:
		value.add_theme_font_override("font",data_font)
		value.add_theme_font_size_override("font_size",roundi(float(roles.font.body)*factor))

func observe() -> Dictionary:
	var cases:Array=[]
	for entry in case_nodes.values():
		if not entry.section.visible:continue
		var text:Label=entry.text
		var font:Font=text.get_theme_font("font")
		var size:int=text.get_theme_font_size("font_size")
		cases.append({"id":entry.case.id,"role":entry.case.role,"weight":entry.case.weight,"text":text.text,"font_size":size,"line_count":text.get_line_count(),"line_height":text.get_line_height(),"rect":[text.position.x,text.position.y,text.size.x,text.size.y],"shaped":Inspect.shape(text.text,font,size)})
	var data_samples:Array=[]
	for value in data_values+digits:
		data_samples.append({"text":value.text,"font_size":value.get_theme_font_size("font_size"),"shaped":Inspect.shape(value.text,value.get_theme_font("font"),value.get_theme_font_size("font_size"))})
	return {"group":group,"theme":mode,"text_scale":1.25 if enlarged else 1,"fallback":fallback_only,"primary_loaded":not missing_primary,"font_status":status.text,"draft":input.text,"input_font_size":input.get_theme_font_size("font_size"),"cases":cases,"data_samples":data_samples,"digit_widths":digits.map(func(d):return d.size.x),"data_font":digits[0].get_theme_font("font").get_font_name(),"workspace":[workspace.position.x,workspace.size.x],"viewport":[get_viewport_rect().size.x,get_viewport_rect().size.y]}
