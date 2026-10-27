extends "res://adapters/godot/verify_combined.gd"
func run() -> void:
 root.size=Vector2i(1280,960);await fresh()
 await click("NoteToggle");await wait(0.5);await input_text(app.get_node("%Note"),"");await click("NoteSave");await record("empty-save",["input:empty-note","pointer:save"])
 await key(KEY_ESCAPE);await record("escape-focus",["key:Escape"])
 await click("Microphone");await key(KEY_TAB);await key(KEY_TAB,true);await key(KEY_SPACE);await record("keyboard-mic-focus",["pointer:microphone","key:Tab","key:ShiftTab","key:Space"])
 await click("NoteToggle");await wait(0.5);await input_text(app.get_node("%Note"),"跨界面草稿");await click("NoteSave");await click("CreativeView");await wait(0.75);await click("ManagementView");await record("view-cancel",["input:draft","pointer:save","pointer:creative","pointer:management"])
 await input_text(app.get_node("%Note"),"重新读取时保留草稿");await click("NoteSave");await click("Reload");await wait(0.75);await record("reload-cancel",["input:draft","pointer:save","pointer:reload"])
 await input_text(app.get_node("%Note"),"较长备注包含中文、English和1234567890。".repeat(8));await record("long-note-wrap",["input:long-note"])
 var sources:Dictionary={}
 for path in ["adapters/godot/fragments.gd","adapters/godot/verify_combined.gd","adapters/godot/verify_combined_extras.gd","components/godot/action_button.gd","components/godot/disclosure.gd","components/godot/dynamic_icon.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
 var file:=FileAccess.open("res://evidence/combined-extras-godot.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"platform":"godot","build_id":observed_build,"source_files":sources,"checks":checks},"\t"));quit()
