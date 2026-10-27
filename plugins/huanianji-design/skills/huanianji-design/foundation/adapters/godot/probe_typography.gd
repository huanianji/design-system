extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shaped(text: String, font: Font, size: int=17) -> Dictionary:
	var server:=TextServerManager.get_primary_interface()
	var line:=TextLine.new()
	line.add_string(text,font,size)
	var glyphs:Array=[]
	for g in server.shaped_text_get_glyphs(line.get_rid()):
		var rid:RID=g.font_rid
		glyphs.append({"start":g.start,"end":g.end,"index":g.index,"flags":g.flags,"valid_font":rid.is_valid(),"font":server.font_get_name(rid) if rid.is_valid() else "","axes":server.font_get_variation_coordinates(rid) if rid.is_valid() else {}})
	return {"text":text,"size":[line.get_size().x,line.get_size().y],"glyphs":glyphs}

func run() -> void:
	var phase:="before"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/manifest.json"))
	var theme:Theme=load("res://"+manifest.bundle+"/themes/management_light.tres")
	var font:Font=theme.default_font
	var primary:FontFile=load("res://assets/fonts/ResourceHanRoundedCN-VF.otf")
	var chars:Array=[]
	for ch in "华年集共光影白宝米鹿工坊绮霁婧喆槿鹤㐀㐂㑇𠮷𠮶𡈽𩸽𪚥𫠠𰻞𱻀éÇé가한별한별あア🙂🚀":
		chars.append({"char":ch,"codepoint":ch.unicode_at(0),"primary":primary.has_char(ch.unicode_at(0)),"configured_chain":font.has_char(ch.unicode_at(0))})
	var cases:Array=[]
	for text in ["华年集 · 米鹿工坊 Live 2026","0123456789 / 19:30—22:00 / ￥1,234.56","𠮷野家 / 𠮶 / 𰻞 / 𱻀","👩🏽‍💻 🚀 🇨🇳 é","한별 Nana 七海あおい",String.chr(0x10ffff)]:cases.append(shaped(text,font))
	var system_fonts:Array=[]
	var available:=OS.get_system_fonts()
	for name in ["PingFang SC","Heiti SC","Songti SC","Arial Unicode MS","Apple Color Emoji","Microsoft YaHei","Segoe UI Emoji","Noto Sans CJK SC"]:
		if available.has(name):
			var sys:=SystemFont.new()
			sys.font_names=PackedStringArray([name])
			sys.allow_system_fallback=false
			var feature_trials:Array=[]
			for setting in [{},{TextServerManager.get_primary_interface().name_to_tag("tnum"):1},{"tnum":1}]:
				var variant:=FontVariation.new()
				variant.base_font=sys
				variant.opentype_features=setting
				var widths:Array=[]
				for digit in "0123456789":widths.append(variant.get_string_size(digit,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x)
				feature_trials.append({"setting":setting,"widths":widths})
			system_fonts.append({"requested":name,"actual":sys.get_font_name(),"path":OS.get_system_font_path(name),"features":TextServerManager.get_primary_interface().font_supported_feature_list(sys.get_rids()[0]),"feature_trials":feature_trials,"coverage":chars.map(func(c):return {"char":c.char,"supported":sys.has_char(c.codepoint)})})
	var digit_widths:Array=[]
	for digit in "0123456789":digit_widths.append(font.get_string_size(digit,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x)
	var coverage_sets:Dictionary={}
	var corpus:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://sample/typography-coverage.json"))
	for id in corpus.sets:
		var missing:Array=[]
		for ch in corpus.sets[id]:
			if not primary.has_char(ch.unicode_at(0)):missing.append({"char":ch,"codepoint":ch.unicode_at(0)})
		coverage_sets[id]={"total":str(corpus.sets[id]).length(),"covered":str(corpus.sets[id]).length()-missing.size(),"missing":missing}
	var out:={"build_id":manifest.build_id,"primary":{"family":primary.get_font_name(),"sha256":FileAccess.get_sha256("res://assets/fonts/ResourceHanRoundedCN-VF.otf"),"supported_char_count":primary.get_supported_chars().length(),"allow_system_fallback":primary.allow_system_fallback,"axes":primary.get_supported_variation_list()},"chars":chars,"cases":cases,"heading":shaped("华年集 Aa 0123",theme.get_font("font","Heading"),28),"digit_widths":digit_widths,"system_fonts":system_fonts}
	out["coverage_sets"]=coverage_sets
	out["configured_fallbacks"]=font.fallbacks.map(func(f):return {"family":f.get_font_name(),"allow_system_fallback":f.allow_system_fallback})
	var file:=FileAccess.open("res://evidence/typography-probe-"+phase+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(out,"\t"))
	print("PRIMARY ",out.primary.family," supported chars ",out.primary.supported_char_count)
	for c in chars:
		if not c.primary:print("FALLBACK ",c.char," => ",c.configured_chain)
	print("DIGITS ",digit_widths)
	quit()
