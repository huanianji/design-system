extends Node

const InputFocus = preload("res://components/godot/input_focus.gd")

signal completed(result: Dictionary)
signal cancelled

# Godot 4.7 的视觉偏移保留原生布局、命中和焦点；无需复制按钮或自行绘制文字。
var target: Button
var config: Dictionary
var motion: Tween
var reduced := false
var busy := false
var desired_disabled := false
var generation := 0
var restore_focus := false
var blocked := false
var available_focus_mode := Control.FOCUS_ALL
var accessible_description := ""
var held := false
var focus_policy: Node
var visual_scale: Vector2:
	get: return target.offset_transform_scale
	set(value): target.offset_transform_scale = value

func bind(button: Button, parameters: Dictionary) -> void:
	target = button
	config = parameters
	name = "ButtonFeedback"
	button.add_child(self)
	focus_policy=InputFocus.for_button(button)
	button.offset_transform_enabled = true
	button.offset_transform_visual_only = true
	button.offset_transform_pivot_ratio = Vector2(0.5,0.5)
	button.button_down.connect(press.bind(true))
	button.button_up.connect(press.bind(false))
	desired_disabled = button.disabled
	button.visibility_changed.connect(func():
		if not button.is_visible_in_tree(): reset())
	button.focus_exited.connect(func():
		if held: reset())
	button.get_window().focus_exited.connect(reset)
	set_process(true)

static func attach(button: Button, parameters: Dictionary) -> Node:
	var existing := button.get_node_or_null("ButtonFeedback")
	if existing:
		existing.config = parameters
		return existing
	var behavior = load("res://components/godot/action_button.gd").new()
	behavior.bind(button,parameters)
	return behavior

func _process(_delta: float) -> void:
	sync_availability()

func sync_availability() -> void:
	# 原生禁用按钮仍可能被鼠标聚焦；明确排除，不能只依赖 disabled 的默认外观。
	if target.disabled:
		if not blocked: available_focus_mode=target.focus_mode
		blocked=true
		target.focus_mode=Control.FOCUS_NONE
		# 在途只阻断再次激活，已经释放的输入反馈应继续；显式禁用仍由set_disabled归稳。
		if not busy and not visual_scale.is_equal_approx(Vector2.ONE): reset()
	elif blocked:
		# TabGroup 可能已显式重设单一键盘入口；不覆盖新的焦点归属。
		if target.focus_mode==Control.FOCUS_NONE: target.focus_mode=available_focus_mode
		blocked=false

func reset() -> void:
	held=false
	if motion and motion.is_valid(): motion.kill()
	visual_scale = Vector2.ONE

func set_disabled(value: bool) -> void:
	desired_disabled = value
	target.disabled = value or busy
	sync_availability()
	if value: reset()

func begin() -> int:
	if target.disabled or busy or not is_inside_tree(): return 0
	generation += 1
	restore_focus = target.has_focus()
	if held: press(false)
	busy = true
	target.disabled = true
	accessible_description=target.accessibility_description
	target.accessibility_description = "处理中"
	sync_availability()
	return generation

func finish(token: int, result: Dictionary) -> bool:
	if not busy or token != generation: return false
	busy = false
	target.disabled = desired_disabled
	target.accessibility_description = accessible_description
	sync_availability()
	if restore_focus and not target.disabled and not target.get_viewport().gui_get_focus_owner(): focus_policy.grab(target)
	completed.emit(result)
	return true

func cancel() -> void:
	if not busy: return
	generation += 1
	busy = false
	target.disabled = desired_disabled
	target.accessibility_description = accessible_description
	sync_availability()
	reset()
	if restore_focus and not target.disabled and not target.get_viewport().gui_get_focus_owner(): focus_policy.grab(target)
	cancelled.emit()

func set_reduced(value: bool) -> void:
	reduced = value
	if motion and motion.is_valid(): motion.kill()
	visual_scale = Vector2.ONE

func press(down: bool) -> void:
	if not down and not held: return
	if down and target.disabled: return
	held=down
	if motion and motion.is_valid(): motion.kill()
	if reduced or (target.disabled and not busy):
		visual_scale = Vector2.ONE
		return
	motion = create_tween()
	var start := visual_scale.x
	if down:
		motion.tween_method(func(t): visual_scale = Vector2.ONE*lerpf(start,float(config.press_scale),ease_bezier(t,config.press_easing)),0.0,1.0,float(config.press_seconds))
	else:
		# WAAPI 的 easing 作用于整条时间轴；先映射全局进度，再插值关键帧。
		var peak := float(config.release_peak)
		if target.get_meta("hj_tab_owner",0)!=0 or target.theme_type_variation == "TabButton": peak = float(config.tab_release_peak)
		var values := [start,peak,float(config.release_return),1.0]
		var offsets := [0.0,float(config.release_offsets[0]),float(config.release_offsets[1]),1.0]
		motion.tween_method(func(t): visual_scale = Vector2.ONE*sample_keys(ease_bezier(t,config.release_easing),values,offsets),0.0,1.0,float(config.release_seconds))

static func ease_bezier(progress: float, points: Array) -> float:
	if progress<=0: return 0
	if progress>=1: return 1
	var low := 0.0
	var high := 1.0
	for _i in 18:
		var at := (low+high)*0.5
		var x := 3.0*(1-at)*(1-at)*at*float(points[0])+3.0*(1-at)*at*at*float(points[2])+at*at*at
		if x<progress: low=at
		else: high=at
	var at := (low+high)*0.5
	return 3.0*(1-at)*(1-at)*at*float(points[1])+3.0*(1-at)*at*at*float(points[3])+at*at*at

static func sample_keys(progress: float, values: Array, offsets: Array) -> float:
	for i in range(1,offsets.size()):
		if progress<=float(offsets[i]):
			return lerpf(float(values[i-1]),float(values[i]),(progress-float(offsets[i-1]))/(float(offsets[i])-float(offsets[i-1])))
	return float(values[-1])

func _exit_tree() -> void:
	generation += 1
	if motion and motion.is_valid(): motion.kill()
	if is_instance_valid(target):
		target.offset_transform_scale=Vector2.ONE
		if busy:
			busy=false
			target.disabled=desired_disabled
			target.accessibility_description=accessible_description
		if blocked and target.focus_mode==Control.FOCUS_NONE: target.focus_mode=available_focus_mode
