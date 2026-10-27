extends "res://adapters/godot/verify_combined.gd"
var layout_cases:Array=[]
func layout_record(id:String) -> void:
 await wait(0.4)
 var cards:Array=[]
 for key in app.asset_tiles:
  var tile:Dictionary=app.asset_tiles[key]
  if tile.button.is_visible_in_tree():cards.append({"id":key,"width":tile.button.size.x,"height":tile.button.size.y,"centered":tile.label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"label_height":tile.label.size.y})
 var title:Control=app.get_node("%LibraryLabel");var category_all:Button=app.get_node("%CategoryAll")
 var obs:Dictionary={"viewport":[root.size.x,root.size.y],"enlarged":app.enlarged,"cards":cards,"filter_gap":category_all.global_position.x-title.get_global_rect().end.x,"all_selected":category_all.button_pressed,"canvas_clip":app.get_node("%Canvas").clip_contents,"fits":app.get_node("%Workspace").get_global_rect().end.x<=root.size.x}
 app.get_node("%Scroll").ensure_control_visible(app.get_node("%AssetStrip"));await wait(0.1)
 var path:="evidence/combined-layout-"+id+"-godot.png";RenderingServer.force_draw();root.get_texture().get_image().save_png("res://"+path)
 layout_cases.append({"id":id,"observed":obs,"screenshot":path})
func run() -> void:
 root.size=Vector2i(1280,960);await fresh();await click("CreativeView");await layout_record("wide")
 await click("TextScale");await layout_record("wide-125")
 root.size=Vector2i(800,720);await layout_record("compact-125")
 var sources:Dictionary={}
 for path in ["web/fragments.css","adapters/godot/create_fragments.py","sample/fragments.tscn","adapters/godot/fragments.gd","adapters/godot/verify_combined_layout.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
 var file:=FileAccess.open("res://evidence/combined-layout-godot.json",FileAccess.WRITE);file.store_string(JSON.stringify({"platform":"godot","build_id":observed_build,"source_files":sources,"checks":layout_cases},"\t"));quit()
