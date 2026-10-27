extends SceneTree

const Contract = preload("res://adapters/godot/style_contract.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var input := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bundle="): input = arg.trim_prefix("--bundle=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var bundle = JSON.parse_string(FileAccess.get_file_as_string(input))
	if not bundle is Dictionary or output.is_empty():
		push_error("生成输入不可用")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for id in bundle.profiles:
		var profile: Dictionary = bundle.profiles[id]
		var data: Dictionary = profile.godot
		var face := load(data.font.file) as FontFile
		if face == null:
			push_error("无法加载共同字库")
			quit(2)
			return
		# 外部字库不承载临时属性覆盖；缺字允许系统补字，并在排版检查中追踪真实来源。
		face.allow_system_fallback = true
		var fonts: Array[Font] = []
		for weight in [data.font.regular_weight,data.font.heading_weight]:
			var fallback := SystemFont.new()
			fallback.font_names = PackedStringArray(data.font.fallbacks)
			fallback.allow_system_fallback = true
			var font := FontVariation.new()
			font.base_font = face
			font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):float(weight)}
			font.fallbacks = [fallback]
			fonts.append(font)
		for mode in ["light","dark"]:
			var c := Contract.build(data,mode,profile.accent,fonts[0],fonts[1])
			var theme := Theme.new()
			theme.default_font = c.font
			theme.default_font_size = c.font_size
			for name in c.bases: theme.set_type_variation(name,c.bases[name])
			for name in c.styles:
				for key in c.styles[name]:
					var value = c.styles[name][key]
					var dtype := Theme.DATA_TYPE_COLOR
					if value is Dictionary:
						value = Contract.make_box(value)
						dtype = Theme.DATA_TYPE_STYLEBOX
					elif value is Font: dtype = Theme.DATA_TYPE_FONT
					elif value is Texture2D: dtype = Theme.DATA_TYPE_ICON
					elif value is int: dtype = Theme.DATA_TYPE_FONT_SIZE if key.ends_with("font_size") else Theme.DATA_TYPE_CONSTANT
					theme.set_theme_item(dtype,key,name,value)
			if ResourceSaver.save(theme,output.path_join(id+"_"+mode+".tres")) != OK:
				push_error("原生主题保存失败")
				quit(2)
				return
	print("GENERATED ",bundle.profiles.size()*2," native themes")
	quit()
