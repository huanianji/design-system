extends Node

const Feedback=preload("res://components/godot/action_button.gd")
var target:Control
var mark:TextureRect
var kind:String
var config:Dictionary
var enabled:=true
var progress:=0.0
var reduced:=false
var animation:Dictionary={}

static func attach(control:Control, role:String, parameters:Dictionary) -> Node:
	var existing:=control.get_node_or_null("DynamicIcon")
	if existing:return existing
	var behavior=load("res://components/godot/dynamic_icon.gd").new()
	behavior.target=control;behavior.kind=role;behavior.config=parameters
	control.add_child(behavior);behavior.name="DynamicIcon"
	control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	control.pivot_offset=Vector2(control.size.x/2,control.size.y*0.125 if role=="bell" else control.size.y/2)
	if role=="microphone":
		behavior.mark=TextureRect.new();behavior.mark.texture=load("res://assets/icons/slash.svg")
		behavior.mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		behavior.mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
		control.add_child(behavior.mark);behavior.mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.visibility_changed.connect(func():
		if not control.is_visible_in_tree():behavior.settle())
	behavior.settle();return behavior

func stop() -> void:
	animation={}
	set_process(false)

# 用实际经过时间推进图标，避免引擎Tween时步与浏览器时钟形成累计节奏差。
func _process(_delta:float) -> void:
	if animation.is_empty():return
	var p:float=clampf((Time.get_ticks_usec()-int(animation.started))/1000000.0/float(animation.seconds),0.0,1.0)
	if kind=="bell":
		var values:Array=animation.values
		var segment:int=mini(int(p*(values.size()-1)),values.size()-2)
		var q:float=p*(values.size()-1)-segment
		target.rotation_degrees=lerpf(float(values[segment]),float(values[segment+1]),q*q*(3-2*q))
	elif kind=="microphone":
		progress=lerpf(float(animation.from),float(animation.to),1-pow(1-p,3));draw_state()
		target.scale=Vector2.ONE*Feedback.sample_keys(Feedback.ease_bezier(p,config.release_easing),[animation.scale_from,config.tab_release_peak,config.release_return,1.0],[0.0,config.release_offsets[0],config.release_offsets[1],1.0])
	if p>=1.0:settle()

func draw_state() -> void:
	if mark:mark.modulate.a=progress
	target.set_meta("hj_icon_progress",progress)
	target.set_meta("hj_icon_enabled",enabled)

func settle() -> void:
	stop()
	target.scale=Vector2.ONE
	if kind=="microphone":progress=0.0 if enabled else 1.0
	target.rotation=PI*progress if kind=="direction" else 0.0
	draw_state()

func notify() -> void:
	if kind!="bell":return
	stop()
	if reduced:settle();return
	var values:Array=[target.rotation_degrees];values.append_array(config.bell_degrees)
	animation={"started":Time.get_ticks_usec(),"seconds":config.bell_seconds,"values":values}
	set_process(true)

func set_enabled(value:bool, animated:bool=true) -> void:
	if kind!="microphone" or (enabled==value and animated):return
	enabled=value
	var from:float=progress
	var scale_from:float=target.scale.x
	stop();draw_state()
	if reduced or not animated:settle();return
	animation={"started":Time.get_ticks_usec(),"seconds":config.release_seconds,"from":from,"to":0.0 if enabled else 1.0,"scale_from":scale_from}
	set_process(true)

func follow(value:float) -> void:
	if kind!="direction":return
	progress=value;target.rotation=PI*value;draw_state()

func set_reduced(value:bool) -> void:
	reduced=value
	if reduced:settle()

func _exit_tree() -> void:
	stop()
	if is_instance_valid(target):target.rotation=PI*progress if kind=="direction" else 0.0;target.scale=Vector2.ONE
