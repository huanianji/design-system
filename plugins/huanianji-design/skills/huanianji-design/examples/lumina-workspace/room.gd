extends Node3D

var objects: Dictionary={}
var grid: Node3D
var marker: MeshInstance3D
var environment: WorldEnvironment
var lamp: OmniLight3D
var base_positions: Dictionary={}

func material(color: String, emission := false) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=Color(color); m.roughness=.82
	if emission: m.emission_enabled=true; m.emission=Color(color); m.emission_energy_multiplier=.7
	return m

func cube(parent: Node3D, at: Vector3, dimensions: Vector3, color: String) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=dimensions
	n.mesh=mesh; n.material_override=material(color); n.position=at; parent.add_child(n); return n

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=32
	n.mesh=mesh; n.material_override=material(color); n.position=at; parent.add_child(n); return n

func _ready() -> void:
	environment=WorldEnvironment.new(); var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("a5b6b9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("fff5e4"); env.ambient_light_energy=.65
	environment.environment=env; add_child(environment)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-36,-38,0); sun.light_color=Color("ffe4ba"); sun.light_energy=1.4; sun.shadow_enabled=true; add_child(sun)
	cube(self,Vector3(0,-.08,0),Vector3(8,.16,6),"9b8c76")
	cube(self,Vector3(0,1.8,-2.6),Vector3(8,3.6,.15),"d2cfbd")
	cube(self,Vector3(-3.9,1.8,0),Vector3(.15,3.6,5.2),"b4bcb3")
	# 窗格与陈设为本预览原创几何，不依赖媒体后端或外部素材。
	cube(self,Vector3(-1.3,2,-2.49),Vector3(2.6,2.05,.05),"91b6bb")
	for x in [-2.64,-1.3,.04]: cube(self,Vector3(x,2,-2.42),Vector3(.075,2.18,.1),"e9ddc1")
	for y in [.93,2,3.07]: cube(self,Vector3(-1.3,y,-2.42),Vector3(2.74,.075,.1),"e9ddc1")
	cube(self,Vector3(-1.3,.85,-2.2),Vector3(3,.16,.5),"b38a65")
	var desk:=Node3D.new(); desk.position=Vector3(.4,0,-.65); add_child(desk); objects.desk=desk
	cube(desk,Vector3(0,1,0),Vector3(2.65,.12,1),"c58f67")
	for x in [-1.12,1.12]:
		for z in [-.35,.35]: cube(desk,Vector3(x,.48,z),Vector3(.1,.96,.1),"454b48")
	cube(desk,Vector3(.2,1.43,-.26),Vector3(.95,.56,.055),"353e40")
	cube(desk,Vector3(.2,1.43,-.22),Vector3(.85,.46,.025),"adc6b6")
	cube(desk,Vector3(.2,1.13,-.24),Vector3(.07,.25,.07),"454b48")
	cube(desk,Vector3(.2,1.08,-.18),Vector3(.42,.035,.24),"454b48")
	cube(desk,Vector3(.2,1.09,.2),Vector3(.7,.028,.2),"ded6c2")
	cylinder(desk,Vector3(-.75,1.18,.18),.105,.25,"e8ded0")
	var seat:=Node3D.new(); seat.position=Vector3(.6,0,.62); add_child(seat); objects.chair=seat
	cube(seat,Vector3(0,.62,0),Vector3(.82,.14,.72),"697d70")
	var back:=cube(seat,Vector3(0,1.06,.33),Vector3(.82,.82,.12),"697d70"); back.rotation_degrees.x=-8
	for x in [-.31,.31]:
		for z in [-.25,.25]:cube(seat,Vector3(x,.28,z),Vector3(.065,.56,.065),"4e5b53")
	var light:=Node3D.new(); light.position=Vector3(2.1,0,-1.4); add_child(light); objects.lamp=light
	cylinder(light,Vector3(0,.06,0),.32,.12,"4b5951"); cylinder(light,Vector3(0,1.05,0),.035,2,"4b5951")
	var shade:=MeshInstance3D.new(); var cone:=CylinderMesh.new(); cone.top_radius=.22; cone.bottom_radius=.5; cone.height=.48; shade.mesh=cone; shade.position.y=2; shade.material_override=material("e9cfa4"); light.add_child(shade)
	lamp=OmniLight3D.new(); lamp.position=Vector3(0,1.8,0); lamp.light_color=Color("ffe1ab"); lamp.light_energy=1.2; lamp.omni_range=3; light.add_child(lamp)
	var plant:=Node3D.new(); plant.position=Vector3(-2.7,0,-.5); add_child(plant); objects.plant=plant
	cylinder(plant,Vector3(0,.22,0),.25,.44,"bd8668")
	for i in 7:
		var stem:=cube(plant,Vector3(0,.7,0),Vector3(.025,.85,.025),"596d4f"); stem.rotation_degrees.z=(i-3)*7
		var leaf:=MeshInstance3D.new(); var leaf_mesh:=SphereMesh.new(); leaf_mesh.radius=.18; leaf_mesh.height=.7; leaf.mesh=leaf_mesh; leaf.material_override=material("71886a"); leaf.position=Vector3(sin(i*2.4)*.25,.95+cos(i)*.18,cos(i*2.4)*.2); leaf.rotation_degrees=Vector3(i*12,0,(i-3)*20); plant.add_child(leaf)
	grid=Node3D.new(); add_child(grid)
	for i in range(-8,9):
		var a:=cube(grid,Vector3(i*.5,.015,0),Vector3(.008,.005,6),"777e77"); a.layers=2
	for i in range(-6,7):
		var a:=cube(grid,Vector3(0,.015,i*.5),Vector3(8,.005,.008),"777e77"); a.layers=2
	marker=MeshInstance3D.new(); var ring:=TorusMesh.new(); ring.inner_radius=.58; ring.outer_radius=.6; marker.mesh=ring; marker.material_override=material("c5f5d4",true); marker.layers=2; marker.position=Vector3(.4,.04,-.65); add_child(marker)
	for key in objects:
		base_positions[key]=objects[key].position
		var body:=StaticBody3D.new();body.set_meta("element_id",key);objects[key].add_child(body)
		var shape:=CollisionShape3D.new();var volume:=BoxShape3D.new()
		volume.size={"desk":Vector3(2.65,1.6,1),"chair":Vector3(.9,1.5,.9),"lamp":Vector3(1,2.3,1),"plant":Vector3(.8,1.4,.8)}[key]
		shape.shape=volume;shape.position.y=volume.size.y/2;body.add_child(shape)

func select(key: String) -> void:
	marker.visible=objects.has(key)
	if objects.has(key): marker.position=objects[key].position+Vector3(0,.04,0)

func transform_object(key: String, values: Dictionary) -> void:
	if not objects.has(key): return
	var n:Node3D=objects[key]; n.position=Vector3(values.x,0,values.z); n.rotation_degrees.y=values.rotation; n.scale=Vector3.ONE*values.scale; n.visible=values.visible
	if marker.visible:select(key)

func color_exposure(value: float) -> void:
	environment.environment.ambient_light_energy=.65*pow(2,value)
	lamp.light_energy=1.2*pow(2,value)
