extends Control

const Style=preload("res://preview_theme.gd")
const Icons=preload("res://source_icons.gd")
const Feedback=preload("res://components/godot/action_button.gd")
const Tabs=preload("res://components/godot/tab_group.gd")
const Disclosure=preload("res://components/godot/disclosure.gd")
const DynamicIcon=preload("res://components/godot/dynamic_icon.gd")
const Room=preload("res://room.gd")
const Timeline=preload("res://timeline.gd")
const KeyframeButton=preload("res://keyframe_button.gd")

var dark:=true
var large:=false
var reduced:=false
var selected:="desk"
var tool:="select"
var scope:=0
var current_tab:=0
var playing:=false
var clock:=2.4
var grid_enabled:=true
var maximized:=""
var state:Dictionary={
	"desk":{"name":"书桌","icon":"cube","x":.4,"z":-.65,"rotation":0.0,"scale":1.0,"visible":true,"locked":false},
	"chair":{"name":"工作椅","icon":"cube","x":.6,"z":.62,"rotation":0.0,"scale":1.0,"visible":true,"locked":false},
	"lamp":{"name":"落地灯","icon":"light","x":2.1,"z":-1.4,"rotation":0.0,"scale":1.0,"visible":true,"locked":false},
	"plant":{"name":"窗边绿植","icon":"cube","x":-2.7,"z":-.5,"rotation":0.0,"scale":1.0,"visible":true,"locked":false}}
var exposure:=0.0
var undo_stack:Array=[]
var redo_stack:Array=[]
var keyframes:Dictionary={}
var gesture_start:Dictionary={}
var motion:Dictionary
var shell:MarginContainer
var body:VBoxContainer
var scene:Node3D
var stage_view:SubViewport
var output_view:SubViewport
var stage_camera:Camera3D
var output_camera:Camera3D
var timeline:Control
var time_label:Label
var status_label:Label
var play_button:Button
var inspector_title:Label
var inspector_scroll:ScrollContainer
var feedbacks:Array=[]
var disclosures:Array=[]
var tab_groups:Array=[]
var references:Dictionary={}
var panels:Dictionary={}
var group_open:Dictionary={"transform":true,"appearance":true,"advanced":false}
var drawer:PanelContainer
var updating:=false
var started_at:=0.0

func _ready() -> void:
	get_window().title="Lumina · 创作台提案（Godot 原生预览）"
	get_window().min_size=Vector2i(1200,760)
	motion=JSON.parse_string(FileAccess.get_file_as_string("res://motion.json"))
	_create_scene()
	_build()
	if "--verify" in OS.get_cmdline_user_args(): _verify.call_deferred()

func _create_scene() -> void:
	stage_view=SubViewport.new(); stage_view.size=Vector2i(1000,720);stage_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;stage_view.own_world_3d=true;add_child(stage_view)
	scene=Room.new();stage_view.add_child(scene)
	stage_camera=Camera3D.new();stage_view.add_child(stage_camera);stage_camera.position=Vector3(6.7,5.0,7.5);stage_camera.look_at(Vector3(0,1,-.5));stage_camera.fov=47;stage_camera.cull_mask=3
	output_view=SubViewport.new();output_view.size=Vector2i(1000,720);output_view.world_3d=stage_view.find_world_3d();output_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(output_view)
	output_camera=Camera3D.new();output_view.add_child(output_camera);output_camera.position=Vector3(4.3,2.9,5.9);output_camera.look_at(Vector3(-.1,1.25,-1));output_camera.fov=45;output_camera.cull_mask=1
	stage_camera.make_current();output_camera.make_current();scene.select(selected)

func color(key: String) -> Color: return Style.colors[key]
func _label(text: String, parent: Node, pixels:=14, muted:=false, strong:=false, data:=false) -> Label:
	var l:=Label.new();l.text=text;parent.add_child(l);Style.label_role(l,pixels,muted,strong,data);return l
func _row(parent: Node, gap:=8) -> HBoxContainer:
	var n:=HBoxContainer.new();n.add_theme_constant_override("separation",gap);parent.add_child(n);return n
func _column(parent: Node, gap:=8) -> VBoxContainer:
	var n:=VBoxContainer.new();n.add_theme_constant_override("separation",gap);parent.add_child(n);return n
func _spacer(parent: Node) -> Control:
	var c:=Control.new();c.size_flags_horizontal=SIZE_EXPAND_FILL;parent.add_child(c);return c
func _panel(parent: Node, inset:=Style.PANEL_INSET, radius:=14) -> PanelContainer:
	var p:=PanelContainer.new();p.add_theme_stylebox_override("panel",Style.panel(inset,radius));parent.add_child(p);return p
func _button(text: String, parent: Node, action: Callable, icon:="", variant:="", id:="") -> Button:
	var b:=Button.new();b.text=text;b.theme_type_variation=variant;b.custom_minimum_size.y=34 if not large else 40
	if icon!="":b.icon=Icons.icon(icon,18);b.add_theme_constant_override("icon_max_width",18)
	parent.add_child(b)
	if action.is_valid():b.pressed.connect(action)
	var f:Node=Feedback.attach(b,motion);f.set_reduced(reduced);feedbacks.append(f)
	if id!="":references[id]=b;b.accessibility_name=text if text!="" else id
	return b
func _icon_button(key: String, hint: String, parent: Node, action: Callable, id:="") -> Button:
	var b:=_button("",parent,action,key,"Tool",id);b.tooltip_text=hint;b.accessibility_name=hint;b.custom_minimum_size=Vector2(36,36);return b
func _section_line(parent: Node) -> void:
	var line:=HSeparator.new();var s:=StyleBoxLine.new();s.color=color("border");s.thickness=1;line.add_theme_stylebox_override("separator",s);parent.add_child(line)

func _build() -> void:
	updating=true
	theme=Style.make(dark,large)
	RenderingServer.set_default_clear_color(color("bg"))
	feedbacks=[];disclosures=[];tab_groups=[];references={};panels={}
	shell=MarginContainer.new();shell.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(shell)
	for side in ["left","right","top","bottom"]:shell.add_theme_constant_override("margin_"+side,Style.PAGE_INSET)
	body=_column(shell,Style.GROUP_GAP)
	_build_header()
	var workspace:=_row(body,Style.GROUP_GAP);workspace.size_flags_vertical=SIZE_EXPAND_FILL
	_build_rail(workspace)
	var splitter:=HSplitContainer.new();workspace.add_child(splitter);splitter.size_flags_horizontal=SIZE_EXPAND_FILL;splitter.split_offset=-352;splitter.add_theme_constant_override("separation",Style.GROUP_GAP)
	var middle:=VSplitContainer.new();middle.size_flags_horizontal=SIZE_EXPAND_FILL;middle.size_flags_vertical=SIZE_EXPAND_FILL;middle.add_theme_constant_override("separation",Style.GROUP_GAP);splitter.add_child(middle);middle.split_offset=-296
	var views:=HSplitContainer.new();views.size_flags_vertical=SIZE_EXPAND_FILL;views.add_theme_constant_override("separation",Style.GROUP_GAP);middle.add_child(views);views.split_offset=0
	_build_view(views,true);_build_view(views,false)
	_build_timeline(middle)
	var sidebar:=VSplitContainer.new();sidebar.custom_minimum_size.x=344 if not large else 380;sidebar.add_theme_constant_override("separation",Style.GROUP_GAP);splitter.add_child(sidebar);sidebar.split_offset=252 if not large else 276
	_build_elements(sidebar);_build_inspector(sidebar)
	var footer:=_row(body)
	status_label=_label("演示布景 · 未连接直播输入与输出",footer,12,true)
	_spacer(footer);_label("原生界面提案   /   100%" if not large else "原生界面提案   /   125%",footer,12,true)
	updating=false
	_update_visibility();_refresh_values()
	for g in tab_groups:g.layout(false)

func _rebuild() -> void:
	_commit_gesture()
	var previous:=shell;remove_child(previous);previous.queue_free()
	_build()

func _build_header() -> void:
	var line:=_row(body,12)
	_label("Lumina",line,20,false,true)
	var divider:=VSeparator.new();line.add_child(divider)
	_label("午后工作室",line,14,false,true)
	_label("界面预览",line,12,true)
	_spacer(line)
	var b:=_button("浅色" if dark else "深色",line,func():dark=not dark;_rebuild.call_deferred(),"globe","Quiet","theme")
	b.tooltip_text="切换中性浅／深背景，演示布景的颜色保持不变"
	_button("字号 125%" if large else "字号 100%",line,func():large=not large;_rebuild.call_deferred(),"","Quiet","font_scale")
	var reduce:=_button("减少动态",line,func():_set_reduced(not reduced),"","Quiet","reduced");reduce.toggle_mode=true;reduce.set_pressed_no_signal(reduced)
	var toolbar:=_row(body,20)
	var menus:=_row(toolbar,8)
	for title in ["文件","编辑","视图"]:
		var menu_title:String=title
		var menu_button:=_button(title,menus,func():_show_menu(menu_title),"","Quiet")
		if title=="视图":references.view_menu=menu_button
	var separator:=VSeparator.new();toolbar.add_child(separator)
	var history:=_row(toolbar,8)
	_icon_button("undo","撤销 Ctrl / Cmd + Z",history,_undo,"undo").disabled=undo_stack.is_empty()
	_icon_button("redo","重做 Ctrl / Cmd + Shift + Z",history,_redo,"redo").disabled=redo_stack.is_empty()
	_spacer(toolbar)
	var project_actions:=_row(toolbar,12)
	_label("当前工程 · 演示数据",project_actions,12,true)
	var save:=_button("保存工程",project_actions,Callable(),"save","Quiet","save");save.disabled=true;save.tooltip_text="界面预览不写入正式工程；正式保存仍使用 Lumina 原有流程"
	var output:=_button("输出未连接",project_actions,Callable(),"camera","","output");output.disabled=true;output.tooltip_text="真实直播输入与 Spout 输出须在 Windows / D3D12 环境验证"

func _build_rail(parent: Node) -> void:
	var p:=_panel(parent,10,14);p.custom_minimum_size.x=62
	var rail_style:StyleBoxFlat=p.get_theme_stylebox("panel").duplicate();rail_style.content_margin_top=16;rail_style.content_margin_bottom=16;p.add_theme_stylebox_override("panel",rail_style)
	var column:=_column(p,8)
	for spec in [["select","选择"],["move","移动"],["rotate","旋转"],["scale","缩放"]]:
		var key:String=spec[0]
		var b:=_icon_button(key,spec[1],column,func():_choose_tool(key),"tool_"+key);b.toggle_mode=true;b.set_pressed_no_signal(tool==key);b.custom_minimum_size=Vector2(42,42)
	_section_line(column)
	for spec in [["trim_time","裁剪时间"],["stretch_time","伸缩时间"]]:
		var key:String=spec[0]
		var b:=_icon_button(key,spec[1],column,func():_notify("时间裁剪／伸缩手势保留于正式时间轴；本预览只验证定位和播放"));b.disabled=true;b.tooltip_text="保留入口；本轮不重写正式时间编辑算法"
	_section_line(column)
	_icon_button("add","添加演示元素",column,_open_drawer,"add")
	var library:=_icon_button("library","素材库",column,Callable());library.disabled=true;library.tooltip_text="正式素材库保留，本预览不连接媒体导入"
	var blank:=Control.new();blank.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(blank)
	_icon_button("info","关于本次提案",column,func():_notify("Lumina · 华年集出品。独立原生界面提案；未改动正式工程与输出。"))

func _build_view(parent: Node, stage: bool) -> void:
	var key:="stage" if stage else "output"
	var p:=_panel(parent);p.custom_minimum_size=Vector2(250,210);p.size_flags_horizontal=SIZE_EXPAND_FILL;p.size_flags_vertical=SIZE_EXPAND_FILL;panels[key]=p
	var column:=_column(p,12)
	var header:=_row(column)
	_label("舞台视图" if stage else "输出预览",header,14,false,true)
	_spacer(header)
	if stage:
		var grid:=_icon_button("fit","舞台网格",header,func():grid_enabled=not grid_enabled;scene.grid.visible=grid_enabled;references.grid.set_pressed_no_signal(grid_enabled),"grid");grid.toggle_mode=true;grid.set_pressed_no_signal(grid_enabled)
	_icon_button("minimize" if maximized==key else "maximize","还原双预览" if maximized==key else "放大此视图（时间轴保留）",header,func():maximized="" if maximized==key else key;_update_visibility(),"maximize_"+key)
	var canvas:=PanelContainer.new();canvas.size_flags_vertical=SIZE_EXPAND_FILL;canvas.add_theme_stylebox_override("panel",Style.box(Color("161b1d"),Color(0,0,0,0),4,0,false));column.add_child(canvas)
	var texture:=TextureRect.new();texture.texture=stage_view.get_texture() if stage else output_view.get_texture();texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.size_flags_horizontal=SIZE_EXPAND_FILL;texture.size_flags_vertical=SIZE_EXPAND_FILL;texture.mouse_default_cursor_shape=CURSOR_POINTING_HAND if stage else CURSOR_ARROW;canvas.add_child(texture)
	if stage:texture.gui_input.connect(_stage_input.bind(texture));references.stage_texture=texture
	var caption:=_row(column)
	var caption_label:=_label("编辑视角 · "+state[selected].name if stage else "主机位 · 本地演示",caption,12,true)
	if stage:references.stage_caption=caption_label
	_spacer(caption)
	_label("3D" if stage else "16:9",caption,12,true,false,true)
	# 输出视口保持实际16:9，编辑视口按可用空间适配，不裁掉画面。
	if not stage:output_view.size=Vector2i(1280,720)

func _build_elements(parent: Node) -> void:
	var panel:=_panel(parent);panel.custom_minimum_size.y=240;panels.elements=panel
	var column:=_column(panel,8)
	var head:=_row(column);head.custom_minimum_size.y=32
	references.elements_title=_label("元素",head,16,false,true);_spacer(head);references.elements_count=_label(str(state.size()),head,12,true,false,true)
	for key in state:
		var target:String=key
		var row:=_row(column,4)
		var choice:=_button(state[key].name,row,func():_select(target),state[key].icon,"Quiet","element_"+key)
		choice.size_flags_horizontal=SIZE_EXPAND_FILL;choice.alignment=HORIZONTAL_ALIGNMENT_LEFT;choice.toggle_mode=true;choice.set_pressed_no_signal(selected==key);choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;choice.tooltip_text=state[key].name
		var eye:=_icon_button("eye" if state[key].visible else "eye_off","显示／隐藏 "+state[key].name,row,func():_set_visible(target),"visibility_"+key)
		eye.custom_minimum_size=Vector2(30,30)
		var lock:=_icon_button("lock" if state[key].locked else "unlock","锁定／解锁 "+state[key].name,row,func():_toggle_locked(target),"lock_"+key)
		lock.custom_minimum_size=Vector2(30,30);lock.toggle_mode=true;lock.set_pressed_no_signal(state[key].locked)

func _build_inspector(parent: Node) -> void:
	var panel:=_panel(parent);panel.size_flags_vertical=SIZE_EXPAND_FILL;panels.inspector=panel
	var column:=_column(panel,16)
	var plate:=Control.new();plate.custom_minimum_size.y=40 if not large else 46;column.add_child(plate)
	var indicator:=Panel.new();indicator.mouse_filter=MOUSE_FILTER_IGNORE;indicator.add_theme_stylebox_override("panel",Style.box(color("wash"),Color(0,0,0,0),8,0));plate.add_child(indicator)
	var pages:=HBoxContainer.new();plate.add_child(pages);pages.set_anchors_and_offsets_preset(PRESET_FULL_RECT);pages.add_theme_constant_override("separation",0)
	var buttons:Array=[]
	for spec in [["属性","properties"],["调色","color"]]:
		var b:=_button(spec[0],pages,Callable(),spec[1],"TabButton","tab_"+spec[1]);b.size_flags_horizontal=SIZE_EXPAND_FILL;buttons.append(b)
	var group:=Tabs.new();group.bind(buttons,motion,indicator);tab_groups.append(group);group.select(current_tab,false,false);group.changed.connect(func(index):current_tab=index;_refresh_inspector())
	pages.resized.connect(func():group.layout(false))
	for button in buttons:button.resized.connect(func():group.layout(false))
	inspector_title=_label(state[selected].name,column,16,false,true)
	var choices:=_row(column,4);var scope_buttons:Array=[]
	for i in 2:
		var b:=_button(["当前时刻","整体摆放"][i],choices,Callable(),"","Quiet","scope_"+str(i));b.size_flags_horizontal=SIZE_EXPAND_FILL;scope_buttons.append(b)
	var scope_group:=Tabs.new();scope_group.bind(scope_buttons,motion);scope_group.select(scope,false,false);scope_group.changed.connect(func(index):scope=index;_sync_key_states();_notify("编辑范围："+["当前时刻","整体摆放"][index]+"。关键帧仅记录在本预览。"));tab_groups.append(scope_group)
	inspector_scroll=ScrollContainer.new();inspector_scroll.size_flags_vertical=SIZE_EXPAND_FILL;inspector_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(inspector_scroll)
	var inner:=_column(inspector_scroll,12);inner.size_flags_horizontal=SIZE_EXPAND_FILL
	var properties:=_column(inner,12);references.properties_page=properties
	var transform_body:=_disclosure(properties,"位置与变换","transform")
	_numeric("水平位置","x",transform_body,-5,5,.01,"m")
	_numeric("纵深位置","z",transform_body,-4,4,.01,"m")
	_numeric("旋转","rotation",transform_body,-180,180,1,"°")
	_numeric("缩放","scale",transform_body,.1,3,.01,"×")
	var appearance:=_disclosure(properties,"显示与外观","appearance")
	_label("显隐在元素列表控制；内容颜色保持原样。",appearance,12,true).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var advanced:=_disclosure(properties,"编辑说明","advanced")
	_label("数值直接响应。空心菱形插入当前值，实心菱形可更新或移除。\n本地帧仅验证操作入口与排版，正式插值规则仍使用原实现。",advanced,12,true).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var grading:=_column(inner,12);references.color_page=grading
	_label("全局光感 · 演示",grading,14,false,true)
	_label("仅调整本地布景光照；正式逐层调色仍使用原管线。",grading,12,true).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var r:=_row(grading);_label("曝光",r);_spacer(r);var exp:=_label("%+.1f EV"%exposure,r,12,true,false,true);references.exposure_value=exp
	var slider:=HSlider.new();slider.min_value=-1;slider.max_value=1;slider.step=.05;slider.value=exposure;slider.custom_minimum_size.y=32;grading.add_child(slider);references.exposure=slider
	slider.accessibility_name="本地布景曝光";slider.value_changed.connect(func(value):exposure=value;scene.color_exposure(value);exp.text="%+.1f EV"%value)
	_button("还原曝光",grading,func():slider.value=0.0,"reset","Quiet","reset_exposure")
	_refresh_inspector()

func _disclosure(parent: Node, title: String, key: String) -> VBoxContainer:
	var column:=_column(parent,0)
	var trigger:=_button(title,column,Callable(),"","Section","disclosure_"+key);trigger.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var arrow:=TextureRect.new();arrow.texture=Icons.icon("down",14);arrow.custom_minimum_size=Vector2(14,14);arrow.size=Vector2(14,14);arrow.mouse_filter=MOUSE_FILTER_IGNORE;trigger.add_child(arrow);arrow.pivot_offset=Vector2(7,7);arrow.modulate=color("muted")
	trigger.resized.connect(func():arrow.position=Vector2(trigger.size.x-26,(trigger.size.y-14)/2))
	var region:=Control.new();column.add_child(region);region.size_flags_horizontal=SIZE_EXPAND_FILL
	var content:=MarginContainer.new();content.set_anchors_and_offsets_preset(PRESET_TOP_WIDE);region.add_child(content)
	for side in ["left","right"]:content.add_theme_constant_override("margin_"+side,12)
	content.add_theme_constant_override("margin_top",8);content.add_theme_constant_override("margin_bottom",12)
	var inner:=_column(content,10)
	var d:=Disclosure.new();d.open=bool(group_open[key]);disclosures.append(d);references["region_"+key]=region
	# 字段构建后再测量，避免内容为空时取得零高度。
	_initialize_disclosure.call_deferred(d,key,content,trigger,region,arrow)
	return inner

func _initialize_disclosure(d: Node, key: String, inner: Control, trigger: Button, region: Control, arrow: Control) -> void:
	if not is_instance_valid(d):return
	if not is_instance_valid(inner) or not inner.is_inside_tree():d.free();return
	# 公共展开组件需要在绑定时拿到真实字段，才能连上Escape与焦点回收。
	var targets:Array=[];_collect_focus(inner,targets)
	d.bind(trigger,region,inner,motion,arrow,targets);d.icon=DynamicIcon.attach(arrow,"direction",motion);d.set_reduced(reduced);d.changed.connect(func(value):group_open[key]=value);d.set_open(group_open[key],false)
func _collect_focus(node: Node, targets: Array) -> void:
	if node is Control and node.focus_mode!=FOCUS_NONE:targets.append(node)
	for child in node.get_children():_collect_focus(child,targets)

func _numeric(title: String, key: String, parent: Node, minimum: float, maximum: float, step_value: float, suffix: String) -> void:
	var row:=_row(parent,Style.FIELD_GAP);var caption:=_label(title,row,12,true);caption.custom_minimum_size.x=62 if not large else 74
	var number:=SpinBox.new();number.min_value=minimum;number.max_value=maximum;number.step=step_value;number.value=state[selected][key];number.suffix=suffix;number.size_flags_horizontal=SIZE_EXPAND_FILL;number.custom_minimum_size.y=34;row.add_child(number);references["field_"+key]=number;number.accessibility_name=title
	number.get_line_edit().alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var data_font:=FontVariation.new();data_font.base_font=Style.FONT;data_font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):400.0};data_font.opentype_features={"tnum":1};number.get_line_edit().add_theme_font_override("font",data_font)
	number.value_changed.connect(func(value):
		if updating:return
		if state[selected].locked:
			updating=true;number.value=state[selected][key];updating=false;return
		if gesture_start.is_empty():gesture_start=state.duplicate(true)
		state[selected][key]=value;scene.transform_object(selected,state[selected]))
	number.get_line_edit().focus_exited.connect(_commit_gesture)
	number.get_line_edit().text_submitted.connect(func(_text):_commit_gesture())
	var key_button:Button=KeyframeButton.new();key_button.theme_type_variation="KeyframeButton";key_button.custom_minimum_size=Vector2(32,36) if not large else Vector2(36,40);key_button.accessibility_name=title+"关键帧";row.add_child(key_button);references["key_"+key]=key_button
	key_button.pressed.connect(_activate_key.bind(key))
	var feedback:Node=Feedback.attach(key_button,motion);feedback.set_reduced(reduced);feedbacks.append(feedback)

func _build_timeline(parent: Node) -> void:
	var panel:=_panel(parent);panel.custom_minimum_size.y=288;panels.timeline=panel
	var column:=_column(panel,12)
	var row:=_row(column,8)
	references.timeline_title=_label("时间轴",row,16,false,true)
	_label("12.0 s",row,12,true,false,true)
	_spacer(row)
	_icon_button("reset","回到开头",row,func():_seek(0.0),"restart")
	play_button=_button("暂停" if playing else "播放",row,_toggle_play,"pause" if playing else "play","Quiet","play")
	time_label=_label(_time_text(),row,12,false,false,true);time_label.custom_minimum_size.x=78;time_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var loop:=_icon_button("loop","循环播放（演示默认开启）",row,Callable());loop.disabled=true
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll);references.timeline_scroll=scroll
	timeline=Timeline.new();timeline.colors=Style.colors;timeline.time=clock;timeline.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(timeline);references.timeline=timeline
	timeline.seeked.connect(_seek)
	timeline.configure(state,keyframes)

func _refresh_values() -> void:
	updating=true
	for key in ["x","z","rotation","scale"]:
		if references.has("field_"+key):
			references["field_"+key].value=state[selected][key]
			references["field_"+key].editable=not state[selected].locked
	for key in state:
		references["element_"+key].set_pressed_no_signal(key==selected)
		references["visibility_"+key].icon=Icons.icon("eye" if state[key].visible else "eye_off",18)
		references["lock_"+key].icon=Icons.icon("lock" if state[key].locked else "unlock",18)
		references["lock_"+key].set_pressed_no_signal(state[key].locked)
		references["lock_"+key].tooltip_text=("解锁 " if state[key].locked else "锁定 ")+state[key].name
		scene.transform_object(key,state[key])
	scene.select(selected)
	if inspector_title:inspector_title.text=state[selected].name
	if references.has("stage_caption"):references.stage_caption.text="编辑视角 · "+state[selected].name
	if references.has("undo"):references.undo.disabled=undo_stack.is_empty();references.redo.disabled=redo_stack.is_empty()
	_sync_key_states()
	updating=false

func _snapshot() -> Dictionary:
	return {"objects":state.duplicate(true),"keyframes":keyframes.duplicate(true)}

func _restore(snapshot: Dictionary) -> void:
	state=snapshot.objects.duplicate(true);keyframes=snapshot.keyframes.duplicate(true)

func _key_at(target: String, key: String, when: float) -> int:
	var frames:Array=keyframes.get(target,{}).get(key,[])
	for i in frames.size():
		if is_equal_approx(float(frames[i].time),snappedf(when,.1)):return i
	return -1

func _sync_key_states() -> void:
	for key in ["x","z","rotation","scale"]:
		if not references.has("key_"+key):continue
		var button:Button=references["key_"+key]
		button.at_key=_key_at(selected,key,clock)>=0
		button.has_track=not keyframes.get(selected,{}).get(key,[]).is_empty()
		button.key_color=Color("e8d29d") if dark else Color("946926")
		button.get_node("ButtonFeedback").set_disabled(state[selected].locked)
		button.tooltip_text=button.accessibility_name+" · "+("当前已有帧，点击更新或移除" if button.at_key else "点击在当前时刻插入关键帧")+"\n仅记录在独立预览，不写入正式工程"
		if state[selected].locked:button.tooltip_text="元素已锁定，请先解锁"
		button.queue_redraw()
	if timeline:timeline.configure(state,keyframes)

func _activate_key(key: String) -> void:
	if state[selected].locked:_notify("元素已锁定，请先解锁");return
	_commit_gesture()
	if playing:_toggle_play()
	var target:=selected;var when:=snappedf(clock,.1)
	if _key_at(target,key,when)<0:_record_key(target,key,when);return
	var menu:=PopupMenu.new();add_child(menu)
	menu.add_item("更新当前值",0);menu.add_item("移除当前关键帧",1)
	menu.id_pressed.connect(func(id):
		if selected!=target or not is_equal_approx(snappedf(clock,.1),when):_notify("目标或时刻已变化，请重新打开关键帧菜单");return
		if id==0:_record_key(target,key,when)
		else:_remove_key(target,key,when))
	menu.popup_hide.connect(menu.queue_free)
	var button:Button=references["key_"+key]
	menu.position=Vector2i(button.get_screen_position()+Vector2(0,button.size.y));menu.popup()

func _record_key(target: String, key: String, when: float) -> void:
	if state[target].locked:_notify("元素已锁定，请先解锁");return
	_commit_gesture();undo_stack.append(_snapshot());redo_stack.clear()
	if not keyframes.has(target):keyframes[target]={}
	if not keyframes[target].has(key):keyframes[target][key]=[]
	var index:=_key_at(target,key,when)
	var entry:Dictionary={"time":snappedf(when,.1),"value":state[target][key]}
	if index<0:keyframes[target][key].append(entry)
	else:keyframes[target][key][index]=entry
	keyframes[target][key].sort_custom(func(a,b):return float(a.time)<float(b.time))
	_refresh_values();_notify("已记录 "+state[target].name+" · "+{"x":"水平位置","z":"纵深位置","rotation":"旋转","scale":"缩放"}[key]+" 的本地关键帧")

func _remove_key(target: String, key: String, when: float) -> void:
	if state[target].locked:_notify("元素已锁定，请先解锁");return
	var index:=_key_at(target,key,when)
	if index<0:return
	undo_stack.append(_snapshot());redo_stack.clear();keyframes[target][key].remove_at(index)
	if keyframes[target][key].is_empty():keyframes[target].erase(key)
	if keyframes[target].is_empty():keyframes.erase(target)
	_refresh_values();_notify("已移除当前本地关键帧")

func _refresh_inspector() -> void:
	if references.has("properties_page"):
		references.properties_page.visible=current_tab==0;references.color_page.visible=current_tab==1
	for d in disclosures:
		if is_instance_valid(d) and d.is_inside_tree():d.refresh()

func _choose_tool(value: String) -> void:
	tool=value
	for key in ["select","move","rotate","scale"]:references["tool_"+key].set_pressed_no_signal(key==value)
	_notify({"select":"选择元素：点击右侧元素或舞台中的演示对象","move":"移动工具：在舞台拖动目标；属性数值可精调","rotate":"旋转工具：在舞台横向拖动目标","scale":"缩放工具：在舞台横向拖动目标"}[value])

func _select(key: String) -> void:
	_commit_gesture();selected=key;_refresh_values()
	_notify("已选择 "+state[key].name)

func _set_visible(key: String) -> void:
	_commit_gesture();undo_stack.append(_snapshot());redo_stack.clear();state[key].visible=not state[key].visible;_refresh_values()

func _toggle_locked(key: String) -> void:
	_commit_gesture();undo_stack.append(_snapshot());redo_stack.clear()
	state[key].locked=not state[key].locked;_refresh_values()
	_notify(state[key].name+(" 已锁定，可查看和切换显隐" if state[key].locked else " 已解锁"))

func _commit_gesture() -> void:
	if gesture_start.is_empty():return
	if gesture_start!=state:undo_stack.append({"objects":gesture_start.duplicate(true),"keyframes":keyframes.duplicate(true)});redo_stack.clear()
	gesture_start={}
	if references.has("undo"):references.undo.disabled=undo_stack.is_empty();references.redo.disabled=redo_stack.is_empty()

func _undo() -> void:
	_commit_gesture()
	if undo_stack.is_empty():return
	redo_stack.append(_snapshot());_restore(undo_stack.pop_back());_refresh_values();_notify("已撤销本地编辑")
func _redo() -> void:
	if redo_stack.is_empty():return
	undo_stack.append(_snapshot());_restore(redo_stack.pop_back());_refresh_values();_notify("已重做本地编辑")

func _stage_input(event: InputEvent, texture: TextureRect) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			gesture_start=state.duplicate(true)
			if tool=="select":
				var factor:float=minf(texture.size.x/stage_view.size.x,texture.size.y/stage_view.size.y)
				var point:Vector2=(event.position-(texture.size-Vector2(stage_view.size)*factor)/2)/factor
				var origin:=stage_camera.project_ray_origin(point);var direction:=stage_camera.project_ray_normal(point)
				var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*100)
				var hit:=stage_view.find_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and hit.collider.has_meta("element_id"):
					var target:=str(hit.collider.get_meta("element_id"))
					if not state[target].locked:_select(target)
					else:_notify("元素已锁定，可在元素列表解锁")
		else:_commit_gesture()
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT and tool!="select":
		if state[selected].locked:_notify("元素已锁定，请先解锁");return
		if gesture_start.is_empty():gesture_start=state.duplicate(true)
		var speed:=.002 if Input.is_key_pressed(KEY_SHIFT) else .01
		if tool=="move":state[selected].x=clampf(state[selected].x+event.relative.x*speed,-5,5);state[selected].z=clampf(state[selected].z+event.relative.y*speed,-4,4)
		elif tool=="rotate":state[selected].rotation=wrapf(state[selected].rotation+event.relative.x*.5,-180,180)
		elif tool=="scale":state[selected].scale=clampf(state[selected].scale+event.relative.x*speed,.1,3)
		_refresh_values()

func _update_visibility() -> void:
	panels.stage.visible=maximized!="output";panels.output.visible=maximized!="stage"
	scene.grid.visible=grid_enabled
	for key in ["stage","output"]:references["maximize_"+key].icon=Icons.icon("minimize" if maximized==key else "maximize",18)

func _toggle_play() -> void:
	playing=not playing;play_button.text="暂停" if playing else "播放";play_button.icon=Icons.icon("pause" if playing else "play",18)
	_notify("本地运镜播放中" if playing else "已暂停本地运镜")
func _seek(value: float) -> void:
	clock=value;timeline.time=value;timeline.queue_redraw();time_label.text=_time_text();_update_camera();_sync_key_states()
func _time_text() -> String:return "%02d:%02d.%01d"%[int(clock)/60,int(clock)%60,int(fmod(clock,1)*10)]
func _update_camera() -> void:
	var phase:=clock/12*TAU
	output_camera.position=Vector3(4.3+sin(phase)*.5,2.9,5.9+cos(phase)*.25);output_camera.look_at(Vector3(-.1,1.25,-1))
func _process(delta: float) -> void:
	if playing:_seek(fmod(clock+delta,12))
	for d in disclosures:
		if is_instance_valid(d) and d.is_inside_tree() and d.open and (not d.motion or not d.motion.is_valid()):d.refresh()

func _set_reduced(value: bool) -> void:
	reduced=value;references.reduced.set_pressed_no_signal(value)
	for f in feedbacks:if is_instance_valid(f):f.set_reduced(value)
	for d in disclosures:if is_instance_valid(d):d.set_reduced(value)
	for g in tab_groups:if is_instance_valid(g):g.set_reduced(value)
	_notify("已减少界面动态；播放中的内容继续按真实时间运行" if value else "已恢复日常级界面动态")

func _notify(text: String) -> void:
	if status_label:status_label.text=text;status_label.tooltip_text=text;status_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;status_label.size_flags_horizontal=SIZE_EXPAND_FILL

func _show_menu(title: String) -> void:
	var popup:=PopupMenu.new();add_child(popup)
	if title=="文件":
		popup.add_item("新建／打开／保存：正式工程入口保留");popup.set_item_disabled(0,true)
		popup.add_item("演示数据与正式工程完全独立");popup.set_item_disabled(1,true)
	elif title=="编辑":
		popup.add_item("撤销",0);popup.set_item_disabled(0,undo_stack.is_empty());popup.add_item("重做",1);popup.set_item_disabled(1,redo_stack.is_empty());popup.id_pressed.connect(func(id):_undo() if id==0 else _redo())
	else:
		popup.add_item("还原双预览",0);popup.add_item("切换浅深背景",1);popup.id_pressed.connect(func(id):
			if id==0:maximized="";_update_visibility()
			else:dark=not dark;_rebuild.call_deferred())
	popup.popup_hide.connect(popup.queue_free);popup.position=get_window().position+Vector2i(get_global_mouse_position());popup.popup()

func _open_drawer() -> void:
	if is_instance_valid(drawer):drawer.queue_free();return
	drawer=_panel(self,16,16);drawer.position=Vector2(86,180);drawer.custom_minimum_size=Vector2(270,220)
	var col:=_column(drawer,12);var head:=_row(col);_label("添加演示元素",head,16,false,true);_spacer(head);_icon_button("close","关闭",head,func():drawer.queue_free())
	_label("本轮可选择现有布景对象。\n正式素材导入与添加操作继续使用原流程。",col,12,true).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for key in state:
		var value:String=key;_button(state[key].name,col,func():_select(value);drawer.queue_free(),state[key].icon,"Quiet")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:_commit_gesture.call_deferred()
	if event is InputEventKey and event.pressed:
		var owner:=get_viewport().gui_get_focus_owner()
		if event.keycode==KEY_ESCAPE:
			if not gesture_start.is_empty():
				state=gesture_start.duplicate(true);gesture_start={};_refresh_values();get_viewport().set_input_as_handled();return
			# SpinBox的内置编辑器会先消耗Escape；在应用适配层保留公共展开的焦点约定。
			if DisplayServer.ime_get_text().is_empty():
				for d in disclosures:
					if is_instance_valid(d) and d.is_inside_tree() and d.open and owner and d.region.is_ancestor_of(owner):
						d.set_open(false);get_viewport().set_input_as_handled();return
			if is_instance_valid(drawer):drawer.queue_free()
		if (event.ctrl_pressed or event.meta_pressed) and event.keycode==KEY_Z:
			if owner is LineEdit:return
			_redo() if event.shift_pressed else _undo();get_viewport().set_input_as_handled()
		if event.keycode==KEY_SPACE and not (owner is LineEdit or owner is Button):_toggle_play();get_viewport().set_input_as_handled()

func _verify() -> void:
	await get_tree().create_timer(1).timeout
	var report:Dictionary={"baseline":"1fed2c27f828aac05489c2b40818b9251a7db43b","engine":Engine.get_version_info().string,"checks":[]}
	for key in references:
		if references[key] is Control:
			var control:Control=references[key]
			if control.is_visible_in_tree() and control.size.x<1:report.checks.append({"name":"nonzero "+key,"ok":false})
	report.checks.append({"name":"initial selections / single timeline","ok":references.element_desk.button_pressed and current_tab==0 and timeline.time==clock})
	report.checks.append(_layout_check("dark 100"))
	_select("lamp");references.field_rotation.value=24;_commit_gesture();_undo()
	report.checks.append({"name":"parameter undo preserves target","ok":selected=="lamp" and is_zero_approx(state.lamp.rotation)})
	_redo();report.checks.append({"name":"parameter redo","ok":is_equal_approx(state.lamp.rotation,24)})
	await _pointer_click(references.key_x)
	report.checks.append({"name":"pointer inserts property key and timeline child track","ok":references.key_x.at_key and _key_at("lamp","x",clock)>=0 and timeline.tracks.any(func(row):return row.kind=="property" and row.target=="lamp")})
	_undo();var removed_by_undo:=_key_at("lamp","x",clock)<0
	_redo();report.checks.append({"name":"key insertion undo and redo preserve object values","ok":removed_by_undo and _key_at("lamp","x",clock)>=0 and is_equal_approx(state.lamp.rotation,24)})
	var original_time:=clock;_seek(clock+.5)
	report.checks.append({"name":"key button separates existing track from current key","ok":references.key_x.has_track and not references.key_x.at_key})
	_remove_key("lamp","x",original_time);_undo()
	report.checks.append({"name":"remove key can be undone","ok":_key_at("lamp","x",original_time)>=0})
	_seek(original_time)
	await _pointer_click(references.lock_lamp)
	var locked_x:float=state.lamp.x
	references.field_x.value=locked_x+.5;_record_key("lamp","z",clock)
	report.checks.append({"name":"pointer lock disables numeric and key editing","ok":state.lamp.locked and not references.field_x.editable and references.key_x.disabled and is_equal_approx(state.lamp.x,locked_x) and _key_at("lamp","z",clock)<0})
	_choose_tool("move");await _pointer_drag(references.stage_texture)
	report.checks.append({"name":"locked target rejects actual stage pointer drag","ok":is_equal_approx(state.lamp.x,locked_x)})
	_undo();report.checks.append({"name":"lock can be undone and editing restored","ok":not state.lamp.locked and references.field_x.editable and not references.key_x.disabled})
	_redo();await _pointer_click(references.lock_lamp);_choose_tool("select")
	for _i in 4:disclosures[0].set_open(false);await get_tree().create_timer(.07).timeout;disclosures[0].set_open(true)
	_set_reduced(true)
	report.checks.append({"name":"interrupted disclosure settles under reduced motion","ok":is_equal_approx(disclosures[0].region.custom_minimum_size.y,disclosures[0].target)})
	_set_reduced(false);dark=false;_rebuild();await get_tree().create_timer(.3).timeout
	report.checks.append({"name":"theme rebuild preserves selection and data","ok":selected=="lamp" and is_equal_approx(state.lamp.rotation,24) and not dark})
	report.checks.append(_layout_check("light 100"))
	large=true;_rebuild();await get_tree().create_timer(.3).timeout
	report.checks.append({"name":"125 percent roles and scroll","ok":Style.ui_scale==1.25 and inspector_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED})
	report.checks.append(_layout_check("light 125"))
	current_tab=1;_rebuild();await get_tree().create_timer(.2).timeout
	await _pointer_click(references.tab_properties)
	report.checks.append({"name":"expanded groups survive hidden tab and theme rebuild","ok":current_tab==0 and group_open.transform and references.region_transform.custom_minimum_size.y>100})
	references.field_x.get_line_edit().grab_focus()
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;Input.parse_input_event(escape)
	await get_tree().create_timer(.5).timeout
	report.checks.append({"name":"Escape closes focused region and returns focus to trigger","ok":not disclosures[0].open and get_viewport().gui_get_focus_owner()==references.disclosure_transform,"open":disclosures[0].open,"focus":str(get_viewport().gui_get_focus_owner())})
	disclosures[0].set_open(true,false)
	await _pointer_click(references.tab_color)
	report.checks.append({"name":"pointer tab and indicator cover whole button","ok":current_tab==1 and absf(tab_groups[0].indicator.size.x-references.tab_color.size.x)<1})
	get_viewport().get_texture().get_image().save_png("res://evidence/light-125.png")
	# 用逻辑视口验证布局；物理窗口的Retina映射不作为本次Windows DPI证据。
	get_window().content_scale_size=Vector2i(1200,760);await get_tree().create_timer(.4).timeout
	report.checks.append({"name":"1200 by 760 logical viewport at 125 percent keeps sidebar and timeline inside viewport","ok":size.is_equal_approx(Vector2(1200,760)) and panels.output.get_global_rect().end.x<=size.x and timeline.get_global_rect().end.y<=size.y and references.tab_color.get_global_rect().end.x<=size.x,"logical_size":[size.x,size.y]})
	report.checks.append(_layout_check("light 125 narrow"))
	get_viewport().get_texture().get_image().save_png("res://evidence/light-125-1200x760.png")
	get_window().content_scale_size=Vector2i(1440,900)
	dark=true;large=false;current_tab=0;keyframes.clear();_rebuild();_select("desk");state.lamp.rotation=0;undo_stack.clear();redo_stack.clear();_refresh_values()
	await get_tree().create_timer(.5).timeout
	var rebound:=await _sample_rebound(references.tool_move)
	report.checks.append({"name":"pointer press and release rebound, stable hit box","ok":rebound.press<.98 and rebound.peak>1.01 and absf(rebound.rest-1)<.001 and rebound.stable,"samples":rebound})
	_choose_tool("select");_notify("演示布景 · 未连接直播输入与输出")
	await get_tree().process_frame
	var file:=FileAccess.open("res://evidence/engine-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	get_viewport().get_texture().get_image().save_png("res://evidence/dark-1440x900.png")
	print("LUMINA_PREVIEW_CHECKS "+JSON.stringify(report))
	if "--quit-after-verify" in OS.get_cmdline_user_args():get_tree().quit(0 if report.checks.all(func(check):return check.ok) else 1)

func _layout_check(condition: String) -> Dictionary:
	var failures:Array=[]
	for spec in [["elements","elements_title"],["elements","elements_count"],["timeline","timeline_title"],["inspector","tab_properties"]]:
		var panel:Rect2=panels[spec[0]].get_global_rect();var content:Rect2=references[spec[1]].get_global_rect()
		if content.position.x-panel.position.x<Style.PANEL_INSET-.5 or content.position.y-panel.position.y<Style.PANEL_INSET-.5 or panel.end.x-content.end.x<Style.PANEL_INSET-.5:failures.append(spec[1]+" panel inset")
	for property in ["x","z","rotation","scale"]:
		var number:Rect2=references["field_"+property].get_global_rect();var key:Rect2=references["key_"+property].get_global_rect()
		if key.position.x-number.end.x<Style.FIELD_GAP-.5 or key.end.x>panels.inspector.get_global_rect().end.x-Style.PANEL_INSET:failures.append(property+" key spacing")
	var menu_end:float=references.view_menu.get_global_rect().end.x
	if references.undo.get_global_rect().position.x-menu_end<32:failures.append("toolbar group gap")
	return {"name":"layout clearance "+condition,"ok":failures.is_empty(),"failures":failures}

func _pointer_click(control: Control) -> void:
	var at:=control.get_global_rect().get_center()
	var movement:=InputEventMouseMotion.new();movement.position=at;movement.global_position=at;Input.parse_input_event(movement)
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.position=at;down.global_position=at;down.pressed=true;Input.parse_input_event(down)
	await get_tree().process_frame
	var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=at;up.global_position=at;Input.parse_input_event(up)
	await get_tree().create_timer(.35).timeout

func _pointer_drag(control: Control) -> void:
	var at:=control.get_global_rect().get_center()
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.position=at;down.global_position=at;down.pressed=true;Input.parse_input_event(down)
	await get_tree().process_frame
	var movement:=InputEventMouseMotion.new();movement.position=at+Vector2(48,0);movement.global_position=movement.position;movement.relative=Vector2(48,0);movement.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(movement)
	await get_tree().process_frame
	var up:InputEventMouseButton=down.duplicate();up.pressed=false;up.position=movement.position;Input.parse_input_event(up)
	await get_tree().create_timer(.1).timeout

func _sample_rebound(button: Button) -> Dictionary:
	var rect:=button.get_global_rect();var at:=rect.get_center()
	var movement:=InputEventMouseMotion.new();movement.position=at;movement.global_position=at;Input.parse_input_event(movement)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=true;Input.parse_input_event(event)
	await get_tree().create_timer(.12).timeout
	var press:float=button.offset_transform_scale.x
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	var peak:=1.0
	for _i in 15:
		await get_tree().create_timer(.035).timeout
		peak=maxf(peak,button.offset_transform_scale.x)
	return {"press":press,"peak":peak,"rest":button.offset_transform_scale.x,"stable":button.get_global_rect().is_equal_approx(rect)}
