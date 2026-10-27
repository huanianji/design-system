extends "res://adapters/godot/observe_management_states.gd"

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/typography.tscn").instantiate()
	root.add_child(app)
	root.grab_focus()
	await wait(0.6)
	var daily:Dictionary=app.observe()
	var no_missing:bool=daily.cases.all(func(c):return c.shaped.missing.is_empty())
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://evidence/typography-missing-godot.png")
	var passed:bool=not daily.primary_loaded and daily.font_status=="主字库未加载，当前显示系统回退。" and no_missing
	var file:=FileAccess.open("res://evidence/typography-missing-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"setup":"--missing-font；读取不存在的诊断字库路径，未删除真实字体文件","actual":daily,"screenshot":"evidence/typography-missing-godot.png"},"\t"))
	print("MISSING FONT REPORTED AND READABLE ",passed)
	app.queue_free()
	await process_frame
	quit(0 if passed else 1)
