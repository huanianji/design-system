extends Control

const Action = preload("res://components/godot/action_button.gd")
const Tabs = preload("res://components/godot/tab_group.gd")
const Disclosure = preload("res://components/godot/disclosure.gd")
var manifest: Dictionary
var roles: Dictionary
var mode := "light"
var reduced := false
var enlarged := false
var attempts := 0
var mounts := 0
var parts: Dictionary = {}
var feedbacks: Array = []
var group: VBoxContainer
var mount_point: VBoxContainer
var result: Label
var fail_next: Button
var disable_tab: Button
var disable_all: Button
var background: ColorRect
var card: PanelContainer

func label(text: String, parent: Node, variation: String = "") -> Label:
	var item:=Label.new()
	item.text=text
	item.theme_type_variation=variation
	parent.add_child(item)
	return item

func button(text: String, parent: Node, id: String) -> Button:
	var item:=Button.new()
	item.text=text
	item.name=id
	parent.add_child(item)
	var action=Action.attach(item,roles.motion)
	feedbacks.append(action)
	return item

func state_button(text: String, parent: Node, id: String) -> Button:
	var item:=button(text,parent,id)
	item.toggle_mode=true
	return item

func _ready() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://generated/manifest.json"))
	var bundle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+manifest.bundle+"/profiles.json"))
	roles=bundle.profiles.management.godot
	get_window().title="华年集 · 公共交互检查台"
	background=ColorRect.new()
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,40 if side in ["left","right"] else 20)
	add_child(margin)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",16)
	stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	scroll.focus_mode=Control.FOCUS_NONE
	margin.add_child(scroll)
	scroll.add_child(stack)
	var toolbar:=HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",12)
	stack.add_child(toolbar)
	label("Godot · "+str(manifest.build_id).left(8),toolbar,"Muted")
	var mode_button:=button("切换深色",toolbar,"Mode")
	mode_button.pressed.connect(func(): mode="dark" if mode=="light" else "light";mode_button.text="切换浅色" if mode=="dark" else "切换深色";apply_theme())
	var reduce_button:=button("减少动态",toolbar,"Reduce")
	reduce_button.toggle_mode=true
	reduce_button.toggled.connect(func(value):
		reduced=value
		for item in feedbacks:
			if is_instance_valid(item): item.set_reduced(value)
		parts.tabs.set_reduced(value)
		parts.reveal.set_reduced(value))
	var scale_button:=button("字号 125%",toolbar,"Scale")
	scale_button.pressed.connect(func(): enlarged=not enlarged;scale_button.text="字号 100%" if enlarged else "字号 125%";apply_theme())
	button("移除并重建",toolbar,"Remount").pressed.connect(mount)
	var center:=CenterContainer.new()
	stack.add_child(center)
	card=PanelContainer.new()
	card.custom_minimum_size.x=880
	center.add_child(card)
	var body:=VBoxContainer.new()
	body.add_theme_constant_override("separation",24)
	card.add_child(body)
	label("公共交互检查台",body,"Heading")
	label("本地状态演示：结果由检查台模拟，不连接业务服务。",body,"Muted")
	var conditions:=HFlowContainer.new()
	conditions.add_theme_constant_override("h_separation",12)
	conditions.add_theme_constant_override("v_separation",12)
	body.add_child(conditions)
	fail_next=state_button("下次操作返回失败",conditions,"FailNext")
	disable_tab=state_button("禁用第二个 Tab",conditions,"DisableTab")
	disable_tab.toggled.connect(func(value): parts.tabs.set_disabled(1,value))
	disable_all=state_button("禁用全部 Tab",conditions,"DisableAll")
	disable_all.toggled.connect(func(value):
		for i in 3: parts.tabs.set_disabled(i,value or (i==1 and disable_tab.button_pressed)))
	mount_point=VBoxContainer.new()
	body.add_child(mount_point)
	result=label("尚未操作",body)
	result.name="Result"
	label("华年集出品 · 首批公共行为",body,"Muted")
	mount()
	apply_theme()
	get_window().size_changed.connect(refresh_layout)

func mount() -> void:
	if is_instance_valid(group):
		mount_point.remove_child(group)
		group.queue_free()
	feedbacks=feedbacks.filter(func(item): return is_instance_valid(item) and item.is_inside_tree())
	mounts+=1
	group=VBoxContainer.new()
	group.add_theme_constant_override("separation",int(roles.space.group))
	mount_point.add_child(group)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	group.add_child(row)
	var action_button:=button("执行本地操作",row,"LabAction")
	var action=action_button.get_node("ButtonFeedback")
	action_button.pressed.connect(start_operation.bind(action))
	button("不可用操作",row,"DisabledAction").disabled=true
	var samples:=HBoxContainer.new()
	samples.add_theme_constant_override("separation",12)
	group.add_child(samples)
	button("按钮一",samples,"ButtonOne")
	button("按钮二",samples,"ButtonTwo")
	var track_panel:=PanelContainer.new()
	track_panel.theme_type_variation="TabsPanel"
	group.add_child(track_panel)
	var track_root:=Control.new()
	track_root.custom_minimum_size.y=42
	track_panel.add_child(track_root)
	var plate:=Panel.new()
	plate.theme_type_variation="SelectionPlate"
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	track_root.add_child(plate)
	var track:=HBoxContainer.new()
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_theme_constant_override("separation",4)
	track_root.add_child(track)
	var tab_buttons: Array=[]
	for i in 3:
		var item:=button(["概览","草稿","设置"][i],track,"LabTab"+str(i))
		item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab_buttons.append(item)
	tab_buttons[1].disabled=disable_tab.button_pressed
	var panels: Array=[]
	for i in 3:
		var panel:=VBoxContainer.new()
		panel.name="Panel"+str(i)
		panel.add_theme_constant_override("separation",16)
		group.add_child(panel)
		panels.append(panel)
	label("概览内容",panels[0])
	var trigger:=button("局部设置",panels[0],"LabToggle")
	trigger.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var arrow:=TextureRect.new()
	arrow.texture=load("res://assets/icons/chevron.svg")
	arrow.size=Vector2(16,16)
	arrow.pivot_offset=Vector2(8,8)
	arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	trigger.add_child(arrow)
	var region:=Control.new()
	region.name="LabRegion"
	panels[0].add_child(region)
	var content:=VBoxContainer.new()
	region.add_child(content)
	label("局部草稿",content)
	var draft:=LineEdit.new()
	draft.name="LocalDraft"
	draft.text="保留这份草稿"
	content.add_child(draft)
	label("独立草稿",panels[1])
	var tab_draft:=LineEdit.new()
	tab_draft.name="TabDraft"
	tab_draft.text="切换后仍保留"
	panels[1].add_child(tab_draft)
	label("设置内容",panels[2])
	var tabs:=Tabs.new()
	tabs.bind(tab_buttons,roles.motion,plate,panels)
	var reveal:=Disclosure.new()
	reveal.bind(trigger,region,content,roles.motion,arrow,[draft])
	reveal.set_open(false,false)
	parts={"action":action,"buttons":tab_buttons,"tabs":tabs,"reveal":reveal,"draft":draft,"tab_draft":tab_draft,"trigger":trigger,"region":region,"content":content,"arrow":arrow}
	for i in 3: tabs.set_disabled(i,disable_all.button_pressed or (i==1 and disable_tab.button_pressed))
	for item in feedbacks:
		if is_instance_valid(item): item.set_reduced(reduced)
	tabs.set_reduced(reduced)
	reveal.set_reduced(reduced)
	result.text="已重建，旧操作已取消" if mounts>1 else "尚未操作"
	call_deferred("refresh_layout")

func start_operation(action: Node) -> void:
	var token: int=action.begin()
	if token==0: return
	var owner_id:=mounts
	var fail:=fail_next.button_pressed
	attempts+=1
	result.text="处理中…"
	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(action) or not action.is_inside_tree() or owner_id!=mounts: return
	var value:={"ok":not fail,"error":"本地模拟失败，可重试" if fail else ""}
	if action.finish(token,value): result.text="本地操作完成" if value.ok else value.error

func apply_theme() -> void:
	var source:=load("res://%s/themes/management_%s.tres" % [manifest.bundle,mode]) as Theme
	theme=source.duplicate(true) if enlarged else source
	if enlarged:
		theme.default_font_size=roundi(source.default_font_size*1.25)
		for type_name in theme.get_type_list():
			for key in theme.get_font_size_list(type_name): theme.set_font_size(key,type_name,roundi(source.get_font_size(key,type_name)*1.25))
	background.color=Color(roles.palette[mode].page)
	if not parts.is_empty(): parts.arrow.self_modulate=Color(roles.palette[mode].muted)
	call_deferred("refresh_layout")

func refresh_layout() -> void:
	if parts.is_empty(): return
	card.custom_minimum_size.x=minf(880,get_viewport_rect().size.x-80)
	parts.arrow.position=Vector2(parts.trigger.size.x-26,(parts.trigger.size.y-16)/2)
	parts.content.size.x=parts.region.size.x
	parts.reveal.refresh()
	parts.tabs.layout(false,true)
