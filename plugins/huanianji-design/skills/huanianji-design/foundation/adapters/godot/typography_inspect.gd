extends RefCounted

static func shape(text: String, font: Font, size: int=17) -> Dictionary:
	var server:=TextServerManager.get_primary_interface()
	var line:=TextLine.new()
	line.add_string(text,font,size)
	var glyphs:Array=[]
	var missing:Array=[]
	for g in server.shaped_text_get_glyphs(line.get_rid()):
		var rid:RID=g.font_rid
		var family:=server.font_get_name(rid) if rid.is_valid() else ""
		var cluster:=text.substr(g.start,g.end-g.start)
		var absent:bool=(not rid.is_valid() or g.index==0 or family.to_lower().contains("lastresort")) and not cluster.strip_edges().is_empty()
		var item:={"start":g.start,"end":g.end,"index":g.index,"flags":g.flags,"font":family,"style":server.font_get_style_name(rid) if rid.is_valid() else "","missing":absent,"axes":server.font_get_variation_coordinates(rid) if rid.is_valid() else {}}
		glyphs.append(item)
		if absent:missing.append(cluster)
	return {"text":text,"size":[line.get_size().x,line.get_size().y],"glyphs":glyphs,"missing":missing}
