extends "res://adapters/godot/observe_management_states.gd"

var checks:Array=[]

func check(name: String, passed: bool, detail: Variant=null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	if not passed:print("FAIL ",name," ",detail)

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/typography.tscn").instantiate()
	root.add_child(app)
	root.grab_focus()
	await wait(0.6)
	if not app.initialized:quit(1);return
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://sample/typography-review.json"))
	for scenario in contract.cases:
		root.size=Vector2i(scenario.context.viewport[0],scenario.context.viewport[1])
		await wait(0.1)
		for action_value in scenario.actions:
			var parts:PackedStringArray=action_value.split(":")
			if parts[0]=="text":await input_text(app.input,action_value.trim_prefix("text:draft:"))
			else:
				var target:Button=app.group_buttons[parts[2]] if parts[1]=="group" else (app.mode_button if parts[1]=="mode" else (app.scale_button if parts[1]=="scale" else app.fallback_button))
				await pointer(target.get_global_rect().get_center())
		await wait(0.5)
		RenderingServer.force_draw()
		var measured:Dictionary=app.observe()
		var samples:Array=[]
		for c in measured.cases:
			samples.append({"id":c.id,"role":c.role,"weight":c.weight,"text":c.text})
			var specification:Dictionary=app.fixture.cases.filter(func(x):return x.id==c.id)[0]
			check(scenario.id+"/glyphs/"+c.id,not c.shaped.missing.is_empty() if specification.get("expected_missing",false) else c.shaped.missing.is_empty(),c.shaped.missing)
			check(scenario.id+"/size/"+c.id,c.font_size==roundi(float(app.roles.font[c.role])*float(scenario.context.text_scale)),c.font_size)
			check(scenario.id+"/vertical/"+c.id,c.rect[3]>=c.line_count*c.line_height-1,{"height":c.rect[3],"lines":c.line_count,"line_height":c.line_height})
			if not measured.fallback:
				for glyph in c.shaped.glyphs:
					if glyph.font.begins_with("Resource Han Rounded"):
						check(scenario.id+"/weight/"+c.id,float(glyph.axes.get(str(2003265652),glyph.axes.get(2003265652,0)))==float(c.weight),glyph.axes)
		if measured.group=="mixed":check(scenario.id+"/tabular",measured.digit_widths.all(func(v):return is_equal_approx(v,measured.digit_widths[0])),measured.digit_widths)
		check(scenario.id+"/input-size",measured.input_font_size==roundi(float(app.roles.font.body)*float(scenario.context.text_scale)),measured.input_font_size)
		if measured.group=="mixed":
			for sample in measured.data_samples:
				check(scenario.id+"/data-size/"+sample.text,sample.font_size==roundi(float(app.roles.font.body)*float(scenario.context.text_scale)),sample.font_size)
				if not measured.fallback:
					var correct:bool=sample.shaped.glyphs.all(func(g):return float(g.axes.get(str(2003265652),g.axes.get(2003265652,0)))==float(app.roles.font.regular_weight))
					check(scenario.id+"/data-weight/"+sample.text,correct,sample.shaped.glyphs.map(func(g):return g.axes))
		var overflow:bool=app.workspace.get_global_rect().end.x>root.size.x+1
		check(scenario.id+"/horizontal",not overflow,app.workspace.get_global_rect())
		var screenshot:String="evidence/typography-"+phase+"-godot-"+scenario.id+".png"
		root.get_texture().get_image().save_png("res://"+screenshot)
		cases.append({"id":scenario.id,"actions":scenario.actions,"context":{"build_id":app.manifest.build_id,"fixture":FileAccess.get_sha256("res://sample/typography.json"),"viewport":measured.viewport,"theme":measured.theme,"text_scale":measured.text_scale},"observed":{"group":measured.group,"fallback":measured.fallback,"primary_loaded":measured.primary_loaded,"draft":measured.draft,"samples":samples,"horizontal_overflow":overflow,"raw":measured},"screenshot":screenshot})
	var file:=FileAccess.open("res://evidence/typography-"+phase+"-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"godot","evidence_root":"..","input_driver":"Input.parse_input_event","implementation_sha256":FileAccess.get_sha256("res://adapters/godot/typography.gd"),"adapter_sha256":FileAccess.get_sha256("res://adapters/godot/verify_typography.gd"),"cases":cases,"checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	print("FONT CHECKPOINTS ",cases.size()," checks ",checks.size()," failures ",checks.filter(func(c):return not c.passed).size())
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
