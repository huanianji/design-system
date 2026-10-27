extends Node

signal changed(value: String)
var target: Control
var message: Label
var status := "idle"
var disabled := false
var read_only := false
var colors: Dictionary
var description := ""

static func attach(field: Control, palette: Dictionary, hint: Label = null) -> Node:
	var existing:=field.get_node_or_null("InputField")
	if existing: return existing
	var behavior=load("res://components/godot/input_field.gd").new()
	behavior.target=field
	behavior.message=hint
	field.add_child(behavior)
	behavior.name="InputField"
	behavior.colors=palette
	behavior.description=field.accessibility_description
	field.set_meta("hj_input_field",true)
	# 不拦截编辑键、光标或输入法；TextEdit和LineEdit继续走各自的原生编辑路径。
	if field is LineEdit: field.text_changed.connect(func(_text): behavior.edited())
	else: field.text_changed.connect(behavior.edited)
	if field is TextEdit:
		field.gui_input.connect(func(event):
			if event is InputEventKey and event.pressed and event.keycode==KEY_TAB and DisplayServer.ime_get_text().is_empty():
				var next:Control=field.find_prev_valid_focus() if event.shift_pressed else field.find_next_valid_focus()
				if next:next.grab_focus()
				field.accept_event())
	behavior.refresh()
	return behavior

func edited() -> void:
	set_status()
	changed.emit(target.text)

func set_status(value: String = "idle", text: String = "") -> void:
	status=value
	target.set_meta("hj_input_status",status)
	if message:
		message.text=text
		message.add_theme_color_override("font_color",Color(colors.get(value,colors.muted)))
	target.accessibility_description=description+("。"+text if not text.is_empty() else "")
	refresh()

func refresh(palette: Dictionary = {}) -> void:
	if not palette.is_empty(): colors=palette
	target.add_theme_color_override("font_placeholder_color",Color(colors.muted))
	target.add_theme_color_override("font_readonly_color",Color(colors.muted))
	target.add_theme_color_override("font_uneditable_color",Color(colors.muted))
	for key in ["normal","read_only","focus"]:
		target.remove_theme_stylebox_override(key)
		var style:StyleBox=target.get_theme_stylebox("normal" if key=="read_only" else key).duplicate()
		if style is StyleBoxFlat and status=="error": style.border_color=Color(colors.error)
		target.add_theme_stylebox_override(key,style)
	if message: message.add_theme_color_override("font_color",Color(colors.get(status,colors.muted)))

func set_disabled(value: bool) -> void:
	disabled=value
	target.editable=not disabled and not read_only
	target.focus_mode=Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	target.modulate.a=0.65 if disabled else 1.0

func set_read_only(value: bool) -> void:
	read_only=value
	target.editable=not disabled and not read_only
