extends Control

const Contract = preload("res://adapters/godot/style_contract.gd")
const ButtonFeedback = preload("res://components/godot/action_button.gd")
const Tabs = preload("res://components/godot/tab_group.gd")
const Disclosure = preload("res://components/godot/disclosure.gd")
var tab_group
var disclosure
var initialized := false
var roles: Dictionary
var profile := "baseline"
var manifest: Dictionary
var bundle: Dictionary
var mode := "light"
var accent := "indigo"
var enlarged := false
var reduced := false
var expanded := false
var selected := 0
var clicks := 0
var changes: Array = []
var animations: Dictionary = {}
var expand_target := 0.0
var button_feedback: Dictionary = {}
var event_log: Array = []
var ime_seen := false
var ime_max_length := 0
var ime_committed := false
var live_poll := 0.0

func _ready() -> void:
	%Reload.pressed.connect(func():
		if initialized: reload_design()
		else: get_tree().reload_current_scene())
	if not read_design(): return
	initialized = true
	var content: Dictionary = bundle.content
	for name in content:
		get_node("%"+name).text = str(content[name])
	get_window().title = "华年集 · 共同基础 / Godot 原生"
	%Mode.pressed.connect(func(): set_mode("dark" if mode == "light" else "light"))
	%Accent.pressed.connect(func():
		var names: Array = ["baseline","jade-demo"]
		set_profile(names[(names.find(profile)+1)%names.size()]))
	%TextScale.pressed.connect(toggle_text_scale)
	%Reduce.toggled.connect(set_reduced)
	%ReadyCheck.toggled.connect(check_changed)
	%Action.pressed.connect(func(): clicks += 1; %ActionNote.text = "已体验 %d 次 · 本地演示" % clicks; log_event("activate", clicks))
	%Bell.pressed.connect(ring_bell.bind("click"))
	%Bell.mouse_entered.connect(ring_bell.bind("hover"))
	%Bell.focus_entered.connect(func():
		if not %Bell.is_hovered(): ring_bell("focus"))
	%Brightness.value_changed.connect(func(v): %BrightnessLabel.text = "参数调节  %d%%" % v; log_event("brightness",v))
	%TopicInput.text_changed.connect(func(value):
		if ime_seen and not value.is_empty(): ime_committed = true
		log_event("input",value))
	tab_group=Tabs.new()
	tab_group.bind([%Tab0,%Tab1,%Tab2],roles.motion,%Plate)
	tab_group.changed.connect(func(index): selected=index; log_event("tab",index))
	disclosure=Disclosure.new()
	disclosure.bind(%Expand,%Reveal,%Settings,roles.motion,%ExpandArt,[%Brightness])
	disclosure.changed.connect(func(value):
		expanded=value
		expand_target=disclosure.target
		%Expand.text="收起设置" if value else "展开设置"
		log_event("expanded",value))
	for candidate in find_children("*","Button",true,false):
		if candidate is CheckBox: continue
		var feedback = ButtonFeedback.attach(candidate,roles.motion)
		button_feedback[candidate.name] = feedback
	get_window().size_changed.connect(resize_layout)
	apply_theme()
	await get_tree().process_frame
	resize_layout()
	await get_tree().process_frame
	place_indicator(false)
	%TopicInput.grab_focus()
	log_event("ready", profile)

func _process(delta: float) -> void:
	if not initialized: return
	var composing := DisplayServer.ime_get_text()
	if not composing.is_empty():
		ime_seen = true
		ime_max_length = maxi(ime_max_length, composing.length())
	live_poll += delta
	if live_poll > 0.2:
		live_poll = 0
		var file := FileAccess.open(evidence_path("live-state.json"),FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(snapshot(),"\t"))

func evidence_path(name: String) -> String:
	return ProjectSettings.globalize_path("res://evidence/" + name)

func log_event(kind: String, value: Variant) -> void:
	event_log.append({"kind":kind,"value":value,"ms":Time.get_ticks_msec()})
	if event_log.size() > 150: event_log.pop_front()

func design_error(message: String) -> void:
	%Card.hide()
	%LabTitle.text = message
	push_error(message)

func read_design() -> bool:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://generated/manifest.json"))
	if not raw is Dictionary:
		design_error("共同源未生成，请运行 build.py build")
		return false
	manifest = raw
	if not current_source(): return false
	for name in manifest.assets:
		if FileAccess.get_sha256("res://"+name) != manifest.assets[name]:
			design_error("资源已变化，请重新生成："+name)
			return false
	for name in manifest.outputs:
		if FileAccess.get_sha256("res://"+name) != manifest.outputs[name]:
			design_error("生成物缺失或被改动，请重新生成："+name)
			return false
	bundle = JSON.parse_string(FileAccess.get_file_as_string("res://"+manifest.bundle+"/profiles.json"))
	if not bundle.profiles.has(profile): profile = "baseline"
	roles = bundle.profiles[profile].godot
	accent = bundle.profiles[profile].accent
	return true

func current_source() -> bool:
	for name in manifest.inputs:
		if FileAccess.get_sha256("res://"+name) != manifest.inputs[name]:
			design_error("共同源已变更，请重新生成并读取")
			return false
	return true

func reload_design() -> void:
	if not read_design(): return
	for feedback in button_feedback.values(): feedback.config = roles.motion
	apply_theme()

func set_profile(value: String) -> void:
	profile = value
	roles = bundle.profiles[profile].godot
	accent = bundle.profiles[profile].accent
	for feedback in button_feedback.values(): feedback.config = roles.motion
	apply_theme()
	log_event("profile",value)

func set_mode(value: String) -> void:
	mode = value
	apply_theme()
	log_event("mode",value)

func toggle_text_scale() -> void:
	enlarged = not enlarged
	apply_theme()

func apply_theme() -> void:
	if not current_source(): return
	tab_group.config=roles.motion
	disclosure.config=roles.motion
	%Card.show()
	%LabTitle.text = "Godot 原生 · "+str(manifest.build_id).left(8)
	var resource_path := "res://%s/themes/%s_%s.tres" % [manifest.bundle,profile,mode]
	var source := load(resource_path) as Theme
	if source == null:
		push_error("主题资源不可用：" + resource_path)
		return
	theme = source.duplicate(true) if enlarged else source
	if enlarged:
		theme.default_font_size = roundi(source.default_font_size * 1.25)
		for type_name in theme.get_type_list():
			for key in theme.get_font_size_list(type_name):
				theme.set_font_size(key,type_name,roundi(source.get_font_size(key,type_name)*1.25))
	var p := Contract.palette(roles,mode,accent)
	%Background.color = Color(p.page)
	%BellArt.self_modulate = Color(p.ink)
	%ExpandArt.self_modulate = Color(p.muted)
	%SceneLabel.add_theme_color_override("font_color",Color(p.accent))
	%Mode.text = "切换浅色" if mode == "dark" else "切换深色"
	%Accent.text = "主题："+str(bundle.profiles[profile].label)
	%TextScale.text = "字号 100%" if enlarged else "字号 125%"
	%CheckArt.glyph_offset_x = float(roles.optical.check_x)
	%CheckArt.queue_redraw()
	call_deferred("resize_layout")

func resize_layout() -> void:
	var width := get_viewport_rect().size.x
	var margin := int(roles.space.page_small if width < 1000 else roles.space.page_large)
	%Shell.add_theme_constant_override("margin_left",margin)
	%Shell.add_theme_constant_override("margin_right",margin)
	%Card.custom_minimum_size.x = minf(880,width-margin*2-18)
	%Side.custom_minimum_size.x = 80 if width < 900 else 110
	%Settings.size.x = %Reveal.size.x
	%Action.pivot_offset = %Action.size/2
	%CheckArt.pivot_offset = Vector2(14,14)
	%BellArt.pivot_offset = Vector2(12,3)
	%CheckArt.position.y = (%ReadyCheck.size.y-28)/2
	%BellArt.position.x = (%Bell.size.x-24)/2 + float(roles.optical.bell_x)
	%BellArt.position.y = (%Bell.size.y-24)/2
	%ExpandArt.position = Vector2(%Expand.size.x-24,(%Expand.size.y-16)/2)
	%ExpandArt.pivot_offset = Vector2(8,8)
	place_indicator(false,true)
	if expanded and not is_equal_approx(expand_target,%Settings.get_combined_minimum_size().y):
		set_expanded(true)

func stop_animation(key: String) -> void:
	if animations.has(key) and is_instance_valid(animations[key]):
		animations[key].kill()
	animations.erase(key)

func tween_for(key: String) -> Tween:
	stop_animation(key)
	var tween := create_tween()
	animations[key] = tween
	return tween

func press_action(down: bool) -> void:
	button_feedback.Action.press(down)

func check_changed(checked: bool) -> void:
	stop_animation("check")
	log_event("check",checked)
	if reduced:
		%CheckArt.progress = 1.0 if checked else 0.0
		%CheckArt.scale = Vector2.ONE
		return
	var t := tween_for("check")
	t.set_parallel(true)
	t.tween_property(%CheckArt,"progress",1.0 if checked else 0.0,float(roles.motion.check_draw_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 从当前缩放接续，不先跳回固定起点。
	t.tween_property(%CheckArt,"scale",Vector2.ONE*float(roles.motion.check_press_scale),float(roles.motion.check_press_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(%CheckArt,"scale",Vector2.ONE,float(roles.motion.check_release_seconds)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func select_tab(index: int) -> void:
	tab_group.select(index)

func place_indicator(animate: bool, preserve_if_unchanged: bool = false) -> void:
	if tab_group: tab_group.layout(animate,preserve_if_unchanged)

func set_expanded(value: bool) -> void:
	disclosure.set_open(value)

func set_reduced(value: bool) -> void:
	reduced = value
	%Reduce.set_pressed_no_signal(value)
	for key in animations.keys(): stop_animation(key)
	for feedback in button_feedback.values(): feedback.set_reduced(value)
	tab_group.set_reduced(value)
	disclosure.set_reduced(value)
	%CheckArt.scale = Vector2.ONE
	%CheckArt.progress = 1.0 if %ReadyCheck.button_pressed else 0.0
	%BellArt.rotation = 0
	place_indicator(false)
	set_expanded(expanded)
	log_event("reduced",value)

func ring_bell(trigger: String = "click") -> void:
	stop_animation("bell")
	if reduced or %Bell.disabled: return
	var t := tween_for("bell")
	var values: Array = [%BellArt.rotation]
	for angle in roles.motion.bell_degrees: values.append(deg_to_rad(float(angle)))
	t.tween_method(func(progress): %BellArt.rotation=ButtonFeedback.sample_keys(ButtonFeedback.ease_bezier(progress,roles.motion.press_easing),values,[0.0,0.25,0.5,0.75,1.0]),0.0,1.0,float(roles.motion.bell_seconds))
	log_event("bell",trigger)

func snapshot() -> Dictionary:
	var boxes := {}
	for name in ["Card","Body","Frame","Scene","SceneRow","Side","Side0","Bell","BellArt","Action","ReadyCheck","Reveal","Settings","Plate","Tab0","Tab1","Tab2"]:
		var control := get_node("%"+name) as Control
		boxes[name] = {"position":[control.global_position.x,control.global_position.y],"size":[control.size.x,control.size.y],"scale":[control.scale.x,control.scale.y]}
	var focus := get_viewport().gui_get_focus_owner()
	return {"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":[get_window().size.x,get_window().size.y],"profile":profile,"build_id":manifest.build_id,"mode":mode,"accent":accent,"enlarged":enlarged,"reduced":reduced,"expanded":expanded,"selected":selected,"checked":%ReadyCheck.button_pressed,"parameter":%Brightness.value,"text":%TopicInput.text,"clicks":clicks,"check_progress":%CheckArt.progress,"focus":str(focus.name) if focus else "","ime_seen":ime_seen,"ime_max_length":ime_max_length,"ime_committed":ime_committed,"boxes":boxes,"events":event_log.duplicate()}

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(evidence_path(name+".png"))
	var file := FileAccess.open(evidence_path(name+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot(),"\t"))
