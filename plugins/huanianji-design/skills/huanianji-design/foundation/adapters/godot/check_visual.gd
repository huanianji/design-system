@tool
extends Control

@export var glyph_offset_x := 0.0:
	set(value):
		glyph_offset_x = value
		queue_redraw()

var progress := 1.0:
	set(value):
		progress = value
		queue_redraw()

func _draw() -> void:
	var parent := get_parent() as CheckBox
	var color := parent.get_theme_color("font_pressed_color", "Action")
	var active := parent.get_theme_stylebox("normal", "Action").duplicate() as StyleBoxFlat
	var inactive := parent.get_theme_stylebox("normal", "LineEdit").duplicate() as StyleBoxFlat
	var outline := parent.get_theme_stylebox("panel", "CheckShape") as StyleBoxFlat
	for corner in ["top_left","top_right","bottom_right","bottom_left"]:
		active.set("corner_radius_"+corner,outline.get("corner_radius_"+corner))
		inactive.set("corner_radius_"+corner,outline.get("corner_radius_"+corner))

	draw_style_box(inactive, Rect2(Vector2.ZERO, size))
	if progress > 0:
		active.bg_color.a = clampf(progress,0,1)
		draw_style_box(active, Rect2(Vector2.ZERO,size))
		var a := Vector2(7+glyph_offset_x,14)
		var b := Vector2(12+glyph_offset_x,19)
		var c := Vector2(22+glyph_offset_x,8)
		var distance := (a.distance_to(b) + b.distance_to(c)) * progress
		var elbow := minf(distance/a.distance_to(b),1)
		draw_line(a,a.lerp(b,elbow),color,2.2,true)
		if distance > a.distance_to(b):
			draw_line(b,b.lerp(c,clampf((distance-a.distance_to(b))/b.distance_to(c),0,1)),color,2.2,true)
