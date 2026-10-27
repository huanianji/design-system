extends Node

const InputFocus = preload("res://components/godot/input_focus.gd")

signal changed(open: bool)

var trigger: Button
var region: Control
var content: Control
var arrow: Control
var icon: Node
var focus_targets: Array
var config: Dictionary
var open := false
var target := 0.0
var reduced := false
var motion: Tween
var focus_policy: Node

func bind(button: Button, viewport: Control, inner: Control, parameters: Dictionary, icon: Control = null, fields: Array = []) -> void:
	trigger=button
	focus_policy=InputFocus.for_button(button)
	region=viewport
	content=inner
	arrow=icon
	focus_targets=fields
	config=parameters
	name="Disclosure"
	region.add_child(self)
	region.clip_contents=true
	trigger.pressed.connect(func(): set_open(not open))
	for field in focus_targets: field.gui_input.connect(func(event):
		if open and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and DisplayServer.ime_get_text().is_empty():
			set_open(false)
			trigger.accept_event())
	region.visibility_changed.connect(func():
		if not region.is_visible_in_tree(): set_open(open,false))

func set_open(value: bool, animated: bool = true) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if not value and focus and region.is_ancestor_of(focus): focus_policy.grab(trigger)
	open=value
	for field in focus_targets: field.focus_mode=Control.FOCUS_ALL if open else Control.FOCUS_NONE
	# 收起后保留内容供测量与草稿恢复；命中由裁切边界、焦点由上述目标控制。
	target=content.get_combined_minimum_size().y if open else 0.0
	if motion and motion.is_valid(): motion.kill()
	changed.emit(open)
	if reduced or not animated:
		settle()
		return
	var from: float=region.custom_minimum_size.y
	var angle: float=arrow.rotation if arrow else 0.0
	var bump:=minf(float(config.expand_limit),absf(target-from)*float(config.expand_ratio))
	var heights: Array=[from,target+bump,target-bump*float(config.expand_return_ratio),target] if open else [from,from+bump*float(config.collapse_lift_ratio),0.0]
	var offsets: Array=config.expand_offsets if open else config.collapse_offsets
	motion=create_tween().set_parallel(true)
	motion.tween_method(func(progress: float):
		if icon: icon.follow(lerpf(angle/PI,1.0 if value else 0.0,1.0-pow(1.0-progress,3)))
		elif arrow: arrow.rotation=lerpf(angle,PI if value else 0.0,1.0-pow(1.0-progress,3))
		for i in range(1,offsets.size()):
			if progress<=float(offsets[i]):
				var q: float=(progress-float(offsets[i-1]))/(float(offsets[i])-float(offsets[i-1]))
				var weight: float=1.0-pow(1.0-q,3) if value and i==1 else smoothstep(0,1,q)
				region.custom_minimum_size.y=maxf(0,lerpf(float(heights[i-1]),float(heights[i]),weight))
				break
	,0.0,1.0,float(config.expand_seconds))

func settle() -> void:
	if motion and motion.is_valid(): motion.kill()
	region.custom_minimum_size.y=target
	if icon: icon.follow(1.0 if open else 0.0)
	elif arrow: arrow.rotation=PI if open else 0.0

func refresh() -> void:
	if open and not is_equal_approx(target,content.get_combined_minimum_size().y): set_open(open,false)

func set_reduced(value: bool) -> void:
	reduced=value
	if reduced: settle()

func _exit_tree() -> void:
	if motion and motion.is_valid(): motion.kill()
	if is_instance_valid(region): region.custom_minimum_size.y=target
	if is_instance_valid(arrow): arrow.rotation=PI if open else 0.0
