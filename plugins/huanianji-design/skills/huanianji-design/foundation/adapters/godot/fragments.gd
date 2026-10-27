extends Control

const Feedback = preload("res://components/godot/action_button.gd")
const Disclosure = preload("res://components/godot/disclosure.gd")
const DynamicIcon = preload("res://components/godot/dynamic_icon.gd")
const InputField = preload("res://components/godot/input_field.gd")
var icons:Dictionary={}
var pending_note:Dictionary={}
var fail_next:=false
var note_field
var note_disclosure
var manifest: Dictionary
var bundle: Dictionary
var fixture: Dictionary
var roles: Dictionary
var view := "management"
var mode := "light"
var enlarged := false
var reduced := false
var initialized := false
var selected := ""
var status_filter := "all"
var category := "all"
var asset_id := ""
var note_open := false
var note_target := 0.0
var people: Dictionary = {}
var previews: Dictionary = {}
var tree_items: Dictionary = {}
var asset_tiles: Dictionary = {}
var feedbacks: Dictionary = {}
var animations: Dictionary = {}
var mutating := false
var asset_focus_from_keyboard := false
var asset_pointer_focus := StyleBoxEmpty.new()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		update_asset_focus_visibility(false)
	elif event is InputEventKey and event.pressed:
		update_asset_focus_visibility(true)
		# 鼠标获焦后直接用 Space 等按键，也应显露当前键盘位置。
		var focus:=get_viewport().gui_get_focus_owner()
		if focus:focus.grab_focus()

func update_asset_focus_visibility(from_keyboard: bool) -> void:
	asset_focus_from_keyboard = from_keyboard
	for entry in asset_tiles.values():
		if from_keyboard:entry.button.remove_theme_stylebox_override("focus")
		else:entry.button.add_theme_stylebox_override("focus",asset_pointer_focus)

func _ready() -> void:
	%Reload.pressed.connect(func():
		if initialized: reload_design()
		else: get_tree().reload_current_scene())
	if not read_design(): return
	initialized = true
	%DetailContent.offset_transform_enabled = true
	%DetailContent.offset_transform_visual_only = true
	%DetailContent.offset_transform_pivot_ratio = Vector2(0.5,0)
	get_window().title = "华年集 · 管理与创作工作台"
	for person in fixture.streamers: people[person.id] = {"checks":person.checks.duplicate(),"note":person.note,"savedNote":person.note,"noteStatus":"idle","noteMessage":"","mic":true}
	for asset in fixture.assets: previews[asset.id] = {"zoom":fixture.preview.zoom_default,"opacity":fixture.preview.opacity_default}
	%ManagementView.pressed.connect(set_view.bind("management"))
	%CreativeView.pressed.connect(set_view.bind("creative"))
	%Mode.pressed.connect(func(): set_mode("dark" if mode=="light" else "light"))
	%TextScale.pressed.connect(func(): enlarged=not enlarged; apply_theme())
	%Reduce.toggled.connect(set_reduced)
	%Query.text_changed.connect(func(_value): rebuild_roster())
	for pair in [["AllFilter","all"],["AttentionFilter","attention"],["LiveFilter","live"],["ScheduledFilter","scheduled"]]:
		get_node("%"+pair[0]).pressed.connect(set_filter.bind(pair[1]))
	%AttentionAction.pressed.connect(func(): icons.bell.notify();%Query.text="";set_filter("attention"))
	%SimulateFailure.toggled.connect(func(value):fail_next=value)
	%Microphone.pressed.connect(toggle_microphone)
	%NoteSave.pressed.connect(save_note)
	%Roster.item_selected.connect(roster_selected)
	%Roster.set_column_title(0,"主播")
	%Roster.set_column_title(1,"开播时段")
	%Roster.set_column_title(2,"状态")
	%Roster.set_column_title(3,"准备")
	for i in range(4):
		%Roster.set_column_title_alignment(i,HORIZONTAL_ALIGNMENT_LEFT)
		%Roster.set_column_expand(i,i==0)
	for i in range(3): get_node("%Task"+str(i)).toggled.connect(task_changed.bind(i))
	icons.bell=create_button_icon(%AttentionAction,"BellGlyph","bell.svg","bell")
	icons.microphone=create_button_icon(%Microphone,"MicrophoneGlyph","mic.svg","microphone")
	icons.direction=DynamicIcon.attach(%NoteArrow,"direction",roles.motion)
	note_field=InputField.attach(%Note,palette(),%NoteMessage)
	note_disclosure=Disclosure.new()
	note_disclosure.bind(%NoteToggle,%NoteReveal,%NoteInner,roles.motion,%NoteArrow,[%Note,%NoteSave])
	note_disclosure.icon=icons.direction
	note_disclosure.changed.connect(func(value):
		note_open=value
		note_target=note_disclosure.target
		%NoteToggle.text="收起开播备注" if value else "展开开播备注")
	note_field.changed.connect(func(value):
		if not mutating and people.has(selected):
			var local:Dictionary=people[selected];local.note=value;local.noteStatus="idle";local.noteMessage="与已保存内容一致。" if value==local.savedNote else "尚有未保存的修改。";show_note_status())
	for pair in [["CategoryAll","all"],["CategoryOpening","opening"],["CategoryFrame","frame"],["CategoryScene","scene"]]:
		get_node("%"+pair[0]).pressed.connect(set_category.bind(pair[1]))
	%Zoom.min_value = fixture.preview.zoom_min
	%Zoom.max_value = fixture.preview.zoom_max
	%Zoom.value_changed.connect(parameter_changed.bind("zoom"))
	%Opacity.value_changed.connect(parameter_changed.bind("opacity"))
	%ResetPreview.pressed.connect(reset_preview)
	%Canvas.checker.assign([Color(fixture.preview.checker[0]),Color(fixture.preview.checker[1])])
	%Disclaimer.text = fixture.disclaimer
	create_asset_tiles()
	bind_feedbacks()
	apply_theme()
	rebuild_roster()
	filter_assets()
	get_window().size_changed.connect(resize_layout)
	await get_tree().process_frame
	resize_layout()

func create_button_icon(button:Button, node_name:String, file:String, role:String) -> Node:
	button.icon=load("res://assets/icons/blank.svg")
	button.add_theme_constant_override("icon_max_width",24)
	var glyph:=TextureRect.new();glyph.name=node_name;glyph.texture=load("res://assets/icons/"+file)
	glyph.size=Vector2(24,24);glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	button.add_child(glyph)
	return DynamicIcon.attach(glyph,role,roles.motion)

func place_button_icon(button:Button, icon:Node, optical:float=0) -> void:
	var text_width:float=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	icon.target.position=Vector2((button.size.x-text_width-24-button.get_theme_constant("h_separation"))/2+optical,(button.size.y-24)/2)
	icon.target.pivot_offset=Vector2(12,3 if icon.kind=="bell" else 12)

func show_note_status() -> void:
	if people.has(selected):note_field.set_status(people[selected].noteStatus,people[selected].noteMessage)

func cancel_note() -> void:
	if pending_note.is_empty():return
	var local:Dictionary=people[pending_note.owner]
	pending_note={};feedbacks.NoteSave.cancel()
	local.noteStatus="idle";local.noteMessage="保存已取消，草稿已保留。"
	note_field.set_disabled(false)
	if not note_open:%Note.focus_mode=Control.FOCUS_NONE
	show_note_status()

func save_note() -> void:
	if selected.is_empty() or not DisplayServer.ime_get_text().is_empty():return
	var local:Dictionary=people[selected]
	if local.note.strip_edges().is_empty():
		local.noteStatus="error";local.noteMessage="请先写一条开播备注。";show_note_status();%Note.grab_focus();return
	var action:Node=feedbacks.NoteSave
	var token:int=action.begin()
	if token==0:return
	var task:Dictionary={"owner":selected,"value":local.note,"failed":fail_next,"token":token};pending_note=task
	local.noteStatus="pending";local.noteMessage="正在保存到当前窗口…";note_field.set_disabled(true);show_note_status()
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree() or pending_note.is_empty() or action.generation!=token:return
	pending_note={}
	local.noteStatus="error" if task.failed else "success"
	local.noteMessage="保存失败，备注已保留，可重试。" if task.failed else "已保存到当前窗口。"
	if not task.failed:local.savedNote=task.value
	note_field.set_disabled(false)
	if not note_open:%Note.focus_mode=Control.FOCUS_NONE
	show_note_status();action.finish(token,{"ok":not task.failed})

func toggle_microphone() -> void:
	if selected.is_empty():return
	people[selected].mic=not people[selected].mic
	update_microphone(true)

func update_microphone(animated:bool=false, refresh_only:bool=false) -> void:
	if selected.is_empty():return
	%Microphone.set_pressed_no_signal(people[selected].mic)
	%Microphone.text="麦克风开启" if people[selected].mic else "麦克风静音"
	if not refresh_only:icons.microphone.set_enabled(people[selected].mic,animated)
	icons.microphone.target.modulate=Color(palette().accent if people[selected].mic else palette().ink)

func reject(message: String) -> void:
	%Workspace.hide()
	%SourceStamp.text = message
	push_error(message)

func current_source() -> bool:
	for path in manifest.inputs:
		if FileAccess.get_sha256("res://"+path)!=manifest.inputs[path]:
			reject("共同源已变更，请重新生成并读取")
			return false
	return true

func read_design() -> bool:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://generated/manifest.json"))
	if not raw is Dictionary:
		reject("请先生成共同设计资源")
		return false
	manifest = raw
	if not current_source(): return false
	for group in [manifest.assets,manifest.outputs]:
		for path in group:
			if FileAccess.get_sha256("res://"+path)!=group[path]:
				reject("资源缺失或被修改，请重新生成")
				return false
	bundle = JSON.parse_string(FileAccess.get_file_as_string("res://"+manifest.bundle+"/profiles.json"))
	if not bundle.has("fragments"):
		reject("缺少片段内容，请重新生成")
		return false
	fixture = bundle.fragments
	roles = bundle.profiles[view].godot
	return true

func reload_design() -> void:
	cancel_note()
	if not read_design(): return
	apply_theme()
	note_field.refresh(palette())
	update_tree_colors()
	update_detail(false)
	call_deferred("fit_roster_height")
	update_preview()

func fit_roster_height() -> void:
	# 当前固定短名单随页面完整展开；高度按原生排布读取，避免另一份行高常数。
	var tree:Tree=%Roster
	var panel:=tree.get_theme_stylebox("panel")
	var height:float=panel.get_minimum_size().y+tree.get_theme_stylebox("title_button_normal").get_minimum_size().y+tree.get_theme_font("title_button_font").get_height(tree.get_theme_font_size("title_button_font_size"))
	if not tree_items.is_empty():
		var last:TreeItem=tree_items.values()[-1]
		height=maxf(height,tree.get_item_area_rect(last,0).end.y+tree.get_scroll().y+panel.get_margin(SIDE_BOTTOM))
	tree.custom_minimum_size.y=ceilf(height)

func fit_roster_columns() -> void:
	var tree:Tree=%Roster
	var font:Font=tree.get_theme_font("font")
	var size:int=tree.get_theme_font_size("font_size")
	var title_font:Font=tree.get_theme_font("title_button_font")
	var title_size:int=tree.get_theme_font_size("title_button_font_size")
	var padding:int=tree.get_theme_constant("h_separation")*2
	# 名单用于直接比较时段和状态；按完整数据测量，文字放大时不省略结束时间。
	for column in [1,2,3]:
		var width:float=title_font.get_string_size(tree.get_column_title(column),HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
		for person in fixture.streamers:
			var value:String=person.slot if column==1 else (fixture.statuses[person.status].label if column==2 else "3 / 3")
			width=maxf(width,font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
		tree.set_column_custom_minimum_width(column,maxi([130,88,64][column-1],ceili(width)+padding))

func bind_feedbacks() -> void:
	for button in find_children("*","Button",true,false):
		if button is CheckBox or feedbacks.has(button.name): continue
		var f = Feedback.attach(button,roles.motion)
		feedbacks[button.name] = f

func palette() -> Dictionary:
	return roles.palette[mode]

func apply_theme() -> void:
	if not current_source(): return
	roles = bundle.profiles[view].godot
	note_disclosure.config=roles.motion
	var source := load("res://%s/themes/%s_%s.tres" % [manifest.bundle,view,mode]) as Theme
	theme = source.duplicate(true) if enlarged else source
	if enlarged:
		theme.default_font_size = roundi(source.default_font_size*1.25)
		for type_name in theme.get_type_list():
			for key in theme.get_font_size_list(type_name): theme.set_font_size(key,type_name,roundi(source.get_font_size(key,type_name)*1.25))
	%Workspace.show()
	%Background.color = Color(palette().page)
	%Management.visible = view=="management"
	%Creative.visible = view=="creative"
	%ManagementView.set_pressed_no_signal(view=="management")
	%CreativeView.set_pressed_no_signal(view=="creative")
	%Mode.text = "切换浅色" if mode=="dark" else "切换深色"
	%TextScale.text = "字号 100%" if enlarged else "字号 125%"
	%SourceStamp.text = "Godot · "+str(manifest.build_id).left(8)
	for f in feedbacks.values(): f.config=roles.motion
	for icon in icons.values():icon.config=roles.motion
	note_field.refresh(palette())
	icons.bell.target.modulate=Color(palette().action_ink)
	update_microphone(false,true)
	%ManagementGrid.add_theme_constant_override("h_separation",int(bundle.profiles.management.godot.space.group)*2)
	%CreativeGrid.add_theme_constant_override("h_separation",int(bundle.profiles.creative.godot.space.group)+roundi(float(roles.space.tight)/2.0))
	for i in range(3):
		get_node("%TaskArt"+str(i)).glyph_offset_x = float(roles.optical.check_x)
		get_node("%TaskArt"+str(i)).queue_redraw()
	%NoteArrow.self_modulate = Color(palette().muted)
	for name in ["ZoomValue","OpacityValue","CreativeCaption"]: get_node("%"+name).add_theme_color_override("font_color",Color(palette().accent))
	update_tree_colors()
	update_tile_colors()
	call_deferred("resize_layout")

func set_view(value: String) -> void:
	cancel_note()
	for icon in icons.values():icon.settle()
	stop_animation("asset-change");%Canvas.art_alpha=1.0
	var focus:=get_viewport().gui_get_focus_owner()
	if focus and get_node("%Management" if view=="management" else "%Creative").is_ancestor_of(focus):
		get_node("%ManagementView" if value=="management" else "%CreativeView").grab_focus()
	view = value
	apply_theme()

func set_mode(value: String) -> void:
	mode = value
	apply_theme()

func set_reduced(value: bool) -> void:
	reduced = value
	note_disclosure.set_reduced(value)
	%Reduce.set_pressed_no_signal(value)
	for key in animations.keys(): stop_animation(key)
	for f in feedbacks.values(): f.set_reduced(value)
	for icon in icons.values():icon.set_reduced(value)
	%Canvas.art_alpha=1.0
	for i in range(3):
		var art = get_node("%TaskArt"+str(i))
		art.scale = Vector2.ONE
		art.progress = 1.0 if people.has(selected) and people[selected].checks[i] else 0.0
	set_note_open(note_open,false)
	settle_detail()

func settle_detail() -> void:
	stop_animation("detail")
	%DetailContent.offset_transform_scale = Vector2.ONE
	%DetailContent.offset_transform_position = Vector2.ZERO
	%DetailContent.modulate.a = 1

func animate_detail() -> void:
	var m: Dictionary = roles.motion
	var running: bool = animations.has("detail") and animations.detail.is_valid() and animations.detail.is_running()
	var from: float = %DetailContent.offset_transform_scale.x if running else float(m.detail_start_scale)
	var alpha: float = %DetailContent.modulate.a if running else 0.6
	var values := [from,float(m.detail_peak_scale),float(m.detail_return_scale),1.0]
	var offsets := [0.0,float(m.release_offsets[0]),float(m.release_offsets[1]),1.0]
	var draw := func(progress: float):
		var value := Feedback.sample_keys(Feedback.ease_bezier(progress,m.release_easing),values,offsets)
		%DetailContent.offset_transform_scale = Vector2.ONE*value
		%DetailContent.offset_transform_position.y = float(m.detail_distance)*(1.0-value)/(1.0-float(m.detail_start_scale))
		%DetailContent.modulate.a = lerpf(alpha,1.0,1.0-pow(1.0-progress,3))
	var t := tween_for("detail")
	draw.call(0.0)
	t.tween_method(draw,0.0,1.0,float(m.release_seconds))
	t.tween_callback(settle_detail)

func stop_animation(key: String) -> void:
	if animations.has(key) and animations[key].is_valid(): animations[key].kill()
	animations.erase(key)

func tween_for(key: String) -> Tween:
	stop_animation(key)
	var tween := create_tween()
	animations[key] = tween
	return tween

func filtered_people() -> Array:
	var result: Array = []
	var query: String = %Query.text.strip_edges().to_lower()
	for p in fixture.streamers:
		if status_filter!="all" and p.status!=status_filter: continue
		if not query.is_empty() and not (str(p.name)+" "+str(p.topic)+" "+str(p.slot)).to_lower().contains(query): continue
		result.append(p)
	return result

func set_filter(value: String) -> void:
	status_filter = value
	rebuild_roster()

func rebuild_roster() -> void:
	if not initialized: return
	var previous:=selected
	var list := filtered_people()
	if not list.any(func(p):return p.id==selected):
		cancel_note();selected=str(list[0].id) if not list.is_empty() else ""
	mutating = true
	%Roster.clear()
	tree_items.clear()
	var root_item: TreeItem = %Roster.create_item()
	for p in list:
		var item: TreeItem = %Roster.create_item(root_item)
		item.custom_minimum_height = 54 if not enlarged else 64
		# 原生 Tree 保留整行选择 / 焦点；首列只定制两个字体角色的绘制。
		item.set_cell_mode(0,TreeItem.CELL_MODE_CUSTOM)
		item.set_meta("identity",p.name+"\n"+p.topic)
		item.set_description(0,p.name+"，"+p.topic)
		item.set_custom_draw_callback(0,draw_roster_identity)
		item.set_tooltip_text(0,p.topic)
		item.set_text(1,p.slot)
		item.set_text(2,fixture.statuses[p.status].label)
		item.set_text(3,str(people[p.id].checks.filter(func(c):return c).size())+" / 3")
		item.set_metadata(0,p.id)
		tree_items[p.id] = item
		if p.id==selected: item.select(0)
	mutating = false
	%RosterEmpty.visible = list.is_empty()
	%ResultCount.text = "显示 %d 位" % list.size()
	for pair in [["AllFilter","all"],["AttentionFilter","attention"],["LiveFilter","live"],["ScheduledFilter","scheduled"]]: get_node("%"+pair[0]).set_pressed_no_signal(status_filter==pair[1])
	update_tree_colors()
	if previous!=selected or %DetailName.text.is_empty():update_detail(false)
	call_deferred("fit_roster_height")

func draw_roster_identity(item: TreeItem, rect: Rect2) -> void:
	var lines:=str(item.get_meta("identity")).split("\n")
	var font:Font=%Roster.get_theme_font("font")
	var scale_factor:=1.25 if enlarged else 1.0
	var name_line:=TextLine.new()
	name_line.add_string(lines[0],font,int(round(float(roles.font.body)*scale_factor)))
	var topic_line:=TextLine.new()
	topic_line.add_string(lines[1],font,int(round(float(roles.font.small)*scale_factor)))
	var y:float=rect.position.y+(rect.size.y-name_line.get_size().y-topic_line.get_size().y-3)/2
	for pair in [[name_line,Color(palette().ink)],[topic_line,Color(palette().muted)]]:
		var line:TextLine=pair[0]
		line.width=maxf(0,rect.size.x-16)
		line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		line.draw(%Roster.get_custom_drawing_canvas_item(),Vector2(rect.position.x+8,y),pair[1])
		y+=line.get_size().y+3

func update_tree_colors() -> void:
	if fixture.is_empty() or roles.is_empty(): return
	for p in fixture.streamers:
		if not tree_items.has(p.id): continue
		var item: TreeItem = tree_items[p.id]
		item.set_custom_color(2,Color(palette()[fixture.statuses[p.status].role]))
	if not selected.is_empty():
		var person: Dictionary = fixture.streamers.filter(func(p):return p.id==selected)[0]
		%DetailStatus.add_theme_color_override("font_color",Color(palette()[fixture.statuses[person.status].role]))

func roster_selected() -> void:
	if mutating: return
	var item: TreeItem = %Roster.get_selected()
	if item:
		if selected==str(item.get_metadata(0)): return
		cancel_note()
		selected = str(item.get_metadata(0))
		update_detail(true)

func update_detail(animated: bool) -> void:
	%DetailContent.visible = not selected.is_empty()
	%DetailEmpty.visible = selected.is_empty()
	if selected.is_empty():
		settle_detail()
		return
	var person: Dictionary = fixture.streamers.filter(func(p):return p.id==selected)[0]
	%DetailName.text = person.name
	%DetailStatus.text = fixture.statuses[person.status].label
	%DetailStatus.add_theme_color_override("font_color",Color(palette()[fixture.statuses[person.status].role]))
	%DetailSlot.text = "时段  "+person.slot
	%DetailTopic.text = "内容  "+person.topic
	%ReadyCount.text = str(people[selected].checks.filter(func(c):return c).size())+" / 3 已确认"
	mutating = true
	for i in range(3):
		# 三个绘制节点会被新主播复用，先结束旧主播拥有的运动。
		stop_animation("check"+str(i))
		get_node("%TaskArt"+str(i)).scale = Vector2.ONE
		get_node("%Task"+str(i)).text = fixture.tasks[i]
		get_node("%Task"+str(i)).set_pressed_no_signal(people[selected].checks[i])
		get_node("%TaskArt"+str(i)).progress = 1.0 if people[selected].checks[i] else 0.0
	%Note.text = people[selected].note
	show_note_status()
	update_microphone()
	mutating = false
	set_note_open(note_open,false)
	if animated and not reduced:
		animate_detail()
	else:
		settle_detail()

func task_changed(value: bool, index: int) -> void:
	if mutating or selected.is_empty(): return
	people[selected].checks[index] = value
	%ReadyCount.text = str(people[selected].checks.filter(func(c):return c).size())+" / 3 已确认"
	if tree_items.has(selected): tree_items[selected].set_text(3,str(people[selected].checks.filter(func(c):return c).size())+" / 3")
	var art: Control = get_node("%TaskArt"+str(index))
	stop_animation("check"+str(index))
	if reduced:
		art.progress = 1.0 if value else 0.0
		art.scale = Vector2.ONE
		return
	var t := tween_for("check"+str(index))
	t.set_parallel(true)
	t.tween_property(art,"progress",1.0 if value else 0.0,float(roles.motion.check_draw_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(art,"scale",Vector2.ONE*float(roles.motion.check_press_scale),float(roles.motion.check_press_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(art,"scale",Vector2.ONE,float(roles.motion.check_release_seconds)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_note_open(value: bool, animated: bool = true) -> void:
	note_disclosure.set_open(value,animated)

func create_asset_tiles() -> void:
	for asset in fixture.assets:
		# 整张卡片只表达一个选择动作；图片与标题不再建立独立焦点目标。
		var button := Button.new()
		button.name = "Asset_"+asset.id
		button.accessibility_name = asset.name
		button.custom_minimum_size = Vector2(180,142)
		button.theme_type_variation = "AssetChoice"
		button.toggle_mode = true
		button.pressed.connect(select_asset.bind(asset.id))
		%AssetStrip.add_child(button)
		var inset := MarginContainer.new()
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for edge in ["left","top","right","bottom"]:inset.add_theme_constant_override("margin_"+edge,8)
		button.add_child(inset)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation",6)
		inset.add_child(column)
		var image := TextureRect.new()
		image.texture = load("res://"+asset.file)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(160,80)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(image)
		var caption := Label.new()
		caption.text = asset.name
		caption.theme_type_variation = "Body"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.y = 40
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)
		asset_tiles[asset.id] = {"panel":button,"button":button,"label":caption}
	update_asset_focus_visibility(asset_focus_from_keyboard)

func set_category(value: String) -> void:
	category = value
	filter_assets()

func filter_assets() -> void:
	stop_animation("asset-change");%Canvas.art_alpha=1.0
	var visible: Array = fixture.assets.filter(func(a):return category=="all" or a.category==category)
	if not visible.any(func(a):return a.id==asset_id): asset_id=str(visible[0].id) if not visible.is_empty() else ""
	for asset in fixture.assets: asset_tiles[asset.id].panel.visible=category=="all" or asset.category==category
	for pair in [["CategoryAll","all"],["CategoryOpening","opening"],["CategoryFrame","frame"],["CategoryScene","scene"]]: get_node("%"+pair[0]).set_pressed_no_signal(category==pair[1])
	update_preview()

func select_asset(value: String) -> void:
	if asset_id==value:return
	stop_animation("asset-change")
	asset_id = value
	update_preview()
	if not reduced:
		%Canvas.art_alpha=0.0
		var t:=tween_for("asset-change")
		t.tween_property(%Canvas,"art_alpha",1.0,float(roles.motion.select_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func parameter_changed(value: float, key: String) -> void:
	if mutating or asset_id.is_empty(): return
	stop_animation("asset-change");%Canvas.art_alpha=1.0
	previews[asset_id][key] = value
	update_preview()

func reset_preview() -> void:
	stop_animation("asset-change");%Canvas.art_alpha=1.0
	previews[asset_id] = {"zoom":fixture.preview.zoom_default,"opacity":fixture.preview.opacity_default}
	update_preview()

func update_preview() -> void:
	if asset_id.is_empty(): return
	var asset: Dictionary = fixture.assets.filter(func(a):return a.id==asset_id)[0]
	%AssetTitle.text = asset.name
	%InspectorName.text = asset.name
	%AssetDescription.text = asset.description
	%Canvas.texture = load("res://"+asset.file)
	%Canvas.zoom = float(previews[asset_id].zoom)
	%Canvas.opacity = float(previews[asset_id].opacity)
	mutating = true
	%Zoom.value = previews[asset_id].zoom
	%Opacity.value = previews[asset_id].opacity
	mutating = false
	%ZoomValue.text = "%d%%" % previews[asset_id].zoom
	%OpacityValue.text = "%d%%" % previews[asset_id].opacity
	%ResetPreview.disabled = previews[asset_id].zoom==fixture.preview.zoom_default and previews[asset_id].opacity==fixture.preview.opacity_default
	%PreviewStatus.text="默认预览" if %ResetPreview.disabled else "当前素材的预览已调整"
	update_tile_colors()

func update_tile_colors() -> void:
	if roles.is_empty(): return
	for id in asset_tiles:
		asset_tiles[id].button.set_pressed_no_signal(id==asset_id)
		asset_tiles[id].label.add_theme_color_override("font_color",Color(palette().accent if id==asset_id else palette().ink))

func resize_layout() -> void:
	if not initialized: return
	place_button_icon(%AttentionAction,icons.bell,float(roles.optical.bell_x))
	place_button_icon(%Microphone,icons.microphone)
	# 主题通知在当前调用结束后传播；在排布阶段读取实际生效的字号。
	fit_roster_columns()
	var width: float = get_viewport_rect().size.x
	var margin: int = int(roles.space.page_small if width<1000 else roles.space.page_large)
	%Shell.add_theme_constant_override("margin_left",margin)
	%Shell.add_theme_constant_override("margin_right",margin)
	%Workspace.custom_minimum_size.x = minf(1200,width-margin*2-18)
	%ManagementGrid.columns = 1 if width<1050 else 2
	%CreativeGrid.columns = 1 if width<1050 else 2
	%Canvas.custom_minimum_size.y=330 if width<1050 else 355
	call_deferred("fit_roster_height")
	%NoteInner.size.x = %NoteReveal.size.x
	%NoteArrow.position = Vector2(%NoteToggle.size.x-24,(%NoteToggle.size.y-16)/2)
	%NoteArrow.pivot_offset = Vector2(8,8)
	for i in range(3):
		var art: Control = get_node("%TaskArt"+str(i))
		art.position.y = (get_node("%Task"+str(i)).size.y-28)/2
		art.pivot_offset = Vector2(14,14)
	if note_open and not is_equal_approx(note_target,%NoteInner.get_combined_minimum_size().y): set_note_open(true,false)

func snapshot() -> Dictionary:
	return {"view":view,"mode":mode,"enlarged":enlarged,"reduced":reduced,"selected":selected,"status":status_filter,"query":%Query.text,"note_open":note_open,"people":people.duplicate(true),"asset":asset_id,"category":category,"previews":previews.duplicate(true),"visible":filtered_people().map(func(p):return p.id),"build_id":manifest.get("build_id",""),"failNext":fail_next,"note_busy":not pending_note.is_empty()}

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://evidence/"+name+".png")
	var file := FileAccess.open("res://evidence/"+name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot(),"\t"))

func _exit_tree() -> void:
	pending_note={}
	for key in animations.keys():stop_animation(key)
