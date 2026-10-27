extends Control
signal seeked(value: float)
var time:=2.4
var dragging:=false
var colors: Dictionary
const LENGTH:=12.0
var label_width:=168.0
var row_height:=28.0
var tracks:Array=[]
var tracked_frames:Dictionary={}

func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	focus_mode=Control.FOCUS_ALL
	accessibility_name="统一时间轴，左右方向键定位，空格播放"
	clip_contents=true

func configure(objects: Dictionary, frames: Dictionary) -> void:
	var next:Array=[{"label":"场景 · 午后工作室","kind":"scene"},{"label":"摄影机 · 主机位","kind":"camera"}]
	for key in objects:
		next.append({"label":objects[key].name,"kind":"object","target":key})
		for property in frames.get(key,{}):
			next.append({"label":"    "+{"x":"水平位置","z":"纵深位置","rotation":"旋转","scale":"缩放"}[property],"kind":"property","target":key,"property":property})
	label_width=196.0 if get_theme_default_font_size()>14 else 168.0
	row_height=32.0 if get_theme_default_font_size()>14 else 28.0
	if next==tracks and frames==tracked_frames:return
	tracks=next;tracked_frames=frames.duplicate(true)
	custom_minimum_size=Vector2(440,30+tracks.size()*row_height+8);queue_redraw()

func at_x(value: float) -> float: return label_width+(size.x-label_width-24)*value/LENGTH

func _text_fit(text: String, font: Font, pixels: int) -> String:
	if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x<label_width-24:return text
	while not text.is_empty() and font.get_string_size(text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>label_width-24:text=text.left(-1)
	return text+"…"

func _diamond(point: Vector2, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([point+Vector2(0,-4),point+Vector2(4,0),point+Vector2(0,4),point+Vector2(-4,0)]),tint)

func _draw() -> void:
	if colors.is_empty():return
	var text:Color=colors.muted; var font:Font=get_theme_default_font(); var fs:=get_theme_default_font_size()-2
	draw_rect(Rect2(label_width,0,size.x-label_width,size.y),colors.field)
	for i in 13:
		var x:=at_x(i); draw_line(Vector2(x,0),Vector2(x,size.y-8),colors.border,1)
		draw_string(font,Vector2(x+5,18),"%02d"%i,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,text)
	for i in tracks.size():
		var row:Dictionary=tracks[i];var y:=30+i*row_height
		draw_line(Vector2(0,y),Vector2(size.x,y),colors.border,1)
		draw_string(font,Vector2(4,y+row_height/2+fs*.35),_text_fit(row.label,font,fs),HORIZONTAL_ALIGNMENT_LEFT,label_width-24,fs,text)
		if row.kind=="property":
			for frame in tracked_frames.get(row.target,{}).get(row.property,[]):_diamond(Vector2(at_x(frame.time),y+row_height/2),colors.accent)
		else:
			var start:=0.0 if row.kind in ["scene","camera"] else 1.0
			var width:=at_x(12 if row.kind in ["scene","camera"] else 10)-at_x(start)
			var style:=StyleBoxFlat.new();style.bg_color=colors.wash if row.kind in ["scene","camera"] else colors.surface;style.set_corner_radius_all(4)
			draw_style_box(style,Rect2(at_x(start)+1,y+5,width-2,row_height-10))
			if row.kind=="camera":
				for p in [0.0,4.0,8.0,12.0]:_diamond(Vector2(at_x(p),y+row_height/2),colors.accent)
	var x:=at_x(time)
	draw_line(Vector2(x,0),Vector2(x,size.y-8),colors.accent,2)
	draw_colored_polygon(PackedVector2Array([Vector2(x-5,0),Vector2(x+5,0),Vector2(x+5,8),Vector2(x,13),Vector2(x-5,8)]),colors.accent)
	if has_focus():draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),colors.accent,false,1)

func _get_tooltip(at: Vector2) -> String:
	var index:=int((at.y-30)/row_height)
	return tracks[index].label if at.y>=30 and index>=0 and index<tracks.size() else "拖动标尺定位；菱形表示关键帧"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if dragging:
			grab_focus();set_time_from_x(event.position.x)
		else: release_focus()
		accept_event()
	if event is InputEventMouseMotion and dragging:set_time_from_x(event.position.x);accept_event()
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT,KEY_RIGHT]:
			time=clampf(time+(.1 if event.keycode==KEY_RIGHT else -.1),0,LENGTH);seeked.emit(time);queue_redraw();accept_event()

func set_time_from_x(x: float) -> void:
	time=clampf((x-label_width)/(size.x-label_width-24)*LENGTH,0,LENGTH);seeked.emit(time);queue_redraw()
