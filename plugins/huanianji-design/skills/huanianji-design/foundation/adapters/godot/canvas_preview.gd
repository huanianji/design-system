extends Control

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
var zoom := 100.0:
	set(value):
		zoom = value
		queue_redraw()
var opacity := 100.0:
	set(value):
		opacity = value
		queue_redraw()
var art_alpha:=1.0:
	set(value):
		art_alpha=value
		queue_redraw()
var checker: Array[Color] = [Color("#eeeef1"),Color("#dedee3")]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func art_rect() -> Rect2:
	if texture == null: return Rect2()
	var original := texture.get_size()
	var factor := minf(size.x/original.x,size.y/original.y)*0.7*zoom/100.0
	var drawn := original*factor
	return Rect2((size-drawn)/2,drawn)

func _draw() -> void:
	# 棋盘属于内容预览，固定本色，不跟随工具界面的浅深主题。
	for y in range(0,ceili(size.y),16):
		for x in range(0,ceili(size.x),16):
			draw_rect(Rect2(x,y,minf(16,size.x-x),minf(16,size.y-y)),checker[(int(x/16.0)+int(y/16.0))%2])
	if texture:
		draw_texture_rect(texture,art_rect(),false,Color(1,1,1,opacity/100.0*art_alpha))
