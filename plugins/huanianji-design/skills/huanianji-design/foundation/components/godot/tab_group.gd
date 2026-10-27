extends Node

const Action = preload("res://components/godot/action_button.gd")
const InputFocus = preload("res://components/godot/input_focus.gd")

signal changed(index: int)

var buttons: Array
var panels: Array
var indicator: Control
var config: Dictionary:
	set(value):
		config=value
		for button in buttons:
			if is_instance_valid(button):
				var feedback: Node=button.get_node_or_null("ButtonFeedback")
				if feedback: feedback.config=value
var selected := 0
var reduced := false
var motion: Tween
var target := Rect2()

func bind(items: Array, parameters: Dictionary, plate: Control = null, content_panels: Array = []) -> void:
	buttons = items
	config = parameters
	indicator = plate
	panels = content_panels
	name = "TabGroup"
	buttons[0].get_parent().add_child(self)
	for i in buttons.size():
		Action.attach(buttons[i],parameters)
		buttons[i].set_meta("hj_tab_owner",get_instance_id())
		if buttons[i].theme_type_variation.is_empty(): buttons[i].theme_type_variation="TabButton"
		buttons[i].toggle_mode = true
		buttons[i].pressed.connect(select.bind(i))
		buttons[i].gui_input.connect(key_input.bind(i))
	buttons[0].visibility_changed.connect(func():
		if not buttons[0].is_visible_in_tree(): layout(false))
	for i in buttons.size():
		if not buttons[i].disabled:
			select(i,false,false)
			return
	clear()

func set_disabled(index: int, value: bool) -> void:
	Action.attach(buttons[index],config).set_disabled(value)
	if value and index==selected:
		for i in buttons.size():
			if not buttons[i].disabled:
				select(i)
				return
		clear()
	elif not value and selected < 0: select(index)
	elif not value: buttons[index].focus_mode=Control.FOCUS_ALL if index==selected else Control.FOCUS_CLICK

func clear() -> void:
	selected=-1
	for button in buttons:
		button.set_pressed_no_signal(false)
		button.focus_mode=Control.FOCUS_NONE
	for panel in panels: panel.hide()
	layout(false)
	changed.emit(-1)

func select(index: int, animate: bool = true, notify: bool = true) -> bool:
	if index < 0 or index >= buttons.size() or buttons[index].disabled: return false
	selected = index
	var focus := get_viewport().gui_get_focus_owner()
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i==index)
		buttons[i].focus_mode = Control.FOCUS_NONE if buttons[i].disabled else (Control.FOCUS_ALL if i==index else Control.FOCUS_CLICK)
		if i < panels.size():
			if i != index and focus and panels[i].is_ancestor_of(focus): InputFocus.for_button(buttons[index]).grab(buttons[index])
			panels[i].visible = i==index
	layout(animate)
	if notify: changed.emit(index)
	return true

func key_input(event: InputEvent, index: int) -> void:
	if not event is InputEventKey or not event.pressed: return
	if not event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_HOME,KEY_END]: return
	var enabled: Array = []
	for i in buttons.size():
		if not buttons[i].disabled: enabled.append(i)
	if enabled.is_empty(): return
	var at := enabled.find(index)
	var next: int
	if event.keycode == KEY_HOME: next=enabled[0]
	elif event.keycode == KEY_END: next=enabled[-1]
	else: next=enabled[posmod(at+(1 if event.keycode==KEY_RIGHT else -1),enabled.size())]
	select(next)
	buttons[next].grab_focus()
	buttons[index].accept_event()

func layout(animate: bool = true, preserve: bool = false) -> void:
	if not indicator: return
	indicator.visible=selected>=0
	if selected < 0:
		if motion and motion.is_valid(): motion.kill()
		return
	var button: Control = buttons[selected]
	var rect := Rect2(button.position,button.size)
	if preserve and rect.is_equal_approx(target): return
	target = rect
	if motion and motion.is_valid(): motion.kill()
	if not animate or reduced:
		indicator.position=rect.position
		indicator.size=rect.size
		return
	motion=create_tween().set_parallel(true)
	motion.tween_property(indicator,"position",rect.position,float(config.select_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(indicator,"size",rect.size,float(config.select_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_reduced(value: bool) -> void:
	reduced=value
	for button in buttons:
		if is_instance_valid(button): button.get_node("ButtonFeedback").set_reduced(value)
	layout(false)

func _exit_tree() -> void:
	if motion and motion.is_valid(): motion.kill()
	for button in buttons:
		if is_instance_valid(button) and button.get_meta("hj_tab_owner",0)==get_instance_id(): button.remove_meta("hj_tab_owner")
