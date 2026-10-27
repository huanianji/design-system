extends Node

# 每个Viewport保留同一份输入方式，动态新建按钮也能沿用当前意图。
var keyboard := true
var refresh_queued := false

static func for_button(button: Button) -> Node:
	var viewport:Viewport=button.get_viewport()
	button.set_meta("hj_managed_focus",true)
	var policy:Variant=viewport.get_meta("hj_input_focus") if viewport.has_meta("hj_input_focus") else null
	if is_instance_valid(policy): return policy
	policy=load("res://components/godot/input_focus.gd").new()
	policy.name="HuanianjiInputFocus"
	viewport.set_meta("hj_input_focus",policy)
	# 控件可能仍在父场景的_ready内；延后挂到Viewport，避免抢改正在初始化的子树。
	viewport.call_deferred("add_child",policy)
	return policy

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(func(_control): queue_refresh())
	queue_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: keyboard=false
	elif event is InputEventScreenTouch and event.pressed: keyboard=false
	elif event is InputEventKey and event.pressed: keyboard=true
	elif event is InputEventJoypadButton and event.pressed: keyboard=true
	else: return
	queue_refresh()

func grab(button: Button) -> void:
	button.grab_focus(not keyboard)

func queue_refresh() -> void:
	if refresh_queued: return
	refresh_queued=true
	call_deferred("refresh")

func refresh() -> void:
	refresh_queued=false
	var owner:Control=get_viewport().gui_get_focus_owner()
	if owner is Button and owner.get_meta("hj_managed_focus",false) and owner.has_focus(true)!=keyboard:
		owner.grab_focus(not keyboard)

func _exit_tree() -> void:
	var viewport:=get_parent()
	if viewport and viewport.get_meta("hj_input_focus",null)==self: viewport.remove_meta("hj_input_focus")
