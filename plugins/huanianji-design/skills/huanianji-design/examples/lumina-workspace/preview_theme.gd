extends RefCounted

const FONT = preload("res://fonts/ResourceHanRoundedCN-VF.otf")
const SOURCE_ICONS = preload("res://source_icons.gd")
const PAGE_INSET = 24
const PANEL_INSET = 24
const GROUP_GAP = 16
const FIELD_GAP = 8
static var colors: Dictionary
static var ui_scale := 1.0

static func box(fill: Color, edge: Color, radius := 8, inset := 12, asymmetric := true) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color=fill; b.border_color=edge; b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	if asymmetric: b.corner_radius_top_right=roundi(radius*1.6)
	b.content_margin_left=inset; b.content_margin_right=inset
	b.content_margin_top=8; b.content_margin_bottom=8
	return b

static func panel(inset := PANEL_INSET, radius := 14) -> StyleBoxFlat:
	var style:=box(colors.panel,colors.border,radius,inset)
	# 面板安全区覆盖四边；控件自身的紧凑内距不承担面板留白。
	style.content_margin_top=inset;style.content_margin_bottom=inset
	return style

static func stepper_icon(up: bool, tint: Color) -> Texture2D:
	var path:String=SOURCE_ICONS.PATHS.down
	var transform:="rotate(180 12 12)" if up else ""
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24"><path d="%s" transform="%s" fill="none" stroke="#%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'%[path,transform,tint.to_html(false)]
	var image:=Image.new();image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

static func make(dark: bool, large: bool) -> Theme:
	ui_scale=1.25 if large else 1.0
	colors={"bg":Color("171819"),"panel":Color("222325"),"surface":Color("2b2d30"),"field":Color("1c1d1f"),"border":Color("3a3c40"),"text":Color("f0f0ef"),"muted":Color("b0b2b6"),"accent":Color("b1d8c2"),"wash":Color("35463e"),"on_accent":Color("1d3026"),"grid":Color("3d4143")}
	if not dark:
		colors={"bg":Color("ededee"),"panel":Color("fafafa"),"surface":Color("f0f0f1"),"field":Color("ffffff"),"border":Color("d5d6d9"),"text":Color("242629"),"muted":Color("64686e"),"accent":Color("376c52"),"wash":Color("e0ece5"),"on_accent":Color("ffffff"),"grid":Color("d3d5d7")}
	var body_font:=FontVariation.new();body_font.base_font=FONT
	body_font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):400.0}
	var t:=Theme.new(); t.default_font=body_font; t.default_font_size=roundi(14*ui_scale)
	for type in ["Label","Button","LineEdit","TextEdit","CheckBox","PopupMenu","SpinBox"]:
		t.set_font("font",type,body_font)
		t.set_font_size("font_size",type,roundi(14*ui_scale))
		t.set_color("font_color",type,colors.text)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var bg:Color=colors.field if state=="normal" else colors.surface
		var edge:Color=colors.border
		if state in ["pressed","hover_pressed"]: bg=colors.wash; edge=colors.accent
		t.set_stylebox(state,"Button",box(bg,edge,8))
		t.set_color("font_"+state+"_color","Button",colors.muted if state=="disabled" else colors.text)
		t.set_color("icon_"+state+"_color","Button",colors.muted if state=="disabled" else colors.text)
	t.set_color("font_hover_color","Button",colors.text); t.set_color("font_pressed_color","Button",colors.accent)
	t.set_color("icon_pressed_color","Button",colors.accent)
	t.set_constant("h_separation","Button",8)
	var focus:=box(Color(0,0,0,0),colors.accent,8); focus.set_border_width_all(2)
	t.set_stylebox("focus","Button",focus)
	for variant in ["Quiet","TabButton","Tool","Primary","Section","KeyframeButton"]:
		t.set_type_variation(variant,"Button")
		var normal:=box(Color(0,0,0,0),Color(0,0,0,0),6)
		if variant=="Primary": normal=box(colors.accent,colors.accent,10)
		t.set_stylebox("normal",variant,normal)
		t.set_stylebox("hover",variant,box(colors.surface,colors.border,6))
		t.set_stylebox("pressed",variant,box(colors.wash,colors.accent,6))
		t.set_stylebox("hover_pressed",variant,box(colors.wash,colors.accent,6))
		if variant=="Primary":
			t.set_color("font_color",variant,colors.on_accent); t.set_color("icon_normal_color",variant,colors.on_accent)
			t.set_stylebox("hover",variant,box(colors.accent.lightened(.07),colors.accent,10))
			t.set_color("font_hover_color",variant,colors.on_accent); t.set_color("icon_hover_color",variant,colors.on_accent)
		if variant=="TabButton":
			for state in ["normal","hover","pressed","hover_pressed"]:
				t.set_stylebox(state,variant,box(Color(0,0,0,0),Color(0,0,0,0),6))
		if variant in ["Tool","KeyframeButton"]:
			# 图标工具只在悬停时露出承载框，禁用和选中不继承普通按钮的底板。
			for state in ["normal","pressed","disabled"]:t.set_stylebox(state,variant,normal)
			t.set_stylebox("hover_pressed",variant,box(colors.surface,colors.border,6))
			t.set_color("icon_pressed_color",variant,colors.accent)
			t.set_color("icon_hover_pressed_color",variant,colors.accent)
		if variant=="Section":
			t.set_stylebox("normal",variant,normal)
			t.set_stylebox("hover",variant,box(colors.surface,Color(0,0,0,0),6))
	for type in ["LineEdit","TextEdit"]:
		t.set_stylebox("normal",type,box(colors.field,colors.border,6))
		t.set_stylebox("focus",type,box(colors.field,colors.accent,6))
		t.set_color("caret_color",type,colors.accent)
		t.set_color("selection_color",type,colors.wash)
		t.set_color("font_selected_color",type,colors.text)
	# Godot默认数值箭头偏浅；两种背景都明确消费当前主题的可读颜色。
	for direction in ["up","down"]:
		for state in ["","_hover","_pressed","_disabled"]:
			t.set_icon(direction+state,"SpinBox",stepper_icon(direction=="up",colors.accent if state in ["_hover","_pressed"] else colors.muted))
	var track:=box(colors.border,colors.border,2,0,false); track.content_margin_top=2; track.content_margin_bottom=2
	for type in ["HSlider","HScrollBar","VScrollBar"]:
		t.set_stylebox("slider",type,track)
		t.set_stylebox("scroll",type,track)
		t.set_stylebox("scroll_focus",type,track)
		t.set_stylebox("grabber_area",type,box(colors.accent,colors.accent,2,0,false))
		t.set_stylebox("grabber_area_highlight",type,box(colors.accent,colors.accent,2,0,false))
	t.set_stylebox("panel","PanelContainer",box(colors.panel,colors.border,14,16))
	return t

static func label_role(label: Label, size: int, muted := false, strong := false, data := false) -> void:
	label.add_theme_font_size_override("font_size",roundi(size*ui_scale))
	label.add_theme_color_override("font_color",colors.muted if muted else colors.text)
	if strong or data:
		var variation:=FontVariation.new(); variation.base_font=FONT
		variation.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):600.0 if strong else 400.0}
		if data: variation.opentype_features={"tnum":1}
		label.add_theme_font_override("font",variation)
