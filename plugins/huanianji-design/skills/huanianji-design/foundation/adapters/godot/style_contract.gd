extends RefCounted

# 共同角色到 Godot 原生主题的映射；行为和排布由平台适配负责。
static func palette(data: Dictionary, mode: String, accent: String) -> Dictionary:
	var out: Dictionary = data[mode].duplicate()
	out.merge(data.accents[accent][mode])
	return out

static func box(bg: Color, radii: Array, margin: float = 0, border: Color = Color.TRANSPARENT, width: int = 0) -> Dictionary:
	return {"bg_color":bg, "corner_radius_top_left":int(radii[0]), "corner_radius_top_right":int(radii[1]), "corner_radius_bottom_right":int(radii[2]), "corner_radius_bottom_left":int(radii[3]), "content_margin_left":margin, "content_margin_right":margin, "content_margin_top":margin, "content_margin_bottom":margin, "border_color":border, "border_width_left":width, "border_width_top":width, "border_width_right":width, "border_width_bottom":width, "anti_aliasing":true}

static func build(data: Dictionary, mode: String, accent: String, font: Font, heading: Font) -> Dictionary:
	var p := palette(data, mode, accent)
	var s: Dictionary = data.shape
	var body: int = int(data.font.body)
	var styles := {}
	var bases := {}
	styles["Label"] = {"font_color":Color(p.ink), "font_size":body}
	styles["VBoxContainer"] = {"separation":int(data.space.group)}
	styles["HBoxContainer"] = {"separation":int(data.space.tight)}
	styles["HFlowContainer"] = {"h_separation":8, "v_separation":8}
	styles["Button"] = {"font_color":Color(p.ink), "font_hover_color":Color(p.ink), "font_pressed_color":Color(p.accent), "font_focus_color":Color(p.ink), "font_disabled_color":Color(p.muted), "font_size":body, "normal":box(Color(p.paper), s.small, 10, Color(p.line), 1), "hover":box(Color(p.soft), s.small, 10, Color(p.accent), 1), "pressed":box(Color(p.wash), s.small, 10, Color(p.accent), 1), "disabled":box(Color(p.soft), s.small, 10, Color(p.line), 1), "focus":box(Color.TRANSPARENT, s.small, 0, Color(p.accent), 2)}
	styles["PanelContainer"] = {"panel":box(Color(p.paper), s.panel, float(data.space.panel), Color(p.line), 1)}
	styles["Panel"] = {"panel":box(Color(p.soft), s.small)}
	styles["LineEdit"] = {"font_size":body, "font_color":Color(p.ink), "font_placeholder_color":Color(p.muted), "caret_color":Color(p.accent), "selection_color":Color(p.wash), "normal":box(Color(p.soft), s.small, 12, Color(p.control_line), 1), "focus":box(Color.TRANSPARENT, s.small, 0, Color(p.accent), 2)}
	styles["CheckBox"] = {"font_color":Color(p.ink), "font_focus_color":Color(p.ink), "font_pressed_color":Color(p.ink), "font_hover_color":Color(p.ink), "font_size":body, "h_separation":12, "normal":box(Color.TRANSPARENT, s.small, 10), "hover":box(Color(p.soft), s.small, 10), "pressed":box(Color(p.soft), s.small, 10), "focus":box(Color.TRANSPARENT, s.small, 0, Color(p.accent), 2), "checked":load("res://assets/icons/blank.svg"), "unchecked":load("res://assets/icons/blank.svg")}
	styles["HSlider"] = {"slider":box(Color(p.control_line), [3,3,3,3],3), "grabber_area":box(Color(p.accent), [3,3,3,3],3), "grabber_area_highlight":box(Color(p.accent), [3,3,3,3],3), "grabber":load("res://assets/icons/grabber.svg"), "grabber_highlight":load("res://assets/icons/grabber.svg")}
	styles["Heading"] = {"font":heading, "font_size":int(data.font.title), "font_color":Color(p.ink)}
	bases["Heading"] = "Label"
	styles["Muted"] = {"font_size":int(data.font.small), "font_color":Color(p.muted)}
	bases["Muted"] = "Label"
	for kind in ["success", "warning", "error"]:
		styles[kind.capitalize()] = {"font_size":int(data.font.small), "font_color":Color(p[kind])}
		bases[kind.capitalize()] = "Label"
	styles["Section"] = {"font":heading, "font_size":int(data.font.section)}
	bases["Section"] = "Label"
	styles["Body"] = {"font":font,"font_size":body}
	bases["Body"] = "Label"
	styles["StrongBody"] = {"font":heading,"font_size":body}
	bases["StrongBody"] = "Label"
	styles["SmallButton"] = {"font_size":int(data.font.small)}
	bases["SmallButton"] = "Button"
	styles["Action"] = {"font":heading, "font_color":Color(p.action_ink), "font_hover_color":Color(p.action_ink), "font_focus_color":Color(p.action_ink), "font_pressed_color":Color(p.action_ink), "normal":box(Color(p.action), s.button, 12), "hover":box(Color(p.action).lightened(0.06), s.button, 12), "pressed":box(Color(p.action), s.button, 12), "focus":box(Color.TRANSPARENT, s.button, 0, Color(p.accent), 2)}
	bases["Action"] = "Button"
	styles["TabButton"] = {"normal":box(Color.TRANSPARENT, s.small, 8), "hover":box(Color(Color(p.paper),0.25), s.small, 8), "pressed":box(Color.TRANSPARENT, s.small, 8), "font_pressed_color":Color(p.accent)}
	bases["TabButton"] = "Button"
	styles["SmallTabButton"] = {"font_size":int(data.font.small)}
	bases["SmallTabButton"] = "TabButton"
	styles["TabsPanel"] = {"panel":box(Color(p.soft), s.button, 6)}
	bases["TabsPanel"] = "PanelContainer"
	styles["FramePanel"] = {"panel":box(Color(p.paper), s.frame, float(data.space.frame), Color(p.line), 1)}
	bases["FramePanel"] = "PanelContainer"
	styles["ScenePanel"] = {"panel":box(Color(p.soft), s.small, float(data.space.scene))}
	bases["ScenePanel"] = "PanelContainer"
	styles["PreviewPanel"] = {"panel":box(Color(p.wash), s.micro, 10, Color(p.line), 1)}
	bases["PreviewPanel"] = "PanelContainer"
	styles["SelectionPlate"] = {"panel":box(Color(p.wash), s.small)}
	bases["SelectionPlate"] = "Panel"
	styles["SidePanel"] = {"panel":box(Color(p.paper), s.micro, 0, Color(p.line), 1)}
	bases["SidePanel"] = "Panel"
	# 原生组合状态不会自动继承已配置的 hover/pressed；显式补齐，避免退回引擎默认。
	for kind in ["Button", "CheckBox"]:
		styles[kind]["hover_pressed"] = styles[kind].pressed.duplicate(true)
		styles[kind]["font_hover_pressed_color"] = Color(p.ink) if kind == "CheckBox" else Color(p.accent)
		styles[kind]["align_to_largest_stylebox"] = 1
	styles["CheckBox"]["disabled"] = box(Color.TRANSPARENT,s.small,10)
	styles["CheckBox"]["font_disabled_color"] = Color(p.muted)
	styles["Action"]["hover_pressed"] = box(Color(p.action).lightened(0.03),s.button,12)
	styles["Action"]["font_hover_pressed_color"] = Color(p.action_ink)
	styles["Action"]["disabled"] = box(Color(p.soft),s.button,12,Color(p.line),1)
	styles["TabButton"]["hover_pressed"] = box(Color.TRANSPARENT,s.small,8)
	styles["TabButton"]["disabled"] = box(Color.TRANSPARENT,s.small,8)
	styles["TabButton"]["font_hover_pressed_color"] = Color(p.accent)
	styles["ExpandButton"] = {}
	bases["ExpandButton"] = "TabButton"
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var spec: Dictionary = styles["TabButton"][state].duplicate(true)
		spec.content_margin_right = 30.0
		styles["ExpandButton"][state] = spec
	styles["CheckShape"] = {"panel":box(Color(p.action),s.check)}
	bases["CheckShape"] = "Panel"
	styles["Tree"] = {"font_color":Color(p.ink),"font_selected_color":Color(p.ink),"font_hovered_color":Color(p.ink),"font_hovered_selected_color":Color(p.ink),"font_hovered_dimmed_color":Color(p.ink),"font_disabled_color":Color(p.muted),"title_button_color":Color(p.muted),"guide_color":Color(p.line),"font_size":body,"title_button_font_size":int(data.font.small),"v_separation":12,"h_separation":10,"draw_guides":1,"panel":box(Color(p.paper),s.small,8),"focus":box(Color.TRANSPARENT,s.small,0,Color(p.accent),2)}
	for key in ["selected","hovered_selected"]: styles["Tree"][key]=box(Color(p.wash),s.micro,0)
	for key in ["selected_focus","hovered_selected_focus"]: styles["Tree"][key]=box(Color(p.wash),s.micro,0,Color(p.accent),1)
	for key in ["hovered","hovered_dimmed"]: styles["Tree"][key]=box(Color(p.soft),s.micro,0)
	styles["Tree"]["cursor"]=box(Color.TRANSPARENT,s.micro,0,Color(p.accent),1)
	styles["Tree"]["cursor_unfocused"]=box(Color.TRANSPARENT,s.micro,0)
	for key in ["title_button_normal","title_button_hover","title_button_pressed"]: styles["Tree"][key]=box(Color(p.soft),s.micro,10)
	styles["RosterTree"]={}
	bases["RosterTree"]="Tree"
	for key in ["title_button_normal","title_button_hover","title_button_pressed"]:
		var title:=box(Color.TRANSPARENT,[0,0,0,0],10,Color(p.line))
		title.border_width_bottom=1
		styles["RosterTree"][key]=title
	styles["TaskCheck"]={"font_size":int(data.font.small),"h_separation":10,"pressed":box(Color.TRANSPARENT,s.small,10),"hover_pressed":box(Color(p.soft),s.small,10)}
	bases["TaskCheck"]="CheckBox"
	styles["NoteDisclosure"]={"font_size":int(data.font.small),"font_pressed_color":Color(p.ink),"font_hover_pressed_color":Color(p.ink)}
	bases["NoteDisclosure"]="ExpandButton"
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var spec:=box(Color(p.soft),s.small,10)
		spec.content_margin_right=30.0
		styles["NoteDisclosure"][state]=spec
	styles["TextEdit"]={"font_size":body,"font_color":Color(p.ink),"font_selected_color":Color(p.ink),"caret_color":Color(p.accent),"selection_color":Color(p.wash),"normal":box(Color(p.soft),s.small,10,Color(p.control_line),1),"focus":box(Color.TRANSPARENT,s.small,0,Color(p.accent),2),"read_only":box(Color(p.soft),s.small,10)}
	styles["NoteInput"]={"font_size":int(data.font.small)}
	bases["NoteInput"]="TextEdit"
	styles["AssetChoice"]={"normal":box(Color(p.soft),s.small,8,Color(p.line),1),"hover":box(Color(p.soft),s.small,8,Color(p.accent),1),"pressed":box(Color(p.wash),s.small,8,Color(p.accent),1),"hover_pressed":box(Color(p.wash),s.small,8,Color(p.accent),1),"focus":box(Color.TRANSPARENT,s.small,0,Color(p.accent),2)}
	bases["AssetChoice"]="Button"
	return {"styles":styles, "bases":bases, "font":font, "font_size":body}

static func make_box(spec: Dictionary) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	for property in spec:
		result.set(property, spec[property])
	return result
