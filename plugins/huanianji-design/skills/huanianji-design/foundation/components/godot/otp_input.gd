extends Control

signal changed(slots: Array)
var slots: Array[String]=["","","","","",""]
var fields: Array[LineEdit]=[]
var labels: Array[Label]=[]
var boxes: Array[PanelContainer]=[]
var digits_motion: Dictionary={}
var motion: Tween
var error_motion: Tween
var plate: Panel
var track: HBoxContainer
var config: Dictionary
var colors: Dictionary
var roles: Dictionary
var message: Label
var status := "idle"
var reduced := false
var disabled := false
var read_only := false
var focused := -1
var composing := false

static func digits(text: String) -> String:
	var result:=""
	for character in text:
		var code:=character.unicode_at(0)
		if code>=0xff10 and code<=0xff19: character=str(code-0xff10)
		if character>="0" and character<="9": result+=character
	return result

func bind(parameters: Dictionary, palette: Dictionary, hint: Label = null) -> void:
	roles=parameters
	config=roles.motion
	colors=palette
	message=hint
	custom_minimum_size=Vector2(0,float(roles.space.code_cell))
	track=HBoxContainer.new()
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_theme_constant_override("separation",int(roles.space.code_gap))
	add_child(track)
	for i in slots.size():
		var box:=PanelContainer.new()
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		box.clip_contents=true
		track.add_child(box)
		boxes.append(box)
		var field:=LineEdit.new()
		field.name="Digit"+str(i)
		field.custom_minimum_size=Vector2(0,float(roles.space.code_cell))
		field.expand_to_text_length=false
		field.add_theme_constant_override("minimum_character_width",1)
		field.alignment=HORIZONTAL_ALIGNMENT_CENTER
		field.accessibility_name="验证码第 %d 位" % (i+1)
		field.placeholder_text=""
		for key in ["normal","read_only","focus"]:field.add_theme_stylebox_override(key,StyleBoxEmpty.new())
		box.add_child(field)
		fields.append(field)
		var digit:=Label.new()
		digit.mouse_filter=Control.MOUSE_FILTER_IGNORE
		digit.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		digit.offset_transform_enabled=true
		digit.offset_transform_visual_only=true
		box.add_child(digit)
		labels.append(digit)
		field.text_changed.connect(func(_value): call_deferred("commit",i))
		field.focus_entered.connect(func(): focused=i;field.select_all();layout(true);refresh_glyphs())
		field.focus_exited.connect(func(): call_deferred("sync_focus"))
		field.gui_input.connect(key_input.bind(i))
	plate=Panel.new()
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	resized.connect(func(): call_deferred("layout",false))
	refresh(parameters,palette)
	set_process(true)
	call_deferred("layout",false)

func commit(index: int) -> void:
	if disabled or read_only or not DisplayServer.ime_get_text().is_empty():return
	var text:=fields[index].text
	var value:=digits(text)
	var previous:=slots.duplicate()
	if text.is_empty():slots[index]=""
	elif not value.is_empty():
		for n in mini(value.length(),slots.size()-index):slots[index+n]=value[n]
	for i in slots.size():
		fields[i].text=slots[i]
		if previous[i]!=slots[i] and not slots[i].is_empty(): enter_digit(i)
	set_status()
	refresh_glyphs()
	if not value.is_empty(): focus(mini(slots.size()-1,index+value.length()))
	changed.emit(slots.duplicate())

func focus(index: int) -> void:
	fields[index].grab_focus()
	fields[index].select_all()

func sync_focus() -> void:
	if not is_inside_tree():return
	var owner:=get_viewport().gui_get_focus_owner()
	var next:=fields.find(owner) if owner is LineEdit else -1
	# 旧字段的focus_exited延后执行时，新字段可能已开始移动焦点框；不得把新运动立即截断。
	if next!=focused:
		focused=next
		layout(false)
	refresh_glyphs()

func key_input(event: InputEvent, index: int) -> void:
	# 鼠标默认处理会在focus_entered之后重新放光标；释放后全选，保证粘贴是替换该位。
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		fields[index].call_deferred("select_all")
		return
	if not event is InputEventKey or not event.pressed or disabled or composing:return
	if event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_HOME,KEY_END]:
		focus(0 if event.keycode==KEY_HOME else slots.size()-1 if event.keycode==KEY_END else clampi(index+(-1 if event.keycode==KEY_LEFT else 1),0,slots.size()-1))
		fields[index].accept_event()
	elif not read_only and event.keycode in [KEY_BACKSPACE,KEY_DELETE]:
		if slots[index].is_empty() and event.keycode==KEY_BACKSPACE:focus(maxi(0,index-1))
		else: fields[index].text="";commit(index)
		fields[index].accept_event()

func box_style(border: Color, width: int = 1, transparent: bool = false) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color.TRANSPARENT if transparent else Color(colors.soft)
	style.border_color=border
	style.set_border_width_all(width)
	var corners:Array=roles.shape.small
	style.corner_radius_top_left=int(corners[0])
	style.corner_radius_top_right=int(corners[1])
	style.corner_radius_bottom_right=int(corners[2])
	style.corner_radius_bottom_left=int(corners[3])
	return style

func refresh(parameters: Dictionary, palette: Dictionary) -> void:
	var geometry_changed:bool=custom_minimum_size.y!=float(parameters.space.code_cell) or track.get_theme_constant("separation")!=int(parameters.space.code_gap)
	roles=parameters;config=roles.motion;colors=palette
	custom_minimum_size.y=float(roles.space.code_cell)
	track.add_theme_constant_override("separation",int(roles.space.code_gap))
	var border:=Color(colors.get(status,colors.line))
	for i in fields.size():
		fields[i].custom_minimum_size.y=float(roles.space.code_cell)
		boxes[i].add_theme_stylebox_override("panel",box_style(border))
		fields[i].add_theme_font_size_override("font_size",roundi(float(roles.font.section)*(get_theme_default_font_size()/float(roles.font.body))))
		labels[i].add_theme_font_size_override("font_size",fields[i].get_theme_font_size("font_size"))
		fields[i].add_theme_color_override("font_selected_color",Color.TRANSPARENT)
		fields[i].add_theme_color_override("selection_color",Color(colors.wash))
		fields[i].add_theme_color_override("caret_color",Color.TRANSPARENT)
		labels[i].add_theme_color_override("font_color",Color(colors.ink))
	plate.add_theme_stylebox_override("panel",box_style(Color(colors.get(status,colors.accent)),2,true))
	if message:message.add_theme_color_override("font_color",Color(colors.get(status,colors.muted)))
	refresh_glyphs()
	if geometry_changed:call_deferred("layout",false)
	elif not motion or not motion.is_valid():layout(false)

func refresh_glyphs() -> void:
	for i in fields.size():
		fields[i].add_theme_color_override("font_color",Color(colors.ink) if composing and focused==i else Color.TRANSPARENT)
		fields[i].add_theme_color_override("font_uneditable_color",Color.TRANSPARENT)
		labels[i].visible=not (composing and focused==i)
		labels[i].text=slots[i] if not slots[i].is_empty() else ("│" if focused==i else "")

func layout(animated: bool = false) -> void:
	if not is_instance_valid(plate):return
	plate.visible=focused>=0 and not disabled
	if motion and motion.is_valid():motion.kill()
	if not plate.visible:return
	var destination:=boxes[focused].position
	plate.size=boxes[focused].size
	if animated and not reduced:
		motion=create_tween()
		motion.tween_property(plate,"position",destination,float(config.select_seconds)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:plate.position=destination

func enter_digit(index: int) -> void:
	if digits_motion.has(index) and digits_motion[index].is_valid():digits_motion[index].kill()
	var digit:=labels[index]
	digit.offset_transform_position=Vector2.ZERO
	digit.modulate.a=1
	if reduced:return
	digit.offset_transform_position=Vector2(0,-fields[index].size.y*float(config.input_enter_ratio))
	digit.modulate.a=0
	var tween:=create_tween().set_parallel()
	digits_motion[index]=tween
	tween.tween_property(digit,"offset_transform_position",Vector2.ZERO,float(config.release_seconds)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(digit,"modulate:a",1.0,float(config.select_seconds))

func set_status(value: String = "idle", text: String = "") -> void:
	status=value
	if message:message.text=text
	for field in fields:field.accessibility_description=text
	if error_motion and error_motion.is_valid():error_motion.kill()
	offset_transform_position=Vector2.ZERO
	if status=="error" and not reduced:
		offset_transform_enabled=true;offset_transform_visual_only=true
		error_motion=create_tween()
		for x in [-1,1,-0.5,0.5,0]:error_motion.tween_property(self,"offset_transform_position",Vector2(x*float(config.input_error_distance),0),float(config.release_seconds)/5.0)
	refresh(roles,colors)

func set_disabled(value: bool) -> void:
	disabled=value
	if disabled:set_reduced(reduced)
	for field in fields:field.editable=not disabled and not read_only;field.focus_mode=Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	modulate.a=0.65 if disabled else 1.0
	sync_focus()

func set_read_only(value: bool) -> void:
	read_only=value
	for field in fields:field.editable=not disabled and not read_only

func complete() -> bool:return slots.all(func(value):return not value.is_empty())
func value() -> String:return "".join(slots)
func clear() -> void:
	set_reduced(reduced)
	slots.assign(["","","","","",""])
	for field in fields:field.text=""
	set_status();refresh_glyphs();changed.emit(slots.duplicate())

func set_reduced(value: bool) -> void:
	reduced=value
	if motion and motion.is_valid():motion.kill()
	if error_motion and error_motion.is_valid():error_motion.kill()
	offset_transform_position=Vector2.ZERO
	for i in labels.size():
		if digits_motion.has(i) and digits_motion[i].is_valid():digits_motion[i].kill()
		labels[i].offset_transform_position=Vector2.ZERO;labels[i].modulate.a=1
	layout(false)

func _process(_delta: float) -> void:
	var next:=not DisplayServer.ime_get_text().is_empty()
	if next!=composing:
		composing=next;refresh_glyphs()
		if not composing and focused>=0:commit(focused)

func _exit_tree() -> void:
	focused=-1
	set_reduced(reduced)
