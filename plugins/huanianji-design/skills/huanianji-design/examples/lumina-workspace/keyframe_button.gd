extends Button

var at_key:=false
var has_track:=false
var key_color:=Color("e8d29d")

func _draw() -> void:
	var center:=size/2
	var points:=PackedVector2Array([center+Vector2(0,-5),center+Vector2(5,0),center+Vector2(0,5),center+Vector2(-5,0)])
	var stroke:Color=key_color if at_key else get_theme_color("font_pressed_color" if has_track else "font_color","Button")
	if disabled:stroke.a=.45
	if at_key:draw_colored_polygon(points,stroke)
	else:points.append(points[0]);draw_polyline(points,stroke,1.4,true)
