extends "res://adapters/godot/observe_management_states.gd"

var checks: Array=[]
var frames: Array=[]

func record(id: String, passed: bool, observed: Dictionary, actions: Array) -> void:
	RenderingServer.force_draw()
	var path:="evidence/controls-"+id+"-godot.png"
	root.get_texture().get_image().save_png("res://"+path)
	checks.append({"id":id,"passed":passed,"observed":observed,"actions":actions,"screenshot":path})
	print("PASS " if passed else "FAIL ",id," ",JSON.stringify(observed))

func observe() -> Dictionary:
	var focus:=root.gui_get_focus_owner()
	return {"focus_owner_visible":focus.has_focus(true) if focus else false,"logical_focus":app.parts.action.target.has_focus(),"focus_visible":app.parts.action.target.has_focus(true),"viewport":[root.size.x,root.size.y],"settings_are_state_buttons":[app.fail_next,app.disable_tab,app.disable_all].all(func(item): return item is Button and not item is CheckBox and item.toggle_mode),"settings":[app.fail_next.button_pressed,app.disable_tab.button_pressed,app.disable_all.button_pressed],"attempts":app.attempts,"busy":app.parts.action.busy,"disabled":app.parts.action.target.disabled,"result":app.result.text,"tab":app.parts.tabs.selected,"keyboard_stops":app.parts.buttons.map(func(b): return b.focus_mode==Control.FOCUS_ALL and not b.disabled),"open":app.parts.reveal.open,"height":app.parts.region.custom_minimum_size.y,"target":app.parts.reveal.target,"draft":app.parts.draft.text,"focus":str(focus.name) if focus else "","mode":app.mode,"reduced":app.reduced,"mounts":app.mounts}

func run() -> void:
	root.size=Vector2i(1280,960)
	app=load("res://sample/controls.tscn").instantiate()
	root.add_child(app)
	root.grab_focus()
	await wait(0.4)
	if not app.get("parts") is Dictionary or app.get("parts").is_empty():
		push_error("公共检查台初始化失败，请检查上方编译/运行诊断")
		quit(2)
		return
	var action_button:Button=app.parts.action.target
	await pointer(action_button.get_global_rect().get_center())
	await pointer(action_button.get_global_rect().get_center())
	var state:=observe()
	record("busy-blocks-repeat",state.busy and state.disabled and state.attempts==1,state,["pointer:action","pointer:action-during-busy"])
	await wait(0.75)
	state=observe()
	record("action-completes",not state.busy and not state.disabled and state.result=="本地操作完成" and not state.focus_visible,state,["wait:local-result"])
	var count:int=app.attempts
	await pointer(app.group.find_child("DisabledAction",true,false).get_global_rect().get_center())
	record("disabled-blocks-activation",app.attempts==count and observe().focus!="DisabledAction",observe(),["pointer:disabled-action"])
	await pointer(app.fail_next.get_global_rect().get_center())
	await pointer(action_button.get_global_rect().get_center())
	await wait(0.75)
	state=observe()
	record("failure-unlocks-retry",not state.busy and not state.disabled and state.result=="本地模拟失败，可重试" and not state.focus_visible,state,["pointer:fail-next","pointer:action","wait:local-result"])
	await pointer(app.fail_next.get_global_rect().get_center())
	# 实际鼠标定位后，通过键盘 Space 执行下一次操作。
	action_button.grab_focus()
	await key(KEY_SPACE)
	await wait(0.75)
	state=observe()
	record("keyboard-retry",state.attempts==3 and state.result=="本地操作完成" and state.focus_visible,state,["condition:action-focus","key:Space","wait:local-result"])
	await pointer(app.parts.buttons[1].get_global_rect().get_center())
	await key(KEY_HOME)
	await pointer(app.disable_tab.get_global_rect().get_center())
	await pointer(app.parts.buttons[0].get_global_rect().get_center())
	await key(KEY_RIGHT)
	state=observe()
	record("tabs-skip-disabled",state.tab==2 and state.focus=="LabTab2",state,["pointer:tab1","key:Home","pointer:disable-tab","pointer:tab0","key:ArrowRight"])
	await key(KEY_HOME)
	await key(KEY_TAB)
	state=observe()
	record("tabs-single-stop",state.focus=="LabToggle",state,["key:Home","key:Tab"])
	await key(KEY_SPACE)
	await wait(0.07)
	var h:float=app.parts.region.custom_minimum_size.y
	await pointer(app.parts.trigger.get_global_rect().get_center())
	await wait(0.04)
	state=observe()
	record("disclosure-reverses",not state.open and h>0 and state.height>0,state,["key:Space","wait:70ms","pointer:toggle","wait:40ms"])
	await pointer(app.find_child("Mode",true,false).get_global_rect().get_center())
	await wait(0.55)
	state=observe()
	record("theme-during-collapse",state.mode=="dark" and not state.open and is_zero_approx(state.height),state,["pointer:mode","wait:settled"])
	await pointer(app.parts.trigger.get_global_rect().get_center())
	await wait(0.04)
	await pointer(app.find_child("Reduce",true,false).get_global_rect().get_center())
	state=observe()
	record("reduce-settles-disclosure",state.reduced and state.open and is_equal_approx(state.height,state.target),state,["pointer:toggle","pointer:reduce"])
	await pointer(app.parts.draft.get_global_rect().get_center())
	await key(KEY_ESCAPE)
	await wait(0.55)
	state=observe()
	record("collapse-restores-focus",state.focus=="LabToggle" and state.draft=="保留这份草稿" and app.parts.draft.focus_mode==Control.FOCUS_NONE,state,["pointer:local-draft","key:Escape","wait:settled"])
	await pointer(action_button.get_global_rect().get_center())
	await pointer(app.find_child("Remount",true,false).get_global_rect().get_center())
	await wait(0.8)
	state=observe()
	record("unmount-cancels-old-result",state.mounts==2 and not state.busy and state.result=="已重建，旧操作已取消",state,["pointer:action","pointer:remount","wait:old-result-window"])
	await pointer(app.parts.action.target.get_global_rect().get_center())
	await wait(0.75)
	state=observe()
	record("remount-no-duplicate-handlers",state.attempts==5 and state.result=="本地操作完成",state,["pointer:action","wait:local-result"])
	await pointer(app.disable_all.get_global_rect().get_center())
	state=observe()
	record("tabs-all-disabled",state.tab==-1,state,["pointer:disable-all"])
	await pointer(app.disable_all.get_global_rect().get_center())
	state=observe()
	record("tabs-reenable",state.tab==0 and state.keyboard_stops==[true,false,false],state,["pointer:enable-tabs"])
	# 当前仍是减少动态；先恢复日常反馈，再验证两个实例互不抢占。
	await pointer(app.find_child("Reduce",true,false).get_global_rect().get_center())
	var one:Button=app.group.find_child("ButtonOne",true,false)
	var two:Button=app.group.find_child("ButtonTwo",true,false)
	await pointer(one.get_global_rect().get_center())
	await pointer(two.get_global_rect().get_center())
	state=observe()
	state.parallel_press=not one.offset_transform_scale.is_equal_approx(Vector2.ONE) and not two.offset_transform_scale.is_equal_approx(Vector2.ONE)
	state.press_samples=[one.offset_transform_scale.x,two.offset_transform_scale.x]
	record("independent-button-feedback",state.parallel_press,state,["pointer:restore-motion","pointer:button-one","pointer:button-two"])
	# API取消和过期回写不伪称真实点击路径。
	var token:int=app.parts.action.begin()
	app.parts.action.cancel()
	var rejected:bool=not app.parts.action.finish(token,{"ok":true})
	record("api-rejects-stale-completion",token>0 and rejected and not app.parts.action.busy,observe(),["api:begin","api:cancel","api:old-finish"])
	await pointer(app.find_child("Scale",true,false).get_global_rect().get_center())
	await wait(0.2)
	var heading:Label
	for item in app.find_children("*","Label",true,false):
		if item.text=="公共交互检查台": heading=item
	state=observe()
	state.setting_font=app.fail_next.get_theme_font_size("font_size")
	state.heading_font=heading.get_theme_font_size("font_size")
	record("lab-125-keeps-roles",state.setting_font==21 and state.heading_font==35,state,["pointer:scale"])
	# 外观变体不是交互角色；小号Tab仍应采用Tab释放幅度，而非普通按钮幅度。
	var small_tab:Button=app.parts.buttons[2]
	small_tab.theme_type_variation="SmallTabButton"
	await wait(0.1)
	await pointer(small_tab.get_global_rect().get_center())
	var peak:=1.0
	var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<520:
		peak=maxf(peak,small_tab.offset_transform_scale.x)
		await process_frame
	state=observe()
	state.tab_peak=peak
	record("tab-role-survives-style-variant",peak>1.005 and peak<1.04,state,["condition:SmallTabButton","pointer:tab2","sample:release"])
	app.parts.tabs.set_reduced(true)
	await pointer(app.parts.buttons[0].get_global_rect().get_center())
	await wait(0.08)
	state=observe()
	state.tab_scale=app.parts.buttons[0].offset_transform_scale.x
	record("group-reduced-covers-button-feedback",is_equal_approx(state.tab_scale,1),state,["api:local-tab-reduced","pointer:tab0"])
	var sources: Dictionary={}
	for path in ["components/godot/input_focus.gd","components/godot/action_button.gd","components/godot/tab_group.gd","components/godot/disclosure.gd","sample/controls_lab.gd"]: sources[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open("res://evidence/controls-godot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source_files":sources,"platform":"godot","build_id":app.manifest.build_id,"input_driver":"Input.parse_input_event; API checks explicitly labelled","checks":checks,"failed":checks.filter(func(c):return not c.passed)},"\t"))
	app.queue_free()
	await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
