extends RefCounted
const BACKGROUND = Color("181c22")
const PANEL = Color("242a33")
const SURFACE = Color("2d3540")
const FIELD = Color("1d232c")
const BORDER = Color("465260")
const TEXT = Color("edf1f6")
const MUTED = Color("b6c0cd")
const SELECTED = Color("a2d8c0")
const TOOL = SELECTED
const KEY = Color("e8d29d")
const CONTROL_GAP = 8
const TOOLBAR_INSET = 8
const PROPERTY_GAP = 12
const PATHS = {
	"end":"M19 4v16M5 4l12 8-12 8z",
	"trim_time":"M6 3v18M18 3v18M3 7h18M3 17h18M10 10l4 2-4 2",
	"stretch_time":"M3 6v12M21 6v12M4 12h16M8 8l-4 4 4 4M16 8l4 4-4 4",
	"properties":"M4 7h16M4 17h16M8 4v6m8 4v6", "add":"M12 5v14M5 12h14",
	"library":"M3 6h6l2 2h10v11H3z", "market":"M3 9h18l-2-6H5zM4 9v12h16V9M9 21v-7h6v7M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0",
	"scenes":"m12 3 10 5-10 5L2 8zm-10 9 10 5 10-5M2 16l10 5 10-5",
	"camera":"M3 7h11v13H3zM14 11l7-4v12l-7-4M6 3h5v4", "color":"M12 3a9 9 0 0 0 0 18h2a2 2 0 0 0 1-4 2 2 0 0 1 1-4h3a3 3 0 0 0 2-3A9 9 0 0 0 12 3zM6 11h.01M9 7h.01M14 6h.01M18 9h.01",
	"cube":"m12 3 9 5v9l-9 5-9-5V8zm0 9v10M3 8l9 4 9-4", "image":"M3 4h18v16H3zM3 16l5-5 5 5 3-3 5 5M16 8h.01",
	"light":"M9 17h6m-5 4h4M8 12a5 5 0 1 1 8 0l-1 3H9z", "globe":"M22 12A10 10 0 1 1 2 12a10 10 0 0 1 20 0M2 12h20M12 2a18 18 0 0 1 0 20 18 18 0 0 1 0-20", "minimize":"M4 12h16", "maximize":"M5 5h14v14H5z", "close":"m5 5 14 14M5 19 19 5",
	"move":"M12 2v20M2 12h20M8 6l4-4 4 4M6 8l-4 4 4 4m12-8 4 4-4 4m-10 2 4 4 4-4",
	"rotate":"M4 10a8 8 0 1 1 2 8M4 4v6h6", "scale":"M4 10V4h6m10 10v6h-6M4 4l6 6m10 10-6-6",
	"select":"M5 3v17l5-5 4 7 3-2-4-7 7-2z", "eye":"M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zm13 0a3 3 0 1 0-6 0 3 3 0 0 0 6 0", "eye_off":"M3 3l18 18M2 12s4-7 10-7c6 0 10 7 10 7s-1 2-3 4M6 6C3 8 2 12 2 12s4 7 10 7c2 0 3 0 5-1", "lock":"M6 10h12v11H6zM8 10V6a4 4 0 0 1 8 0v4", "unlock":"M6 10h12v11H6zM8 10V6a4 4 0 0 1 8 0", "chevron":"m8 5 7 7-7 7", "down":"m5 8 7 7 7-7", "key":"m12 4 8 8-8 8-8-8z", "play":"m7 3 14 9L7 21z", "pause":"M7 3v18M17 3v18", "reset":"M5 4v16M19 4 7 12l12 8z", "fit":"M4 9V4h5m6 0h5v5M4 15v5h5m6 0h5v-5", "undo":"m8 5-5 5 5 5M3 10h11a6 6 0 0 1 0 12", "redo":"m16 5 5 5-5 5M21 10H10a6 6 0 0 0 0 12", "save":"M4 3h14l3 3v15H3V3zm3 0v7h10V3M7 21v-7h10v7", "more":"M4 12h.01M12 12h.01M20 12h.01", "transition":"M2 6h5l10 12h5M2 18h5l10-12h5", "loop":"M4 7h14l-4-4m4 4-4 4M20 17H6l4 4m-4-4 4-4", "loop_off":"M4 7h14l-4-4m4 4-4 4M20 17H6l4 4m-4-4 4-4M4 4l16 16", "info":"M12 11v6m0-10h.01M22 12A10 10 0 1 1 2 12a10 10 0 0 1 20 0"
}
static var icons: Dictionary = {}
static func icon(key: String, dimension := 24) -> Texture2D:
	var cache_key=key+str(dimension)
	if icons.has(cache_key): return icons[cache_key]
	var image = Image.new()
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="#dedede" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>' % [dimension,dimension,PATHS.get(key, PATHS.cube)]
	if image.load_svg_from_string(svg) != OK: return null
	icons[cache_key] = ImageTexture.create_from_image(image)
	return icons[cache_key]
static func box(color: Color, border: Color = BORDER, radius: int = 5, margin: int = 8) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color; style.border_color = border
	style.set_border_width_all(1); style.set_corner_radius_all(radius)
	style.content_margin_left = margin; style.content_margin_right = margin
	style.content_margin_top = 6; style.content_margin_bottom = 6
	return style
static func plain(color: Color = PANEL, margin: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(color,color,0,margin)
	style.set_border_width_all(0); style.content_margin_top = 0; style.content_margin_bottom = 0
	return style
static func floating() -> StyleBoxFlat:
	var style: StyleBoxFlat = box(PANEL,BORDER,7,10)
	style.content_margin_top = 10; style.content_margin_bottom = 10
	style.shadow_size = 14; style.shadow_offset = Vector2(0,5); style.shadow_color = Color(0,0,0,.42)
	return style
static func framed_panel() -> StyleBoxFlat:
	var style: StyleBoxFlat=box(BACKGROUND,BORDER,6,TOOLBAR_INSET)
	style.content_margin_top=TOOLBAR_INSET; style.content_margin_bottom=TOOLBAR_INSET
	return style
static func configure_icon_button(field: Button, key: String, dimension: int = 20) -> Button:
	field.icon = icon(key,dimension); field.text = ""; field.accessibility_name = field.tooltip_text
	field.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER; field.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	field.expand_icon = true; field.add_theme_constant_override("icon_max_width",dimension)
	field.custom_minimum_size = Vector2(34,34)
	return field
static func apply(field: Control, variant: String) -> void: field.theme_type_variation = variant
static func make() -> Theme:
	var theme: Theme = Theme.new(); var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Microsoft YaHei UI","Microsoft YaHei"])
	theme.default_font = font; theme.default_font_size = 14
	var bold: SystemFont = SystemFont.new(); bold.font_names = font.font_names; bold.font_weight = 600
	theme.set_type_variation("Heading","Label"); theme.set_font("font","Heading",bold)
	theme.set_font("font","SectionButton",bold)
	for kind: String in ["Button","MenuButton","OptionButton"]:
		for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var color: Color = SURFACE if state == "normal" else Color("394655") if state == "hover" else Color("344e47") if state in ["pressed","hover_pressed"] else Color("222932")
			var style: StyleBoxFlat = box(color,SELECTED if state == "focus" else BORDER)
			if state == "focus": style.draw_center = false
			theme.set_stylebox(state,kind,style)
		theme.set_color("font_color",kind,TEXT); theme.set_color("font_hover_color",kind,TEXT)
		theme.set_color("font_pressed_color",kind,TEXT); theme.set_color("font_disabled_color",kind,Color("85919f"))
		theme.set_color("icon_normal_color",kind,TEXT); theme.set_color("icon_hover_color",kind,TEXT)
		theme.set_color("icon_disabled_color",kind,Color("85919f")); theme.set_constant("h_separation",kind,8)
	for kind: String in ["ToolButton","RailButton","TabButton","SegmentButton","PrimaryButton","SectionButton","StageToolButton","TopbarButton"]:
		theme.set_type_variation(kind,"Button")
		for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var active: bool = state in ["pressed","hover_pressed"] or (kind=="PrimaryButton" and state!="disabled")
			var color: Color = Color("344e47") if active else Color("35404e") if state == "hover" else PANEL
			if kind=="PrimaryButton" and state in ["hover","hover_pressed"]: color=Color("405f54")
			var style: StyleBoxFlat = box(color,SELECTED if state == "focus" or active else BORDER,5,8)
			if kind in ["TopbarButton","SectionButton"]:
				style = plain(Color("35404e") if state == "hover" or active else Color.TRANSPARENT,10)
				style.content_margin_top = 6; style.content_margin_bottom = 6
				if state == "focus": style.draw_center = false; style.border_color = SELECTED; style.set_border_width_all(1)
			elif state == "focus": style.draw_center = false
			if kind == "TabButton" and active: style.border_color = SELECTED; style.border_width_bottom = 2
			theme.set_stylebox(state,kind,style)
		theme.set_color("icon_pressed_color",kind,TOOL)
	for state: String in ["normal","pressed","disabled","hover","hover_pressed"]: theme.set_stylebox(state,"CheckButton",plain(Color.TRANSPARENT))
	theme.set_stylebox("focus","CheckButton",box(Color.TRANSPARENT,SELECTED,4,2))
	for state: String in ["normal","read_only","focus"]:
		theme.set_stylebox(state,"LineEdit",box(FIELD,SELECTED if state == "focus" else BORDER,4,7))
	theme.set_color("font_color","LineEdit",TEXT); theme.set_color("font_placeholder_color","LineEdit",MUTED)
	theme.set_color("font_color","Label",TEXT)
	theme.set_constant("buttons_width","SpinBox",0); theme.set_constant("set_min_buttons_width_from_icons","SpinBox",0)
	theme.set_constant("field_and_buttons_separation","SpinBox",0)
	var empty: ImageTexture = ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
	for key: String in ["updown","up","up_hover","up_pressed","up_disabled","down","down_hover","down_pressed","down_disabled"]: theme.set_icon(key,"SpinBox",empty)
	theme.set_stylebox("panel","PanelContainer",box(PANEL,BORDER,5,0))
	for kind: String in ["AcceptDialog","PopupMenu","PopupPanel","TooltipPanel"]: theme.set_stylebox("panel",kind,floating())
	theme.set_font_size("font_size","PopupMenu",14); theme.set_constant("v_separation","PopupMenu",10)
	theme.set_stylebox("hover","PopupMenu",box(Color("344e47"),Color("344e47"),4,6))
	for kind: String in ["ItemList","Tree"]:
		theme.set_stylebox("panel",kind,plain(PANEL))
		for state: String in ["selected","selected_focus"]: theme.set_stylebox(state,kind,box(Color("344e47"),Color("496e62"),3,4))
		theme.set_color("font_selected_color",kind,TEXT); theme.set_color("font_color",kind,TEXT)
	theme.set_constant("v_separation","Tree",5); theme.set_constant("h_separation","Tree",10)
	theme.set_constant("icon_max_width","Tree",18); theme.set_constant("draw_guides","Tree",0)
	theme.set_constant("draw_relationship_lines","Tree",0); theme.set_constant("button_margin","Tree",6)
	theme.set_stylebox("button_hover","Tree",box(SURFACE,BORDER)); theme.set_stylebox("button_pressed","Tree",box(SURFACE,SELECTED))
	for kind: String in ["VBoxContainer","HBoxContainer"]: theme.set_constant("separation",kind,8)
	for kind: String in ["SplitContainer","HSplitContainer","VSplitContainer"]:
		theme.set_constant("separation",kind,6); theme.set_constant("minimum_grab_thickness",kind,8)
		for key: String in ["grabber","h_grabber","v_grabber"]: theme.set_icon(key,kind,empty)
		theme.set_stylebox("split_bar_background",kind,plain(BACKGROUND))
	for kind: String in ["HScrollBar","VScrollBar"]:
		theme.set_stylebox("scroll",kind,plain(FIELD))
		for state: String in ["grabber","grabber_highlight","grabber_pressed"]:
			theme.set_stylebox(state,kind,box(Color("647384") if state == "grabber" else Color("8ba191"),Color.TRANSPARENT,4,0))
	var track: StyleBoxFlat = plain(Color("4c5968")); track.content_margin_top = 2; track.content_margin_bottom = 2
	theme.set_stylebox("slider","HSlider",track); theme.set_stylebox("grabber_area","HSlider",plain(TOOL))
	theme.set_stylebox("grabber_area_highlight","HSlider",plain(SELECTED))
	var border: StyleBoxFlat = floating(); border.content_margin_top = 34
	theme.set_stylebox("embedded_border","Window",border); theme.set_stylebox("embedded_unfocused_border","Window",border)
	theme.set_color("title_color","Window",TEXT)
	return theme
